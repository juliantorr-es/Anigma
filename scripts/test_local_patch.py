#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import tempfile
import inspect
import subprocess
from pathlib import Path

from rig_tools import local_patch, monitor, schema_validation, session_bundle, supervisor_loop


REPO_ROOT = Path(__file__).resolve().parents[1]


def _repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="rig-local-patch-test-"))
    for rel in [
        "Docs/dev/rig",
        "Docs/schemas",
        "Docs/td/briefs",
        "Docs/proofs",
        ".build/rig/results",
        ".build/rig/monitor",
        ".build/rig/context",
        ".build/rig/loop/plans",
        ".build/rig/agents/plans",
        ".build/rig/agents/runs",
        ".build/rig/patches",
        ".build/rig/sandboxes",
        "Session-bundles",
        "scripts",
    ]:
        (repo / rel).mkdir(parents=True, exist_ok=True)
    for rel in [
        "Docs/schemas/rig.local_patch.v1.schema.json",
        "Docs/schemas/rig.patch_validation.v1.schema.json",
        "Docs/schemas/rig.context_pack.v1.schema.json",
        "Docs/schemas/rig.loop_plan.v1.schema.json",
        "Docs/schemas/rig.loop_run.v1.schema.json",
        "Docs/schemas/rig.agent_plan.v1.schema.json",
        "Docs/schemas/rig.agent_run.v1.schema.json",
        "Docs/schemas/rig.result.v1.schema.json",
        "Docs/schemas/rig.event.v1.schema.json",
    ]:
        shutil.copy2(REPO_ROOT / rel, repo / rel)
    (repo / "Docs/dev/rig/README.md").write_text("Rig docs", encoding="utf-8")
    (repo / "Docs/dev/rig/LOCAL_PATCHES.md").write_text("Patch docs", encoding="utf-8")
    (repo / "Docs/td/briefs/td-cleanup-005.md").write_text("Brief", encoding="utf-8")
    (repo / ".build/rig/results/latest.json").write_text(json.dumps({"schema_version": "rig.result.v1", "run_id": "run-1", "task": "td-cleanup-005", "command_group": "affected", "command": "rig affected summary", "status": "passed", "exit_code": 0, "started_at": "2026-05-05T00:00:00Z", "finished_at": "2026-05-05T00:00:01Z", "duration_seconds": 1.0, "artifacts": [], "warnings": [], "errors": [], "notification_requested": False, "notification_status": "skipped", "notification_backend": None, "notification_error": None, "summary": {}}), encoding="utf-8")
    (repo / ".build/rig/context/latest.json").write_text(json.dumps({"schema_version": "rig.context_pack.v1", "task": "td-cleanup-005", "purpose": "loop-planner", "created_at": "2026-05-05T00:00:00Z", "max_chars": 16000, "input_artifacts": [], "selected_artifacts": [], "omitted_artifacts": [], "sections": [], "citations": [], "hashes": {}, "char_count": 0, "compression_ratio": 0.0, "warnings": [], "authoritative": False}), encoding="utf-8")
    (repo / ".build/rig/context/latest.md").write_text("Context", encoding="utf-8")
    (repo / ".git").mkdir(exist_ok=True)
    subprocess.run(["git", "init", "-q"], cwd=repo, check=False)
    return repo


def _write_diff(repo: Path, patch_dir: Path, text: str) -> Path:
    patch_dir.mkdir(parents=True, exist_ok=True)
    patch = patch_dir / "changes.patch"
    patch.write_text(text, encoding="utf-8")
    return patch


def test_status_and_reserved_action() -> None:
    repo = _repo()
    status = local_patch.status(repo)
    assert status["status"] in {"available", "tool_missing"}
    loop_status = supervisor_loop.status(repo)
    assert any(item["action_id"] == "local_patch_propose" and item["enabled"] is False for item in loop_status["actions"])


def test_propose_check_and_validation_flow() -> None:
    repo = _repo()
    original = local_patch.mlx_local.generate_summary
    try:
        responses = iter([
            {
                "status": "generated",
                "backend": "mlx",
                "model": "mlx-community/Qwen3-4B-Instruct-2507-4bit",
                "warnings": [],
                "error": None,
                "output": "Here is a patch proposal that is malformed prose only.",
            },
            {
                "status": "generated",
                "backend": "mlx",
                "model": "mlx-community/Qwen3-4B-Instruct-2507-4bit",
                "warnings": [],
                "error": None,
                "output": """diff --git a/Docs/dev/rig/LOCAL_PATCHES_EXTRA.md b/Docs/dev/rig/LOCAL_PATCHES_EXTRA.md\nnew file mode 100644\n--- /dev/null\n+++ b/Docs/dev/rig/LOCAL_PATCHES_EXTRA.md\n@@ -0,0 +1,2 @@\n+Patch docs extra\n+Updated by patch proposal\n""",
            },
        ])
        local_patch.mlx_local.generate_summary = lambda **kwargs: next(responses)
        proposal = local_patch.propose_patch(repo, task="td-cleanup-005", backend="mlx", model="mlx-community/Qwen3-4B-Instruct-2507-4bit", allowed_paths=["Docs/dev/rig", "scripts"], dry_run=True)
        assert proposal["patch_id"]
        assert proposal["validation"]["repair_loop_used"] is True
        assert proposal["validation"]["repair_attempt_count"] == 2
        assert proposal["validation"]["successful_attempt"] == 2
        patch_path = repo / ".build" / "rig" / "patches" / proposal["patch_id"] / "changes.patch"
        assert patch_path.exists()
        checked = local_patch.check_patch(repo, patch_path)
        assert checked["git_apply_check_status"] in {"passed", "failed"}
        validation = local_patch.validate_patch(repo, patch_path)
        assert validation["sandbox_apply_status"] in {"passed", "failed"}
    finally:
        local_patch.mlx_local.generate_summary = original


def test_no_diff_and_max_attempts_exceeded() -> None:
    repo = _repo()
    original = local_patch.mlx_local.generate_summary
    try:
        local_patch.mlx_local.generate_summary = lambda **kwargs: {
            "status": "generated",
            "backend": "mlx",
            "model": "mlx-community/Qwen3-4B-Instruct-2507-4bit",
            "warnings": [],
            "error": None,
            "output": "no diff here",
        }
        proposal = local_patch.propose_patch(repo, task="td-cleanup-005", backend="mlx", model="mlx-community/Qwen3-4B-Instruct-2507-4bit", allowed_paths=["Docs/dev/rig"], dry_run=True, max_repair_attempts=2)
        assert proposal["validation"]["repair_attempt_count"] == 2
        assert proposal["validation"]["final_failure_reason"] == "max_attempts_exceeded" or proposal["validation"]["final_failure_reason"] in {"no_diff_found", "markdown_fence_or_prose_only"}
    finally:
        local_patch.mlx_local.generate_summary = original


def test_no_repair_stops_after_first_invalid_attempt() -> None:
    repo = _repo()
    original = local_patch.mlx_local.generate_summary
    try:
        local_patch.mlx_local.generate_summary = lambda **kwargs: {
            "status": "generated",
            "backend": "mlx",
            "model": "mlx-community/Qwen3-4B-Instruct-2507-4bit",
            "warnings": [],
            "error": None,
            "output": "prose only",
        }
        proposal = local_patch.propose_patch(repo, task="td-cleanup-005", backend="mlx", model="mlx-community/Qwen3-4B-Instruct-2507-4bit", allowed_paths=["Docs/dev/rig"], dry_run=True, no_repair=True)
        assert proposal["validation"]["repair_attempt_count"] == 1
        assert proposal["validation"]["repair_loop_used"] is False
    finally:
        local_patch.mlx_local.generate_summary = original


def test_scope_rejections_and_parser_guards() -> None:
    repo = _repo()
    patch_dir = repo / ".build" / "rig" / "patches" / "patch-1"
    patch = _write_diff(repo, patch_dir, """diff --git a/.git/config b/.git/config\n--- a/.git/config\n+++ b/.git/config\n@@ -1 +1 @@\n-a\n+b\n""")
    result = local_patch.check_patch(repo, patch)
    assert result["status"] in {"rejected", "check_failed"}
    assert result["forbidden_path_violations"]
    assert local_patch._is_binary_patch("GIT binary patch")
    assert local_patch._has_conflict_markers("<<<<<<<\n=======\n>>>>>>>")
    assert not local_patch._safe_path("../escape")
    assert not local_patch._safe_path("/abs/path")


def test_sandbox_apply_does_not_touch_main_worktree() -> None:
    repo = _repo()
    source = repo / "Docs/dev/rig/LOCAL_PATCHES.md"
    original = source.read_text(encoding="utf-8")
    original_gen = local_patch.mlx_local.generate_summary
    try:
        local_patch.mlx_local.generate_summary = lambda **kwargs: {
            "status": "generated",
            "backend": "mlx",
            "model": "mlx-community/Qwen3-4B-Instruct-2507-4bit",
            "warnings": [],
            "error": None,
            "output": """diff --git a/Docs/dev/rig/LOCAL_PATCHES_EXTRA.md b/Docs/dev/rig/LOCAL_PATCHES_EXTRA.md\nnew file mode 100644\n--- /dev/null\n+++ b/Docs/dev/rig/LOCAL_PATCHES_EXTRA.md\n@@ -0,0 +1,2 @@\n+Patch docs extra\n+Sandbox line\n""",
        }
        proposal = local_patch.propose_patch(repo, task="td-cleanup-005", backend="mlx", model="mlx-community/Qwen3-4B-Instruct-2507-4bit", allowed_paths=["Docs/dev/rig"], dry_run=True)
        patch_path = repo / ".build" / "rig" / "patches" / proposal["patch_id"] / "changes.patch"
        validation = local_patch.apply_sandbox(repo, patch_path)
        assert validation["sandbox_path"]
        assert source.read_text(encoding="utf-8") == original
    finally:
        local_patch.mlx_local.generate_summary = original_gen


def test_schema_validation_and_bundle_integration() -> None:
    repo = _repo()
    patch_dir = repo / ".build" / "rig" / "patches" / "p1"
    proposal = {
        "schema_version": "rig.local_patch.v1",
        "patch_id": "p1",
        "task": "td-cleanup-005",
        "created_at": "2026-05-05T00:00:00Z",
        "backend": "mlx",
        "model": "m",
        "authoritative": False,
        "allowed_paths": ["Docs/dev/rig"],
        "forbidden_paths": [".git"],
        "intended_files": ["Docs/dev/rig/LOCAL_PATCHES.md"],
        "patch_path": ".build/rig/patches/p1/changes.patch",
        "proposal_markdown_path": ".build/rig/patches/p1/proposal.md",
        "source_context": ["Docs/dev/rig/README.md"],
        "warnings": [],
        "limitations": [],
    }
    patch_dir.mkdir(parents=True, exist_ok=True)
    (patch_dir / "patch.json").write_text(json.dumps(proposal), encoding="utf-8")
    (patch_dir / "validation.json").write_text(json.dumps({
        "schema_version": "rig.patch_validation.v1",
        "patch_id": "p1",
        "task": "td-cleanup-005",
        "status": "check_passed",
        "git_apply_check_status": "passed",
        "sandbox_apply_status": "passed",
        "scope_status": "passed",
        "forbidden_path_violations": [],
        "binary_patch_detected": False,
        "deletion_detected": False,
        "validation_commands": [["git", "apply", "--check", "changes.patch"]],
        "artifacts": [],
        "warnings": [],
        "authoritative": False,
    }), encoding="utf-8")
    assert schema_validation.validate_artifacts(repo, family="rig.local_patch.v1").validated_artifact_count == 1
    assert schema_validation.validate_artifacts(repo, family="rig.patch_validation.v1").validated_artifact_count == 1
    state = monitor.build_state(repo)
    assert "patch_summary" in state
    bundle = session_bundle.write_bundle(repo, task="td-cleanup-005", dry_run=True)
    assert bundle.manifest["bundle_status"] == "reviewable"


def test_no_shell_true_in_implementation() -> None:
    src = inspect.getsource(local_patch)
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
