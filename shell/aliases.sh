# ai-tools shell aliases for Mac/Linux (zsh or bash).
# Sourced from ~/.zshrc / ~/.bashrc by install.sh. Prompt is left alone here —
# the Mac already runs oh-my-zsh; shell/profile.ps1 recreates this feel on Windows.

# --- Navigation ---------------------------------------------------------------
alias proj='cd ~/Projects'
alias desk='cd ~/Desktop'
alias docs='cd ~/Documents'
alias dl='cd ~/Downloads'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
mkcd() { mkdir -p "$1" && cd "$1"; }

alias ll='ls -lah'
alias la='ls -lah'

# --- Git (skip if oh-my-zsh's git plugin already defined them) ------------------
if ! command -v gst >/dev/null 2>&1 && ! alias gst >/dev/null 2>&1; then
  alias gst='git status'
  alias ga='git add'
  alias gaa='git add --all'
  alias gb='git branch'
  alias gco='git checkout'
  alias gcb='git checkout -b'
  alias gsw='git switch'
  alias gcmsg='git commit -m'
  alias gd='git diff'
  alias gds='git diff --staged'
  alias gp='git push'
  alias gpsup='git push --set-upstream origin "$(git branch --show-current)"'
  alias gl='git pull'
  alias gf='git fetch'
  alias glog='git log --oneline --decorate --graph'
  alias gsta='git stash push'
  alias gstp='git stash pop'
fi
