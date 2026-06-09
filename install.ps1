# Install ai-tools on Windows (PowerShell, no WSL). Run once per machine as Administrator
# (symlinks need elevation or Developer Mode). Re-run anytime to update.
#   .\install.ps1            apply changes
#   .\install.ps1 -DryRun    show what would change, touch nothing
param([switch]$DryRun)

$RepoDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$AgentsMd    = Join-Path $RepoDir "AGENTS.md"
$CommandsDir = Join-Path $RepoDir "commands"
$StylesDir   = Join-Path $RepoDir "output-styles"
$Settings    = Join-Path $RepoDir "claude\settings.json"
$McpJson     = Join-Path $RepoDir "claude\mcp-servers.json"
$Secrets     = Join-Path $RepoDir "secrets.env"
$ClaudeDir   = Join-Path $env:USERPROFILE ".claude"

function Link-File($src, $dest) {
    if ((Test-Path $dest) -and -not ((Get-Item $dest -Force).LinkType)) {
        Write-Host "    SKIP (real file present — back it up and remove, then re-run): $dest"
        return
    }
    if ($DryRun) { Write-Host "    [dry-run] link $dest"; return }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    if (Test-Path $dest) { Remove-Item $dest -Force }
    New-Item -ItemType SymbolicLink -Path $dest -Target $src | Out-Null
    Write-Host "    $dest"
}

function Prune-Dir($dir) {
    if (-not (Test-Path $dir)) { return }
    Get-ChildItem $dir -Force | Where-Object { $_.LinkType } | ForEach-Object {
        $tgt = $_.Target | Select-Object -First 1
        if ($tgt -and $tgt.StartsWith($RepoDir) -and -not (Test-Path $tgt)) {
            Write-Host "    prune (stale): $($_.FullName)"
            if (-not $DryRun) { Remove-Item $_.FullName -Force }
        }
    }
}

Write-Host "==> Context (~/.claude/CLAUDE.md)"
Link-File $AgentsMd (Join-Path $ClaudeDir "CLAUDE.md")

Write-Host "==> Commands (~/.claude/commands/)"
Prune-Dir (Join-Path $ClaudeDir "commands")
Get-ChildItem $CommandsDir -Filter "*.md" | ForEach-Object {
    Link-File $_.FullName (Join-Path $ClaudeDir "commands\$($_.Name)")
}

Write-Host "==> Output styles (~/.claude/output-styles/)"
Prune-Dir (Join-Path $ClaudeDir "output-styles")
Get-ChildItem $StylesDir -Filter "*.md" | ForEach-Object {
    Link-File $_.FullName (Join-Path $ClaudeDir "output-styles\$($_.Name)")
}

Write-Host "==> Settings (~/.claude/settings.json)"
Link-File $Settings (Join-Path $ClaudeDir "settings.json")

Write-Host "==> Secrets (secrets.env — gitignored)"
if (-not (Test-Path $Secrets)) {
    if (-not $DryRun) { Copy-Item (Join-Path $RepoDir ".env.example") $Secrets }
    Write-Host "    created from template — FILL IN TOKENS, then open a new shell"
} else { Write-Host "    exists (leaving as-is)" }
# Load secrets.env into each new PowerShell session.
$marker = "# ai-tools secrets"
$block = @"
$marker
`$__sec = "$Secrets"
if (Test-Path `$__sec) {
  Get-Content `$__sec | Where-Object { `$_ -match '^\s*[^#].*=' } | ForEach-Object {
    `$k, `$v = `$_ -split '=', 2
    [Environment]::SetEnvironmentVariable(`$k.Trim(), `$v.Trim().Trim('"'), "Process")
  }
}
"@
if (-not (Test-Path $PROFILE) -or -not (Select-String -Path $PROFILE -SimpleMatch $marker -Quiet)) {
    if ($DryRun) { Write-Host "    [dry-run] append secrets loader to $PROFILE" }
    else {
        New-Item -ItemType Directory -Force -Path (Split-Path $PROFILE) | Out-Null
        Add-Content -Path $PROFILE -Value $block
        Write-Host "    added secrets loader to $PROFILE"
    }
} else { Write-Host "    $PROFILE already loads secrets.env" }

Write-Host "==> MCP servers (user scope)"
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "    'claude' CLI not found — skipping (install Claude Code, then re-run)"
} else {
    $servers = (Get-Content $McpJson -Raw | ConvertFrom-Json).mcpServers
    foreach ($name in $servers.PSObject.Properties.Name) {
        $json = $servers.$name | ConvertTo-Json -Depth 20 -Compress
        if ($DryRun) { Write-Host "    [dry-run] claude mcp add-json $name -s user '<json>'"; continue }
        claude mcp remove $name -s user 2>$null | Out-Null
        claude mcp add-json $name $json -s user 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "    registered: $name" }
        else { Write-Host "    FAILED: $name — register manually with 'claude mcp add-json'" }
    }
}

Write-Host ""
Write-Host "Done. Open a new shell so secrets.env is loaded, then run 'claude'."
if ($DryRun) { Write-Host "(dry-run — nothing was changed)" }
