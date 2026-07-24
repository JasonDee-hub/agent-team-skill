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

assert_managed_agent_manifest() {
  local agents_dir="$1"
  local manifest="$agents_dir/.agent-team-managed-agents"
  local expected=(
    agent-team-code-reviewer.md
    agent-team-fullstack-engineer.md
    agent-team-generalist.md
    agent-team-qa.md
    agent-team-researcher.md
    agent-team-troubleshooter.md
    agent-team-ui-operator.md
  )
  local name
  local actual

  assert_exists "$manifest"
  actual="$(wc -l < "$manifest" | tr -d '[:space:]')"
  [[ "$actual" == "7" ]] || fail "expected 7 manifest entries, found $actual"
  for name in "${expected[@]}"; do
    grep -Fqx "$name" "$manifest" || fail "manifest missing $name"
    assert_exists "$agents_dir/$name"
  done
}

assert_trees_equal() {
  diff -qr "$1" "$2" >/dev/null || fail "expected trees to match: $1 and $2"
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
printf '%s\n' 'custom namespaced profile' > "$cursor_home/.cursor/agents/agent-team-custom.md"
printf '%s\n' 'old managed profile' > "$cursor_home/.cursor/agents/agent-team-qa.md"
cursor_output="$(run_install "$cursor_home" 2>&1)"
assert_contains "$cursor_output" "Migration warning: legacy generic Cursor agent profiles"
assert_contains "$cursor_output" "unknown namespaced Cursor profile preserved"
assert_exists "$cursor_home/.cursor/skills/agent-team/SKILL.md"
assert_exists "$cursor_home/.cursor/commands/agent-team.md"
assert_exists "$cursor_home/.cursor/agents/qa.md"
assert_contains "$(<"$cursor_home/.cursor/agents/qa.md")" "user-owned sentinel"
assert_contains "$(<"$cursor_home/.cursor/agents/agent-team-custom.md")" "custom namespaced profile"
assert_not_contains "$(<"$cursor_home/.cursor/agents/agent-team-qa.md")" "old managed profile"
assert_not_exists "$cursor_home/.agents/skills/agent-team"
assert_not_exists "$cursor_home/.claude"
assert_not_exists "$cursor_home/.codex"
assert_prefixed_agent_count "$cursor_home/.cursor/agents" 8
assert_managed_agent_manifest "$cursor_home/.cursor/agents"

printf '%s\n' 'agent-team-custom.md' >> "$cursor_home/.cursor/agents/.agent-team-managed-agents"
run_install "$cursor_home" --cursor >/dev/null
assert_contains "$(<"$cursor_home/.cursor/agents/agent-team-custom.md")" "custom namespaced profile"
assert_managed_agent_manifest "$cursor_home/.cursor/agents"

cursor_snapshot="$TMP_ROOT/cursor-snapshot"
cp -R "$cursor_home/.cursor" "$cursor_snapshot"
run_install "$cursor_home" --cursor >/dev/null
assert_trees_equal "$cursor_snapshot" "$cursor_home/.cursor"
assert_prefixed_agent_count "$cursor_home/.cursor/agents" 8
assert_managed_agent_manifest "$cursor_home/.cursor/agents"

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

echo "Testing changed skill installations preserve a recoverable backup..."
printf '%s\n' 'local customization sentinel' > "$codex_home/.codex/skills/agent-team/local-note.txt"
backup_output="$(run_install "$codex_home" --codex)"
assert_contains "$backup_output" "Preserved previous skill"
assert_not_exists "$codex_home/.codex/skills/agent-team/local-note.txt"
backup_dir="$(find "$codex_home/.codex/backups" -mindepth 1 -maxdepth 1 -type d -name '.agent-team-backup.*' -print -quit)"
[[ -n "$backup_dir" ]] || fail "expected a recoverable previous skill backup"
assert_contains "$(<"$backup_dir/local-note.txt")" "local customization sentinel"
assert_trees_equal "$ROOT/agent-team" "$codex_home/.codex/skills/agent-team"

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

echo "Testing malformed local source preserves the current installation..."
malformed_root="$TMP_ROOT/malformed-source"
malformed_home="$TMP_ROOT/malformed-home"
mkdir -p "$malformed_root" \
  "$malformed_home/.codex/skills/agent-team" \
  "$malformed_home/.cursor/skills/agent-team" \
  "$malformed_home/.cursor/agents"
cp "$ROOT/install.sh" "$malformed_root/install.sh"
cp -R "$ROOT/agent-team" "$malformed_root/agent-team"
rm -f "$malformed_root/agent-team/references/handoff.md"
printf '%s\n' 'working version sentinel' > "$malformed_home/.codex/skills/agent-team/SKILL.md"
printf '%s\n' 'working Cursor skill sentinel' > "$malformed_home/.cursor/skills/agent-team/SKILL.md"
printf '%s\n' 'working Cursor profile sentinel' > "$malformed_home/.cursor/agents/agent-team-qa.md"
if CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$malformed_home" bash "$malformed_root/install.sh" --codex >/dev/null 2>&1; then
  fail "malformed source unexpectedly installed"
fi
assert_contains "$(<"$malformed_home/.codex/skills/agent-team/SKILL.md")" "working version sentinel"
if CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$malformed_home" bash "$malformed_root/install.sh" --cursor >/dev/null 2>&1; then
  fail "malformed source unexpectedly changed Cursor"
fi
assert_contains "$(<"$malformed_home/.cursor/skills/agent-team/SKILL.md")" "working Cursor skill sentinel"
assert_contains "$(<"$malformed_home/.cursor/agents/agent-team-qa.md")" "working Cursor profile sentinel"

echo "Testing whole-install rollback after a late Cursor failure..."
rollback_home="$TMP_ROOT/rollback-home"
rollback_snapshot="$TMP_ROOT/rollback-snapshot"
mkdir -p \
  "$rollback_home/.cursor/skills/agent-team" \
  "$rollback_home/.cursor/agents" \
  "$rollback_home/.cursor/commands"
printf '%s\n' 'old skill sentinel' > "$rollback_home/.cursor/skills/agent-team/SKILL.md"
printf '%s\n' 'old profile sentinel' > "$rollback_home/.cursor/agents/agent-team-qa.md"
printf '%s\n' 'custom profile sentinel' > "$rollback_home/.cursor/agents/agent-team-custom.md"
printf '%s\n' 'old command sentinel' > "$rollback_home/.cursor/commands/agent-team.md"
cp -R "$rollback_home/.cursor" "$rollback_snapshot"
if TMPDIR="$TMP_ROOT/missing-tmp" CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$rollback_home" \
  bash "$ROOT/install.sh" --cursor >/dev/null 2>&1; then
  fail "late Cursor failure unexpectedly succeeded"
fi
assert_trees_equal "$rollback_snapshot" "$rollback_home/.cursor"

echo "Testing --all rollback restores earlier platforms..."
all_rollback_home="$TMP_ROOT/all-rollback-home"
all_rollback_snapshot="$TMP_ROOT/all-rollback-snapshot"
mkdir -p \
  "$all_rollback_home/.cursor/skills/agent-team" \
  "$all_rollback_home/.cursor/agents" \
  "$all_rollback_home/.cursor/commands"
printf '%s\n' 'old all skill sentinel' > "$all_rollback_home/.cursor/skills/agent-team/SKILL.md"
printf '%s\n' 'old all command sentinel' > "$all_rollback_home/.cursor/commands/agent-team.md"
printf '%s\n' 'blocks Claude directory creation' > "$all_rollback_home/.claude"
cp -R "$all_rollback_home/.cursor" "$all_rollback_snapshot"
if CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$all_rollback_home" bash "$ROOT/install.sh" --all >/dev/null 2>&1; then
  fail "--all with a blocked Claude destination unexpectedly succeeded"
fi
assert_trees_equal "$all_rollback_snapshot" "$all_rollback_home/.cursor"
assert_contains "$(<"$all_rollback_home/.claude")" "blocks Claude directory creation"
assert_not_exists "$all_rollback_home/.codex"

echo "Testing fixed install payload ignores unlisted files..."
unlisted_root="$TMP_ROOT/unlisted-source"
unlisted_home="$TMP_ROOT/unlisted-home"
mkdir -p "$unlisted_root"
cp "$ROOT/install.sh" "$unlisted_root/install.sh"
cp -R "$ROOT/agent-team" "$unlisted_root/agent-team"
printf '%s\n' 'must not be installed' > "$unlisted_root/agent-team/unlisted.txt"
CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$unlisted_home" bash "$unlisted_root/install.sh" --codex >/dev/null
assert_not_exists "$unlisted_home/.codex/skills/agent-team/unlisted.txt"
assert_trees_equal "$ROOT/agent-team" "$unlisted_home/.codex/skills/agent-team"

echo "Testing fixed expert manifest rejection..."
extra_root="$TMP_ROOT/extra-source"
extra_home="$TMP_ROOT/extra-home"
mkdir -p "$extra_root" "$extra_home/.codex/skills/agent-team"
cp "$ROOT/install.sh" "$extra_root/install.sh"
cp -R "$ROOT/agent-team" "$extra_root/agent-team"
printf '%s\n' 'unexpected eighth profile' > "$extra_root/agent-team/references/experts/extra.md"
printf '%s\n' 'preserved after extra profile' > "$extra_home/.codex/skills/agent-team/SKILL.md"
if CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$extra_home" bash "$extra_root/install.sh" --codex >/dev/null 2>&1; then
  fail "source with an eighth expert unexpectedly installed"
fi
assert_contains "$(<"$extra_home/.codex/skills/agent-team/SKILL.md")" "preserved after extra profile"

echo "Testing dirty remote cache isolation..."
dirty_cache="$TMP_ROOT/dirty-cache"
dirty_first_home="$TMP_ROOT/dirty-first-home"
dirty_second_home="$TMP_ROOT/dirty-second-home"
CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$dirty_first_home" AGENT_TEAM_CACHE_DIR="$dirty_cache" \
  AGENT_TEAM_REPO_URL="$ROOT" AGENT_TEAM_REF=HEAD bash -s -- --codex < "$ROOT/install.sh" >/dev/null
git -C "$dirty_cache" checkout -f FETCH_HEAD -- agent-team/SKILL.md
printf '%s\n' 'tampered tracked cache content' > "$dirty_cache/agent-team/SKILL.md"
mkdir -p "$dirty_cache/agent-team/references/experts"
printf '%s\n' 'untracked cache content' > "$dirty_cache/agent-team/references/experts/cache-injected.md"
git -C "$dirty_cache" config remote.origin.uploadpack /definitely/missing-agent-team-upload-pack
CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$dirty_second_home" AGENT_TEAM_CACHE_DIR="$dirty_cache" \
  AGENT_TEAM_REPO_URL="$ROOT" AGENT_TEAM_REF=HEAD bash -s -- --codex < "$ROOT/install.sh" >/dev/null
assert_not_contains "$(<"$dirty_second_home/.codex/skills/agent-team/SKILL.md")" "tampered tracked cache content"
assert_not_exists "$dirty_second_home/.codex/skills/agent-team/references/experts/cache-injected.md"
dirty_expected="$TMP_ROOT/dirty-expected"
mkdir -p "$dirty_expected"
git -C "$dirty_cache" archive FETCH_HEAD agent-team | tar -xf - -C "$dirty_expected"
assert_trees_equal "$dirty_expected/agent-team" "$dirty_second_home/.codex/skills/agent-team"

echo "Testing Git replace refs cannot alter the fetched payload..."
replace_original="$(git -C "$dirty_cache" rev-parse FETCH_HEAD)"
git -C "$dirty_cache" checkout -f "$replace_original" >/dev/null
rm -f "$dirty_cache/agent-team/references/experts/cache-injected.md"
printf '%s\n' 'replace-ref injected content' > "$dirty_cache/agent-team/SKILL.md"
git -C "$dirty_cache" add agent-team/SKILL.md
git -C "$dirty_cache" -c user.name='Agent Team Test' -c user.email='agent-team@example.invalid' \
  commit -m 'malicious replacement' >/dev/null
replace_commit="$(git -C "$dirty_cache" rev-parse HEAD)"
git -C "$dirty_cache" replace "$replace_original" "$replace_commit"
replace_home="$TMP_ROOT/replace-home"
CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$replace_home" AGENT_TEAM_CACHE_DIR="$dirty_cache" \
  AGENT_TEAM_REPO_URL="$ROOT" AGENT_TEAM_REF=HEAD bash -s -- --codex < "$ROOT/install.sh" >/dev/null
assert_not_contains "$(<"$replace_home/.codex/skills/agent-team/SKILL.md")" "replace-ref injected content"

echo "Testing cache origin mismatch rejection..."
wrong_origin_home="$TMP_ROOT/wrong-origin-home"
mkdir -p "$wrong_origin_home/.codex/skills/agent-team"
printf '%s\n' 'preserved on origin mismatch' > "$wrong_origin_home/.codex/skills/agent-team/SKILL.md"
git -C "$dirty_cache" remote set-url origin "$TMP_ROOT/not-the-requested-origin"
if wrong_origin_output="$(CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$wrong_origin_home" AGENT_TEAM_CACHE_DIR="$dirty_cache" \
  AGENT_TEAM_REPO_URL="$ROOT" AGENT_TEAM_REF=HEAD bash -s -- --codex < "$ROOT/install.sh" 2>&1)"; then
  fail "wrong cache origin unexpectedly installed"
fi
assert_contains "$wrong_origin_output" "cache origin mismatch"
assert_contains "$(<"$wrong_origin_home/.codex/skills/agent-team/SKILL.md")" "preserved on origin mismatch"

echo "Testing repository URLs never expose embedded credentials..."
credential_home="$TMP_ROOT/credential-home"
if credential_output="$(CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$credential_home" \
  AGENT_TEAM_CACHE_DIR="$TMP_ROOT/credential-cache" \
  AGENT_TEAM_REPO_URL='https://agent:super-secret@example.invalid/repo.git' \
  bash -s -- --codex < "$ROOT/install.sh" 2>&1)"; then
  fail "credential-bearing repository URL unexpectedly accepted"
fi
assert_contains "$credential_output" "must not embed credentials"
assert_not_contains "$credential_output" "super-secret"

echo "Testing compatibility wrapper URLs are rejected without credential disclosure..."
for unsafe_install_url in \
  'https://agent:wrapper-secret@example.invalid/install.sh' \
  'https://example.invalid/install.sh?token=wrapper-secret' \
  'https://example.invalid/install.sh#wrapper-secret'; do
  if wrapper_credential_output="$(
    AGENT_TEAM_INSTALL_URL="$unsafe_install_url" \
      bash -s -- --codex < "$ROOT/scripts/install-from-github.sh" 2>&1
  )"; then
    fail "unsafe compatibility wrapper URL unexpectedly accepted"
  fi
  assert_contains "$wrapper_credential_output" "AGENT_TEAM_INSTALL_URL must not embed credentials, query parameters, or fragments"
  assert_not_contains "$wrapper_credential_output" "wrapper-secret"
done

echo "Testing compatibility wrapper fetch failures do not disclose URL paths..."
if wrapper_fetch_output="$(
  AGENT_TEAM_INSTALL_URL="file://$TMP_ROOT/nonexistent-wrapper-secret/install.sh" \
    bash -s -- --codex < "$ROOT/scripts/install-from-github.sh" 2>&1
)"; then
  fail "missing compatibility wrapper URL unexpectedly succeeded"
fi
assert_contains "$wrapper_fetch_output" "could not fetch the installer"
assert_not_contains "$wrapper_fetch_output" "wrapper-secret"

echo "Testing incomplete wrapper downloads are never executed..."
partial_bin="$TMP_ROOT/partial-bin"
partial_sentinel="$TMP_ROOT/partial-installer-executed"
mkdir -p "$partial_bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "$1" == "-q" ]] || exit 91' \
  'while [[ $# -gt 0 ]]; do' \
  '  if [[ "$1" == "--output" ]]; then' \
  '    printf '"'"'%s\n'"'"' '"'"'touch "$PARTIAL_SENTINEL"'"'"' > "$2"' \
  '    exit 22' \
  '  fi' \
  '  shift' \
  'done' \
  'exit 92' > "$partial_bin/curl"
chmod +x "$partial_bin/curl"
if partial_fetch_output="$(
  PATH="$partial_bin:/usr/bin:/bin" \
    PARTIAL_SENTINEL="$partial_sentinel" \
    AGENT_TEAM_INSTALL_URL="https://example.invalid/install.sh" \
    bash -s -- --codex < "$ROOT/scripts/install-from-github.sh" 2>&1
)"; then
  fail "partial compatibility wrapper download unexpectedly succeeded"
fi
assert_contains "$partial_fetch_output" "could not fetch the installer"
assert_not_exists "$partial_sentinel"

echo "Testing empty wrapper downloads fail closed..."
empty_bin="$TMP_ROOT/empty-bin"
mkdir -p "$empty_bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "$1" == "-q" ]] || exit 91' \
  'exit 0' > "$empty_bin/curl"
chmod +x "$empty_bin/curl"
if empty_fetch_output="$(
  PATH="$empty_bin:/usr/bin:/bin" \
    AGENT_TEAM_INSTALL_URL="https://example.invalid/install.sh" \
    bash -s -- --codex < "$ROOT/scripts/install-from-github.sh" 2>&1
)"; then
  fail "empty compatibility wrapper download unexpectedly succeeded"
fi
assert_contains "$empty_fetch_output" "downloaded installer is empty"

echo "Testing local compatibility wrapper..."
wrapper_home="$TMP_ROOT/wrapper-home"
CODEX_HOME="" AGENT_TEAM_TARGET_HOME="$wrapper_home" bash "$ROOT/scripts/install-from-github.sh" --codex >/dev/null
assert_exists "$wrapper_home/.codex/skills/agent-team/SKILL.md"
assert_not_exists "$wrapper_home/.agents/skills/agent-team"

echo "Testing streamed compatibility wrapper fallback..."
stream_home="$TMP_ROOT/stream-home"
curlrc_home="$TMP_ROOT/curlrc-home"
mkdir -p "$curlrc_home"
printf 'output = "%s"\n' "$TMP_ROOT/curlrc-output" > "$curlrc_home/.curlrc"
curl -q -fsSL "file://$ROOT/scripts/install-from-github.sh" | \
  CURL_HOME="$curlrc_home" \
  CODEX_HOME="" \
  AGENT_TEAM_TARGET_HOME="$stream_home" \
  AGENT_TEAM_CACHE_DIR="$TMP_ROOT/stream-cache" \
  AGENT_TEAM_INSTALL_URL="file://$ROOT/install.sh" \
  AGENT_TEAM_REPO_URL="$ROOT" \
  AGENT_TEAM_REF=HEAD \
  bash -s -- --codex >/dev/null
assert_exists "$stream_home/.codex/skills/agent-team/SKILL.md"
assert_not_exists "$stream_home/.agents/skills/agent-team"
assert_not_exists "$TMP_ROOT/curlrc-output"

echo "All installer tests passed."
