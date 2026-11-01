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
  - Status: every open card's Status follows its labels, so nothing sits in
    "No status" (see STATUS below). An open issue with no workflow label gets
    `proposed`, so untriaged work shows up in Proposed instead of nowhere.
  - Claims: a claim older than CLAIM_HOURS with no open PR linked to the
    issue gets `needs:anthony` and one comment, so a stuck session can't hold
    it.
Done is left to GitHub's built-in "Item closed" workflow.
"""
import argparse
import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
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
              fieldValues(first: 30) {
                nodes {
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field { ... on ProjectV2SingleSelectField { name } }
                  }
                }
              }
              content {
                __typename
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
                # Looked up by name here because fieldValueByName errors when
                # the board has no field of that name (e.g. Priority, at first).
                values = {
                    v["field"]["name"]: v["name"]
                    for v in node["fieldValues"]["nodes"]
                    if v and (v.get("field") or {}).get("name")
                }
                node["priority"] = {"name": values["Priority"]} if "Priority" in values else None
                node["status"] = {"name": values["Status"]} if "Status" in values else None
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
      fields(first: 50) {
        nodes { ... on ProjectV2SingleSelectField { id name options { id name } } }
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
    fields = graphql(FIELD, owner=owner, number=number)["user"]["projectV2"]["fields"]["nodes"]
    field = next((f for f in fields if f and f.get("name") == "Priority"), None)
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
        if "agent:ready" in names or "agent:working" in names:
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


CLAIM_HOURS = 24
STALE_NOTE = "<!-- fleet-board:stale-claim -->"
WORKFLOW_LABELS = {"proposed", "agent:ready", "agent:working", "agent:pause", "needs:anthony", "blocked"}


def status_field(owner, number):
    """Return (field id, {lower-case option name: option id}) for Status."""
    fields = graphql(FIELD, owner=owner, number=number)["user"]["projectV2"]["fields"]["nodes"]
    field = next((f for f in fields if f and f.get("name") == "Status"), None)
    if not field:
        return None, {}
    return field["id"], {o["name"].lower(): o["id"] for o in field.get("options") or []}


def claim_state(owner, repo, num):
    """When agent:working was last added, and whether an open PR links the issue."""
    pages = gh(f"repos/{owner}/{repo}/issues/{num}/timeline?per_page=100", "--paginate", "--slurp")
    claimed, has_pr, noted = None, False, False
    for event in (e for page in pages for e in page):
        kind = event.get("event")
        if kind == "labeled" and (event.get("label") or {}).get("name") == "agent:working":
            claimed, noted = event["created_at"], False
        elif kind == "commented" and STALE_NOTE in (event.get("body") or ""):
            noted = True  # already flagged since the latest claim
        elif kind == "cross-referenced":
            src = (event.get("source") or {}).get("issue") or {}
            if "pull_request" in src and src.get("state") == "open":
                has_pr = True
    if claimed:
        claimed = datetime.fromisoformat(claimed.replace("Z", "+00:00"))
    return claimed, has_pr, noted


def wanted_status(names, is_pr, has_pr):
    """The Status a card's labels call for, or None to leave it alone.

    Blocked wins over everything, so a card waiting on me or on another issue
    never looks like it is moving. A card with `agent:pause` or `lead` keeps
    whatever Status I gave it.
    """
    if is_pr:
        return "In review"
    if "agent:pause" in names or "lead" in names:
        return None
    if "blocked" in names or "needs:anthony" in names:
        return "Blocked"
    if "agent:working" in names:
        return "In review" if has_pr else "Building"
    if "agent:ready" in names:
        return "Ready"
    if "proposed" in names:
        return "Proposed"
    return None


def sync_status(owner, number, apply, repo_items):
    """Status follows labels; untriaged issues get `proposed`; stale claims get flagged."""
    project_id, cards = project_items(owner, number)
    field_id, options = status_field(owner, number)
    if not field_id:
        print("Board has no Status field; leaving Status alone.")
    cutoff = datetime.now(timezone.utc) - timedelta(hours=CLAIM_HOURS)
    moved = triaged = flagged = 0
    missing_options = set()
    for content_id, node in cards.items():
        item = repo_items.get(content_id)
        if not item:
            continue
        c = node["content"]
        repo, num = c["repository"]["name"], c["number"]
        names = {n["name"] for n in c["labels"]["nodes"]}
        is_pr = c.get("__typename") == "PullRequest"
        is_bot = (item.get("user") or {}).get("type") == "Bot"

        # Untriaged: an open issue nobody labelled. Give it `proposed` so it
        # lands in Proposed and in the planner's and my queue.
        if not is_pr and not is_bot and not names & (WORKFLOW_LABELS | {"lead"}):
            print(f"  + {repo}#{num}: no workflow label -> proposed")
            if apply:
                gh(f"repos/{owner}/{repo}/issues/{num}/labels", "-X", "POST", "-f", "labels[]=proposed")
            names.add("proposed")
            triaged += 1

        has_pr = False
        if not is_pr and "agent:working" in names:
            claimed, has_pr, noted = claim_state(owner, repo, num)
            if claimed and claimed <= cutoff and not has_pr and not noted and "needs:anthony" not in names:
                hours = int((datetime.now(timezone.utc) - claimed).total_seconds() // 3600)
                print(f"  ! {repo}#{num}: claimed {hours}h ago, no open PR -> needs:anthony")
                if apply:
                    gh(f"repos/{owner}/{repo}/issues/{num}/labels", "-X", "POST", "-f", "labels[]=needs:anthony")
                    gh(
                        f"repos/{owner}/{repo}/issues/{num}/comments", "-X", "POST", "-f",
                        f"body={STALE_NOTE}\nThis issue was claimed (`agent:working`) {hours} hours ago "
                        "and no open PR links to it, so the session may be stuck. Check the claim "
                        "comment above for its session. To release it, remove `agent:working` and "
                        "`needs:anthony` and add `agent:ready` back.",
                    )
                names.add("needs:anthony")
                flagged += 1

        if not field_id:
            continue
        want = wanted_status(names, is_pr, has_pr)
        have = (node.get("status") or {}).get("name") or ""
        # Only open items get here, so a card in Done was reopened: move it too.
        if not want or have.lower() == want.lower():
            continue
        option = options.get(want.lower())
        if not option:
            missing_options.add(want)
            continue
        print(f"  ~ {repo}#{num}: Status {have or 'No status'} -> {want}")
        if apply:
            graphql(SET_FIELD, project=project_id, item=node["id"], field=field_id, option=option)
        moved += 1
    for name in sorted(missing_options):
        print(f"::warning title=fleet-board::Status field has no '{name}' option; add it on the board")
    verb = "Labelled" if apply else "Would label"
    print(f"{verb} {triaged} untriaged issue(s) proposed.")
    verb = "Flagged" if apply else "Would flag"
    print(f"{verb} {flagged} stale claim(s) needs:anthony.")
    verb = "Moved" if apply else "Would move"
    print(f"{verb} {moved} card(s) to the Status their labels call for.")


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
    total, failed, repo_items = 0, False, {}
    for repo in repos:
        try:
            items = open_items(owner, repo)
        except RuntimeError as e:
            print(f"{repo}: could not list issues: {e}")
            failed = True
            continue
        for i in items:
            repo_items[i["node_id"]] = i
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
    repo_node_ids = {k: f"{v['html_url'].split('/')[-3]}#{v['number']}" for k, v in repo_items.items()}
    sync_priority(owner, number, args.apply, repo_node_ids)
    print()
    # Ready first: a card I dragged to Ready gets its label before Status is
    # re-derived from labels, so my move sticks.
    sync_ready(owner, number, args.apply, repo_node_ids)
    print()
    sync_status(owner, number, args.apply, repo_items)
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as e:
        # Annotations show on the run page, so failures are visible without logs.
        print(f"::error title=fleet-board::{str(e)[:900]}")
        sys.exit(1)
