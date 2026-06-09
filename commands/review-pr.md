---
description: Code review focused on correctness and security (current branch, a PR number, or a pasted diff)
argument-hint: [PR number | empty for current branch]
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git merge-base:*), Bash(gh pr diff:*), Bash(gh pr view:*)
---

Review a diff for **correctness and security**.

## What to review
- If **$ARGUMENTS** is a PR number: `gh pr diff $ARGUMENTS` (and `gh pr view $ARGUMENTS` for context).
- If **$ARGUMENTS** is empty: review the current branch — `git diff $(git merge-base HEAD origin/main)...HEAD`. If that's empty, fall back to `git diff` (uncommitted changes).
- If a diff is pasted below, review that instead.

## Focus
1. **Correctness bugs** — logic errors, off-by-one, unhandled edge cases, race conditions
2. **Security issues** — injection, auth bypass, secret exposure, OWASP Top 10
3. **Simplification** — unnecessary abstraction, duplicated logic, dead code

Do not comment on style, formatting, or naming unless it causes actual confusion.

For each finding: file + line, what's wrong, exact fix or suggested rewrite. If nothing
is wrong, say so plainly — don't manufacture findings.
