#!/usr/bin/env bash
# Compatibility wrapper for older raw GitHub installation links.
set -euo pipefail

INSTALL_URL="${AGENT_TEAM_INSTALL_URL:-https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh}"
SCRIPT_PATH="${BASH_SOURCE[0]:-}"

TEMP_INSTALLER=""

cleanup() {
  [[ -z "$TEMP_INSTALLER" || ! -e "$TEMP_INSTALLER" ]] || rm -f -- "$TEMP_INSTALLER"
}

trap cleanup EXIT

if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
  if [[ -f "$ROOT/install.sh" ]]; then
    exec bash "$ROOT/install.sh" "$@"
  fi
fi

if [[ -z "$INSTALL_URL" || "$INSTALL_URL" == -* ]]; then
  echo "Install failed: AGENT_TEAM_INSTALL_URL must be a nonempty HTTPS or file URL." >&2
  exit 1
fi
case "$INSTALL_URL" in
  *://*@*|*\?*|*\#*)
    echo "Install failed: AGENT_TEAM_INSTALL_URL must not embed credentials, query parameters, or fragments." >&2
    exit 1
    ;;
  https://*|file:///*) ;;
  *)
    echo "Install failed: AGENT_TEAM_INSTALL_URL must use HTTPS or file." >&2
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "Install failed: curl is required to fetch the installer." >&2
  exit 1
fi

TEMP_INSTALLER="$(mktemp "${TMPDIR:-/tmp}/agent-team-install.XXXXXX")"
if ! curl -q -fsSL --output "$TEMP_INSTALLER" "$INSTALL_URL" 2>/dev/null; then
  echo "Install failed: could not fetch the installer." >&2
  exit 1
fi
if [[ ! -s "$TEMP_INSTALLER" ]] || ! LC_ALL=C grep -q '[^[:space:]]' "$TEMP_INSTALLER"; then
  echo "Install failed: downloaded installer is empty." >&2
  exit 1
fi
if ! bash -n "$TEMP_INSTALLER" 2>/dev/null; then
  echo "Install failed: downloaded installer is not valid Bash." >&2
  exit 1
fi

bash "$TEMP_INSTALLER" "$@"
