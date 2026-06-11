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

# Prerequisites for the homelab hl-* commands and remote access. We do the safe,
# mechanical parts (check tools, generate a key, offer to clone) and PRINT the
# steps that need a human (a server password, a browser login). See SETUP.md.
HL_HOST="root@10.0.0.201"                               # homelab Docker LXC
HOMELAB_DIR_DEFAULT="${HOMELAB_DIR:-$HOME/Projects/homelab}"
echo "==> Prerequisites"

# 1. Base CLIs
miss=""
for c in git ssh curl; do command -v "$c" >/dev/null 2>&1 || miss="$miss $c"; done
if [ -n "$miss" ]; then
  echo "    MISSING:$miss"
  case "$(uname -s)" in
    Darwin) echo "      install:  brew install$miss" ;;
    *)      echo "      install:  sudo apt install -y$miss   (Debian/Ubuntu)" ;;
  esac
else
  echo "    base CLIs (git, ssh, curl): present"
fi

# 2. Tailscale — needed to reach the homelab when off the home LAN
if command -v tailscale >/dev/null 2>&1; then
  if tailscale status >/dev/null 2>&1; then
    echo "    tailscale: up"
  else
    echo "    tailscale: installed but DOWN → run:  tailscale up --accept-routes"
  fi
else
  echo "    tailscale: NOT installed"
  case "$(uname -s)" in
    Darwin) echo "      install:  brew install --cask tailscale   (or the App Store)" ;;
    *)      echo "      install:  curl -fsSL https://tailscale.com/install.sh | sh" ;;
  esac
  echo "      then:     tailscale up --accept-routes"
fi

# 3. SSH key — generate if missing; can't auto-authorize (needs the server password)
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ -f "$SSH_KEY" ]; then
  echo "    ssh key: present ($SSH_KEY)"
elif [ "$DRY_RUN" = 1 ]; then
  echo "    [dry-run] ssh-keygen -t ed25519 -f $SSH_KEY -N '' (no passphrase)"
else
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  if ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q; then
    echo "    ssh key: generated $SSH_KEY (no passphrase)"
  else
    echo "    ssh key: generation FAILED — create one with 'ssh-keygen -t ed25519'"
  fi
fi
echo "      authorize on the homelab (one time):  ssh-copy-id $HL_HOST"

# 4. Homelab repo — the hl-* aliases source from it
if [ -d "$HOMELAB_DIR_DEFAULT/.git" ]; then
  echo "    homelab repo: present ($HOMELAB_DIR_DEFAULT)"
elif [ "$DRY_RUN" = 1 ]; then
  echo "    [dry-run] offer to clone homelab into $HOMELAB_DIR_DEFAULT"
elif [ -t 0 ]; then
  printf '    homelab repo not found at %s — clone it now? [y/N] ' "$HOMELAB_DIR_DEFAULT"
  read -r ans
  case "$ans" in
    [yY]*) git clone https://github.com/brignano/homelab "$HOMELAB_DIR_DEFAULT" \
             && echo "    cloned to $HOMELAB_DIR_DEFAULT" ;;
    *)     echo "    skipped — clone later:  git clone https://github.com/brignano/homelab $HOMELAB_DIR_DEFAULT" ;;
  esac
else
  echo "    homelab repo not found at $HOMELAB_DIR_DEFAULT (non-interactive shell, skipping the clone prompt)"
  echo "      clone it:  git clone https://github.com/brignano/homelab $HOMELAB_DIR_DEFAULT"
fi

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

# Wire the homelab `hl-*` shell commands into the same profile. Guarded (no error
# if the homelab repo isn't cloned on this machine) and idempotent (a sentinel
# marker stops re-runs from duplicating it). Override the checkout path with
# HOMELAB_DIR, e.g. on the server: HOMELAB_DIR=/opt/homelab ./install.sh
echo "==> Homelab hl-* commands ($PROFILE)"
HL_BEGIN="# >>> homelab hl-* >>>"
if [ -n "${HOMELAB_DIR:-}" ]; then
  HL_DIR_LINE="HOMELAB_DIR=\"$HOMELAB_DIR\""                       # bake the explicit path
else
  HL_DIR_LINE="HOMELAB_DIR=\"\${HOMELAB_DIR:-\$HOME/Projects/homelab}\""
fi
if grep -qF "$HL_BEGIN" "$PROFILE" 2>/dev/null; then
  echo "    $PROFILE already wires hl-*"
elif [ "$DRY_RUN" = 1 ]; then
  echo "    [dry-run] append hl-* wiring to $PROFILE"
else
  {
    printf '%s\n' "$HL_BEGIN"
    printf '%s\n' "$HL_DIR_LINE"
    printf '%s\n' 'if [ -f "$HOMELAB_DIR/shell/aliases.sh" ]; then . "$HOMELAB_DIR/shell/aliases.sh"; fi'
    printf '%s\n' "# <<< homelab hl-* <<<"
  } >> "$PROFILE"
  echo "    wired hl-* into $PROFILE"
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
# if-form, not `[ ... ] && echo`: the latter returns 1 on a real run (DRY_RUN=0),
# making the whole script exit non-zero even though everything succeeded.
if [ "$DRY_RUN" = 1 ]; then echo "(dry-run — nothing was changed)"; fi
