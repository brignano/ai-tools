# Prompt — Review Docker Compose file

Review the following Docker Compose file for:

1. **Security issues** — ports exposed to 0.0.0.0, secrets in environment variables (vs. files/secrets), privileged mode without justification, world-writable volume mounts
2. **Reliability issues** — missing restart policy, no healthcheck on stateful services, volumes that would lose data on container removal
3. **Correctness** — image pinned to `latest` (flag it but don't force a change), dependency ordering, network isolation
4. **Conventions** — does it follow the pattern: named volumes, `127.0.0.1` port binding, `${VAR:?required}` for secrets?

For each finding: state the line/field, what the issue is, and the exact fix.

---

```yaml
# paste compose file here
```
