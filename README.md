# Soda Claude marketplace

Soda's central [Claude Code](https://claude.com/claude-code) plugin
marketplace. It currently offers one plugin, `soda-installer`, which
installs and auto-updates the **Soda plugin** — today the skills for
root-cause analysis of data quality incidents (`/rca`) and incident
creation (`/create-incident`) — from Soda's private PyPI, entitled by your
Soda Cloud API key.

This repo contains **only distribution machinery** (an install script, an
install command, and a throttled session-start update check). The plugin
content itself is delivered from Soda's private package index. Everything
that runs on your machine is in [`install.sh`](install.sh) and
[`plugins/soda-installer/scripts/update-check.sh`](plugins/soda-installer/scripts/update-check.sh)
— both short on purpose so you can audit them. Your credentials file is
data, never code: it is parsed, not executed.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) — the `claude` CLI, installed
  and logged in ([install instructions](https://docs.claude.com/en/docs/claude-code/setup))
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/) on PATH
- A Soda Cloud API key — create one in the Soda Cloud UI under your avatar →
  **Profile** → **API Keys** → **+**
  ([docs](https://docs.soda.io/reference/soda-apis/generate-api-keys)) —
  entitled for Soda's private PyPI index (your license and region determine
  which; the credentials file lists all four)
- macOS or Linux (native Windows is not supported yet)

## Install

Two options, same result: the Soda skills and the
[`soda-mcp`](https://github.com/sodadata/soda-mcp) server installed at the
**user level** — your Claude Code config (`~/.claude`), the plugin content
under `~/.soda/claude-plugins/soda`, your credentials only in
`~/.soda/claude/soda-credentials.env`; nothing is ever written into your repos.
Both options run the same auditable [`install.sh`](install.sh), and a
throttled (daily) session-start check keeps the plugin up to date
afterwards.

### Option A — install with Claude

Claude performs the installation for you and helps when something goes
wrong. Each action asks for your approval as it happens — this option is
for you if you already work in Claude Code and trust it with those
approvals. In a `claude` session, enter:

```
Install the soda plugin from https://github.com/sodadata/soda-claude-marketplace
```

Claude reads this repo and follows the
[Installation notes for Claude](#installation-notes-for-claude) below: it
downloads and runs `install.sh`, asks you to fill in your credentials file
when that's still needed, and tells you when to restart Claude Code.

### Option B — install with the script directly

One line, from any directory:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install.sh)"
```

The script checks prerequisites, creates `~/.soda/claude/soda-credentials.env` on
first use and **pauses while you edit it** (API key + region/license hosts —
the file documents every choice), installs everything — marketplace,
installer plugin, the Soda plugin from your private index, `soda-mcp` only
if absent — and finishes by **launching `claude`** with the skills
available.

The script is idempotent and keeps a copy at `~/.soda/claude/install.sh` — re-run
it any time to repair an install. The private PyPI index hosts, for
reference:

| License | Region | Index |
| --- | --- | --- |
| Team | EU | `team.pypi.cloud.soda.io` |
| Team | US | `team.pypi.us.soda.io` |
| Enterprise | EU | `enterprise.pypi.cloud.soda.io` |
| Enterprise | US | `enterprise.pypi.us.soda.io` |

## Troubleshooting

- **Resolution error / 401 / 403 from the index** — the API key is revoked
  or not entitled, or `SODA_PYPI_HOST` in `~/.soda/claude/soda-credentials.env` is
  wrong for your license/region. Verify the key in Soda Cloud.
- **Nothing installs at session start** — check that `uv` is on PATH and
  that `~/.soda/claude/soda-credentials.env` exists and is edited (or that
  `UV_INDEX` is exported in the environment Claude Code starts from).
- **Rotating an API key** — edit `~/.soda/claude/soda-credentials.env`, run
  `claude mcp remove soda-mcp`, then `bash ~/.soda/claude/install.sh`: it
  re-registers `soda-mcp` with the new key (an existing registration is
  otherwise left untouched), and the plugin's session-start check picks the
  new key up automatically.
- **Repair / manual update at any time** — re-run the idempotent installer:

  ```bash
  bash ~/.soda/claude/install.sh
  ```

## Installation notes for Claude

This section is for Claude (or another coding agent) performing the
installation because the user asked to install the Soda plugin from this
repository. Follow it exactly.

The entire installation is performed by the public, auditable
[`install.sh`](install.sh) — your job is to download it, run it, and relay
the outcome. Never print the user's credentials file
(`~/.soda/claude/soda-credentials.env`) or any of its values, and never ask the
user to paste credentials into the chat.

1. Download the installer — run exactly:

   ```bash
   curl -fsSL --create-dirs -o ~/.soda/claude/install.sh https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install.sh
   ```

2. Run it **non-interactively** — run exactly:

   ```bash
   SODA_INSTALL_NONINTERACTIVE=1 bash ~/.soda/claude/install.sh
   ```

   The variable stops the script from pausing for keyboard input and from
   launching a nested interactive `claude` at the end (the script also
   auto-detects agent runs via the `CLAUDECODE` env var and a missing tty,
   but be explicit). Never run it without the variable, and never run it
   through a pseudo-tty.

3. Interpret the outcome for the user:
   - **"still contains placeholder values"** (possibly right after "Created
     ~/.soda/claude/soda-credentials.env") — the user hasn't prepared credentials
     yet. Ask them to edit that file themselves (API key: Soda Cloud →
     avatar → Profile → API Keys → +; the region/license hosts are
     documented in the file), then repeat step 2. Do not edit the file for
     them.
   - **uv or claude missing / no plugin or MCP support** — relay the
     install/update link the script printed and stop.
   - **401/403 or resolution error** — the API key or `SODA_PYPI_HOST`
     choice is wrong. Tell the user to verify the key in Soda Cloud and the
     host in the file. Do not retry with other indexes.
   - **"already registered — left untouched"** about soda-mcp — relay it;
     an existing registration is deliberately preserved.
   - **"Done."** — tell the user to restart Claude Code: the `/rca` and
     `/create-incident` skills and the soda-mcp server are available from
     the next session, and a throttled daily check keeps the plugin up to
     date.
