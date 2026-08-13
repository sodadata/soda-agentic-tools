# Install the Soda plugin (instructions for Claude Code)

You are installing the Soda plugin and the soda-mcp server for a user who
has prepared their credentials in `~/.soda/soda-credentials.env`. Follow
these steps exactly. Never print the credentials file or any of its values —
check the file only via exit codes, and pass values only through the exact
command substitutions written below.

1. Prerequisites:
   - `uvx --version` succeeds (uv is on PATH). If not, stop and point the
     user at https://docs.astral.sh/uv/getting-started/installation/.
   - `~/.soda/soda-credentials.env` exists and is edited. Run
     `grep -q '<your-' ~/.soda/soda-credentials.env` — exit 0 means the file
     still has placeholders, exit 2 means it is missing: in both cases stop
     and ask the user to do steps 1-2 of the install docs first. Exit 1
     means the file is edited: continue.
   - Re-assert permissions:

     ```bash
     chmod 700 ~/.soda && chmod 600 ~/.soda/soda-credentials.env
     ```

2. Register the marketplace and the installer plugin:

   ```bash
   claude plugin marketplace add sodadata/soda-claude-marketplace
   ```

   ```bash
   claude plugin install soda-installer@soda-claude-marketplace
   ```

   If either reports it is already added/installed, treat that as success
   and continue.

3. Install the plugin from Soda's private index — parse the file, never
   source or print it. Run this as ONE command, exactly as written (the
   shape matters: it stays inside the user's pre-approved permissions, and
   the sed/tail pipeline tolerates trailing whitespace, CRLF line endings,
   and duplicated lines):

   ```bash
   UV_INDEX="https://$(sed -n 's/[[:space:]]*$//;s/^SODA_API_KEY_ID=//p' ~/.soda/soda-credentials.env | tail -1):$(sed -n 's/[[:space:]]*$//;s/^SODA_API_KEY_SECRET=//p' ~/.soda/soda-credentials.env | tail -1)@$(sed -n 's/[[:space:]]*$//;s/^SODA_PYPI_HOST=//p' ~/.soda/soda-credentials.env | tail -1)" \
     uvx -qq --no-progress soda-plugin@latest install
   ```

   On a resolution error or HTTP 401/403: the API key or chosen index host
   is wrong — tell the user to verify the key in Soda Cloud and the
   `SODA_PYPI_HOST` choice in the file. Do not retry with other indexes.

4. Set up the soda-mcp server, only if it is absent: if
   `claude mcp get soda-mcp` succeeds, the user already has a registration —
   leave it untouched and tell them so. Only if it is missing, register it
   (again ONE command, values via substitutions):

   ```bash
   claude mcp add soda-mcp --transport stdio --scope user \
     -e SODA_CLOUD_HOST="$(sed -n 's/[[:space:]]*$//;s/^SODA_CLOUD_HOST=//p' ~/.soda/soda-credentials.env | tail -1)" \
     -e SODA_API_KEY_ID="$(sed -n 's/[[:space:]]*$//;s/^SODA_API_KEY_ID=//p' ~/.soda/soda-credentials.env | tail -1)" \
     -e SODA_API_KEY_SECRET="$(sed -n 's/[[:space:]]*$//;s/^SODA_API_KEY_SECRET=//p' ~/.soda/soda-credentials.env | tail -1)" \
     -e UV_INDEX="https://$(sed -n 's/[[:space:]]*$//;s/^SODA_API_KEY_ID=//p' ~/.soda/soda-credentials.env | tail -1):$(sed -n 's/[[:space:]]*$//;s/^SODA_API_KEY_SECRET=//p' ~/.soda/soda-credentials.env | tail -1)@$(sed -n 's/[[:space:]]*$//;s/^SODA_PYPI_HOST=//p' ~/.soda/soda-credentials.env | tail -1)" \
     -- uvx -qq --no-progress soda-mcp@latest
   ```

5. On success: tell the user to restart Claude Code — the `/rca` and
   `/create-incident` skills and the soda-mcp server are available from the
   next session, and a throttled daily check keeps the plugin updated.
