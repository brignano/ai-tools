---
description: Security and reliability audit of a Docker Compose file
argument-hint: [path to compose file, or paste below]
allowed-tools: Read, Bash(cat:*)
---

If **$ARGUMENTS** is a file path, read that compose file. Otherwise review the file pasted below.

Review for:

1. **Security issues** — ports exposed to 0.0.0.0, secrets in environment variables (vs. files/secrets), privileged mode without justification, world-writable volume mounts
2. **Reliability issues** — missing restart policy, no healthcheck on stateful services, volumes that would lose data on container removal
3. **Correctness** — image pinned to `latest` (flag it but don't force a change), dependency ordering, network isolation
4. **Conventions** — does it follow the pattern: named volumes, `127.0.0.1` port binding, sensitive values via Docker secrets / mounted secret files (with `${VAR:?required}` env vars reserved for non-sensitive config)?

For each finding: state the line/field, what the issue is, and the exact fix.

---

```yaml
# paste compose file here
```
