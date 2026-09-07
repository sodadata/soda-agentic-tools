# Remove everything install.ps1 installs, on native Windows:
#
#   irm https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/uninstall.ps1 | iex
#
# Reports what it finds, asks once, then removes:
#   - the claude plugin 'soda@soda' and the local marketplace 'soda'
#   - the plugin tree at ~\.soda\claude-plugins\soda
#   - the 'soda-mcp' MCP registration (user scope) and the soda-mcp tool
#
# Idempotent and tolerant: anything already gone is reported and skipped, and
# a missing uv or claude never stops the rest of the cleanup.
#
# Nothing outside ~\.soda\claude-plugins, uv's tool directory and your Claude
# Code config is touched.

Set-StrictMode -Version 2.0

function Say([string]$Text) { Write-Host $Text }
function RunQuiet([string]$Exe, [string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    & $Exe @Arguments 2>&1 | Out-Null
    return $LASTEXITCODE
}
# stdout only: Windows PowerShell 5.1 renders a merged stderr line as
# "uv.exe : <text>", which then corrupts whatever the caller parses.
function Capture([string]$Exe, [string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    $text = (& $Exe @Arguments 2>$null | Out-String)
    if ($LASTEXITCODE -ne 0) { return $null }
    return $text.Trim()
}
function Have([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Main {
    $ErrorActionPreference = 'Stop'   # cmdlet failures abort; native helpers run under 'Continue'
    $interactive = (-not $env:SODA_UNINSTALL_NONINTERACTIVE) -and (-not $env:CLAUDECODE) -and
                   (-not $env:CI) -and [Environment]::UserInteractive

    $pluginDir = Join-Path $HOME '.soda\claude-plugins\soda'
    $haveClaude = Have claude
    $haveUv = Have uv

    # ---------------------------------------------------------- discovery

    $found = $false
    $hasPlugin = $false; $hasMarketplace = $false; $hasMcp = $false; $hasTool = $false
    Say "Found:"

    if (Test-Path $pluginDir) {
        $versionFile = Join-Path $pluginDir '.installed-version'
        $version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'unknown' }
        Say "  - plugin tree        $pluginDir (version $version)"
        if ($version -like '*+local') {
            Say "                       note: '+local' means this was installed from a repo"
            Say "                       checkout. Removing it undoes that install too."
        }
        $found = $true
    }

    if ($haveClaude) {
        $plugins = Capture claude @('plugin', 'list')
        if ($plugins -and $plugins -match 'soda@soda') {
            Say "  - claude plugin      soda@soda"; $hasPlugin = $true; $found = $true
        }
        $marketplaces = Capture claude @('plugin', 'marketplace', 'list')
        if ($marketplaces -and $marketplaces -match '(?m)^\s*\S*\s*soda\s*$') {
            Say "  - claude marketplace soda"; $hasMarketplace = $true; $found = $true
        }
        # Exit code only: the output of 'claude mcp get' includes the API key secret.
        if ((RunQuiet claude @('mcp', 'get', 'soda-mcp')) -eq 0) {
            Say "  - mcp registration   soda-mcp"; $hasMcp = $true; $found = $true
        }
    }

    if ($haveUv) {
        $tools = Capture uv @('tool', 'list')
        if ($tools -and $tools -match '(?m)^soda-mcp ') {
            Say "  - uv tool            soda-mcp"; $hasTool = $true; $found = $true
        }
    }

    if (-not $found) {
        Say "  (nothing): the Soda plugin and soda-mcp are not installed."
        return
    }
    if (-not $haveClaude) { Say "  warning: the claude CLI is not on PATH; its registrations cannot be removed." }
    if (-not $haveUv)     { Say "  warning: uv is not on PATH; the soda-mcp tool cannot be removed." }

    Say ""
    if ($interactive) {
        $reply = Read-Host 'Remove all of the above? [y/N]'
        if ($reply -notmatch '^(y|yes)$') { Say "Aborted: nothing was removed."; return }
        Say ""
    }

    # ------------------------------------------------------------ removal

    function Drop([string]$Label, [string]$Exe, [string[]]$Arguments) {
        if ((RunQuiet $Exe $Arguments) -eq 0) { Say "   removed $Label" }
        else { Say "   skipped $Label (not present, or already removed)" }
    }

    Say "== Removing"
    if ($haveClaude) {
        # Plugin before marketplace: a marketplace with an installed plugin
        # from it refuses to go.
        Drop "claude plugin soda@soda"   claude @('plugin', 'uninstall', 'soda@soda')
        Drop "claude marketplace soda"   claude @('plugin', 'marketplace', 'remove', 'soda')
        Drop "mcp registration soda-mcp" claude @('mcp', 'remove', 'soda-mcp', '-s', 'user')
    }
    if ($haveUv) {
        Drop "uv tool soda-mcp" uv @('tool', 'uninstall', 'soda-mcp')
    }
    if (Test-Path $pluginDir) {
        Remove-Item -Recurse -Force $pluginDir
        Say "   removed $pluginDir"
    }
    # Tidy up only the directories we left empty; never touch a ~\.soda holding
    # anything else (credentials, configs and scan artifacts also live there).
    foreach ($dir in (Join-Path $HOME '.soda\claude-plugins'), (Join-Path $HOME '.soda')) {
        if ((Test-Path $dir) -and -not (Get-ChildItem $dir -Force | Select-Object -First 1)) {
            Remove-Item $dir
        }
    }

    Say ""
    Say "Done. Restart Claude Code sessions to drop the skills and the MCP server."
}

try {
    Main
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($PSCommandPath) { exit 1 }
}
