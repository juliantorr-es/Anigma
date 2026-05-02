#!/usr/bin/env python3
"""
Generate Docs/td/ epic and task descriptors from td-task-registry.yaml.

Reads the canonical registry and creates:
- epic.md + epic.yaml for each epic task
- For epics with children: tasks/<child-id>/task.md + task.yaml
- For standalone tasks: task.md + task.yaml in their own folder

Rules:
- Never overwrite existing non-empty files unless --overwrite is passed
- Preserve hand-authored content (p0-003 already exists)
- Deterministic output (sorted keys, stable formatting)
- Experiment: p0-003 folder already has epic.md + epic.yaml - skip it

Usage:
    python3 Scripts/generate_td_descriptors.py --dry-run
    python3 Scripts/generate_td_descriptors.py --write
    python3 Scripts/generate_td_descriptors.py --write --overwrite
"""

import argparse
import os
import re
import yaml
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
import sys

# =============================================================================
# Configuration
# =============================================================================

REPO_ROOT = Path(__file__).parent.parent.absolute()
REGISTRY_PATH = REPO_ROOT / "Docs" / "td" / "td-task-registry.yaml"
TD_DIR = REPO_ROOT / "Docs" / "td"

# Status to directory mapping
STATUS_DIR_MAP = {
    "complete": "done",
    "completed": "done",
    "done": "done",
    "in_progress": "in_progress",
    "in_review": "in_review",
    "ready": "ready",
    "blocked": "blocked",
    "new": "ready",
    "cancelled": "archived",
    "archived": "archived",
}

# Tasks that are epics (parent tasks)
EPIC_TASK_IDS = {
    "p0-003",           # Polytropos Phase 0
    "p0-004",           # anigmad Subprocess Pooling
    "p1-td-source-of-truth-recovery",
}

# Tasks with existing hand-authored files - skip unless --overwrite
PROTECTED_EPICS = {
    "p0-003",
}


def load_registry() -> Dict[str, Any]:
    """Load and validate the registry YAML."""
    if not REGISTRY_PATH.exists():
        sys.exit(f"ERROR: Registry not found at {REGISTRY_PATH}")
    with open(REGISTRY_PATH, 'r') as f:
        return yaml.safe_load(f)


def get_task_map(registry: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    """Build a task_id -> task_dict map."""
    return {t["id"]: t for t in registry.get("tasks", [])}


def is_epic(task: Dict[str, Any]) -> bool:
    """Check if a task is an epic (has children or is in EPIC_TASK_IDS)."""
    return task.get("id") in EPIC_TASK_IDS or bool(task.get("children"))


def is_protected(task_id: str) -> bool:
    """Check if a task has hand-authored files that should be preserved."""
    return task_id in PROTECTED_EPICS


def get_status_dir(task: Dict[str, Any]) -> str:
    """Get the status directory for a task."""
    status = task.get("status", "ready").lower()
    return STATUS_DIR_MAP.get(status, "ready")


def slugify(s: str) -> str:
    """Convert a string to a filesystem-safe directory name."""
    s = s.lower()
    s = re.sub(r'[^a-z0-9_-]', '-', s)
    s = re.sub(r'-+', '-', s)
    s = s.strip('-')
    return s


def dir_for_task(task: Dict[str, Any]) -> Path:
    """Get the directory path for a task."""
    task_id = task["id"]
    status_dir = get_status_dir(task)
    return TD_DIR / status_dir / slugify(task_id)


def has_existing_content(dir_path: Path) -> bool:
    """Check if a directory has existing non-hidden content files."""
    if not dir_path.exists():
        return False
    for f in dir_path.iterdir():
        if not f.name.startswith('.') and f.suffix in ('.md', '.yaml'):
            return True
    return False


def write_file(path: Path, content: str, overwrite: bool = False) -> Tuple[bool, str]:
    """Write a file, respecting overwrite protection. Returns (written, reason)."""
    if path.exists() and not overwrite:
        # Check if file is non-empty
        if path.stat().st_size > 0:
            return False, f"skipped (existing non-empty file)"
    
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')
    return True, "written"


# =============================================================================
# Descriptor Generators
# =============================================================================


def generate_epic_yaml(task: Dict[str, Any], children: List[Dict[str, Any]]) -> str:
    """Generate epic.yaml content for an epic task."""
    child_ids = [c["id"] for c in children]
    
    yaml_data = {
        "id": task["id"],
        "title": task["title"],
        "type": "epic",
        "priority": task.get("priority", "P2"),
        "status": task.get("status", "ready"),
        "lane": task.get("lane", "uncategorized"),
        "summary": clean_summary(task.get("description", "")),
        "description": task.get("description", ""),
        "recommended_worktree": task.get("worktree", "anigma/"),
        "source_docs": sorted(task.get("source_docs", [])),
        "related_docs": sorted(task.get("related_docs", [])),
        "proofs": sorted(task.get("proof", [])),
        "proof_required": sorted(task.get("proof_required", [])),
        "expected_proof": sorted(task.get("expected_proof", [])),
        "tasks": child_ids,
        "children": child_ids,
        "acceptance": task.get("acceptance", []),
        "non_goals": task.get("non_goals", []),
        "td_labels": [f"lane:{task.get('lane', 'uncategorized')}", "type:epic"],
    }
    
    return yaml.dump(yaml_data, default_flow_style=False, sort_keys=False)


def generate_epic_markdown(task: Dict[str, Any], children: List[Dict[str, Any]]) -> str:
    """Generate epic.md content for an epic task."""
    status_emoji = "✅ Done" if task.get("status") in ("complete", "completed", "done") else task.get("status", "ready").title()
    
    child_rows = ""
    if children:
        child_rows = "| ID | Title | Status |\n|----|-------|--------|\n"
        for child in children:
            child_status = child.get("status", "unknown")
            child_title = child.get("title", child["id"])
            child_rows += f"| {child['id']} | {child_title} | {child_status} |\n"
    else:
        child_rows = "*No child tasks*\n"
    
    desc = task.get("description", "No description available.")
    if desc:
        # Clean up newlines
        desc = desc.strip()
    
    acceptance = format_bullets(task.get("acceptance", []), "Acceptance Criteria")
    non_goals = format_bullets(task.get("non_goals", []), "Non-Goals")
    source_docs = format_bullets(task.get("source_docs", []), "Source Docs")
    proofs = format_proof_links(task.get("proof", []))
    
    return f"""# {task["id"]} - {task["title"]}

> **Status**: {status_emoji}  
> **Type**: Epic  
> **Priority**: {task.get("priority", "P2")}  
> **Lane**: {task.get("lane", "uncategorized")}  
> **Worktree**: `{task.get("worktree", "anigma/")}`

---

## Summary

{desc}

## Current Status

**{task.get('status', 'ready').upper()}**

## Epic Tasks

{child_rows}

## Acceptance Criteria

{acceptance}

## Non-Goals

{non_goals}

## Proof Links

{proofs}

## Source Documentation

{source_docs}

## Agent Handoff

> **For AI agents working on this epic**:
> 
> Check the `tasks/` subdirectory for individual task descriptors.
> Refer to `epic.yaml` for structured data and proofs for completion evidence.
> Preserve MaterializationGate patterns when extending.

---

*Epic ID: {task["id"]}*  
*Created: 2026-01-01*
"""


def generate_task_yaml(task: Dict[str, Any], parent_epic: Optional[Dict[str, Any]] = None) -> str:
    """Generate task.yaml content for a task."""
    lane = task.get("lane") or (parent_epic.get("lane") if parent_epic else "uncategorized")
    worktree = task.get("worktree") or (parent_epic.get("worktree") if parent_epic else "anigma/")
    priority = task.get("priority") or (parent_epic.get("priority") if parent_epic else "P2")
    epic_id = parent_epic.get("id") if parent_epic else None
    
    yaml_data = {
        "id": task["id"],
        "title": task["title"],
        "type": task.get("type", "task"),
        "priority": priority,
        "status": task.get("status", "ready"),
        "lane": lane,
        "epic": epic_id,
        "parent": task.get("parent"),
        "summary": clean_summary(task.get("description", "")),
        "description": task.get("description", ""),
        "worktree": worktree,
        "source_docs": sorted(task.get("source_docs", [])),
        "related_docs": sorted(task.get("related_docs", [])),
        "related_diagrams": sorted(task.get("related_diagrams", [])),
        "acceptance": task.get("acceptance", []),
        "non_goals": task.get("non_goals", []),
        "proof": sorted(task.get("proof", [])),
        "proof_required": sorted(task.get("proof_required", [])),
        "expected_proof": sorted(task.get("expected_proof", [])),
        "validator_commands": task.get("validator_commands", []),
        "td_labels": build_td_labels(task, parent_epic),
    }
    
    return yaml.dump(yaml_data, default_flow_style=False, sort_keys=False)


def generate_task_markdown(task: Dict[str, Any], parent_epic: Optional[Dict[str, Any]] = None) -> str:
    """Generate task.md content for a task."""
    epic_ref = parent_epic.get("id") if parent_epic else task.get("parent", "None")
    status_emoji = "✅ Done" if task.get("status") in ("complete", "completed", "done") else task.get("status", "ready").title()
    
    desc = task.get("description", "No description available.")
    if desc:
        desc = desc.strip()
    
    goal = clean_summary(task.get("description", "")) or "See acceptance criteria"
    context = desc
    scope = format_bullets(task.get("acceptance", []), "Acceptance Criteria")
    non_goals = format_bullets(task.get("non_goals", []), "Non-Goals")
    impl_shape = format_bullets(task.get("source_docs", []), "Source Files")
    acceptance = format_bullets(task.get("acceptance", []), "Criteria")
    validators = format_bullets(task.get("validator_commands", []), "Validation Commands")
    proofs = format_proof_links(task.get("proof", []))
    
    return f"""# {task["id"]} - {task["title"]}

> **Status**: {status_emoji}  
> **Type**: {task.get("type", "task").title()}  
> **Priority**: {task.get("priority", "P2")}  
> **Lane**: {task.get("lane", "uncategorized")}  
> **Epic**: [{epic_ref}](../)  
> **Worktree**: `{task.get("worktree", "anigma/")}`

---

## Goal

{goal}

## Context

{context}

## Scope

{scope}

## Non-Goals

{non_goals}

## Implementation Shape

{impl_shape}

## Acceptance Criteria

{acceptance}

## Validation Commands

{validators}

## Proof Requirements

{proofs}

---

*Task ID: {task["id"]}*  
*Created: 2026-01-01*
"""


# =============================================================================
# Helper Functions
# =============================================================================


def clean_summary(text: str) -> Optional[str]:
    """Extract first line as summary, or None."""
    if not text:
        return None
    lines = text.strip().split('\n')
    first = lines[0].strip() if lines else ""
    if len(first) > 200:
        first = first[:197] + "..."
    return first if first else None


def format_bullets(items: List[str], title: str) -> str:
    """Format a list of items as markdown bullet points."""
    if not items:
        return f"## {title}\n\n*None*\n"
    return f"## {title}\n\n" + "\n".join(f"- {item}" for item in items) + "\n"


def format_proof_links(proofs: List[str]) -> str:
    """Format proof artifacts with links to Docs/proofs/."""
    if not proofs:
        return "## Proof\n\n*No proof artifacts*\n"
    
    lines = ["## Proof"]
    for proof in sorted(proofs):
        if proof.startswith("Docs/proofs/"):
            rel = os.path.relpath(proof, "Docs/td")
            lines.append(f"- [{os.path.basename(proof)}](../../{proof})")
        else:
            lines.append(f"- {proof}")
    return "\n".join(lines) + "\n"


def build_td_labels(task: Dict[str, Any], parent_epic: Optional[Dict[str, Any]] = None) -> List[str]:
    """Build TD labels list."""
    labels = []
    lane = task.get("lane") or (parent_epic.get("lane") if parent_epic else None)
    if lane:
        labels.append(f"lane:{lane}")
    if task.get("parent"):
        labels.append(f"parent:{task['parent']}")
    if parent_epic:
        labels.append(f"epic:{parent_epic['id']}")
    labels.append(f"task_id:{task['id']}")
    labels.append(f"type:{task.get('type', 'task')}")
    return sorted(set(labels))


# =============================================================================
# Main Generation Logic
# =============================================================================


def generate_all(
    registry: Dict[str, Any],
    task_map: Dict[str, Dict[str, Any]],
    overwrite: bool = False,
    dry_run: bool = True
) -> Tuple[List[str], List[str], List[str]]:
    """
    Generate all descriptors.
    
    Returns: (created, skipped, errors)
    """
    created = []
    skipped = []
    errors = []
    
    tasks = sorted(registry.get("tasks", []), key=lambda t: t["id"])
    
    # Identify epics and their children
    epics = {t["id"]: t for t in tasks if is_epic(t)}
    children_map = {t["id"]: [task_map[cid] for cid in t.get("children", [])] 
                    for tid, t in epics.items()}
    standalone_tasks = [t for t in tasks if not t.get("parent") and not is_epic(t)]
    
    # Process epics first
    for epic_id in sorted(epics.keys()):
        epic = epics[epic_id]
        children = children_map.get(epic_id, [])
        epic_dir = dir_for_task(epic)
        
        # Check if protected
        if is_protected(epic_id) and has_existing_content(epic_dir):
            if not overwrite:
                skipped.append(f"epic {epic_id} (protected, existing files)")
            else:
                created.append(f"overwritten epic {epic_id}")
            # Create child tasks regardless
            process_children = True
        else:
            process_children = True
            if dry_run:
                created.append(f"[DRY] epic {epic_id} -> {epic_dir}")
            else:
                os.makedirs(epic_dir, exist_ok=True)
                
                # Write epic.yaml
                yaml_path = epic_dir / "epic.yaml"
                w, r = write_file(yaml_path, generate_epic_yaml(epic, children), overwrite)
                if w:
                    created.append(f"  epic.yaml {epic_id}")
                else:
                    skipped.append(f"  skipped epic.yaml {epic_id} ({r})")
                
                # Write epic.md
                md_path = epic_dir / "epic.md"
                w, r = write_file(md_path, generate_epic_markdown(epic, children), overwrite)
                if w:
                    created.append(f"  epic.md {epic_id}")
                else:
                    skipped.append(f"  skipped epic.md {epic_id} ({r})")
        
        # Process children for all epics
        if process_children and children:
            tasks_dir = epic_dir / "tasks"
            os.makedirs(tasks_dir, exist_ok=True)
            
            for child in children:
                child_dir = tasks_dir / slugify(child["id"])
                if dry_run:
                    created.append(f"[DRY] child {child['id']} -> {child_dir}")
                else:
                    os.makedirs(child_dir, exist_ok=True)
                    
                    # Write task.yaml
                    yaml_path = child_dir / "task.yaml"
                    w, r = write_file(yaml_path, generate_task_yaml(child, epic), overwrite)
                    if w:
                        created.append(f"    task.yaml {child['id']}")
                    else:
                        skipped.append(f"    skipped task.yaml {child['id']} ({r})")
                    
                    # Write task.md
                    md_path = child_dir / "task.md"
                    w, r = write_file(md_path, generate_task_markdown(child, epic), overwrite)
                    if w:
                        created.append(f"    task.md {child['id']}")
                    else:
                        skipped.append(f"    skipped task.md {child['id']} ({r})")
    
    # Process standalone tasks
    for task in sorted(standalone_tasks, key=lambda t: t["id"]):
        task_id = task["id"]
        task_dir = dir_for_task(task)
        
        if dry_run:
            created.append(f"[DRY] standalone {task_id} -> {task_dir}")
        else:
            os.makedirs(task_dir, exist_ok=True)
            
            # For standalone tasks, create as epic (since they stand alone)
            yaml_path = task_dir / "epic.yaml"
            w, r = write_file(yaml_path, generate_epic_yaml(task, []), overwrite)
            if w:
                created.append(f"  standalone epic.yaml {task_id}")
            else:
                skipped.append(f"  skipped standalone epic.yaml {task_id} ({r})")
            
            md_path = task_dir / "epic.md"
            w, r = write_file(md_path, generate_epic_markdown(task, []), overwrite)
            if w:
                created.append(f"  standalone epic.md {task_id}")
            else:
                skipped.append(f"  skipped standalone epic.md {task_id} ({r})")
    
    return created, skipped, errors


# =============================================================================
# CLI
# =============================================================================


def main():
    parser = argparse.ArgumentParser(
        description="Generate Docs/td/ epic and task descriptors from registry"
    )
    parser.add_argument(
        "--write", 
        action="store_true", 
        default=False,
        help="Actually write descriptor files"
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        default=False,
        help="Overwrite existing non-empty files"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Show what would be created without writing"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        default=False,
        help="Verbose output"
    )
    
    args = parser.parse_args()
    
    dry_run = args.dry_run
    write = args.write
    overwrite = args.overwrite
    
    if not dry_run and not write:
        print("ERROR: Use --write or --dry-run")
        sys.exit(1)
    
    # Load registry
    try:
        registry = load_registry()
    except SystemExit as e:
        print(e)
        sys.exit(1)
    
    if args.verbose:
        print(f"Loaded {len(registry.get('tasks', []))} tasks from {REGISTRY_PATH}")
    
    task_map = get_task_map(registry)
    
    # Generate
    created, skipped, errors = generate_all(
        registry, task_map, overwrite=overwrite, dry_run=dry_run
    )
    
    # Summary
    print(f"\n{'='*60}")
    print("GENERATION SUMMARY")
    print(f"{'='*60}")
    mode = "DRY RUN" if dry_run else "WRITE"
    print(f"  Mode: {mode}")
    print(f"  Created: {len(created)}")
    print(f"  Skipped: {len(skipped)}")
    print(f"  Errors: {len(errors)}")
    
    if args.verbose or len(errors) > 0:
        if created:
            print(f"\n  Created:")
            for c in created[:15]:
                print(f"    {c}")
        if skipped:
            print(f"\n  Skipped:")
            for s in skipped[:15]:
                print(f"    {s}")
        if errors:
            print(f"\n  Errors:")
            for e in errors[:15]:
                print(f"    {e}")
    
    print(f"{'='*60}")
    
    sys.exit(0 if not errors else 1)


if __name__ == "__main__":
    main()
