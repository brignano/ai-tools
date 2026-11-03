#!/usr/bin/env bash
# Prints a short hash of the parts of the fleet plugin that only update on
# re-upload (manifest, hooks, commands, agents, skills, the start hook), for the
# start hook's stale-copy check. The rules files are left out: the hook reads
# those live. Usage: content-hash.sh <plugin or repo root>
set -euo pipefail
cd "$1"
command -v sha256sum >/dev/null 2>&1 || exit 1
{
  printf '%s\0' .claude-plugin/plugin.json fleet/plugin/session-start.sh fleet/plugin/content-hash.sh
  find -L hooks commands -type f -print0
  find -L agents -maxdepth 1 -type f -name '*.md' -print0
  find -L skills -mindepth 2 -type f ! -name standard.md -print0
} | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-12
