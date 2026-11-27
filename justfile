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

# Bake each image that changed and replace its VM, and update the hub; targets narrow it, such as `just deploy ui` or `just deploy debian-lts`
[group('lab')]
deploy *targets:
    just _lab deploy {{ targets }}

# Put a new osapi build into the running processes, with no images, such as `just bump` or `just bump controller ubuntu-1`
[group('lab')]
bump *targets:
    just _lab bump {{ targets }}

# Bake each image again and replace each VM, also when nothing changed, such as `just rebuild debian-lts`
[group('lab')]
rebuild *targets:
    just _lab rebuild {{ targets }}

# Restart processes with no build and no copy, such as `just restart nats` or `just restart fedora-1`
[group('lab')]
restart *targets:
    just _lab restart {{ targets }}

# Stop processes and VMs, so that launchd does not start them again, such as `just stop jaeger` or `just stop fedora-1`
[group('lab')]
stop *targets:
    just _lab stop {{ targets }}

# Start what `just stop` stopped, such as `just start jaeger` or `just start fedora-1`
[group('lab')]
start *targets:
    just _lab start {{ targets }}

# Run playbooks/lab.yml in a mode on targets: nats, controller, ui (the
# controller), jaeger, hub (the three), vms, client, or a VM's name. With no
# target, each component and each VM. -e and -- arguments go to Ansible.
[private]
_lab mode *targets:
    #!/usr/bin/env bash
    set -euo pipefail
    tags=() vms=() extra=()
    set -- {{ targets }}
    while [ $# -gt 0 ]; do
        t=$1
        shift
        case "$t" in
            # -e and --extra-vars take the next word as their value.
            -e | --extra-vars)
                [ $# -gt 0 ] || { echo "$t needs a value" >&2; exit 1; }
                extra+=("$t" "$1")
                shift
                continue
                ;;
            nats | controller | jaeger | vms | client) tags+=("$t") ;;
            ui) tags+=(controller) ;;
            hub) tags+=(nats controller jaeger) ;;
            -*) extra+=("$t") ;;
            *) vms+=("$t") tags+=(vms) ;;
        esac
    done
    args=(-e lab_mode={{ mode }})
    if [ ${#vms[@]} -gt 0 ]; then args+=(-e "lab_only=$(IFS=,; echo "${vms[*]}")"); fi
    if [ ${#tags[@]} -gt 0 ]; then args+=(--tags "$(IFS=,; echo "${tags[*]}")"); fi
    just ansible-run lab "${args[@]}" ${extra[@]+"${extra[@]}"}

# Run osapi's integration suite against each VM of the lab and each other Ready agent, such as the Mac of `just agent`, or the agents named, such as `just int ubuntu-1 fedora-1`, with the write tests that CI runs; run it in a lab-session. LAB_OSAPI names the osapi checkout (../osapi)
[group('lab')]
int *vms:
    #!/usr/bin/env bash
    set -uo pipefail
    osapi="${LAB_OSAPI:-{{ justfile_directory() }}/../osapi}"
    vms="{{ vms }}"
    if [ -z "$vms" ]; then
        vms=$(awk '/^lab_vms:/ {on=1; next} on && /^[^ #-]/ {on=0} on && /- name:/ {print $3}' ansible/group_vars/all.yml)
        # An agent that is not a VM, such as this Mac with just agent, runs
        # only while someone runs it: test it when it is Ready.
        others=$(.lab/bin/osapi -f .lab/config/cli.yaml client agent list --json 2>/dev/null |
            jq -r '.items[]? | select(.state == "Ready") | .hostname' | grep -vxF "$vms" || true)
        if [ -n "$others" ]; then
            echo "and the agents that are not VMs: $(echo $others)"
            vms="$vms $others"
        fi
    fi
    mkdir -p .lab/int
    # The timeout is the one of osapi's go-int workflow: the suite runs for
    # more than go test's default of 10m.
    failed=()
    for vm in $vms; do
        echo "== $vm"
        if (cd "$osapi" && OSAPI_INTEGRATION_OSAPIFILE={{ justfile_directory() }}/.lab/config/cli.yaml \
            OSAPI_INTEGRATION_TARGET="$vm" OSAPI_INTEGRATION_WRITES=1 OSAPI_INTEGRATION_WRITE_BEHAVIORS=1 \
            GOFLAGS=-timeout=20m mise exec -- just go-unit-int) > ".lab/int/$vm.log" 2>&1; then
            echo "   ok    .lab/int/$vm.log"
        else
            echo "   FAIL  .lab/int/$vm.log"
            grep -E '^\s+--- FAIL' ".lab/int/$vm.log" | head -10
            failed+=("$vm")
        fi
    done
    if [ ${#failed[@]} -gt 0 ]; then
        echo "failed: ${failed[*]}"
        exit 1
    fi

# Remove the lab from the hub; keeps the images and .lab
[group('lab')]
teardown:
    just ansible-run teardown

# Build osapi from your checkout into .lab/bin, for darwin and linux
[group('lab')]
build:
    just ansible-run build

# Show the hub's recent logs: nats and controller, or the ones named, such as `just logs jaeger vm-ubuntu-1`
[group('lab')]
logs *names:
    just ansible-run logs {{ if names == "" { "" } else { "-e lab_logs=" + replace(names, " ", ",") } }}

# Hold the lab for a session, such as `just lock osapi-1139`: wait while another run or session holds it. Each recipe that runs with LAB_SESSION=<name> keeps it, and only `just unlock <name>` gives it back
[group('lab')]
lock name *args:
    #!/usr/bin/env bash
    set -uo pipefail
    log=$(mktemp -t lab-lock)
    trap 'rm -f "$log"' EXIT
    until LAB_SESSION={{ quote(name) }} just ansible-run lock {{ args }} > "$log" 2>&1; do
        grep -q 'holds the lock' "$log" || { cat "$log"; exit 1; }
        echo "the lab is held; waiting"
        sleep 30
    done
    echo "the lab is held by session "{{ quote(name) }}": run its recipes with LAB_SESSION="{{ quote(name) }}", then just unlock "{{ quote(name) }}

# Give back the lab that `just lock <name>` held
[group('lab')]
unlock name *args:
    LAB_SESSION={{ quote(name) }} just ansible-run unlock -e lab_session_release=true {{ args }}

# Hold the lab for one command and give it back after, also when it fails, such as `just lab-session osapi-1139 "just deploy && go test ./..."`
[group('lab')]
lab-session name cmd:
    #!/usr/bin/env bash
    set -uo pipefail
    just lock {{ quote(name) }} || exit 1
    trap 'just unlock {{ quote(name) }}' EXIT
    LAB_SESSION={{ quote(name) }} bash -c {{ quote(cmd) }}

[group('lab')]
ssh vm:
    just ansible-run client > /dev/null
    ssh -F .lab/ssh/config {{ vm }}

# Run this machine as one of the lab's agents, in the foreground
[group('lab')]
agent:
    .lab/bin/osapi -f .lab/config/agent-remote.yaml agent start
