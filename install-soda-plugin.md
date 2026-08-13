# Install the Soda plugin (instructions for Claude Code)

You are installing the Soda plugin and the soda-mcp server for a user. The
entire installation is performed by the public, auditable installer script
from this repository — your job is to download it, run it, and relay the
outcome. Never print the user's credentials file
(`~/.soda/soda-credentials.env`) or any of its values, and never ask the
user to paste credentials into the chat.

1. Download the installer — run exactly this command:

   ```bash
   curl -fsSL --create-dirs -o ~/.soda/install.sh https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install.sh
   ```

2. Run it — exactly this command:

   ```bash
   bash ~/.soda/install.sh
   ```

   When run by you the script is non-interactive: it never pauses for input
   and never launches claude itself.

3. Interpret the outcome for the user:
   - **"still contains placeholder values"** (possibly right after "Created
     ~/.soda/soda-credentials.env") — the user hasn't prepared credentials
     yet. Ask them to edit that file themselves (API key: Soda Cloud →
     avatar → Profile → API Keys → +; the region/license hosts are
     documented in the file), then repeat step 2. Do not edit the file for
     them.
   - **uv or claude missing** — relay the install link the script printed
     and stop.
   - **401/403 or resolution error** — the API key or `SODA_PYPI_HOST`
     choice is wrong. Tell the user to verify the key in Soda Cloud and the
     host in the file. Do not retry with other indexes.
   - **"already registered — left untouched"** about soda-mcp — relay it;
     an existing registration is deliberately preserved.
   - **"Done."** — tell the user to restart Claude Code: the `/rca` and
     `/create-incident` skills and the soda-mcp server are available from
     the next session, and a throttled daily check keeps the plugin up to
     date.
