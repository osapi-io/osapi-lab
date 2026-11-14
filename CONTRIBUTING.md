# Contributing

We welcome contributions to osapi-lab. Before you send a PR, read this document.
It tells how to make and check a change, and how to open a pull request.

## Before you start

- Read the [Code of Conduct](CODE_OF_CONDUCT.md). It applies to all work and all
  discussion in this repository.

- **Design docs.** The design of this repository is in
  [osapi-io/specs](https://github.com/osapi-io/specs) under
  `components/osapi-lab/`. Read it before you change the behaviour. When you
  change the behaviour, change the design doc too.

- **Check existing work.** Look for an open PR or an issue about the change that
  you want to make.

## Prerequisites

[mise](https://mise.jdx.dev) supplies `just`, `uv` and `packer` at the versions
that `.mise.toml` declares. [direnv](https://direnv.net) loads `.envrc`. To
check a change, you need a lab. [Running the lab](#running-the-lab) tells how to
make one.

### Claude Code

If you use [Claude Code] for development, install this plugin from the default
marketplace:

```
/plugin install commit-commands@claude-plugins-official
```

- **commit-commands.** It gives the `/commit` and `/commit-push-pr` slash
  commands. These commands follow the commit conventions of the project.

## Running the lab

You need a lab to check a change. The lab is also where osapi runs on real
machines before a release.

### Set up

The hub is a Mac on Apple Silicon with Remote Login on. On the hub, run:

```bash
brew install cirruslabs/cli/tart mise
```

On your machine, in this repository, run:

```bash
mise install                                           # just, uv, packer
cp ansible/inventory.example.yml ansible/inventory.yml # your hub and osapi checkout
direnv allow                                           # `osapi` here talks to the lab
just fetch site                                        # everything; asks for the hub's sudo password
```

`ansible/inventory.yml` is the only file that names your machines. Git ignores
it.

### Day to day

| You want to                                    | Run                                | Changes                |
| ---------------------------------------------- | ---------------------------------- | ---------------------- |
| See every VM, its image and its osapi build    | `just list`                        | nothing                |
| Read the hub's logs                            | `just logs`                        | nothing                |
| Talk to the lab                                | `osapi client agent list`          | nothing                |
| Look at the lab's NATS, as its `cli` user      | `nats stream ls`, `nats kv ls`     | nothing                |
| Look at the NATS server itself, as `sys`       | `nats-sys server report jetstream` | nothing                |
| Shell into a VM                                | `just ssh ubuntu-1`                | nothing                |
| See a request's trace, controller to agent     | http://127.0.0.1:16686 on the hub  | nothing                |
| Rebuild the fleet from your osapi changes      | `just push`                        | everything; asks sudo  |
| Copy your changes into the running VMs, faster | `just deploy`                      | hub and VMs; asks sudo |
| Bring the whole lab back in line with the repo | `just site`                        | everything; asks sudo  |
| Run this machine as an agent too               | `just agent`                       | this machine           |
| Remove the lab from the hub                    | `just teardown`                    | the hub; asks sudo     |

"Asks sudo" means that the recipe asks for the sudo password of the hub. The
firewall of the hub must admit each new build. If your osapi checkout changed,
`push` reclones every VM, and you lose all changes inside the VMs. If the
checkout did not change, `push` changes nothing. `just` with no arguments lists
every recipe, these recipes and all others.

### Reading `just list`

```
VM         STATE    ADDRESS         RUN BY   AGENT   IMAGE                  OSAPI
ubuntu-1   running  192.168.64.11   launchd  active  img-ubuntu-9f0db41f0   v0.2.1-…-9f0db41f0ab1

images on the hub: img-debian-9f0db41f0, img-fedora-9f0db41f0, img-ubuntu-9f0db41f0
last build here:   feat/behavior-registration@9f0db41f0 (tag 9f0db41f0)
```

A VM in good condition is `running`, `launchd` runs it, and its agent is
`active`. Its `IMAGE` ends in the tag of the last build here. Its `OSAPI`
version contains that commit. If they are different, use this table:

| You see                                   | It means                              | Run         |
| ----------------------------------------- | ------------------------------------- | ----------- |
| `IMAGE` tag older than the last build     | the VMs run an earlier build          | `just push` |
| Same `IMAGE`, `OSAPI` from another commit | a `deploy` ran since the last push    | `just push` |
| `RUN BY manual`, or `STATE absent`        | the VM is not under launchd, or gone  | `just site` |
| `AGENT` anything but `active`             | the agent is down; see the hub's logs | `just logs` |

## Making changes

The lab is Ansible under `ansible/`, and `just` runs it. The Packer templates
are under `packer/`. The
[design doc](https://github.com/osapi-io/specs/blob/main/components/osapi-lab/README.md)
tells how the parts work together. This section tells how to change them.

**Put behaviour in a role. A playbook only lists roles.** A role is the unit
that you use again. `packer`, `tart_vm`, `launchd` and `firewall` know nothing
about osapi. They get their inputs as variables. Each role declares these
variables with defaults in its `defaults/main.yml`. The osapi roles (`build`,
`secrets`, `hub`, `lab_vm`, `agent`, `client`) use the first group of roles. Put
a new role in the first group, unless it must know about osapi.

**You can run a role two times safely.** A task reports `changed` only when it
changed something. Thus the second run of a playbook reports `changed=0`.

**Only `ansible/inventory.yml` names machines. No committed file names them.**
If a person must give a value for a new setting, put the setting in
`inventory.example.yml` with a placeholder.

### Checking a change

`just test` runs all the checks:

- the format of the markdown and the justfiles
- the `production` profile of ansible-lint, which parses every playbook
- the format of the Packer templates

CI runs all the checks but the last one. CI has no Mac and no VMs, so also run
the change on a lab:

| You changed        | Run                              |
| ------------------ | -------------------------------- |
| `packer/`          | `just push`                      |
| a role or playbook | the playbook that uses it, twice |

The second run of a playbook must report `changed=0`. Then make sure that the
lab is in good condition, as [Reading `just list`](#reading-just-list) tells.
`just ansible-run <name> --check --diff` shows what a run will change, but it
changes nothing. In the PR, say what you ran.

Do not commit a file under `.lab/` or `ansible/inventory.yml`. They hold secrets
and machine names. Git ignores them.

## Before committing

```bash
just ready
just test
```

## Branching

Make a branch from `main` with the name `type/short-description`. The `type` is
the [Conventional Commits] type, for example `feat/rocky-image` or
`fix/deploy-ssh-stdin`.

## Commit messages

Follow [Conventional Commits] with the 50/72 rule:

- **Subject line**: 50 characters or fewer, a command, a capital letter at the
  start, no period at the end
- **Body**: wrap at 72 characters, with a blank line between the subject and the
  body
- **Format**: `type(scope): description`
- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

## Submitting a PR

- **Describe your changes.** Say what changed and why.
- **Say what you ran on a hub.** If nobody ran a recipe, nobody checked it.
- **Draft PRs.** Open work that is not complete as a draft. Start the discussion
  in a comment.

## AI usage

The [AI Usage Policy](AI_POLICY.md) applies to all contributions. Say which AI
tool you used. You must be able to tell what your change does without help from
AI tools.

## FAQ

> I want to contribute, where do I start?

We welcome all contributions, for example a typo fix, a new image or a new
recipe. You can also vote for issues, write comments on issues, or help answer
questions.

> I'm stuck, where can I get help?

If you have a question, open a [Discussion] on GitHub.

[claude code]: https://claude.ai/code
[conventional commits]: https://www.conventionalcommits.org
[discussion]: https://github.com/osapi-io/osapi-lab/discussions
