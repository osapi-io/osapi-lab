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
- **[nats CLI].** It examines the NATS of the lab. `.envrc` points it at the
  hub.

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

| You want to                                     | Run                                | Changes                    |
| ----------------------------------------------- | ---------------------------------- | -------------------------- |
| See every VM, its image and its osapi build     | `just list`                        | nothing                    |
| Read the logs of the hub                        | `just logs`                        | nothing                    |
| Send a request to the lab                       | `osapi client agent list`          | nothing                    |
| Examine the NATS of the lab, as its `cli` user  | `nats stream ls`, `nats kv ls`     | nothing                    |
| Examine the NATS server, as `sys`               | `nats-sys server report jetstream` | nothing                    |
| Open a shell on a VM                            | `just ssh ubuntu-1`                | nothing                    |
| See the trace of a request, controller to agent | `http://<lab_hub_addr>:16686`      | nothing                    |
| Rebuild the VMs from your osapi changes         | `just push`                        | everything; asks for sudo  |
| Copy your build into the VMs, without a rebuild | `just deploy`                      | hub and VMs; asks for sudo |
| Make the whole lab agree with this repository   | `just site`                        | everything; asks for sudo  |
| Run this machine as an agent too                | `just agent`                       | this machine               |
| Remove the lab from the hub                     | `just teardown`                    | the hub; asks for sudo     |

"Asks for sudo" means that the recipe asks for the sudo password of the hub. The
recipe needs it because the firewall of the hub must admit each new build.

Do not keep work inside a VM. If your osapi checkout changed, `push` clones each
VM again. You then lose all changes inside the VMs.

If the checkout did not change, `push` changes nothing. `just` with no arguments
lists all the recipes, not only these.

### Read `just list`

```
VM         STATE    ADDRESS         RUN BY   AGENT   IMAGE                  OSAPI
ubuntu-1   running  192.168.64.11   launchd  active  img-ubuntu-9f0db41f0   v0.2.1-…-9f0db41f0ab1

images on the hub: img-debian-9f0db41f0, img-fedora-9f0db41f0, img-ubuntu-9f0db41f0
last build here:   feat/behavior-registration@9f0db41f0 (tag 9f0db41f0)
```

A VM in good condition has `STATE` `running`, `RUN BY` `launchd` and `AGENT`
`active`. Its `IMAGE` ends in the tag of the last build here. Its `OSAPI`
version contains that commit. If the values are different, find the row in this
table:

| You see                                   | It means                                       | Run         |
| ----------------------------------------- | ---------------------------------------------- | ----------- |
| `IMAGE` tag older than the last build     | the VMs run an earlier build                   | `just push` |
| Same `IMAGE`, `OSAPI` from another commit | a `deploy` ran after the last push             | `just push` |
| `RUN BY manual`, or `STATE absent`        | launchd does not run the VM, or the VM is gone | `just site` |
| `AGENT` is not `active`                   | the agent stopped; read the logs of the hub    | `just logs` |

## Make a change

The lab is a set of Ansible roles and playbooks under `ansible/`. `just` runs
them. The Packer templates are under `packer/`. The
[design page](https://github.com/osapi-io/specs/blob/main/components/osapi-lab/README.md)
tells how the parts work together. This section tells how to change them.

**Put behavior in a role. A playbook only lists roles.** A role is the unit that
you use again. The general roles are `packer`, `tart_vm`, `launchd` and
`firewall`. They know nothing about osapi. They get their inputs as variables.
Each role declares these variables with defaults in its `defaults/main.yml`. The
osapi roles (`build`, `secrets`, `hub`, `lab_vm`, `agent`, `client`) use the
general roles. Make a new role a general role, unless it must know about osapi.

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

| You changed        | Run                              |
| ------------------ | -------------------------------- |
| `packer/`          | `just push`                      |
| a role or playbook | the playbook that uses it, twice |

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
