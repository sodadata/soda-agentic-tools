#!/usr/bin/env bash
# Installer for the Soda plugin (Claude Code skills /rca, /create-incident)
# and the soda-mcp server. Everything is driven by the credentials file
# ~/.soda/soda-credentials.env, which this script creates from the template
# on first run.
#
# Idempotent: safe to re-run at any time — it is also the repair tool, and
# (after `claude mcp remove soda-mcp`) the key-rotation tool.
#
# Like the session-start hook in this repo, this script is deliberately
# short and boring so you can audit it before running. The credentials file
# is data, never code: it is parsed with sed, not sourced.
# Docs: https://github.com/sodadata/soda-claude-marketplace
set -euo pipefail

CREDS="$HOME/.soda/soda-credentials.env"
TEMPLATE_URL="https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/soda-credentials.env"

say()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v uv >/dev/null 2>&1 ||
  fail "uv is not on PATH — install it: https://docs.astral.sh/uv/getting-started/installation/"
command -v claude >/dev/null 2>&1 ||
  fail "the claude CLI is not on PATH — install Claude Code: https://docs.claude.com/en/docs/claude-code/setup"

# First run: put the credentials template in place, then stop for editing.
if [ ! -f "$CREDS" ]; then
  curl -fsSL --create-dirs -o "$CREDS" "$TEMPLATE_URL"
  chmod 700 "$HOME/.soda" && chmod 600 "$CREDS"
  say "Created $CREDS"
  say "Edit it — fill in your Soda Cloud API key and pick your region/license"
  say "hosts (the file documents the choices) — then run this script again."
  exit 0
fi
chmod 700 "$HOME/.soda" && chmod 600 "$CREDS"

if grep -q '<your-' "$CREDS"; then
  fail "$CREDS still contains placeholder values — edit it first, then re-run."
fi

# Parse the credentials file: strip trailing whitespace/CR (hand-edited or
# CRLF files), take the last occurrence of a duplicated line.
cred() { sed -n "s/[[:space:]]*\$//;s/^$1=//p" "$CREDS" | tail -1; }
for v in SODA_API_KEY_ID SODA_API_KEY_SECRET SODA_CLOUD_HOST SODA_PYPI_HOST; do
  [ -n "$(cred "$v")" ] || fail "$v is missing from $CREDS"
done
UV_INDEX="https://$(cred SODA_API_KEY_ID):$(cred SODA_API_KEY_SECRET)@$(cred SODA_PYPI_HOST)"
export UV_INDEX

# Run a claude CLI command, tolerating only already-done failures.
run_tolerant() {
  local out
  if out=$("$@" 2>&1); then
    if [ -n "$out" ]; then say "   $out"; fi
    return 0
  fi
  case "$out" in
    *[Aa]lready*) say "   (already done)" ;;
    *) fail "'$*' failed: $out" ;;
  esac
}

say "== Registering Soda's Claude Code marketplace and installer plugin"
run_tolerant claude plugin marketplace add sodadata/soda-claude-marketplace
run_tolerant claude plugin install soda-installer@soda-claude-marketplace

say "== Installing the Soda plugin from Soda's private index"
uvx -qq --no-progress soda-plugin@latest install ||
  fail "plugin install failed. A 401/403 or resolution error means the API key
or SODA_PYPI_HOST in $CREDS is wrong for your license/region — verify the key
in Soda Cloud."

say "== soda-mcp server"
if claude mcp get soda-mcp >/dev/null 2>&1; then
  say "   already registered — left untouched. (Rotating a key? Run"
  say "   'claude mcp remove soda-mcp' and re-run this script.)"
else
  claude mcp add soda-mcp --transport stdio --scope user \
    -e SODA_CLOUD_HOST="$(cred SODA_CLOUD_HOST)" \
    -e SODA_API_KEY_ID="$(cred SODA_API_KEY_ID)" \
    -e SODA_API_KEY_SECRET="$(cred SODA_API_KEY_SECRET)" \
    -e UV_INDEX="$UV_INDEX" \
    -- uvx -qq --no-progress soda-mcp@latest
  say "   registered (user scope)"
fi

say ""
say "Done. Start (or restart) claude — the /rca and /create-incident skills"
say "and the soda-mcp server are available from the next session, kept up to"
say "date by a daily session-start check."
