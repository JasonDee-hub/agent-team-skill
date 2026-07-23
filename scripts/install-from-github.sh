#!/usr/bin/env bash
# Compatibility wrapper for older raw GitHub installation links.
set -euo pipefail

INSTALL_URL="${AGENT_TEAM_INSTALL_URL:-https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh}"
SCRIPT_PATH="${BASH_SOURCE[0]:-}"

if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
  if [[ -f "$ROOT/install.sh" ]]; then
    exec bash "$ROOT/install.sh" "$@"
  fi
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Install failed: curl is required to fetch $INSTALL_URL" >&2
  exit 1
fi

curl -fsSL "$INSTALL_URL" | bash -s -- "$@"
