---
description: Hand work to another repo by filing a linked fleet-spec issue there
argument-hint: <owner/repo> <what is needed>
---

Hand off this work to another repo: **$ARGUMENTS**. Every repo is in the
Build project; this files the work as its own issue so it gets its own thread
and PR.

Load the `fleet-standard` skill and follow "Repos talk through issues" and
"An issue is a spec". Then:

1. Check that repo's open issues for one that already covers it. If one does,
   comment there with the new context instead of filing a duplicate.
2. Otherwise file one issue in that repo: the full spec shape (Problem,
   Acceptance criteria, How to verify, Decisions, Out of scope, Notes), a
   `From owner/repo#N` line naming where it came from (and add a link back to
   it on our issue, so the two are linked both ways), and labels: one `priority:`, `type:`, `size:` and `risk:` from fleet/labels.yml. Add
   `needs:anthony` only if a person must act first.
3. If our work waits on it: add `Blocked by owner/repo#N` to our issue or PR,
   add `blocked` to our issue, and keep this thread open.
4. Tell me in one line: "Filed owner/repo#N." Only if it is urgent, also tell
   the coordinator so it can start a thread for it now. Never point me at
   another project.

Never put personal topics in the issue, never file into life, people or ideas,
and never change that repo from this thread: its issue gets its own PR.
