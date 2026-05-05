#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Scripts"))

from rig_tools import git_manage
from rig_tools.result_index import build_registry_rows
from rig_tools.schema_validation import validate_artifacts


def test_commit_message_deterministic():
    msg = git_manage.generate_commit_message(
        "td-cleanup-005",
        ["Docs/proofs/a.md", "Scripts/x.py"],
        {"path": "Docs/proofs/a.md"},
        {"status": "pass", "report_path": "x"},
        {"status": "passed", "command_group": "docs"},
        {"status": "pass"},
    )
    assert msg.startswith("docs(rig): task td-cleanup-005")
    assert "Registry gate: pass" in msg


def test_plan_blocks_for_forbidden_and_missing_proof():
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        (repo / "anigma" / "Packages" / "AnigmaDaemonCore").mkdir(parents=True, exist_ok=True)
        (repo / "Docs" / "governance").mkdir(parents=True, exist_ok=True)
        (repo / "Scripts").mkdir(parents=True, exist_ok=True)
        (repo / ".git").mkdir(parents=True, exist_ok=True)
        (repo / ".git" / "HEAD").write_text("ref: refs/heads/main\n", encoding="utf-8")
        (repo / ".git" / "refs" / "heads").mkdir(parents=True, exist_ok=True)
        (repo / ".git" / "refs" / "heads" / "main").write_text("deadbeef\n", encoding="utf-8")
        def fake_collect(_repo):
            return {
                "available": True,
                "branch": "main",
                "head": "deadbeef",
                "dirty": True,
                "staged_files": [],
                "unstaged_files": ["anigma/Packages/AnigmaDaemonCore/file.swift"],
                "untracked_files": [],
                "changed_files": ["anigma/Packages/AnigmaDaemonCore/file.swift"],
                "categories": {"production_source": 1},
                "production_source_changed": True,
                "baseline_files_changed": [],
                "proof_files_changed": [],
            }
        orig = git_manage.collect_status
        git_manage.collect_status = fake_collect  # type: ignore[assignment]
        try:
            plan = git_manage.plan_commit(repo, "td-cleanup-005", allowed_paths=["anigma/Packages/AnigmaDaemonCore"])
            assert plan["status"] == "blocked"
            assert "production source changed without proof artifact" in plan["blocking_reasons"]
        finally:
            git_manage.collect_status = orig  # type: ignore[assignment]


def test_stage_and_commit_refuse_without_confirm():
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        plan = {"included_files": ["Docs/proofs/x.md"], "commit_message": "chore(cleanup): task"}
        stage = git_manage.stage_from_plan(repo, plan, confirm=False)
        commit = git_manage.commit_from_plan(repo, plan, confirm=False)
        assert stage.returncode == 5
        assert commit.returncode == 5


def test_commit_refuses_when_head_changes():
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        orig = git_manage.collect_status
        git_manage.collect_status = lambda _repo: {  # type: ignore[assignment]
            "head": "aaa",
            "changed_files": ["Docs/proofs/x.md"],
            "staged_files": [],
            "unstaged_files": [],
            "untracked_files": [],
            "dirty": True,
        }
        try:
            plan = {"included_files": ["Docs/proofs/x.md"], "head": "bbb", "commit_message": "docs(rig): task demo"}
            res = git_manage.commit_from_plan(repo, plan, confirm=True)
            assert res.returncode == 4
        finally:
            git_manage.collect_status = orig  # type: ignore[assignment]


def test_registry_gate_ingests_into_rows():
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        p = repo / ".build" / "anigma-diagnostics" / "tasks" / "task1" / "run1" / "validate" / "logs"
        p.mkdir(parents=True, exist_ok=True)
        (p / "validator-registry-check.json").write_text(json.dumps({"status": "pass", "exitCode": 0, "failureCount": 0, "warningCount": 0}), encoding="utf-8")
        (p / "validator-registry-check.log").write_text("ok", encoding="utf-8")
        rows = build_registry_rows(repo)
        assert len(rows) == 1
        assert rows[0]["phase"] == "validate"


def test_commit_plan_schema_validation():
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        plan_dir = repo / ".build" / "rig" / "git"
        schema_dir = repo / "Docs" / "schemas"
        schema_dir.mkdir(parents=True, exist_ok=True)
        source_schema = Path(__file__).resolve().parents[1] / "Docs" / "schemas" / "rig.git_commit_plan.v1.schema.json"
        (schema_dir / "rig.git_commit_plan.v1.schema.json").write_text(source_schema.read_text(encoding="utf-8"), encoding="utf-8")
        plan_dir.mkdir(parents=True, exist_ok=True)
        plan = {
            "schema_version": "rig.git_commit_plan.v1",
            "task": "demo",
            "generated_at": "2026-05-05T00:00:00Z",
            "branch": "main",
            "head": "deadbeef",
            "dirty": False,
            "staged_files": [],
            "unstaged_files": [],
            "untracked_files": [],
            "included_files": [],
            "excluded_files": [],
            "forbidden_files": [],
            "scope_status": "passed",
            "validation_status": "passed",
            "schema_status": "passed",
            "registry_gate_status": "pass",
            "known_blockers": [],
            "baselines_changed": False,
            "production_source_changed": False,
            "proof_artifact": None,
            "review_bundle": None,
            "commit_message": "chore(cleanup): task demo",
            "blocking_reasons": [],
            "status": "needs_confirmation",
        }
        path = plan_dir / "commit-plan-demo.json"
        path.write_text(json.dumps(plan), encoding="utf-8")
        summary = validate_artifacts(repo, artifact_path=str(path.relative_to(repo)))
        assert summary.failed_count == 0


def test_no_shell_true_in_git_management():
    text = (Path(__file__).resolve().parent / "rig_tools" / "git_manage.py").read_text(encoding="utf-8")
    assert "shell=True" not in text


if __name__ == "__main__":
    test_commit_message_deterministic()
    test_plan_blocks_for_forbidden_and_missing_proof()
    test_stage_and_commit_refuse_without_confirm()
    test_commit_refuses_when_head_changes()
    test_registry_gate_ingests_into_rows()
    test_commit_plan_schema_validation()
    test_no_shell_true_in_git_management()
    print("git_manage tests passed")
