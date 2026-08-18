#!/usr/bin/env bash
# Remove everything install.sh installs:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sodadata/soda-agentic-tools/main/claude/uninstall.sh)"
#
# Reports what it finds, asks once, then removes:
#   - the claude plugin 'soda@soda' and the local marketplace 'soda'
#   - the plugin tree at ~/.soda/claude-plugins/soda
#   - the 'soda-mcp' MCP registration (user scope) and the soda-mcp tool
#
# Idempotent and tolerant: anything already gone is reported and skipped, and
# a missing uv or claude never stops the rest of the cleanup.
#
# Nothing outside ~/.soda/claude-plugins/soda, uv's tool directory and your
# Claude Code config is touched.
set -euo pipefail

say()  { printf '%s\n' "$*"; }

INTERACTIVE=0
if [ -z "${SODA_UNINSTALL_NONINTERACTIVE:-}" ] && [ -z "${CLAUDECODE:-}" ] &&
   { true </dev/tty; } 2>/dev/null; then
  INTERACTIVE=1
fi

PLUGIN_DIR="$HOME/.soda/claude-plugins/soda"
HAVE_CLAUDE=0; command -v claude >/dev/null 2>&1 && HAVE_CLAUDE=1
HAVE_UV=0;     command -v uv     >/dev/null 2>&1 && HAVE_UV=1

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
  if claude plugin list 2>/dev/null | grep -q 'soda@soda'; then
    say "  - claude plugin      soda@soda"
    found=1
  fi
  if claude plugin marketplace list 2>/dev/null | grep -qE '^[[:space:]]*[^[:space:]]*[[:space:]]*soda$'; then
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
fi
[ "$HAVE_UV" = "1" ] && drop "uv tool soda-mcp" uv tool uninstall soda-mcp

if [ -d "$PLUGIN_DIR" ]; then
  rm -rf "$PLUGIN_DIR"
  say "   removed $PLUGIN_DIR"
  # Tidy up only if we left them empty; never touch a ~/.soda holding anything else.
  rmdir "$HOME/.soda/claude-plugins" 2>/dev/null || true
  rmdir "$HOME/.soda" 2>/dev/null || true
fi

say ""
say "Done. Restart Claude Code sessions to drop the skills and the MCP server."

# Left behind by the older, credentials-file based installer — not created by
# install.sh, so it is reported rather than deleted.
if [ -f "$HOME/.soda/claude/soda-credentials.env" ]; then
  say ""
  say "Note: $HOME/.soda/claude/soda-credentials.env still exists (from the older"
  say "installer) and contains your API key. Remove it if you no longer need it."
fi
