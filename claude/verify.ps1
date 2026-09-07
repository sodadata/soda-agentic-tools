# Verify a native Windows install of the Soda plugin, without an Anthropic login.
#
#   .\verify.ps1              # after install.ps1: everything must be present and work
#   .\verify.ps1 -Removed     # after uninstall.ps1: nothing may be left
#
# Checks the four registrations, the plugin tree and Claude Code's cached copy,
# that soda-mcp starts under stdio, that the Stop hook runs under the
# interpreter the installer stamped into it, and that the skills' scripts run
# and can read the credentials back. Prints PASS/FAIL per check and exits 1 on
# any failure. Never prints a credential value.
#
# Used by the windows-install GitHub Actions workflow and by hand on a test VM.

[CmdletBinding()]
param([switch]$Removed)

Set-StrictMode -Version 2.0

$script:failures = 0
function Pass([string]$Text) { Write-Host "PASS  $Text" }
function Failed([string]$Text) { Write-Host "FAIL  $Text" -ForegroundColor Red; $script:failures++ }
function Check([bool]$Condition, [string]$Text) { if ($Condition) { Pass $Text } else { Failed $Text } }
# stdout only: PowerShell 5.1 renders a merged stderr line as "x.exe : <text>".
function Capture([string]$Exe, [string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    $text = (& $Exe @Arguments 2>$null | Out-String)
    return @{ Code = $LASTEXITCODE; Text = $text }
}

$os = $null
try { $os = Get-CimInstance Win32_OperatingSystem } catch { }   # absent off Windows
if ($os) { Write-Host "Windows: $($os.Caption) build $($os.BuildNumber) $env:PROCESSOR_ARCHITECTURE" }
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host ""

# Forward slashes throughout: Windows accepts them in every API used here, and
# it lets the same checks be smoke-run on macOS/Linux while developing.
$pluginDir = Join-Path $HOME '.soda/claude-plugins/soda'
$configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$uvToolBin = (Capture uv @('tool', 'dir', '--bin')).Text.Trim()
$mcpBin = Join-Path $uvToolBin 'soda-mcp.exe'

$plugins = (Capture claude @('plugin', 'list')).Text
$marketplaces = (Capture claude @('plugin', 'marketplace', 'list')).Text
$mcpGet = Capture claude @('mcp', 'get', 'soda-mcp')   # contains the secret: never printed
$tools = (Capture uv @('tool', 'list')).Text

if ($Removed) {
    Check (-not (Test-Path $pluginDir))            "plugin tree gone: $pluginDir"
    Check ($plugins -notmatch 'soda@soda')          "claude plugin soda@soda gone"
    Check ($marketplaces -notmatch '(?m)^\s*\S*\s*soda\s*$') "claude marketplace soda gone"
    Check ($mcpGet.Code -ne 0)                      "mcp registration soda-mcp gone"
    Check ($tools -notmatch '(?m)^soda-mcp ')       "uv tool soda-mcp gone"
    Check (-not (Test-Path $mcpBin))                "soda-mcp.exe gone"
    if ($script:failures) { Write-Host ""; Write-Host "$($script:failures) check(s) failed"; exit 1 }
    Write-Host ""; Write-Host "all clear"; exit 0
}

# --------------------------------------------------------------- registrations

Check ($plugins -match 'soda@soda')                                    "claude plugin soda@soda listed"
Check ($plugins -match 'soda@soda[\s\S]*?Status:\s*\S*\s*enabled')     "claude plugin soda@soda enabled"
Check ($marketplaces -match '(?m)^\s*\S*\s*soda\s*$')                  "claude marketplace soda listed"
Check ($mcpGet.Code -eq 0)                                             "mcp registration soda-mcp present"
Check ($mcpGet.Text -match [regex]::Escape($mcpBin))                   "soda-mcp registered by absolute path to the .exe"
foreach ($name in 'SODA_CLOUD_HOST', 'SODA_API_KEY_ID', 'SODA_API_KEY_SECRET') {
    Check ($mcpGet.Text -match "$name=")                               "soda-mcp registration carries $name"
}
Check ($mcpGet.Text -notmatch 'UV_INDEX')                              "index credential not persisted in the registration"
Check ($tools -match '(?m)^soda-mcp ')                                 "uv tool soda-mcp installed"
Check (Test-Path $mcpBin)                                              "soda-mcp.exe exists"

# ---------------------------------------------------------- soda-mcp starts

$mcpList = Capture claude @('mcp', 'list')
$sodaLine = ($mcpList.Text -split "`n" | Where-Object { $_ -match '^\s*soda-mcp:' } | Select-Object -First 1)
Check ([bool]$sodaLine -and $sodaLine -match 'Connected')              "soda-mcp connects under stdio ('claude mcp list')"
if ($sodaLine) { Write-Host "      $($sodaLine.Trim())" }

# -------------------------------------------------------------- plugin tree

$versionFile = Join-Path $pluginDir '.installed-version'
Check (Test-Path $versionFile)                                         "plugin tree installed at $pluginDir"
$version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { '' }
Write-Host "      version $version"
$tree = Join-Path $pluginDir 'plugins/soda'
foreach ($rel in 'skills/rca/SKILL.md', 'skills/create-incident/SKILL.md', 'hooks/hooks.json',
                 'hooks/require_followup_picker.py', 'skills/_lib/soda_public_api.py') {
    Check (Test-Path (Join-Path $tree $rel))                           "tree has $rel"
}
$manifest = Join-Path $tree '.claude-plugin/plugin.json'
Check ((Test-Path $manifest) -and ((Get-Content $manifest -Raw | ConvertFrom-Json).version -eq $version)) "plugin.json stamped with $version"

# Claude Code serves its own copy from plugins\cache\<marketplace>\<plugin>\<version>
# ('+' becomes '-'); that copy is what sessions actually load.
$cache = Join-Path $configDir "plugins/cache/soda/soda/$($version -replace '\+', '-')"
Check (Test-Path (Join-Path $cache 'skills/rca/SKILL.md'))            "claude's cached copy present: $cache"
$root = if (Test-Path $cache) { $cache } else { $tree }

# ------------------------------------------------------------------ hook

$hooks = Get-Content (Join-Path $root 'hooks/hooks.json') -Raw | ConvertFrom-Json
$hook = $hooks.hooks.Stop[0].hooks[0]
Write-Host "      hook command: $($hook.command)"
$interpreter = Get-Command $hook.command -ErrorAction SilentlyContinue
Check ([bool]$interpreter)                                            "hook interpreter resolves: $($hook.command)"
if ($interpreter) {
    $hookScript = $hook.args[0] -replace '\$\{CLAUDE_PLUGIN_ROOT\}', $root
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "soda-verify-$PID"
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $transcript = Join-Path $tmp 'transcript.jsonl'
    $skillDir = (Join-Path $root 'skills/rca')
    @(
        '{"type":"user","message":{"content":"investigate the failing check"}}'
        ('{"type":"user","isMeta":true,"message":{"content":"Base directory for this skill: ' + ($skillDir -replace '\\', '\\') + '\nDo the RCA."}}')
        '{"type":"assistant","message":{"content":[{"type":"text","text":"Root cause: ..."}]}}'
    ) | Set-Content -Encoding ascii $transcript
    $payloadPath = ($transcript -replace '\\', '\\')
    $out = ('{"transcript_path":"' + $payloadPath + '"}') | & $interpreter.Source $hookScript 2>&1 | Out-String
    Check ($LASTEXITCODE -eq 0 -and $out -match '"decision":\s*"block"')  "Stop hook blocks a turn that loaded /rca without the picker (Windows-style path)"
    $out = ('{"transcript_path":"' + $payloadPath + '","stop_hook_active":true}') | & $interpreter.Source $hookScript 2>&1 | Out-String
    Check ($LASTEXITCODE -eq 0 -and -not $out.Trim())                  "Stop hook lets the turn end once it already asked"
    Remove-Item -Recurse -Force $tmp
}

# --------------------------------------------------------- skill scripts

$coverage = Capture python @((Join-Path $root 'skills/rca/scripts/check_coverage.py'))
$verdict = $null
try { $verdict = $coverage.Text | ConvertFrom-Json } catch { }
Check ($coverage.Code -eq 0 -and $verdict -and $verdict.available -eq $true) "check_coverage.py reads the MCP list under 'python'"
Check ($verdict -and $verdict.qualitySignal -eq $true)                 "check_coverage.py sees soda-mcp as the quality signal"

$lib = Join-Path $root 'skills/_lib'
$code = "import sys; sys.path.insert(0, r'$lib'); import soda_public_api as s; print(' '.join(sorted(s.mcp_credentials())))"
$creds = Capture python @('-c', $code)
Check ($creds.Code -eq 0 -and $creds.Text.Trim() -eq 'SODA_API_KEY_ID SODA_API_KEY_SECRET SODA_CLOUD_HOST') "create-incident credential lookup finds all three via 'claude mcp get'"

Write-Host ""
if ($script:failures) { Write-Host "$($script:failures) check(s) failed"; exit 1 }
Write-Host "all checks passed"
exit 0
