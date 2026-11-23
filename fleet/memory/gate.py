#!/usr/bin/env python3
"""memory-gate: decide whether a PR that touches memory/ merges on its own.

    auto  every rule below holds, so the PR is merged (merge commit)
    hold  anything else: `needs:anthony` plus a Ready to merge comment

A plain script, never a model (decisions/0006). It only reads the PR as data:
the workflow runs this file from the base branch, never from the PR's head.

auto needs ALL of:
  - fleet/merge.yml on the base branch has the line `memory: auto` (Anthony's switch)
  - exactly one changed path, a NEW file matching memory/<slug>.md
  - that file has the frontmatter keys, and a body within the size limit with
    no links, code, HTML or instruction words (memlib.body_problems)
  - the PR comes from branch memory/<N> in this repo and its body says Closes #N
  - issue #N is open, labelled `memory`, opened by the repo owner, quotes
    Anthony, and its Fact is the file's body

Usage (in CI): gate.py <pr-number>   (env: GH_TOKEN, GITHUB_REPOSITORY, BASE_SHA, HEAD_SHA)
"""
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import memlib  # noqa: E402

MERGE_SWITCH = re.compile(r"^memory:\s*auto\s*(#.*)?$", re.M)


def decide(changes, contents, pr, issue, owner, merge_yml):
    """Pure decision. Returns ("auto" | "hold", [reasons it was held]).

    changes:   [(status, path)] from `git diff --name-status --no-renames` (A, M, D, ...)
    contents:  {path: text} of added or modified files at the PR head
    pr:        {"head_ref", "same_repo", "body"}
    issue:     {"number", "state", "author", "labels", "body"} or None
    owner:     login of the repo owner (the only person memories come from)
    merge_yml: text of fleet/merge.yml on the base branch
    """
    why = []
    if not MERGE_SWITCH.search(merge_yml or ""):
        why.append("fleet/merge.yml has no `memory: auto` line yet, so every memory waits for Anthony")

    if not changes:
        why.append("the PR changes nothing")
    for status, path in changes:
        if not path.startswith("memory/"):
            why.append(f"it touches `{path}`, outside memory/")
        elif status != "A":
            why.append(f"it {'edits' if status == 'M' else 'removes or renames'} `{path}`; only new memories merge on their own")
        elif not memlib.PATH.match(path):
            why.append(f"`{path}` is not a memory/<slug>.md file")
    added = [p for s, p in changes if s == "A" and memlib.PATH.match(p)]
    if len(changes) > 1:
        why.append(f"it changes {len(changes)} files; only a single new memory merges on its own")

    body = ""
    if len(added) == 1:
        meta, body = memlib.split(contents.get(added[0], ""))
        why += memlib.meta_problems(meta)
        why += memlib.body_problems(body)

    m = re.fullmatch(r"memory/(\d+)", pr.get("head_ref") or "")
    if not m or not pr.get("same_repo"):
        why.append("it was not opened by the memory workflow (branch memory/<issue> in this repo)")
    else:
        n = int(m.group(1))
        if not re.search(rf"\b(close|closes|closed|fix|fixes|resolve|resolves)\s+#{n}\b", pr.get("body") or "", re.I):
            why.append(f"the PR body doesn't close #{n}")
        if not issue or issue.get("number") != n:
            why.append(f"issue #{n} could not be read")
        else:
            if issue.get("state") != "open":
                why.append(f"issue #{n} is not open")
            if "memory" not in issue.get("labels", []):
                why.append(f"issue #{n} has no `memory` label")
            if "memory:rejected" in issue.get("labels", []):
                why.append(f"issue #{n} was rejected before")
            if (issue.get("author") or "").lower() != owner.lower():
                why.append(f"issue #{n} was not opened by {owner}")
            form = memlib.parse_form(issue.get("body"))
            if not form["quote"]:
                why.append(f"issue #{n} has no quote of Anthony's words")
            if form["replaces"]:
                why.append(f"issue #{n} replaces `{form['replaces']}`; edits and removals wait for Anthony")
            if body and memlib.normalise(form["fact"]) != memlib.normalise(body):
                why.append(f"the file's fact is not the Fact in issue #{n}")

    # Keep order, drop repeats.
    seen, out = set(), []
    for w in why:
        if w not in seen:
            seen.add(w)
            out.append(w)
    return ("hold" if out else "auto"), out


# ---- CI side --------------------------------------------------------------

def sh(*args, input=None, check=True):
    p = subprocess.run(args, capture_output=True, text=True, input=input)
    if check and p.returncode != 0:
        raise RuntimeError(f"{' '.join(args[:3])}... failed: {p.stderr.strip()[:300]}")
    return p.stdout


def gh_json(path):
    return json.loads(sh("gh", "api", path))


def collect(repo, number, base_sha, head_sha):
    pr = gh_json(f"repos/{repo}/pulls/{number}")
    sh("git", "fetch", "-q", "origin", f"+refs/pull/{number}/head:refs/memory-gate/head")
    head = head_sha or sh("git", "rev-parse", "refs/memory-gate/head").strip()
    base = base_sha or pr["base"]["sha"]
    changes = []
    for line in sh("git", "diff", "--name-status", "--no-renames", f"{base}...{head}").splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            changes.append((parts[0][:1], parts[-1]))
    contents = {}
    for status, path in changes:
        if status in ("A", "M"):
            contents[path] = sh("git", "show", f"{head}:{path}", check=False)
    issue = None
    m = re.fullmatch(r"memory/(\d+)", pr["head"]["ref"])
    if m:
        try:
            i = gh_json(f"repos/{repo}/issues/{m.group(1)}")
            issue = {"number": i["number"], "state": i["state"], "author": i["user"]["login"],
                     "labels": [l["name"] for l in i["labels"]], "body": i.get("body") or ""}
        except RuntimeError:
            issue = None
    try:
        with open("fleet/merge.yml", encoding="utf-8") as f:  # base branch checkout
            merge_yml = f.read()
    except OSError:
        merge_yml = ""
    info = {"head_ref": pr["head"]["ref"],
            "same_repo": (pr["head"].get("repo") or {}).get("full_name") == repo,
            "body": pr.get("body") or ""}
    return changes, contents, info, issue, merge_yml, head, pr


def ready_comment(head, pr, why):
    reasons = "; ".join(why)
    return f"""## Ready to merge
Head: {head[:7]} · CI: memory-gate ran · Reviewer: n/a (memory PR) · UX gate: n/a
Preview: none (memory files are text loaded at session start)
Up to date with main: checked by GitHub · Conflicts: see the merge box
What changed: {pr.get('title', 'a memory change')}
What you're approving: this text joins (or changes) the fleet memory that every Claude session loads at start, as background facts.
Risk: a wrong or misleading fact would reach every session until it is reverted. It can't run anything: memory is loaded as data, never as instructions.
Decisions made in this PR: none
Why it needs Anthony: {reasons}
After merge: the next session on any machine loads it. Revert the merge commit to forget it.

Close this PR (or its issue) as not planned to reject it; the same memory then won't be proposed again.

---
_memory-gate (fleet/memory/gate.py), no model involved_"""


def act(repo, number, verdict, why, head, pr):
    """Merge, or hold with a label and comment. Returns the final verdict."""
    if verdict == "auto":
        for attempt in range(3):  # a brand-new PR may not have its mergeability computed yet
            p = subprocess.run(["gh", "pr", "merge", str(number), "--repo", repo, "--merge",
                                "--delete-branch", "--match-head-commit", head],
                               capture_output=True, text=True)
            if p.returncode == 0:
                print(f"memory-gate: auto-merged #{number}")
                return "auto"
            time.sleep(5)
        why = [f"the gate passed but GitHub refused the merge ({p.stderr.strip()[:200]})"]
    sh("gh", "pr", "edit", str(number), "--repo", repo, "--add-label", "needs:anthony", check=False)
    sh("gh", "pr", "comment", str(number), "--repo", repo, "--body-file", "-",
       input=ready_comment(head, pr, why), check=False)
    print(f"memory-gate: held #{number}: " + "; ".join(why))
    return "hold"


def run(repo, number, base_sha="", head_sha="", owner=""):
    changes, contents, info, issue, merge_yml, head, pr = collect(repo, number, base_sha, head_sha)
    verdict, why = decide(changes, contents, info, issue, owner or repo.split("/")[0], merge_yml)
    return act(repo, number, verdict, why, head, pr)


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    repo = os.environ["GITHUB_REPOSITORY"]
    run(repo, int(sys.argv[1]), os.environ.get("BASE_SHA", ""), os.environ.get("HEAD_SHA", ""),
        os.environ.get("REPO_OWNER", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
