#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from rig_tools import schema_validation, supervisor_loop


REPO_ROOT = Path(__file__).resolve().parents[1]


def _repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="rig-loop-test-"))
    for rel in [
        "Docs/dev/rig",
        "Docs/td/briefs",
        "Docs/schemas",
        ".build/rig/results",
        ".build/rig/events",
        ".build/rig/affected",
        ".build/rig/projections",
        ".build/rig/monitor",
        ".build/rig/llm",
        ".build/rig/embeddings",
        ".build/rig/agents/plans",
        ".build/rig/agents/runs",
        ".build/rig/loop/plans",
        ".build/rig/loop/runs",
    ]:
        (repo / rel).mkdir(parents=True, exist_ok=True)
    for rel in [
        "Docs/schemas/rig.loop_plan.v1.schema.json",
        "Docs/schemas/rig.loop_run.v1.schema.json",
        "Docs/schemas/rig.agent_plan.v1.schema.json",
        "Docs/schemas/rig.agent_run.v1.schema.json",
        "Docs/schemas/rig.local_llm_summary.v1.schema.json",
        "Docs/schemas/rig.embedding_index.v1.schema.json",
    ]:
        (repo / rel).write_text((REPO_ROOT / rel).read_text(encoding="utf-8"), encoding="utf-8")
    (repo / "Docs/dev/rig/agent-registry.yaml").write_text((REPO_ROOT / "Docs/dev/rig/agent-registry.yaml").read_text(encoding="utf-8"), encoding="utf-8")
    (repo / "Docs/td/briefs/td-cleanup-005.md").write_text("brief", encoding="utf-8")
    (repo / ".build/rig/affected/summary.md").write_text("affected summary", encoding="utf-8")
    (repo / ".build/rig/projections/latest.md").write_text("projection summary", encoding="utf-8")
    (repo / ".build/rig/results/latest.json").write_text(json.dumps({"schema_version": "rig.result.v1", "run_id": "run-1", "task": "td-cleanup-005"}), encoding="utf-8")
    (repo / ".build/rig/llm/latest-summary.json").write_text(json.dumps({"schema_version": "rig.local_llm_summary.v1", "status": "generated", "authoritative": False, "backend": "mlx", "model": "m", "task": "td-cleanup-005", "source_artifacts": [], "prompt_kind": "session", "summary": "s", "limitations": [], "warnings": [], "created_at": "2026-05-05T00:00:00Z", "input_char_count": 1, "output_char_count": 1}), encoding="utf-8")
    (repo / ".build/rig/embeddings/query-results.json").write_text(json.dumps({"status": "passed", "results": []}), encoding="utf-8")
    return repo


def test_status_and_actions() -> None:
    repo = _repo()
    status = supervisor_loop.status(repo)
    assert any(item["action_id"] == "affected_summary" for item in status["actions"])
    assert any(item["action_id"] == "stop" for item in status["actions"])


def test_plan_validation_and_rejection() -> None:
    repo = _repo()
    plan = {
        "schema_version": "rig.loop_plan.v1",
        "plan_id": "p",
        "task": "td-cleanup-005",
        "mode": "read-only",
        "step_index": 0,
        "action_id": "affected_summary",
        "arguments": {"task": "td-cleanup-005"},
        "reason": "ok",
        "expected_artifacts": [],
        "safety_class": "read_only",
        "requires_confirm": False,
        "authoritative": False,
        "stop_after": False,
        "warnings": [],
    }
    assert supervisor_loop.validate_plan(repo, plan)["status"] == "passed"
    bad = dict(plan, action_id="bad", arguments={"cmd": "rm -rf /"})
    validation = supervisor_loop.validate_plan(repo, bad)
    assert validation["status"] == "failed"


def test_deterministic_fallback_and_plan_write() -> None:
    repo = _repo()
    original = supervisor_loop.mlx_local.generate_summary
    try:
        supervisor_loop.mlx_local.generate_summary = lambda **kwargs: {"status": "failed", "backend": "mlx", "model": "m", "warnings": [], "error": "bad", "output": "not json"}
        plan, path = supervisor_loop.draft_plan(repo, task="td-cleanup-005", mode="read-only", backend="mlx", model="m")
        assert plan["generation_status"] == "failed"
        assert (repo / plan["raw_output_path"]).exists()
        assert path.exists()
    finally:
        supervisor_loop.mlx_local.generate_summary = original


def test_loop_run_and_events() -> None:
    repo = _repo()
    original = supervisor_loop.mlx_local.generate_summary
    original_run = supervisor_loop._run_command
    try:
        supervisor_loop.mlx_local.generate_summary = lambda **kwargs: {"status": "generated", "backend": "mlx", "model": "m", "warnings": [], "error": None, "output": json.dumps({"schema_version": "rig.loop_plan.v1", "plan_id": "td-cleanup-005-loop-plan", "task": "td-cleanup-005", "mode": "read-only", "step_index": 0, "action_id": "stop", "arguments": {}, "reason": "stop", "expected_artifacts": [], "safety_class": "read_only", "requires_confirm": False, "authoritative": False, "stop_after": True, "warnings": []})}
        result = supervisor_loop.run_loop(repo, task="td-cleanup-005", mode="read-only", backend="mlx", model="m", max_steps=2, dry_run=True)
        assert result["status"] == "dry_run"
        assert (repo / ".build/rig/loop/latest.json").exists()
        assert (repo / ".build/rig/loop/latest.md").exists()
    finally:
        supervisor_loop.mlx_local.generate_summary = original
        supervisor_loop._run_command = original_run


def test_validation_for_schemas() -> None:
    repo = _repo()
    plan_path = repo / ".build/rig/loop/plans/p.json"
    plan = {
        "schema_version": "rig.loop_plan.v1",
        "plan_id": "p",
        "task": "td-cleanup-005",
        "mode": "read-only",
        "step_index": 0,
        "action_id": "stop",
        "arguments": {},
        "reason": "stop",
        "expected_artifacts": [],
        "safety_class": "read_only",
        "requires_confirm": False,
        "authoritative": False,
        "stop_after": True,
        "warnings": [],
    }
    plan_path.write_text(json.dumps(plan), encoding="utf-8")
    summary = schema_validation.validate_artifacts(repo, artifact_path=str(plan_path))
    assert summary.validated_artifact_count == 1


def main() -> int:
    failures = []
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
            except Exception as exc:
                print(f"{name}: FAIL: {exc}")
                failures.append(name)
            else:
                print(f"{name}: ok")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
