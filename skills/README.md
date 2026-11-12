# skills/

Personal skills, shipped in the `fleet` plugin to every machine and every cloud
project (see the root README). Each skill is
a directory:

```
skills/<name>/
  SKILL.md        # required — frontmatter + instructions
  ...             # optional: scripts, templates, reference files it points to
```

```markdown
---
name: <name>
description: What it does and when to use it. Claude reads only this line until
  the skill is needed, so name the tasks and files that should trigger it.
---

# <Name>

The instructions, loaded when a task matches the description.
```

On my devices the plugin loads from the checkout, so a file added to a skill
arrives with a plain `git pull`; cloud sessions get it in the next thread, since
they install the plugin from `main` at start. A directory with no `SKILL.md` is ignored.

## What goes here, and what doesn't

A skill belongs here when you'd want it in **every repo on every machine**. If it
names a path, host or service in one repo, it belongs in that repo's
`.claude/skills/` instead, where a clone or a cloud session gets it for free —
`homelab/.claude/skills/` is the worked example.

A skill beats a line in `AGENTS.md` when the rule matters for **some** tasks:
`AGENTS.md` is loaded into every session, a skill only when its description
matches. Something that has to hold in every session stays in `AGENTS.md`.
