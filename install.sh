#!/usr/bin/env bash
# Public entrypoint (root path avoids stale raw.githubusercontent.com caches of older scripts).
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
if [[ "${BASH_SOURCE[0]:-}" == /* || "${BASH_SOURCE[0]:-}" == ./* || "${BASH_SOURCE[0]:-}" == */* ]]; then
  _script="${BASH_SOURCE[0]}"
  if [[ -f "$_script" ]]; then
    _root="$(cd "$(dirname "$_script")" && pwd)"
    if [[ -f "$_root/agent-team/SKILL.md" ]]; then
      SRC="$_root/agent-team"
    fi
  fi
fi

if [[ -z "$SRC" ]]; then
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
