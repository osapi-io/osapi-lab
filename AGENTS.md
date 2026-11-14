# AGENTS.md

Read @CONTRIBUTING.md first. Its "Running the lab" section says what each recipe
does and what it changes; the rest covers how a change is made and checked, and
the pull request workflow. All of it applies to agents exactly as it applies to
people. This file carries only what is specific to agents.

## Running tools

Invoke tools through `mise`, not from your path:

```bash
mise exec -- just
```

`mise` is active in a person's shell and supplies the versions `.mise.toml`
declares. An agent's shell has no activation, so a bare `just` resolves to
whatever is installed globally, usually an older version.

`just` with no arguments lists every recipe with its description, straight from
the justfile, so it is current where prose may not be. Run it to discover what
exists; CONTRIBUTING says when to use which.

Run Ansible only through `just`, never `ansible-playbook` from the path. The
recipes run it through `uv`, so the version is the one `ansible/uv.lock` pins.

## The lab is real machines

Start with a recipe CONTRIBUTING marks as changing nothing. A recipe that asks
for the hub's sudo password is the person's to run: hand it over rather than
working around the prompt.

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
