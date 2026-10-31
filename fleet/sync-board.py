#!/usr/bin/env python3
"""Add every open issue and PR in the repos listed in fleet/board.yml to the
Fleet project board.

Dry run by default: prints what it would add and touches nothing.
Pass --apply to add them. Uses the `gh` CLI, so it authenticates as whatever
GH_TOKEN (or `gh auth login`) holds. Projects owned by a user need a classic
token with the `project` scope (plus `repo` to see private repos).

  python3 fleet/sync-board.py                    # dry run, every listed repo
  python3 fleet/sync-board.py --repo guidebook   # dry run, one repo
  python3 fleet/sync-board.py --apply            # what the workflow runs

It only adds. It never removes, archives or edits a card, so Status,
Priority and anything else set on the board is left alone. New cards get the
board's default Status; GitHub's built-in project workflows take it from there.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import yaml

CONFIG = Path(__file__).with_name("board.yml")


def gh(*args):
    out = subprocess.run(["gh", "api", *args], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"gh api {args[0]}: {out.stderr.strip() or out.stdout.strip()}")
    return json.loads(out.stdout) if out.stdout.strip() else None


def graphql(query, **variables):
    args = ["graphql", "-f", f"query={query}"]
    for k, v in variables.items():
        args += ["-F" if isinstance(v, int) else "-f", f"{k}={v}"]
    data = gh(*args)
    if data.get("errors"):
        raise RuntimeError(json.dumps(data["errors"]))
    return data["data"]


def load_config():
    cfg = yaml.safe_load(CONFIG.read_text())
    repos = cfg.get("repos") or []
    never = {n.lower() for n in cfg.get("never") or []}
    bad = [r for r in repos if r.lower() in never]
    if bad:
        sys.exit(f"board.yml: {', '.join(bad)} must never be on the board")
    return cfg["owner"], int(cfg["project"]), repos


def project_items(owner, number):
    """Return the project's node id and the content ids already on it."""
    query = """
    query($owner: String!, $number: Int!, $after: String) {
      user(login: $owner) {
        projectV2(number: $number) {
          id
          items(first: 100, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes { content { ... on Issue { id } ... on PullRequest { id } } }
          }
        }
      }
    }"""
    seen, after, project_id = set(), None, None
    while True:
        vars_ = {"owner": owner, "number": number}
        if after:
            vars_["after"] = after
        proj = graphql(query, **vars_)["user"]["projectV2"]
        project_id = proj["id"]
        for node in proj["items"]["nodes"]:
            if node.get("content"):
                seen.add(node["content"]["id"])
        page = proj["items"]["pageInfo"]
        if not page["hasNextPage"]:
            return project_id, seen
        after = page["endCursor"]


def open_items(owner, repo):
    """Open issues and PRs (the issues endpoint returns both)."""
    pages = gh(f"repos/{owner}/{repo}/issues?state=open&per_page=100", "--paginate", "--slurp")
    return [item for page in pages for item in page]


ADD = """
mutation($project: ID!, $content: ID!) {
  addProjectV2ItemById(input: {projectId: $project, contentId: $content}) { item { id } }
}"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="add the items (default: dry run)")
    ap.add_argument("--repo", help="only this repo (must be listed in board.yml)")
    args = ap.parse_args()

    owner, number, repos = load_config()
    if args.repo:
        if args.repo not in repos:
            sys.exit(f"{args.repo} is not listed in board.yml")
        repos = [args.repo]

    project_id, on_board = project_items(owner, number)
    total, failed = 0, False
    for repo in repos:
        try:
            items = open_items(owner, repo)
        except RuntimeError as e:
            print(f"{repo}: could not list issues: {e}")
            failed = True
            continue
        missing = [i for i in items if i["node_id"] not in on_board]
        print(f"{repo}: {len(items)} open, {len(missing)} to add")
        for i in missing:
            kind = "PR" if "pull_request" in i else "issue"
            print(f"  + {kind} #{i['number']} {i['title']}")
            if args.apply:
                graphql(ADD, project=project_id, content=i["node_id"])
        total += len(missing)
    verb = "Added" if args.apply else "Would add"
    print(f"\n{verb} {total} item(s) to {owner}'s project {number}.")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
