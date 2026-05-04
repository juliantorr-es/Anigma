#!/usr/bin/env python3
"""
Fold validated agent run receipts into Docs/td task memory.

This script writes curated durable memory only:
- memory.md
- timeline.yaml
- decisions.yaml

It does not ingest raw transcripts. It never changes task status by itself.

Usage:
  python3 scripts/td_docs_from_receipts.py receipt.yaml --apply
  python3 scripts/td_docs_from_receipts.py receipt.yaml --dry-run
"""

import argparse
import datetime as dt
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

import yaml

REPO_ROOT = Path(__file__).parent.parent.absolute()
REGISTRY_PATH = REPO_ROOT / "Docs" / "td" / "td-task-registry.yaml"
RECEIPT_VALIDATOR = REPO_ROOT / "scripts" / "agent_receipt_validate.py"


def load_yaml(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected YAML object")
    return data


def dump_yaml(path: Path, data: Dict[str, Any]) -> None:
    path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=False), encoding="utf-8")


def registry_parent(task_id: str) -> Optional[str]:
    registry = load_yaml(REGISTRY_PATH)
    for task in registry.get("tasks", []):
        if task.get("id") == task_id:
            return task.get("parent")
    return None


def find_task_dir(task_id: str) -> Path:
    td_dir = REPO_ROOT / "Docs" / "td"
    candidates = []
    for task_yaml in td_dir.glob(f"**/{task_id}/task.yaml"):
        candidates.append(task_yaml.parent)
    for epic_yaml in td_dir.glob(f"**/{task_id}/epic.yaml"):
        candidates.append(epic_yaml.parent)
    if len(candidates) == 1:
        return candidates[0]
    if not candidates:
        raise FileNotFoundError(f"could not find Docs/td directory for task_id={task_id}")
    raise RuntimeError(f"multiple Docs/td directories found for task_id={task_id}: {candidates}")


def validate_receipt(path: Path) -> None:
    result = subprocess.run(["python3", str(RECEIPT_VALIDATOR), str(path)], cwd=REPO_ROOT)
    if result.returncode != 0:
        raise RuntimeError(f"receipt validation failed: {path}")


def ensure_memory(path: Path) -> None:
    if not path.exists():
        path.write_text("# Agent Memory\n\nCurated run summaries folded from validated receipts.\n", encoding="utf-8")


def append_memory(task_dir: Path, receipt: Dict[str, Any]) -> None:
    memory_path = task_dir / "memory.md"
    ensure_memory(memory_path)
    verification = receipt.get("verification", [])
    decisions = receipt.get("decisions", [])
    blockers = receipt.get("blockers", [])
    section = [
        "",
        f"## {receipt['run_id']} ({receipt['agent']} {receipt['mode']})",
        "",
        f"- TD issue: `{receipt.get('td_issue') or 'unknown'}`",
        f"- Started: `{receipt['started_at']}`",
        f"- Ended: `{receipt['ended_at']}`",
        f"- Skills: {', '.join(receipt.get('skills', []))}",
        f"- Changed files: {', '.join(receipt.get('changed_files', [])) or 'none'}",
        f"- Proofs: {', '.join(receipt.get('proof_paths', [])) or 'none'}",
        "",
        "Done:",
        receipt["handoff"]["done"],
        "",
        "Remaining:",
        receipt["handoff"].get("remaining", ""),
        "",
        "Uncertain:",
        receipt["handoff"].get("uncertain", ""),
    ]
    if decisions:
        section.extend(["", "Decisions:"])
        section.extend(f"- {item}" for item in decisions)
    if blockers:
        section.extend(["", "Blockers:"])
        section.extend(f"- {item}" for item in blockers)
    if verification:
        section.extend(["", "Verification:"])
        section.extend(f"- `{item['command']}`: {item['result']} - {item.get('summary') or ''}" for item in verification)
    memory_path.write_text(memory_path.read_text(encoding="utf-8").rstrip() + "\n" + "\n".join(section) + "\n", encoding="utf-8")


def upsert_timeline(task_dir: Path, receipt: Dict[str, Any], parent: Optional[str]) -> None:
    path = task_dir / "timeline.yaml"
    if path.exists():
        data = load_yaml(path)
    else:
        data = {
            "version": "1.0.0",
            "last_updated": None,
            "task_id": receipt["task_id"],
            "epic_id": parent,
            "rollup_level": "task",
            "events": [],
        }
    events = data.setdefault("events", [])
    event_id = f"{receipt['run_id']}-{receipt['mode']}"
    if any(event.get("event_id") == event_id for event in events):
        return
    events.append({
        "event_id": event_id,
        "timestamp": receipt["ended_at"],
        "type": "review" if receipt["mode"] == "review" else "event",
        "summary": f"{receipt['agent']} {receipt['mode']} run: {receipt['handoff']['done']}",
        "task_id": receipt["task_id"],
        "epic_id": parent,
        "actor": f"agent-{receipt['agent']}",
        "evidence_paths": receipt.get("proof_paths", []),
        "affected_code": receipt.get("changed_files", []),
        "affected_docs": [path for path in receipt.get("changed_files", []) if path.startswith("Docs/")],
        "source": "agent-run-receipt",
        "status": "confirmed",
    })
    data["last_updated"] = receipt["ended_at"]
    dump_yaml(path, data)


def upsert_decisions(task_dir: Path, receipt: Dict[str, Any]) -> None:
    decisions = receipt.get("decisions", [])
    if not decisions:
        return
    path = task_dir / "decisions.yaml"
    if path.exists():
        data = load_yaml(path)
    else:
        data = {"version": "1.0.0", "last_updated": None, "decisions": []}
    existing_ids = {item.get("id") for item in data.get("decisions", [])}
    for index, decision in enumerate(decisions, start=1):
        decision_id = f"{receipt['run_id']}-decision-{index}"
        if decision_id in existing_ids:
            continue
        data.setdefault("decisions", []).append({
            "id": decision_id,
            "timestamp": receipt["ended_at"],
            "agent": receipt["agent"],
            "task_id": receipt["task_id"],
            "decision": decision,
            "source": "agent-run-receipt",
        })
    data["last_updated"] = receipt["ended_at"]
    dump_yaml(path, data)


def fold_receipt(path: Path, apply: bool) -> List[str]:
    validate_receipt(path)
    receipt = load_yaml(path)
    task_dir = find_task_dir(receipt["task_id"])
    parent = registry_parent(receipt["task_id"])
    actions = [
        f"append {task_dir / 'memory.md'}",
        f"upsert {task_dir / 'timeline.yaml'}",
    ]
    if receipt.get("decisions"):
        actions.append(f"upsert {task_dir / 'decisions.yaml'}")
    if apply:
        append_memory(task_dir, receipt)
        upsert_timeline(task_dir, receipt, parent)
        upsert_decisions(task_dir, receipt)
    return actions


def main() -> int:
    parser = argparse.ArgumentParser(description="Fold validated agent receipts into Docs/td memory")
    parser.add_argument("receipts", nargs="+", help="Receipt YAML file(s)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="Write memory/timeline/decision updates")
    mode.add_argument("--dry-run", action="store_true", help="Print intended writes without changing files")
    args = parser.parse_args()
    apply = args.apply and not args.dry_run

    try:
        for raw in args.receipts:
            actions = fold_receipt(Path(raw), apply=apply)
            print(f"{'APPLY' if apply else 'DRY-RUN'} {raw}")
            for action in actions:
                print(f"  - {action}")
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
