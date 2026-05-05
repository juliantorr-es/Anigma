from __future__ import annotations

import csv
import json
import tempfile
from pathlib import Path

from rig_tools.result_index import build_context_pack, build_indexes, write_indexes


def _write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _sample_repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="rig-index-test-"))
    _write(
        repo / ".build" / "rig" / "results" / "latest.json",
        {
            "schema_version": "rig.result.v1",
            "run_id": "run-1",
            "command_group": "pipeline",
            "command": "rig pipeline run --profile local-fast --task demo",
            "task": "demo",
            "status": "passed",
            "exit_code": 0,
            "started_at": "2026-05-05T10:00:00Z",
            "finished_at": "2026-05-05T10:00:01Z",
            "duration_seconds": 1.0,
            "artifacts": [{"path": ".build/x", "type": "manifest"}],
            "warnings": ["w1"],
            "errors": [],
            "summary": {"stdout_lines": 1},
            "next_actions": [],
        },
    )
    _write(
        repo / ".build" / "anigma-pipeline" / "runs" / "demo" / "run-1" / "manifest.json",
        {
            "task": "demo",
            "run_id": "run-1",
        },
    )
    _write(
        repo / ".build" / "anigma-pipeline" / "runs" / "demo" / "run-1" / "step-results" / "step-1.json",
        {
            "run_id": "run-1",
            "task_id": "demo",
            "profile": "local-fast",
            "step_id": "step-1",
            "command": "echo hi",
            "status": "passed",
            "exit_code": 0,
            "duration_seconds": 0.25,
            "matched_known_blocker": None,
            "stdout_log": ".build/anigma-pipeline/runs/demo/run-1/logs/step-1.stdout.log",
            "stderr_log": ".build/anigma-pipeline/runs/demo/run-1/logs/step-1.stderr.log",
        },
    )
    _write(
        repo / ".build" / "rig" / "swift-diagnostics" / "latest.json",
        {
            "command": ["swift", "build", "--target", "AnigmaDaemonCore"],
            "target": "AnigmaDaemonCore",
            "exit_code": 1,
            "status": "failed",
            "diagnostics": [
                {"severity": "error", "category": "missing_type", "file": "Foo.swift", "line": 1, "column": 2, "message": "cannot find type", "known_blocker_id": "b1"},
                {"severity": "warning", "category": "concurrency_sendable", "file": "Bar.swift", "line": 2, "column": 3, "message": "sendable warning"},
            ],
        },
    )
    _write(
        repo / ".build" / "rig" / "affected" / "profiles.json",
        {
            "task": "demo",
            "mode": "stdin",
            "recommended_profiles": ["local-fast", "cleanup-review"],
            "recommended_validation_commands": ["python3 scripts/test_rig_cli.py"],
            "target_notes": [],
        },
    )
    _write(
        repo / ".build" / "rig" / "affected" / "summary.json",
        {
            "task": "demo",
            "mode": "stdin",
            "changed_file_count": 2,
            "directly_affected_targets": ["AnigmaDaemonCore"],
            "affected_risk_count": 3,
            "recommended_profiles": ["local-fast", "cleanup-review"],
        },
    )
    _write(
        repo / ".build" / "rig" / "cache-metadata" / "atlas-build.json",
        {
            "artifact_id": "atlas-build",
            "producer": "anigma_build_repo_atlas",
            "command": "python3 scripts/anigma_build_repo_atlas.py",
            "cache_key": "abc",
            "status": "fresh",
            "input_files": [{"path": "scripts/anigma_build_repo_atlas.py", "sha256": "1"}],
            "output_files": [{"path": "Docs/atlas/repo-map.json", "sha256": "2"}],
            "duration_seconds": 1.23,
        },
    )
    _write(
        repo / "Docs" / "atlas" / "repo-map.json",
        {"targets": [{"name": "AnigmaDaemonCore", "source_paths": ["anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore"]}]},
    )
    _write(
        repo / "Docs" / "atlas" / "targets.json",
        {"targets": [{"name": "AnigmaDaemonCore", "source_paths": ["anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore"]}]},
    )
    _write(
        repo / "Docs" / "atlas" / "risk-index.json",
        [{"path": "anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Foo.swift", "target": "AnigmaDaemonCore", "severity": "high", "confidence": "medium", "category": "missing_type"}],
    )
    (repo / "Docs" / "pipeline" / "profiles").mkdir(parents=True, exist_ok=True)
    (repo / "Docs" / "pipeline" / "profiles" / "local-fast.yaml").write_text("name: local-fast\n", encoding="utf-8")
    (repo / "Docs" / "pipeline" / "profiles" / "cleanup-review.yaml").write_text("name: cleanup-review\n", encoding="utf-8")
    return repo


def main() -> int:
    repo = _sample_repo()
    indexes = build_indexes(repo)
    assert len(indexes["rig-run-index"]) == 1
    assert len(indexes["rig-step-index"]) == 1
    assert len(indexes["rig-swift-diagnostics-index"]) == 1
    assert len(indexes["rig-affected-index"]) == 1
    assert len(indexes["rig-cache-metadata-index"]) == 1
    paths = write_indexes(repo)
    for path in paths.values():
        assert path.exists(), path
    for name in ["rig-run-index", "rig-step-index", "rig-swift-diagnostics-index", "rig-affected-index", "rig-cache-metadata-index"]:
        csv_path = repo / "Docs" / "indexes" / f"{name}.csv"
        with csv_path.open(encoding="utf-8", newline="") as fh:
            reader = csv.reader(fh)
            header = next(reader)
            assert header, name
    pack = build_context_pack(repo, task="demo", budget="small")
    assert "Rig Context Pack" in pack["markdown"]
    assert pack["latest_run"]["run_id"] == "run-1"
    assert pack["latest_affected"]["task"] == "demo"
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
