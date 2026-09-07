# One-line installer for the Soda plugin (Claude Code skills /rca and
# /create-incident) and the soda-mcp server, for native Windows. The macOS and
# Linux installer is install.sh next to this file; WSL uses that one.
#
#   $env:SODA_CLOUD_HOST = "cloud.soda.io"
#   $env:SODA_API_KEY_ID = "<id>"
#   $env:SODA_API_KEY_SECRET = "<secret>"
#   irm https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/install.ps1 | iex
#
# Supported: Windows 11 23H2 or later and Windows Server 2022 or later, x64 or
# ARM64. Older releases are refused unless SODA_INSTALL_ALLOW_UNSUPPORTED_OS=1.
#
# Run it from any directory: everything installs at the user level (~\.soda,
# uv's tool directory and your Claude Code config), never into the current
# folder, and no profile or PATH is modified.
#
# Credentials are read from the environment and are NEVER written to a file by
# this script. They end up in exactly one place: the env block of the soda-mcp
# entry in your Claude Code config.
#
#   SODA_CLOUD_HOST           cloud.soda.io (EU) or cloud.us.soda.io (US)
#   SODA_API_KEY_ID           Soda Cloud -> avatar -> Profile -> API Keys -> +
#   SODA_API_KEY_SECRET
#
# Optional: the private package index, only used while installing:
#
#   SODA_PYPI_INDEX           default team.pypi.cloud.soda.io. Others:
#                             team.pypi.us.soda.io,
#                             enterprise.pypi.cloud.soda.io,
#                             enterprise.pypi.us.soda.io
#   SODA_PYPI_API_KEY_ID      defaults to SODA_API_KEY_ID
#   SODA_PYPI_API_KEY_SECRET  defaults to SODA_API_KEY_SECRET
#
# Idempotent: safe to re-run at any time. It is also the repair tool and the
# update tool (re-running upgrades both soda-mcp and the plugin).
#
# Works in Windows PowerShell 5.1 and PowerShell 7. Deliberately short and
# boring so you can audit it before running.
# Docs: https://github.com/sodadata/soda-agentic-tools

Set-StrictMode -Version 2.0

function Say([string]$Text) { Write-Host $Text }
function Fail([string]$Text) { throw $Text }

# Native commands: run with a local 'Continue' preference so stderr chatter
# never becomes a terminating error (Windows PowerShell 5.1 does that when
# stderr is redirected), and hand back the exit code.
function Run([string]$Exe, [string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    & $Exe @Arguments
    return $LASTEXITCODE
}
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
    # Cmdlet failures (a bad path, an unreadable file) abort at once instead of
    # carrying an empty value forward. Native commands are unaffected: the
    # helpers above run them under a local 'Continue'.
    $ErrorActionPreference = 'Stop'

    # Interactive = a real console, not inside a Claude Code tool call
    # (CLAUDECODE is set there), not CI, and not explicitly overridden.
    $interactive = (-not $env:SODA_INSTALL_NONINTERACTIVE) -and (-not $env:CLAUDECODE) -and
                   (-not $env:CI) -and [Environment]::UserInteractive

    # ------------------------------------------------------------ platform

    Say "== Checking Windows version"
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -notin @('AMD64', 'ARM64')) {
        Fail "unsupported processor architecture '$arch': x64 or ARM64 is required."
    }
    # ProductType 1 = workstation; 2 and 3 = domain controller / server.
    if ($os.ProductType -eq 1) { $minBuild = 22631; $need = "Windows 11 23H2 or later" }
    else                       { $minBuild = 20348; $need = "Windows Server 2022 or later" }
    Say "   $($os.Caption) build $build ($arch)"
    if ($build -lt $minBuild) {
        if ($env:SODA_INSTALL_ALLOW_UNSUPPORTED_OS) {
            Say "   warning: below the supported floor ($need); continuing because"
            Say "   SODA_INSTALL_ALLOW_UNSUPPORTED_OS is set."
        } else {
            Fail ("this Windows release is not supported: $need is required. " +
                  "Set SODA_INSTALL_ALLOW_UNSUPPORTED_OS=1 to install anyway, at your own risk.")
        }
    }

    # ------------------------------------------------------- prerequisites

    Say "== Checking prerequisites"
    if (-not (Have uv)) {
        Fail "uv is not on PATH. Install it: https://docs.astral.sh/uv/getting-started/installation/"
    }
    if (-not (Have claude)) {
        Fail "the claude CLI is not on PATH. Install Claude Code: https://code.claude.com/docs/en/setup"
    }
    if ((RunQuiet claude @('plugin', '--help')) -ne 0) {
        Fail "this Claude Code version has no plugin support. Update Claude Code ('claude update'), then re-run."
    }
    if ((RunQuiet claude @('mcp', '--help')) -ne 0) {
        Fail "this Claude Code version has no MCP support. Update Claude Code ('claude update'), then re-run."
    }
    # 'python' must be a real interpreter: the Microsoft Store app-execution
    # alias is a stub that prints a Store hint and exits 9009.
    $pythonOk = (Have python) -and
        ((RunQuiet python @('-c', 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)')) -eq 0)
    if (-not $pythonOk) {
        Fail ("no working 'python' (3.8 or newer) on PATH. The skills run Python scripts. " +
              "Install it with 'winget install Python.Python.3.12' or from python.org, and if " +
              "'python' opens the Microsoft Store, turn off the python aliases under " +
              "Settings -> Apps -> Advanced app settings -> App execution aliases.")
    }
    $gitBash = (Have git) -and ((Have bash) -or (Test-Path "$env:ProgramFiles\Git\bin\bash.exe"))
    if (-not $gitBash) {
        Say "   note: Git for Windows is not installed. Claude Code then runs the skills'"
        Say "   commands through PowerShell instead of Bash; that works, but Git for Windows"
        Say "   is recommended: https://git-scm.com/downloads/win"
    }
    $uvVersion = (Capture uv @('--version'))
    $claudeVersion = (Capture claude @('--version'))
    # No double quotes inside native arguments: PowerShell 5.1 mangles them.
    $pythonVersion = (Capture python @('-c', 'import platform; print(platform.python_version())'))
    Say "   OK: $uvVersion, claude $claudeVersion, python $pythonVersion"

    $auth = Capture claude @('auth', 'status')
    if ($auth -and $auth -match '"loggedIn":\s*false') {
        Say "   note: claude is not logged in yet. That is fine for installing;"
        Say "   login happens the first time claude starts."
    }

    # --------------------------------------------------------- credentials

    Say "== Checking credentials"
    $missing = @()
    foreach ($name in 'SODA_CLOUD_HOST', 'SODA_API_KEY_ID', 'SODA_API_KEY_SECRET') {
        if (-not [Environment]::GetEnvironmentVariable($name)) { $missing += $name }
    }
    if ($missing.Count -gt 0) {
        Say ""
        Say "ERROR: missing environment variable(s): $($missing -join ' ')"
        Say ""
        Say "Create a Soda Cloud API key (Soda Cloud -> avatar -> Profile -> API Keys -> +)"
        Say "and run the installer with the values set, for example:"
        Say ""
        Say '  $env:SODA_CLOUD_HOST = "cloud.soda.io"'
        Say '  $env:SODA_API_KEY_ID = "<your-api-key-id>"'
        Say '  $env:SODA_API_KEY_SECRET = "<your-api-key-secret>"'
        Say '  irm https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/install.ps1 | iex'
        Say ""
        Say "Set them in the current window only, as above, so the key never lands in a"
        Say "profile. US region: SODA_CLOUD_HOST=cloud.us.soda.io"
        Say ""
        Say "If your Soda Cloud is not on the Team/EU plan, also set SODA_PYPI_INDEX to one"
        Say "of: team.pypi.cloud.soda.io, team.pypi.us.soda.io,"
        Say "enterprise.pypi.cloud.soda.io, enterprise.pypi.us.soda.io"
        Fail "missing credentials"
    }
    $cloudHost = $env:SODA_CLOUD_HOST
    $keyId = $env:SODA_API_KEY_ID
    $keySecret = $env:SODA_API_KEY_SECRET
    $index = if ($env:SODA_PYPI_INDEX) { $env:SODA_PYPI_INDEX } else { 'team.pypi.cloud.soda.io' }
    $indexKeyId = if ($env:SODA_PYPI_API_KEY_ID) { $env:SODA_PYPI_API_KEY_ID } else { $keyId }
    $indexKeySecret = if ($env:SODA_PYPI_API_KEY_SECRET) { $env:SODA_PYPI_API_KEY_SECRET } else { $keySecret }
    Say "   OK: all credentials present"

    # -------------------------------------------------------- what happens

    $pluginDir = Join-Path $HOME '.soda\claude-plugins\soda'
    $uvToolBin = Capture uv @('tool', 'dir', '--bin')
    if (-not $uvToolBin) { Fail "'uv tool dir --bin' failed." }
    $mcpBin = Join-Path $uvToolBin 'soda-mcp.exe'

    Say ""
    Say "About to install, at the user level:"
    Say ""
    Say "  1. soda-mcp        -> $mcpBin"
    Say "                        registered with claude as 'soda-mcp' (user scope),"
    Say "                        carrying your Soda Cloud credentials"
    Say "  2. the soda plugin -> $pluginDir"
    Say "                        registered with claude as marketplace 'soda',"
    Say "                        plugin 'soda@soda' (skills /rca, /create-incident)"
    Say ""
    Say "  Soda Cloud host    : $cloudHost"
    Say "  Private PyPI index : $index"
    if ($indexKeyId -ne $keyId) {
        Say ""
        Say "  note: the package-index API key differs from the Soda Cloud API key."
        Say "  That is a dev/testing setup; customers normally use one key for both."
    }
    Say ""
    Say "Nothing is written into the current directory and no profile or PATH is"
    Say "changed. Your credentials are not written to any file by this script."
    Say ""

    if ($interactive) {
        $reply = Read-Host 'Proceed? [y/N]'
        if ($reply -notmatch '^(y|yes)$') { Say "Aborted: nothing was installed."; return }
        Say ""
    }

    # The index credential is needed only while installing. It is deliberately
    # NOT passed to the soda-mcp registration: soda-mcp is installed as a real
    # tool below, so it never resolves anything from the index at session start.
    $env:UV_INDEX = "https://$([uri]::EscapeDataString($indexKeyId)):$([uri]::EscapeDataString($indexKeySecret))@$index"
    # Trust the Windows certificate store, so a corporate TLS-inspecting proxy
    # with its own root CA does not break the downloads. Process scope only.
    if (-not $env:UV_NATIVE_TLS) { $env:UV_NATIVE_TLS = 'true' }

    try {
        # ------------------------------------------------------- soda-mcp

        Say "== Installing soda-mcp from Soda's private index"
        # soda-mcp depends on 'cryptography', which publishes no Windows ARM64
        # wheel; a native ARM64 Python would try to compile it with Rust and
        # fail. On ARM64, run soda-mcp under a uv-managed x64 Python instead:
        # Windows runs it through its x64 emulation, and every dependency has
        # an x64 wheel. The plugin's own scripts stay on the native Python.
        $mcpPython = @()
        if ($arch -eq 'ARM64') {
            Say "   Windows on ARM: installing soda-mcp under an x64 Python (its 'cryptography'"
            Say "   dependency has no ARM64 wheel); uv downloads that Python once"
            $mcpPython = @('--python', 'cpython-3.12-windows-x86_64-none')
        }
        if ((Run uv (@('tool', 'install', '--force', '-q') + $mcpPython + @('soda-mcp'))) -ne 0) {
            Fail ("soda-mcp install failed. A 401/403 or resolution error means the API key " +
                  "is wrong, or SODA_PYPI_INDEX ($index) is not the index your license " +
                  "and region entitle; verify the key in Soda Cloud. A build error " +
                  "(cargo, maturin, Visual C++) means a dependency has no prebuilt wheel " +
                  "for this Windows architecture; report that to Soda support.")
        }
        if (-not (Test-Path $mcpBin)) {
            Fail "soda-mcp installed but no executable at $mcpBin. Report this to Soda support."
        }
        # Ask uv for the version rather than the binary: soda-mcp takes no
        # arguments and would start a stdio server that never returns.
        $installed = (Capture uv @('tool', 'list')) -split "`n" | Where-Object { $_ -match '^soda-mcp ' } | Select-Object -First 1
        Say "   installed: $installed"

        Say "== Registering soda-mcp with claude (user scope)"
        [void](RunQuiet claude @('mcp', 'remove', 'soda-mcp', '-s', 'user'))
        $addArgs = @('mcp', 'add', 'soda-mcp', '--transport', 'stdio', '--scope', 'user',
                     '-e', "SODA_CLOUD_HOST=$cloudHost",
                     '-e', "SODA_API_KEY_ID=$keyId",
                     '-e', "SODA_API_KEY_SECRET=$keySecret",
                     '--', $mcpBin)
        if ((RunQuiet claude $addArgs) -ne 0) { Fail "could not register soda-mcp with claude." }
        Say "   registered"

        # ---------------------------------------------------- soda plugin

        Say "== Installing the soda plugin from Soda's private index"
        # The wheel unpacks itself into $pluginDir, which is a local Claude Code
        # marketplace, and registers marketplace 'soda' + plugin 'soda@soda'.
        if ((Run uvx @('-qq', '--no-progress', 'soda-plugin@latest', 'install')) -ne 0) {
            Fail ("plugin install failed. A 401/403 or resolution error means the API key " +
                  "is wrong, or SODA_PYPI_INDEX ($index) is not the index your license " +
                  "and region entitle. Verify the key in Soda Cloud.")
        }
    } finally {
        Remove-Item Env:UV_INDEX -ErrorAction SilentlyContinue
    }

    # ---------------------------------------------------------------- report

    $versionFile = Join-Path $pluginDir '.installed-version'
    $version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'unknown' }

    Say ""
    Say "Done."
    Say ""
    Say "  marketplace 'soda'   $pluginDir"
    Say "  plugin 'soda@soda'   version $version"
    $skillsDir = Join-Path $pluginDir 'plugins\soda\skills'
    if (Test-Path $skillsDir) {
        Get-ChildItem $skillsDir -Directory | Where-Object { $_.Name -notlike '_*' } |
            ForEach-Object { Say "    skill /$($_.Name)" }
    }
    Say "  mcp server 'soda-mcp'  $mcpBin (user scope)"
    Say ""
    if ($env:CLAUDE_CONFIG_DIR) {
        Say "Start claude on this install with CLAUDE_CONFIG_DIR still set to"
        Say "  $env:CLAUDE_CONFIG_DIR"
        Say "then check it with /plugin and /mcp inside the session."
    } else {
        Say "Start claude, or restart your running sessions, to pick this up."
        Say "Check it with /plugin and /mcp inside the session."
    }
    Say ""
    Say "To undo everything:"
    Say "  claude plugin uninstall soda@soda"
    Say "  claude plugin marketplace remove soda"
    Say "  claude mcp remove soda-mcp -s user"
    Say "  uv tool uninstall soda-mcp"
    Say "  Remove-Item -Recurse -Force `"$pluginDir`""
}

try {
    Main
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    # As a file (CI, or a downloaded copy) report failure through the exit
    # code; under 'irm | iex' an exit would close the user's console instead.
    if ($PSCommandPath) { exit 1 }
}
