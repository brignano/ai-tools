# Install ai-tools global Claude context on Windows.
# Run once per machine in PowerShell. Re-run anytime to update.
# Requires PowerShell 5.1+ (built into Windows 10/11).

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$CommandsDir = Join-Path $ClaudeDir "commands"

Write-Host "==> Creating ~/.claude directories"
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
New-Item -ItemType Directory -Force -Path $CommandsDir | Out-Null

Write-Host "==> Symlinking CLAUDE.md"
$claudeMd = Join-Path $ClaudeDir "CLAUDE.md"
$sourceMd = Join-Path $RepoDir "claude\CLAUDE.md"
if (Test-Path $claudeMd) { Remove-Item $claudeMd -Force }
New-Item -ItemType SymbolicLink -Path $claudeMd -Target $sourceMd | Out-Null

Write-Host "==> Symlinking commands"
Get-ChildItem -Path (Join-Path $RepoDir "claude\commands") -Filter "*.md" | ForEach-Object {
    $dest = Join-Path $CommandsDir $_.Name
    if (Test-Path $dest) { Remove-Item $dest -Force }
    New-Item -ItemType SymbolicLink -Path $dest -Target $_.FullName | Out-Null
    Write-Host "    linked $($_.Name)"
}

Write-Host ""
Write-Host "Done. Global Claude context is active."
Write-Host "Commands available in every Claude Code session:"
Get-ChildItem -Path $CommandsDir -Filter "*.md" | Select-Object -ExpandProperty Name
