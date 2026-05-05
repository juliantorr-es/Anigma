#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def git_changed_files() -> list[str]:
    res = subprocess.run(
        ["git", "diff", "--name-only"],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if res.returncode != 0:
        return []
    return [line.strip() for line in res.stdout.splitlines() if line.strip()]


def validate_scope(changed_files: list[str], allowed: list[str], forbidden: list[str]) -> tuple[bool, list[str]]:
    violations: list[str] = []
    if not changed_files:
        return True, violations
    allowed = [a.rstrip("/") for a in allowed]
    forbidden = [f.rstrip("/") for f in forbidden]
    for file_path in changed_files:
        if any(file_path == f or file_path.startswith(f + "/") for f in forbidden):
            violations.append(f"forbidden:{file_path}")
            continue
        if allowed and not any(file_path == a or file_path.startswith(a + "/") for a in allowed):
            violations.append(f"out_of_scope:{file_path}")
    return not violations, violations


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", required=True)
    ap.add_argument("--allowed-path", action="append", default=[])
    ap.add_argument("--forbidden-path", action="append", default=[])
    ap.add_argument("--allow-empty", action="store_true")
    ap.add_argument("--changed-file", action="append", default=[], help="Inject changed files for testing")
    args = ap.parse_args()

    changed = args.changed_file or git_changed_files()
    if not changed and args.allow_empty:
        return 0
    ok, violations = validate_scope(changed, args.allowed_path, args.forbidden_path)
    if not ok:
        for v in violations:
            print(v, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
