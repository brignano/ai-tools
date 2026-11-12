# Setup script of the claude.ai cloud environment (Default), pasted there verbatim.
# Fleet plugin straight from brignano/ai-tools main, so merges reach every new thread without re-uploading a zip.
if [ -d "$HOME/.ai-tools/.git" ]; then git -C "$HOME/.ai-tools" pull -q --ff-only || true
else git clone -q --depth 1 https://github.com/brignano/ai-tools "$HOME/.ai-tools" || true; fi
if command -v claude >/dev/null && [ -f "$HOME/.ai-tools/.claude-plugin/marketplace.json" ]; then
  claude plugin marketplace add "$HOME/.ai-tools" || true
  claude plugin install fleet@brignano --scope user || true
fi
true
