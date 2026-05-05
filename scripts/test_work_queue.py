#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import tempfile
import inspect
from pathlib import Path

from rig_tools import monitor, schema_validation, session_bundle, supervisor_loop, work_queue


REPO_ROOT = Path(__file__).resolve().parents[1]


def _repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="rig-queue-test-"))
    for rel in [
        "Docs/dev/rig",
        "Docs/schemas",
        "Docs/td/briefs",
        ".build/rig/queue",
        ".build/rig/queue/checkpoints",
        ".build/rig/queue/runs",
        ".build/rig/context",
        ".build/rig/loop/plans",
        ".build/rig/loop/runs",
        ".build/rig/affected",
        ".build/rig/projections",
        ".build/rig/swift-diagnostics",
        ".build/rig/schema-validation",
        ".build/rig/llm",
        ".build/rig/embeddings",
        ".build/rig/results",
        ".build/rig/agents/plans",
        ".build/rig/agents/runs",
        "Session-bundles",
    ]:
        (repo / rel).mkdir(parents=True, exist_ok=True)
    for rel in [
        "Docs/schemas/rig.queue.v1.schema.json",
        "Docs/schemas/rig.checkpoint.v1.schema.json",
        "Docs/schemas/rig.loop_plan.v1.schema.json",
        "Docs/schemas/rig.loop_run.v1.schema.json",
        "Docs/schemas/rig.context_pack.v1.schema.json",
        "Docs/schemas/rig.agent_plan.v1.schema.json",
        "Docs/schemas/rig.agent_run.v1.schema.json",
        "Docs/schemas/rig.result.v1.schema.json",
        "Docs/schemas/rig.event.v1.schema.json",
    ]:
        shutil.copy2(REPO_ROOT / rel, repo / rel)
    (repo / "Docs/td/briefs/td-cleanup-005.md").write_text("Brief", encoding="utf-8")
    (repo / ".build/rig/affected/summary.md").write_text("Affected", encoding="utf-8")
    (repo / ".build/rig/projections/latest.md").write_text("Projection", encoding="utf-8")
    (repo / ".build/rig/swift-diagnostics/latest.md").write_text("Swift diagnostics", encoding="utf-8")
    (repo / ".build/rig/schema-validation/latest.md").write_text("Schema validation", encoding="utf-8")
    (repo / ".build/rig/llm/latest-summary.md").write_text("LLM summary", encoding="utf-8")
    (repo / ".build/rig/embeddings/query-results.md").write_text("Embedding hits", encoding="utf-8")
    (repo / ".build/rig/loop/latest.md").write_text("Loop summary", encoding="utf-8")
    (repo / ".build/rig/context/latest.md").write_text("Context pack", encoding="utf-8")
    (repo / ".build/rig/context/latest.json").write_text(json.dumps({"schema_version": "rig.context_pack.v1", "task": "td-cleanup-005", "purpose": "loop-planner", "created_at": "2026-05-05T00:00:00Z", "max_chars": 16000, "input_artifacts": [], "selected_artifacts": [], "omitted_artifacts": [], "sections": [], "citations": [], "hashes": {}, "char_count": 0, "compression_ratio": 0.0, "warnings": [], "authoritative": False}), encoding="utf-8")
    (repo / ".build" / "rig" / "agents" / "plans" / "td-cleanup-005-codex-plan.json").write_text(json.dumps({"schema_version": "rig.agent_plan.v1", "plan_id": "td-cleanup-005-codex-plan", "task": "td-cleanup-005", "agent_id": "codex", "mode": "review", "prompt": "prompt", "allowed_paths": [], "forbidden_paths": [], "expected_outputs": [], "timeout_seconds": 1800, "requires_confirm": True, "git_mutation_allowed": False, "source_context": [], "created_by": "rig.py agent plan", "authoritative": False, "warnings": []}), encoding="utf-8")
    (repo / ".build" / "rig" / "agents" / "runs" / "run-1").mkdir(parents=True, exist_ok=True)
    (repo / ".build" / "rig" / "agents" / "runs" / "run-1" / "agent-run.json").write_text(json.dumps({"schema_version": "rig.agent_run.v1", "run_id": "run-1", "task": "td-cleanup-005", "agent_id": "codex", "status": "dry_run", "exit_code": 0, "started_at": "2026-05-05T00:00:00Z", "finished_at": "2026-05-05T00:00:01Z", "duration_seconds": 1.0, "command_template_id": "codex", "prompt_path": "p", "stdout_path": "o", "stderr_path": "e", "event_path": "ev", "artifacts": [], "warnings": [], "authoritative": False}), encoding="utf-8")
    result_payload = {
        "schema_version": "rig.result.v1",
        "run_id": "run-1",
        "task": "td-cleanup-005",
        "command_group": "affected",
        "command": "rig affected summary",
        "status": "passed",
        "exit_code": 0,
        "started_at": "2026-05-05T00:00:00Z",
        "finished_at": "2026-05-05T00:00:01Z",
        "duration_seconds": 1.0,
        "artifacts": [],
        "warnings": [],
        "errors": [],
        "notification_requested": False,
        "notification_status": "skipped",
        "notification_backend": None,
        "notification_error": None,
        "summary": {},
    }
    (repo / ".build" / "rig" / "results" / "latest.json").write_text(json.dumps(result_payload), encoding="utf-8")
    (repo / ".git").mkdir(exist_ok=True)
    (repo / ".venv-rig").mkdir(exist_ok=True)
    return repo


def test_add_list_status_and_pause_resume_cancel() -> None:
    repo = _repo()
    job = work_queue.add_job(repo, task="td-cleanup-005", mode="read-only", max_steps=3)
    assert job["status"] == "queued"
    assert work_queue.list_jobs(repo)
    assert work_queue.status(repo)["jobs_total"] == 1
    assert work_queue.pause_job(repo, job["job_id"])["status"] == "paused"
    assert work_queue.resume_job(repo, job["job_id"])["status"] == "queued"
    assert work_queue.cancel_job(repo, job["job_id"])["status"] == "cancelled"


def test_run_one_fake_job_writes_checkpoint() -> None:
    repo = _repo()
    job = work_queue.add_job(repo, task="td-cleanup-005", mode="read-only", max_steps=3)
    original_draft = supervisor_loop.draft_plan
    original_run = supervisor_loop._run_command
    original_write = work_queue.context_compression.write_context_pack
    try:
        work_queue.context_compression.write_context_pack = lambda *args, **kwargs: {"json_path": str(repo / ".build" / "rig" / "context" / "latest.json"), "md_path": str(repo / ".build" / "rig" / "context" / "latest.md")}
        supervisor_loop.draft_plan = lambda *args, **kwargs: ({
            "schema_version": "rig.loop_plan.v1",
            "plan_id": "td-cleanup-005-loop-plan",
            "task": "td-cleanup-005",
            "mode": "read-only",
            "step_index": 0,
            "action_id": "monitor_snapshot",
            "arguments": {},
            "reason": "scan",
            "expected_artifacts": [],
            "safety_class": "read_only",
            "requires_confirm": False,
            "authoritative": False,
            "stop_after": True,
            "warnings": [],
            "sequence": [
                {"action_id": "monitor_snapshot", "arguments": {}, "reason": "scan", "expected_artifacts": [], "safety_class": "read_only", "requires_confirm": False, "authoritative": False, "stop_after": True, "warnings": []},
            ],
            "generation_status": "generated",
            "backend": "mlx",
            "model": "m",
            "max_steps": 3,
            "source_artifacts": [".build/rig/context/latest.json", ".build/rig/context/latest.md"],
        }, repo / ".build" / "rig" / "loop" / "plans" / "td-cleanup-005-loop-plan.json")
        supervisor_loop._run_command = lambda *args, **kwargs: __import__("subprocess").CompletedProcess(args=args[1], returncode=0, stdout="{}", stderr="")
        result = work_queue.run_jobs(repo, max_jobs=1)
        assert result["processed"] == 1
        assert result["run_ids"]
        assert (repo / ".build" / "rig" / "queue" / "queue.json").exists()
        checkpoints = sorted((repo / ".build" / "rig" / "queue" / "checkpoints").glob("*.json"))
        assert checkpoints
        checkpoint = json.loads(checkpoints[-1].read_text())
        assert checkpoint["job_id"] == job["job_id"]
        assert checkpoint["step_index"] == 1
        assert checkpoint["last_action"] == "monitor_snapshot"
        updated = work_queue.show_job(repo, job["job_id"])
        assert updated["job"]["status"] in {"completed", "blocked"}
    finally:
        supervisor_loop.draft_plan = original_draft
        supervisor_loop._run_command = original_run
        work_queue.context_compression.write_context_pack = original_write


def test_resume_from_checkpoint() -> None:
    repo = _repo()
    job = work_queue.add_job(repo, task="td-cleanup-005", mode="read-only", max_steps=3)
    checkpoint = work_queue._checkpoint_payload(job, loop_run_id="lr", step_index=1, last_action="monitor_snapshot", last_result_path="x", next_allowed_actions=["schema_validate_results"], stop_reason=None)
    work_queue._write_json(work_queue._checkpoint_path(repo, job["job_id"]), checkpoint)
    original_draft = supervisor_loop.draft_plan
    original_run = supervisor_loop._run_command
    try:
        work_queue.context_compression.write_context_pack = lambda *args, **kwargs: {"json_path": str(repo / ".build" / "rig" / "context" / "latest.json"), "md_path": str(repo / ".build" / "rig" / "context" / "latest.md")}
        supervisor_loop.draft_plan = lambda *args, **kwargs: ({
            "schema_version": "rig.loop_plan.v1",
            "plan_id": "td-cleanup-005-loop-plan",
            "task": "td-cleanup-005",
            "mode": "read-only",
            "step_index": 0,
            "action_id": "stop",
            "arguments": {},
            "reason": "completed",
            "expected_artifacts": [],
            "safety_class": "read_only",
            "requires_confirm": False,
            "authoritative": False,
            "stop_after": True,
            "warnings": [],
            "sequence": [
                {"action_id": "monitor_snapshot", "arguments": {}, "reason": "scan", "expected_artifacts": [], "safety_class": "read_only", "requires_confirm": False, "authoritative": False, "stop_after": False, "warnings": []},
                {"action_id": "stop", "arguments": {}, "reason": "done", "expected_artifacts": [], "safety_class": "read_only", "requires_confirm": False, "authoritative": False, "stop_after": True, "warnings": []},
            ],
            "generation_status": "generated",
            "backend": "mlx",
            "model": "m",
            "max_steps": 3,
            "source_artifacts": [".build/rig/context/latest.json", ".build/rig/context/latest.md"],
        }, repo / ".build" / "rig" / "loop" / "plans" / "td-cleanup-005-loop-plan.json")
        supervisor_loop._run_command = lambda *args, **kwargs: __import__("subprocess").CompletedProcess(args=args[1], returncode=0, stdout="{}", stderr="")
        result = work_queue.run_jobs(repo, max_jobs=1)
        assert result["processed"] == 1
        cp = json.loads((repo / ".build" / "rig" / "queue" / "checkpoints" / f"{job['job_id']}.json").read_text())
        assert cp["step_index"] >= 2
    finally:
        supervisor_loop.draft_plan = original_draft
        supervisor_loop._run_command = original_run


def test_blocked_reason_and_schema_validation() -> None:
    repo = _repo()
    job = work_queue.add_job(repo, task="td-cleanup-005", mode="read-only", max_steps=1)
    job["status"] = "blocked"
    job["stop_reason"] = "swift_known_blocker"
    work_queue._update_job(repo, job)
    checkpoint = work_queue._checkpoint_payload(job, loop_run_id="lr", step_index=1, last_action="monitor_snapshot", last_result_path="x", next_allowed_actions=[], stop_reason="swift_known_blocker")
    work_queue._write_json(work_queue._checkpoint_path(repo, job["job_id"]), checkpoint)
    qsum = schema_validation.validate_artifacts(repo, family="rig.queue.v1")
    csum = schema_validation.validate_artifacts(repo, family="rig.checkpoint.v1")
    assert qsum.validated_artifact_count == 1
    assert csum.validated_artifact_count == 1


def test_monitor_and_bundle_integrations() -> None:
    repo = _repo()
    job = work_queue.add_job(repo, task="td-cleanup-005", mode="read-only", max_steps=1)
    work_queue._write_json(work_queue._checkpoint_path(repo, job["job_id"]), work_queue._checkpoint_payload(job, loop_run_id=None, step_index=0, last_action=None, last_result_path=None, next_allowed_actions=[], stop_reason="queued"))
    state = monitor.build_state(repo)
    assert "queue_summary" in state
    md, json_path = session_bundle._context_pack(repo, "td-cleanup-005")
    assert md is not None and json_path is not None


def test_no_shell_true_in_implementation() -> None:
    src = inspect.getsource(work_queue)
    assert "shell=True" not in src


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
