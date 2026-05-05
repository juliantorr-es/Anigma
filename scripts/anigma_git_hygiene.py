#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.anigma_result_contract import collect_git_metadata, stable_json_dumps
from scripts.anigma_validate_scope import validate_scope

REPO_ROOT = Path(__file__).resolve().parents[1]


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def inside_repo() -> bool:
    res = git("rev-parse", "--is-inside-work-tree")
    return res.returncode == 0 and res.stdout.strip() == "true"


def parse_porcelain(lines: list[str]) -> dict:
    staged, unstaged, untracked = [], [], []
    for line in lines:
        if not line.strip():
            continue
        code = line[:2]
        path = line[3:].strip()
        if code == "??":
            untracked.append(path)
        else:
            if code[0] != " ":
                staged.append(path)
            if code[1] != " ":
                unstaged.append(path)
    changed = sorted(set(staged + unstaged + untracked))
    return {
        "staged_files": sorted(set(staged)),
        "unstaged_files": sorted(set(unstaged)),
        "untracked_files": sorted(set(untracked)),
        "changed_files": changed,
        "dirty": bool(lines),
    }


def classify(path: str) -> str:
    p = Path(path)
    s = path.lower()
    if s.startswith("docs/atlas/") or s.startswith(".build/anigma-") or s.startswith(".build/anigma-pipeline/"):
        return "atlas" if "atlas" in s else "generated_or_build"
    if s.startswith("docs/pipeline/") or s.startswith("docs/git/"):
        return "pipeline"
    if s.startswith("docs/proofs/"):
        return "proofs"
    if s.startswith("docs/baselines/") or s.startswith(".build/"):
        return "baselines" if s.startswith("docs/baselines/") else "generated_or_build"
    if s.startswith("docs/"):
        return "docs"
    if s.startswith("scripts/"):
        return "scripts"
    if s.startswith("anigma/") and (p.suffix in {".swift", ".c", ".cc", ".cpp", ".cxx", ".h", ".hpp", ".m", ".mm", ".metal"} or "sources/" in s or "packages/" in s):
        return "production_source"
    return "unknown"


def status_payload() -> dict:
    meta = collect_git_metadata(REPO_ROOT)
    if not meta.get("available"):
        return meta
    changed = meta["changed_files"]
    categories = Counter(classify(path) for path in changed)
    return {
        **meta,
        "baseline_files_changed": [p for p in changed if p.startswith("Docs/baselines/")],
        "production_source_changed": any(classify(p) == "production_source" for p in changed),
        "proof_files_changed": [p for p in changed if p.startswith("Docs/proofs/")],
        "generated_or_build_files_changed": [p for p in changed if classify(p) == "generated_or_build"],
        "categories": dict(sorted(categories.items())),
    }


def diff_summary_payload(changed_files: list[str] | None = None) -> dict:
    meta = collect_git_metadata(REPO_ROOT, changed_files=changed_files)
    if not meta.get("available"):
        return meta
    cats = Counter(classify(path) for path in meta["changed_files"])
    return {
        "available": True,
        "task": None,
        "changed_files": meta["changed_files"],
        "categories": dict(sorted(cats.items())),
        "summary": {
            "production_source": cats.get("production_source", 0),
            "scripts": cats.get("scripts", 0),
            "docs": cats.get("docs", 0),
            "proofs": cats.get("proofs", 0),
            "baselines": cats.get("baselines", 0),
            "atlas": cats.get("atlas", 0),
            "pipeline": cats.get("pipeline", 0),
            "generated_or_build": cats.get("generated_or_build", 0),
            "unknown": cats.get("unknown", 0),
        },
    }


def commit_message(task: str, changed_files: list[str]) -> str:
    scope_bits = []
    if any(classify(p) == "production_source" for p in changed_files):
        scope_bits.append("align production source")
    if any(p.startswith("Docs/proofs/") for p in changed_files):
        scope_bits.append("update proof")
    if any(p.startswith("Docs/atlas/") for p in changed_files):
        scope_bits.append("refresh atlas")
    if any(p.startswith("Docs/baselines/") for p in changed_files):
        scope_bits.append("reconcile baselines")
    if not scope_bits:
        scope_bits.append("pipeline and docs")
    return f"{task}: " + ", ".join(scope_bits)


def precommit(task: str, allowed: list[str], forbidden: list[str]) -> dict:
    meta = status_payload()
    if not meta.get("available"):
        return meta
    scope_ok, violations = validate_scope(meta["changed_files"], allowed, forbidden)
    result = {
        "status": "passed" if scope_ok else "failed",
        "branch": meta["branch"],
        "head": meta["head"],
        "dirty": meta["dirty"],
        "changed_files": meta["changed_files"],
        "scope_ok": scope_ok,
        "scope_violations": violations,
        "baseline_files_changed": meta["baseline_files_changed"],
        "production_source_changed": meta["production_source_changed"],
        "proof_files_changed": meta["proof_files_changed"],
    }
    return result


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    p_scope = sub.add_parser("scope")
    p_scope.add_argument("--task", required=True)
    p_scope.add_argument("--allowed-path", action="append", default=[])
    p_scope.add_argument("--forbidden-path", action="append", default=[])
    p_scope.add_argument("--changed-file", action="append", default=[])
    p_diff = sub.add_parser("diff-summary")
    p_diff.add_argument("--task", required=True)
    p_pre = sub.add_parser("precommit")
    p_pre.add_argument("--task", required=True)
    p_pre.add_argument("--allowed-path", action="append", default=["scripts", "Docs"])
    p_pre.add_argument("--forbidden-path", action="append", default=[])
    p_pre.add_argument("--changed-file", action="append", default=[])
    p_commit = sub.add_parser("commit-message")
    p_commit.add_argument("--task", required=True)
    args = ap.parse_args()

    if not inside_repo():
        print("not a git repository", file=sys.stderr)
        return 2

    if args.cmd == "status":
        data = status_payload()
        if not data.get("available"):
            print("not a git repository", file=sys.stderr)
            return 2
        print(stable_json_dumps(data))
        print(f"branch: {data['branch']}")
        print(f"head: {data['head']}")
        print(f"dirty: {data['dirty']}")
        print(f"changed_files: {len(data['changed_files'])}")
        return 0

    if args.cmd == "scope":
        if args.changed_file:
            files = args.changed_file
        else:
            meta = collect_git_metadata(REPO_ROOT)
            files = meta["changed_files"] if meta.get("available") else []
        ok, violations = validate_scope(files, args.allowed_path, args.forbidden_path)
        data = {"task": args.task, "status": "passed" if ok else "failed", "changed_files": files, "violations": violations}
        print(stable_json_dumps(data))
        return 0 if ok else 1

    if args.cmd == "diff-summary":
        data = diff_summary_payload()
        print(stable_json_dumps(data))
        print("summary:")
        for k, v in data["summary"].items():
            print(f"- {k}: {v}")
        return 0

    if args.cmd == "precommit":
        if args.changed_file:
            meta = {"changed_files": args.changed_file, **status_payload()}
            ok, violations = validate_scope(args.changed_file, args.allowed_path, args.forbidden_path)
            data = {
                "status": "passed" if ok else "failed",
                "branch": meta.get("branch"),
                "head": meta.get("head"),
                "dirty": meta.get("dirty"),
                "changed_files": args.changed_file,
                "scope_ok": ok,
                "scope_violations": violations,
                "baseline_files_changed": [p for p in args.changed_file if p.startswith("Docs/baselines/")],
                "production_source_changed": any(classify(p) == "production_source" for p in args.changed_file),
                "proof_files_changed": [p for p in args.changed_file if p.startswith("Docs/proofs/")],
            }
        else:
            data = precommit(args.task, args.allowed_path, args.forbidden_path)
        print(stable_json_dumps(data))
        return 0 if data.get("status") == "passed" else 1

    if args.cmd == "commit-message":
        changed = status_payload().get("changed_files", [])
        msg = commit_message(args.task, changed)
        print(msg)
        return 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
