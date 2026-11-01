#!/usr/bin/env python3
"""Weekly backlog check across the repos in fleet/board.yml.

Finds the open issues that make the backlog hard to read, and writes them to
one issue in brignano/ai-tools titled "Fleet backlog health" (created once,
then edited in place each week, so it never piles up notifications):

  - Possibly done: a merged PR mentions it and no open PR does. Close it
    or say what is left. PRs that say "Part of #N" don't count.
  - No priority: no `priority:` label.
  - Too many P1: more than MAX_P1 open `priority:p1` issues in one repo.
  - Blocked with no reason: `blocked` but no "Blocked by" line in the body.
  - Idle: no update in IDLE_DAYS days.

It never labels, closes or comments on the issues it lists. Projects read
their repo's section when I ask "what's next", and the Sunday review reads
the whole thing.

  python3 fleet/backlog-health.py            # print the report
  python3 fleet/backlog-health.py --apply    # also write the health issue
"""
import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

CONFIG = Path(__file__).with_name("board.yml")
HEALTH_REPO = "ai-tools"
HEALTH_TITLE = "Fleet backlog health"
MARKER = "<!-- fleet:backlog-health -->"
MAX_P1 = 2
IDLE_DAYS = 30


def gh(*args):
    out = subprocess.run(["gh", "api", *args], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"gh api {args[0]}: {out.stderr.strip() or out.stdout.strip()}")
    return json.loads(out.stdout) if out.stdout.strip() else None


def paged(path):
    return [x for page in gh(path, "--paginate", "--slurp") for x in page]


def mentioning_prs(owner, repo, num):
    """(merged PRs, open PRs) that cross-reference this issue, minus "Part of"."""
    part_of = re.compile(rf"part of\s+(?:{owner}/{re.escape(repo)})?#{num}\b", re.I)
    merged, still_open = [], []
    for e in paged(f"repos/{owner}/{repo}/issues/{num}/timeline?per_page=100"):
        if e.get("event") != "cross-referenced":
            continue
        src = (e.get("source") or {}).get("issue") or {}
        pr = src.get("pull_request")
        if not pr:
            continue
        if src.get("state") == "open":
            still_open.append(src)
        elif pr.get("merged_at") and not part_of.search(src.get("body") or ""):
            merged.append(src)
    return merged, still_open


def check_repo(owner, repo, now):
    issues = [
        i for i in paged(f"repos/{owner}/{repo}/issues?state=open&per_page=100")
        if "pull_request" not in i and (i.get("user") or {}).get("type") != "Bot"
        and MARKER not in (i.get("body") or "")  # the health issue itself
    ]
    found = {"Possibly done": [], "No priority": [], "Too many P1": [], "Blocked with no reason": [], "Idle": []}
    p1 = []
    for i in issues:
        names = {l["name"] for l in i["labels"]}
        if "lead" in names:
            continue  # leads are mine to answer, not backlog
        ref = f"{repo}#{i['number']} {i['title']}"
        merged, still_open = mentioning_prs(owner, repo, i["number"])
        if merged and not still_open:
            last = max(merged, key=lambda p: p["pull_request"]["merged_at"])
            found["Possibly done"].append(f"{ref} (merged {last['html_url']})")
        if not any(n.startswith("priority:") for n in names):
            found["No priority"].append(ref)
        if "priority:p1" in names:
            p1.append(ref)
        if "blocked" in names and not re.search(r"blocked by", i.get("body") or "", re.I):
            found["Blocked with no reason"].append(ref)
        updated = datetime.fromisoformat(i["updated_at"].replace("Z", "+00:00"))
        if now - updated > timedelta(days=IDLE_DAYS):
            found["Idle"].append(f"{ref} (last update {updated:%b %d})")
    if len(p1) > MAX_P1:
        found["Too many P1"] = p1
    return len(issues), found


def render(results, now):
    lines = [
        MARKER,
        f"Updated {now:%a %b %d, %Y} by the `fleet-backlog-health` workflow. "
        "Rules: fleet/README.md, \"Status, priority and blocked\".",
        "",
    ]
    clean = []
    for repo, (count, found) in results.items():
        problems = {k: v for k, v in found.items() if v}
        if not problems:
            clean.append(repo)
            continue
        lines.append(f"## {repo} ({count} open)")
        for kind, refs in problems.items():
            lines.append(f"**{kind}**")
            lines += [f"- {r}" for r in refs]
        lines.append("")
    if clean:
        lines.append("Nothing to fix: " + ", ".join(clean) + ".")
    return "\n".join(lines)


def write_issue(owner, body):
    existing = [
        i for i in paged(f"repos/{owner}/{HEALTH_REPO}/issues?state=open&per_page=100")
        if i["title"] == HEALTH_TITLE and MARKER in (i.get("body") or "")
    ]
    if existing:
        num = existing[0]["number"]
        gh(f"repos/{owner}/{HEALTH_REPO}/issues/{num}", "-X", "PATCH", "-f", f"body={body}")
        print(f"Updated {owner}/{HEALTH_REPO}#{num}")
    else:
        made = gh(
            f"repos/{owner}/{HEALTH_REPO}/issues", "-X", "POST",
            "-f", f"title={HEALTH_TITLE}", "-f", f"body={body}", "-f", "labels[]=type:chore",
            # agent:pause keeps it out of the board sync's triage and every queue.
            "-f", "labels[]=agent:pause",
        )
        print(f"Opened {made['html_url']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="write the health issue (default: print only)")
    args = ap.parse_args()

    cfg = yaml.safe_load(CONFIG.read_text())
    owner = cfg["owner"]
    now = datetime.now(timezone.utc)
    results, failed = {}, False
    for repo in cfg.get("repos") or []:
        try:
            results[repo] = check_repo(owner, repo, now)
        except RuntimeError as e:
            print(f"::warning title=backlog-health::{repo}: {str(e)[:500]}")
            failed = True
    body = render(results, now)
    print(body)
    if args.apply:
        write_issue(owner, body)
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as e:
        print(f"::error title=backlog-health::{str(e)[:900]}")
        sys.exit(1)
