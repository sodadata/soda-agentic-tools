#!/usr/bin/env bash
# SessionStart update check for the Soda plugin (package soda-plugin on
# Soda's private PyPI, entitled by your Soda Cloud API key via UV_INDEX —
# taken from the environment, or derived from ~/.soda/claude/soda-credentials.env).
#
# Contract, in priority order:
#   1. Never block or break session start: every path exits 0, quickly.
#   2. At most one network check per 24h (timestamp-file throttle).
#   3. Resolving soda-plugin@latest IS the update check — the install
#      command is idempotent and prints when a restart is needed.
#
# This script is deliberately short and boring: it is the only code from this
# public repo that executes on your machine, and being easy to audit is part
# of its job. The credentials file is data, never code: it is parsed with
# sed, not sourced.

BASE="$HOME/.soda/claude-plugins"
STAMP="$BASE/.soda-plugin-last-check"
INSTALLED="$BASE/soda/.installed-version"
CREDS="$HOME/.soda/claude/soda-credentials.env"

main() {
  command -v uv >/dev/null 2>&1 || return 0

  # Throttle: skip unless the last check is more than 24h old.
  if [ -f "$STAMP" ]; then
    now=$(date +%s)
    last=$(stat -f %m "$STAMP" 2>/dev/null || stat -c %Y "$STAMP" 2>/dev/null || echo 0)
    [ $((now - last)) -lt 86400 ] && return 0
  fi
  mkdir -p "$BASE" 2>/dev/null && touch "$STAMP" 2>/dev/null

  # Installs from a repo checkout (version suffix "+local") are managed
  # locally — never overwrite them with the published wheel.
  case "$(cat "$INSTALLED" 2>/dev/null)" in *+local*) return 0 ;; esac

  # No UV_INDEX in the environment: derive it from the credentials file.
  # Trailing whitespace/CR is stripped so CRLF or hand-edited files parse;
  # tail -1 resolves a duplicated line to its last occurrence; the case
  # guard skips unedited "<your-...>" placeholder values.
  if [ -z "${UV_INDEX:-}" ] && [ -f "$CREDS" ]; then
    cred() { sed -n "s/[[:space:]]*\$//;s/^$1=//p" "$CREDS" 2>/dev/null | tail -1; }
    id=$(cred SODA_API_KEY_ID) secret=$(cred SODA_API_KEY_SECRET) host=$(cred SODA_PYPI_HOST)
    case "$id$secret$host" in *"<"*) ;; *)
      [ -n "$id" ] && [ -n "$secret" ] && [ -n "$host" ] &&
        export UV_INDEX="https://$id:$secret@$host"
    esac
  fi

  if [ ! -f "$INSTALLED" ]; then
    if [ -z "${UV_INDEX:-}" ]; then
      echo "Soda plugin not installed: create ~/.soda/claude/soda-credentials.env or set UV_INDEX (see the Soda plugin install docs), then run /soda-installer:install." >&2
      return 0
    fi
    echo "Installing the Soda plugin..." >&2
  fi
  [ -z "${UV_INDEX:-}" ] && return 0

  uvx -qq --no-progress soda-plugin@latest install >&2 ||
    echo "Soda plugin update check failed (network or UV_INDEX credentials) — retrying tomorrow." >&2
}

main
exit 0
