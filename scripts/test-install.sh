#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-team-install-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_exists() {
  [[ -e "$1" ]] || fail "expected $1 to exist"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "expected $1 not to exist"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected output not to contain: $needle"
}

assert_prefixed_agent_count() {
  local agents_dir="$1"
  local expected="$2"
  local actual

  actual="$(find "$agents_dir" -maxdepth 1 -type f -name 'agent-team-*.md' | wc -l | tr -d '[:space:]')"
  [[ "$actual" == "$expected" ]] || fail "expected $expected prefixed agents in $agents_dir, found $actual"
}

run_install() {
  local target_home="$1"
  shift
  CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$target_home" bash "$ROOT/install.sh" "$@"
}

echo "Testing Cursor installation and migration safety..."
cursor_home="$TMP_ROOT/cursor-home"
mkdir -p "$cursor_home/.cursor/agents"
printf '%s\n' 'user-owned sentinel' > "$cursor_home/.cursor/agents/qa.md"
printf '%s\n' 'stale profile' > "$cursor_home/.cursor/agents/agent-team-stale.md"
cursor_output="$(run_install "$cursor_home" 2>&1)"
assert_contains "$cursor_output" "Migration warning: legacy generic Cursor agent profiles"
assert_exists "$cursor_home/.cursor/skills/agent-team/SKILL.md"
assert_exists "$cursor_home/.cursor/commands/agent-team.md"
assert_exists "$cursor_home/.cursor/agents/qa.md"
assert_contains "$(<"$cursor_home/.cursor/agents/qa.md")" "user-owned sentinel"
assert_not_exists "$cursor_home/.cursor/agents/agent-team-stale.md"
assert_not_exists "$cursor_home/.agents/skills/agent-team"
assert_not_exists "$cursor_home/.claude"
assert_not_exists "$cursor_home/.codex"
assert_prefixed_agent_count "$cursor_home/.cursor/agents" 7

printf '%s\n' 'another stale profile' > "$cursor_home/.cursor/agents/agent-team-obsolete.md"
run_install "$cursor_home" --cursor >/dev/null
assert_not_exists "$cursor_home/.cursor/agents/agent-team-obsolete.md"
assert_prefixed_agent_count "$cursor_home/.cursor/agents" 7

echo "Testing Claude Code installation..."
claude_home="$TMP_ROOT/claude-home"
run_install "$claude_home" --claude >/dev/null
assert_exists "$claude_home/.claude/skills/agent-team/SKILL.md"
assert_not_exists "$claude_home/.cursor"
assert_not_exists "$claude_home/.codex"
assert_not_exists "$claude_home/.agents"

echo "Testing canonical Codex installation..."
codex_home="$TMP_ROOT/codex-home"
run_install "$codex_home" --codex >/dev/null
assert_exists "$codex_home/.codex/skills/agent-team/SKILL.md"
assert_not_exists "$codex_home/.agents/skills/agent-team"
assert_not_exists "$codex_home/.cursor"
assert_not_exists "$codex_home/.claude"

echo "Testing legacy Codex migration warning..."
legacy_codex_home="$TMP_ROOT/legacy-codex-home"
mkdir -p "$legacy_codex_home/.agents/skills/agent-team"
printf '%s\n' 'legacy sentinel' > "$legacy_codex_home/.agents/skills/agent-team/SKILL.md"
legacy_codex_output="$(run_install "$legacy_codex_home" --codex 2>&1)"
assert_contains "$legacy_codex_output" "Migration warning: legacy Codex skill copy"
assert_contains "$(<"$legacy_codex_home/.agents/skills/agent-team/SKILL.md")" "legacy sentinel"
assert_exists "$legacy_codex_home/.codex/skills/agent-team/SKILL.md"

echo "Testing custom CODEX_HOME..."
custom_home="$TMP_ROOT/custom-target-home"
custom_codex_root="$TMP_ROOT/custom-codex-root"
AGENT_TEAM_TARGET_HOME="$custom_home" CODEX_HOME="$custom_codex_root" bash "$ROOT/install.sh" --codex >/dev/null
assert_exists "$custom_codex_root/skills/agent-team/SKILL.md"
assert_not_exists "$custom_home/.codex"
assert_not_exists "$custom_home/.agents/skills/agent-team"

echo "Testing CODEX_HOME at the legacy-looking canonical path..."
agents_codex_home="$TMP_ROOT/agents-codex-home"
mkdir -p "$agents_codex_home/.agents/skills/agent-team"
printf '%s\n' 'existing canonical copy' > "$agents_codex_home/.agents/skills/agent-team/SKILL.md"
agents_codex_output="$(AGENT_TEAM_TARGET_HOME="$agents_codex_home" CODEX_HOME="$agents_codex_home/.agents" bash "$ROOT/install.sh" --codex 2>&1)"
assert_not_contains "$agents_codex_output" "Migration warning: legacy Codex skill copy"
assert_exists "$agents_codex_home/.agents/skills/agent-team/SKILL.md"

echo "Testing --all installation..."
all_home="$TMP_ROOT/all-home"
run_install "$all_home" --all >/dev/null
assert_exists "$all_home/.cursor/skills/agent-team/SKILL.md"
assert_exists "$all_home/.cursor/commands/agent-team.md"
assert_prefixed_agent_count "$all_home/.cursor/agents" 7
assert_exists "$all_home/.claude/skills/agent-team/SKILL.md"
assert_exists "$all_home/.codex/skills/agent-team/SKILL.md"
assert_not_exists "$all_home/.agents/skills/agent-team"

echo "Testing local compatibility wrapper..."
wrapper_home="$TMP_ROOT/wrapper-home"
CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$wrapper_home" bash "$ROOT/scripts/install-from-github.sh" --codex >/dev/null
assert_exists "$wrapper_home/.codex/skills/agent-team/SKILL.md"
assert_not_exists "$wrapper_home/.agents/skills/agent-team"

echo "Testing streamed compatibility wrapper fallback..."
stream_home="$TMP_ROOT/stream-home"
curl -fsSL "file://$ROOT/scripts/install-from-github.sh" | \
  CODEX_HOME="" \
  AGENT_TEAM_TARGET_HOME="$stream_home" \
  AGENT_TEAM_CACHE_DIR="$TMP_ROOT/stream-cache" \
  AGENT_TEAM_INSTALL_URL="file://$ROOT/install.sh" \
  AGENT_TEAM_REPO_URL="$ROOT" \
  bash -s -- --codex >/dev/null
assert_exists "$stream_home/.codex/skills/agent-team/SKILL.md"
assert_not_exists "$stream_home/.agents/skills/agent-team"

echo "All installer tests passed."
