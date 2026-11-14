<p align="center">
  <picture>
    <source srcset="asset/logo-dark.svg" media="(prefers-color-scheme: dark)">
    <source srcset="asset/logo-light.svg" media="(prefers-color-scheme: light)">
    <img src="asset/logo-dark.svg" alt="osapi-lab" width="496">
  </picture>
</p>

<p align="center">A small fleet of real machines to run osapi against.</p>

<p align="center">
  <a href="https://github.com/osapi-io/osapi-lab/actions/workflows/just-lint.yml"><img alt="just lint" src="https://img.shields.io/github/actions/workflow/status/osapi-io/osapi-lab/just-lint.yml?branch=main&style=for-the-badge"></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-MIT-brightgreen.svg?style=for-the-badge"></a>
  <a href="https://conventionalcommits.org"><img alt="conventional commits" src="https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg?style=for-the-badge"></a>
  <a href="https://just.systems"><img alt="built with just" src="https://img.shields.io/badge/Built_with-Just-black?style=for-the-badge&logo=just&logoColor=white"></a>
  <img alt="github commit activity" src="https://img.shields.io/github/commit-activity/m/osapi-io/osapi-lab?style=for-the-badge">
</p>

<p align="center">
<b>One Mac, a few Linux VMs, and a branch of osapi running on all of them.</b>
</p>

<p align="center">
Packer builds the images, Tart runs them, and just copies a local build of osapi
in. Testing a branch takes a build and a deploy, not an image rebuild.
</p>

## Usage

A Mac is the hub. It runs osapi's embedded NATS server and the controller under
launchd, and [Tart] VMs on it each run an agent. Agents dial out to NATS, so
nothing needs a route into a VM; the hub only has to be reachable.

```
            Mac (hub)                        your machine on the tailnet
   ┌──────────────────────────┐           ┌──────────────────────────────┐
   │ osapi nats server :4222  │◄──────────│ osapi client, agent (macos)  │
   │ osapi controller  :8080  │ Tailscale │ just push, just hub ...      │
   └────────────▲─────────────┘           └──────────────────────────────┘
                │ vmnet, the subnet's .1
     ┌──────────┼───────────┐
 ubuntu-1    debian-1    fedora-1        Tart VMs, one agent each
```

Ubuntu and Debian are both osapi's `debian` platform, so every behavior runs.
Fedora is outside osapi's supported list, so `deploy` sets osapi's
`IGNORE_LINUX` override on it: it runs the generic Linux providers and skips the
rest. A Mac agent skips nearly everything but facts, load, memory and disk.

### Set up the hub, once

On the Mac that will be the hub, in a terminal (the firewall step asks for
sudo):

```bash
brew install cirruslabs/cli/tart
cp lab.env.example lab.env   # set LAB_HUB_ADDR to this Mac's tailnet name
just hub-build secrets images hub-install up deploy
```

### Set up your machine, once

In your own clone of this repository:

```bash
cp lab.env.example lab.env   # set LAB_HUB_SSH, LAB_HUB_ADDR, LAB_OSAPI_DIR
direnv allow
just remote-client           # the lab's client config, for `osapi` here
just push                    # your osapi checkout, built and running everywhere
```

Machine names live only in `lab.env`, which is gitignored. `.envrc` loads it,
puts `.lab/bin` on `PATH` as `osapi` and points it at the lab.

### Day to day

Everything runs from your machine, in this directory.

| You want to                       | Run                                                   |
| --------------------------------- | ----------------------------------------------------- |
| Look at the lab                   | `osapi client agent list`                             |
| Run your osapi changes everywhere | `just push` (asks for sudo)                           |
| Only build them here              | `just build`                                          |
| Restart the hub and every agent   | `just restart` (asks for sudo)                        |
| Run any hub recipe from here      | `just hub <recipes>`, e.g. `just hub ips`             |
| Shell into a VM                   | `just hub ssh ubuntu-1`                               |
| Follow the hub's logs             | `just hub hub-logs`                                   |
| Add a VM                          | a line in [`nodes`](nodes), then `just hub up deploy` |
| Stop or start the VMs             | `just hub down`, `just hub up`                        |
| Run your machine as an agent too  | `just remote-agent`                                   |

`push` is `build`, `copy` and `restart`. `build` compiles whatever
`LAB_OSAPI_DIR` holds, branch and uncommitted changes included, for darwin and
linux. `restart` asks for sudo because the hub's firewall has to admit each new
build: macOS knows an unsigned binary by its signature, and every build has a
new one.

A change to this repository reaches the hub with `git pull` there. After a
change to `config/` or `launchd/`, run `just hub hub-install deploy`; after a
change to `packer/`, `just hub images destroy up deploy`. `just` alone lists
every recipe.

## What lives where

| Path                   | What it is                                                     |
| ---------------------- | -------------------------------------------------------------- |
| `nodes`                | The VMs: a name and the image each is cloned from              |
| `packer/`              | The base images. OS preparation only, no osapi, no secrets     |
| `config/`              | Templates for the hub's and the agents' osapi config           |
| `launchd/`             | The template for the hub's two launchd jobs                    |
| `scripts/render`       | Fills a template's `${NAME}` placeholders from the environment |
| `.lab/` (gitignored)   | Builds, rendered configs, secrets, the SSH key, logs, NATS     |
| `lab.env` (gitignored) | Per-machine settings, from `lab.env.example`                   |

Secrets never enter an image or the repository. `just secrets` writes them to
`.lab/secrets.env` on the hub, and `just deploy` renders each VM's config from
them. An agent's config carries a throwaway signing key rather than the hub's,
because osapi validates every key in the file whatever the command.

## Contributing

See the [Contributing](CONTRIBUTING.md) guide for prerequisites, the PR
workflow, and how a change is checked.

## License

The [MIT] License.

[mit]: LICENSE
[tart]: https://tart.run
