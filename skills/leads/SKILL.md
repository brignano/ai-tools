---
name: leads
description: Use when adding or changing any form, signup, contact, pilot or preview-request flow that takes in leads on a site or product. Wires the four-step lead standard (store, email owner, auto-reply, GitHub issue plus nudge).
---

# Leads

The standard is "Leads" in `fleet/README.md` (brignano/ai-tools). Read it; this
is the checklist. A new form without all four steps is incomplete.

Store first. Then each step in its own try/catch: log failures, never block,
slow or fail the form.

1. **Store** the lead (full details) behind one small function.
2. **Email Anthony** via Resend from `<project>@<domain>` with a link to the record.
3. **Auto-reply** from `hello@<domain>`: HTML plus plain text, dark mode, fixed
   template, one per address per week, states the reply window. Show Anthony
   the wording and get approval before it ships.
4. **Open a GitHub issue**: title `Lead: <company or name>`, label `lead`,
   assignee `brignano`, body = link to the record and the promised window.
   **Never put an email, phone number or message text in the issue.** Closing
   it means handled.

Then add the daily nudge: copy `fleet/leads/lead-nudge-caller.yml` to
`.github/workflows/lead-nudge.yml` and set `promise_hours` to the window the
auto-reply promises.

## What it needs

- `RESEND_API_KEY` and `LEAD_GITHUB_TOKEN` in the platform's secret store,
  never in commits. `LEAD_GITHUB_TOKEN` is the one shared fine-grained token
  (Issues read/write, only lead-taking repos, expires yearly). Ask Anthony to
  add the repo to its list; do not create another token.
- Resend sending domain verified (DNS) before shipping. Tell Anthony which
  records and secrets to set in the PR.
- The `lead` label: if missing, it comes from `fleet/labels.yml`. Don't invent labels.
- Never set `agent:ready` on a lead issue.
