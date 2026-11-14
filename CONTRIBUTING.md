# Contributing

Contributions to osapi-lab are very welcome, but we ask that you read this
document before submitting a PR. It covers prerequisites, how a change is
checked, and the pull request workflow.

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

- **A Mac on Apple Silicon** to be the hub, with [Tart]:
  `brew install cirruslabs/cli/tart`.
- **[mise].** Supplies `just`, `packer` and `uv` at the versions `.mise.toml`
  declares: `mise install`.
- **An osapi checkout** on the hub, at `LAB_OSAPI_DIR` in `lab.env`.

### Claude Code

If you use [Claude Code] for development, install this plugin from the default
marketplace:

```
/plugin install commit-commands@claude-plugins-official
```

- **commit-commands.** provides `/commit` and `/commit-push-pr` slash commands
  that follow the project's commit conventions automatically.

## Making changes

`just test` checks formatting, which is all CI can run: it has no Mac and no
VMs. Everything else is checked on a running lab. [Usage](README.md#usage) sets
one up.

Get your change onto the hub with `git pull` there, then run, from your machine:

| You changed                        | Run                                          |
| ---------------------------------- | -------------------------------------------- |
| `packer/`                          | `just hub images <distro> destroy up deploy` |
| `config/agent.yaml`, `deploy`      | `just hub deploy`                            |
| `config/hub.yaml`, `launchd/`      | `just hub hub-install deploy`                |
| `config/client.yaml`               | `just hub render`, then `just remote-client` |
| `nodes`, `up`, `down`              | `just hub up ips`                            |
| `build`, `copy`, `restart`, `push` | `just push`                                  |

Then show `osapi client agent list` with every node `Ready`, and say in the PR
what you ran.

Never commit anything under `.lab/` or `lab.env`. They hold secrets and machine
names, and are gitignored.

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
[mise]: https://mise.jdx.dev
[tart]: https://tart.run
