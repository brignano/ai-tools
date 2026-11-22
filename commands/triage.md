---
description: Digest and sort new issues in one reply (keep, duplicate, close, needs Decisions, merge), changing nothing until Anthony answers
argument-hint: [owner/repo | all] [7d]
---

Triage the issues for **$ARGUMENTS**:

- empty: the repo this project or session works in (with several, ask which, or do each)
- `owner/repo`: that one repo
- `all`: every repo in `fleet/board.yml` in brignano/ai-tools; leave out repos with nothing new
- a window like `7d` or `30d`: issues created or edited in that window, instead of "since the last triage"

Load the `fleet-standard` skill first. Read everything from GitHub, not from memory.

## What to read

1. **Open issues since the last triage.** An issue carrying a
   `<!-- triaged: YYYY-MM-DD -->` comment and not edited (body, title, labels
   or new comments) after that date is skipped. A window argument overrides this.
2. **For duplicates:** every open issue in the same repo, plus issues closed in
   the last 30 days.
3. **For "possibly done":** merged PRs that mention the issue. Reason the same
   way as `fleet/backlog-health.py` and the "Fleet backlog health" issue, so the
   two never disagree.

## One line per issue

`#N <plain-words summary, under 15 words>`, then any label suggestions, then the
verdict:

- **keep**: valid as written.
- **duplicate of #M**: same problem and outcome as #M.
- **close (done)**: a merged PR finished it; name the PR.
- **close (low value)**: say why in a few words (superseded, no longer true,
  cost outweighs the gain).
- **needs Decisions**: no `## Decisions` section. Suggest running the planner;
  never write Decisions yourself.
- **merge into #M**: overlaps #M enough to be one issue.

Suggest `priority:`, `size:`, `risk:` or `type:` only when missing or looking
wrong, and only from `fleet/labels.yml`. Respect the caps in "Status, priority
and blocked" (at most 2 `priority:p1` per repo) and say `size:m` or larger
needs a proposal first.

Issues labelled `lead` or `agent:working`, or opened by a bot, are listed
under **Not touched** with no verdict and are never acted on.

## Output

Group by verdict, number every line across the groups, keep it short. Follow
fleet README "Asking Anthony": in a thread with a question-card tool, one card
per verdict group that has anything other than keep ("Close these 4 as
done?", options all / pick / none). Otherwise end with reply codes, one per
line:

```
1 ok        apply what line 1 suggests
3 close     close #N as the line says
3 keep      ignore the suggestion
all ok      apply every suggestion
```

## After Anthony answers

Change nothing before he replies. Then apply only what he approved:

- labels he accepted;
- closing with a one-line comment and the right `state_reason`
  (`completed` for done, `not_planned` for low value or duplicate, with
  "Duplicate of #M" in the comment);
- a "Merged into #M" comment plus closing as `not_planned` for merges;
- a hidden `<!-- triaged: YYYY-MM-DD -->` comment on every issue he kept or
  you touched, so the next `/triage` skips it until it changes.

Never run on a schedule and never post anywhere but the chat it was run in;
if that ever seems useful, ask Anthony.
