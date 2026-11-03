---
description: Merge a PR the fleet way: re-run any stale gates, merge, then confirm main is green
argument-hint: [PR number or URL, empty for this thread's PR]
---

I'm asking you to merge **$ARGUMENTS** (empty: the PR this thread is about).
This ask is my approval for that one PR.

Load the `fleet-standard` skill and follow "Merging when I ask":

1. Read the PR at its current head: CI, review threads, the latest
   `Reviewer: APPROVE` comment and its SHA, the Ready to merge comment, and
   whether it is up to date with the base.
2. Run whatever gate is missing or stale for this head: update the branch from
   the base, wait for CI, answer open review threads, run the `reviewer`
   subagent again on the new head (PR number and issue only), and run the UX
   gate if users see the change. Don't ask me to wait or reconfirm unless a gate fails.
3. Merge with the repo's merge method and delete the branch.
4. Check the default branch's CI after the merge, and the deploy if the repo
   deploys on merge. Tell me in one line that it merged and main is green, or what broke.
   If it needs a homelab deploy, end with the PR's `## Deploy` section: whether
   CT 100 deploys it automatically, and the copy-paste line in a code block:
   `hl-ssh -t "cd /root/homelab && claude '/deploy <stack>'"` (fill in the stack).

If a gate fails, don't merge: say in one line what failed and what you're doing,
fix it in the PR, and merge once green without asking again. This never covers
a release, tag or publish.
