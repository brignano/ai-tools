#!/usr/bin/env python3
"""PreToolUse guard of the fleet plugin: enforces two hard rules from
fleet/README.md ("Hard rules for every agent") so they hold without anyone
having to remember them.

- Never push to the default branch (main or master), including force pushes.
- Never write secrets files (.env, .env.local, ...; .env.example and other
  templates are fine).

Exit 2 blocks the tool call and shows stderr to the model. Anything this script
can't parse is allowed: it must never break a session.
"""
import json
import os
import re
import shlex
import subprocess
import sys

DEFAULT = {"main", "master"}
TEMPLATE = re.compile(r"\.(example|sample|template|dist)$")


def block(msg):
    print(f"Blocked by the fleet plugin: {msg}", file=sys.stderr)
    sys.exit(2)


def is_secret_file(path):
    name = os.path.basename(path or "")
    return (name == ".env" or name.startswith(".env.")) and not TEMPLATE.search(name)


def current_branch(cwd):
    try:
        out = subprocess.run(["git", "-C", cwd or ".", "symbolic-ref", "--short", "-q", "HEAD"],
                             capture_output=True, text=True, timeout=5)
        return out.stdout.strip()
    except Exception:
        return ""


def check_push(command, cwd):
    # Look at each simple command; `git -C dir push ...` included.
    for part in re.split(r"&&|\|\||;|\n", command):
        try:
            words = shlex.split(part)
        except ValueError:
            continue
        if "git" not in words or "push" not in words:
            continue
        g = words.index("git")
        if g > words.index("push"):
            continue
        rest = words[words.index("push") + 1:]
        cdir = cwd
        if "-C" in words[g:words.index("push")]:
            i = words.index("-C", g)
            if i + 1 < len(words):
                cdir = os.path.join(cwd or ".", words[i + 1])
        args = [w for w in rest if not w.startswith("-")]
        refspecs = args[1:]  # args[0] is the remote
        for ref in refspecs:
            dst = ref.lstrip("+").split(":")[-1]
            dst = dst.removeprefix("refs/heads/")
            if dst in DEFAULT:
                block(f"`{part.strip()}` pushes to {dst}. Push a branch and open a PR.")
        if not refspecs and current_branch(cdir) in DEFAULT:
            block(f"`{part.strip()}` would push {current_branch(cdir)}. Push a branch and open a PR.")


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    if tool == "Bash":
        cmd = inp.get("command", "")
        if "push" in cmd and "git" in cmd:
            check_push(cmd, data.get("cwd"))
        if re.search(r"(>|>>|\btee\b)\s*\S*\.env(\.[\w-]+)?(\s|$)", cmd):
            m = re.search(r"(>|>>|\btee\b)\s*(\S*\.env(\.[\w-]+)?)(\s|$)", cmd)
            if m and is_secret_file(m.group(2)):
                block(f"writing {m.group(2)}. Secrets files are Anthony's to edit.")
    elif tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        path = inp.get("file_path") or inp.get("notebook_path") or ""
        if is_secret_file(path):
            block(f"editing {path}. Secrets files are Anthony's to edit.")


if __name__ == "__main__":
    main()
