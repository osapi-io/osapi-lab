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
fetch:
    mkdir -p .just/remote
    curl -sSfL https://raw.githubusercontent.com/osapi-io/osapi-justfiles/refs/heads/main/md/md.just -o .just/remote/md.just
    curl -sSfL https://raw.githubusercontent.com/osapi-io/osapi-justfiles/refs/heads/main/just/just.just -o .just/remote/just.just
    curl -sSfL https://raw.githubusercontent.com/osapi-io/osapi-justfiles/refs/heads/main/ansible/ansible.just -o .just/remote/ansible.just

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

# Rebuild the fleet from your osapi checkout (asks for the hub's sudo password)
[group('lab')]
push:
    just ansible-run push -K

# Copy your osapi build into the hub and the running VMs (asks for sudo)
[group('lab')]
deploy:
    just ansible-run deploy -K

# Build everything from nothing; safe to run again (asks for sudo)
[group('lab')]
site:
    just ansible-run site -K

# Remove the lab from the hub; keeps the images and .lab (asks for sudo)
[group('lab')]
teardown:
    just ansible-run teardown -K

# Build osapi from your checkout into .lab/bin
[group('lab')]
build:
    just ansible-run build

# Bake the build into the images the VMs are cloned from
[group('lab')]
images:
    just ansible-run images

# Show the hub's recent NATS and controller logs
[group('lab')]
logs:
    just ansible-run logs

# Open a shell on a VM, such as `just ssh ubuntu-1`
[group('lab')]
ssh vm:
    just ansible-run client > /dev/null
    ssh -F .lab/ssh/config {{ vm }}

# Run this machine as one of the lab's agents, in the foreground
[group('lab')]
agent:
    .lab/bin/osapi -f .lab/config/remote.yaml agent start
