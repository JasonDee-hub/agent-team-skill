#!/usr/bin/env bash
# Thin wrapper kept for older README links; prefers root install.sh logic.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/install.sh" ]]; then
  exec bash "$ROOT/install.sh" "$@"
fi
echo "Install failed: missing install.sh in repo root." >&2
exit 1
