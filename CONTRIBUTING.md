# Contributing

Contributions to osapi-lab are very welcome, but we ask that you read this
document before submitting a PR. It covers how a change is made and checked, and
the pull request workflow.

## Before you start

- Read the [Code of Conduct](CODE_OF_CONDUCT.md). It applies to every
  interaction in this repo.

- **Design docs.** How this repository is built is documented in
  [osapi-io/specs](https://github.com/osapi-io/specs) under
  `components/osapi-lab/`. Read it before changing behaviour, and change it when
  you do.

- **Check existing work.** Is there an existing PR? Are there issues discussing
  the change you want to make?

## Prerequisites

[mise](https://mise.jdx.dev) supplies `just`, `uv` and `packer` at the versions
`.mise.toml` declares, and [direnv](https://direnv.net) loads `.envrc`. A lab to
check a change on is set up as [Running the lab](#running-the-lab) describes.

### Claude Code

If you use [Claude Code] for development, install this plugin from the default
marketplace:

```
/plugin install commit-commands@claude-plugins-official
```

- **commit-commands.** provides `/commit` and `/commit-push-pr` slash commands
  that follow the project's commit conventions automatically.

## Running the lab

You need one to check a change on, and it is how osapi gets run on real machines
before a release.

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

| You want to                                    | Run                       | Changes                |
| ---------------------------------------------- | ------------------------- | ---------------------- |
| See every VM, its image and its osapi build    | `just list`               | nothing                |
| Read the hub's logs                            | `just logs`               | nothing                |
| Talk to the lab                                | `osapi client agent list` | nothing                |
| Shell into a VM                                | `just ssh ubuntu-1`       | nothing                |
| Rebuild the fleet from your osapi changes      | `just push`               | everything; asks sudo  |
| Copy your changes into the running VMs, faster | `just deploy`             | hub and VMs; asks sudo |
| Bring the whole lab back in line with the repo | `just site`               | everything; asks sudo  |
| Run this machine as an agent too               | `just agent`              | this machine           |

"Asks sudo" is the hub's sudo password: its firewall has to admit each new
build. `push` also reclones every VM, so anything changed inside one is lost.
`just` alone lists every recipe, these and the rest.

### Reading `just list`

```
VM         STATE    ADDRESS         RUN BY   AGENT   IMAGE                  OSAPI
ubuntu-1   running  192.168.64.11   launchd  active  img-ubuntu-9f0db41f0   v0.2.1-…-9f0db41f0ab1

images on the hub: img-debian-9f0db41f0, img-fedora-9f0db41f0, img-ubuntu-9f0db41f0
last build here:   feat/behavior-registration@9f0db41f0 (tag 9f0db41f0)
```

A healthy VM is `running`, run by `launchd`, with an `active` agent. Its `IMAGE`
ends in the tag of the last build here, and its `OSAPI` version carries that
commit. When they differ:

| You see                                   | It means                              | Run         |
| ----------------------------------------- | ------------------------------------- | ----------- |
| `IMAGE` tag older than the last build     | the VMs run an earlier build          | `just push` |
| Same `IMAGE`, `OSAPI` from another commit | a `deploy` ran since the last push    | `just push` |
| `RUN BY manual`, or `STATE absent`        | the VM is not under launchd, or gone  | `just site` |
| `AGENT` anything but `active`             | the agent is down; see the hub's logs | `just logs` |

## Making changes

The lab is Ansible under `ansible/`, run through `just`, with Packer templates
under `packer/`. The
[design doc](https://github.com/osapi-io/specs/blob/main/components/osapi-lab/README.md)
says how the pieces fit; this section says how to change them.

**Behaviour goes in a role; a playbook only lists roles.** Roles are the unit
that gets reused. `packer`, `tart_vm`, `launchd` and `firewall` know nothing
about osapi: they take their inputs as variables, declared with defaults in
their `defaults/main.yml`. The osapi roles (`build`, `secrets`, `hub`, `lab_vm`,
`agent`, `client`) compose them. Keep a new role in the first group unless it
has to know about osapi.

**A role is safe to run twice.** Every task reports `changed` only when it
changed something, so a second run of any playbook reports `changed=0`.

**`ansible/inventory.yml` names machines; nothing committed does.** A new
setting a person has to fill in goes in `inventory.example.yml` with a
placeholder.

### Checking a change

`just test` runs every check: markdown and justfile formatting, ansible-lint's
`production` profile (which parses every playbook), and Packer formatting. CI
runs all but the last. It has no Mac and no VMs, so a change is also run on a
lab:

| You changed        | Run                              |
| ------------------ | -------------------------------- |
| `packer/`          | `just push`                      |
| a role or playbook | the playbook that uses it, twice |

The second run of a playbook should report `changed=0`. Then check the lab is
healthy, as [Reading `just list`](#reading-just-list) describes.
`just ansible-run <name> --check --diff` shows what a run would change without
changing it. Say in the PR what you ran.

Never commit anything under `.lab/` or `ansible/inventory.yml`. They hold
secrets and machine names, and are gitignored.

## Before committing

```bash
just ready
just test
```

## Branching

Create a branch from `main` named `type/short-description`, where `type` matches
the [Conventional Commits] type: `feat/rocky-image`, `fix/deploy-ssh-stdin`.

## Commit messages

Follow [Conventional Commits] with the 50/72 rule:

- **Subject line**: max 50 characters, imperative mood, capitalized, no period
- **Body**: wrap at 72 characters, separated from subject by a blank line
- **Format**: `type(scope): description`
- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

## Submitting a PR

- **Describe your changes.** Say what changed and why.
- **Say what you ran on a hub.** A recipe nobody ran has not been checked.
- **Draft PRs.** Open incomplete work as a draft and start the discussion in a
  comment.

## AI usage

All contributions are subject to the [AI Usage Policy](AI_POLICY.md). Disclose
the tool you used, and make sure you can explain what your change does without
the aid of AI tools.

## FAQ

> I want to contribute, where do I start?

All kinds of contributions are welcome, whether it's a typo fix or a new image
or recipe. You can also contribute by upvoting/commenting on issues or helping
to answer questions.

> I'm stuck, where can I get help?

If you have questions, open a [Discussion] on GitHub.

[claude code]: https://claude.ai/code
[conventional commits]: https://www.conventionalcommits.org
[discussion]: https://github.com/osapi-io/osapi-lab/discussions
