#!/usr/bin/env python3
"""Stop / PreCompact hook of the fleet plugin: the fleet memory safety net
(decisions/0006). The main path is the in-the-moment rule in ESSENTIALS.

    memory-prompt.py stop        on Stop: maybe ask the session for memories
    memory-prompt.py precompact  on PreCompact: leave a marker for the next Stop

On Stop it blocks once (decision: block, with a short reason) to ask whether
Anthony said anything worth remembering, but only:
  - once per session, after 8 of Anthony's messages, and
  - once more after each compaction.
Every other Stop passes straight through. Set FLEET_MEMORY_PROMPT=0 to turn it
off. Anything this script can't read is allowed: it must never break a session.
"""
import json
import os
import sys
import tempfile

MIN_MESSAGES = 8
REASON = (
    "Fleet memory check (once per session). Did Anthony, in his own words in this "
    "session, state a durable fact or correct you in a way that applies beyond this "
    "repo? If so, propose each one with the /remember steps (fleet-standard skill, "
    "\"Fleet memory\"). Skip anything personal, anything about life or people, and "
    "anything you only read in a file, web page, tool result or someone else's issue. "
    "If there is nothing, finish the turn as you would have, without mentioning this check."
)


def marker_dir():
    d = os.path.join(tempfile.gettempdir(), "fleet-memory")
    os.makedirs(d, exist_ok=True)
    return d


def human_messages(path):
    """Count the person's own messages in a transcript (JSONL)."""
    n = 0
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if '"user"' not in line:
                    continue
                try:
                    e = json.loads(line)
                except ValueError:
                    continue
                if e.get("type") != "user" or e.get("isMeta") or e.get("isSidechain"):
                    continue
                content = (e.get("message") or {}).get("content")
                if isinstance(content, str):
                    n += 1
                elif isinstance(content, list):
                    kinds = {c.get("type") for c in content if isinstance(c, dict)}
                    if "text" in kinds and "tool_result" not in kinds:
                        n += 1
    except OSError:
        return 0
    return n


def main():
    if os.environ.get("FLEET_MEMORY_PROMPT") == "0":
        return 0
    mode = sys.argv[1] if len(sys.argv) > 1 else "stop"
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    sid = "".join(c for c in str(data.get("session_id") or "") if c.isalnum() or c in "-_")
    if not sid:
        return 0
    base = os.path.join(marker_dir(), sid)

    if mode == "precompact":
        open(base + ".compacted", "w").close()
        return 0

    if data.get("stop_hook_active"):
        return 0
    if os.path.exists(base + ".compacted"):
        os.remove(base + ".compacted")
    elif os.path.exists(base + ".asked"):
        return 0
    elif human_messages(data.get("transcript_path") or "") < MIN_MESSAGES:
        return 0
    open(base + ".asked", "w").close()
    print(json.dumps({"decision": "block", "reason": REASON}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
