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


GLOBAL_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}


def git_subcommand(words, i):
    """Index of git's subcommand in words, given words[i] == 'git'."""
    i += 1
    while i < len(words):
        w = words[i]
        if w in GLOBAL_WITH_ARG:
            i += 2
        elif w.startswith("-"):
            i += 1
        else:
            return i
    return None


def check_push(command, cwd):
    cdir = cwd or "."
    for part in re.split(r"&&|\|\||[;|&\n]", command):
        try:
            words = shlex.split(part)
        except ValueError:
            continue
        if not words:
            continue
        if words[0] == "cd" and len(words) > 1:
            cdir = os.path.join(cdir, os.path.expanduser(words[1]))
            continue
        if words[0] != "git":
            continue
        sub = git_subcommand(words, 0)
        if sub is None or words[sub] != "push":
            continue
        gdir = cdir
        if "-C" in words[1:sub]:
            k = words.index("-C", 1)
            gdir = os.path.join(cdir, os.path.expanduser(words[k + 1]))
        args = [w for w in words[sub + 1:] if not w.startswith("-")]
        refspecs = args[1:]  # args[0] is the remote
        branch = current_branch(gdir)
        for ref in refspecs:
            dst = ref.lstrip("+").split(":")[-1]
            if dst.startswith("refs/heads/"):
                dst = dst[len("refs/heads/"):]
            if dst in ("HEAD", "@"):
                dst = branch
            if dst in DEFAULT:
                block(f"`{part.strip()}` pushes to {dst}. Push a branch and open a PR.")
        if not refspecs and branch in DEFAULT:
            block(f"`{part.strip()}` would push {branch}. Push a branch and open a PR.")


def main():
    try:
        data = json.load(sys.stdin)
        tool = data.get("tool_name") or ""
        inp = data.get("tool_input") or {}
        if tool == "Bash":
            cmd = inp.get("command") or ""
            if "push" in cmd and "git" in cmd:
                check_push(cmd, data.get("cwd"))
            m = re.search(r"(>|>>|\btee\b)\s*(\S*\.env(\.[\w-]+)?)(\s|$)", cmd)
            if m and is_secret_file(m.group(2)):
                block(f"writing {m.group(2)}. Secrets files are Anthony's to edit.")
        elif tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
            path = inp.get("file_path") or inp.get("notebook_path") or ""
            if is_secret_file(path):
                block(f"editing {path}. Secrets files are Anthony's to edit.")
    except SystemExit:
        raise
    except Exception:
        return  # fail open: never break a session


if __name__ == "__main__":
    main()
