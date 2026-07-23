#!/usr/bin/env bash
# Create an optional encrypted archive; public releases still ship agent-team/ as plaintext.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -d agent-team ]]; then
  echo "Missing agent-team/ (plaintext). Nothing to seal." >&2
  exit 1
fi

KEY_FILE=""
TMP_KEY=""
TMP_TAR=""

cleanup() {
  [[ -n "$TMP_TAR" && -f "$TMP_TAR" ]] && rm -f "$TMP_TAR"
  [[ -n "$TMP_KEY" && -f "$TMP_KEY" ]] && rm -f "$TMP_KEY"
}
trap cleanup EXIT

resolve_key_file() {
  if [[ -n "${AGENT_TEAM_KEY_FILE:-}" ]]; then
    KEY_FILE="$AGENT_TEAM_KEY_FILE"
    return
  fi
  if [[ -n "${AGENT_TEAM_KEY:-}" ]]; then
    TMP_KEY="$(mktemp)"
    chmod 600 "$TMP_KEY"
    printf '%s' "$AGENT_TEAM_KEY" > "$TMP_KEY"
    KEY_FILE="$TMP_KEY"
    return
  fi
  local default="$HOME/.config/agent-team-skill/install.key"
  if [[ -f "$default" ]]; then
    KEY_FILE="$default"
    return
  fi
  echo "No key. Set AGENT_TEAM_KEY, or AGENT_TEAM_KEY_FILE, or create $default" >&2
  exit 1
}

resolve_key_file
if [[ ! -f "$KEY_FILE" ]]; then
  echo "Key file not found: $KEY_FILE" >&2
  exit 1
fi

mkdir -p sealed
TMP_TAR="$(mktemp)"
tar -C "$ROOT" -czf "$TMP_TAR" agent-team
openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
  -in "$TMP_TAR" -out "$ROOT/sealed/agent-team.enc" \
  -pass "file:${KEY_FILE}"

echo "Encrypted archive created → sealed/agent-team.enc"
echo "Publishing remains plaintext: keep agent-team/ in the release; the archive is optional."
