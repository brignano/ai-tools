#!/usr/bin/env bash
# Fleet context for cloud sessions. Repos call this from their own SessionStart
# hook. On my devices install.sh already links ai-tools into ~/.claude, so this
# only acts in Claude Code cloud sessions (CLAUDE_CODE_REMOTE=true).
#
# Whatever it prints becomes session context, which is how the global AGENTS.md
# and the fleet standard reach an agent that never ran install.sh.
# Never fails the session.
set -uo pipefail
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

DIR="$HOME/.ai-tools"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull -q --ff-only 2>/dev/null || true
else
  git clone -q --depth 1 https://github.com/brignano/ai-tools "$DIR" 2>/dev/null || exit 0
fi

# Subagents (implementer, Explore, test-runner, reviewer) so the builder can delegate.
mkdir -p "$HOME/.claude/agents"
for f in "$DIR"/agents/*.md; do
  [ "$(basename "$f")" = README.md ] && continue
  ln -sfn "$f" "$HOME/.claude/agents/$(basename "$f")"
done

# Skills (ux-review, design-system, releases, ...) so fleet rules can name them.
mkdir -p "$HOME/.claude/skills"
for d in "$DIR"/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  ln -sfn "${d%/}" "$HOME/.claude/skills/$(basename "$d")"
done

echo "# Global context (brignano/ai-tools AGENTS.md)"
cat "$DIR/AGENTS.md"
echo
echo "# Fleet standard (brignano/ai-tools fleet/README.md)"
cat "$DIR/fleet/README.md"
