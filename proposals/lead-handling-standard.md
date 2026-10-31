# Lead handling standard

Status: accepted
Issue: brignano/ai-tools#56

## Problem
Every project that takes leads can drop one, and each would copy the handling
differently. `brignano/sites` solved it; the solution needs to be one standard
that is changed in one place.

## Design
- **Single source**: `fleet/README.md` "Leads" plus the `leads` skill, in
  ai-tools. The fleet session-start hook already loads the README into every
  cloud session, so a change reaches all projects on the next session.
- **Label**: `lead` in `fleet/labels.yml`, synced to every repo.
- **Nudge**: reusable `lead-nudge.yml` (`workflow_call`); projects add a ten-line
  caller pinned to `@main`. Tradeoff: a bad edit reaches every repo at once; a
  moving `v1` tag is the alternative if that bites.
- **Agents**: builder and planner skip `lead` issues; only Anthony closes them.
- **Token**: one fine-grained token, named `GITHUB_TOKEN` in each host (as sites
  already does), Issues read/write, only lead-taking repos, yearly expiry.
  Never an Actions secret: the name is reserved there.

## Not now
A central config / lead-funnel service (see the config API issue). Step 1 is
written as a swappable store function so it can move there later.
