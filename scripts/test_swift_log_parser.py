#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from rig_tools.swift_log_parser import load_known_blockers, parse_swift_log_text

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "rig.py"
KNOWN_BLOCKERS = REPO_ROOT / "Docs" / "build" / "known-blockers.yaml"
FIXTURE_DIR = REPO_ROOT / "scripts" / "fixtures" / "swift_logs"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def main() -> int:
    blockers = load_known_blockers(KNOWN_BLOCKERS)

    compile_text = (FIXTURE_DIR / "compile_diagnostics.log").read_text(encoding="utf-8")
    compile_diags = parse_swift_log_text(
        compile_text,
        command="swift build --target AnigmaDaemonCore",
        target="AnigmaDaemonCore",
        known_blockers=blockers,
    )
    categories = {diag["category"] for diag in compile_diags}
    assert "ambiguous_init" in categories, categories
    assert "missing_type" in categories, categories
    assert "concurrency_sendable" in categories, categories
    assert "mainactor_misuse" in categories, categories
    assert "actor_isolation" in categories, categories
    assert "access_control" in categories, categories
    assert "package_manifest" in categories, categories
    assert any(diag.get("known_blocker_id") == "build-anigmacore-runtimecore-001" for diag in compile_diags), compile_diags
    assert all(diag.get("target") == "AnigmaDaemonCore" for diag in compile_diags), compile_diags

    linker_text = (FIXTURE_DIR / "linker_and_test_failure.log").read_text(encoding="utf-8")
    linker_diags = parse_swift_log_text(
        linker_text,
        command="swift test --filter ExampleTests",
        target="AnigmaDaemonCore",
        known_blockers=blockers,
    )
    linker_categories = {diag["category"] for diag in linker_diags}
    assert "linker_error" in linker_categories, linker_categories
    assert "native_dependency_missing" in linker_categories, linker_categories
    assert "test_failure" in linker_categories, linker_categories

    result = run("swift", "diagnose-log", "--log", str(FIXTURE_DIR / "compile_diagnostics.log"))
    assert result.returncode == 0, result.stderr
    assert ".build/rig/swift-diagnostics/latest.json" in result.stdout, result.stdout

    latest_json = REPO_ROOT / ".build" / "rig" / "swift-diagnostics" / "latest.json"
    latest_md = REPO_ROOT / ".build" / "rig" / "swift-diagnostics" / "latest.md"
    assert latest_json.exists(), latest_json
    assert latest_md.exists(), latest_md

    payload = json.loads(latest_json.read_text(encoding="utf-8"))
    assert payload["tool"] == "rig-swift-diagnostics"
    assert payload["summary"]["total"] >= 1
    assert payload["diagnostics"], payload
    assert payload["diagnostics"][0]["message"], payload

    assert (REPO_ROOT / ".build" / "rig" / "swift-diagnostics" / "latest.input.log").exists()
    assert (REPO_ROOT / ".build" / "rig" / "swift-diagnostics" / "latest.stdout.log").exists()
    assert (REPO_ROOT / ".build" / "rig" / "swift-diagnostics" / "latest.stderr.log").exists()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
