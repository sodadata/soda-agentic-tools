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
— it's short on purpose so you can audit it.

## Prerequisites

Identical to `soda-mcp`, plus the Claude Code CLI:

- [Claude Code](https://claude.com/claude-code) — the `claude` CLI, installed
  and logged in ([install instructions](https://docs.claude.com/en/docs/claude-code/setup))
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/) on PATH
- A Soda Cloud API key (`SODA_API_KEY_ID` / `SODA_API_KEY_SECRET`) — create
  one in the Soda Cloud UI under your avatar → **Profile** → **API Keys** →
  **+** ([docs](https://docs.soda.io/reference/soda-apis/generate-api-keys))
- `UV_INDEX` exported for your license and region:

| License | Region | Index |
| --- | --- | --- |
| Team | EU | `https://team.pypi.cloud.soda.io` |
| Team | US | `https://team.pypi.us.soda.io` |
| Enterprise | EU | `https://enterprise.pypi.cloud.soda.io` |
| Enterprise | US | `https://enterprise.pypi.us.soda.io` |

```bash
export UV_INDEX="https://${SODA_API_KEY_ID}:${SODA_API_KEY_SECRET}@team.pypi.cloud.soda.io"
```

The Soda skills work together with the `soda-mcp` server — set that up too
(see the soda-mcp install docs).

## Install

```bash
claude plugin marketplace add sodadata/soda-claude-marketplace
```

```bash
claude plugin install soda-installer@soda-claude-marketplace
```

That's it. On the next session start the Soda plugin is installed
automatically (or run `/soda-installer:install` to do it right away). From
then on, a throttled (daily) session-start check keeps it up to date; new
versions apply to the next session.

Everything installs at the **user level**, never in a project folder: the
marketplace registration and plugin installs land in your Claude Code config
(`~/.claude`), and the Soda plugin content itself is unpacked to
`~/.soda/claude-plugins/soda`. Run the two commands from any directory — the
skills are then available in every project and session on this machine, and
nothing is written into your repos.

## Troubleshooting

- **Resolution error / 401 / 403 from the index** — `UV_INDEX` is wrong for
  your license/region, or the API key is revoked or not entitled. Verify the
  key in Soda Cloud.
- **Nothing installs at session start** — check that `uv` is on PATH and
  `UV_INDEX` is exported in the environment Claude Code starts from.
- Manual install/update at any time:

  ```bash
  uvx -qq --no-progress soda-plugin@latest install
  ```
