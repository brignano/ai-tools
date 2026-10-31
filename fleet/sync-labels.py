#!/usr/bin/env python3
"""Sync fleet/labels.yml to every repo I own.

Dry run by default: prints what it would change and touches nothing.
Pass --apply to make the changes. Uses the `gh` CLI, so it authenticates as
whatever GH_TOKEN (or `gh auth login`) holds.

  python3 fleet/sync-labels.py                    # dry run, every repo
  python3 fleet/sync-labels.py --repo driftwood   # dry run, one repo
  python3 fleet/sync-labels.py --apply            # what the workflow runs

Per repo, in order:
  1. Each label in `labels`: fix its colour and description if they differ.
     If it is missing and an alias exists, rename the alias in place (issues
     keep it). If both exist, add the label to every open issue and PR that
     carries the alias, then delete the alias. Otherwise create it, unless
     `only_if_present` is set.
  2. Each label in `retire`: delete it, but only if no open issue or PR
     carries it. Otherwise report it and leave it.
Labels in neither list are never touched.
"""
import argparse
import json
import subprocess
import sys
import urllib.parse
from pathlib import Path

import yaml

OWNER = "brignano"
CONFIG = Path(__file__).with_name("labels.yml")


def gh(*args, method="GET", fields=None, paginate=False):
    cmd = ["gh", "api", "-X", method, "-H", "Accept: application/vnd.github+json"]
    if paginate:
        cmd += ["--paginate", "--slurp"]
    for k, v in (fields or {}).items():
        cmd += ["-f", f"{k}={v}"]
    cmd += list(args)
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"gh api {' '.join(args)}: {out.stderr.strip() or out.stdout.strip()}")
    if not out.stdout.strip():
        return None
    data = json.loads(out.stdout)
    if paginate:  # --slurp wraps each page in a list
        return [item for page in data for item in page]
    return data


def q(name):
    return urllib.parse.quote(name, safe="")


def load_config():
    cfg = yaml.safe_load(CONFIG.read_text())
    labels = cfg.get("labels") or []
    retire = cfg.get("retire") or []
    seen = set()
    for lab in labels:
        for n in [lab["name"], *(lab.get("aliases") or [])]:
            key = n.lower()
            if key in seen:
                sys.exit(f"labels.yml: '{n}' appears twice")
            seen.add(key)
        lab["color"] = str(lab["color"]).lstrip("#").lower()
        if len(lab["color"]) != 6:
            sys.exit(f"labels.yml: bad colour for '{lab['name']}'")
    for n in retire:
        if n.lower() in seen:
            sys.exit(f"labels.yml: '{n}' is both kept and retired")
    return labels, retire


def list_repos(only):
    if only:
        return [only]
    repos = gh(f"users/{OWNER}/repos?type=owner&per_page=100", paginate=True)
    # The user endpoint hides private repos; the token's own list includes them.
    try:
        repos += gh("user/repos?affiliation=owner&per_page=100", paginate=True)
    except RuntimeError:
        pass
    names = {
        r["name"]
        for r in repos
        if r["owner"]["login"] == OWNER and not r["archived"] and not r["fork"]
    }
    return sorted(names)


def open_items(repo, label):
    """Open issues and PRs carrying `label` (the issues API returns both)."""
    return gh(
        f"repos/{OWNER}/{repo}/issues?state=open&per_page=100&labels={q(label)}",
        paginate=True,
    )


def sync_repo(repo, labels, retire, apply):
    changes, notes = [], []

    def do(desc, *args, **kw):
        changes.append(desc)
        if apply:
            gh(*args, **kw)

    current = {l["name"].lower(): l for l in gh(f"repos/{OWNER}/{repo}/labels?per_page=100", paginate=True)}

    for lab in labels:
        name, color, descr = lab["name"], lab["color"], lab.get("description", "")
        have = current.get(name.lower())
        aliases = [current[a.lower()] for a in lab.get("aliases") or [] if a.lower() in current]

        if have is None and aliases:
            old = aliases.pop(0)
            do(f"rename '{old['name']}' -> '{name}'", f"repos/{OWNER}/{repo}/labels/{q(old['name'])}",
               method="PATCH", fields={"new_name": name, "color": color, "description": descr})
            current.pop(old["name"].lower())
            have = current[name.lower()] = {"name": name, "color": color, "description": descr}

        if have is None:
            if lab.get("only_if_present"):
                continue
            do(f"create '{name}'", f"repos/{OWNER}/{repo}/labels", method="POST",
               fields={"name": name, "color": color, "description": descr})
            current[name.lower()] = {"name": name, "color": color, "description": descr}
        elif have["name"] != name or have["color"].lower() != color or (have.get("description") or "") != descr:
            do(f"restyle '{have['name']}'", f"repos/{OWNER}/{repo}/labels/{q(have['name'])}", method="PATCH",
               fields={"new_name": name, "color": color, "description": descr})

        # Alias and label both exist: move open items over, then drop the alias.
        for old in aliases:
            items = open_items(repo, old["name"])
            for it in items:
                do(f"#{it['number']}: '{old['name']}' -> '{name}'",
                   f"repos/{OWNER}/{repo}/issues/{it['number']}/labels", method="POST",
                   fields={"labels[]": name})
            do(f"delete alias '{old['name']}'", f"repos/{OWNER}/{repo}/labels/{q(old['name'])}", method="DELETE")
            current.pop(old["name"].lower())

    for n in retire:
        have = current.get(n.lower())
        if not have:
            continue
        items = open_items(repo, have["name"])
        if items:
            nums = ", ".join(f"#{i['number']}" for i in items)
            notes.append(f"kept '{have['name']}': still on open {nums}")
            continue
        do(f"retire '{have['name']}'", f"repos/{OWNER}/{repo}/labels/{q(have['name'])}", method="DELETE")

    return changes, notes


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="make the changes (default: dry run)")
    ap.add_argument("--repo", help="sync one repo by name")
    args = ap.parse_args()

    labels, retire = load_config()
    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"{mode}: {len(labels)} labels, {len(retire)} to retire")

    failed = []
    for repo in list_repos(args.repo):
        try:
            changes, notes = sync_repo(repo, labels, retire, args.apply)
        except RuntimeError as e:
            failed.append(repo)
            print(f"\n{repo}: FAILED {e}")
            continue
        print(f"\n{repo}: {len(changes) or 'no'} change(s)")
        for c in changes:
            print(f"  {c}")
        for n in notes:
            print(f"  note: {n}")

    if failed:
        sys.exit(f"\nfailed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
