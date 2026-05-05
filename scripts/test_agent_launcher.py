#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from rig_tools import agent_launcher, agent_plan, schema_validation


REPO_ROOT = Path(__file__).resolve().parents[1]


def _repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="rig-agent-test-"))
    for rel in [
        "Docs/dev/rig",
        "Docs/td/briefs",
        "Docs/proofs",
        "Docs/indexes",
        "Docs/schemas",
        ".build/rig/results",
        ".build/rig/events",
        ".build/rig/affected",
        ".build/rig/projections",
        ".build/rig/llm",
        ".build/rig/embeddings",
        ".build/rig/git",
        ".build/rig/monitor",
        ".build/rig/agents/plans",
        ".build/rig/agents/runs",
    ]:
        (repo / rel).mkdir(parents=True, exist_ok=True)
    for rel in [
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
    (repo / ".build/rig/embeddings/query-results.json").write_text(json.dumps({"status": "passed"}), encoding="utf-8")
    (repo / ".build/rig/git/commit-plan-td-cleanup-005.json").write_text(json.dumps({"status": "ready", "included_files": []}), encoding="utf-8")
    return repo


def test_registry_detection_reports_missing_agents() -> None:
    repo = _repo()
    original = agent_plan._which
    try:
        agent_plan._which = lambda name: name == "claude"
        agents = agent_plan.detect_agents(repo)
        by_id = {item["agent_id"]: item for item in agents}
        assert by_id["claude"]["available"] is True
        assert by_id["codex"]["available"] is False
        assert by_id["codex"]["enabled"] is False
    finally:
        agent_plan._which = original


def test_plan_generation_is_advisory_and_schema_shaped() -> None:
    repo = _repo()
    original = agent_plan.mlx_local.generate_summary
    try:
        agent_plan.mlx_local.generate_summary = lambda **kwargs: {
            "status": "generated",
            "backend": "mlx",
            "model": "m",
            "warnings": [],
            "error": None,
            "output": json.dumps({
                "schema_version": "rig.agent_plan.v1",
                "plan_id": "td-cleanup-005-codex-plan",
                "task": "td-cleanup-005",
                "agent_id": "codex",
                "mode": "review",
                "prompt": "plan",
                "prompt_file": ".build/rig/agents/plans/td-cleanup-005-codex-plan.prompt.md",
                "allowed_paths": [],
                "forbidden_paths": [],
                "expected_outputs": ["review"],
                "timeout_seconds": 1800,
                "requires_confirm": True,
                "git_mutation_allowed": False,
                "source_context": ["Docs/td/briefs/td-cleanup-005.md"],
                "created_by": "rig.py agent plan",
                "authoritative": False,
                "warnings": []
            }),
        }
        plan = agent_plan.draft_agent_plan(repo, task="td-cleanup-005", model="m")
        assert plan["authoritative"] is False
        assert plan["task"] == "td-cleanup-005"
        assert (repo / ".build/rig/agents/plans" / f"{plan['plan_id']}.json").exists()
        validation = agent_plan.validate_plan(repo, plan)
        assert validation["status"] == "passed"
    finally:
        agent_plan.mlx_local.generate_summary = original


def test_malformed_llm_output_writes_raw_output() -> None:
    repo = _repo()
    original = agent_plan.mlx_local.generate_summary
    try:
        agent_plan.mlx_local.generate_summary = lambda **kwargs: {
            "status": "failed",
            "backend": "mlx",
            "model": "m",
            "warnings": ["bad_json"],
            "error": "malformed",
            "output": "not json at all",
        }
        plan = agent_plan.draft_agent_plan(repo, task="td-cleanup-005", model="m")
        assert plan["generation_status"] == "failed"
        raw_path = repo / plan["raw_output_path"]
        assert raw_path.exists()
        assert raw_path.read_text(encoding="utf-8") == "not json at all"
        assert "llm_output_unparseable" in plan["warnings"]
    finally:
        agent_plan.mlx_local.generate_summary = original


def test_validate_plan_rejects_forbidden_values() -> None:
    repo = _repo()
    plan = {
        "schema_version": "rig.agent_plan.v1",
        "plan_id": "bad",
        "task": "td-cleanup-005",
        "agent_id": "vibe",
        "mode": "review",
        "prompt": "shell=rm -rf /",
        "prompt_file": ".build/rig/agents/plans/bad.prompt.md",
        "allowed_paths": [],
        "forbidden_paths": [],
        "expected_outputs": [],
        "timeout_seconds": 1,
        "requires_confirm": True,
        "git_mutation_allowed": False,
        "source_context": [],
        "created_by": "rig.py agent plan",
        "authoritative": False,
        "warnings": [],
    }
    validation = agent_plan.validate_plan(repo, plan)
    assert validation["status"] == "failed"
    assert "vibe_disabled" in validation["errors"]
    assert "forbidden_instruction" in validation["errors"]


def test_dry_run_does_not_execute_subprocess() -> None:
    repo = _repo()
    plan_path = repo / ".build/rig/agents/plans/plan.json"
    plan = {
        "schema_version": "rig.agent_plan.v1",
        "plan_id": "plan",
        "task": "td-cleanup-005",
        "agent_id": "codex",
        "mode": "review",
        "prompt": "hello",
        "prompt_file": ".build/rig/agents/plans/plan.prompt.md",
        "allowed_paths": [],
        "forbidden_paths": [],
        "expected_outputs": [],
        "timeout_seconds": 1800,
        "requires_confirm": True,
        "git_mutation_allowed": False,
        "source_context": [],
        "created_by": "rig.py agent plan",
        "authoritative": False,
        "warnings": [],
    }
    plan_path.write_text(json.dumps(plan), encoding="utf-8")
    called = {"count": 0}
    original = subprocess.run
    try:
        def fake_run(*args, **kwargs):
            called["count"] += 1
            raise AssertionError("subprocess should not run in dry-run")
        subprocess.run = fake_run  # type: ignore[assignment]
        result = agent_launcher.launch_from_plan(repo, plan_path, dry_run=True)
        assert result["status"] == "dry_run"
        assert called["count"] == 0
    finally:
        subprocess.run = original  # type: ignore[assignment]


def test_confirmed_launch_captures_artifacts_without_shell_true() -> None:
    repo = _repo()
    plan_path = repo / ".build/rig/agents/plans/plan.json"
    plan = {
        "schema_version": "rig.agent_plan.v1",
        "plan_id": "plan",
        "task": "td-cleanup-005",
        "agent_id": "gemini",
        "mode": "review",
        "prompt": "hello",
        "prompt_file": ".build/rig/agents/plans/plan.prompt.md",
        "allowed_paths": [],
        "forbidden_paths": [],
        "expected_outputs": [],
        "timeout_seconds": 1800,
        "requires_confirm": True,
        "git_mutation_allowed": False,
        "source_context": [],
        "created_by": "rig.py agent plan",
        "authoritative": False,
        "warnings": [],
    }
    plan_path.write_text(json.dumps(plan), encoding="utf-8")
    captured = {}
    original = subprocess.run
    try:
        def fake_run(cmd, **kwargs):
            captured["cmd"] = cmd
            captured["kwargs"] = kwargs
            class Proc:
                returncode = 0
                stdout = "{\"ok\":true}"
                stderr = ""
            return Proc()
        subprocess.run = fake_run  # type: ignore[assignment]
        result = agent_launcher.launch_from_plan(repo, plan_path, confirm=True)
        assert result["status"] == "passed"
        assert captured["kwargs"]["shell"] is False
        assert (repo / ".build/rig/agents/runs" / result["run_id"] / "agent-run.json").exists()
    finally:
        subprocess.run = original  # type: ignore[assignment]


def test_timeout_handling_returns_failure() -> None:
    repo = _repo()
    plan_path = repo / ".build/rig/agents/plans/plan.json"
    plan = {
        "schema_version": "rig.agent_plan.v1",
        "plan_id": "plan",
        "task": "td-cleanup-005",
        "agent_id": "claude",
        "mode": "review",
        "prompt": "hello",
        "prompt_file": ".build/rig/agents/plans/plan.prompt.md",
        "allowed_paths": [],
        "forbidden_paths": [],
        "expected_outputs": [],
        "timeout_seconds": 1,
        "requires_confirm": True,
        "git_mutation_allowed": False,
        "source_context": [],
        "created_by": "rig.py agent plan",
        "authoritative": False,
        "warnings": [],
    }
    plan_path.write_text(json.dumps(plan), encoding="utf-8")
    original = subprocess.run
    try:
        def fake_run(*args, **kwargs):
            raise subprocess.TimeoutExpired(cmd=args[0], timeout=1)
        subprocess.run = fake_run  # type: ignore[assignment]
        result = agent_launcher.launch_from_plan(repo, plan_path, confirm=True)
        assert result["exit_code"] == 124
        assert result["status"] == "failed"
    finally:
        subprocess.run = original  # type: ignore[assignment]


def test_schema_validation_understands_agent_artifacts() -> None:
    repo = _repo()
    plan = {
        "schema_version": "rig.agent_plan.v1",
        "plan_id": "plan",
        "task": "td-cleanup-005",
        "agent_id": "codex",
        "mode": "review",
        "prompt": "hello",
        "prompt_file": ".build/rig/agents/plans/plan.prompt.md",
        "allowed_paths": [],
        "forbidden_paths": [],
        "expected_outputs": [],
        "timeout_seconds": 1800,
        "requires_confirm": True,
        "git_mutation_allowed": False,
        "source_context": [],
        "created_by": "rig.py agent plan",
        "authoritative": False,
        "warnings": [],
    }
    run_payload = {
        "schema_version": "rig.agent_run.v1",
        "run_id": "run-1",
        "plan_id": "plan",
        "task": "td-cleanup-005",
        "agent_id": "codex",
        "status": "passed",
        "exit_code": 0,
        "started_at": "2026-05-05T00:00:00Z",
        "finished_at": "2026-05-05T00:00:01Z",
        "duration_seconds": 1.0,
        "command_template_id": "codex",
        "prompt_path": ".build/rig/agents/runs/run-1/prompt.md",
        "stdout_path": ".build/rig/agents/runs/run-1/stdout.log",
        "stderr_path": ".build/rig/agents/runs/run-1/stderr.log",
        "event_path": ".build/rig/agents/runs/run-1/events.jsonl",
        "artifacts": [],
        "warnings": [],
        "authoritative": False,
    }
    plan_path = repo / ".build/rig/agents/plans/plan.json"
    run_dir = repo / ".build/rig/agents/runs/run-1"
    run_dir.mkdir(parents=True, exist_ok=True)
    plan_path.write_text(json.dumps(plan), encoding="utf-8")
    (run_dir / "agent-run.json").write_text(json.dumps(run_payload), encoding="utf-8")
    summary = schema_validation.validate_artifacts(repo, family="rig.agent_plan.v1")
    assert summary.validated_artifact_count >= 1
    summary2 = schema_validation.validate_artifacts(repo, family="rig.agent_run.v1")
    assert summary2.validated_artifact_count >= 1


def main() -> int:
    tests = [name for name, value in globals().items() if name.startswith("test_") and callable(value)]
    failed = []
    for name in sorted(tests):
        try:
            globals()[name]()
        except Exception as exc:
            failed.append((name, exc))
            print(f"{name}: FAIL: {exc}")
        else:
            print(f"{name}: ok")
    if failed:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
