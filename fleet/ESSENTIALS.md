# Fleet essentials

The one page every session starts with. The full standard is the
`fleet-standard` skill: load it before you plan, build, review, merge, file an
issue in another repo, or touch labels, releases or leads. Repo rules in its
own AGENTS.md/CLAUDE.md win where they are stricter.

## How work flows
- **Backlog = GitHub issues in the repo that owns the code.** The Fleet board
  (github.com/users/brignano/projects/1) is my view; labels are what agents act on.
- **Every open issue is ready by default** (`agent:ready`, set by the board sync)
  unless held: `needs:anthony`, `blocked`, `agent:pause`, `agent:working`, `lead`,
  a `Release plan:` issue, or one opened by a bot or outsider.
- **Order:** highest `priority:` first (p1 > p2 > p3), then smallest `size:`, then oldest.
- **Issues are specs:** Problem, Acceptance criteria, How to verify, Decisions,
  Out of scope, Notes. A builder never decides what Decisions leaves open: it
  comments the question, adds `needs:anthony`, and stops.
- **Design review before build:** size M work starts with a proposal PR (no code),
  then the agent explains it to me in plain words with options and costs, adds
  `needs:anthony` and stops. Nothing is built until I accept it. Builders comment
  their plan before coding.
- **Specs in `proposals/`, decisions in `decisions/` (ADRs), user docs in `docs/`.**
  Repos that deploy several parts keep a driftwood `architecture.yaml`, checked in
  CI; never hand-draw the system diagram. No GitHub Pages.
- **Keep everything in sync in the same PR:** README, `docs/`, the product site, and
  agent context (AGENTS.md, CLAUDE.md, skills) so the next session starts informed.
  Other repos get an issue.
- **Labels only from fleet/labels.yml.** Every agent-filed issue gets `proposed`
  plus one `priority:`, `type:`, `size:` and `risk:`.

## Threads and projects
- One thread per issue or PR, titled after it. It ends when the PR merges or the
  issue closes.
- **Claim before work:** add `agent:working`, remove `agent:ready`, comment
  "Claimed by <session link>". Never touch an issue someone else claimed.
- **Projects talk through issues.** Work for another repo becomes an issue there
  (spec shape, labels, "From owner/repo#N"), and you tell me in one line
  (`/handoff`). Never ask me to add that repo to the project.
- "What's next" is answered from GitHub in this order: waiting on me, in
  progress, up next (top 5), held, blocked, tidy-up (`/next`).

## Shipping
- Never push to the default branch. Every PR links its issue with `Closes #N`
  or `Part of #N`, and ends with `## Release` (Impact none/patch/minor/major).
- **Gates, in order:** self-review (code-review medium + simplify), CI green,
  the `reviewer` subagent posting `Reviewer: APPROVE` with the head SHA, the UX
  gate for anything a user sees, and a preview link at the top of the PR for site repos.
- **Merge only** when I ask ("merge it": `/merge-it` runs the gates, then merges)
  or the repo is in fleet/merge.yml `auto` and "Who merges" allows it. Otherwise
  add `needs:anthony` plus a "Ready to merge" comment.
- **Asking Anthony:** every ask stands alone (readable on a phone with nothing
  else open): numbered "Decision 1 of N" blocks with context, options, a
  recommendation and a reply code. Never a bare "3 decisions left". Ready to
  merge also says what he's approving, the risk and the decisions made. Format:
  fleet README, "Asking Anthony".
- No version bumps or releases without my "publish X".
- **Homelab deploys:** cloud sessions can't reach CT 100. Any PR that needs a
  deploy has a `## Deploy` section, and the merge reply repeats it: the exact
  line in a code block, e.g. `hl-ssh -t "cd /root/homelab && claude '/deploy monitoring'"`
  (name the stack; drop it to deploy all), plus whether CT 100 deploys it
  automatically. Never just say "run /deploy".

## Always
- UI styles from `brignano/design` tokens only, never a picked colour or hex
  (`design-system` skill). New sites follow the `hosting` skill and default to private.
- Never touch secrets or `.env`, never weaken a check, never work on a `lead` issue.
  (The plugin's guard blocks pushes to main and writes to secrets files.)
- Personal topics (`life`, `people`) never go into issues or PRs, and no project
  files issues in life, people or ideas.
