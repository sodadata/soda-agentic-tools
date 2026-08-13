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
claude --allowedTools "WebFetch(domain:raw.githubusercontent.com),Bash(curl -fsSL --create-dirs -o ~/.soda/install.sh https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install.sh),Bash(bash ~/.soda/install.sh)" \
  "install the soda plugin as described in https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install-soda-plugin.md"
```

Claude fetches [`install-soda-plugin.md`](install-soda-plugin.md), which has
it download and run [`install.sh`](install.sh) (read both — that's exactly
what will run): the script registers this marketplace, installs the
installer plugin, installs the Soda plugin from your private index,
registers `soda-mcp` if it isn't already configured, and Claude then tells
you to restart Claude Code once. The `--allowedTools` list is session-scoped
and pre-approves only the two exact commands the instructions use; anything
else still asks. From then on, a throttled (daily) session-start check keeps
the plugin up to date; new versions apply to the next session.

Everything installs at the **user level**, never in a project folder: the
marketplace registration, plugin installs, and the `soda-mcp` server land in
your Claude Code config (`~/.claude`), the Soda plugin content itself is
unpacked to `~/.soda/claude-plugins/soda`, and your credentials live only in
`~/.soda/soda-credentials.env`. Run the install from any directory — the
skills are then available in every project and session on this machine, and
nothing is written into your repos.

<details>
<summary>Manual install (no agent involved)</summary>

The same result, by hand, using the same auditable
[`install.sh`](install.sh) the agent runs — download it once, run it twice:

```bash
curl -fsSL --create-dirs -o ~/.soda/install.sh \
  https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install.sh

# First run creates ~/.soda/soda-credentials.env and stops for you to edit it
bash ~/.soda/install.sh

# ... edit ~/.soda/soda-credentials.env (API key + region/license hosts) ...

# Second run installs everything: marketplace, installer plugin, the Soda
# plugin from your private index, and soda-mcp (only if absent)
bash ~/.soda/install.sh

# One start — the skills (/rca, /create-incident) and soda-mcp are available
claude
```

The script is idempotent — re-run it any time to repair an install. If you
already created the credentials file in step 1 above, the first run installs
directly. The private PyPI index hosts, for reference:

| License | Region | Index |
| --- | --- | --- |
| Team | EU | `team.pypi.cloud.soda.io` |
| Team | US | `team.pypi.us.soda.io` |
| Enterprise | EU | `enterprise.pypi.cloud.soda.io` |
| Enterprise | US | `enterprise.pypi.us.soda.io` |

Prefer fully hand-driven commands instead of the script? They are exactly
the steps in `install.sh` — read it and run them one by one.

</details>

## Troubleshooting

- **The session opens but the install prompt never runs** — on a machine
  where Claude Code has never been used, the first launch runs first-time
  onboarding (theme, Anthropic login) and discards the command-line prompt.
  Finish onboarding, exit, and run install step 3 again — or simply paste
  the quoted prompt into the open session.
- **Resolution error / 401 / 403 from the index** — the API key is revoked
  or not entitled, or `SODA_PYPI_HOST` (or `UV_INDEX`) is wrong for your
  license/region. Verify the key in Soda Cloud.
- **Nothing installs at session start** — check that `uv` is on PATH and
  that `~/.soda/soda-credentials.env` exists and is edited (or that
  `UV_INDEX` is exported in the environment Claude Code starts from).
- **Rotating an API key** — edit `~/.soda/soda-credentials.env`, run
  `claude mcp remove soda-mcp`, then `bash ~/.soda/install.sh`: it
  re-registers `soda-mcp` with the new key (an existing registration is
  otherwise left untouched), and the plugin's session-start check picks the
  new key up automatically.
- **Repair / manual update at any time** — re-run the idempotent installer:

  ```bash
  bash ~/.soda/install.sh
  ```
