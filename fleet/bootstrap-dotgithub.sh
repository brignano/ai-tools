#!/usr/bin/env bash
# One-time: create brignano/.github and give it the fleet's default issue forms.
# GitHub shows these in every repo of mine that has no .github/ISSUE_TEMPLATE of
# its own. Agents can't create a repo whose name starts with a dot, so run this
# yourself (needs `gh auth login`). Safe to re-run: it only updates the forms.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

gh repo view brignano/.github >/dev/null 2>&1 ||
  gh repo create brignano/.github --public --description "Default issue forms for my repos (source: brignano/ai-tools fleet/)"
gh repo clone brignano/.github "$work/repo" -- --depth 1 2>/dev/null || {
  git init -q -b main "$work/repo"
  git -C "$work/repo" remote add origin https://github.com/brignano/.github.git
}

mkdir -p "$work/repo/.github/ISSUE_TEMPLATE"
cp "$here"/issue-forms/*.yml "$work/repo/.github/ISSUE_TEMPLATE/"
cat > "$work/repo/README.md" <<'MD'
# brignano/.github

Default issue forms for every repo of mine without its own. The source is
[`brignano/ai-tools` `fleet/issue-forms/`](https://github.com/brignano/ai-tools/tree/main/fleet/issue-forms);
edit there and re-run `fleet/bootstrap-dotgithub.sh`. Labels are synced from
`fleet/labels.yml` in the same repo.
MD

cd "$work/repo"
git add -A
git diff --cached --quiet && { echo "brignano/.github already up to date"; exit 0; }
git commit -qm "Sync default issue forms from ai-tools fleet/"
git push -q origin HEAD:main
echo "pushed: https://github.com/brignano/.github"
