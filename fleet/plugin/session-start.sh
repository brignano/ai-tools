#!/usr/bin/env bash
# SessionStart hook of the fleet plugin (.claude-plugin/plugin.json).
#
# The plugin already ships the skills, subagents and commands. This hook adds
# the rules: it prints the global AGENTS.md and fleet/README.md, which become
# session context. It reads them from the live repo when it can, so a merged
# rule reaches the next session without rebuilding the plugin. Without network
# it falls back to the copy inside the plugin. Never fails the session.
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LIVE="$HOME/.ai-tools"

if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  # Cloud session: fetch the latest rules (shallow, quiet, bounded).
  if [ -d "$LIVE/.git" ]; then
    timeout 30 git -C "$LIVE" pull -q --ff-only 2>/dev/null || true
  else
    timeout 60 git clone -q --depth 1 https://github.com/brignano/ai-tools "$LIVE" 2>/dev/null || true
  fi
fi
# On my devices ~/.ai-tools is the install.sh checkout that ai-refresh keeps current.
SRC="$ROOT"
[ -f "$LIVE/fleet/README.md" ] && [ -f "$LIVE/AGENTS.md" ] && SRC="$LIVE"

# install.sh links AGENTS.md as ~/.claude/CLAUDE.md, which Claude Code already
# loads; printing it again would duplicate it.
if ! cmp -s "$HOME/.claude/CLAUDE.md" "$SRC/AGENTS.md" 2>/dev/null; then
  echo "# Global context (brignano/ai-tools AGENTS.md)"
  cat "$SRC/AGENTS.md" 2>/dev/null
  echo
fi
echo "# Fleet standard (brignano/ai-tools fleet/README.md)"
cat "$SRC/fleet/README.md" 2>/dev/null
exit 0
