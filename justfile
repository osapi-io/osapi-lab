set allow-duplicate-variables

# Shared recipes are imported flat and prefixed (md-*, just-*, ansible-*).
# import? tolerates the files being absent so `just fetch` works on a fresh clone.

import? '.just/remote/md.just'

import? '.just/remote/just.just'

import? '.just/remote/ansible.just'

# No documentation site, so md formats every markdown file in the repository.
md_site_dir := ""
md_extra_excludes := "--exclude '.lab/**' --exclude '**/.venv/**'"

# --- Fetch ---

# List the recipes
default:
    @just --list

# Fetch shared justfiles from osapi-justfiles
#
# It fetches the commit that main is at, not refs/heads/main: the raw URL of a
# branch is cached for five minutes, so a run just after a merge got the old
# modules and said nothing (osapi-io/osapi-justfiles#108). git ls-remote asks
# the server and has no cache, and the URL of a commit never changes. The
# commit goes to .just/remote/VERSION, so a build records what it used.
fetch:
    #!/usr/bin/env bash
    set -euo pipefail
    sha=$(git ls-remote https://github.com/osapi-io/osapi-justfiles refs/heads/main | cut -f1)
    base="https://raw.githubusercontent.com/osapi-io/osapi-justfiles/$sha"
    mkdir -p .just/remote
    for module in md just ansible; do
        curl -sSfL "$base/$module/$module.just" -o ".just/remote/$module.just"
    done
    echo "$sha" > .just/remote/VERSION
    echo "osapi-justfiles $sha"

# --- Top-level orchestration ---

# Run all checks
test:
    just md-fmt-check
    just just-fmt-check
    just ansible-test
    packer fmt -check packer

# Format and lint before committing
ready:
    just md-fmt
    just just-fmt
    just ansible-fmt
    packer fmt packer

# --- Lab ---

# Show every VM, the image it came from and the osapi build inside it
[group('lab')]
list:
    just ansible-run list

# Bake every image again and replace every VM, also when nothing changed (needs passwordless sudo on the hub)
[group('lab')]
rebuild:
    just ansible-run rebuild

# Bake the images of what changed and replace those VMs (needs passwordless sudo on the hub)
[group('lab')]
deploy:
    just ansible-run deploy

# Create the whole lab: secrets, the hub, the images and the VMs; safe to run again
[group('lab')]
site:
    just ansible-run site

# Remove the lab from the hub; keeps the images and .lab
[group('lab')]
teardown:
    just ansible-run teardown

# Build osapi from your checkout into .lab/bin
[group('lab')]
build:
    just ansible-run build

# Bake the images of what changed, and leave the running VMs as they are
[group('lab')]
images:
    just ansible-run images

# Show the hub's recent NATS and controller logs
[group('lab')]
logs:
    just ansible-run logs

# Open a shell on a VM, such as `just ssh ubuntu-1`
# Hold the lab for a session, such as `just lock osapi-1139`: wait while another run or session holds it. Each recipe that runs with LAB_SESSION=<name> keeps it, and only `just unlock <name>` gives it back
[group('lab')]
lock name:
    #!/usr/bin/env bash
    set -uo pipefail
    until LAB_SESSION={{ name }} just ansible-run lock > /tmp/lab-lock-{{ name }}.log 2>&1; do
        grep -q 'holds the lock' /tmp/lab-lock-{{ name }}.log || { cat /tmp/lab-lock-{{ name }}.log; exit 1; }
        echo "the lab is held; waiting"
        sleep 30
    done
    rm -f /tmp/lab-lock-{{ name }}.log
    echo "the lab is held by session {{ name }}: run its recipes with LAB_SESSION={{ name }}, then just unlock {{ name }}"

# Give back the lab that `just lock <name>` held
[group('lab')]
unlock name:
    LAB_SESSION={{ name }} just ansible-run unlock -e lab_session_release=true

# Hold the lab for one command and give it back after, also when it fails, such as `just lab-session osapi-1139 "just deploy && go test ./..."`
[group('lab')]
lab-session name cmd:
    #!/usr/bin/env bash
    set -uo pipefail
    just lock {{ name }} || exit 1
    trap 'just unlock {{ name }}' EXIT
    LAB_SESSION={{ name }} bash -c {{ quote(cmd) }}

[group('lab')]
ssh vm:
    just ansible-run client > /dev/null
    ssh -F .lab/ssh/config {{ vm }}

# Run this machine as one of the lab's agents, in the foreground
[group('lab')]
agent:
    .lab/bin/osapi -f .lab/config/agent-remote.yaml agent start
