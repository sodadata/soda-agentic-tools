---
description: Install the Soda plugin from Soda's private PyPI
---

Install (or update) the Soda plugin. Follow these steps exactly:

1. Check prerequisites before running anything:
   - `uv` must be on PATH (https://docs.astral.sh/uv/getting-started/installation/).
   - The environment variable `UV_INDEX` must be set to Soda's private PyPI
     index for the user's license and region, with their Soda Cloud API key
     embedded as Basic auth, e.g.
     `https://$SODA_API_KEY_ID:$SODA_API_KEY_SECRET@team.pypi.cloud.soda.io`
     (indexes: `team.pypi.cloud.soda.io`, `team.pypi.us.soda.io`,
     `enterprise.pypi.cloud.soda.io`, `enterprise.pypi.us.soda.io`).
   - If either is missing, stop and tell the user what to set up — the
     credentials and index are the same ones used for `soda-mcp`; point them
     to the Soda plugin install documentation or their Soda contact.

2. Run:

   ```bash
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
