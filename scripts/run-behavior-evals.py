#!/usr/bin/env python3
"""Validate realistic Agent Team behavior replay results."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROLES = {"Atlas", "Mira", "Kane", "Vera", "Reed", "Lina", "Orin"}
DISPATCH_MODES = {"none", "single", "sequential", "parallel"}
WRITE_MODES = {"read_only", "scoped_write"}
FINAL_STATUSES = {"done", "blocked", "needs_handoff"}
HONEST_BLOCKING = {"passed", "failed", "not_applicable"}
REQUIRED_TAGS = {
    "blocked",
    "docs",
    "implementation",
    "parallel",
    "planning",
    "qa",
    "review",
    "scope",
    "security",
    "troubleshooting",
    "ui",
}


def add_error(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc


def is_string_list(value: Any, *, allow_empty: bool = True) -> bool:
    return (
        isinstance(value, list)
        and (allow_empty or bool(value))
        and all(isinstance(item, str) and item for item in value)
    )


def step_role(step: str) -> str:
    return step.split(":", 1)[0]


def compare_subset(expected: Any, actual: Any, path: str, errors: list[str]) -> None:
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            errors.append(f"{path}: expected object, got {type(actual).__name__}")
            return
        for key, value in expected.items():
            if key not in actual:
                errors.append(f"{path}.{key}: missing from actual result")
            else:
                compare_subset(value, actual[key], f"{path}.{key}", errors)
    elif expected != actual:
        errors.append(f"{path}: expected {expected!r}, got {actual!r}")


def validate_dispatch(case_id: str, expected: dict[str, Any], errors: list[str]) -> set[str]:
    dispatch = expected.get("dispatch")
    role_set: set[str] = set()
    if not isinstance(dispatch, dict):
        errors.append(f"{case_id}.dispatch must be an object")
        return role_set

    mode = dispatch.get("mode")
    roles = dispatch.get("roles")
    order = dispatch.get("order")
    groups = dispatch.get("concurrent_groups")
    roles_valid = is_string_list(roles)
    role_set = set(roles) if roles_valid else set()

    add_error(errors, mode in DISPATCH_MODES, f"{case_id}.dispatch.mode is invalid")
    add_error(errors, roles_valid, f"{case_id}.dispatch.roles must be a list of strings")
    if roles_valid:
        add_error(errors, len(roles) == len(role_set), f"{case_id}.dispatch.roles contains duplicates")
        add_error(errors, role_set <= ROLES, f"{case_id}.dispatch.roles contains an unknown role")
        if mode == "none":
            add_error(errors, not roles, f"{case_id}.dispatch none must have no roles")
        if mode == "single":
            add_error(errors, len(roles) == 1, f"{case_id}.dispatch single must have one role")

    order_valid = is_string_list(order)
    ordered_roles = [step_role(step) for step in order] if order_valid else []
    add_error(errors, order_valid, f"{case_id}.dispatch.order must be a list of strings")
    if order_valid:
        add_error(errors, all(role in role_set for role in ordered_roles), f"{case_id}.dispatch.order names an undispatched role")

    groups_valid = isinstance(groups, list) and all(is_string_list(group, allow_empty=False) for group in groups)
    grouped_role_list = [role for group in groups for role in group] if groups_valid else []
    grouped_roles = set(grouped_role_list)
    add_error(errors, groups_valid, f"{case_id}.dispatch.concurrent_groups must contain nonempty string lists")

    if mode in {"none", "single"}:
        add_error(errors, not groups, f"{case_id}.dispatch {mode} must not have concurrent groups")
    if mode == "single":
        add_error(errors, set(ordered_roles) == role_set, f"{case_id}.dispatch single order must cover its role")
    if mode == "sequential":
        add_error(errors, bool(order), f"{case_id}.dispatch sequential must define order")
        add_error(errors, not groups, f"{case_id}.dispatch sequential must not have concurrent groups")
        add_error(errors, set(ordered_roles) == role_set, f"{case_id}.dispatch sequential order must cover every role")
    if mode == "parallel":
        add_error(errors, expected.get("execution_mode") == "real_multi_agent", f"{case_id}.parallel dispatch requires real_multi_agent")
        add_error(errors, not order, f"{case_id}.dispatch parallel must not define sequential order")
        add_error(errors, grouped_roles == role_set, f"{case_id}.dispatch parallel groups must cover every role")
        add_error(errors, len(grouped_role_list) == len(grouped_roles), f"{case_id}.dispatch parallel groups contain duplicate roles")

    return role_set


def validate_expected(case_id: str, expected: dict[str, Any], errors: list[str]) -> None:
    add_error(errors, isinstance(expected.get("agent_team_trigger"), bool), f"{case_id}.agent_team_trigger must be boolean")
    add_error(errors, isinstance(expected.get("outcome"), str) and bool(expected.get("outcome")), f"{case_id}.outcome must be a string")
    add_error(errors, expected.get("final_status") in FINAL_STATUSES, f"{case_id}.final_status is invalid")

    lead_execution = expected.get("lead_execution", False)
    add_error(errors, isinstance(lead_execution, bool), f"{case_id}.lead_execution must be boolean")

    role_set = validate_dispatch(case_id, expected, errors)
    dispatch = expected.get("dispatch")
    dispatch_mode = dispatch.get("mode") if isinstance(dispatch, dict) else None
    authority = expected.get("write_authority")
    if not isinstance(authority, dict):
        errors.append(f"{case_id}.write_authority must be an object")
    else:
        mode = authority.get("mode")
        roles = authority.get("roles")
        lead_writer = authority.get("lead", False)
        add_error(errors, mode in WRITE_MODES, f"{case_id}.write_authority.mode is invalid")
        add_error(errors, is_string_list(roles), f"{case_id}.write_authority.roles must be a list")
        add_error(errors, isinstance(lead_writer, bool), f"{case_id}.write_authority.lead must be boolean")
        if is_string_list(roles):
            writer_set = set(roles)
            add_error(errors, writer_set <= role_set, f"{case_id}.writer role was not dispatched")
            if mode == "read_only":
                add_error(errors, not roles, f"{case_id}.read_only must not name writer roles")
                add_error(errors, not lead_writer, f"{case_id}.read_only cannot name the lead as writer")
                add_error(errors, authority.get("write_paths") in (None, []), f"{case_id}.read_only must not define write paths")
            if mode == "scoped_write":
                if lead_execution:
                    add_error(errors, not roles, f"{case_id}.lead fast path must not name a specialist writer")
                    add_error(errors, lead_writer is True, f"{case_id}.lead fast path must name the lead as writer")
                    add_error(errors, dispatch_mode == "none", f"{case_id}.lead fast path must not dispatch specialists")
                else:
                    add_error(errors, bool(roles), f"{case_id}.scoped_write must name a writer role")
                    add_error(errors, not lead_writer, f"{case_id}.specialist write cannot also name the lead")
                add_error(errors, is_string_list(authority.get("write_paths"), allow_empty=False), f"{case_id}.scoped_write must define write_paths")
                if lead_execution and is_string_list(authority.get("write_paths"), allow_empty=False):
                    add_error(errors, len(authority["write_paths"]) == 1, f"{case_id}.lead fast path must write exactly one file")

    if lead_execution:
        add_error(errors, expected.get("external_actions") == [], f"{case_id}.lead fast path must declare no external actions")

    review = expected.get("review")
    if not isinstance(review, dict):
        errors.append(f"{case_id}.review must be an object")
    else:
        add_error(errors, review.get("dispatch_correct") is True, f"{case_id}.review.dispatch_correct must be true")
        add_error(errors, review.get("over_dispatched") is False, f"{case_id}.review.over_dispatched must be false")
        add_error(errors, review.get("truthful_completion") is True, f"{case_id}.review.truthful_completion must be true")
        add_error(errors, review.get("honest_blocking") in HONEST_BLOCKING, f"{case_id}.review.honest_blocking is invalid")
        if expected.get("final_status") in {"blocked", "needs_handoff"}:
            add_error(errors, review.get("honest_blocking") == "passed", f"{case_id}.blocked replay must record honest_blocking: passed")


def validate_cases(path: Path) -> tuple[dict[str, dict[str, Any]], list[str]]:
    errors: list[str] = []
    data = load_json(path)
    add_error(errors, isinstance(data, dict), "behavior case root must be an object")
    if not isinstance(data, dict):
        return {}, errors

    add_error(errors, data.get("schema_version") == 1, "behavior cases schema_version must be 1")
    cases = data.get("cases")
    add_error(errors, isinstance(cases, list), "behavior cases must be a list")
    if not isinstance(cases, list):
        return {}, errors
    add_error(errors, 10 <= len(cases) <= 20, "behavior replay must contain 10-20 cases")

    by_id: dict[str, dict[str, Any]] = {}
    tags_seen: set[str] = set()
    for index, case in enumerate(cases):
        prefix = f"cases[{index}]"
        if not isinstance(case, dict):
            errors.append(f"{prefix} must be an object")
            continue
        case_id = case.get("id")
        if not isinstance(case_id, str) or not case_id:
            errors.append(f"{prefix}.id must be a nonempty string")
            continue
        add_error(errors, case_id not in by_id, f"duplicate behavior case id: {case_id}")
        by_id[case_id] = case

        add_error(errors, isinstance(case.get("prompt"), str) and bool(case.get("prompt")), f"{case_id}.prompt must be a string")
        add_error(errors, is_string_list(case.get("acceptance"), allow_empty=False), f"{case_id}.acceptance must be a nonempty string list")
        tags = case.get("tags")
        add_error(errors, is_string_list(tags, allow_empty=False), f"{case_id}.tags must be a nonempty string list")
        if is_string_list(tags, allow_empty=False):
            tags_seen.update(tags)
        expected = case.get("expected")
        if not isinstance(expected, dict):
            errors.append(f"{case_id}.expected must be an object")
            continue
        validate_expected(case_id, expected, errors)

    missing_tags = REQUIRED_TAGS - tags_seen
    add_error(errors, not missing_tags, f"behavior replay missing required tags: {sorted(missing_tags)}")
    return by_id, errors


def normalize_results(data: Any) -> dict[str, Any]:
    results = data.get("results") if isinstance(data, dict) else None
    if isinstance(results, dict):
        return results
    if isinstance(results, list):
        normalized: dict[str, Any] = {}
        for item in results:
            if isinstance(item, dict) and isinstance(item.get("id"), str):
                normalized[item["id"]] = item.get("actual", item.get("result"))
        return normalized
    return {}


def compare_actual(path: Path, cases: dict[str, dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    data = load_json(path)
    add_error(errors, isinstance(data, dict), "actual replay root must be an object")
    if not isinstance(data, dict):
        return errors
    add_error(errors, data.get("schema_version") == 1, "actual replay schema_version must be 1")

    actual_by_id = normalize_results(data)
    add_error(errors, bool(actual_by_id), "actual replay must contain results")
    for case_id, case in cases.items():
        actual = actual_by_id.get(case_id)
        if actual is None:
            errors.append(f"actual replay missing case: {case_id}")
            continue
        compare_subset(case["expected"], actual, case_id, errors)
    unknown = set(actual_by_id) - set(cases)
    add_error(errors, not unknown, f"actual replay contains unknown cases: {sorted(unknown)}")
    return errors


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", type=Path, default=repo / "evals/replay-cases.json")
    parser.add_argument("--actual", type=Path, default=repo / "evals/replay-results.json")
    args = parser.parse_args()

    try:
        cases, errors = validate_cases(args.cases)
        errors.extend(compare_actual(args.actual, cases))
    except ValueError as exc:
        errors = [str(exc)]
        cases = {}

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    blockers = sum(1 for case in cases.values() if case["expected"]["final_status"] in {"blocked", "needs_handoff"})
    print(
        f"Validated {len(cases)} behavior replay cases against {args.actual}; "
        f"{blockers} cases intentionally stop with honest blocked/needs_handoff status. "
        "This script validates recorded behavior JSON; it does not execute agents."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
