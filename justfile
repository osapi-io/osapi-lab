set allow-duplicate-variables
set dotenv-load
set dotenv-filename := "lab.env"

# Shared recipes are imported flat and prefixed (md-fmt, just-fmt).
# import? tolerates the files being absent so `just fetch` works on a fresh clone.

import? '.just/remote/md.just'

import? '.just/remote/just.just'

# No documentation site, so md formats every markdown file in the repository.
md_site_dir := ""
md_extra_excludes := "--exclude '.lab/**'"

# Everything a lab generates lives here, gitignored.
state := justfile_directory() / ".lab"
osapi_dir := env("LAB_OSAPI_DIR", home_directory() / "git/osapi-io/osapi")
hub_ssh := env("LAB_HUB_SSH", "")
hub_dir := env("LAB_HUB_DIR", "git/osapi-io/osapi-lab")
ssh_opts := "-i " + state / "ssh/id_ed25519" + " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# The node lines from the nodes file, without comments or blanks.
nodes := "grep -Ev '^[[:space:]]*(#|$)' " + justfile_directory() / "nodes"

# --- Fetch ---

# List the recipes
default:
    @just --list

# Fetch shared justfiles from osapi-justfiles
fetch:
    mkdir -p .just/remote
    curl -sSfL https://raw.githubusercontent.com/osapi-io/osapi-justfiles/refs/heads/main/md/md.just -o .just/remote/md.just
    curl -sSfL https://raw.githubusercontent.com/osapi-io/osapi-justfiles/refs/heads/main/just/just.just -o .just/remote/just.just

# --- Top-level orchestration ---

# Run all checks
test:
    just md-fmt-check
    just just-fmt-check

# Format and lint before committing
ready:
    just md-fmt
    just just-fmt

# --- Hub: run on the Mac mini ---

# Build osapi on the hub from its own checkout at LAB_OSAPI_DIR
[group('hub')]
hub-build:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ state }}/bin
    cd {{ osapi_dir }}
    # osapi embeds ui/dist, so the UI is built first. osapi's own `just build`
    # does the same, but only for the platform it runs on. fetch brings in the
    # shared react recipes, which a fresh checkout does not have.
    mise trust -q .
    mise exec -- just fetch > /dev/null
    mise exec -- just react-deps react-build
    for os in darwin linux; do
      CGO_ENABLED=0 GOOS=$os GOARCH=arm64 mise exec -- go build -o {{ state }}/bin/osapi-$os-arm64 .
    done
    ln -sf osapi-darwin-arm64 {{ state }}/bin/osapi
    echo "built $(git rev-parse --abbrev-ref HEAD)@$(git rev-parse --short HEAD) into {{ state }}/bin"

# Generate the lab's secrets and SSH key, once
[group('hub')]
secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f {{ state }}/secrets.env ]; then echo "secrets exist: {{ state }}/secrets.env"; exit 0; fi
    mkdir -p {{ state }}/ssh
    chmod 0700 {{ state }}
    [ -f {{ state }}/ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -C osapi-lab -f {{ state }}/ssh/id_ed25519
    umask 077
    export LAB_STATE={{ state }}
    export LAB_NATS_PASSWORD=$(openssl rand -hex 24)
    export LAB_SIGNING_KEY=$(openssl rand -hex 32)
    export LAB_AGENT_DUMMY_KEY=$(openssl rand -hex 32)
    # osapi validates the whole config before any command, token generate
    # included, so the token is signed using the hub's own config, rendered with
    # a placeholder where the token goes.
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    LAB_TOKEN=pending scripts/render config/hub.yaml > "$tmp"
    token=$({{ state }}/bin/osapi-darwin-arm64 -f "$tmp" token generate -r admin -u lab | awk '/Token:/ {print $2}')
    [ -n "$token" ] || { echo "token generate printed no token" >&2; exit 1; }
    cat > {{ state }}/secrets.env <<EOF
    LAB_NATS_PASSWORD=$LAB_NATS_PASSWORD
    LAB_SIGNING_KEY=$LAB_SIGNING_KEY
    LAB_TOKEN=$token
    LAB_AGENT_DUMMY_KEY=$LAB_AGENT_DUMMY_KEY
    EOF
    echo "wrote {{ state }}/secrets.env and {{ state }}/ssh/id_ed25519"

# Render the hub's config and the config remote agents fetch
[group('hub')]
render:
    #!/usr/bin/env bash
    set -euo pipefail
    set -a; . {{ state }}/secrets.env; set +a
    export LAB_STATE={{ state }}
    mkdir -p {{ state }}/config {{ state }}/log
    umask 077
    scripts/render config/hub.yaml > {{ state }}/config/hub.yaml
    # A remote agent uses its own hostname and dials the hub's tailnet address.
    LAB_NODE= LAB_DISTRO=macos LAB_NATS_HOST=${LAB_HUB_ADDR:?set LAB_HUB_ADDR in lab.env} \
      scripts/render config/agent.yaml > {{ state }}/config/remote.yaml
    scripts/render config/client.yaml > {{ state }}/config/client.yaml
    echo "rendered {{ state }}/config/hub.yaml, remote.yaml and client.yaml"

# Install and start the hub's NATS server and controller under launchd
[group('hub')]
hub-install: render firewall
    #!/usr/bin/env bash
    set -euo pipefail
    export LAB_STATE={{ state }}
    for c in nats controller; do
      case $c in
        nats) args='<string>nats</string><string>server</string><string>start</string>' ;;
        controller) args='<string>controller</string><string>start</string>' ;;
      esac
      plist=~/Library/LaunchAgents/io.osapi.lab.$c.plist
      launchctl bootout gui/$(id -u) "$plist" 2>/dev/null || true
      LAB_COMPONENT=$c LAB_ARGS=$args scripts/render launchd/hub.plist > "$plist"
      launchctl bootstrap gui/$(id -u) "$plist"
    done
    echo "hub running; logs in {{ state }}/log"

# Let the VMs and remote agents reach NATS through the macOS firewall
[group('hub')]
firewall:
    #!/usr/bin/env bash
    set -euo pipefail
    fw=/usr/libexec/ApplicationFirewall/socketfilterfw
    bin={{ state }}/bin/osapi-darwin-arm64
    # The firewall knows an unsigned binary by its signature, and every build
    # signs anew, so this runs after each build. Reading the state needs no
    # sudo; only a change does, so a firewall already letting osapi in costs
    # nothing.
    blockall=$($fw --getblockall | grep -q 'blocking all' && echo on || echo off)
    blocked=$($fw --getappblocked "$bin" | grep -q 'is blocked' && echo yes || echo no)
    if [ "$blockall" = off ] && [ "$blocked" = no ]; then
      echo "firewall: ok, osapi accepts incoming connections"
      exit 0
    fi
    if ! sudo -n true 2>/dev/null && ! [ -t 0 ]; then
      echo "firewall: needs sudo; run it from a terminal (ssh -t)" >&2
      exit 1
    fi
    # "Block all incoming connections" overrides any per-app allow, so it goes
    # off. The firewall stays on and admits only the hub's binary.
    [ "$blockall" = off ] || sudo $fw --setblockall off
    sudo $fw --add "$bin"
    sudo $fw --unblockapp "$bin"
    $fw --getappblocked "$bin"

# Restart the hub, picking up a new build or config
[group('hub')]
hub-restart: firewall
    launchctl kickstart -k gui/$(id -u)/io.osapi.lab.nats
    launchctl kickstart -k gui/$(id -u)/io.osapi.lab.controller

# Stop the hub and remove its launchd jobs
[group('hub')]
hub-uninstall:
    #!/usr/bin/env bash
    for c in nats controller; do
      plist=~/Library/LaunchAgents/io.osapi.lab.$c.plist
      launchctl bootout gui/$(id -u) "$plist" 2>/dev/null || true
      rm -f "$plist"
    done

# Follow the hub's logs
[group('hub')]
hub-logs:
    tail -F {{ state }}/log/nats.log {{ state }}/log/controller.log

# Run an osapi command against the hub, such as `just osapi client agent list`
[group('hub')]
osapi *args:
    #!/usr/bin/env bash
    set -euo pipefail
    # On the hub, its own config; anywhere else, the client config
    # `just remote-client` fetched.
    cfg={{ state }}/config/hub.yaml
    [ -f "$cfg" ] || cfg={{ state }}/config/client.yaml
    exec {{ state }}/bin/osapi-darwin-arm64 -f "$cfg" {{ args }}

# --- Images and VMs: run on the Mac mini ---

# Build the base images with Packer: all three, or one (ubuntu, debian, fedora)
[group('vm')]
images distro="":
    #!/usr/bin/env bash
    set -euo pipefail
    mise exec -- packer init packer
    only=""
    if [ -n "{{ distro }}" ]; then only="-only=tart-cli.{{ distro }}"; fi
    mise exec -- packer build -force $only -var "ssh_pubkey=$(cat {{ state }}/ssh/id_ed25519.pub)" packer

# Clone and start every VM in the nodes file that is not already running
[group('vm')]
up:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ state }}/log
    {{ nodes }} | while read -r name image; do
      vm=lab-$name
      tart list -q | grep -qx "$vm" || tart clone "lab-$image" "$vm"
      if [ "$(tart list | awk -v vm="$vm" '$2 == vm {print $NF}')" = running ]; then
        echo "$vm: running"
        continue
      fi
      nohup tart run --no-graphics "$vm" > {{ state }}/log/$vm.log 2>&1 < /dev/null &
      echo "$vm: started"
    done

# Stop every VM in the nodes file
[group('vm')]
down:
    {{ nodes }} | while read -r name _; do tart stop "lab-$name" 2>/dev/null && echo "lab-$name: stopped" || true; done

# Stop and delete every VM in the nodes file (images are kept)
[group('vm')]
destroy: down
    {{ nodes }} | while read -r name _; do tart delete "lab-$name" 2>/dev/null && echo "lab-$name: deleted" || true; done

# Print each VM's address
[group('vm')]
ips:
    {{ nodes }} | while read -r name _; do printf '%-12s %s\n' "$name" "$(tart ip lab-$name 2>/dev/null || echo -)"; done

# Open a shell on a VM
[group('vm')]
ssh node:
    ssh {{ ssh_opts }} admin@$(tart ip lab-{{ node }})

# Copy the build and a rendered config into every VM and restart its agent
[group('vm')]
deploy:
    #!/usr/bin/env bash
    set -euo pipefail
    set -a; . {{ state }}/secrets.env; set +a
    mkdir -p {{ state }}/config
    umask 077
    {{ nodes }} | while read -r name image; do
      ip=$(tart ip "lab-$name" --wait 120)
      # The hub is the .1 of the VM's vmnet subnet.
      LAB_NODE=$name LAB_DISTRO=$image LAB_NATS_HOST=${ip%.*}.1 \
        scripts/render config/agent.yaml > {{ state }}/config/$name.yaml
      # Checked with the same build before it ships, so a config the agent would
      # reject stops here rather than crash-looping in the VM. osapi validates
      # the config before every command; liveness is one every release has.
      if out=$({{ state }}/bin/osapi-darwin-arm64 -f {{ state }}/config/$name.yaml client health liveness 2>&1) \
        || grep -q 'invalid config' <<< "$out"; then
        if grep -q 'invalid config' <<< "$out"; then echo "$name: $out" >&2; exit 1; fi
      fi
      scp {{ ssh_opts }} {{ state }}/bin/osapi-linux-arm64 {{ state }}/config/$name.yaml admin@$ip:/tmp/
      # osapi's agent exits at startup on a distribution outside its supported
      # list. IGNORE_LINUX is osapi's own override: the agent starts, uses the
      # generic Linux providers, and skips what has none. Only nodes that are not
      # Debian family get it, so the gate still runs everywhere it passes.
      case $image in
        ubuntu | debian) dropin='sudo rm -f /etc/systemd/system/osapi-agent.service.d/lab.conf' ;;
        *) dropin='sudo install -d /etc/systemd/system/osapi-agent.service.d && printf "[Service]\nEnvironment=IGNORE_LINUX=1\n" | sudo tee /etc/systemd/system/osapi-agent.service.d/lab.conf > /dev/null' ;;
      esac
      ssh -n {{ ssh_opts }} admin@$ip "sudo hostnamectl set-hostname $name \
        && sudo install -m 0755 /tmp/osapi-linux-arm64 /usr/local/bin/osapi \
        && sudo install -m 0600 /tmp/$name.yaml /etc/osapi/osapi.yaml \
        && rm -f /tmp/osapi-linux-arm64 /tmp/$name.yaml \
        && $dropin \
        && sudo systemctl daemon-reload \
        && sudo systemctl restart osapi-agent"
      echo "$name ($ip): deployed"
    done

# --- Your machine on the tailnet, such as a laptop ---

# Build your osapi checkout, ship it, restart the hub and every VM (asks for sudo)
[group('laptop')]
push: build copy restart

# Build osapi for darwin and linux from LAB_OSAPI_DIR into .lab/bin here
[group('laptop')]
build:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ state }}/bin
    cd {{ osapi_dir }}
    rev="$(git rev-parse --abbrev-ref HEAD)@$(git rev-parse --short HEAD)"
    [ -z "$(git status --porcelain)" ] || rev="$rev with uncommitted changes"
    echo "building $rev"
    # osapi embeds ui/dist, so the UI is built first, as `build` does on the hub.
    mise trust -q .
    mise exec -- just fetch > /dev/null
    mise exec -- just react-deps react-build > /dev/null
    # Each binary is built under a new name and moved over the old one: macOS
    # kills a signed binary whose bytes change in place.
    for os in darwin linux; do
      CGO_ENABLED=0 GOOS=$os GOARCH=arm64 mise exec -- go build -o {{ state }}/bin/osapi-$os-arm64.new .
      mv -f {{ state }}/bin/osapi-$os-arm64.new {{ state }}/bin/osapi-$os-arm64
    done
    ln -sf osapi-darwin-arm64 {{ state }}/bin/osapi
    echo "$rev" > {{ state }}/bin/REVISION

# Copy the binaries `build` made to the hub
[group('laptop')]
copy:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${LAB_HUB_SSH:?set LAB_HUB_SSH in lab.env}"
    for os in darwin linux; do
      scp -q {{ state }}/bin/osapi-$os-arm64 "$LAB_HUB_SSH:{{ hub_dir }}/.lab/bin/osapi-$os-arm64.new"
    done
    ssh "$LAB_HUB_SSH" "cd {{ hub_dir }}/.lab/bin && mv -f osapi-darwin-arm64.new osapi-darwin-arm64 && mv -f osapi-linux-arm64.new osapi-linux-arm64"
    echo "copied $(cat {{ state }}/bin/REVISION) to the hub"

# Restart the hub and deploy to every VM; the firewall step may ask for sudo
[group('laptop')]
restart:
    just hub hub-restart deploy
    @echo "lab running $(cat {{ state }}/bin/REVISION 2>/dev/null || echo 'the hub build')"

# Run lab recipes on the hub from here, such as `just hub ips` or `just hub up deploy`
[group('laptop')]
hub +recipes:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${LAB_HUB_SSH:?set LAB_HUB_SSH in lab.env}"
    # -t, so a recipe that needs sudo (firewall, which hub-install and
    # hub-restart run) can ask for your password. A non-interactive shell on the
    # hub has no mise or tart on PATH, so the usual install locations are added.
    ssh -t "$LAB_HUB_SSH" 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:$HOME/.homebrew/bin:$PATH" && cd {{ hub_dir }} && mise exec -- just {{ recipes }}'

# Fetch the hub's darwin build and the client config, for `just osapi` here
[group('laptop')]
remote-client:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${LAB_HUB_SSH:?set LAB_HUB_SSH in lab.env}"
    mkdir -p {{ state }}/bin {{ state }}/config
    chmod 0700 {{ state }}
    # Into a new file, then moved over the old one: macOS kills a signed binary
    # whose bytes change in place, which scp onto a running agent's binary does.
    scp "$LAB_HUB_SSH:{{ hub_dir }}/.lab/bin/osapi-darwin-arm64" {{ state }}/bin/osapi-darwin-arm64.new
    mv -f {{ state }}/bin/osapi-darwin-arm64.new {{ state }}/bin/osapi-darwin-arm64
    scp "$LAB_HUB_SSH:{{ hub_dir }}/.lab/config/client.yaml" {{ state }}/config/
    chmod 0600 {{ state }}/config/client.yaml
    ln -sf osapi-darwin-arm64 {{ state }}/bin/osapi
    echo "ready: run 'direnv allow' once, then 'osapi client agent list' in this directory"

# Fetch the hub's darwin build and remote config, then run an agent here
[group('laptop')]
remote-agent:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${LAB_HUB_SSH:?set LAB_HUB_SSH in lab.env}"
    mkdir -p {{ state }}/bin {{ state }}/config
    # Into a new file, then moved over the old one: macOS kills a signed binary
    # whose bytes change in place, which scp onto a running agent's binary does.
    scp "$LAB_HUB_SSH:{{ hub_dir }}/.lab/bin/osapi-darwin-arm64" {{ state }}/bin/osapi-darwin-arm64.new
    mv -f {{ state }}/bin/osapi-darwin-arm64.new {{ state }}/bin/osapi-darwin-arm64
    scp "$LAB_HUB_SSH:{{ hub_dir }}/.lab/config/remote.yaml" {{ state }}/config/
    chmod 0600 {{ state }}/config/remote.yaml
    cd {{ state }}
    exec bin/osapi-darwin-arm64 -f config/remote.yaml agent start
