# 0007: One Build project, merge commits, size M in one PR

Status: accepted
Date: 2026-11-23
From: #114
Amends: [0003](0003-design-review-before-build.md) (where the build goes after the design is accepted)

## Context
On 2026-11-22 Anthony moved every build repo into one Claude project, Build,
and archived the per-repo projects; Life stays separate. The standard still
assumed one project per repo, so agents would send him to "start a session
in project X" or treat other repos as unreachable. Two rules from the old
projects also weren't written down: squash merging is disabled on his repos,
and a size M issue's proposal and build share one PR.

## Decision
- Every build repo lives in the Build project. Threads are titled with their
  repo (`homelab#386: ...`). Work for another repo is still its own issue in
  that repo, linked both ways, with its own thread and PR; there is no
  hand-off to another project.
- PRs merge with merge commits, never squash.
- A size M issue opens its PR with the proposal only. After Anthony accepts
  it in the Design review, the build is pushed to the same PR, which then
  goes through the normal gates. A proposal that splits into several issues
  still merges on its own.

## Consequences
- One place to start work, and no project switching.
- Fewer PRs per M issue; the proposal commit and the code land together.
- Approval of a design is not approval to merge its code: the combined PR
  still waits for "merge it" or the merge rules.
