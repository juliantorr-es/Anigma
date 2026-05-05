#!/usr/bin/env python3
"""
Authority Class: Class 2 Gate Validator
Mutation Behavior: Non-mutating
Canonical Inputs: Docs/governance/validator-registry.yaml, repository Scripts/ tree
Generated Outputs: stdout report, optional JSON summary, optional JSON result
Baseline Behavior: Read-only; does not write baselines or registry files
CI/Review Usage: validate and review phases as a standalone registry gate
Failure Semantics: exit 1 on governed violation, exit 2 on invalid invocation,
  exit 3 on environment/tooling error, exit 4 on schema/baseline incompatibility,
  exit 5 on unsafe mutation refusal
Owner Doctrine: Validator Constitution and script-governance enforcement
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple

try:
    import yaml
except ImportError:  # pragma: no cover - environment dependent
    yaml = None


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_REGISTRY = REPO_ROOT / "Docs" / "governance" / "validator-registry.yaml"

ALLOWED_AUTHORITIES = {
    "utility_script",
    "advisory_analyzer",
    "gate_validator",
    "baseline_manager",
    "renderer_generator",
    "state_synchronizer",
    "mutator_migration_script",
    "diagnostic_aggregator",
}

PASSIVE_PHASES = {"validate", "review", "check", "local", "local_advisory"}
MUTATING_AUTHORITIES = {
    "baseline_manager",
    "state_synchronizer",
    "mutator_migration_script",
}
EXPLICIT_MUTATION_FLAGS = {
    "--update-baseline",
    "--write-baseline",
    "--apply",
    "--write",
    "--mutate",
    "--repair",
}


@dataclass(frozen=True)
class Finding:
    path: str
    field: str
    message: str
    severity: str


@dataclass(frozen=True)
class ValidationSummary:
    status: str
    registry_path: str
    total_entries: int
    violations: List[Finding]
    warnings: List[Finding]


def _repo_relative(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def _load_yaml(path: Path) -> Dict[str, Any]:
    if yaml is None:
        raise RuntimeError("PyYAML is not installed")
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise ValueError("Registry root must be a mapping")
    return data


def _append(result: List[Finding], path: str, field: str, message: str, severity: str) -> None:
    result.append(Finding(path=path, field=field, message=message, severity=severity))


def _validate_common_shape(entry: Dict[str, Any], entry_path: str) -> Tuple[List[Finding], List[Finding]]:
    violations: List[Finding] = []
    warnings: List[Finding] = []

    required = {
        "path",
        "authority_class",
        "mutates",
        "phases",
        "canonical_inputs",
        "generated_outputs",
        "baseline_behavior",
        "dangerous_modes",
        "proof_required_for_changes",
        "notes",
    }

    missing = required - set(entry)
    if missing:
        _append(
            violations,
            entry_path,
            "entry",
            f"missing required fields: {', '.join(sorted(missing))}",
            "error",
        )
        return violations, warnings

    path_value = entry.get("path")
    if not isinstance(path_value, str) or not path_value.strip():
        _append(violations, entry_path, "path", "path must be a non-empty string", "error")

    authority = entry.get("authority_class")
    if authority not in ALLOWED_AUTHORITIES:
        _append(
            violations,
            entry_path,
            "authority_class",
            f"authority_class must be one of {', '.join(sorted(ALLOWED_AUTHORITIES))}",
            "error",
        )

    if not isinstance(entry.get("mutates"), bool):
        _append(violations, entry_path, "mutates", "mutates must be a boolean", "error")

    for field in ("phases", "canonical_inputs", "generated_outputs", "dangerous_modes"):
        if not isinstance(entry.get(field), list):
            _append(violations, entry_path, field, f"{field} must be a list", "error")

    if not isinstance(entry.get("proof_required_for_changes"), bool):
        _append(
            violations,
            entry_path,
            "proof_required_for_changes",
            "proof_required_for_changes must be a boolean",
            "error",
        )

    return violations, warnings


def _has_explicit_mutation_flag(dangerous_modes: Sequence[Any]) -> bool:
    return any(isinstance(mode, str) and mode in EXPLICIT_MUTATION_FLAGS for mode in dangerous_modes)


def _notes_indicate_dry_run(notes: Any, phases: Sequence[Any]) -> bool:
    notes_text = str(notes or "").lower()
    if "dry-run" in notes_text or "dry run" in notes_text or "check" in notes_text:
        return True
    return any(isinstance(phase, str) and phase.lower() in {"dry-run", "check"} for phase in phases)


def validate_registry(data: Dict[str, Any], registry_path: Path, strict: bool = False) -> ValidationSummary:
    violations: List[Finding] = []
    warnings: List[Finding] = []

    entry_path = _repo_relative(registry_path)
    if data.get("version") != 1:
        _append(violations, entry_path, "version", "version must be 1", "error")
    if data.get("status") != "descriptive_only":
        _append(violations, entry_path, "status", "status must be descriptive_only", "error")
    if data.get("enforcement") != "none":
        _append(violations, entry_path, "enforcement", "enforcement must be none", "error")

    validators = data.get("validators")
    if not isinstance(validators, list) or not validators:
        _append(violations, entry_path, "validators", "validators must be a non-empty list", "error")
        return ValidationSummary(
            status="fail",
            registry_path=_repo_relative(registry_path),
            total_entries=0,
            violations=violations,
            warnings=warnings,
        )

    seen_paths: Set[str] = set()
    for index, entry in enumerate(validators):
        item_path = f"{_repo_relative(registry_path)}[{index}]"
        if not isinstance(entry, dict):
            _append(violations, item_path, "entry", "each validator entry must be a mapping", "error")
            continue

        entry_violations, entry_warnings = _validate_common_shape(entry, item_path)
        violations.extend(entry_violations)
        warnings.extend(entry_warnings)

        path_value = entry.get("path")
        if isinstance(path_value, str) and path_value.strip():
            if path_value in seen_paths:
                _append(violations, item_path, "path", f"duplicate registry path: {path_value}", "error")
            seen_paths.add(path_value)

            resolved = (REPO_ROOT / path_value).resolve()
            if not resolved.exists():
                _append(violations, item_path, "path", f"registered path does not exist: {path_value}", "error")

        authority = entry.get("authority_class")
        phases = entry.get("phases") if isinstance(entry.get("phases"), list) else []
        dangerous_modes = entry.get("dangerous_modes") if isinstance(entry.get("dangerous_modes"), list) else []
        mutates = entry.get("mutates")
        baseline_behavior = str(entry.get("baseline_behavior") or "")
        notes = entry.get("notes")
        generated_outputs = entry.get("generated_outputs") if isinstance(entry.get("generated_outputs"), list) else []

        passive_overlap = sorted(set(str(phase).lower() for phase in phases) & PASSIVE_PHASES)
        if authority == "baseline_manager" and passive_overlap:
            _append(
                violations,
                item_path,
                "phases",
                f"baseline_manager must not appear in passive phases: {', '.join(passive_overlap)}",
                "error",
            )

        if authority == "mutator_migration_script" and passive_overlap:
            _append(
                violations,
                item_path,
                "phases",
                f"mutator_migration_script must not appear in passive phases: {', '.join(passive_overlap)}",
                "error",
            )

        if authority == "state_synchronizer" and passive_overlap:
            if "review" in passive_overlap and not _notes_indicate_dry_run(notes, phases):
                _append(
                    violations,
                    item_path,
                    "phases",
                    "state_synchronizer may appear in review only if notes or phases clearly indicate dry-run/check behavior",
                    "error",
                )
            forbidden = sorted(p for p in passive_overlap if p != "review")
            if forbidden:
                _append(
                    violations,
                    item_path,
                    "phases",
                    f"state_synchronizer must not appear in passive phases: {', '.join(forbidden)}",
                    "error",
                )

        if mutates is True and passive_overlap:
            if not (authority == "renderer_generator" and generated_outputs):
                _append(
                    violations,
                    item_path,
                    "mutates",
                    "mutating entries must not appear in passive phases unless they are renderer_generator entries with generated outputs",
                    "error",
                )

        if baseline_behavior and ("write" in baseline_behavior.lower() or "mutate" in baseline_behavior.lower()):
            if not _has_explicit_mutation_flag(dangerous_modes):
                _append(
                    violations,
                    item_path,
                    "dangerous_modes",
                    "baseline-writing behavior requires an explicit dangerous mode such as --update-baseline, --write-baseline, --apply, --write, --mutate, or --repair",
                    "error",
                )

        if dangerous_modes and not any(
            isinstance(mode, str) and mode in EXPLICIT_MUTATION_FLAGS for mode in dangerous_modes
        ):
            warnings.append(
                Finding(
                    path=item_path,
                    field="dangerous_modes",
                    message="dangerous_modes should describe explicit mutation flags and not rely on hidden default behavior",
                    severity="warning",
                )
            )

    status = "pass" if not violations else "fail"
    if strict:
        warnings.extend(_warn_unregistered_scripts())
    return ValidationSummary(
        status=status,
        registry_path=_repo_relative(registry_path),
        total_entries=len(validators),
        violations=violations,
        warnings=warnings,
    )


def _warn_unregistered_scripts() -> List[Finding]:
    warnings: List[Finding] = []
    scripts_dir = REPO_ROOT / "Scripts"
    if not scripts_dir.exists():
        return warnings

    registered = set()
    try:
        data = _load_yaml(DEFAULT_REGISTRY)
        for entry in data.get("validators", []):
            if isinstance(entry, dict) and isinstance(entry.get("path"), str):
                registered.add(entry["path"])
    except Exception:
        return warnings

    for path in sorted(scripts_dir.glob("*.py")):
        rel = _repo_relative(path)
        if rel not in registered:
            warnings.append(
                Finding(
                    path=rel,
                    field="registry",
                    message="script is not registered in validator-registry.yaml",
                    severity="warning",
                )
            )
    return warnings


def _write_json_result(summary: ValidationSummary) -> Dict[str, Any]:
    return {
        "schema_version": "validator.registry.check.v1",
        "status": summary.status,
        "registry_path": summary.registry_path,
        "total_entries": summary.total_entries,
        "violation_count": len(summary.violations),
        "warning_count": len(summary.warnings),
        "violations": [asdict(v) for v in summary.violations],
        "warnings": [asdict(w) for w in summary.warnings],
    }


def _print_human(summary: ValidationSummary) -> None:
    print(f"registry: {summary.registry_path}")
    print(f"total entries: {summary.total_entries}")
    print(f"violations: {len(summary.violations)}")
    print(f"warnings: {len(summary.warnings)}")
    print(f"final status: {summary.status}")
    if summary.violations:
        print()
        print("Violations:")
        for item in summary.violations:
            print(f"- path={item.path} field={item.field} message={item.message}")
    if summary.warnings:
        print()
        print("Warnings:")
        for item in summary.warnings:
            print(f"- path={item.path} field={item.field} message={item.message}")


def _print_json(summary: ValidationSummary) -> None:
    print(json.dumps(_write_json_result(summary), indent=2, sort_keys=True))


def _parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate the Anigma validator registry.")
    parser.add_argument(
        "--registry",
        default=str(DEFAULT_REGISTRY),
        help="Path to validator-registry.yaml",
    )
    parser.add_argument("--check", action="store_true", help="Run in explicit check mode")
    parser.add_argument("--json", action="store_true", help="Emit JSON only")
    parser.add_argument(
        "--format",
        choices=("human", "json"),
        default="human",
        help="Output format",
    )
    parser.add_argument("--strict", action="store_true", help="Add warnings for unregistered Scripts/*.py files")
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parse_args(argv)
    registry_path = Path(args.registry)

    if not registry_path.exists():
        print(f"registry not found: {registry_path}", file=sys.stderr)
        return 2

    if yaml is None:
        print("PyYAML is required for validator-registry validation", file=sys.stderr)
        return 3

    try:
        data = _load_yaml(registry_path)
    except Exception as exc:
        print(f"failed to load registry: {exc}", file=sys.stderr)
        return 2

    summary = validate_registry(data, registry_path, strict=args.strict)

    if args.json or args.format == "json":
        _print_json(summary)
    else:
        if args.check:
            print("check mode: non-mutating")
        _print_human(summary)

    if summary.violations:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
