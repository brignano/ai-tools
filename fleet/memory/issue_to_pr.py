#!/usr/bin/env python3
"""memory-pr: turn one `Memory:` issue into a PR, then run the gate on it.

A plain script, no model (decisions/0006): the session that filed the issue
already did the thinking. Runs in .github/workflows/memory-pr.yml with the
repo checked out at main and GH_TOKEN set to the workflow's own token.

  1. Only issues opened by the repo owner count; others are closed with a note.
  2. A missing field gets a comment saying what is missing, and stops.
  3. An exact duplicate of a memory, or of a rejected one, is closed with a link.
  4. Otherwise it writes memory/<slug>.md (or edits/deletes the `Replaces`
     file) on branch memory/<N>, opens a PR that closes the issue, and hands
     the PR to gate.py, which merges it or holds it for Anthony.

Usage: issue_to_pr.py   (env: GITHUB_EVENT_PATH, GITHUB_REPOSITORY, GH_TOKEN)
"""
import datetime
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate  # noqa: E402
import memlib  # noqa: E402

FOOTER = "\n\n---\n_memory-pr (fleet/memory/issue_to_pr.py), no model involved_"


def sh(*args, input=None, check=True):
    return gate.sh(*args, input=input, check=check)


def comment(repo, n, text):
    sh("gh", "issue", "comment", str(n), "--repo", repo, "--body-file", "-", input=text + FOOTER)


def close(repo, n, reason):
    # state_reason "duplicate" isn't offered by `gh issue close`, so use the API.
    sh("gh", "api", "-X", "PATCH", f"repos/{repo}/issues/{n}",
       "-f", "state=closed", "-f", f"state_reason={reason}")


def rejected_facts(repo):
    """{normalised fact: issue number} for every closed memory:rejected issue."""
    out = sh("gh", "issue", "list", "--repo", repo, "--state", "closed", "--label", "memory:rejected",
             "--limit", "500", "--json", "number,body", check=False) or "[]"
    facts = {}
    for i in json.loads(out):
        fact = memlib.normalise(memlib.parse_form(i.get("body"))["fact"])
        if fact:
            facts[fact] = i["number"]
    return facts


def build(repo, issue, folder="memory"):
    """What to do for this issue: ("skip"|"comment"|"close-duplicate"|"write", detail)."""
    n = issue["number"]
    owner = repo.split("/")[0]
    if issue["user"]["login"].lower() != owner.lower():
        return "close-outsider", f"Fleet memories only come from {owner}'s own sessions, so this one is closed."
    form = memlib.parse_form(issue.get("body"))
    problems = memlib.form_problems(form)
    if problems:
        return "comment", ("This memory can't become a PR yet. Edit the issue to fix:\n\n"
                           + "\n".join(f"- {p}" for p in problems))

    existing = {slug: (meta, body) for slug, meta, body in memlib.read_folder(folder)}
    fact = memlib.normalise(form["fact"])
    if form["replaces"] and form["replaces"] not in existing:
        return "comment", f"**Replaces** names `{form['replaces']}`, but there is no `memory/{form['replaces']}.md`."
    if fact and not form["replaces"]:
        for slug, (_, body) in existing.items():
            if memlib.normalise(body) == fact:
                return "close-duplicate", f"This is already remembered in `memory/{slug}.md`."
    return "write", form, existing


def main():
    repo = os.environ["GITHUB_REPOSITORY"]
    with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as f:
        n = json.load(f)["issue"]["number"]
    # Read it live: an earlier run may already have merged (and closed) it.
    issue = json.loads(sh("gh", "api", f"repos/{repo}/issues/{n}"))
    labels = {l["name"] for l in issue.get("labels", [])}
    if issue.get("state") != "open" or "memory" not in labels or "memory:rejected" in labels:
        print("memory-pr: nothing to do")
        return 0

    result = build(repo, issue)
    kind = result[0]
    if kind == "close-outsider":
        comment(repo, n, result[1])
        close(repo, n, "not_planned")
        return 0
    if kind == "comment":
        comment(repo, n, result[1])
        return 0
    if kind == "close-duplicate":
        comment(repo, n, result[1])
        close(repo, n, "duplicate")
        return 0

    _, form, existing = result
    fact = memlib.normalise(form["fact"])
    if fact and not form["replaces"]:
        rej = rejected_facts(repo)
        if fact in rej:
            comment(repo, n, f"Anthony rejected this memory before (#{rej[fact]}), so it isn't proposed again.")
            close(repo, n, "duplicate")
            return 0

    if form["replaces"] and not form["fact"]:
        slug, action = form["replaces"], "Forget"
    else:
        slug = form["replaces"] or memlib.slugify(form["fact"], taken=existing)
        action = "Edit" if form["replaces"] else "Remember"
    path = f"memory/{slug}.md"
    branch = f"memory/{n}"

    sh("git", "config", "user.name", "github-actions[bot]")
    sh("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    sh("git", "checkout", "-q", "-B", branch)
    if action == "Forget":
        sh("git", "rm", "-q", path)
    else:
        meta = {"topic": form["topic"], "from": form["from"], "session": form["session"],
                "added": datetime.date.today().isoformat()}
        with open(path, "w", encoding="utf-8") as f:
            f.write(memlib.render(meta, form["fact"]))
        sh("git", "add", path)
    sh("git", "commit", "-q", "-m", f"{action} memory: {slug} (#{n})")
    sh("git", "push", "-q", "--force", "origin", f"HEAD:refs/heads/{branch}")

    title = f"{action} memory: {form['fact'][:60] or slug}"
    found = json.loads(sh("gh", "pr", "list", "--repo", repo, "--head", branch, "--state", "open",
                          "--json", "number") or "[]")
    if found:
        number = found[0]["number"]
    else:
        quote = "\n".join("> " + l for l in form["quote"].splitlines())
        body = (f"Closes #{n}\n\n{action} `{path}`.\n\n**Fact:** {form['fact'] or '(removed)'}\n\n"
                f"**Anthony's words:**\n{quote}\n\nFrom {form['from']} · [session]({form['session']})\n\n"
                "## Release\nImpact: none" + FOOTER)
        url = sh("gh", "pr", "create", "--repo", repo, "--head", branch, "--base", "main",
                 "--title", title, "--body-file", "-", "--label", "memory", input=body).strip()
        number = int(url.rstrip("/").rsplit("/", 1)[-1])
    # PRs opened with the workflow token don't trigger other workflows, so the
    # gate runs here, from this (main) checkout.
    sh("git", "checkout", "-q", "main")
    gate.run(repo, number, owner=repo.split("/")[0])
    return 0


if __name__ == "__main__":
    sys.exit(main())
