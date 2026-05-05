#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(REPO_ROOT / "scripts" / "anigma_generate_task_brief.py"), *args],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )


def main() -> int:
    list_result = run("--list-templates")
    assert list_result.returncode == 0, list_result.stderr
    assert "cleanup_executable_consolidation" in list_result.stdout

    text_result = run(
        "--task",
        "td-cleanup-004",
        "--template",
        "cleanup_executable_consolidation",
        "--risk",
        "daemon_ipc_binding",
        "--target",
        "AnigmaDaemonCore",
        "--limit",
        "10",
    )
    assert text_result.returncode == 0, text_result.stderr
    assert "Task ID: td-cleanup-004" in text_result.stdout
    assert "Selected Findings" in text_result.stdout
    assert "--use-atlas" not in text_result.stdout
    assert "--json-out .build/anigma-executable-consolidation-audit.json" in text_result.stdout

    json_result = run(
        "--task",
        "td-cleanup-004",
        "--template",
        "cleanup_executable_consolidation",
        "--risk",
        "daemon_ipc_binding",
        "--target",
        "AnigmaDaemonCore",
        "--limit",
        "10",
        "--format",
        "json",
    )
    assert json_result.returncode == 0, json_result.stderr
    obj = json.loads(json_result.stdout)
    assert obj["task"] == "td-cleanup-004"
    assert obj["template"] == "cleanup_executable_consolidation"
    assert obj["selected_count"] == len(obj["findings"])
    assert obj["selected_count"] > 0

    write_path = REPO_ROOT / "Docs" / "td" / "briefs" / "td-cleanup-004-batch-003-ipc-ownership.md"
    write_path.parent.mkdir(parents=True, exist_ok=True)
    write_result = run(
        "--task",
        "td-cleanup-004",
        "--template",
        "cleanup_executable_consolidation",
        "--risk",
        "daemon_ipc_binding",
        "--target",
        "AnigmaDaemonCore",
        "--limit",
        "10",
        "--write",
        str(write_path),
    )
    assert write_result.returncode == 0, write_result.stderr
    assert write_path.exists()
    assert "Implement td-cleanup-004" in write_path.read_text(encoding="utf-8")
    assert "--use-atlas" not in write_path.read_text(encoding="utf-8")

    singleton_write_path = REPO_ROOT / "Docs" / "td" / "briefs" / "td-cleanup-005-batch-004-singleton-triage.md"
    singleton_result = run(
        "--task",
        "td-cleanup-005",
        "--template",
        "cleanup_singleton_triage",
        "--risk",
        "singleton_global_state",
        "--target",
        "AnigmaDaemonCore",
        "--limit",
        "10",
        "--write",
        str(singleton_write_path),
    )
    assert singleton_result.returncode == 0, singleton_result.stderr
    singleton_text = singleton_write_path.read_text(encoding="utf-8")
    assert "{{" not in singleton_text, singleton_text
    assert "remaining singleton_global_state findings" in singleton_text
    assert "Production Swift changes are allowed only for selected confirmed/likely singleton risks in AnigmaDaemonCore." in singleton_text
    assert "daemon_ipc_binding" not in singleton_text
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
