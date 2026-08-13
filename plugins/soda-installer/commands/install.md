---
description: Install the Soda plugin from Soda's private PyPI
---

Install (or update) the Soda plugin. Follow these steps exactly. Never print
the credentials file or any of its values.

1. Check prerequisites before running anything:
   - `uv` must be on PATH (https://docs.astral.sh/uv/getting-started/installation/).
   - Credentials for Soda's private PyPI index, one of:
     - The environment variable `UV_INDEX`, set to the index for the user's
       license and region with their Soda Cloud API key embedded as Basic
       auth, e.g.
       `https://$SODA_API_KEY_ID:$SODA_API_KEY_SECRET@team.pypi.cloud.soda.io`
       (indexes: `team.pypi.cloud.soda.io`, `team.pypi.us.soda.io`,
       `enterprise.pypi.cloud.soda.io`, `enterprise.pypi.us.soda.io`), or
     - The credentials file `~/.soda/soda-credentials.env` (see the Soda
       plugin install docs), edited — if
       `grep -q '<your-' ~/.soda/soda-credentials.env` exits 0 the file
       still has placeholders.
   - If neither is available, stop and tell the user what to set up — the
     credentials and index are the same ones used for `soda-mcp`; point them
     to the Soda plugin install documentation or their Soda contact.

2. Run — with `UV_INDEX` already set:

   ```bash
   uvx -qq --no-progress soda-plugin@latest install
   ```

   or, deriving it from the credentials file (ONE command; parse the file,
   never source or print it):

   ```bash
   UV_INDEX="https://$(sed -n 's/[[:space:]]*$//;s/^SODA_API_KEY_ID=//p' ~/.soda/soda-credentials.env | tail -1):$(sed -n 's/[[:space:]]*$//;s/^SODA_API_KEY_SECRET=//p' ~/.soda/soda-credentials.env | tail -1)@$(sed -n 's/[[:space:]]*$//;s/^SODA_PYPI_HOST=//p' ~/.soda/soda-credentials.env | tail -1)" \
     uvx -qq --no-progress soda-plugin@latest install
   ```

3. Relay the outcome:
   - On success, tell the user to restart Claude Code — the `/rca` and
     `/create-incident` skills are available from the next session. Mention
     that the `soda-mcp` server must also be configured for the skills to be
     useful.
   - On a resolution error or HTTP 401/403, the `UV_INDEX` URL or the API
     key is wrong (or the subscription doesn't include this package) —
     show the error and suggest verifying the key in Soda Cloud.
