#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import uuid
import zipfile
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.anigma_result_contract import artifact_record, collect_git_metadata, create_run_manifest, create_step_result, normalize_status, stable_id, utc_now, write_json_stable

REPO_ROOT = Path(__file__).resolve().parents[1]
PIPELINE_ROOT = REPO_ROOT / ".build" / "anigma-pipeline" / "runs"
PROFILES_DIR = REPO_ROOT / "Docs" / "pipeline" / "profiles"
BLOCKERS_FILE = REPO_ROOT / "Docs" / "build" / "known-blockers.yaml"

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None


def parse_scalar(value: str):
    value = value.strip()
    if value in {"true", "True"}:
        return True
    if value in {"false", "False"}:
        return False
    if value in {"null", "Null", "None", "~"}:
        return None
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [parse_scalar(part.strip().strip("'\"")) for part in inner.split(",")]
    if (value.startswith("'") and value.endswith("'")) or (value.startswith('"') and value.endswith('"')):
        return value[1:-1]
    try:
        if "." in value:
            return float(value)
        return int(value)
    except ValueError:
        return value


def parse_yaml_minimal(text: str):
    lines = [line.rstrip() for line in text.splitlines() if line.strip() and not line.lstrip().startswith("#")]
    root = {}
    stack = [(-1, root, None)]

    def push(level, container, key=None):
        stack.append((level, container, key))

    def current():
        return stack[-1][1]

    i = 0
    while i < len(lines):
        line = lines[i]
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()
        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = current()
        if stripped.startswith("- "):
            item_text = stripped[2:]
            if not isinstance(parent, list):
                raise ValueError("list item without list parent")
            if ":" in item_text and not item_text.endswith(":"):
                key, val = item_text.split(":", 1)
                item = {key.strip(): parse_scalar(val.strip())}
                parent.append(item)
            else:
                parent.append(parse_scalar(item_text))
            i += 1
            continue
        if ":" in stripped:
            key, val = stripped.split(":", 1)
            key = key.strip()
            val = val.strip()
            if val == "":
                nxt = None
                j = i + 1
                while j < len(lines):
                    nl = lines[j]
                    nindent = len(nl) - len(nl.lstrip(" "))
                    nstrip = nl.strip()
                    if nstrip and not nstrip.startswith("#"):
                        nxt = nstrip
                        break
                    j += 1
                if nxt is not None and nxt.startswith("- "):
                    container = []
                else:
                    container = {}
                if isinstance(parent, dict):
                    parent[key] = container
                else:
                    parent.append({key: container})
                push(indent, container, key)
            else:
                if isinstance(parent, dict):
                    parent[key] = parse_scalar(val)
                else:
                    parent.append({key: parse_scalar(val)})
        i += 1
    return root


def load_yaml(path: Path) -> dict:
    if yaml is not None:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return parse_yaml_minimal(path.read_text(encoding="utf-8"))


def load_blockers() -> list[dict]:
    if not BLOCKERS_FILE.exists():
        return []
    data = load_yaml(BLOCKERS_FILE)
    return data.get("blockers", []) if isinstance(data, dict) else []


def match_known_blocker(command: str, exit_code: int, blockers: list[dict]) -> dict | None:
    for blocker in blockers:
        if blocker.get("status") not in {"open", "active", True}:
            continue
        cmd = str(blocker.get("command") or "")
        sigs = blocker.get("signature") or []
        if cmd and cmd in command:
            return blocker
        if any(sig and sig in command for sig in sigs):
            return blocker
        if blocker.get("exit_code") is not None and blocker.get("exit_code") == exit_code:
            return blocker
    return None


def expand(text: str, task: str, target: str | None) -> str:
    return (
        text.replace("{task}", task)
        .replace("{target}", target or "")
        .replace("{repo_root}", str(REPO_ROOT))
    )


def step_shell(command: str, cwd: Path, stdout_path: Path, stderr_path: Path) -> tuple[int, float]:
    start = datetime.now(timezone.utc)
    proc = subprocess.run(command, cwd=cwd, shell=True, text=True, capture_output=True, executable="/bin/zsh")
    stdout_path.write_text(proc.stdout or "", encoding="utf-8")
    stderr_path.write_text(proc.stderr or "", encoding="utf-8")
    duration = (datetime.now(timezone.utc) - start).total_seconds()
    return proc.returncode, duration


def sha256_path(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def latest_run_dir(task: str) -> Path | None:
    task_dir = PIPELINE_ROOT / task
    if not task_dir.exists():
        return None
    runs = [p for p in task_dir.iterdir() if p.is_dir()]
    return max(runs, key=lambda p: p.stat().st_mtime) if runs else None


def latest_profile_run_dir(task: str, preferred_profile: str = "cleanup-review") -> Path | None:
    task_dir = PIPELINE_ROOT / task
    if not task_dir.exists():
        return None
    matches = []
    for run in task_dir.iterdir():
        manifest = run / "manifest.json"
        if not run.is_dir() or not manifest.exists():
            continue
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
        except Exception:
            continue
        matches.append((run, data.get("profile")))
    preferred = [run for run, profile in matches if profile == preferred_profile]
    if preferred:
        return max(preferred, key=lambda p: p.stat().st_mtime)
    all_runs = [run for run, _ in matches]
    return max(all_runs, key=lambda p: p.stat().st_mtime) if all_runs else None


def extract_scoped_paths(task: str) -> set[str]:
    paths: set[str] = set()
    for source in [
        REPO_ROOT / "Docs" / "td" / "briefs" / f"{task}-batch-003-ipc-ownership.md",
        REPO_ROOT / "Docs" / "proofs" / f"{task}-batch-003-ipc-ownership.md",
        REPO_ROOT / "Docs" / "proofs" / f"{task}.md",
        REPO_ROOT / "Docs" / "proofs" / "context-pipeline-audit-normalization-2026-05-05.md",
    ]:
        if not source.exists():
            continue
        text = source.read_text(encoding="utf-8")
        for match in __import__("re").findall(r"anigma/[A-Za-z0-9_./-]+", text):
            paths.add(match)
    return paths


def git_untracked_files() -> list[str]:
    res = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=REPO_ROOT, text=True, capture_output=True, check=False)
    return sorted(line.strip() for line in res.stdout.splitlines() if line.strip()) if res.returncode == 0 else []


def no_index_patch_for(path: Path) -> str:
    rel = str(path.relative_to(REPO_ROOT))
    content = path.read_text(encoding="utf-8").splitlines()
    lines = [f"diff --git a/{rel} b/{rel}", "new file mode 100644", "--- /dev/null", f"+++ b/{rel}", "@@"]
    for line in content:
        lines.append(f"+{line}")
    return "\n".join(lines) + "\n"


def collect_bundle_sources(task: str, run_dir: Path) -> tuple[list[Path], list[str], set[str]]:
    included: list[Path] = []
    omitted: list[str] = []
    scoped_paths = extract_scoped_paths(task)
    candidates = [
        run_dir / "manifest.json",
        run_dir / "summary.md",
        run_dir / "step-results",
        run_dir / "logs",
        REPO_ROOT / "Docs" / "td" / "briefs",
        REPO_ROOT / "Docs" / "proofs",
        REPO_ROOT / "Docs" / "atlas" / "risk-index.json",
        REPO_ROOT / "Docs" / "atlas" / "targets.json",
        REPO_ROOT / "Docs" / "atlas" / "entrypoints.json",
        REPO_ROOT / ".build" / "anigma-dead-code-audit.json",
        REPO_ROOT / ".build" / "anigma-executable-consolidation-audit.json",
    ]
    task_tokens = [task, task.replace("td-", "")]
    for candidate in candidates:
        if not candidate.exists():
            omitted.append(str(candidate.relative_to(REPO_ROOT)))
            continue
        if candidate.is_file():
            included.append(candidate)
            continue
        if candidate.is_dir():
            for path in sorted(candidate.rglob("*")):
                if not path.is_file():
                    continue
                rel = str(path.relative_to(REPO_ROOT))
                if rel.startswith(".git/") or "/.git/" in rel or rel.startswith(".build/review-bundles/"):
                    continue
                if path.name == ".DS_Store" or path.name.endswith(".pyc") or "__pycache__" in path.parts:
                    continue
                if rel.startswith("DerivedData/") or "/DerivedData/" in rel:
                    continue
                if candidate.name == "briefs" or candidate.name == "proofs":
                    if not any(token in path.name or token in str(path) for token in task_tokens):
                        continue
                included.append(path)
    for rel in git_untracked_files():
        path = REPO_ROOT / rel
        if not path.exists():
            continue
        if scoped_paths and rel not in scoped_paths and not any(rel.startswith(sp.rstrip("/") + "/") for sp in scoped_paths):
            continue
        included.append(path)
    return sorted(set(included)), sorted(set(omitted)), scoped_paths


def write_zip_deterministic(zip_path: Path, files: list[tuple[Path, str]]) -> None:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    fixed = (2020, 1, 1, 0, 0, 0)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for src, arc in files:
            zi = zipfile.ZipInfo(arc, date_time=fixed)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zf.writestr(zi, src.read_bytes())


def build_bundle(task: str, run_dir: Path, out: Path | None = None) -> tuple[Path, dict]:
    bundle_root = REPO_ROOT / ".build" / "review-bundles"
    bundle_root.mkdir(parents=True, exist_ok=True)
    if out is None:
        out = bundle_root / f"{task}-review.zip"
    included, omitted, scoped_paths = collect_bundle_sources(task, run_dir)
    manifest = {}
    run_profile = None
    run_scope_status = None
    run_changed_files: list[str] = []
    if (run_dir / "manifest.json").exists():
        manifest = json.loads((run_dir / "manifest.json").read_text(encoding="utf-8"))
        run_profile = manifest.get("profile")
        run_scope_status = manifest.get("git", {}).get("scope_status")
        run_changed_files = manifest.get("git", {}).get("changed_files", [])
    task_scoped_changed = [p for p in run_changed_files if p in scoped_paths or any(p.startswith(sp.rstrip("/") + "/") for sp in scoped_paths)]
    out_of_scope = [p for p in run_changed_files if p not in task_scoped_changed]
    bundle_manifest = {
        "task": task,
        "run_id": run_dir.name,
        "created_by": "anigma_pipeline.py",
        "source_run_dir": str(run_dir.relative_to(REPO_ROOT)),
        "source_run_profile": run_profile,
        "included_files": [],
        "omitted_optional_files": omitted,
        "generated_patch": False,
        "production_source_changed": manifest.get("git", {}).get("production_source_changed"),
        "scope_status": run_scope_status or "not_checked",
        "review_status": "reviewable_as_task_scoped_bundle" if run_scope_status == "passed" else "not_reviewable_as_task_scoped_bundle",
        "changed_file_count": len(run_changed_files),
        "task_scoped_changed_file_count": len(task_scoped_changed),
        "out_of_scope_changed_files": sorted(set(out_of_scope)),
        "untracked_files": git_untracked_files(),
        "untracked_files_included": [],
        "review_profile_incomplete": run_profile != "cleanup-review",
        "missing_review_steps": [] if run_profile == "cleanup-review" else ["dead-code gate", "executable-consolidation gate", "scope validation", "build"],
        "known_blockers": [],
    }
    bundle_manifest["known_blockers"] = manifest.get("known_blockers", [])
    changes_patch = run_dir / "changes.patch"
    diff = subprocess.run(["git", "diff"], cwd=REPO_ROOT, text=True, capture_output=True, check=False)
    changes_patch.write_text(diff.stdout or "", encoding="utf-8")
    included.append(changes_patch)
    bundle_manifest["generated_patch"] = True
    task_patch = run_dir / "task-scoped-changes.patch"
    task_patch_lines = []
    task_patch_lines.append(diff.stdout or "")
    task_patch_lines.append("")
    for rel in sorted(set(run_changed_files)):
        if task_scoped_changed and rel not in task_scoped_changed and not any(rel.startswith(sp.rstrip("/") + "/") for sp in scoped_paths):
            continue
        path = REPO_ROOT / rel
        if path.exists() and path.is_file():
            if rel in git_untracked_files():
                task_patch_lines.append(no_index_patch_for(path))
                bundle_manifest["untracked_files_included"].append(rel)
    task_patch.write_text("\n".join(task_patch_lines).rstrip() + "\n", encoding="utf-8")
    included.append(task_patch)
    if bundle_manifest["untracked_files_included"]:
        bundle_manifest["untracked_files_included"] = sorted(set(bundle_manifest["untracked_files_included"]))
    # Add raw untracked file contents for review extraction.
    untracked_root = run_dir / "untracked-files"
    untracked_manifest = []
    for rel in bundle_manifest["untracked_files_included"]:
        src = REPO_ROOT / rel
        dst = untracked_root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
        included.append(dst)
        untracked_manifest.append({"path": rel, "sha256": sha256_path(src)})
    if untracked_manifest:
        write_json_stable(run_dir / "untracked-files-manifest.json", {"files": sorted(untracked_manifest, key=lambda x: x["path"])})
    files_for_zip: list[tuple[Path, str]] = []
    for path in sorted(set(included), key=lambda p: str(p.relative_to(REPO_ROOT))):
        rel = str(path.relative_to(REPO_ROOT))
        bundle_manifest["included_files"].append({
            "source": rel,
            "destination": rel,
            "sha256": sha256_path(path),
        })
        files_for_zip.append((path, rel))
    bundle_manifest["included_files"] = sorted(bundle_manifest["included_files"], key=lambda x: x["destination"])
    manifest_path = run_dir / "bundle-manifest.json"
    write_json_stable(manifest_path, bundle_manifest)
    files_for_zip.append((manifest_path, "bundle-manifest.json"))
    write_zip_deterministic(out, files_for_zip)
    return out, bundle_manifest


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    run = sub.add_parser("run")
    run.add_argument("--profile", required=True)
    run.add_argument("--task", required=True)
    run.add_argument("--target")
    bundle = sub.add_parser("bundle")
    bundle.add_argument("--task", required=True)
    bundle.add_argument("--latest-run", action="store_true")
    bundle.add_argument("--run-id")
    bundle.add_argument("--out")
    args = ap.parse_args()
    if args.cmd == "bundle":
        run_dir = None
        if args.run_id:
            run_dir = PIPELINE_ROOT / args.task / args.run_id
        elif args.latest_run:
            run_dir = latest_profile_run_dir(args.task)
        if not run_dir or not run_dir.exists():
            print("missing pipeline run", file=sys.stderr)
            return 2
        out, manifest = build_bundle(args.task, run_dir, Path(args.out) if args.out else None)
        print(str(out.relative_to(REPO_ROOT)))
        return 0
    if args.cmd != "run":
        return 2

    profile_path = PROFILES_DIR / f"{args.profile}.yaml"
    if not profile_path.exists():
        print(f"Missing profile: {profile_path}", file=sys.stderr)
        return 2
    profile = load_yaml(profile_path)
    steps = profile.get("steps", [])
    run_id = f"{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{uuid.uuid4().hex[:8]}"
    run_dir = PIPELINE_ROOT / args.task / run_id
    logs_dir = run_dir / "logs"
    results_dir = run_dir / "step-results"
    artifacts_dir = run_dir / "artifacts"
    for d in (logs_dir, results_dir, artifacts_dir):
        d.mkdir(parents=True, exist_ok=True)

    blockers = load_blockers()
    step_results = []
    run_status = "passed"
    known_blockers = []
    scope_violations = []
    changed_files = []

    for step in steps:
        step_id = step["id"]
        command = expand(step.get("command", ""), args.task, args.target)
        stdout_path = logs_dir / f"{step_id}.stdout.log"
        stderr_path = logs_dir / f"{step_id}.stderr.log"
        started_at = utc_now()
        exit_code, duration = step_shell(command, REPO_ROOT, stdout_path, stderr_path)
        finished_at = utc_now()
        blocker = match_known_blocker(command, exit_code, blockers) if exit_code != 0 else None
        status = "passed" if exit_code == 0 else "known_blocked" if blocker else "failed"
        if blocker:
            known_blockers.append(blocker)
        if "anigma_validate_scope.py" in command:
            changed_files = subprocess.run(["git", "diff", "--name-only"], cwd=REPO_ROOT, text=True, capture_output=True).stdout.splitlines()
            if exit_code != 0:
                scope_violations = [line for line in (stderr_path.read_text(encoding="utf-8").splitlines()) if line.strip()]
        result = create_step_result(
            run_id=run_id,
            task_id=args.task,
            profile=args.profile,
            step_id=step_id,
            command=command,
            exit_code=exit_code,
            status=status,
            started_at=started_at,
            finished_at=finished_at,
            duration_seconds=duration,
            stdout_log=str(stdout_path.relative_to(REPO_ROOT)),
            stderr_log=str(stderr_path.relative_to(REPO_ROOT)),
            artifacts=[artifact_record(stdout_path.relative_to(REPO_ROOT), "log"), artifact_record(stderr_path.relative_to(REPO_ROOT), "log")],
            matched_known_blocker=blocker,
        )
        write_json_stable(results_dir / f"{step_id}.json", result)
        step_results.append(result)
        if exit_code != 0 and step.get("required", True) and not (blocker and profile.get("continue_on_known_blocked_required")):
            run_status = status
            break
        if exit_code != 0 and not step.get("required", True):
            run_status = run_status if run_status != "passed" else status

    manifest = create_run_manifest(
        run_id=run_id,
        task_id=args.task,
        profile=args.profile,
        target=args.target,
        started_at=step_results[0]["started_at"] if step_results else utc_now(),
        finished_at=utc_now(),
        status=run_status if step_results else "failed",
        steps=step_results,
        artifacts=[artifact_record(run_dir.relative_to(REPO_ROOT), "run_dir")],
        summary={"step_count": len(step_results), "passed": sum(1 for s in step_results if s["status"] == "passed"), "failed": sum(1 for s in step_results if s["status"] == "failed"), "known_blocked": sum(1 for s in step_results if s["status"] == "known_blocked")},
        changed_files=changed_files,
        in_scope=not scope_violations if changed_files else None,
        scope_violations=scope_violations,
        known_blockers=known_blockers,
        git={**collect_git_metadata(REPO_ROOT, changed_files=changed_files or None), "scope_status": "failed" if scope_violations else ("passed" if changed_files is not None else None)},
    )
    write_json_stable(run_dir / "manifest.json", manifest)
    summary = [
        f"# Pipeline Run: {args.profile}",
        "",
        f"- task: `{args.task}`",
        f"- target: `{args.target or ''}`",
        f"- status: `{manifest['status']}`",
        f"- steps: `{len(step_results)}`",
        f"- known blockers: `{len(known_blockers)}`",
        f"- scope violations: `{len(scope_violations)}`",
        "",
        "## Steps",
    ]
    for s in step_results:
        summary.append(f"- `{s['step_id']}`: `{s['status']}` (exit `{s['exit_code']}`)")
    (run_dir / "summary.md").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(str(run_dir.relative_to(REPO_ROOT)))
    return 0 if manifest["status"] in {"passed", "known_blocked"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
