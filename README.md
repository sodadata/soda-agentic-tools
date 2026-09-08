# Soda plugin for Claude Code

Installs the **Soda plugin** for [Claude Code](https://claude.com/claude-code) —
today the skills for root-cause analysis of data quality incidents (`/rca`) — together with the
[`soda-mcp`](https://github.com/sodadata/soda-mcp) server. Both come from Soda's
private package index, entitled by your Soda Cloud API key.

This repo contains only the installer. Everything that runs on your machine is
in [`install.sh`](install.sh) and [`uninstall.sh`](uninstall.sh) — both short on
purpose so you can audit them before running them.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) — the `claude` CLI, installed
  and logged in ([install instructions](https://docs.claude.com/en/docs/claude-code/setup))
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/) on PATH
- Python 3.8 or newer on PATH: `python3` on macOS and Linux, `python` on
  Windows (the skills run Python scripts)
- A Soda Cloud API key — create one in the Soda Cloud UI under your avatar →
  **Profile** → **API Keys** → **+**
  ([docs](https://docs.soda.io/reference/soda-apis/generate-api-keys)) —
  entitled for Soda's private package index
- One of these platforms:

  | Platform | Supported | Installer |
  | --- | --- | --- |
  | macOS | 13 or later | `install.sh` |
  | Linux | Ubuntu 20.04+, Debian 10+, RHEL 8+ | `install.sh` |
  | Windows, inside WSL 2 | Windows 11 23H2 or later | `install.sh`, run in the WSL distribution |
  | Windows, native | Windows 11 23H2 or later, ARM64 | `install.ps1` — see [Install on Windows](#install-on-windows) |

  On x64 Windows, use WSL 2 for now. Windows 10 is out of Microsoft support
  and is not supported. Under Extended Security Updates the installer can be
  forced with `SODA_INSTALL_ALLOW_UNSUPPORTED_OS=1`, on request and at your
  own risk.

## Feature flag

For now, you will need to enable the feature flag `incidentRcaReportEnabled` 
in your organization settings on Soda Cloud.

## Install

One line, from any directory, with your credentials passed as environment
variables:

```bash
SODA_CLOUD_HOST=cloud.soda.io \
SODA_API_KEY_ID=<your-api-key-id> \
SODA_API_KEY_SECRET=<your-api-key-secret> \
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/install.sh)"
```

Prefixing the command like this keeps your API key out of your shell profile
and out of your shell history.

Set `SODA_CLOUD_HOST=cloud.us.soda.io` for the US region. If your plan is not
Team/EU, also set `SODA_PYPI_INDEX` to your index:

| License | Region | `SODA_PYPI_INDEX` |
| --- | --- | --- |
| Team | EU | `team.pypi.cloud.soda.io` (default) |
| Team | US | `team.pypi.us.soda.io` |
| Enterprise | EU | `enterprise.pypi.cloud.soda.io` |
| Enterprise | US | `enterprise.pypi.us.soda.io` |

The script checks the prerequisites and your credentials, prints exactly what
it is going to do, and asks once before changing anything.

## Usage of the RCA capability

Ideally, add following MCP connection in your Claude Code for an effective RCA:
* MCP connection to your code repositories like GitHub
* MCP connection to your database like Snowflake
* MCP connection to your orchestration like Airflow
* MCP connection to your transformations like dbt

Once that is done, just copy a link of the failing check and paste it in a Claude Code session.  
It will find out it's a failing check and start the RCA skill.

## Install on Windows

Two ways to run Claude Code on Windows, and the plugin follows Claude Code:

- **WSL 2** — open your WSL distribution and use the macOS/Linux
  [install](#install) above, unchanged. Recommended when your IT allows WSL:
  it is the rehearsed path, and the only one where Claude Code's sandboxing
  works.
- **Native Windows** — the PowerShell installer below. Windows 11 23H2 or
  later, on ARM64. On x64, use WSL 2 for now.

Native prerequisites, on top of the list above:

- [Claude Code](https://code.claude.com/docs/en/setup) installed with its
  Windows installer (`irm https://claude.ai/install.ps1 | iex`) or WinGet
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/) —
  `irm https://astral.sh/uv/install.ps1 | iex`
- Python 3.8 or newer as `python` on PATH — `winget install Python.Python.3.12`
  or the python.org installer. If typing `python` opens the Microsoft Store,
  turn off the Python entries under **Settings → Apps → Advanced app settings →
  App execution aliases**: that alias is a stub, not an interpreter, and the
  installer refuses it.
- [Git for Windows](https://git-scm.com/downloads/win), recommended. It gives
  Claude Code a Bash tool; without it Claude Code runs the skills' commands
  through PowerShell, which the skills support but which is less rehearsed.

Then, in PowerShell (5.1 or 7), from any directory:

```powershell
$env:SODA_CLOUD_HOST = "cloud.soda.io"
$env:SODA_API_KEY_ID = "<your-api-key-id>"
$env:SODA_API_KEY_SECRET = "<your-api-key-secret>"
irm https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/install.ps1 | iex
```

Setting the variables in the window like this keeps the key out of your
profile. They apply to the current window only. The same optional variables as
on macOS/Linux apply (`SODA_PYPI_INDEX` and the two `SODA_PYPI_API_KEY_*`
overrides), and the script does the same things in the same order, with these
Windows differences:

- It refuses to run below the supported Windows floor (see
  `SODA_INSTALL_ALLOW_UNSUPPORTED_OS`).
- It sets `UV_NATIVE_TLS=true` for the duration of the install, so uv trusts
  the Windows certificate store. That is what makes the downloads work behind
  a corporate proxy that inspects TLS with its own root CA. Claude Code itself
  follows the system proxy and certificate settings; see
  [network configuration](https://code.claude.com/docs/en/network-config).
- `soda-mcp` lands as `soda-mcp.exe` in uv's tool directory
  (`%USERPROFILE%\.local\bin` by default) and the plugin under
  `%USERPROFILE%\.soda\claude-plugins\soda`. Claude Code keeps its own copy
  under `%USERPROFILE%\.claude\plugins\cache`. If your endpoint policy
  (AppLocker, WDAC) blocks executables under the user profile, those are the
  paths to allow; `soda-mcp.exe` is a uv-generated launcher and is not
  code-signed.
- The plugin's Stop hook is stamped with the absolute path of the Python
  interpreter found at install time, because Windows has no `python3`
  command. Re-run the installer after moving or upgrading Python.
- On **ARM64** Windows, `soda-mcp` is installed under a uv-managed x64
  Python, which Windows runs through its x64 emulation. One of its
  dependencies (`cryptography`) publishes no ARM64 wheel, and a native
  install would try to compile it. uv downloads that Python once, about
  30 MB; everything else, including the plugin's scripts, stays native.

To check the result without starting a session, download and run
[`verify.ps1`](claude/verify.ps1): it checks every registration, starts
`soda-mcp`, and runs the hook and the skill scripts.

To uninstall:

```powershell
irm https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/uninstall.ps1 | iex
```

## What the script does

On approval it runs the following, with `UV_INDEX` pointing at the private index
for the duration of the install only:

```bash
# 1. soda-mcp as a real tool, so no index access is needed at session start
uv tool install --force soda-mcp

# 2. register it by absolute path, carrying your Soda Cloud credentials
claude mcp add soda-mcp --transport stdio --scope user \
  -e SODA_CLOUD_HOST=... -e SODA_API_KEY_ID=... -e SODA_API_KEY_SECRET=... \
  -- "$(uv tool dir --bin)/soda-mcp"

# 3. fetch the plugin and let it unpack itself into
#    ~/.soda/claude-plugins/soda, which is itself a local marketplace
uvx soda-plugin@latest install

#    step 3 in turn runs:
#      claude plugin marketplace add ~/.soda/claude-plugins/soda
#      claude plugin install soda@soda
```

Everything installs at the **user level** — uv's tool directory, `~/.soda`, and
your Claude Code config. Nothing is written into the directory you run it from,
and your shell profile is not modified.

**Your credentials are never written to a file by this script.** They end up in
exactly one place: the `env` block of the `soda-mcp` entry in your Claude Code
config. The `/create-incident` skill reads them back from there, so there is a
single copy to rotate or revoke.

Restart Claude Code afterwards — skills load at session start.

## Check the install

Start a Claude Code session:

```bash
claude
```

Then, inside the session:

- **`/plugin`** — opens the plugin manager. `soda` should be listed as
  installed and enabled, carrying the `rca` and `create-incident` skills.
- **`/mcp`** — lists the MCP servers. `soda-mcp` should show as connected.

The skills themselves are then available as `/rca` and `/create-incident`.

## Update

Re-run the same command. It is idempotent, and upgrades both `soda-mcp` and the
plugin to the current release.

## Uninstall

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/uninstall.sh)"
```

It reports what it finds, asks once, then removes the plugin, the local
marketplace, the `soda-mcp` registration, the `soda-mcp` tool, and
`~/.soda/claude-plugins/soda`.

It also clears anything left by the retired `soda-installer` plugin: that
plugin, its `soda-claude-marketplace` marketplace, its update-check stamp, and
`~/.soda/claude/soda-credentials.env`. That last file holds a Soda Cloud API
key, so it is listed by name in the confirmation prompt before anything goes.

## Environment variables

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `SODA_CLOUD_HOST` | yes | — | Your Soda Cloud host: `cloud.soda.io` (EU) or `cloud.us.soda.io` (US) |
| `SODA_API_KEY_ID` | yes | — | Soda Cloud API key id |
| `SODA_API_KEY_SECRET` | yes | — | Soda Cloud API key secret |
| `SODA_PYPI_INDEX` | no | `team.pypi.cloud.soda.io` | The private package index for your license and region (see the table above) |
| `SODA_PYPI_API_KEY_ID` | no | `SODA_API_KEY_ID` | Use a *different* key for the package index than for Soda Cloud |
| `SODA_PYPI_API_KEY_SECRET` | no | `SODA_API_KEY_SECRET` | As above |
| `SODA_INSTALL_NONINTERACTIVE` | no | — | Set to `1` to skip the confirmation prompt (agents, CI) |
| `SODA_UNINSTALL_NONINTERACTIVE` | no | — | The same, for `uninstall.sh` |
| `SODA_INSTALL_ALLOW_UNSUPPORTED_OS` | no | — | Windows only: set to `1` to install below the supported Windows floor |

The two `SODA_PYPI_*` key variables exist because the key entitled for the
package index is not always the key you use against Soda Cloud. When they
differ, the script says so in its plan output — normal for a test setup, worth
a second look on a customer machine.

## (For developers) Testing the install

To try the installer without touching your own setup, point both `HOME` and
`CLAUDE_CONFIG_DIR` at a scratch directory. Both are needed:
`CLAUDE_CONFIG_DIR` does not follow `HOME`.

| Variable | Redirects |
| --- | --- |
| `HOME` | the plugin tree at `~/.soda/claude-plugins/soda`, and uv's tool directory where the `soda-mcp` binary lands |
| `CLAUDE_CONFIG_DIR` | Claude Code's config — the marketplace, plugin and `soda-mcp` registrations |

```bash
TEST_HOME=/tmp/soda-install-test

HOME=$TEST_HOME \
CLAUDE_CONFIG_DIR=$TEST_HOME/.claude \
SODA_CLOUD_HOST=<your-soda-cloud-host> \
SODA_API_KEY_ID=<your-api-key-id> \
SODA_API_KEY_SECRET=<your-api-key-secret> \
SODA_PYPI_INDEX=<your-index-host> \
SODA_PYPI_API_KEY_ID=<index-key-id> \
SODA_PYPI_API_KEY_SECRET=<index-key-secret> \
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/install.sh)"
```

Then start Claude Code on that install — overriding **only**
`CLAUDE_CONFIG_DIR`, not `HOME`:

```bash
CLAUDE_CONFIG_DIR=$TEST_HOME/.claude claude
```

The registrations store absolute paths into `$TEST_HOME`, so the plugin and
`soda-mcp` still resolve, while your real `HOME` keeps your login keychain
reachable. This is a separate Claude Code profile, so it will ask you to log in
the first time. Overriding `HOME` here as well would hide the keychain on
macOS: login succeeds in the browser but the token cannot be stored, and every
session reports "not logged in".

In that session, use `/plugin` and `/mcp` exactly as in
[Check the install](#check-the-install) to confirm the plugin and the MCP
server came up — this time against the sandbox rather than your own profile.

To remove it, run the [uninstall](#uninstall) command prefixed with the same two
variables used for the install, then `rm -rf $TEST_HOME`.

Avoid `claude mcp get soda-mcp` in a shared terminal or an agent session: it
prints the API key secret in plain text.

### Windows

The same isolation works on Windows with `$env:USERPROFILE` and
`$env:CLAUDE_CONFIG_DIR` pointed at a scratch directory (`HOME` is derived from
`USERPROFILE` there). The [Windows install](.github/workflows/windows-install.yml)
workflow does this on hosted runners: **Actions → Windows install → Run
workflow**. It installs Claude Code, uv and Python on a fresh Windows Server
2022, 2025 and (experimental) Windows 11 ARM64 runner, runs `install.ps1` from
the checkout or from the published copy, runs `verify.ps1`, re-installs under
Windows PowerShell 5.1, then uninstalls and verifies that nothing is left. It
needs the `SODA_API_KEY_ID` / `SODA_API_KEY_SECRET` repository secrets, and
optionally `ANTHROPIC_API_KEY` for the session test. It always tests the
published wheel.

Hosted runners are Windows Server images with an unrestricted user, so
Windows 11 client behaviour (Store aliases, AppLocker, managed policies) and
proxies still need a manual run on a Windows 11 VM. x64 and Windows Server are
exercised only by this workflow, which has not run yet: until it is green, the
platform table above claims only what was verified by hand, Windows 11 on ARM64.

## Troubleshooting

- **`401`/`403` or a resolution error from the index** — the API key is revoked
  or not entitled, or `SODA_PYPI_INDEX` is wrong for your license and region.
  Verify the key in Soda Cloud and check the table above.
- **`/rca` or `/create-incident` not available** — restart Claude Code; skills
  load at session start.
- **`/create-incident` reports that soda-mcp is not registered** — re-run the
  installer, then restart Claude Code. That skill reads its credentials from the
  `soda-mcp` registration.
- **Rotating an API key** — re-run the installer with the new key. It replaces
  the existing `soda-mcp` registration.
- **Windows: "this Windows release is not supported"** — the floor is Windows 11
  23H2 (build 22631). See
  `SODA_INSTALL_ALLOW_UNSUPPORTED_OS`.
- **Windows: "no working 'python'"** — `python` is the Microsoft Store stub or
  missing. Install Python and disable the app execution aliases (see
  [Install on Windows](#install-on-windows)).
- **Windows: certificate or TLS errors from uv behind a corporate proxy** —
  the installer already sets `UV_NATIVE_TLS`. If the download still fails,
  the proxy's root CA is not in the Windows certificate store; ask IT.
- **Windows: the follow-up picker never appears after `/rca`** — the Stop hook's
  interpreter path is stale (Python moved or was upgraded). Re-run the
  installer.
