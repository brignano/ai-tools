#!/usr/bin/env bash
# Install ai-tools context on Mac or Linux.
# Run once per machine. Re-run anytime to update symlinks.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_MD="$REPO_DIR/AGENTS.md"
COMMANDS_DIR="$REPO_DIR/commands"

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  ln -sf "$src" "$dest"
  echo "    $dest"
}

echo "==> Claude Code (~/.claude/)"
link "$AGENTS_MD" "$HOME/.claude/CLAUDE.md"
for file in "$COMMANDS_DIR"/*.md; do
  link "$file" "$HOME/.claude/commands/$(basename "$file")"
done

# -- Add new agents below as needed --
# echo "==> Cursor (~/.cursorrules)"
# link "$AGENTS_MD" "$HOME/.cursorrules"

# echo "==> GitHub Copilot"
# link "$AGENTS_MD" "$HOME/.github/copilot-instructions.md"

# echo "==> Windsurf"
# link "$AGENTS_MD" "$HOME/.windsurfrules"

echo ""
echo "Done. AGENTS.md is active for all installed AI tools."
