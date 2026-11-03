#!/usr/bin/env bash
# Build the fleet plugin as one zip to upload at claude.ai (Customize > Plugins),
# which is how every cloud project and thread gets it.
#   fleet/plugin/build.sh [out.zip]     default: dist/fleet-plugin.zip
# The zip holds only what the plugin needs: no workflows, installers or secrets.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
OUT="${1:-dist/fleet-plugin.zip}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac

python3 -c 'import json,sys; [json.load(open(f)) for f in sys.argv[1:]]' \
  .claude-plugin/plugin.json hooks/hooks.json

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/.claude-plugin" "$STAGE/fleet/plugin" "$STAGE/agents" "$STAGE/skills"
cp .claude-plugin/plugin.json .claude-plugin/icon.png "$STAGE/.claude-plugin/"
cp -R hooks commands "$STAGE/"
cp fleet/plugin/session-start.sh fleet/plugin/content-hash.sh "$STAGE/fleet/plugin/"
cp fleet/README.md fleet/ESSENTIALS.md "$STAGE/fleet/"
cp -R fleet/roles "$STAGE/fleet/"
cp AGENTS.md LICENSE "$STAGE/"
cp agents/*.md "$STAGE/agents/"
for d in skills/*/; do
  [ -f "$d/SKILL.md" ] && cp -RL "${d%/}" "$STAGE/skills/"
done

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
(cd "$STAGE" && zip -qr "$OUT" .)
echo "$OUT (content $(bash fleet/plugin/content-hash.sh "$STAGE"))"
