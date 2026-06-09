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

# Wire the homelab `hl-*` shell commands into the shell profile(s). The block is
# guarded (no error if the homelab repo isn't cloned here) and idempotent (a
# sentinel marker stops re-runs from duplicating it). Override the checkout path
# by running with HOMELAB_DIR set, e.g. on the server: HOMELAB_DIR=/opt/homelab.
wire_homelab_shell() {
  local begin="# >>> homelab hl-* >>>" end="# <<< homelab hl-* <<<" dir_line
  if [ -n "${HOMELAB_DIR:-}" ]; then
    dir_line="HOMELAB_DIR=\"$HOMELAB_DIR\""              # bake the explicit path
  else
    dir_line="HOMELAB_DIR=\"\${HOMELAB_DIR:-\$HOME/Projects/homelab}\""
  fi
  local block
  block="$(printf '%s\n%s\n%s\n%s' \
    "$begin" "$dir_line" \
    'if [ -f "$HOMELAB_DIR/shell/aliases.sh" ]; then . "$HOMELAB_DIR/shell/aliases.sh"; fi' \
    "$end")"

  local wrote=0 rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -e "$rc" ] || continue
    wrote=1
    if grep -qF "$begin" "$rc" 2>/dev/null; then
      echo "    $rc (already wired)"
    else
      printf '\n%s\n' "$block" >> "$rc"
      echo "    $rc"
    fi
  done
  if [ "$wrote" -eq 0 ]; then                            # no rc yet — create the right one
    case "${SHELL:-}" in *zsh) rc="$HOME/.zshrc" ;; *) rc="$HOME/.bashrc" ;; esac
    printf '\n%s\n' "$block" >> "$rc"
    echo "    $rc (created)"
  fi
}

echo "==> Homelab hl-* commands (shell profile)"
wire_homelab_shell

# -- Add new agents below as needed --
# echo "==> Cursor (~/.cursorrules)"
# link "$AGENTS_MD" "$HOME/.cursorrules"

# echo "==> GitHub Copilot"
# link "$AGENTS_MD" "$HOME/.github/copilot-instructions.md"

# echo "==> Windsurf"
# link "$AGENTS_MD" "$HOME/.windsurfrules"

echo ""
echo "Done. AGENTS.md is active for all installed AI tools."
