#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path

from rig_tools import agent_plan, context_compression, schema_validation, session_bundle, supervisor_loop


REPO_ROOT = Path(__file__).resolve().parents[1]


def _repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="rig-context-test-"))
    for rel in [
        "Docs/dev/rig",
        "Docs/td/briefs",
        "Docs/proofs",
        "Docs/indexes",
        "Docs/schemas",
        ".build/rig/affected",
        ".build/rig/projections",
        ".build/rig/embeddings",
        ".build/rig/swift-diagnostics",
        ".build/rig/schema-validation",
        ".build/rig/llm",
        ".build/rig/agents/plans",
        ".build/rig/agents/runs",
        ".build/rig/loop/plans",
        ".build/rig/loop/runs",
        ".build/rig/context",
        ".build/rig/git",
        "Session-bundles",
    ]:
        (repo / rel).mkdir(parents=True, exist_ok=True)
    for rel in [
        "Docs/schemas/rig.context_pack.v1.schema.json",
        "Docs/schemas/rig.loop_plan.v1.schema.json",
        "Docs/schemas/rig.loop_run.v1.schema.json",
        "Docs/schemas/rig.agent_plan.v1.schema.json",
        "Docs/schemas/rig.agent_run.v1.schema.json",
    ]:
        shutil.copy2(REPO_ROOT / rel, repo / rel)
    (repo / "Docs/td/briefs/td-cleanup-005.md").write_text("# Brief\n\nNeed evidence.\n", encoding="utf-8")
    (repo / ".build/rig/affected/summary.md").write_text("AFFECTED\n- blocker: yes\n", encoding="utf-8")
    (repo / ".build/rig/projections/latest.md").write_text("PROJECTIONS\n- projection: A\n", encoding="utf-8")
    (repo / ".build/rig/embeddings/query-results.md").write_text("EMBEDDINGS\n- hit: X\n", encoding="utf-8")
    (repo / ".build/rig/swift-diagnostics/latest.md").write_text("SWIFT\n- error: missing module\n", encoding="utf-8")
    (repo / ".build/rig/schema-validation/latest.md").write_text("SCHEMA\n- status: passed\n", encoding="utf-8")
    (repo / ".build/rig/llm/latest-summary.md").write_text("LLM summary\n", encoding="utf-8")
    (repo / ".build/rig/agents/plans/p.json").write_text(json.dumps({"schema_version": "rig.agent_plan.v1", "plan_id": "p", "task": "td-cleanup-005", "agent_id": "codex"}), encoding="utf-8")
    (repo / ".build/rig/agents/runs/r/agent-run.json").parent.mkdir(parents=True, exist_ok=True)
    (repo / ".build/rig/agents/runs/r/agent-run.json").write_text(json.dumps({"schema_version": "rig.agent_run.v1", "run_id": "r", "task": "td-cleanup-005"}), encoding="utf-8")
    (repo / ".build/rig/loop/latest.md").write_text("LOOP\n- stop\n", encoding="utf-8")
    (repo / ".build/rig/loop/latest.json").write_text(json.dumps({"schema_version": "rig.loop_run.v1", "run_id": "lr", "task": "td-cleanup-005", "mode": "read-only", "status": "dry_run", "started_at": "2026-05-05T00:00:00Z", "finished_at": "2026-05-05T00:00:01Z", "duration_seconds": 1.0, "max_steps": 3, "steps": [], "event_path": "x", "result_path": "y", "artifacts": [], "stop_reason": "dry_run", "warnings": [], "authoritative": False}), encoding="utf-8")
    (repo / ".build/rig/git/commit-plan-td-cleanup-005.json").write_text(json.dumps({"schema_version": "rig.git_commit_plan.v1", "task": "td-cleanup-005", "status": "blocked"}), encoding="utf-8")
    (repo / "Docs/proofs/td-cleanup-005-proof.md").write_text("Proof line 1\nProof line 2\n", encoding="utf-8")
    for idx in range(3):
        (repo / f"Docs/proofs/td-cleanup-005-supplemental-{idx}.md").write_text("SUPPLEMENTAL\n" + ("line\n" * 500), encoding="utf-8")
    (repo / "Docs/indexes/rig-run-index.json").write_text(json.dumps([]), encoding="utf-8")
    (repo / ".git").mkdir(exist_ok=True)
    (repo / ".venv-rig").mkdir(exist_ok=True)
    (repo / "Docs/.DS_Store").write_text("junk", encoding="utf-8")
    (repo / "Docs/__pycache__").mkdir(exist_ok=True)
    (repo / "Docs/__pycache__/x.pyc").write_bytes(b"\0")
    return repo


def test_context_pack_shape_and_budget() -> None:
    repo = _repo()
    pack = context_compression.build_context_pack(repo, task="td-cleanup-005", purpose="loop-planner", max_chars=1200, use_llm=False)
    assert pack["schema_version"] == "rig.context_pack.v1"
    assert pack["authoritative"] is False
    assert pack["task"] == "td-cleanup-005"
    assert pack["char_count"] <= 1200
    assert pack["selected_artifacts"]
    assert pack["omitted_artifacts"]
    assert any(sec["section_type"] == "task_brief" for sec in pack["sections"])
    assert any(sec["section_type"] == "affected_summary" for sec in pack["sections"])
    assert any(sec["section_type"] == "swift_diagnostics" for sec in pack["sections"])
    assert any(item["path"].startswith("Docs/td/briefs/") for item in pack["citations"])
    assert all(".git" not in item["path"] and ".venv-rig" not in item["path"] and ".DS_Store" not in item["path"] and "__pycache__" not in item["path"] for item in pack["citations"])
    assert "Docs/td/briefs/td-cleanup-005.md" in pack["hashes"]


def test_large_artifact_truncated_and_deterministic_ordering() -> None:
    repo = _repo()
    pack = context_compression.build_context_pack(repo, task="td-cleanup-005", purpose="review", max_chars=400, use_llm=False)
    pack2 = context_compression.build_context_pack(repo, task="td-cleanup-005", purpose="review", max_chars=400, use_llm=False)
    paths = [item["path"] for item in pack["citations"]]
    assert paths == [item["path"] for item in pack2["citations"]]
    assert pack["char_count"] <= 400
    assert pack["omitted_artifacts"]


def test_optional_llm_summary_is_advisory() -> None:
    repo = _repo()
    original = context_compression.mlx_local.generate_summary
    try:
        context_compression.mlx_local.generate_summary = lambda **kwargs: {"status": "generated", "backend": "mlx", "model": "m", "output": "LLM bullets", "warnings": []}
        pack = context_compression.build_context_pack(repo, task="td-cleanup-005", purpose="review", max_chars=2400, use_llm=True, model="m")
        assert "llm_summaries_advisory" in pack["warnings"]
        assert any(sec.get("llm_summary", {}).get("advisory") for sec in pack["sections"] if sec.get("llm_summary"))
    finally:
        context_compression.mlx_local.generate_summary = original


def test_schema_validation_and_latest_pack() -> None:
    repo = _repo()
    pack = context_compression.write_context_pack(repo, task="td-cleanup-005", purpose="agent-plan", max_chars=2400, use_llm=False)
    assert (repo / ".build" / "rig" / "context" / "latest.json").exists()
    assert (repo / ".build" / "rig" / "context" / "latest.md").exists()
    summary = schema_validation.validate_artifacts(repo, artifact_path=str(repo / ".build" / "rig" / "context" / "latest.json"))
    assert summary.validated_artifact_count == 1
    assert summary.passed_count == 1
    assert pack["json_path"].endswith("td-cleanup-005-context-pack.json")


def test_loop_and_agent_collect_latest_context_pack() -> None:
    repo = _repo()
    context_compression.write_context_pack(repo, task="td-cleanup-005", purpose="loop-planner", max_chars=2000, use_llm=False)
    loop_ctx = supervisor_loop._collect_context(repo, "td-cleanup-005")
    agent_ctx = agent_plan.collect_context(repo, "td-cleanup-005")
    assert loop_ctx["source_artifacts"] == [".build/rig/context/latest.json", ".build/rig/context/latest.md"]
    assert agent_ctx["source_artifacts"] == [".build/rig/context/latest.json", ".build/rig/context/latest.md"]
    assert len(loop_ctx["context"]) <= supervisor_loop.MAX_CONTEXT_CHARS
    assert len(agent_ctx["context"]) <= 24000


def test_session_bundle_context_pack_hook() -> None:
    repo = _repo()
    context_compression.write_context_pack(repo, task="td-cleanup-005", purpose="review", max_chars=2400, use_llm=False)
    md, json_path = session_bundle._context_pack(repo, "td-cleanup-005")
    assert md and md.name == "td-cleanup-005-context-pack.md"
    assert json_path and json_path.name == "td-cleanup-005-context-pack.json"


def test_budget_helper() -> None:
    assert context_compression.budget_for_purpose("loop-planner") == 16000
    assert context_compression.budget_for_purpose("agent-plan") == 24000


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
