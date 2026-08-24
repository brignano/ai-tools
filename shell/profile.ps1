# ai-tools shell profile for PowerShell (5.1 and 7+).
# Sourced from $PROFILE by install.ps1 — do not copy, edit here and re-open the shell.
# Mirrors the oh-my-zsh feel from the Mac/Linux machines: nav shortcuts, omz-style
# git shorthands, zsh-like history/completion, Starship prompt.

# --- Navigation ---------------------------------------------------------------
function proj { Set-Location "$HOME\Projects" }
function desk { Set-Location "$HOME\Desktop" }
function docs { Set-Location ([Environment]::GetFolderPath('MyDocuments')) }
function dl   { Set-Location "$HOME\Downloads" }
function ..   { Set-Location .. }
function ...  { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function mkcd([string]$dir) { New-Item -ItemType Directory -Force $dir | Out-Null; Set-Location $dir }

# --- Unix-isms ------------------------------------------------------------------
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force @args }
function which([string]$name) { (Get-Command $name -ErrorAction SilentlyContinue).Source }
function touch([string]$file) {
    if (Test-Path $file) { (Get-Item $file).LastWriteTime = Get-Date }
    else { New-Item -ItemType File $file | Out-Null }
}
function grep { $input | Select-String @args }
function open { Invoke-Item @args }

# --- Git (oh-my-zsh git-plugin names) -------------------------------------------
# PowerShell ships aliases that shadow these (gc, gcb, gl, gm, gp, gpv); aliases win
# over functions, so drop the built-ins first.
foreach ($a in 'gc','gcb','gl','gm','gp','gpv') {
    if (Test-Path "Alias:$a") { Remove-Item "Alias:$a" -Force }
}
function gst   { git status @args }
function ga    { git add @args }
function gaa   { git add --all @args }
function gb    { git branch @args }
function gco   { git checkout @args }
function gcb   { git checkout -b @args }
function gsw   { git switch @args }
function gcmsg { git commit -m @args }
function gc    { git commit @args }
function gd    { git diff @args }
function gds   { git diff --staged @args }
function gp    { git push @args }
function gpsup { git push --set-upstream origin (git branch --show-current) }
function gl    { git pull @args }
function gf    { git fetch @args }
function glog  { git log --oneline --decorate --graph @args }
function gsta  { git stash push @args }
function gstp  { git stash pop @args }
function grhh  { git reset --hard @args }
function gclean { git clean -fd @args }

# --- zsh-like line editing (PSReadLine) ------------------------------------------
if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward   # type a prefix, ↑ filters history
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete            # zsh-style completion menu
    # Inline autosuggestions (zsh-autosuggestions) need PSReadLine >= 2.1 — PS7 has it,
    # Windows PowerShell 5.1 ships 2.0 and silently skips this.
    try { Set-PSReadLineOption -PredictionSource History -ErrorAction Stop } catch {}
}

# --- Prompt (Starship, config shared via this repo) -------------------------------
# Per-user zip installs land outside PATH until the next login; pick them up too.
$__starshipUser = "$env:LOCALAPPDATA\Programs\starship\bin"
if (-not (Get-Command starship -ErrorAction SilentlyContinue) -and (Test-Path "$__starshipUser\starship.exe")) {
    $env:Path += ";$__starshipUser"
}
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $env:STARSHIP_CONFIG = Join-Path $PSScriptRoot "starship.toml"
    Invoke-Expression (&starship init powershell)
}
