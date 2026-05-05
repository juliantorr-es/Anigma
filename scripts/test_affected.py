#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from rig_tools.affected import _affected_risks_for_targets_and_files, _infer_targets_from_paths, _recommend_profiles, _repo_map_direct_targets, compute, write_outputs

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "rig.py"
OUT_DIR = REPO_ROOT / ".build" / "rig" / "affected"


def run(*args: str, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=REPO_ROOT, text=True, input=input_text, capture_output=True, check=False)


def main() -> int:
    shutil.rmtree(OUT_DIR, ignore_errors=True)

    stdin_result = compute(
        REPO_ROOT,
        mode="files",
        stdin_files=[
            "scripts/rig.py",
            "anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift",
            "anigma/Package.swift",
            ".build/cache/ignored.txt",
        ],
        task="td-cleanup-005",
        command=["rig", "affected", "files", "--stdin"],
    )
    assert "scripts/rig.py" in stdin_result.changed_files
    assert "anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift" in stdin_result.changed_files
    assert "anigma/Package.swift" in stdin_result.changed_files
    assert ".build/cache/ignored.txt" not in stdin_result.changed_files
    assert "AnigmaDaemonCore" in stdin_result.directly_affected_targets
    assert "local-fast" in stdin_result.recommended_profiles
    assert "cleanup-review" in stdin_result.recommended_profiles
    assert any("swift build" in cmd for cmd in stdin_result.recommended_validation_commands), stdin_result.recommended_validation_commands

    repo_map = [{"path": "foo/bar.swift", "target": "RepoMapTarget"}]
    assert _repo_map_direct_targets(["foo/bar.swift"], repo_map) == ["RepoMapTarget"]

    inferred_targets, unknown = _infer_targets_from_paths(
        [
            "anigma/Sources/AnigmaDaemonCore/Services/HTTPServer.swift",
            "anigma/Tests/AnigmaDaemonCore/HTTPServerTests.swift",
            "scripts/rig.py",
        ],
        json.loads((REPO_ROOT / "Docs" / "atlas" / "targets.json").read_text(encoding="utf-8")),
    )
    assert "AnigmaDaemonCore" in inferred_targets, inferred_targets
    assert "scripts/rig.py" in unknown, unknown

    profiles = _recommend_profiles(
        ["scripts/rig.py"],
        [],
        [],
        ["local-fast", "cleanup-review", "daemon-runtime", "backend-regularization"],
    )
    assert profiles == ["local-fast"], profiles

    profiles = _recommend_profiles(
        ["anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift"],
        ["AnigmaDaemonCore"],
        [],
        ["local-fast", "cleanup-review", "daemon-runtime", "backend-regularization"],
    )
    assert profiles[:2] == ["daemon-runtime", "cleanup-review"], profiles

    profiles = _recommend_profiles(
        ["anigma/Package.swift"],
        [],
        [],
        ["local-fast", "cleanup-review", "daemon-runtime", "backend-regularization"],
    )
    assert "backend-regularization" in profiles, profiles

    risk_index = [
        {"path": "scripts/rig.py", "category": "tooling", "severity": "low", "confidence": "high", "target": "Rig"},
        {"path": "anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift", "category": "daemon_ipc_binding", "severity": "high", "confidence": "medium", "target": "AnigmaDaemonCore"},
    ]
    risks = _affected_risks_for_targets_and_files(risk_index, ["scripts/rig.py"], ["Rig"])
    assert len(risks) == 1 and risks[0]["path"] == "scripts/rig.py", risks

    out_paths = write_outputs(REPO_ROOT, stdin_result, task="td-cleanup-005")
    assert out_paths["files_json"].exists()
    assert out_paths["targets_json"].exists()
    assert out_paths["risks_json"].exists()
    assert out_paths["profiles_json"].exists()
    assert out_paths["summary_md"].exists()

    cli_files = run("affected", "files", "--stdin", input_text="scripts/rig.py\nanigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift\n")
    assert cli_files.returncode == 0, cli_files.stderr
    files_json = REPO_ROOT / cli_files.stdout.strip().splitlines()[0]
    payload = json.loads(files_json.read_text(encoding="utf-8"))
    assert "scripts/rig.py" in payload["changed_files"]
    assert "AnigmaDaemonCore" in payload["changed_files"] or payload["unknown_files"], payload

    cli_targets = run("affected", "targets", "--base", "HEAD", "--head", "HEAD")
    assert cli_targets.returncode == 0, cli_targets.stderr
    targets_json = REPO_ROOT / cli_targets.stdout.strip().splitlines()[0]
    assert targets_json.exists(), targets_json

    cli_summary = run("affected", "summary", "--task", "td-cleanup-005")
    assert cli_summary.returncode == 0, cli_summary.stderr
    summary_md = REPO_ROOT / cli_summary.stdout.strip().splitlines()[0]
    assert summary_md.exists(), summary_md

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
