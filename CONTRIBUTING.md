# Contributing

Thank you for your contribution to osapi-lab.

## Before you start

- Read the [Code of Conduct](CODE_OF_CONDUCT.md). It applies to all
  communication in this repository.
- **Design pages.** The design pages of this repository are in
  [osapi-io/specs](https://github.com/osapi-io/specs), under
  `components/osapi-lab/`. Read them before you change the behavior. When you
  change the behavior, change the design page in the same work. A design page in
  this repository becomes incorrect when the code changes. No check finds the
  difference.
- **Examine the work that exists.** Look for a pull request or an issue about
  the change. If you find one, use what it says in your work.
- **Backward compatibility.** Make sure that your change does not stop a program
  that uses osapi-lab. A change that keeps compatibility is more likely to
  merge. If your change cannot keep it, open an issue first. Then the
  maintainers can discuss the API change before you do the work.

## Prerequisites

Install the tools with [mise]:

```bash
mise install
```

- **[uv].** A Python package runner. `just md-fmt` uses it to run [mdformat].
  The Ansible recipes use it to install Ansible into `ansible/.venv`, at the
  versions that `ansible/uv.lock` pins. Git ignores `ansible/.venv`.
- **[just].** The task runner. Use it to build, test and format.
- **[Packer].** It builds the Tart images of the VMs. `just test` checks the
  format of the templates.
- **[nsc].** The NATS of the lab runs in operator (JWT) mode. `nsc` makes its
  operator, its accounts and its users.
- **[nats CLI].** It examines the NATS of the lab. `.envrc` gives it the address
  of the NATS of the lab, and its credentials.

mise does not supply [direnv]. Install it yourself. direnv loads `.envrc`. Then,
in this directory, `osapi` and `nats` send their requests to the lab.

To check a change, you need a lab. [Run the lab](#run-the-lab) tells how to make
one.

### Coding agents

This repository works with any coding agent that reads `AGENTS.md`. `CLAUDE.md`
only points to `AGENTS.md`. Prepare your agent as its documentation tells you.
This repository does not need a plugin or an extension.

## Run the lab

You need a lab to check a change. The lab is also where osapi runs on real
machines before a release.

### Make the lab

The hub is a Mac on Apple Silicon. Enable Remote Login on the hub. Then, on the
hub, run:

```bash
brew install cirruslabs/cli/tart mise
echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/osapi-lab
sudo chmod 0440 /etc/sudoers.d/osapi-lab
sudo visudo -cf /etc/sudoers.d/osapi-lab               # make sure that sudoers is correct
```

The lab must use sudo on the hub without a password, because the firewall of the
hub must admit each new build. Ansible runs a different command through sudo
each time. Thus a sudoers rule for one command is not sufficient. Make the rule
for the user that `ansible_user` in your inventory names.

On your machine, in this repository, run:

```bash
mise install                                           # just, uv, packer
cp ansible/inventory.example.yml ansible/inventory.yml # your hub and osapi checkout
direnv allow                                           # `osapi` here talks to the lab
just fetch site                                        # everything
```

`ansible/inventory.yml` is the only file that names your machines. Git ignores
it.

### Day to day

| You want to                                     | Run                                | Changes      |
| ----------------------------------------------- | ---------------------------------- | ------------ |
| See every VM, its image and its osapi build     | `just list`                        | nothing      |
| Read the logs of the hub                        | `just logs`                        | nothing      |
| Send a request to the lab                       | `osapi client agent list`          | nothing      |
| Examine the NATS of the lab, as its `cli` user  | `nats stream ls`, `nats kv ls`     | nothing      |
| Examine the NATS server, as `sys`               | `nats-sys server report jetstream` | nothing      |
| Open a shell on a VM                            | `just ssh ubuntu-1`                | nothing      |
| See the trace of a request, controller to agent | `http://<lab_hub_addr>:16686`      | nothing      |
| Bring the lab to your checkout                  | `just deploy`                      | hub and VMs  |
| Put a new build into the running processes      | `just bump`                        | hub and VMs  |
| Bake each image again and replace each VM       | `just rebuild`                     | everything   |
| Restart the processes, with no build            | `just restart`                     | hub and VMs  |
| Stop processes and VMs, and start them again    | `just stop`, `just start`          | hub and VMs  |
| Run this machine as an agent too                | `just agent`                       | this machine |
| Remove the lab from the hub                     | `just teardown`                    | the hub      |

Do not keep work inside a VM. A VM is its image: `deploy` replaces a VM with a
clone of its new image when your osapi checkout or `packer/` changed, and
`rebuild` replaces each VM. You then lose all changes inside the VMs.

`debian-lts` is the exception. It has `upgrade_in_place: true` in
`ansible/group_vars/all.yml`. `deploy` does not replace it. `deploy` copies the
new linux build into it, restarts its agent, and waits until the agent is
`Ready`. The run fails if the agent does not come back. Thus `debian-lts` keeps
its machine ID, its consumers and its job history, as a host that an operator
upgrades. Its `IMAGE` in `just list` stays the image of its first clone, and its
`OSAPI` is the last build. `just rebuild` replaces it, and its history starts
again.

If the checkout and `packer/` did not change, `deploy` changes nothing. `just`
with no arguments lists all the recipes, not only these.

### Change one part of the lab

`deploy`, `bump`, `rebuild`, `restart`, `stop` and `start` each take targets.
With no target, a recipe does its work on each part of the lab. A target limits
it to that part:

| Target       | The part                                    |
| ------------ | ------------------------------------------- |
| `nats`       | the NATS server on the hub                  |
| `controller` | the controller on the hub, with the API     |
| `ui`         | the controller, because osapi embeds the UI |
| `jaeger`     | the trace collector on the hub              |
| `hub`        | `nats`, `controller` and `jaeger`           |
| `vms`        | each VM                                     |
| a VM's name  | that VM, such as `ubuntu-1` or `debian-lts` |
| `client`     | the configs on this machine                 |

For example:

```sh
just deploy ui                  # builds darwin, restarts the controller only
just bump ubuntu-1 fedora-1     # the new build into two VMs
just rebuild debian-lts         # a new image and a new clone of debian-lts
just restart nats               # restarts NATS, and waits for each agent
just stop fedora-1              # stops the VM; launchd does not start it again
just start fedora-1             # starts it again, and waits for its agent
```

A run on a part changes only that part. A process on the hub restarts only when
it is a target and its binary, its config, its certificate or its credentials
changed, or in a `restart`. A run on the hub waits until each agent is `Ready`
again. The build compiles linux only when the run reaches a VM, so a `deploy ui`
takes about 30 seconds.

`ansible/playbooks/lab.yml` does each of these. A recipe gives it the mode, the
VMs in `lab_only` and the parts as tags. An argument that starts with `-` goes
to Ansible, such as `just deploy vms -e build_force=true`.

### One run at a time

Only one run can change the images and the VMs. `deploy`, `bump`, `rebuild`,
`restart`, `build` and `teardown` take a lock on the hub, `~/.osapi-lab/lock`,
and give it back when they end. A second run stops with the name of the run that
holds the lock: its machine, its process, its build and its start time. Two runs
at once delete each other's images (#38).

A run that stops before its end keeps the lock. The next run on the same machine
sees that the process is gone, and breaks the lock. A lock from a run on a
different machine stays. Make sure that no run is active, then break it:

```bash
just ansible-run deploy -e lab_lock_break=true
```

A run that deletes the images of a different build also keeps each image that a
build recorded in the last hour.

### Read `just list`

```
VM         STATE    ADDRESS         RUN BY   AGENT   IMAGE                  OSAPI
ubuntu-1   running  192.168.64.11   launchd  active  img-ubuntu-1-9f0db41f0 v0.2.1-…-9f0db41f0ab1

images on the hub: img-debian-1-9f0db41f0, img-fedora-1-9f0db41f0, img-ubuntu-1-9f0db41f0
last build here:   feat/behavior-registration@9f0db41f0 (tag 9f0db41f0)
```

A VM in good condition has `STATE` `running`, `RUN BY` `launchd` and `AGENT`
`active`. Its `IMAGE` ends in the tag of the last build here. Its `OSAPI`
version contains that commit. If the values are different, find the row in this
table:

| You see                               | It means                                        | Run           |
| ------------------------------------- | ----------------------------------------------- | ------------- |
| `IMAGE` tag older than the last build | the VMs run an earlier build (not `debian-lts`) | `just deploy` |
| `RUN BY manual`, or `STATE absent`    | launchd does not run the VM, or the VM is gone  | `just deploy` |
| `AGENT` is not `active`               | the agent stopped; read the logs of the hub     | `just logs`   |

## Make a change

The lab is a set of Ansible roles and playbooks under `ansible/`. `just` runs
them. The Packer templates are under `packer/`. The
[design page](https://github.com/osapi-io/specs/blob/main/components/osapi-lab/README.md)
tells how the parts work together. This section tells how to change them.

**Configure a VM in its image, not after it boots.** `packer/lab.pkr.hcl` builds
one image for each VM with the provisioners of Packer: `file` copies each file
in, and `shell` runs short `inline` steps. `templatefile()` renders the config
of the agent from `packer/agent.yaml.pkrtpl.hcl`. A difference between
distributions is a map in `locals`, not a `case` in a script. Ansible makes only
what must exist outside the image, the NATS user of each VM, and passes its
credential to the build in `PKR_VAR_nats_creds`. Then it clones the VMs. Nothing
logs in to a running VM to change it.

**Pull a base image if you can.** The images of Ubuntu, Debian and Fedora start
from the Tart images of Cirrus Labs. Cirrus Labs publishes no openSUSE image.
Thus `packer/bases/opensuse` has the source of a base that the hub makes: the
URL and the checksum of the official qcow2 cloud image of openSUSE, and a
cloud-init seed. The `tart_base` role downloads the image, writes it as the raw
disk of a Tart VM, and boots it one time with the seed. The seed makes the
`admin` account and stops the VM. A change to a file in that directory makes a
new base, and the images that use it bake again.

**Put behavior in a role. A playbook only lists roles.** A role is the unit that
you use again. The general roles are `packer`, `tart_vm`, `tart_base`, `launchd`
and `firewall`. They know nothing about osapi. They get their inputs as
variables. Each role declares these variables with defaults in its
`defaults/main.yml`. The osapi roles (`build`, `secrets`, `hub`, `lab_vm`,
`client`) use the general roles. Make a new role a general role, unless it must
know about osapi.

**Make each role safe to run two times.** A task reports `changed` only when it
changed something. Thus the second run of a playbook reports `changed=0`.

**Only `ansible/inventory.yml` names machines. No committed file names them.**
If a person must give a value for a new setting, put the setting in
`inventory.example.yml` with a placeholder.

### Check a change

`just test` runs all the checks:

- the format of the markdown and the justfiles
- the `production` profile of ansible-lint, which parses every playbook
- the format of the Packer templates

CI runs all the checks except the format of the Packer templates. CI has no Mac
and no VMs. Thus also run the change on a lab:

| You changed        | Run                                               |
| ------------------ | ------------------------------------------------- |
| `packer/`          | `just deploy`, which bakes again                  |
| a role or playbook | `just deploy` with the target that uses it, twice |

The second run of a playbook must report `changed=0`. Then make sure that the
lab is in good condition. [Read `just list`](#read-just-list) tells how.
`just ansible-run <name> --check --diff` shows what a run will change. It
changes nothing. In the pull request, tell what you ran.

Do not commit a file under `.lab/` or `ansible/inventory.yml`. They hold secrets
and machine names. Git ignores them.

### Documentation

[mdformat] formats the markdown files, through `uvx`. CI makes sure that the
format is correct.

```bash
just md-fmt-check   # Check formatting
just md-fmt         # Auto-fix formatting
```

Write each page in Simplified Technical English, as
[the osapi-io constitution](https://github.com/osapi-io/specs/blob/main/CONSTITUTION.md)
requires.

## Before you commit

Run `just ready` before you commit. It formats the markdown, the justfiles, the
roles and playbooks, and the Packer templates. Then run `just test`:

```bash
just ready
just test
```

## Branches

Make all changes on a branch. Make the branch from `main`. Give it the name
`type/short-description`, where `type` is the [Conventional Commits] type:

- `feat/add-retry-logic`
- `fix/null-pointer-crash`
- `docs/update-api-reference`
- `refactor/simplify-handler`
- `chore/update-dependencies`

## Commit messages

Use [Conventional Commits] with the 50/72 rule:

- **Subject line.** 50 characters or fewer, in the imperative mood, with no
  period at the end.
- **Body.** Wrap it at 72 characters. Put a blank line between the subject and
  the body.
- **Format.** `type(scope): description`.
- **Types.** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `chore`.
- Tell what changed and why, not how.

Write commit messages that help the reader. Keep the number of commits in a pull
request small. Most pull requests have one commit. A large pull request can have
a few. Use squash and rebase to combine commits.

## Submit a pull request

- **Describe your changes.** Tell what changed and why. Then a reviewer does not
  have to read the diff to find the reason.
- **Links to issues and pull requests.** Link to related issues and pull
  requests. Tell how your change is different from that work, or how it adds to
  it.
- **What you ran on a hub.** Tell which recipes you ran on a hub. If nobody ran
  a recipe, nobody checked it.
- **Examples.** Add examples or screenshots that show the effect of your change.
- **Draft pull requests.** If your change is not complete but you want to
  discuss it, open the pull request as a draft. Start the discussion in a
  comment, not in the description. Then you can change the description later and
  keep the discussion.

## AI usage

We write this repository with the help of AI tools. The
[AI Usage Policy](AI_POLICY.md) applies to all contributions. Tell which tool
you used. Make sure that you can explain what your change does without the help
of an AI tool.

## FAQ

> I want to contribute. Where do I start?

All contributions are welcome, from a typo fix to a new feature. You can also
vote or comment on issues, or help answer questions.

> I need help. Where do I ask?

Open a [Discussion] on GitHub.

[conventional commits]: https://www.conventionalcommits.org
[direnv]: https://direnv.net
[discussion]: https://github.com/osapi-io/osapi-lab/discussions
[just]: https://just.systems
[mdformat]: https://pypi.org/project/mdformat/
[mise]: https://mise.jdx.dev
[nats cli]: https://github.com/nats-io/natscli
[nsc]: https://github.com/nats-io/nsc
[packer]: https://developer.hashicorp.com/packer
[uv]: https://docs.astral.sh/uv/
