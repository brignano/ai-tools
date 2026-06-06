#!/usr/bin/env bash
# Install ai-tools global Claude context on Mac or Linux.
# Run once per machine. Re-run anytime to update symlinks.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"

echo "==> Creating ~/.claude directories"
mkdir -p "$COMMANDS_DIR"

echo "==> Symlinking CLAUDE.md"
ln -sf "$REPO_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

echo "==> Symlinking commands"
for file in "$REPO_DIR/claude/commands/"*.md; do
  name="$(basename "$file")"
  ln -sf "$file" "$COMMANDS_DIR/$name"
  echo "    linked $name"
done

echo ""
echo "Done. Global Claude context is active."
echo "Commands available in every Claude Code session:"
ls "$COMMANDS_DIR"
