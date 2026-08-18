#!/usr/bin/env bash
# One-line installer for the Soda plugin (Claude Code skills /rca and
# /create-incident) and the soda-mcp server:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/install.sh)"
#
# Run it from any directory — everything installs at the user level (~/.soda,
# uv's tool directory and your Claude Code config), never into the current
# folder, and no shell profile is modified.
#
# Credentials are read from the environment and are NEVER written to a file by
# this script. They end up in exactly one place: the env block of the soda-mcp
# entry in your Claude Code config.
#
#   SODA_CLOUD_HOST           cloud.soda.io (EU) or cloud.us.soda.io (US)
#   SODA_API_KEY_ID           Soda Cloud -> avatar -> Profile -> API Keys -> +
#   SODA_API_KEY_SECRET
#
# Optional — the private package index, only used while installing:
#
#   SODA_PYPI_INDEX           default team.pypi.cloud.soda.io. Others:
#                             team.pypi.us.soda.io,
#                             enterprise.pypi.cloud.soda.io,
#                             enterprise.pypi.us.soda.io
#   SODA_PYPI_API_KEY_ID      defaults to SODA_API_KEY_ID
#   SODA_PYPI_API_KEY_SECRET  defaults to SODA_API_KEY_SECRET
#
# Idempotent: safe to re-run at any time — it is also the repair tool and the
# update tool (re-running upgrades both soda-mcp and the plugin).
#
# Deliberately short and boring so you can audit it before running.
# Docs: https://github.com/sodadata/soda-agentic-tools
set -euo pipefail

say()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Interactive = a usable terminal, not inside a Claude Code tool call
# (CLAUDECODE is set there), and not explicitly overridden. Non-interactive
# runs never pause: an agent has already had the run approved by the user.
INTERACTIVE=0
if [ -z "${SODA_INSTALL_NONINTERACTIVE:-}" ] && [ -z "${CLAUDECODE:-}" ] &&
   { true </dev/tty; } 2>/dev/null; then
  INTERACTIVE=1
fi

# ---------------------------------------------------------------- prerequisites

say "== Checking prerequisites"
command -v uv >/dev/null 2>&1 ||
  fail "uv is not on PATH — install it: https://docs.astral.sh/uv/getting-started/installation/"
command -v claude >/dev/null 2>&1 ||
  fail "the claude CLI is not on PATH — install Claude Code: https://docs.claude.com/en/docs/claude-code/setup"
claude plugin --help >/dev/null 2>&1 ||
  fail "this Claude Code version has no plugin support — update Claude Code (e.g. 'claude update'), then re-run."
claude mcp --help >/dev/null 2>&1 ||
  fail "this Claude Code version has no MCP support — update Claude Code (e.g. 'claude update'), then re-run."
command -v python3 >/dev/null 2>&1 ||
  fail "python3 is not on PATH — the /create-incident skill runs a python3 script.
On macOS: 'xcode-select --install'. On Linux: install python3 with your package manager."
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1 ||
  fail "python3 is older than 3.8 — the /create-incident skill needs 3.8 or newer."
say "   OK: uv $(uv --version 2>/dev/null | awk '{print $2}'), claude $(claude --version 2>/dev/null | awk '{print $1}'), python3 $(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"

auth=$(claude auth status 2>/dev/null) || true
case "$auth" in
  *'"loggedIn": false'*)
    say "   note: claude is not logged in yet — that's fine for installing;"
    say "   login happens the first time claude starts." ;;
esac

# ------------------------------------------------------------------ credentials

say "== Checking credentials"
missing=""
for v in SODA_CLOUD_HOST SODA_API_KEY_ID SODA_API_KEY_SECRET; do
  eval "value=\${$v:-}"
  [ -n "$value" ] || missing="$missing $v"
done
if [ -n "$missing" ]; then
  printf 'ERROR: missing environment variable(s):%s\n\n' "$missing" >&2
  cat >&2 <<'EOF'
Create a Soda Cloud API key (Soda Cloud -> avatar -> Profile -> API Keys -> +)
and run the installer with the values set, for example:

  SODA_CLOUD_HOST=cloud.soda.io \
  SODA_API_KEY_ID=<your-api-key-id> \
  SODA_API_KEY_SECRET=<your-api-key-secret> \
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/install.sh)"

Prefixing the command like this keeps the key out of your shell profile.
US region: SODA_CLOUD_HOST=cloud.us.soda.io

If your Soda Cloud is not on the Team/EU plan, also set SODA_PYPI_INDEX to one
of: team.pypi.cloud.soda.io, team.pypi.us.soda.io,
enterprise.pypi.cloud.soda.io, enterprise.pypi.us.soda.io
EOF
  exit 1
fi

SODA_PYPI_INDEX="${SODA_PYPI_INDEX:-team.pypi.cloud.soda.io}"
SODA_PYPI_API_KEY_ID="${SODA_PYPI_API_KEY_ID:-$SODA_API_KEY_ID}"
SODA_PYPI_API_KEY_SECRET="${SODA_PYPI_API_KEY_SECRET:-$SODA_API_KEY_SECRET}"
say "   OK: all credentials present"

# --------------------------------------------------------------- what happens

PLUGIN_DIR="$HOME/.soda/claude-plugins/soda"
UV_TOOL_BIN="$(uv tool dir --bin)"
MCP_BIN="$UV_TOOL_BIN/soda-mcp"

say ""
say "About to install, at the user level:"
say ""
say "  1. soda-mcp        -> $MCP_BIN"
say "                        registered with claude as 'soda-mcp' (user scope),"
say "                        carrying your Soda Cloud credentials"
say "  2. the soda plugin -> $PLUGIN_DIR"
say "                        registered with claude as marketplace 'soda',"
say "                        plugin 'soda@soda' (skills /rca, /create-incident)"
say ""
say "  Soda Cloud host    : $SODA_CLOUD_HOST"
say "  Private PyPI index : $SODA_PYPI_INDEX"
if [ "$SODA_PYPI_API_KEY_ID" != "$SODA_API_KEY_ID" ]; then
  say ""
  say "  note: the package-index API key differs from the Soda Cloud API key."
  say "  That is a dev/testing setup — customers normally use one key for both."
fi
say ""
say "Nothing is written into the current directory and no shell profile is"
say "changed. Your credentials are not written to any file by this script."
say ""

if [ "$INTERACTIVE" = "1" ]; then
  printf 'Proceed? [y/N] ' >/dev/tty
  read -r reply </dev/tty
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) say "Aborted — nothing was installed."; exit 0 ;;
  esac
  say ""
fi

# The index credential is needed only while installing. It is deliberately NOT
# passed to the soda-mcp registration: soda-mcp is installed as a real tool
# below, so it never resolves anything from the index at session start.
export UV_INDEX="https://$SODA_PYPI_API_KEY_ID:$SODA_PYPI_API_KEY_SECRET@$SODA_PYPI_INDEX"

# --------------------------------------------------------------------- soda-mcp

say "== Installing soda-mcp from Soda's private index"
uv tool install --force -q soda-mcp ||
  fail "soda-mcp install failed. A 401/403 or resolution error means the API key
is wrong, or SODA_PYPI_INDEX ($SODA_PYPI_INDEX) is not the index your license
and region entitle. Verify the key in Soda Cloud."
[ -x "$MCP_BIN" ] ||
  fail "soda-mcp installed but no executable at $MCP_BIN — report this to Soda support."
# Ask uv for the version rather than the binary: soda-mcp takes no arguments
# and would start a stdio server that never returns.
say "   installed: $(uv tool list 2>/dev/null | awk '/^soda-mcp /{print $1, $2; exit}' || true)"

say "== Registering soda-mcp with claude (user scope)"
# Replace any earlier registration: older installs launched soda-mcp through
# 'uvx soda-mcp@latest' with the index credential embedded, which this design
# deliberately drops.
claude mcp remove soda-mcp -s user >/dev/null 2>&1 || true
claude mcp add soda-mcp --transport stdio --scope user \
  -e SODA_CLOUD_HOST="$SODA_CLOUD_HOST" \
  -e SODA_API_KEY_ID="$SODA_API_KEY_ID" \
  -e SODA_API_KEY_SECRET="$SODA_API_KEY_SECRET" \
  -- "$MCP_BIN" >/dev/null ||
  fail "could not register soda-mcp with claude."
say "   registered"

# ----------------------------------------------------------------- soda plugin

say "== Installing the soda plugin from Soda's private index"
# The wheel unpacks itself into $PLUGIN_DIR — which is a local Claude Code
# marketplace — and registers marketplace 'soda' + plugin 'soda@soda'.
uvx -qq --no-progress soda-plugin@latest install ||
  fail "plugin install failed. A 401/403 or resolution error means the API key
is wrong, or SODA_PYPI_INDEX ($SODA_PYPI_INDEX) is not the index your license
and region entitle. Verify the key in Soda Cloud."

# ---------------------------------------------------------------------- report

version="unknown"
[ -f "$PLUGIN_DIR/.installed-version" ] && version=$(cat "$PLUGIN_DIR/.installed-version")

say ""
say "Done."
say ""
say "  marketplace 'soda'   $PLUGIN_DIR"
say "  plugin 'soda@soda'   version $version"
for skill in "$PLUGIN_DIR"/plugins/soda/skills/*/; do
  [ -d "$skill" ] || continue
  say "    skill /$(basename "$skill")"
done
say "  mcp server 'soda-mcp'  $MCP_BIN (user scope)"
say ""
say "Start claude, or restart your running sessions, to pick this up."
say ""
say "To undo everything:"
say "  claude plugin uninstall soda@soda"
say "  claude plugin marketplace remove soda"
say "  claude mcp remove soda-mcp -s user"
say "  uv tool uninstall soda-mcp"
say "  rm -rf ~/.soda/claude-plugins"
