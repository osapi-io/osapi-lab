# AGENTS.md

Test: `just test` | Fix formatting: `just ready` | Look at the lab: `just list`

Read @CONTRIBUTING.md first. It covers how a change is made and checked, and the
pull request workflow, all of which apply to agents exactly as they apply to
people. This file carries only what is specific to agents.

## Running tools

Invoke tools through `mise`, not from your path:

```bash
mise exec -- just list
```

`mise` is active in a person's shell and supplies the versions `.mise.toml`
declares. An agent's shell has no activation, so a bare `just` resolves to
whatever is installed globally, usually an older version.

Run Ansible only through `just`: a lab recipe, or `just ansible-run <playbook>`
for any playbook under `ansible/playbooks/`. Both run it through `uv` from
`ansible/`, so the version is the one `ansible/uv.lock` pins. Never call
`ansible-playbook` from the path.

## The lab is real machines

`just list` reads the lab and changes nothing; start there. Every other recipe
changes the hub or the VMs, and `push` reclones every VM.

`push`, `deploy` and `site` stop for the person's sudo password on the hub. Hand
those runs to the person rather than working around the prompt.

## Never print secrets

`.lab/secrets/`, `.lab/ssh/` and `.lab/config/` hold the NATS password, the JWT
signing key, an admin token and the VMs' SSH key. Do not cat, copy or paste them
into output, issues or PRs.

Machine names live only in `ansible/inventory.yml`, which is gitignored. Before
committing, check no hostname, tailnet address or home path entered a committed
file.

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
