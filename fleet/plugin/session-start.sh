#!/usr/bin/env bash
# SessionStart hook of the fleet plugin (.claude-plugin/plugin.json).
#
# The plugin already ships the skills, subagents and commands. This hook adds
# the rules: the global AGENTS.md and the one-page fleet/ESSENTIALS.md, which
# become session context (the full standard is the fleet-standard skill, loaded
# only when a task needs it). It reads them from the live repo when it can, so a
# merged rule reaches the next session without rebuilding the plugin, and
# falls back to the copy inside the plugin. Never fails the session.
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
[ -f "$LIVE/fleet/ESSENTIALS.md" ] && [ -f "$LIVE/AGENTS.md" ] && SRC="$LIVE"

# install.sh links AGENTS.md as ~/.claude/CLAUDE.md, which Claude Code already
# loads; printing it again would duplicate it.
if ! cmp -s "$HOME/.claude/CLAUDE.md" "$SRC/AGENTS.md" 2>/dev/null; then
  echo "# Global context (brignano/ai-tools AGENTS.md)"
  cat "$SRC/AGENTS.md" 2>/dev/null
  echo
fi
echo "# Fleet essentials (brignano/ai-tools fleet/ESSENTIALS.md)"
cat "$SRC/fleet/ESSENTIALS.md" 2>/dev/null

# Stale-copy check: cloud sessions install the plugin from main (cloud-setup.sh),
# so an uploaded zip is a leftover snapshot; tell Anthony when one is running
# and its skills, agents or commands no longer match main.
# The zip carries fleet/plugin/BUILD, the hash of its sources at build time;
# a checkout (my devices) has none and is never stale.
if [ "$SRC" = "$LIVE" ] && [ -f "$ROOT/fleet/plugin/BUILD" ]; then
  here="$(tr -d '[:space:]' < "$ROOT/fleet/plugin/BUILD")"
  main="$(bash "$LIVE/fleet/plugin/content-hash.sh" "$LIVE" 2>/dev/null)"
  if [ -n "$here" ] && [ -n "$main" ] && [ "$here" != "$main" ]; then
    echo
    echo "# Fleet plugin is out of date"
    echo "The fleet plugin running here (content $here) is behind brignano/ai-tools main ($main):"
    echo "its skills, agents or commands changed since it was uploaded. Rules above are current."
    echo "Tell Anthony once, in your first reply, in one line: remove the uploaded fleet plugin"
    echo "under claude.ai Customize > Plugins; the cloud environment installs it from main."
  fi
fi
exit 0
