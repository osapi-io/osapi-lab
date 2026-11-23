<p align="center">
  <picture>
    <source srcset="asset/logo-dark.svg" media="(prefers-color-scheme: dark)">
    <source srcset="asset/logo-light.svg" media="(prefers-color-scheme: light)">
    <img src="asset/logo-dark.svg" alt="osapi-lab" width="496">
  </picture>
</p>

<p align="center">A small fleet of real machines to run osapi on.</p>

<p align="center">
  <a href="https://github.com/osapi-io/osapi-lab/actions/workflows/ansible-lint.yml"><img alt="ansible lint" src="https://img.shields.io/github/actions/workflow/status/osapi-io/osapi-lab/ansible-lint.yml?branch=main&style=for-the-badge&label=ansible%20lint"></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-MIT-brightgreen.svg?style=for-the-badge"></a>
  <a href="https://conventionalcommits.org"><img alt="conventional commits" src="https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg?style=for-the-badge"></a>
  <a href="https://just.systems"><img alt="built with just" src="https://img.shields.io/badge/Built_with-Just-black?style=for-the-badge&logo=just&logoColor=white"></a>
  <img alt="github commit activity" src="https://img.shields.io/github/commit-activity/m/osapi-io/osapi-lab?style=for-the-badge">
</p>

<p align="center">
<b>One Mac, some Linux VMs, and your osapi branch on all of them.</b>
</p>

<p align="center">
Ansible builds your osapi checkout. Packer bakes one Tart image for each VM: the
build, its config and each package. Then Ansible clones the VMs from these
images. Nothing configures a VM after it boots. You do all of it from your own
machine.
</p>

## 🚀 Usage

A Mac is the hub. The hub runs the NATS server and the controller of osapi. It
also runs one Tart VM for each Linux distribution. Each VM runs an agent. Your
machine builds osapi and controls all the other machines over SSH. The hub does
not need a checkout of this repository.

```
            Mac (hub)                        your machine
   ┌──────────────────────────┐           ┌──────────────────────────┐
   │ osapi nats server :4222  │◄──────────│ Ansible, osapi client    │
   │ osapi controller  :8080  │           └──────────────────────────┘
   └────────────▲─────────────┘
                │
    ┌─────────┬─┴───────┬──────────┐
 ubuntu-1  debian-1  fedora-1  opensuse-1   Tart VMs, one agent each
```

To run the lab, see [Run the lab](CONTRIBUTING.md#run-the-lab). The
[design page](https://github.com/osapi-io/specs/blob/main/components/osapi-lab/README.md)
tells how the lab works and why it has this design.

## 🤝 Contributing

The [Contributing](CONTRIBUTING.md) guide tells how to run the lab, and how to
make and check a change to it.

## 📄 License

The [MIT] License.

[mit]: LICENSE
