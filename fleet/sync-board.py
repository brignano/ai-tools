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

It never removes or archives a card. Labels are what agents can see, so the
board and the labels are kept in step in two places:
  - Priority: created if missing (P1, P2, P3) and filled from each card's
    `priority:p1/p2/p3` label. A card with no priority label keeps its value.
  - Ready: when I move a card to Status "Ready", its issue gets `agent:ready`
    and loses `proposed`. That is the signal builders act on.
Every other field is left to GitHub's built-in project workflows and to me.
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
    """Return the project's node id and {content id: item} for every card."""
    query = """
    query($owner: String!, $number: Int!, $after: String) {
      user(login: $owner) {
        projectV2(number: $number) {
          id
          items(first: 100, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              priority: fieldValueByName(name: "Priority") {
                ... on ProjectV2ItemFieldSingleSelectValue { name }
              }
              status: fieldValueByName(name: "Status") {
                ... on ProjectV2ItemFieldSingleSelectValue { name }
              }
              content {
                ... on Issue { id number state repository { name } labels(first: 30) { nodes { name } } }
                ... on PullRequest { id number state repository { name } labels(first: 30) { nodes { name } } }
              }
            }
          }
        }
      }
    }"""
    seen, after, project_id = {}, None, None
    while True:
        vars_ = {"owner": owner, "number": number}
        if after:
            vars_["after"] = after
        proj = graphql(query, **vars_)["user"]["projectV2"]
        project_id = proj["id"]
        for node in proj["items"]["nodes"]:
            if (node.get("content") or {}).get("id"):
                seen[node["content"]["id"]] = node
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


PRIORITIES = ["P1", "P2", "P3"]

FIELD = """
query($owner: String!, $number: Int!) {
  user(login: $owner) {
    projectV2(number: $number) {
      field(name: "Priority") {
        ... on ProjectV2SingleSelectField { id options { id name } }
      }
    }
  }
}"""

CREATE_FIELD = """
mutation($project: ID!) {
  createProjectV2Field(input: {
    projectId: $project, dataType: SINGLE_SELECT, name: "Priority",
    singleSelectOptions: [
      {name: "P1", color: RED, description: "Do next"},
      {name: "P2", color: YELLOW, description: "Soon"},
      {name: "P3", color: GRAY, description: "Someday"}
    ]
  }) {
    projectV2Field { ... on ProjectV2SingleSelectField { id options { id name } } }
  }
}"""

SET_FIELD = """
mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $project, itemId: $item, fieldId: $field,
    value: {singleSelectOptionId: $option}
  }) { projectV2Item { id } }
}"""


def priority_field(owner, number, project_id, apply):
    """Return (field id, {option name: option id}), creating the field if needed."""
    field = graphql(FIELD, owner=owner, number=number)["user"]["projectV2"]["field"]
    if not field:
        print("Priority field: missing, " + ("creating it" if apply else "would create it"))
        if not apply:
            return None, {p: None for p in PRIORITIES}
        field = graphql(CREATE_FIELD, project=project_id)["createProjectV2Field"]["projectV2Field"]
    options = {o["name"]: o["id"] for o in field.get("options") or []}
    missing = [p for p in PRIORITIES if p not in options]
    if missing:
        sys.exit(f"Priority field has no option(s) {', '.join(missing)}; add them on the board")
    return field["id"], options


def label_priority(node):
    names = {n["name"].lower() for n in node["content"]["labels"]["nodes"]}
    for p in PRIORITIES:
        if f"priority:{p.lower()}" in names:
            return p
    return None


def sync_priority(owner, number, apply, repo_node_ids):
    """Set Priority from priority:pN labels on cards from the listed repos."""
    project_id, cards = project_items(owner, number)
    field_id, options = priority_field(owner, number, project_id, apply)
    changed = 0
    for content_id, node in cards.items():
        if content_id not in repo_node_ids:
            continue
        want = label_priority(node)
        have = (node.get("priority") or {}).get("name")
        if want and want != have:
            print(f"  ~ {repo_node_ids[content_id]}: Priority {have or '-'} -> {want}")
            if apply:
                graphql(SET_FIELD, project=project_id, item=node["id"], field=field_id, option=options[want])
            changed += 1
    verb = "Set" if apply else "Would set"
    print(f"{verb} Priority on {changed} card(s).")


def sync_ready(owner, number, apply, repo_node_ids):
    """Cards I moved to Ready get agent:ready (and lose proposed)."""
    _, cards = project_items(owner, number)
    changed = 0
    for content_id, node in cards.items():
        if content_id not in repo_node_ids:
            continue
        if ((node.get("status") or {}).get("name") or "").lower() != "ready":
            continue
        c = node["content"]
        names = {n["name"] for n in c["labels"]["nodes"]}
        if "agent:ready" in names:
            continue
        repo, num = c["repository"]["name"], c["number"]
        print(f"  ~ {repo}#{num}: Status is Ready -> label agent:ready")
        if apply:
            gh(f"repos/{owner}/{repo}/issues/{num}/labels", "-X", "POST", "-f", "labels[]=agent:ready")
            if "proposed" in names:
                gh(f"repos/{owner}/{repo}/issues/{num}/labels/proposed", "-X", "DELETE")
        changed += 1
    verb = "Labelled" if apply else "Would label"
    print(f"{verb} {changed} Ready card(s) agent:ready.")


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
    total, failed, repo_node_ids = 0, False, {}
    for repo in repos:
        try:
            items = open_items(owner, repo)
        except RuntimeError as e:
            print(f"{repo}: could not list issues: {e}")
            failed = True
            continue
        for i in items:
            repo_node_ids[i["node_id"]] = f"{repo}#{i['number']}"
        missing = [i for i in items if i["node_id"] not in on_board]
        print(f"{repo}: {len(items)} open, {len(missing)} to add")
        for i in missing:
            kind = "PR" if "pull_request" in i else "issue"
            print(f"  + {kind} #{i['number']} {i['title']}")
            if args.apply:
                graphql(ADD, project=project_id, content=i["node_id"])
        total += len(missing)
    verb = "Added" if args.apply else "Would add"
    print(f"\n{verb} {total} item(s) to {owner}'s project {number}.\n")
    sync_priority(owner, number, args.apply, repo_node_ids)
    print()
    sync_ready(owner, number, args.apply, repo_node_ids)
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as e:
        # Annotations show on the run page, so failures are visible without logs.
        print(f"::error title=fleet-board::{str(e)[:900]}")
        sys.exit(1)
