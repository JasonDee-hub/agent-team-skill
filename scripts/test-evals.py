#!/usr/bin/env python3
"""Regression tests for the Agent Team eval contract runner."""

from __future__ import annotations

import copy
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Optional


REPO = Path(__file__).resolve().parent.parent
RUNNER = REPO / "scripts/run-evals.py"
BEHAVIOR_RUNNER = REPO / "scripts/run-behavior-evals.py"
BASE_CASES = json.loads((REPO / "evals/cases.json").read_text(encoding="utf-8"))
BASE_REPLAY_CASES = json.loads((REPO / "evals/replay-cases.json").read_text(encoding="utf-8"))
BASE_REPLAY_RESULTS = json.loads((REPO / "evals/replay-results.json").read_text(encoding="utf-8"))


def run(cases: dict[str, Any], actual: Optional[dict[str, Any]] = None) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="agent-team-eval-test.") as temp_dir:
        temp = Path(temp_dir)
        cases_path = temp / "cases.json"
        cases_path.write_text(json.dumps(cases, ensure_ascii=False), encoding="utf-8")
        command = [sys.executable, str(RUNNER), "--cases", str(cases_path)]
        if actual is not None:
            actual_path = temp / "actual.json"
            actual_path.write_text(json.dumps(actual, ensure_ascii=False), encoding="utf-8")
            command.extend(["--actual", str(actual_path)])
        return subprocess.run(command, check=False, capture_output=True, text=True)


def run_behavior(cases: dict[str, Any], actual: dict[str, Any]) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="agent-team-behavior-test.") as temp_dir:
        temp = Path(temp_dir)
        cases_path = temp / "replay-cases.json"
        actual_path = temp / "replay-results.json"
        cases_path.write_text(json.dumps(cases, ensure_ascii=False), encoding="utf-8")
        actual_path.write_text(json.dumps(actual, ensure_ascii=False), encoding="utf-8")
        command = [
            sys.executable,
            str(BEHAVIOR_RUNNER),
            "--cases",
            str(cases_path),
            "--actual",
            str(actual_path),
        ]
        return subprocess.run(command, check=False, capture_output=True, text=True)


def run_with_kane_profile(profile: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="agent-team-skill-test.") as temp_dir:
        skill = Path(temp_dir) / "agent-team"
        shutil.copytree(REPO / "agent-team", skill)
        (skill / "references/experts/fullstack-engineer.md").write_text(profile, encoding="utf-8")
        command = [sys.executable, str(RUNNER), "--skill", str(skill)]
        return subprocess.run(command, check=False, capture_output=True, text=True)


def require_success(result: subprocess.CompletedProcess[str], label: str) -> None:
    if result.returncode != 0:
        raise AssertionError(f"{label} failed:\n{result.stderr}")


def require_failure(result: subprocess.CompletedProcess[str], label: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"{label} unexpectedly passed:\n{result.stdout}")


require_success(run(BASE_CASES), "valid eval definitions")

kane_profile = (REPO / "agent-team/references/experts/fullstack-engineer.md").read_text(encoding="utf-8")
boundary_rule = "- 区分 absent/empty 与一般 falsy；除非契约明确排除，否则保留 `0`、`false` 等合法值，禁止用宽泛 falsy 判断代替缺失/空判断\n"
require_failure(run_with_kane_profile(kane_profile.replace(boundary_rule, "")), "Kane profile without boundary-value rule")

performance_mutations = {
    "clear-code-fix-kane-only": ("initial_dispatches", 2),
    "same-agent-same-role-reuses-persona": ("restate_scope", False),
    "independent-read-only-parallel": ("parallel_when_independent", False),
    "strict-review-fix-targeted-delta": ("review_scope", "full_review"),
}

for case_id, (field, invalid_value) in performance_mutations.items():
    weakened_performance_contract = copy.deepcopy(BASE_CASES)
    for case in weakened_performance_contract["cases"]:
        if case["id"] == case_id:
            case["expected"]["efficiency"][field] = invalid_value
    require_failure(run(weakened_performance_contract), f"weakened performance contract: {case_id}.{field}")

acceptance_conflict_reported_done = copy.deepcopy(BASE_CASES)
for case in acceptance_conflict_reported_done["cases"]:
    if case["id"] == "strict-review-fix-targeted-delta":
        case["expected"]["efficiency"]["acceptance_conflict_blocks_done"] = False
require_failure(run(acceptance_conflict_reported_done), "acceptance-conflicting risk reported as done")

acceptance_conflict_skips_delta_fix = copy.deepcopy(BASE_CASES)
for case in acceptance_conflict_skips_delta_fix["cases"]:
    if case["id"] == "strict-review-fix-targeted-delta":
        case["expected"]["efficiency"]["acceptance_conflict_requires_delta_fix"] = False
require_failure(run(acceptance_conflict_skips_delta_fix), "acceptance conflict skips same-Kane delta fix")

missing_performance_invariant = copy.deepcopy(BASE_CASES)
for case in missing_performance_invariant["cases"]:
    if case["id"] == "clear-code-fix-kane-only":
        case["expected"]["invariants"].remove("lead_does_not_repeat_sufficient_evidence")
require_failure(run(missing_performance_invariant), "missing performance invariant")

missing_acceptance_conflict_invariant = copy.deepcopy(BASE_CASES)
for case in missing_acceptance_conflict_invariant["cases"]:
    if case["id"] == "strict-review-fix-targeted-delta":
        case["expected"]["invariants"].remove("acceptance_conflicting_risk_cannot_be_downgraded_to_risks")
require_failure(run(missing_acceptance_conflict_invariant), "missing acceptance-conflict invariant")

read_only_write = copy.deepcopy(BASE_CASES)
read_only_write["cases"][0]["expected"]["write_authority"]["write_paths"] = ["**"]
require_failure(run(read_only_write), "read-only contract with write paths")

missing_write_paths = copy.deepcopy(BASE_CASES)
for case in missing_write_paths["cases"]:
    if case["id"] == "clear-code-fix-kane-only":
        del case["expected"]["write_authority"]["write_paths"]
require_failure(run(missing_write_paths), "scoped-write contract without paths")

simulated_parallel = copy.deepcopy(BASE_CASES)
for case in simulated_parallel["cases"]:
    if case["id"] == "simulation-is-not-independent":
        case["expected"]["dispatch"] = {
            "roles": ["Kane", "Vera"],
            "mode": "parallel",
            "order": [],
            "concurrent_groups": [["Kane", "Vera"]],
        }
require_failure(run(simulated_parallel), "parallel single-agent simulation")

parallel_without_real_agents = copy.deepcopy(BASE_CASES)
for case in parallel_without_real_agents["cases"]:
    if case["id"] == "independent-read-only-parallel":
        del case["expected"]["execution_mode"]
require_failure(run(parallel_without_real_agents), "parallel dispatch without real agents")

incomplete_sequence = copy.deepcopy(BASE_CASES)
for case in incomplete_sequence["cases"]:
    if case["id"] == "feature-then-independent-qa":
        case["expected"]["dispatch"]["order"] = ["Kane"]
require_failure(run(incomplete_sequence), "sequential dispatch with an omitted role")

incomplete_parallel_group = copy.deepcopy(BASE_CASES)
for case in incomplete_parallel_group["cases"]:
    if case["id"] == "independent-read-only-parallel":
        case["expected"]["dispatch"]["concurrent_groups"] = [["Mira"]]
require_failure(run(incomplete_parallel_group), "parallel dispatch with an omitted role")

duplicate_parallel_role = copy.deepcopy(BASE_CASES)
for case in duplicate_parallel_role["cases"]:
    if case["id"] == "independent-read-only-parallel":
        case["expected"]["dispatch"]["concurrent_groups"] = [["Mira", "Reed"], ["Reed"]]
require_failure(run(duplicate_parallel_role), "parallel dispatch with a duplicate role")

broad_write_path = copy.deepcopy(BASE_CASES)
for case in broad_write_path["cases"]:
    if case["id"] == "clear-code-fix-kane-only":
        case["expected"]["write_authority"]["write_paths"] = ["/**"]
require_failure(run(broad_write_path), "scoped-write contract with a global path")

lead_fast_path_two_files = copy.deepcopy(BASE_CASES)
for case in lead_fast_path_two_files["cases"]:
    if case["id"] == "low-risk-single-file-lead-fast-path":
        paths = ["src/format.ts", "tests/format.test.ts"]
        case["expected"]["write_authority"]["write_paths"] = paths
        case["expected"]["scope"]["write_paths"] = paths
require_failure(run(lead_fast_path_two_files), "lead fast path with two write files")

lead_fast_path_external_action = copy.deepcopy(BASE_CASES)
for case in lead_fast_path_external_action["cases"]:
    if case["id"] == "low-risk-single-file-lead-fast-path":
        case["expected"]["scope"]["external_actions"] = ["git push origin main"]
require_failure(run(lead_fast_path_external_action), "lead fast path with an external action")

lead_fast_path_without_lead_writer = copy.deepcopy(BASE_CASES)
for case in lead_fast_path_without_lead_writer["cases"]:
    if case["id"] == "low-risk-single-file-lead-fast-path":
        case["expected"]["write_authority"]["lead"] = False
require_failure(run(lead_fast_path_without_lead_writer), "lead fast path without explicit lead writer")

unsafe_paths = (
    "../src/**",
    "/Users/**",
    "~/src/**",
    "C:/src/**",
    "C:../secrets/**",
    "src/../secrets/**",
    "$HOME/**",
    "$(pwd)/**",
    "!(src)/**",
    "src/`pwd`/**",
    "src/foo|bar/**",
    "agent-team/.?/**",
    "agent-team/.*/**",
)

for unsafe_path in unsafe_paths:
    escaped_write_path = copy.deepcopy(BASE_CASES)
    for case in escaped_write_path["cases"]:
        if case["id"] == "clear-code-fix-kane-only":
            case["expected"]["write_authority"]["write_paths"] = [unsafe_path]
    require_failure(run(escaped_write_path), f"unsafe write path {unsafe_path}")

for unsafe_path in ("**", *unsafe_paths):
    escaped_read_path = copy.deepcopy(BASE_CASES)
    for case in escaped_read_path["cases"]:
        if case["id"] == "read-path-escape-needs-handoff":
            case["expected"]["scope"]["read_paths"] = [unsafe_path]
    require_failure(run(escaped_read_path), f"unsafe read path {unsafe_path}")

for unsafe_path in ("C:../secrets/**", "agent-team/.?/**", "agent-team/.*/**"):
    unsafe_scope_write_path = copy.deepcopy(BASE_CASES)
    for case in unsafe_scope_write_path["cases"]:
        if case["id"] == "write-path-escape-needs-handoff":
            case["expected"]["write_authority"]["write_paths"] = [unsafe_path]
            case["expected"]["scope"]["write_paths"] = [unsafe_path]
    require_failure(run(unsafe_scope_write_path), f"unsafe path in authority and scope: {unsafe_path}")

for security_case_id in ("read-path-escape-needs-handoff", "write-path-escape-needs-handoff"):
    missing_security_scope = copy.deepcopy(BASE_CASES)
    for case in missing_security_scope["cases"]:
        if case["id"] == security_case_id:
            del case["expected"]["scope"]
    require_failure(run(missing_security_scope), f"{security_case_id} without scope")

actual = {"results": {case["id"]: case["expected"] for case in BASE_CASES["cases"]}}
require_success(run(BASE_CASES, actual), "matching machine-readable results")
actual["results"].pop(next(iter(actual["results"])))
require_failure(run(BASE_CASES, actual), "incomplete machine-readable results")

require_success(run_behavior(BASE_REPLAY_CASES, BASE_REPLAY_RESULTS), "valid behavior replay results")

over_dispatched_replay = copy.deepcopy(BASE_REPLAY_RESULTS)
over_dispatched_replay["results"]["replay-readme-quickstart-doc"]["review"]["over_dispatched"] = True
require_failure(run_behavior(BASE_REPLAY_CASES, over_dispatched_replay), "behavior replay with over-dispatch")

missing_replay_result = copy.deepcopy(BASE_REPLAY_RESULTS)
missing_replay_result["results"].pop("replay-cache-ttl-fix")
require_failure(run_behavior(BASE_REPLAY_CASES, missing_replay_result), "behavior replay with a missing result")

fake_success_replay = copy.deepcopy(BASE_REPLAY_RESULTS)
fake_success_replay["results"]["replay-production-deploy-missing-creds"]["final_status"] = "done"
require_failure(run_behavior(BASE_REPLAY_CASES, fake_success_replay), "behavior replay that turns a blocker into success")

print("Eval runner regression tests passed.")
