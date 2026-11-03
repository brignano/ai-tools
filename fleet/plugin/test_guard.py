#!/usr/bin/env python3
"""Table test for guard.py. Run: python3 fleet/plugin/test_guard.py (build.sh runs it)."""
import json
import os
import subprocess
import sys
import tempfile

GUARD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "guard.py")


def repo(branch):
    d = tempfile.mkdtemp()
    subprocess.run(["git", "init", "-q", "-b", branch, d], check=True)
    return d


def rc(payload):
    p = subprocess.run([sys.executable, GUARD], input=payload, capture_output=True, text=True)
    return p.returncode


def bash(cmd, cwd):
    return json.dumps({"tool_name": "Bash", "tool_input": {"command": cmd}, "cwd": cwd})


def edit(path, tool="Edit"):
    return json.dumps({"tool_name": tool, "tool_input": {"file_path": path}})


main, feat = repo("main"), repo("feat")
CASES = [
    # (payload, expected exit code)
    (bash("git push origin main", feat), 2),
    (bash("git push origin +HEAD:refs/heads/master", feat), 2),
    (bash(f"git -C {main} push --force origin HEAD:main", feat), 2),
    (bash("git push", main), 2),
    (bash("git push -u origin HEAD", main), 2),
    (bash("git push origin @", main), 2),
    (bash(f"cd {main} && git push", feat), 2),
    (bash("git push -u origin feat", feat), 0),
    (bash("git push", feat), 0),
    (bash("git push origin HEAD", feat), 0),
    (bash("git stash push -m wip", main), 0),
    (bash("git log --grep push", main), 0),
    (bash("git commit -m push", main), 0),
    (bash("git log --oneline | grep push", main), 0),
    (bash("echo hi > .env", feat), 2),
    (bash("echo x | tee .env.local", feat), 2),
    (bash("echo x > .env.example", feat), 0),
    (edit("/r/.env.local", "Write"), 2),
    (edit("/r/.env"), 2),
    (edit("/r/.env.example"), 0),
    (edit("/r/src/env.ts"), 0),
    ("garbage", 0),
    (json.dumps({"tool_name": "Bash", "tool_input": {"command": None}}), 0),
    (json.dumps({"tool_name": "Bash"}), 0),
]

failed = 0
for payload, want in CASES:
    got = rc(payload)
    if got != want:
        failed += 1
        print(f"FAIL want {want} got {got}: {payload}")
print(f"guard: {len(CASES) - failed}/{len(CASES)} passed")
sys.exit(1 if failed else 0)
