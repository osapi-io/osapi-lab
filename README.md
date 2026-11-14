<p align="center">
  <picture>
    <source srcset="asset/logo-dark.svg" media="(prefers-color-scheme: dark)">
    <source srcset="asset/logo-light.svg" media="(prefers-color-scheme: light)">
    <img src="asset/logo-dark.svg" alt="osapi-lab" width="496">
  </picture>
</p>

<p align="center">A small fleet of real machines to run osapi against.</p>

<p align="center">
  <a href="https://github.com/osapi-io/osapi-lab/actions/workflows/ansible-lint.yml"><img alt="ansible lint" src="https://img.shields.io/github/actions/workflow/status/osapi-io/osapi-lab/ansible-lint.yml?branch=main&style=for-the-badge&label=ansible%20lint"></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-MIT-brightgreen.svg?style=for-the-badge"></a>
  <a href="https://conventionalcommits.org"><img alt="conventional commits" src="https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg?style=for-the-badge"></a>
  <a href="https://just.systems"><img alt="built with just" src="https://img.shields.io/badge/Built_with-Just-black?style=for-the-badge&logo=just&logoColor=white"></a>
  <img alt="github commit activity" src="https://img.shields.io/github/commit-activity/m/osapi-io/osapi-lab?style=for-the-badge">
</p>

<p align="center">
<b>One Mac, a few Linux VMs, and your osapi branch running on all of them.</b>
</p>

<p align="center">
Ansible builds your osapi checkout, bakes it into Tart images with Packer, and
rebuilds the fleet from them, all from your own machine.
</p>

## Usage

A Mac is the hub: it runs osapi's NATS server and controller, and a Tart VM per
Linux distribution, each running an agent. Your machine builds osapi and drives
everything over SSH; the hub needs no checkout of this repository.

```
            Mac (hub)                        your machine
   ┌──────────────────────────┐           ┌──────────────────────────┐
   │ osapi nats server :4222  │◄──────────│ just push, osapi client  │
   │ osapi controller  :8080  │           └──────────────────────────┘
   └────────────▲─────────────┘
                │
     ┌──────────┼───────────┐
 ubuntu-1    debian-1    fedora-1        Tart VMs, one agent each
```

### Set up

On the hub, a Mac on Apple Silicon, with Remote Login on:

```bash
brew install cirruslabs/cli/tart mise
```

On your machine, in this repository:

```bash
mise install                                           # just, uv, packer
cp ansible/inventory.example.yml ansible/inventory.yml # your hub and osapi checkout
direnv allow                                           # `osapi` here talks to the lab
just fetch site                                        # everything; asks for the hub's sudo password
```

`ansible/inventory.yml` is gitignored and is the only file that names your
machines.

### Day to day

| You want to                                    | Run                       |
| ---------------------------------------------- | ------------------------- |
| See every VM, its image and its osapi build    | `just list`               |
| Rebuild the fleet from your osapi changes      | `just push`               |
| Copy your changes into the running VMs, faster | `just deploy`             |
| Talk to the lab                                | `osapi client agent list` |
| Shell into a VM                                | `just ssh ubuntu-1`       |
| Read the hub's logs                            | `just logs`               |
| Run this machine as an agent too               | `just agent`              |

`push`, `deploy` and `site` ask for the hub's sudo password: the hub's firewall
has to admit each new build. `just` alone lists every recipe.

How it works, and why it is built this way, is in the
[design doc](https://github.com/osapi-io/specs/blob/main/components/osapi-lab/README.md).

## Contributing

See the [Contributing](CONTRIBUTING.md) guide for how a change to the lab is
made and checked.

## License

The [MIT] License.

[mit]: LICENSE
