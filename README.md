# Soda plugin for Claude Code

Installs the **Soda plugin** for [Claude Code](https://claude.com/claude-code) —
today the skills for root-cause analysis of data quality incidents (`/rca`) and
incident creation (`/create-incident`) — together with the
[`soda-mcp`](https://github.com/sodadata/soda-mcp) server. Both come from Soda's
private package index, entitled by your Soda Cloud API key.

This repo contains only the installer. Everything that runs on your machine is
in [`install.sh`](install.sh) and [`uninstall.sh`](uninstall.sh) — both short on
purpose so you can audit them before running them.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) — the `claude` CLI, installed
  and logged in ([install instructions](https://docs.claude.com/en/docs/claude-code/setup))
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/) on PATH
- `python3` 3.8 or newer on PATH (used by the `/create-incident` skill)
- A Soda Cloud API key — create one in the Soda Cloud UI under your avatar →
  **Profile** → **API Keys** → **+**
  ([docs](https://docs.soda.io/reference/soda-apis/generate-api-keys)) —
  entitled for Soda's private package index
- macOS or Linux (native Windows is not supported yet)

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
