# Install ai-tools on Windows (PowerShell, no WSL). Run once per machine, elevated or
# not: symlinks need Administrator or Developer Mode, and without either the installer
# falls back to hard links (re-run after a 'git pull' to refresh them).
# Re-run anytime to update.
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

# Creating a symlink on Windows needs Administrator or Developer Mode; a hard link
# needs neither but only works inside one volume. Probe once (in TEMP, cleaned up)
# so an unprivileged run links with hard links instead of failing on every file.
function Test-SymlinkSupport {
    $dir  = Join-Path $env:TEMP "ai-tools-symlink-probe-$PID"
    $tgt  = Join-Path $dir "target"
    $link = Join-Path $dir "link"
    try {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        New-Item -ItemType File -Force -Path $tgt | Out-Null
        New-Item -ItemType SymbolicLink -Path $link -Target $tgt -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
    finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
}
$CanSymlink   = Test-SymlinkSupport
$LinkKind     = if ($CanSymlink) { "SymbolicLink" } else { "HardLink" }
$LinkFailures = 0

# What this installer put in ~/.claude, and the content it linked (hashtable keys
# are case-insensitive, so paths match regardless of casing). A hard link doesn't
# survive 'git pull' - git replaces files rather than editing them - so a re-run has
# to refresh a plain file it left behind, while still refusing to clobber a config
# you wrote yourself. The recorded hash tells those two apart.
$Manifest  = Join-Path $ClaudeDir ".ai-tools-links.json"
$Installed = @{}
if (Test-Path $Manifest) {
    $raw = Get-Content $Manifest -Raw
    if ($raw -and $raw.Trim()) {
        try { ($raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $Installed[$_.Name] = $_.Value } }
        catch { Write-Host "    (ignoring unreadable $Manifest)" }
    }
}

function Link-File($src, $dest) {
    if (Test-Path $dest) {
        $item = Get-Item $dest -Force
        if (-not $item.LinkType) {
            if (-not $Installed.ContainsKey($dest)) {
                Write-Host "    SKIP (real file present - back it up and remove, then re-run): $dest"
                return
            }
            # Ours, but no longer a link (git replaced the repo file, or something
            # rewrote this one). Repo wins; keep local edits next to it.
            if ((Get-FileHash $dest).Hash -ne $Installed[$dest]) {
                Write-Host "    relink (edited since install - saving it as $($item.Name).bak): $dest"
                if (-not $DryRun) { Copy-Item $dest "$dest.bak" -Force }
            }
        }
    }
    # Hard links can't cross volumes, so bail before removing what's already there.
    if ($LinkKind -eq "HardLink" -and
        [IO.Path]::GetPathRoot($src) -ne [IO.Path]::GetPathRoot((Split-Path $dest))) {
        Write-Host "    FAILED (repo and $ClaudeDir are on different drives - needs a symlink): $dest"
        Write-Host "      fix: turn on Developer Mode (Settings > System > For developers), or run elevated"
        $script:LinkFailures++
        return
    }
    if ($DryRun) { Write-Host "    [dry-run] link ($LinkKind) $dest"; return }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    if (Test-Path $dest) { Remove-Item $dest -Force }
    try {
        New-Item -ItemType $LinkKind -Path $dest -Target $src -ErrorAction Stop | Out-Null
        $script:Installed[$dest] = (Get-FileHash $src).Hash
        Write-Host "    $dest"
    } catch {
        Write-Host "    FAILED: $dest - $($_.Exception.Message)"
        $script:LinkFailures++
    }
}

# Drop what we installed for commands/styles that no longer exist in the repo.
# Symlinks name their target; hard links don't (and PowerShell 7 reports no target
# at all for them), so go by the manifest and the name the source dir would provide.
function Prune-Dir($dir, $srcDir) {
    if (-not (Test-Path $dir)) { return }
    Get-ChildItem $dir -Force -File | ForEach-Object {
        if (-not $Installed.ContainsKey($_.FullName)) {
            $tgt = $_.Target | Select-Object -First 1                  # pre-manifest symlink
            if (-not ($_.LinkType -and $tgt -and $tgt.StartsWith($RepoDir))) { return }
        }
        if (Test-Path (Join-Path $srcDir $_.Name)) { return }
        Write-Host "    prune (stale): $($_.FullName)"
        if (-not $DryRun) { Remove-Item $_.FullName -Force; $Installed.Remove($_.FullName) }
    }
}

# Prerequisites for the homelab hl-* commands and remote access. Safe, mechanical
# parts are done here; steps needing a human (server password, browser login) are
# printed. See SETUP.md.
$HlHost = "root@10.0.0.201"                              # homelab Docker LXC
$HomelabDirDefault = if ($env:HOMELAB_DIR) { $env:HOMELAB_DIR } else { Join-Path $env:USERPROFILE "Projects\homelab" }
Write-Host "==> Prerequisites"

# 1. Base CLIs
$miss = @(); foreach ($c in 'git','ssh','curl') { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { $miss += $c } }
if ($miss) {
    Write-Host "    MISSING: $($miss -join ' ')"
    Write-Host "      install:  winget install $($miss -join ' ')   (Git.Git, OpenSSH.Client, cURL.cURL)"
} else { Write-Host "    base CLIs (git, ssh, curl): present" }

# 2. Tailscale
if (Get-Command tailscale -ErrorAction SilentlyContinue) {
    tailscale status *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "    tailscale: up" }
    else { Write-Host "    tailscale: installed but DOWN -> run:  tailscale up --accept-routes" }
} else {
    Write-Host "    tailscale: NOT installed"
    Write-Host "      install:  winget install tailscale.tailscale   (or tailscale.com/download)"
    Write-Host "      then:     tailscale up --accept-routes"
}

# 2b. Shell niceties - PowerShell 7 and Starship power the oh-my-zsh-style prompt
if (Get-Command pwsh -ErrorAction SilentlyContinue) { Write-Host "    pwsh (PowerShell 7): present" }
else {
    Write-Host "    pwsh (PowerShell 7): NOT installed - shell profile works on 5.1, but autosuggestions need 7"
    Write-Host "      install:  winget install Microsoft.PowerShell"
}
if (Get-Command starship -ErrorAction SilentlyContinue) { Write-Host "    starship: present" }
else {
    Write-Host "    starship: NOT installed - prompt falls back to the PowerShell default"
    Write-Host "      install:  winget install Starship.Starship"
}

# 2c. Link type - how the ~/.claude config gets wired to this repo
if ($CanSymlink) { Write-Host "    links: symlinks (config follows the repo automatically)" }
else {
    Write-Host "    links: hard links - no Administrator or Developer Mode, so symlinks are unavailable"
    Write-Host "      works the same day to day, but re-run install.ps1 after a 'git pull' to refresh"
    Write-Host "      for symlinks: turn on Developer Mode (Settings > System > For developers), or run elevated"
}

# 3. SSH key - generate if missing; can't auto-authorize (needs the server password)
$SshKey = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
if (Test-Path $SshKey) { Write-Host "    ssh key: present ($SshKey)" }
elseif ($DryRun) { Write-Host "    [dry-run] ssh-keygen -t ed25519 -f $SshKey -N `"`" (no passphrase)" }
else {
    New-Item -ItemType Directory -Force -Path (Split-Path $SshKey) | Out-Null
    ssh-keygen -t ed25519 -f $SshKey -N '""' -q
    if (Test-Path $SshKey) { Write-Host "    ssh key: generated $SshKey (no passphrase)" }
    else { Write-Host "    ssh key: generation FAILED - create one with 'ssh-keygen -t ed25519'" }
}
Write-Host "      authorize on the homelab (one time, Windows has no ssh-copy-id):"
Write-Host "        type `$env:USERPROFILE\.ssh\id_ed25519.pub | ssh $HlHost `"cat >> .ssh/authorized_keys`""

# 4. Homelab repo - the hl-* aliases source from it
if (Test-Path (Join-Path $HomelabDirDefault ".git")) { Write-Host "    homelab repo: present ($HomelabDirDefault)" }
elseif ($DryRun) { Write-Host "    [dry-run] offer to clone homelab into $HomelabDirDefault" }
else {
    $ans = Read-Host "    homelab repo not found at $HomelabDirDefault - clone it now? [y/N]"
    if ($ans -match '^[yY]') { git clone https://github.com/brignano/homelab $HomelabDirDefault; Write-Host "    cloned to $HomelabDirDefault" }
    else { Write-Host "    skipped - clone later:  git clone https://github.com/brignano/homelab $HomelabDirDefault" }
}

Write-Host "==> Context (~/.claude/CLAUDE.md)"
Link-File $AgentsMd (Join-Path $ClaudeDir "CLAUDE.md")

Write-Host "==> Commands (~/.claude/commands/)"
Prune-Dir (Join-Path $ClaudeDir "commands") $CommandsDir
Get-ChildItem $CommandsDir -Filter "*.md" | ForEach-Object {
    Link-File $_.FullName (Join-Path $ClaudeDir "commands\$($_.Name)")
}

Write-Host "==> Output styles (~/.claude/output-styles/)"
Prune-Dir (Join-Path $ClaudeDir "output-styles") $StylesDir
Get-ChildItem $StylesDir -Filter "*.md" | ForEach-Object {
    Link-File $_.FullName (Join-Path $ClaudeDir "output-styles\$($_.Name)")
}

Write-Host "==> Settings (~/.claude/settings.json)"
Link-File $Settings (Join-Path $ClaudeDir "settings.json")

# Record what we linked, so the next run can refresh its own files (see $Manifest).
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    Set-Content -Path $Manifest -Encoding UTF8 -Value (ConvertTo-Json -InputObject $Installed)
}

Write-Host "==> Secrets (secrets.env - gitignored)"
if (-not (Test-Path $Secrets)) {
    if (-not $DryRun) { Copy-Item (Join-Path $RepoDir ".env.example") $Secrets }
    Write-Host "    created from template - FILL IN TOKENS, then open a new shell"
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

# Wire the homelab hl-* commands into $PROFILE. Guarded (no error if the homelab
# repo isn't cloned here) and idempotent (a sentinel marker stops re-runs from
# duplicating it). Override the checkout path with $env:HOMELAB_DIR.
Write-Host "==> Homelab hl-* commands ($PROFILE)"
$HlBegin = "# >>> homelab hl-* >>>"
if ($env:HOMELAB_DIR) {
    $HlDirLine = "`$HomelabDir = `"$env:HOMELAB_DIR`""           # bake the explicit path
} else {
    $HlDirLine = "`$HomelabDir = if (`$env:HOMELAB_DIR) { `$env:HOMELAB_DIR } else { `"`$HOME\Projects\homelab`" }"
}
$HlBlock = @(
    $HlBegin
    $HlDirLine
    "if (Test-Path `"`$HomelabDir\shell\aliases.ps1`") { . `"`$HomelabDir\shell\aliases.ps1`" }"
    "# <<< homelab hl-* <<<"
) -join "`r`n"
if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -SimpleMatch $HlBegin -Quiet)) {
    Write-Host "    $PROFILE already wires hl-*"
} elseif ($DryRun) {
    Write-Host "    [dry-run] append hl-* wiring to $PROFILE"
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $PROFILE) | Out-Null
    Add-Content -Path $PROFILE -Value "`r`n$HlBlock"
    Write-Host "    wired hl-* into $PROFILE"
}

# Wire the shell profile (nav + git aliases, PSReadLine, Starship) into BOTH
# PowerShell profiles - Windows PowerShell 5.1 and PowerShell 7 keep separate
# $PROFILE paths, and either may be the one a terminal opens.
Write-Host "==> Shell profile (aliases, PSReadLine, Starship)"
$ShBegin = "# >>> ai-tools shell >>>"
$ShBlock = @(
    $ShBegin
    ". `"$RepoDir\shell\profile.ps1`""
    "# <<< ai-tools shell <<<"
) -join "`r`n"
$MyDocs = [Environment]::GetFolderPath('MyDocuments')
$ProfilePaths = @(
    (Join-Path $MyDocs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1")
    (Join-Path $MyDocs "PowerShell\Microsoft.PowerShell_profile.ps1")
)
foreach ($pf in $ProfilePaths) {
    if ((Test-Path $pf) -and (Select-String -Path $pf -SimpleMatch $ShBegin -Quiet)) {
        Write-Host "    already wired: $pf"
    } elseif ($DryRun) {
        Write-Host "    [dry-run] append shell wiring to $pf"
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $pf) | Out-Null
        Add-Content -Path $pf -Value "`r`n$ShBlock"
        Write-Host "    wired: $pf"
    }
}

Write-Host "==> MCP servers (user scope)"
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "    'claude' CLI not found - skipping (install Claude Code, then re-run)"
} else {
    $servers = (Get-Content $McpJson -Raw | ConvertFrom-Json).mcpServers
    foreach ($name in $servers.PSObject.Properties.Name) {
        $json = $servers.$name | ConvertTo-Json -Depth 20 -Compress
        if ($DryRun) { Write-Host "    [dry-run] claude mcp add-json $name -s user '<json>'"; continue }
        claude mcp remove $name -s user 2>$null | Out-Null
        claude mcp add-json $name $json -s user 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "    registered: $name" }
        else { Write-Host "    FAILED: $name - register manually with 'claude mcp add-json'" }
    }
}

Write-Host ""
if ($LinkFailures) {
    Write-Host "Done with $LinkFailures link failure(s) above - fix those and re-run install.ps1."
} else {
    Write-Host "Done. Open a new shell so secrets.env is loaded, then run 'claude'."
}
if (-not $CanSymlink) { Write-Host "(hard links in use - re-run this after 'git pull' to pick up changes)" }
if ($DryRun) { Write-Host "(dry-run - nothing was changed)" }
