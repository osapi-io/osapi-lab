# AGENTS.md

Read @CONTRIBUTING.md first. Its "Run the lab" section tells what each recipe
does and what it changes. The other sections tell how to make and check a
change, and how to open a pull request. All of it applies to agents the same as
to people. This file holds only the rules that are specific to agents.

## Run the tools

Run tools through `mise`, not from your path:

```bash
mise exec -- just
```

`mise` is active in the shell of a person and supplies the versions that
`.mise.toml` declares. The shell of an agent has no activation. Thus a bare
`just` uses the version that is installed globally, which is usually older.

`just` with no arguments lists every recipe with its description. The list comes
from the justfile, so it is current where the prose can be out of date.
CONTRIBUTING tells when to use each recipe.

Run `just` to find the recipes.

Run Ansible only through `just`. Do not run `ansible-playbook` from the path.
The recipes run Ansible through `uv`, so the version is the one that
`ansible/uv.lock` pins.

## The lab is real machines

Start with a recipe that CONTRIBUTING marks as one that changes nothing. If a
recipe asks for the sudo password of the hub, give that recipe to the person to
run. Do not try to bypass the prompt.

## Never print secrets

Do not cat the files in `.lab/secrets/`, `.lab/ssh/` and `.lab/config/`. Do not
copy them into output, issues or pull requests. They hold the NATS password, the
JWT signing key, an admin token and the SSH key of the VMs.

Before you commit, make sure that no committed file holds a hostname, a tailnet
address or a home path. Only `ansible/inventory.yml` holds machine names, and
git ignores that file.

## Where the rules come from

@CONTRIBUTING.md names the specification under "Before you start". If a
convention here and the specification do not agree, the specification is
correct. Say so. Do not follow the code.

## Commit trailer

When you commit through Claude Code, end the message with:

```
🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Design pages

**The design is in the design pages.** Write or change the page in
[osapi-io/specs](https://github.com/osapi-io/specs) before you build. Correct
the page where the build shows that it is wrong.

A design page in this repository becomes out of date when the code changes. No
check finds the difference.
