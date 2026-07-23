#!/usr/bin/env bash
# Public entrypoint (root path avoids stale raw.githubusercontent.com caches of older scripts).
# Install/update agent-team from GitHub into Cursor / Claude Code / Codex.
set -euo pipefail

REPO_URL="${AGENT_TEAM_REPO_URL:-https://github.com/JasonDee-hub/agent-team-skill.git}"
TARGET_HOME="${AGENT_TEAM_TARGET_HOME:-$HOME}"
CACHE_DIR="${AGENT_TEAM_CACHE_DIR:-${XDG_CACHE_HOME:-$TARGET_HOME/.cache}/agent-team-skill}"
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
Usage: install.sh [--cursor] [--claude] [--codex] [--all]

Default: --cursor
No key required. Copies agent-team/ into your skill directories.
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

# Prefer a local checkout when this script is run from a cloned repo (not via curl|bash).
SRC=""
_script="${BASH_SOURCE[0]:-}"
if [[ -n "$_script" && -f "$_script" ]]; then
  _root="$(cd "$(dirname "$_script")" && pwd)"
  if [[ -f "$_root/agent-team/SKILL.md" ]]; then
    SRC="$_root/agent-team"
  fi
fi

if [[ -z "$SRC" ]]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "Install failed: git is required for remote installation. Install git and try again." >&2
    exit 1
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
  SRC="$CACHE_DIR/agent-team"
fi

if [[ ! -f "$SRC/SKILL.md" ]]; then
  echo "Install failed: agent-team/SKILL.md not found at $SRC" >&2
  exit 1
fi

copy_skill() {
  local dest_parent="$1"
  mkdir -p "$dest_parent"
  rm -rf "$dest_parent/agent-team"
  cp -R "$SRC" "$dest_parent/agent-team"
  echo "Installed skill → $dest_parent/agent-team"
}

if $install_cursor; then
  mkdir -p "$TARGET_HOME/.cursor/skills" "$TARGET_HOME/.cursor/agents" "$TARGET_HOME/.cursor/commands"
  copy_skill "$TARGET_HOME/.cursor/skills"
  for expert in "$SRC/references/experts/"*.md; do
    cp "$expert" "$TARGET_HOME/.cursor/agents/agent-team-$(basename "$expert")"
  done
  cp "$SRC/commands/agent-team.md" "$TARGET_HOME/.cursor/commands/agent-team.md"
  echo "Installed Cursor agents → $TARGET_HOME/.cursor/agents/agent-team-*.md"
  echo "Installed Cursor command → $TARGET_HOME/.cursor/commands/agent-team.md"
  if mkdir -p "$TARGET_HOME/.agents/skills" 2>/dev/null; then
    copy_skill "$TARGET_HOME/.agents/skills"
  fi
fi

if $install_claude; then
  mkdir -p "$TARGET_HOME/.claude/skills"
  copy_skill "$TARGET_HOME/.claude/skills"
fi

if $install_codex; then
  mkdir -p "$TARGET_HOME/.agents/skills" "$TARGET_HOME/.codex/skills"
  copy_skill "$TARGET_HOME/.agents/skills"
  copy_skill "$TARGET_HOME/.codex/skills"
fi

echo
echo "Done."
if $install_cursor; then
  echo "Cursor: /agent-team <your request>"
fi
if $install_claude; then
  echo "Claude Code: /agent-team <your request>"
fi
if $install_codex; then
  echo 'Codex: $agent-team <your request> (or ask for the expert team in natural language)'
fi
