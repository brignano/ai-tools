---
name: releases
description: How Anthony cuts releases — in the GitHub UI, with hand-written notes as the changelog — and how release automation on v* tags must behave. Use when preparing or cutting a release, writing release notes, bumping a version, or writing or changing a workflow that runs on tags.
---

# Releases — the GitHub release page is the changelog

**I create releases in the GitHub UI, and the release notes are the record.**
Anyone following a project reads that page to find new capabilities as they
ship. So it gets written for that reader, by hand. There is no `CHANGELOG.md`
duplicating it, and npm is distribution only — never where changes are
documented.

What this means when you are helping me cut one:

- **Do not hand me `git tag` / `git push origin <tag>`.** Releases → *Draft a
  new release* → *Choose a tag* creates the tag on publish. The whole flow is
  the UI, so CLI steps are noise I have to translate.
- **Always include the notes as a copy-pasteable fenced markdown block**, ready
  to paste into the body with nothing to edit first. Proposing a release without
  the notes attached is half an answer — attach them without being asked.
- **Write for a consumer, not a maintainer.** Lead with what they can now do. A
  generated list of merged PR titles is raw material for the notes, not the
  notes.
- **Keep repo hygiene out of them.** "The LICENSE file was missing" is a commit
  message; a release page reader needs "MIT licensed".

## Release automation, where a repo has any
A workflow on `v*` tags must **verify, never create**. Publishing from the UI is
what creates the tag, so by the time the workflow runs the release already
exists and there is nothing left for it to make. Have it re-run the checks
against the tagged tree and fail loudly when the tag disagrees with the version
in `package.json` — that mismatch is invisible once a release page exists.

Do not expect a stray `gh release create` to announce itself by failing. With
`--draft` it **succeeds**: a draft is not bound to a tag, so it does not collide
with the published release, and you get a second release object, same name,
unpublished, authored by `github-actions[bot]`. `hoststats` v0.1.0 left exactly
one of those behind. Only a non-draft create errors. Silent duplication is both
the likelier outcome and the harder one to spot.

Note also that verification lands *after* publication, so a red run means "pull
that release", not "the release was blocked". Say so in the workflow rather than
implying a gate that is not there.
