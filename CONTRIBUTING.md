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

A lab to check your change on, set up as the README's [Set up](README.md#set-up)
describes.

### Claude Code

If you use [Claude Code] for development, install this plugin from the default
marketplace:

```
/plugin install commit-commands@claude-plugins-official
```

- **commit-commands.** provides `/commit` and `/commit-push-pr` slash commands
  that follow the project's commit conventions automatically.

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
| anything           | `just list` afterwards           |

The second run of a playbook should report `changed=0`.
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
