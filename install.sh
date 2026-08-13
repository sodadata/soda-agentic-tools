#!/usr/bin/env bash
# One-line installer for the Soda plugin (Claude Code skills /rca,
# /create-incident) and the soda-mcp server:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main/install.sh)"
#
# Run it from any directory — everything installs at the user level
# (~/.soda and your Claude Code config), never into the current folder.
#
# In an interactive terminal it pauses while you edit the credentials file,
# installs everything, and finishes by launching claude. Non-interactively
# (Claude Code agent, CI) it never pauses and never launches — it prints
# what is missing and exits, or installs and asks for a restart.
#
# Idempotent: safe to re-run at any time — it is also the repair tool, and
# (after `claude mcp remove soda-mcp`) the key-rotation tool. A copy is kept
# at ~/.soda/install.sh for those later runs.
#
# Like the session-start hook in this repo, this script is deliberately
# short and boring so you can audit it before running. The credentials file
# is data, never code: it is parsed with sed, not sourced.
# Docs: https://github.com/sodadata/soda-claude-marketplace
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/sodadata/soda-claude-marketplace/main"
CREDS="$HOME/.soda/soda-credentials.env"
SELF="$HOME/.soda/install.sh"

say()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Interactive = a usable terminal, and not inside a Claude Code tool call.
INTERACTIVE=0
if [ -z "${CLAUDECODE:-}" ] && { true </dev/tty; } 2>/dev/null; then
  INTERACTIVE=1
fi

say "== Checking prerequisites"
command -v curl >/dev/null 2>&1 ||
  fail "curl is not on PATH."
command -v uv >/dev/null 2>&1 ||
  fail "uv is not on PATH — install it: https://docs.astral.sh/uv/getting-started/installation/"
command -v claude >/dev/null 2>&1 ||
  fail "the claude CLI is not on PATH — install Claude Code: https://docs.claude.com/en/docs/claude-code/setup"
claude plugin --help >/dev/null 2>&1 ||
  fail "this Claude Code version has no plugin support — update Claude Code (e.g. 'claude update'), then re-run."
claude mcp --help >/dev/null 2>&1 ||
  fail "this Claude Code version has no MCP support — update Claude Code (e.g. 'claude update'), then re-run."
say "   OK: curl, uv $(uv --version 2>/dev/null | awk '{print $2}'), claude $(claude --version 2>/dev/null | awk '{print $1}')"
auth=$(claude auth status 2>/dev/null) || true
case "$auth" in
  *'"loggedIn": false'*)
    say "   note: claude is not logged in yet — that's fine for installing;"
    say "   login happens the first time claude starts." ;;
esac

mkdir -p "$HOME/.soda" && chmod 700 "$HOME/.soda"

# Keep a copy of this script for later repair/rotation runs (the one-liner
# leaves no file behind).
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  cp -f "${BASH_SOURCE[0]}" "$SELF" 2>/dev/null || true
else
  curl -fsSL -o "$SELF" "$BASE_URL/install.sh" 2>/dev/null || true
fi
chmod 700 "$SELF" 2>/dev/null || true

# Credentials: fetch the template on first use, then make sure it is edited.
if [ ! -f "$CREDS" ]; then
  curl -fsSL -o "$CREDS" "$BASE_URL/soda-credentials.env" ||
    fail "could not fetch the credentials template (network?)"
  say "Created $CREDS"
fi
chmod 600 "$CREDS"

while grep -q '<your-' "$CREDS"; do
  if [ "$INTERACTIVE" = "1" ]; then
    say ""
    say "Next: fill in your Soda Cloud API key and your region/license hosts in"
    say "    $CREDS"
    say "(open it in your editor — the file documents every choice; API keys:"
    say "Soda Cloud -> avatar -> Profile -> API Keys -> +)"
    printf 'Press enter when the file is saved (ctrl-c to abort)... ' >/dev/tty
    read -r _ </dev/tty
  else
    fail "$CREDS still contains placeholder values — ask the user to edit it, then run this script again."
  fi
done

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
if [ "$INTERACTIVE" = "1" ]; then
  say "Done — starting claude. The /rca and /create-incident skills and the"
  say "soda-mcp server are available. (Re-run ~/.soda/install.sh any time to"
  say "repair the install.)"
  say ""
  exec claude
fi
say "Done. Restart Claude Code — the /rca and /create-incident skills and"
say "the soda-mcp server are available from the next session, kept up to"
say "date by a daily session-start check."
