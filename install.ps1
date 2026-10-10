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
$SkillsDir   = Join-Path $RepoDir "skills"
$AgentDefsDir = Join-Path $RepoDir "agents"
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

# Drop what we installed for commands/styles/agents that no longer exist in the repo.
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

# A skill is a directory, and a hard link cannot point at one. Without symlink rights
# use a junction instead: it needs no privilege, and because it names the directory
# rather than its files, a 'git pull' that replaces files inside it keeps it valid.
# Remove a directory link with Remove-Link, never Remove-Item: on Windows PowerShell
# 5.1, Remove-Item on a junction can delete the contents of the directory it points
# at, which here is the repo. The item's own non-recursive Delete() removes only the
# link, live or dangling (a dangling one is a FileInfo on macOS/Linux, where
# [IO.Directory]::Delete would throw).
function Remove-Link($path) { (Get-Item $path -Force).Delete() }

function Link-Dir($src, $dest) {
    $item = Get-Item $dest -Force -ErrorAction SilentlyContinue
    if ($item -and -not $item.LinkType) {
        Write-Host "    SKIP (real directory present - back it up and remove, then re-run): $dest"
        return
    }
    $kind = if ($CanSymlink) { "SymbolicLink" } else { "Junction" }
    if ($DryRun) { Write-Host "    [dry-run] link ($kind) $dest"; return }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    if ($item) { Remove-Link $dest }
    try {
        New-Item -ItemType $kind -Path $dest -Target $src -ErrorAction Stop | Out-Null
        Write-Host "    $dest"
    } catch {
        Write-Host "    FAILED: $dest - $($_.Exception.Message)"
        $script:LinkFailures++
    }
}

# Drop directory links into this repo whose skill no longer exists. No -Directory
# filter: once its target is gone, a dangling symlink is no longer a directory and
# -Directory would skip exactly the links this is here to remove.
function Prune-DirLinks($dir, $srcDir) {
    if (-not (Test-Path $dir)) { return }
    Get-ChildItem $dir -Force | Where-Object { $_.LinkType } | ForEach-Object {
        $tgt = $_.Target | Select-Object -First 1
        if (-not ($_.LinkType -and $tgt -and $tgt.StartsWith($RepoDir))) { return }
        if (Test-Path (Join-Path $srcDir $_.Name)) { return }
        Write-Host "    prune (stale): $($_.FullName)"
        if (-not $DryRun) { Remove-Link $_.FullName }
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

# 3b. Commit signing - sign every commit with the SSH key from step 3. Turning on
# commit.gpgsign without a usable key makes EVERY commit fail ("gpg failed to sign
# the data"), so the key has to be in place before the flag goes on; if it isn't,
# we say so and leave signing OFF rather than hand back a machine that can't commit.
# Paths go into git config with forward slashes - backslashes are escape characters
# in the config file, and a Windows path is written there verbatim.
$SignKeyPub = "$SshKey.pub"
$Signers    = Join-Path $env:USERPROFILE ".ssh\allowed_signers"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "    commit signing: SKIPPED (no git - install it, then re-run)"
} elseif (-not (Test-Path $SignKeyPub)) {
    Write-Host "    commit signing: SKIPPED (no public key at $SignKeyPub) - left OFF"
    Write-Host "      enabling it without a key breaks every commit; make one:  ssh-keygen -t ed25519"
} else {
    $SignFmt = (git config --global gpg.format 2>$null)
    $SignKey = (git config --global user.signingkey 2>$null)
    if ($SignKey -and $SignFmt -ne 'ssh') {
        # An OpenPGP/x509 setup is already here; replacing it would break their signing.
        $Shown = if ($SignFmt) { $SignFmt } else { 'openpgp' }
        Write-Host "    commit signing: existing $Shown setup - leaving as-is"
    } else {
        $KeyPath     = $SignKeyPub.Replace('\', '/')
        $SignersPath = $Signers.Replace('\', '/')
        if ($DryRun) {
            Write-Host "    [dry-run] git config --global gpg.format ssh"
            Write-Host "    [dry-run] git config --global user.signingkey $KeyPath"
            Write-Host "    [dry-run] git config --global commit.gpgsign true"
            Write-Host "    commit signing: would enable (ssh, $KeyPath)"
        } else {
            git config --global gpg.format ssh
            git config --global user.signingkey $KeyPath
            git config --global commit.gpgsign true
            Write-Host "    commit signing: on (ssh, $KeyPath)"
        }

        # Local verification only. Without an allowed-signers file commits still sign
        # and GitHub still verifies them, but `git log --show-signature` errors out and
        # %G? reports N - which reads like signing is broken when it isn't.
        $SignerEmail = (git config --global user.email 2>$null)
        $KeyData = ((Get-Content $SignKeyPub -Raw).Trim() -split '\s+')[0, 1] -join ' '
        if (-not $SignerEmail) {
            Write-Host "      allowed_signers: skipped (no git user.email - set it, then re-run)"
        } elseif ((Test-Path $Signers) -and (Select-String -Path $Signers -SimpleMatch $KeyData -Quiet)) {
            if (-not $DryRun) { git config --global gpg.ssh.allowedSignersFile $SignersPath }
            Write-Host "      allowed_signers: already lists this key"
        } elseif ($DryRun) {
            Write-Host "      [dry-run] add '$SignerEmail' to $Signers; set gpg.ssh.allowedSignersFile"
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path $Signers) | Out-Null
            Add-Content -Path $Signers -Value "$SignerEmail $KeyData"
            git config --global gpg.ssh.allowedSignersFile $SignersPath
            Write-Host "      allowed_signers: added $SignerEmail"
        }
        Write-Host "      add the key to GitHub as a SIGNING key (one time per account):"
        Write-Host "        https://github.com/settings/ssh/new  -> Key type: Signing Key"
    }
}

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

Write-Host "==> Skills (~/.claude/skills/)"
Prune-DirLinks (Join-Path $ClaudeDir "skills") $SkillsDir
Get-ChildItem $SkillsDir -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") } |
    ForEach-Object { Link-Dir $_.FullName (Join-Path $ClaudeDir "skills\$($_.Name)") }

Write-Host "==> Agents (~/.claude/agents/)"
Prune-Dir (Join-Path $ClaudeDir "agents") $AgentDefsDir
Get-ChildItem $AgentDefsDir -Filter "*.md" | Where-Object { $_.Name -ne "README.md" } | ForEach-Object {
    Link-File $_.FullName (Join-Path $ClaudeDir "agents\$($_.Name)")
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
# The profile wiring below bakes this checkout's path into $PROFILE. Each block sits
# between sentinel lines so a re-run can find it again: appended if missing,
# rewritten in place if it differs (install.ps1 ran from another checkout, or the
# repo moved), left alone if it already matches. $legacy matches an older form of
# a block that had no closing sentinel, so it gets replaced rather than duplicated.
function Set-ProfileBlock($path, $label, $block, $legacy) {
    $lines = $block -split "`r`n"
    $text  = if (Test-Path $path) { Get-Content $path -Raw } else { $null }
    if ($null -eq $text) { $text = "" }
    $m = [regex]::Match($text, "(?s)" + [regex]::Escape($lines[0]) + ".*?" + [regex]::Escape($lines[-1]))
    if (-not $m.Success -and $legacy) { $m = [regex]::Match($text, $legacy) }
    if ($m.Success -and ($m.Value -replace "`r", "") -eq ($block -replace "`r", "")) {
        Write-Host "    $label already wired: $path"; return
    }
    $verb = if ($m.Success) { "updated" } else { "added" }
    if ($DryRun) { Write-Host "    [dry-run] $verb $label in $path"; return }
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    if ($m.Success) {
        $text = $text.Substring(0, $m.Index) + $block + $text.Substring($m.Index + $m.Length)
        Set-Content -Path $path -Value $text -NoNewline
    } else {
        Add-Content -Path $path -Value "`r`n$block"
    }
    Write-Host "    $verb $label in $path"
}

# Load secrets.env into each new PowerShell session.
$SecBlock = @(
    "# >>> ai-tools secrets >>>"
    "`$__sec = `"$Secrets`""
    "if (Test-Path `$__sec) {"
    "  Get-Content `$__sec | Where-Object { `$_ -match '^\s*[^#].*=' } | ForEach-Object {"
    "    `$k, `$v = `$_ -split '=', 2"
    "    [Environment]::SetEnvironmentVariable(`$k.Trim(), `$v.Trim().Trim('`"'), `"Process`")"
    "  }"
    "}"
    "# <<< ai-tools secrets <<<"
) -join "`r`n"
# Pre-sentinel form: a "# ai-tools secrets" line, then the loader up to its closing
# brace (the only unindented one).
$SecLegacy = '(?s)# ai-tools secrets\r?\n\$__sec = .*?\r?\n\}(?=\r?\n|$)'
Set-ProfileBlock $PROFILE "secrets loader" $SecBlock $SecLegacy

# Wire the homelab hl-* commands into $PROFILE. Guarded (no error if the homelab
# repo isn't cloned here). Override the checkout path with $env:HOMELAB_DIR.
Write-Host "==> Homelab hl-* commands ($PROFILE)"
if ($env:HOMELAB_DIR) {
    $HlDirLine = "`$HomelabDir = `"$env:HOMELAB_DIR`""           # bake the explicit path
} else {
    $HlDirLine = "`$HomelabDir = if (`$env:HOMELAB_DIR) { `$env:HOMELAB_DIR } else { `"`$HOME\Projects\homelab`" }"
}
$HlBlock = @(
    "# >>> homelab hl-* >>>"
    $HlDirLine
    "if (Test-Path `"`$HomelabDir\shell\aliases.ps1`") { . `"`$HomelabDir\shell\aliases.ps1`" }"
    "# <<< homelab hl-* <<<"
) -join "`r`n"
Set-ProfileBlock $PROFILE "hl-*" $HlBlock

# Wire the shell profile (nav + git aliases, ai-refresh, PSReadLine, Starship) into
# BOTH PowerShell profiles - Windows PowerShell 5.1 and PowerShell 7 keep separate
# $PROFILE paths, and either may be the one a terminal opens.
Write-Host "==> Shell profile (aliases, ai-refresh, PSReadLine, Starship)"
$ShBlock = @(
    "# >>> ai-tools shell >>>"
    ". `"$RepoDir\shell\profile.ps1`""
    "# <<< ai-tools shell <<<"
) -join "`r`n"
$MyDocs = [Environment]::GetFolderPath('MyDocuments')
foreach ($pf in @(
    (Join-Path $MyDocs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1")
    (Join-Path $MyDocs "PowerShell\Microsoft.PowerShell_profile.ps1")
)) { Set-ProfileBlock $pf "shell profile" $ShBlock }

Write-Host "==> MCP servers (user scope)"
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "    'claude' CLI not found - skipping (install Claude Code, then re-run)"
} else {
    # Register each server, or skip it (and unregister any earlier copy) because its
    # stdio command isn't installed here or a ${VAR} it needs is empty in
    # secrets.env. Retired servers are unregistered outright.
    $cfg = Get-Content $McpJson -Raw | ConvertFrom-Json
    $sec = @{}
    if (Test-Path $Secrets) {
        Get-Content $Secrets | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
            $k, $v = $_ -split '=', 2
            $sec[$k.Trim()] = $v.Trim().Trim('"')
        }
    }
    foreach ($name in $cfg._retired) {
        if ($DryRun) { Write-Host "    [dry-run] unregister (retired): $name"; continue }
        claude mcp remove $name -s user 2>$null | Out-Null
        Write-Host "    unregistered (retired): $name"
    }
    foreach ($name in $cfg.mcpServers.PSObject.Properties.Name) {
        $srv  = $cfg.mcpServers.$name
        $json = $srv | ConvertTo-Json -Depth 20 -Compress
        $empty = @([regex]::Matches($json, '\$\{(\w+)\}') | ForEach-Object { $_.Groups[1].Value } |
                   Where-Object { -not $sec[$_] } | Select-Object -Unique)
        $why = if ($srv.command -and -not (Get-Command $srv.command -ErrorAction SilentlyContinue)) {
            "'$($srv.command)' not installed"
        } elseif ($empty) { "set $($empty -join ', ') in secrets.env" }
        if ($DryRun) {
            if ($why) { Write-Host "    [dry-run] skip: $name ($why)" } else { Write-Host "    [dry-run] register: $name" }
            continue
        }
        claude mcp remove $name -s user 2>$null | Out-Null
        if ($why) { Write-Host "    skipped: $name ($why)"; continue }
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
