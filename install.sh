#!/usr/bin/env bash
# Public entrypoint (root path avoids stale raw.githubusercontent.com caches of older scripts).
# Install/update agent-team from GitHub into Cursor / Claude Code / Codex.
set -euo pipefail

REPO_URL="${AGENT_TEAM_REPO_URL:-https://github.com/JasonDee-hub/agent-team-skill.git}"
TARGET_HOME="${AGENT_TEAM_TARGET_HOME:-$HOME}"
CACHE_DIR="${AGENT_TEAM_CACHE_DIR:-${XDG_CACHE_HOME:-$TARGET_HOME/.cache}/agent-team-skill}"
REF="${AGENT_TEAM_REF:-main}"
CODEX_ROOT="${CODEX_HOME:-$TARGET_HOME/.codex}"

SKILL_MANIFEST=(
  SKILL.md
  agents/openai.yaml
  commands/agent-team.md
  references/domain-grilling.md
  references/handoff.md
  references/lean.md
  references/experts/code-reviewer.md
  references/experts/fullstack-engineer.md
  references/experts/generalist.md
  references/experts/qa.md
  references/experts/researcher.md
  references/experts/troubleshooter.md
  references/experts/ui-operator.md
)
CURSOR_ROLE_FILES=(
  agent-team-code-reviewer.md
  agent-team-fullstack-engineer.md
  agent-team-generalist.md
  agent-team-qa.md
  agent-team-researcher.md
  agent-team-troubleshooter.md
  agent-team-ui-operator.md
)
CURSOR_MANIFEST_NAME=".agent-team-managed-agents"

TEMP_SOURCE=""
TEMP_FETCH_REPO=""
AUX_TEMP=""
TXN_STAGE=""
TXN_CURRENT_BACKUP=""
TXN_CURRENT_DEST=""
TXN_CURRENT_ACTIVATED=false
TXN_COMMITTED=false
TXN_DESTS=()
TXN_BACKUPS=()
TXN_KEEP_BACKUPS=()
TXN_COUNT=0

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

remove_path() {
  local path="$1"

  if [[ -d "$path" && ! -L "$path" ]]; then
    rm -rf -- "$path"
  else
    rm -f -- "$path"
  fi
}

restore_path() {
  local dest="$1"
  local backup="$2"
  local backup_parent

  if [[ -n "$backup" ]] && ! path_exists "$backup"; then
    return 1
  fi
  if path_exists "$dest"; then
    remove_path "$dest" || return 1
  fi
  if [[ -n "$backup" ]] && path_exists "$backup"; then
    backup_parent="$(dirname "$backup")"
    mv -- "$backup" "$dest"
    rmdir "$backup_parent" 2>/dev/null || true
  fi
}

rollback_transaction() {
  local index
  local ok=true
  local current_recorded=false

  if [[ -n "$TXN_CURRENT_DEST" ]]; then
    if [[ "$TXN_COUNT" -gt 0 && "${TXN_DESTS[$((TXN_COUNT - 1))]}" == "$TXN_CURRENT_DEST" ]]; then
      current_recorded=true
    fi
    if ! $current_recorded && { $TXN_CURRENT_ACTIVATED || path_exists "$TXN_CURRENT_BACKUP"; }; then
      if ! restore_path "$TXN_CURRENT_DEST" "$TXN_CURRENT_BACKUP"; then
        echo "Rollback warning: could not restore $TXN_CURRENT_DEST; backup kept at $TXN_CURRENT_BACKUP" >&2
        ok=false
      fi
    fi
  fi

  for ((index=TXN_COUNT - 1; index >= 0; index--)); do
    if ! restore_path "${TXN_DESTS[$index]}" "${TXN_BACKUPS[$index]}"; then
      echo "Rollback warning: could not restore ${TXN_DESTS[$index]}; backup kept at ${TXN_BACKUPS[$index]}" >&2
      ok=false
    fi
  done

  $ok
}

commit_transaction() {
  local index

  TXN_COMMITTED=true
  for ((index=0; index < TXN_COUNT; index++)); do
    if [[ -z "${TXN_BACKUPS[$index]}" ]]; then
      continue
    fi
    if [[ "${TXN_KEEP_BACKUPS[$index]}" == true ]]; then
      echo "Preserved previous skill → ${TXN_BACKUPS[$index]}"
    else
      remove_path "${TXN_BACKUPS[$index]}" || echo "Cleanup warning: stale backup kept at ${TXN_BACKUPS[$index]}" >&2
    fi
  done
  TXN_DESTS=()
  TXN_BACKUPS=()
  TXN_KEEP_BACKUPS=()
  TXN_COUNT=0
}

cleanup() {
  local status=$?

  if [[ "$status" -ne 0 && "$TXN_COMMITTED" == false ]]; then
    rollback_transaction || true
  fi
  [[ -z "$TXN_STAGE" || ! -e "$TXN_STAGE" ]] || rm -rf "$TXN_STAGE"
  [[ -z "$TEMP_SOURCE" || ! -e "$TEMP_SOURCE" ]] || rm -rf "$TEMP_SOURCE"
  [[ -z "$TEMP_FETCH_REPO" || ! -e "$TEMP_FETCH_REPO" ]] || rm -rf "$TEMP_FETCH_REPO"
  [[ -z "$AUX_TEMP" || ! -e "$AUX_TEMP" ]] || rm -f "$AUX_TEMP"
  return "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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

validate_skill_source() {
  local root="$1"
  local relative
  local expert_count

  if [[ ! -d "$root" || -L "$root" ]]; then
    echo "Install failed: skill source is not a regular directory: $root" >&2
    return 1
  fi
  if [[ -n "$(find "$root" -type l -print -quit)" ]]; then
    echo "Install failed: skill source must not contain symlinks: $root" >&2
    return 1
  fi

  for relative in "${SKILL_MANIFEST[@]}"; do
    if [[ ! -f "$root/$relative" || -L "$root/$relative" ]]; then
      echo "Install failed: required regular file is missing or unsafe: $root/$relative" >&2
      return 1
    fi
  done

  expert_count="$(find "$root/references/experts" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d '[:space:]')"
  if [[ "$expert_count" != "7" ]]; then
    echo "Install failed: expected exactly 7 expert profiles, found $expert_count at $root/references/experts" >&2
    return 1
  fi
}

git_safe() {
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 git "$@"
}

prepare_remote_source() {
  local actual_origin
  local cache_created=false
  local commit
  local fetch_repo

  if ! command -v git >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    echo "Install failed: git and tar are required for remote installation." >&2
    return 1
  fi
  if [[ -z "$REF" || "$REF" == -* ]]; then
    echo "Install failed: AGENT_TEAM_REF must be a nonempty ref and cannot start with '-'." >&2
    return 1
  fi
  if [[ -z "$REPO_URL" || "$REPO_URL" == -* ]]; then
    echo "Install failed: AGENT_TEAM_REPO_URL must be nonempty and cannot start with '-'." >&2
    return 1
  fi
  case "$REPO_URL" in
    *://*@*|*\?*|*\#*)
      echo "Install failed: AGENT_TEAM_REPO_URL must not embed credentials, query parameters, or fragments." >&2
      return 1
      ;;
  esac

  mkdir -p "$(dirname "$CACHE_DIR")"
  if [[ -e "$CACHE_DIR" && ! -d "$CACHE_DIR/.git" ]]; then
    echo "Install failed: cache exists but is not a Git checkout: $CACHE_DIR" >&2
    return 1
  fi

  if [[ ! -d "$CACHE_DIR/.git" ]]; then
    echo "Cloning Agent Team cache..."
    git_safe clone --no-checkout --quiet -- "$REPO_URL" "$CACHE_DIR"
    cache_created=true
  fi

  actual_origin="$(git_safe -C "$CACHE_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$actual_origin" != "$REPO_URL" ]]; then
    echo "Install failed: cache origin mismatch." >&2
    return 1
  fi

  if $cache_created; then
    fetch_repo="$CACHE_DIR"
  else
    TEMP_FETCH_REPO="$(mktemp -d "${TMPDIR:-/tmp}/agent-team-fetch.XXXXXX")"
    fetch_repo="$TEMP_FETCH_REPO/repo"
    git_safe clone --no-checkout --quiet --reference-if-able "$CACHE_DIR" -- "$REPO_URL" "$fetch_repo"
  fi

  echo "Fetching Agent Team source..."
  git_safe -C "$fetch_repo" fetch --force --quiet origin "$REF"
  commit="$(GIT_NO_REPLACE_OBJECTS=1 git_safe -C "$fetch_repo" rev-parse --verify 'FETCH_HEAD^{commit}')"

  TEMP_SOURCE="$(mktemp -d "${TMPDIR:-/tmp}/agent-team-source.XXXXXX")"
  GIT_NO_REPLACE_OBJECTS=1 git_safe -C "$fetch_repo" archive "$commit" agent-team | tar -xf - -C "$TEMP_SOURCE"
  SRC="$TEMP_SOURCE/agent-team"
}

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
  prepare_remote_source
fi
validate_skill_source "$SRC"

copy_skill_transactional() {
  local backup_parent
  local dest_parent="$1"
  local relative
  local staged
  local dest="$dest_parent/agent-team"

  mkdir -p "$dest_parent"
  TXN_STAGE="$(mktemp -d "$dest_parent/.agent-team-stage.XXXXXX")"
  staged="$TXN_STAGE/agent-team"
  mkdir -p "$staged"
  for relative in "${SKILL_MANIFEST[@]}"; do
    mkdir -p "$(dirname "$staged/$relative")"
    cp "$SRC/$relative" "$staged/$relative"
  done
  validate_skill_source "$staged"
  if [[ -d "$dest" && ! -L "$dest" ]] && diff -qr "$staged" "$dest" >/dev/null; then
    rm -rf "$TXN_STAGE"
    TXN_STAGE=""
    echo "Skill already current → $dest"
    return
  fi
  backup_parent="$(dirname "$dest_parent")/backups"
  activate_staged_path "$staged" "$dest" "$backup_parent" true
  rm -rf "$TXN_STAGE"
  TXN_STAGE=""
  echo "Installed skill → $dest"
}

activate_staged_path() {
  local staged="$1"
  local dest="$2"
  local backup_parent="${3:-}"
  local keep_backup="${4:-false}"
  local dest_parent

  dest_parent="$(dirname "$dest")"
  TXN_CURRENT_DEST="$dest"
  TXN_CURRENT_BACKUP=""
  TXN_CURRENT_ACTIVATED=false

  if path_exists "$dest"; then
    if [[ -z "$backup_parent" ]]; then
      backup_parent="$dest_parent"
    fi
    mkdir -p "$backup_parent"
    TXN_CURRENT_BACKUP="$(mktemp -d "$backup_parent/.agent-team-backup.XXXXXX")"
    rmdir "$TXN_CURRENT_BACKUP"
    mv -- "$dest" "$TXN_CURRENT_BACKUP"
  fi

  if ! mv -- "$staged" "$dest"; then
    echo "Install failed: could not activate staged path at $dest" >&2
    return 1
  fi
  TXN_CURRENT_ACTIVATED=true
  TXN_DESTS[$TXN_COUNT]="$dest"
  TXN_BACKUPS[$TXN_COUNT]="$TXN_CURRENT_BACKUP"
  TXN_KEEP_BACKUPS[$TXN_COUNT]="$keep_backup"
  TXN_COUNT=$((TXN_COUNT + 1))
  TXN_CURRENT_DEST=""
  TXN_CURRENT_BACKUP=""
  TXN_CURRENT_ACTIVATED=false
}

copy_file_transactional() {
  local source="$1"
  local dest="$2"
  local dest_parent

  dest_parent="$(dirname "$dest")"
  mkdir -p "$dest_parent"
  TXN_STAGE="$(mktemp "$dest_parent/.agent-team-file-stage.XXXXXX")"
  cp "$source" "$TXN_STAGE"
  activate_staged_path "$TXN_STAGE" "$dest"
  TXN_STAGE=""
}

warn_legacy_cursor_agents() {
  local agents_dir="$1"
  local legacy_names=(
    code-reviewer.md
    fullstack-engineer.md
    generalist.md
    qa.md
    researcher.md
    troubleshooter.md
    ui-operator.md
  )
  local found=()
  local name

  for name in "${legacy_names[@]}"; do
    if [[ -e "$agents_dir/$name" ]]; then
      found+=("$name")
    fi
  done

  if [[ ${#found[@]} -gt 0 ]]; then
    echo "Migration warning: legacy generic Cursor agent profiles were found in $agents_dir:" >&2
    printf '  %s\n' "${found[@]}" >&2
    echo "They were left untouched. Back them up and remove them if they belong to an older Agent Team install." >&2
  fi
}

install_cursor_agents() {
  local agents_dir="$1"
  local manifest="$agents_dir/$CURSOR_MANIFEST_NAME"
  local installed
  local known
  local expert
  local manifest_stage
  local is_known

  warn_legacy_cursor_agents "$agents_dir"

  for installed in "$agents_dir"/agent-team-*.md; do
    [[ -e "$installed" ]] || continue
    is_known=false
    for known in "${CURSOR_ROLE_FILES[@]}"; do
      if [[ "$(basename "$installed")" == "$known" ]]; then
        is_known=true
        break
      fi
    done
    if ! $is_known; then
      echo "Migration warning: unknown namespaced Cursor profile preserved: $installed" >&2
    fi
  done

  for expert in "$SRC/references/experts/"*.md; do
    copy_file_transactional "$expert" "$agents_dir/agent-team-$(basename "$expert")"
  done

  manifest_stage="$(mktemp "${TMPDIR:-/tmp}/agent-team-manifest.XXXXXX")"
  AUX_TEMP="$manifest_stage"
  printf '%s\n' "${CURSOR_ROLE_FILES[@]}" > "$manifest_stage"
  copy_file_transactional "$manifest_stage" "$manifest"
  rm -f "$manifest_stage"
  AUX_TEMP=""
}

warn_legacy_codex_copy() {
  local legacy="$TARGET_HOME/.agents/skills/agent-team"
  local canonical="$CODEX_ROOT/skills/agent-team"

  if [[ -e "$legacy" ]]; then
    if [[ -e "$canonical" && "$legacy" -ef "$canonical" ]]; then
      return
    fi
    echo "Migration warning: legacy Codex skill copy found at $legacy." >&2
    echo "Codex now uses $canonical only. Back up and remove the legacy copy to avoid duplicate discovery." >&2
  fi
}

if $install_cursor; then
  mkdir -p "$TARGET_HOME/.cursor/skills" "$TARGET_HOME/.cursor/agents" "$TARGET_HOME/.cursor/commands"
  copy_skill_transactional "$TARGET_HOME/.cursor/skills"
  install_cursor_agents "$TARGET_HOME/.cursor/agents"
  copy_file_transactional "$SRC/commands/agent-team.md" "$TARGET_HOME/.cursor/commands/agent-team.md"
  echo "Installed Cursor agents → $TARGET_HOME/.cursor/agents/agent-team-*.md"
  echo "Installed Cursor command → $TARGET_HOME/.cursor/commands/agent-team.md"
fi

if $install_claude; then
  mkdir -p "$TARGET_HOME/.claude/skills"
  copy_skill_transactional "$TARGET_HOME/.claude/skills"
fi

if $install_codex; then
  warn_legacy_codex_copy
  mkdir -p "$CODEX_ROOT/skills"
  copy_skill_transactional "$CODEX_ROOT/skills"
fi

commit_transaction

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
