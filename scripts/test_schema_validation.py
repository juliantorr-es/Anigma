from __future__ import annotations

import json
import tempfile
from pathlib import Path

from rig_tools.schema_validation import list_families, validate_artifacts, validate_instance, _simple_validate


def _write(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(payload, str):
        path.write_text(payload, encoding="utf-8")
    else:
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="rig-schema-test-"))
    schemas_dir = repo / "Docs" / "schemas"
    schemas_dir.mkdir(parents=True, exist_ok=True)
    source_repo = Path(__file__).resolve().parents[1]
    for name in [
        "rig.result.v1.schema.json",
        "rig.event.v1.schema.json",
        "rig.affected.v1.schema.json",
        "rig.swift_diagnostics.v1.schema.json",
        "rig.cache_metadata.v1.schema.json",
    ]:
        (schemas_dir / name).write_text((source_repo / "Docs" / "schemas" / name).read_text(encoding="utf-8"), encoding="utf-8")
    _write(
        repo / ".build" / "rig" / "results" / "latest.json",
        {
            "schema_version": "rig.result.v1",
            "run_id": "r1",
            "command_group": "pipeline",
            "command": "rig pipeline run",
            "status": "passed",
            "exit_code": 0,
            "artifacts": [],
            "warnings": [],
            "errors": [],
            "summary": {},
        },
    )
    _write(
        repo / ".build" / "rig" / "swift-diagnostics" / "latest.json",
        {
            "schema_version": "rig.swift_diagnostics.v1",
            "run_label": "swift-build-AnigmaDaemonCore",
            "command": ["swift", "build"],
            "exit_code": 1,
            "status": "failed",
            "summary": {},
            "diagnostics": [{"severity": "error", "category": "missing_type", "message": "cannot find type", "raw_line": "Foo.swift:1:1: error: cannot find type"}],
        },
    )
    _write(
        repo / ".build" / "rig" / "affected" / "files.json",
        {
            "schema_version": "rig.affected.v1",
            "mode": "git",
            "changed_files": ["a.swift"],
            "directly_affected_targets": ["AnigmaDaemonCore"],
            "recommended_profiles": ["local-fast"],
            "affected_risk_count": 1,
        },
    )
    _write(
        repo / ".build" / "rig" / "affected" / "targets.json",
        {
            "schema_version": "rig.affected.v1",
            "mode": "git",
            "changed_files": ["a.swift"],
            "directly_affected_targets": ["AnigmaDaemonCore"],
            "recommended_profiles": ["local-fast"],
            "affected_risk_count": 1,
        },
    )
    _write(
        repo / ".build" / "rig" / "affected" / "risks.json",
        {
            "schema_version": "rig.affected.v1",
            "mode": "git",
            "changed_files": ["a.swift"],
            "directly_affected_targets": ["AnigmaDaemonCore"],
            "recommended_profiles": ["local-fast"],
            "affected_risk_count": 1,
        },
    )
    _write(
        repo / ".build" / "rig" / "affected" / "profiles.json",
        {
            "schema_version": "rig.affected.v1",
            "mode": "git",
            "changed_files": ["a.swift"],
            "directly_affected_targets": ["AnigmaDaemonCore"],
            "recommended_profiles": ["local-fast"],
            "affected_risk_count": 1,
        },
    )
    _write(
        repo / ".build" / "rig" / "cache-metadata" / "atlas-build.json",
        {
            "schema_version": "rig.cache-metadata.v1",
            "artifact_id": "atlas-build",
            "producer": "anigma_build_repo_atlas",
            "command": "python3 scripts/anigma_build_repo_atlas.py",
            "input_files": [{"path": "scripts/anigma_build_repo_atlas.py", "sha256": "1"}],
            "output_files": [{"path": "Docs/atlas/repo-map.json", "sha256": "2"}],
            "cache_key": "abc",
            "status": "fresh",
            "environment_fingerprint": {"python_version": "3.11"},
        },
    )
    _write(
        repo / ".build" / "rig" / "affected" / "summary.json",
        {
            "schema_version": "rig.affected.v1",
            "mode": "git",
            "changed_files": ["a.swift"],
            "directly_affected_targets": ["AnigmaDaemonCore"],
            "recommended_profiles": ["local-fast"],
            "affected_risk_count": 1,
        },
    )
    _write(
        repo / ".build" / "rig" / "events" / "run-1.jsonl",
        "\n".join([
            json.dumps({
                "schema_version": "rig.event.v1",
                "event_type": "run_started",
                "timestamp_utc": "2026-05-05T10:00:00Z",
                "run_id": "r1",
                "command_group": "pipeline",
                "command": "rig pipeline run",
                "task": None,
                "attributes": {},
            }),
            json.dumps({
                "schema_version": "rig.event.v1",
                "event_type": "run_finished",
                "timestamp_utc": "2026-05-05T10:00:01Z",
                "run_id": "r1",
                "command_group": "pipeline",
                "command": "rig pipeline run",
                "task": None,
                "attributes": {"status": "passed", "exit_code": 0, "result_path": ".build/rig/results/latest.json"},
            }),
        ]) + "\n",
    )
    return repo


def main() -> int:
    repo = _repo()
    assert "rig.result.v1" in list_families()
    valid = validate_artifacts(repo, artifact_path=".build/rig/results/latest.json", family="rig.result.v1")
    assert valid.status == "passed"
    missing = {"schema_version": "rig.result.v1", "run_id": "r1", "command_group": "pipeline", "command": "rig pipeline run", "status": "passed", "exit_code": 0, "artifacts": [], "warnings": [], "errors": []}
    schema = json.loads((repo / "Docs" / "schemas" / "rig.result.v1.schema.json").read_text(encoding="utf-8"))
    errs = validate_instance(missing, schema)
    assert errs, "expected required field failure"
    bad_status = dict(missing, summary={}, status="oops")
    errs = validate_instance(bad_status, schema)
    assert errs, "expected enum failure"
    event_schema = json.loads((repo / "Docs" / "schemas" / "rig.event.v1.schema.json").read_text(encoding="utf-8"))
    good_event = {
        "schema_version": "rig.event.v1",
        "event_type": "run_started",
        "timestamp_utc": "2026-05-05T10:00:00Z",
        "run_id": "r1",
        "command_group": "pipeline",
        "command": "rig pipeline run",
        "attributes": {},
    }
    assert not validate_instance(good_event, event_schema)
    bad_event = dict(good_event, event_type="bogus")
    assert validate_instance(bad_event, event_schema)
    assert _simple_validate(missing, schema)
    event_lines = [
        json.dumps(good_event),
        json.dumps(dict(good_event, event_type="artifact", attributes={"path": "x", "artifact_type": "result"})),
    ]
    for line in event_lines:
        assert not validate_instance(json.loads(line), event_schema)
    event_family = validate_artifacts(repo, family="rig.event.v1")
    assert event_family.status == "passed"
    swift = validate_artifacts(repo, artifact_path=".build/rig/swift-diagnostics/latest.json", family="rig.swift_diagnostics.v1")
    assert swift.status == "passed"
    cache = validate_artifacts(repo, artifact_path=".build/rig/cache-metadata/atlas-build.json", family="rig.cache_metadata.v1")
    assert cache.status == "passed"
    affected = validate_artifacts(repo, artifact_path=".build/rig/affected/files.json", family="rig.affected.v1")
    assert affected.status == "passed"
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
