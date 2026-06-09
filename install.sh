#!/usr/bin/env bash
# Install ai-tools on Mac or Linux. Run once per machine; re-run anytime to update.
#   ./install.sh            apply changes
#   ./install.sh --dry-run  show what would change, touch nothing
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_MD="$REPO_DIR/AGENTS.md"
COMMANDS_DIR="$REPO_DIR/commands"
STYLES_DIR="$REPO_DIR/output-styles"
SETTINGS="$REPO_DIR/claude/settings.json"
MCP_JSON="$REPO_DIR/claude/mcp-servers.json"
SECRETS="$REPO_DIR/secrets.env"
CLAUDE_DIR="$HOME/.claude"

run() { if [ "$DRY_RUN" = 1 ]; then echo "    [dry-run] $*"; else "$@"; fi; }

# Symlink src -> dest, but never clobber a real (non-symlink) file.
link() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "    SKIP (real file present — back it up and remove, then re-run): $dest"
    return
  fi
  run mkdir -p "$(dirname "$dest")"
  run ln -sf "$src" "$dest"
  echo "    $dest"
}

# Remove symlinks in $1 that point into this repo but whose target no longer exists
# (a command/style deleted or moved upstream leaves a dangling link otherwise).
prune() {
  local dir="$1" l tgt
  [ -d "$dir" ] || return 0
  for l in "$dir"/*; do
    [ -L "$l" ] || continue
    tgt="$(readlink "$l")"
    case "$tgt" in
      "$REPO_DIR"/*) [ -e "$l" ] || { echo "    prune (stale): $l"; run rm -f "$l"; } ;;
    esac
  done
}

echo "==> Context (~/.claude/CLAUDE.md)"
link "$AGENTS_MD" "$CLAUDE_DIR/CLAUDE.md"

echo "==> Commands (~/.claude/commands/)"
prune "$CLAUDE_DIR/commands"
for f in "$COMMANDS_DIR"/*.md; do link "$f" "$CLAUDE_DIR/commands/$(basename "$f")"; done

echo "==> Output styles (~/.claude/output-styles/)"
prune "$CLAUDE_DIR/output-styles"
for f in "$STYLES_DIR"/*.md; do link "$f" "$CLAUDE_DIR/output-styles/$(basename "$f")"; done

echo "==> Settings (~/.claude/settings.json)"
link "$SETTINGS" "$CLAUDE_DIR/settings.json"

echo "==> Secrets (secrets.env — gitignored)"
if [ ! -f "$SECRETS" ]; then
  run cp "$REPO_DIR/.env.example" "$SECRETS"
  echo "    created from template — FILL IN TOKENS, then open a new shell"
else
  echo "    exists (leaving as-is)"
fi
# Source secrets.env from the shell profile so Claude Code sees the tokens at launch.
case "$(basename "${SHELL:-/bin/bash}")" in
  zsh) PROFILE="$HOME/.zshrc" ;;
  *)   PROFILE="$HOME/.bashrc" ;;
esac
SRC_LINE="[ -f \"$SECRETS\" ] && set -a && . \"$SECRETS\" && set +a  # ai-tools secrets"
if ! grep -qF "ai-tools secrets" "$PROFILE" 2>/dev/null; then
  if [ "$DRY_RUN" = 1 ]; then
    echo "    [dry-run] append secrets-sourcing line to $PROFILE"
  else
    printf '%s\n' "$SRC_LINE" >> "$PROFILE"
    echo "    added sourcing line to $PROFILE"
  fi
else
  echo "    $PROFILE already sources secrets.env"
fi

echo "==> MCP servers (user scope)"
if ! command -v claude >/dev/null 2>&1; then
  echo "    'claude' CLI not found — skipping (install Claude Code, then re-run)"
elif ! command -v python3 >/dev/null 2>&1; then
  echo "    python3 not found — skipping MCP registration"
else
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    json="$(python3 -c "import json,sys; print(json.dumps(json.load(open('$MCP_JSON'))['mcpServers'][sys.argv[1]]))" "$name")"
    if [ "$DRY_RUN" = 1 ]; then
      echo "    [dry-run] claude mcp add-json $name -s user '<json>'"
    else
      claude mcp remove "$name" -s user >/dev/null 2>&1 || true
      if claude mcp add-json "$name" "$json" -s user >/dev/null 2>&1; then
        echo "    registered: $name"
      else
        echo "    FAILED: $name — register manually with 'claude mcp add-json'"
      fi
    fi
  done < <(python3 -c "import json; print('\n'.join(json.load(open('$MCP_JSON'))['mcpServers']))")
fi

echo ""
echo "Done. Open a new shell so secrets.env is loaded, then run 'claude'."
[ "$DRY_RUN" = 1 ] && echo "(dry-run — nothing was changed)"
