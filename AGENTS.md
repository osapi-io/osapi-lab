# AGENTS.md

Test: `just test` | Fix formatting: `just ready`

Read @CONTRIBUTING.md first. It covers prerequisites, how a change is checked,
and the pull request workflow, all of which apply to agents exactly as they
apply to people. This file carries only what is specific to agents.

## Running tools

Invoke tools through `mise`, not from your path:

```bash
mise exec -- just test
```

`mise` is active in a person's shell and supplies the versions `.mise.toml`
declares. An agent's shell has no activation, so a bare `just` resolves to
whatever is installed globally, usually an older version.

## The hub is another machine

Images, VMs and the hub's launchd jobs exist only on the hub. From any other
machine, run hub recipes through `just hub`, which carries the SSH, `PATH` and
directory:

```bash
mise exec -- just hub ips
```

`firewall`, and so `hub-install`, `hub-restart`, `restart` and `push`, can ask
for sudo on the hub. Without a terminal it stops with "needs sudo" rather than
hanging. Hand that step to the person rather than working around it.

## A change is checked on a running lab

`just test` checks formatting only.
[Making changes](CONTRIBUTING.md#making-changes) says what to run for each kind
of change. Show `osapi client agent list` afterwards and say in the PR what you
ran.

Machine names come from `lab.env`, never from a committed file. Before
committing, check that no hostname, tailnet address or home path entered one.

## Never print secrets

`.lab/secrets.env`, `.lab/config/` and `.lab/ssh/` hold the NATS password, the
JWT signing key, an admin token and the VMs' SSH key. Do not cat, copy or paste
them into output, issues or PRs.

## Where the rules come from

@CONTRIBUTING.md names the specification under "Before you start". When a
convention here and the specification disagree, the specification wins. Say so
rather than following the code.

## Commit trailer

When committing via Claude Code, end the message with:

```
🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Task tracking

**Design happens in the design docs.** Write or change the page in
[osapi-io/specs](https://github.com/osapi-io/specs) before building, and correct
it where building proves it wrong. A design document kept in this repository
goes stale the moment the code moves past it, and nothing catches the drift.
