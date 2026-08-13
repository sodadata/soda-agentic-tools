# Soda Claude marketplace

Soda's central [Claude Code](https://claude.com/claude-code) plugin
marketplace. It currently offers one plugin, `soda-installer`, which
installs and auto-updates the **Soda plugin** — today the skills for
root-cause analysis of data quality incidents (`/rca`) and incident
creation (`/create-incident`) — from Soda's private PyPI, entitled by your
Soda Cloud API key.

This repo contains **only distribution machinery** (an install command and a
throttled session-start update check). The plugin content itself is delivered
from Soda's private package index. Everything that runs on your machine is in
[`plugins/soda-installer/scripts/update-check.sh`](plugins/soda-installer/scripts/update-check.sh)
— it's short on purpose so you can audit it. Your credentials file is data,
never code: it is parsed, not executed.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) — the `claude` CLI, installed
  and logged in ([install instructions](https://docs.claude.com/en/docs/claude-code/setup))
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/) on PATH
- A Soda Cloud API key — create one in the Soda Cloud UI under your avatar →
  **Profile** → **API Keys** → **+**
  ([docs](https://docs.soda.io/reference/soda-apis/generate-api-keys)) —
  entitled for Soda's private PyPI index (your license and region determine
  which; the credentials file below lists all four)
- macOS or Linux (native Windows is not supported yet)

## Install

Three steps — Claude Code performs the actual installation, including the
[`soda-mcp`](https://github.com/sodadata/soda-mcp) server setup if you don't
have it yet:

```bash
# 1. Fetch the credentials template into its private home — the secret never
#    touches a project folder. Safe to re-run: an existing file is never
#    overwritten.
test -f ~/.soda/soda-credentials.env || curl -fsSL --create-dirs \
  -o ~/.soda/soda-credentials.env \
  https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/soda-credentials.env
chmod 700 ~/.soda && chmod 600 ~/.soda/soda-credentials.env

# 2. Edit ~/.soda/soda-credentials.env: fill in your Soda Cloud API key and
#    pick your region/license hosts (the file documents the choices)

# 3. Start Claude Code — any folder — with the install prompt and the
#    session-scoped permissions the install needs
claude --allowedTools "WebFetch(domain:raw.githubusercontent.com),Bash(claude plugin:*),Bash(claude mcp:*),Bash(uvx:*),Bash(grep:*),Bash(sed:*),Bash(tail:*),Bash(chmod:*)" \
  "install the soda plugin as described in https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install-soda-plugin.md"
```

Claude fetches [`install-soda-plugin.md`](install-soda-plugin.md) (read it —
that's exactly what will run), registers this marketplace, installs the
installer plugin, installs the Soda plugin from your private index, registers
`soda-mcp` if it isn't already configured, and tells you to restart Claude
Code once. The `--allowedTools` list is session-scoped and pre-approves only
what those steps use; anything else still asks. From then on, a throttled
(daily) session-start check keeps the plugin up to date; new versions apply
to the next session.

Everything installs at the **user level**, never in a project folder: the
marketplace registration, plugin installs, and the `soda-mcp` server land in
your Claude Code config (`~/.claude`), the Soda plugin content itself is
unpacked to `~/.soda/claude-plugins/soda`, and your credentials live only in
`~/.soda/soda-credentials.env`. Run the install from any directory — the
skills are then available in every project and session on this machine, and
nothing is written into your repos.

<details>
<summary>Manual install (no agent involved)</summary>

The same result, by hand — with your index picked from the table:

| License | Region | Index |
| --- | --- | --- |
| Team | EU | `team.pypi.cloud.soda.io` |
| Team | US | `team.pypi.us.soda.io` |
| Enterprise | EU | `enterprise.pypi.cloud.soda.io` |
| Enterprise | US | `enterprise.pypi.us.soda.io` |

```bash
# Private index access with the API key embedded (or create
# ~/.soda/soda-credentials.env as above and skip the export)
export UV_INDEX="https://<SODA_API_KEY_ID>:<SODA_API_KEY_SECRET>@team.pypi.cloud.soda.io"

claude plugin marketplace add sodadata/soda-claude-marketplace

claude plugin install soda-installer@soda-claude-marketplace

# The first claude start with the installer plugin triggers the Soda plugin
# installation — a restart is needed after it.
claude

# Subsequent sessions have the Soda skills (/rca, /create-incident) installed.
claude
```

Set up the `soda-mcp` server separately per its
[install docs](https://github.com/sodadata/soda-mcp) — same credentials and
index.

</details>

## Troubleshooting

- **Resolution error / 401 / 403 from the index** — the API key is revoked
  or not entitled, or `SODA_PYPI_HOST` (or `UV_INDEX`) is wrong for your
  license/region. Verify the key in Soda Cloud.
- **Nothing installs at session start** — check that `uv` is on PATH and
  that `~/.soda/soda-credentials.env` exists and is edited (or that
  `UV_INDEX` is exported in the environment Claude Code starts from).
- **Rotating an API key** — edit `~/.soda/soda-credentials.env`, run
  `claude mcp remove soda-mcp`, and re-run install step 3: the plugin picks
  up the new key on the next session-start check, and the install re-registers
  `soda-mcp` with the new key (an existing registration is otherwise left
  untouched).
- Manual install/update at any time — needs `UV_INDEX` exported in your
  shell (the credentials file is only read by the session-start check and
  the installer, not by uv itself):

  ```bash
  uvx -qq --no-progress soda-plugin@latest install
  ```
