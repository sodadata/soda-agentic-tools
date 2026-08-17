---
description: Install the Soda plugin from Soda's private PyPI
---

Install (or update) the Soda plugin. The whole installation — marketplace,
this installer plugin, the Soda plugin from the private index, and the
`soda-mcp` server — is performed by Soda's public, auditable `install.sh`.
Your job is to download it, run it, and relay the outcome. Follow these
steps exactly. Never print the credentials file
(`~/.soda/claude/soda-credentials.env`) or any of its values, and never ask
the user to paste credentials into the chat.

1. Download the installer — run exactly:

   ```bash
   curl -fsSL --create-dirs -o ~/.soda/claude/install.sh https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install.sh
   ```

2. Run it **non-interactively** — run exactly:

   ```bash
   SODA_INSTALL_NONINTERACTIVE=1 bash ~/.soda/claude/install.sh
   ```

   The variable stops the script from pausing for keyboard input and from
   launching a nested interactive `claude` at the end. Never run it without
   the variable, and never run it through a pseudo-tty.

3. Interpret the outcome for the user:
   - **"still contains placeholder values"** (possibly right after "Created
     ~/.soda/claude/soda-credentials.env") — the user hasn't prepared
     credentials yet. Ask them to edit that file themselves (API key: Soda
     Cloud → avatar → **Profile** → **API Keys** → **+**; the region and
     license hosts are documented in the file), then repeat step 2. Do not
     edit the file for them.
   - **uv or claude missing / no plugin or MCP support** — relay the
     install/update link the script printed and stop.
   - **401/403 or resolution error** — the API key or `SODA_PYPI_HOST`
     choice is wrong for the user's license and region. Tell them to verify
     the key in Soda Cloud and the host in the file. Do not retry with other
     indexes.
   - **"already registered — left untouched"** about `soda-mcp` — relay it;
     an existing registration is deliberately preserved. Rotating a key
     needs `claude mcp remove soda-mcp` before re-running the script.
   - **"Done."** — tell the user to restart Claude Code: the `/rca` and
     `/create-incident` skills and the `soda-mcp` server are available from
     the next session, and a throttled daily check keeps the plugin up to
     date.
