#!/usr/bin/env bash
# Install/update agent-team from GitHub into Cursor / Claude Code / Codex.
set -euo pipefail

REPO_URL="${AGENT_TEAM_REPO_URL:-https://github.com/JasonDee-hub/agent-team-skill.git}"
CACHE_DIR="${AGENT_TEAM_CACHE_DIR:-$HOME/.cursor/skill-repos/agent-team-skill}"
REF="${AGENT_TEAM_REF:-main}"

install_cursor=false
install_claude=false
install_codex=false

if [[ $# -eq 0 ]]; then
  install_cursor=true
else
  for arg in "$@"; do
    case "$arg" in
      --cursor) install_cursor=true ;;
      --claude) install_claude=true ;;
      --codex) install_codex=true ;;
      --all)
        install_cursor=true
        install_claude=true
        install_codex=true
        ;;
      -h|--help)
        cat <<'EOF'
Usage: install-from-github.sh [--cursor] [--claude] [--codex] [--all]

Default: --cursor
EOF
        exit 0
        ;;
      *)
        echo "Unknown option: $arg" >&2
        exit 1
        ;;
    esac
  done
fi

resolve_key_file() {
  if [[ -n "${AGENT_TEAM_KEY_FILE:-}" ]]; then
    echo "$AGENT_TEAM_KEY_FILE"
    return
  fi
  if [[ -n "${AGENT_TEAM_KEY:-}" ]]; then
    local tmp
    tmp="$(mktemp)"
    printf '%s' "$AGENT_TEAM_KEY" > "$tmp"
    echo "$tmp"
    return
  fi
  local default="$HOME/.config/agent-team-skill/install.key"
  if [[ -f "$default" ]]; then
    echo "$default"
    return
  fi
  echo "Install unavailable. Please contact the maintainer." >&2
  exit 1
}

KEY_FILE="$(resolve_key_file)"
CLEANUP_TMP=false
if [[ -n "${AGENT_TEAM_KEY:-}" && "${KEY_FILE}" == /tmp/* ]]; then
  CLEANUP_TMP=true
fi

mkdir -p "$(dirname "$CACHE_DIR")"

if [[ -d "$CACHE_DIR/.git" ]]; then
  echo "Updating $CACHE_DIR ..."
  git -C "$CACHE_DIR" fetch origin
  git -C "$CACHE_DIR" checkout "$REF"
  git -C "$CACHE_DIR" pull --ff-only origin "$REF"
else
  echo "Cloning $REPO_URL → $CACHE_DIR ..."
  git clone --branch "$REF" "$REPO_URL" "$CACHE_DIR"
fi

ENC="$CACHE_DIR/sealed/agent-team.enc"
if [[ ! -f "$ENC" ]]; then
  $CLEANUP_TMP && rm -f "$KEY_FILE" || true
  echo "Install unavailable. Please contact the maintainer." >&2
  exit 1
fi

TMP_TAR="$(mktemp)"
if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$ENC" -out "$TMP_TAR" -pass "file:${KEY_FILE}"; then
  rm -f "$TMP_TAR"
  $CLEANUP_TMP && rm -f "$KEY_FILE" || true
  echo "Install unavailable. Please contact the maintainer." >&2
  exit 1
fi
$CLEANUP_TMP && rm -f "$KEY_FILE" || true

rm -rf "$CACHE_DIR/agent-team"
tar -C "$CACHE_DIR" -xzf "$TMP_TAR"
rm -f "$TMP_TAR"

SRC="$CACHE_DIR/agent-team"

copy_skill() {
  local dest_parent="$1"
  mkdir -p "$dest_parent"
  rm -rf "$dest_parent/agent-team"
  cp -R "$SRC" "$dest_parent/agent-team"
  echo "Installed skill → $dest_parent/agent-team"
}

if $install_cursor; then
  mkdir -p "$HOME/.cursor/skills" "$HOME/.cursor/agents" "$HOME/.cursor/commands"
  copy_skill "$HOME/.cursor/skills"
  cp "$SRC/references/experts/"*.md "$HOME/.cursor/agents/"
  cp "$SRC/commands/agent-team.md" "$HOME/.cursor/commands/agent-team.md"
  echo "Installed Cursor agents → $HOME/.cursor/agents/"
  echo "Installed Cursor command → $HOME/.cursor/commands/agent-team.md"
  if mkdir -p "$HOME/.agents/skills" 2>/dev/null; then
    copy_skill "$HOME/.agents/skills"
  fi
fi

if $install_claude; then
  mkdir -p "$HOME/.claude/skills"
  copy_skill "$HOME/.claude/skills"
fi

if $install_codex; then
  mkdir -p "$HOME/.codex/skills"
  copy_skill "$HOME/.codex/skills"
fi

echo
echo "Done. In Agent chat, try: /agent-team <your request>"
