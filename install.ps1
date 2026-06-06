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

# -- Add new agents below as needed --
# Write-Host "==> Cursor"
# New-Link $AgentsMd (Join-Path $env:USERPROFILE ".cursorrules")

# Write-Host "==> GitHub Copilot"
# New-Link $AgentsMd (Join-Path $env:USERPROFILE ".github\copilot-instructions.md")

# Write-Host "==> Windsurf"
# New-Link $AgentsMd (Join-Path $env:USERPROFILE ".windsurfrules")

Write-Host ""
Write-Host "Done. AGENTS.md is active for all installed AI tools."
