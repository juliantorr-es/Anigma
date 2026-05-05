#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import subprocess


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def normalize_status(status: str | None) -> str:
    value = (status or "").strip().lower()
    if value in {"passed", "pass", "ok", "success", "succeeded", "clean"}:
        return "passed"
    if value in {"failed", "fail", "error", "errored"}:
        return "failed"
    if value in {"known_blocked", "known-blocked", "blocked"}:
        return "known_blocked"
    if value in {"skipped", "skip"}:
        return "skipped"
    return "failed"


def stable_json_dumps(data) -> str:
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False)


def write_json_stable(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(stable_json_dumps(data) + "\n", encoding="utf-8")


def artifact_record(path: str | Path, kind: str | None = None, note: str | None = None) -> dict:
    return {
        "path": str(path),
        "kind": kind or "artifact",
        "note": note,
    }


def stable_id(*parts: str) -> str:
    h = hashlib.sha256()
    for part in parts:
        h.update(part.encode("utf-8"))
        h.update(b"\0")
    return h.hexdigest()


def create_step_result(
    *,
    run_id: str,
    task_id: str,
    profile: str,
    step_id: str,
    command: str,
    exit_code: int,
    status: str,
    started_at: str,
    finished_at: str,
    duration_seconds: float,
    stdout_log: str,
    stderr_log: str,
    artifacts: list[dict] | None = None,
    matched_known_blocker: dict | None = None,
) -> dict:
    return {
        "schema": "anigma.pipeline.step_result.v1",
        "run_id": run_id,
        "task_id": task_id,
        "profile": profile,
        "step_id": step_id,
        "command": command,
        "exit_code": exit_code,
        "status": normalize_status(status),
        "started_at": started_at,
        "finished_at": finished_at,
        "duration_seconds": round(float(duration_seconds), 3),
        "stdout_log": stdout_log,
        "stderr_log": stderr_log,
        "artifacts": artifacts or [],
        "matched_known_blocker": matched_known_blocker,
    }


def create_run_manifest(
    *,
    run_id: str,
    task_id: str,
    profile: str,
    target: str | None,
    started_at: str,
    finished_at: str | None = None,
    status: str = "passed",
    steps: list[dict] | None = None,
    artifacts: list[dict] | None = None,
    summary: dict | None = None,
    changed_files: list[str] | None = None,
    in_scope: bool | None = None,
    scope_violations: list[str] | None = None,
    known_blockers: list[dict] | None = None,
    git: dict | None = None,
) -> dict:
    return {
        "schema": "anigma.pipeline.run_manifest.v1",
        "run_id": run_id,
        "task_id": task_id,
        "profile": profile,
        "target": target,
        "started_at": started_at,
        "finished_at": finished_at,
        "status": normalize_status(status),
        "steps": steps or [],
        "artifacts": artifacts or [],
        "summary": summary or {},
        "changed_files": changed_files or [],
        "in_scope": in_scope,
        "scope_violations": scope_violations or [],
        "known_blockers": known_blockers or [],
        "git": git or {},
    }


def git_cmd(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )


def collect_git_metadata(repo_root: Path, changed_files: list[str] | None = None) -> dict:
    branch = git_cmd("rev-parse", "--abbrev-ref", "HEAD", cwd=repo_root)
    head = git_cmd("rev-parse", "HEAD", cwd=repo_root)
    status = git_cmd("status", "--porcelain=v1", cwd=repo_root)
    if status.returncode != 0 or head.returncode != 0 or branch.returncode != 0:
        return {"available": False}
    lines = [line.rstrip("\n") for line in status.stdout.splitlines() if line.strip()]
    staged = []
    unstaged = []
    untracked = []
    for line in lines:
        code = line[:2]
        file_path = line[3:].strip()
        if code == "??":
            untracked.append(file_path)
        else:
            if code[0] != " ":
                staged.append(file_path)
            if code[1] != " ":
                unstaged.append(file_path)
    changed = changed_files if changed_files is not None else sorted(set(staged + unstaged + untracked))
    return {
        "available": True,
        "branch": branch.stdout.strip(),
        "head": head.stdout.strip(),
        "dirty": bool(lines),
        "staged_files": sorted(set(staged)),
        "unstaged_files": sorted(set(unstaged)),
        "untracked_files": sorted(set(untracked)),
        "changed_files": sorted(set(changed)),
    }
