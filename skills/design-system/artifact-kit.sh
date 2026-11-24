#!/usr/bin/env bash
# artifact-kit.sh — start a claude.ai Artifact on @brignano/design.
#
#   bash artifact-kit.sh <dir> [version]
#
# Puts the package's tokens.css and components.css (verbatim, from the npm
# tarball) into <dir>, and copies starter.html to <dir>/index.html unless one
# is already there. Publish <dir>/index.html with the Artifact tool and pass
# the two stylesheets in `files`, as the last line prints. Version defaults to
# the latest on npm. Re-running only refreshes the stylesheets.
set -euo pipefail

dir="${1:?usage: artifact-kit.sh <dir> [version]}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
version="${2:-$(npm view @brignano/design version 2>/dev/null)}"
[ -n "$version" ] || { echo "artifact-kit: npm view @brignano/design failed" >&2; exit 1; }

mkdir -p "$dir"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
( cd "$tmp" && npm pack "@brignano/design@$version" --silent >/dev/null )
tar xzf "$tmp"/brignano-design-*.tgz -C "$tmp"
cp "$tmp/package/tokens.css" "$tmp/package/components.css" "$dir/"

if [ ! -e "$dir/index.html" ]; then
  sed "s/__DESIGN_VERSION__/$version/" "$here/starter.html" > "$dir/index.html"
fi

echo "@brignano/design $version -> $dir"
echo "publish: file_path=$dir/index.html files={\"tokens.css\":\"$dir/tokens.css\",\"components.css\":\"$dir/components.css\"}"
