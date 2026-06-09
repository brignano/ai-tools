# Install ai-tools context on Windows (PowerShell, no WSL required).
# Run once per machine as Administrator. Re-run anytime to update.

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AgentsMd = Join-Path $RepoDir "AGENTS.md"
$CommandsDir = Join-Path $RepoDir "commands"

function New-Link($src, $dest) {
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    if (Test-Path $dest) { Remove-Item $dest -Force }
    New-Item -ItemType SymbolicLink -Path $dest -Target $src | Out-Null
    Write-Host "    $dest"
}

Write-Host "==> Claude Code (~/.claude/)"
New-Link $AgentsMd (Join-Path $env:USERPROFILE ".claude\CLAUDE.md")
Get-ChildItem -Path $CommandsDir -Filter "*.md" | ForEach-Object {
    New-Link $_.FullName (Join-Path $env:USERPROFILE ".claude\commands\$($_.Name)")
}

# Wire the homelab hl-* commands into $PROFILE. Guarded (no error if the homelab
# repo isn't cloned here) and idempotent (a sentinel marker stops re-runs from
# duplicating it). Override the checkout path with $env:HOMELAB_DIR.
Write-Host "==> Homelab hl-* commands (PowerShell `$PROFILE)"
$Begin = "# >>> homelab hl-* >>>"
$End   = "# <<< homelab hl-* <<<"
if ($env:HOMELAB_DIR) {
    $DirLine = "`$HomelabDir = `"$env:HOMELAB_DIR`""   # bake the explicit path
} else {
    $DirLine = "`$HomelabDir = if (`$env:HOMELAB_DIR) { `$env:HOMELAB_DIR } else { `"`$HOME\Projects\homelab`" }"
}
$Block = @(
    $Begin
    $DirLine
    "if (Test-Path `"`$HomelabDir\shell\aliases.ps1`") { . `"`$HomelabDir\shell\aliases.ps1`" }"
    $End
) -join "`r`n"

New-Item -ItemType Directory -Force -Path (Split-Path $PROFILE) | Out-Null
if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -SimpleMatch $Begin -Quiet)) {
    Write-Host "    $PROFILE (already wired)"
} else {
    Add-Content -Path $PROFILE -Value "`r`n$Block"
    Write-Host "    $PROFILE"
}

# -- Add new agents below as needed --
# Write-Host "==> Cursor"
# New-Link $AgentsMd (Join-Path $env:USERPROFILE ".cursorrules")

# Write-Host "==> GitHub Copilot"
# New-Link $AgentsMd (Join-Path $env:USERPROFILE ".github\copilot-instructions.md")

# Write-Host "==> Windsurf"
# New-Link $AgentsMd (Join-Path $env:USERPROFILE ".windsurfrules")

Write-Host ""
Write-Host "Done. AGENTS.md is active for all installed AI tools."
