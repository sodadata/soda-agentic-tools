#!/usr/bin/env bash
# Remove everything install.sh installs, plus anything the retired installer
# plugin left behind:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/uninstall.sh)"
#
# Reports what it finds, asks once, then removes:
#   - the claude plugin 'soda@soda' and the local marketplace 'soda'
#   - the plugin tree at ~/.soda/claude-plugins/soda
#   - the 'soda-mcp' MCP registration (user scope) and the soda-mcp tool
#   - legacy: the plugin 'soda-installer@soda-claude-marketplace', its
#     marketplace, its update-check stamp, and the credentials file it read
#
# Idempotent and tolerant: anything already gone is reported and skipped, and
# a missing uv or claude never stops the rest of the cleanup.
#
# Nothing outside ~/.soda/claude, ~/.soda/claude-plugins, uv's tool directory
# and your Claude Code config is touched.
set -euo pipefail

say()  { printf '%s\n' "$*"; }

INTERACTIVE=0
if [ -z "${SODA_UNINSTALL_NONINTERACTIVE:-}" ] && [ -z "${CLAUDECODE:-}" ] &&
   { true </dev/tty; } 2>/dev/null; then
  INTERACTIVE=1
fi

PLUGIN_DIR="$HOME/.soda/claude-plugins/soda"

# Left behind by the older, credentials-file based installer. The stamp is its
# 24h update-check throttle; the env file holds the API key it derived UV_INDEX
# from. Neither is created by install.sh.
LEGACY_PLUGIN="soda-installer@soda-claude-marketplace"
LEGACY_MARKETPLACE="soda-claude-marketplace"
LEGACY_STAMP="$HOME/.soda/claude-plugins/.soda-plugin-last-check"
LEGACY_CREDS="$HOME/.soda/claude/soda-credentials.env"

HAVE_CLAUDE=0; command -v claude >/dev/null 2>&1 && HAVE_CLAUDE=1
HAVE_UV=0;     command -v uv     >/dev/null 2>&1 && HAVE_UV=1

has_plugin()      { claude plugin list 2>/dev/null | grep -qF "$1"; }
has_marketplace() {
  claude plugin marketplace list 2>/dev/null |
    grep -qE "^[[:space:]]*[^[:space:]]*[[:space:]]*$1\$"
}

# ------------------------------------------------------------------ discovery

found=0
say "Found:"

if [ -d "$PLUGIN_DIR" ]; then
  version="unknown"
  [ -f "$PLUGIN_DIR/.installed-version" ] && version=$(cat "$PLUGIN_DIR/.installed-version")
  say "  - plugin tree        $PLUGIN_DIR (version $version)"
  case "$version" in
    *+local)
      say "                       note: '+local' means this was installed from a repo"
      say "                       checkout (the demo). Removing it undoes that install too." ;;
  esac
  found=1
fi

if [ "$HAVE_CLAUDE" = "1" ]; then
  if has_plugin 'soda@soda'; then
    say "  - claude plugin      soda@soda"
    found=1
  fi
  if has_marketplace 'soda'; then
    say "  - claude marketplace soda"
    found=1
  fi
  if claude mcp get soda-mcp >/dev/null 2>&1; then
    say "  - mcp registration   soda-mcp"
    found=1
  fi
fi

if [ "$HAVE_UV" = "1" ] && uv tool list 2>/dev/null | grep -q '^soda-mcp '; then
  say "  - uv tool            soda-mcp"
  found=1
fi

# Tracked per item so the removal pass stays silent when there is no legacy
# install — the common case, and two "skipped" lines would only confuse.
legacy=0; FOUND_LEGACY_PLUGIN=0; FOUND_LEGACY_MARKETPLACE=0
if [ "$HAVE_CLAUDE" = "1" ]; then
  has_plugin "$LEGACY_PLUGIN" && {
    say "  - legacy plugin      $LEGACY_PLUGIN"; FOUND_LEGACY_PLUGIN=1; legacy=1; }
  has_marketplace "$LEGACY_MARKETPLACE" && {
    say "  - legacy marketplace $LEGACY_MARKETPLACE"; FOUND_LEGACY_MARKETPLACE=1; legacy=1; }
fi
[ -f "$LEGACY_STAMP" ] && { say "  - legacy stamp       $LEGACY_STAMP"; legacy=1; }
if [ -f "$LEGACY_CREDS" ]; then
  say "  - legacy credentials $LEGACY_CREDS"
  say "                       note: this file contains your Soda Cloud API key."
  legacy=1
fi
[ "$legacy" = "1" ] && found=1

if [ "$found" = "0" ]; then
  say "  (nothing) — the Soda plugin and soda-mcp are not installed."
  exit 0
fi

[ "$HAVE_CLAUDE" = "1" ] ||
  say "  warning: the claude CLI is not on PATH — its registrations cannot be removed."
[ "$HAVE_UV" = "1" ] ||
  say "  warning: uv is not on PATH — the soda-mcp tool cannot be removed."

say ""
if [ "$INTERACTIVE" = "1" ]; then
  printf 'Remove all of the above? [y/N] ' >/dev/tty
  read -r reply </dev/tty
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) say "Aborted — nothing was removed."; exit 0 ;;
  esac
  say ""
fi

# -------------------------------------------------------------------- removal

# Tolerant: report the outcome, never abort the remaining steps.
drop() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    say "   removed $label"
  else
    say "   skipped $label (not present, or already removed)"
  fi
}

say "== Removing"
if [ "$HAVE_CLAUDE" = "1" ]; then
  # Plugin before marketplace: a marketplace with an installed plugin from it
  # refuses to go.
  drop "claude plugin soda@soda"  claude plugin uninstall soda@soda
  drop "claude marketplace soda"  claude plugin marketplace remove soda
  drop "mcp registration soda-mcp" claude mcp remove soda-mcp -s user
  [ "$FOUND_LEGACY_PLUGIN" = "1" ] &&
    drop "legacy plugin $LEGACY_PLUGIN" claude plugin uninstall "$LEGACY_PLUGIN"
  [ "$FOUND_LEGACY_MARKETPLACE" = "1" ] &&
    drop "legacy marketplace $LEGACY_MARKETPLACE" claude plugin marketplace remove "$LEGACY_MARKETPLACE"
fi
[ "$HAVE_UV" = "1" ] && drop "uv tool soda-mcp" uv tool uninstall soda-mcp

if [ -d "$PLUGIN_DIR" ]; then
  rm -rf "$PLUGIN_DIR"
  say "   removed $PLUGIN_DIR"
fi

[ -f "$LEGACY_STAMP" ] && { rm -f "$LEGACY_STAMP"; say "   removed $LEGACY_STAMP"; }
[ -f "$LEGACY_CREDS" ] && { rm -f "$LEGACY_CREDS"; say "   removed $LEGACY_CREDS"; }

# Tidy up only the directories we left empty; never touch a ~/.soda holding
# anything else (credentials, configs and scan artifacts also live there).
rmdir "$HOME/.soda/claude" "$HOME/.soda/claude-plugins" 2>/dev/null || true
rmdir "$HOME/.soda" 2>/dev/null || true

say ""
say "Done. Restart Claude Code sessions to drop the skills and the MCP server."
