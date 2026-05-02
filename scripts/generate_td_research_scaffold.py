#!/usr/bin/env python3
"""
TD Research Scaffold Generator

Generates deterministic research/decision/timeline scaffolding for TD epics and tasks.
Reads existing Docs/td descriptors and creates missing research artifacts with
conservative placeholders.

Usage:
    python3 scripts/generate_td_research_scaffold.py --write --overwrite
    python3 scripts/generate_td_research_scaffold.py --dry-run --verbose
    python3 scripts/generate_td_research_scaffold.py --status ready --epic p0-004

Constraints:
    - DO NOT INVENT line numbers, symbols, or file paths
    - Use empty arrays for fields requiring inspection: line_ranges: [], symbols: [], affected_files: []
    - Use conservative placeholders: status: not_started, research_stage: intake
    - Never mark P0-004 implementation complete
    - Never duplicate proof content
    - Never move global proof artifacts into task folders
"""

import argparse
import os
import sys
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Any

# =============================================================================
# CONSTANTS
# =============================================================================

REPO_ROOT = Path(__file__).parent.parent
DOCSRoot = REPO_ROOT / "Docs"
TD_ROOT = DOCSRoot / "td"
SCHEMAS_DIR = DOCSRoot / "schemas"
TIMELINE_DIR = DOCSRoot / "timeline"

# Research stage order
RESEARCH_STAGES = [
    "intake",
    "source_review", 
    "code_map",
    "doctrine_alignment",
    "implementation_plan",
    "implementation",
    "verification",
    "proof",
    "closed"
]

# =============================================================================
# TEMPLATES
# =============================================================================

EPIC_RESEARCH_LOG_TEMPLATE = """# TD Research Log

## Research Stages

| Stage | Status | Date | Notes |
|-------|--------|------|-------|
| intake | active | {date} | Initial intake |
| source_review | not_started | - | Review system docs and roadmaps |
| code_map | not_started | - | Map relevant code surfaces |
| doctrine_alignment | not_started | - | Align with governance doctrines |
| implementation_plan | not_started | - | Define implementation approach |
| implementation | not_started | - | DO NOT START until research complete |
| verification | not_started | - | Verify against verification profiles |
| proof | not_started | - | Generate proof artifacts |
| closed | not_started | - | Archive only when complete |

## WARNING

DO NOT INVENT line numbers, symbols, or file paths.
All fields requiring inspection MUST use empty arrays until actually inspected.
DO NOT mark P0-004 implementation complete.
"""

EPIC_FINDINGS_TEMPLATE = """# Research Findings

research_stage: intake

findings: []

current_architecture_summary: ""
constraints: []
risks: []
recommended_next_stage: source_review

evidences: []
"""

EPIC_FILE_MAP_TEMPLATE = """# File Map for Research

# Known research targets (from existing documentation)
# Add actual file entries after inspection
inspected_files: []

# Example structure for each entry:
# - path: "anigma/Sources/SubprocessPooling/..."
#   exists: true
#   role: "..."
#   tier: 2 or 3
#   module: "..."
#   relevant_symbols: []
#   expected_action: inspect
#   rationale: "..."
#   related_docs: []
#   related_tasks: []
"""

EPIC_SYMBOL_MAP_TEMPLATE = """# Symbol Map for Research

## WARNING

DO NOT INVENT symbol names or line numbers.
Symbol entries MUST only be added after actual code inspection.
Use empty array until symbols are actually discovered.

inspected_symbols: []
"""

EPIC_OPEN_QUESTIONS_TEMPLATE = """# Open Questions

open_questions: []

# Example structure for each entry:
# - question_id: "Q-001"
#   question: "..."
#   severity: blocker | important | minor
#   owner: operator | agent | future_implementation
#   required_before: implementation | verification | closeout
#   candidate_resolution: "..."
#   source_context: "..."
"""

EPIC_DECISION_LOG_TEMPLATE = """# Decision Log

decisions: []

# Example structure for each entry:
# - decision_id: "AD-001"
#   title: "..."
#   status: proposed | accepted | rejected | superseded
#   type: architectural | implementation | research | process
#   description: "..."
#   context: "..."
#   options_considered: []
#   selected_option: "..."
#   rationale: "..."
#   impacts: []
#   risks: []
#   related_docs: []
#   related_tasks: []
#   doctrine_alignment: []
"""

EPIC_TIMELINE_MD_TEMPLATE = """# Epic Timeline

## Event Summary

| Event ID | Timestamp | Type | Summary | Status |
|----------|-----------|------|--------|--------|

## Notes

Timeline events roll up to project-timeline.yaml.
Task-level events roll up to epic-level events.
"""

EPIC_EVENTS_YAML_TEMPLATE = """# Epic Timeline Events
events: []

# Example structure for each entry:
# - event_id: "p0-004-ev-001"
#   timestamp: "2026-01-01T00:00:00Z"
#   type: research_started | source_review_started | code_map_started | doctrine_alignment_started | implementation_started | verification_started | proof_generated | decision_made | blocked | unblocked
#   summary: "..."
#   actor: operator | agent | system
#   evidence: "..."
#   related_files: []
#   related_docs: []
#   related_tasks: []
#   rollup_level: epic
#   epic_id: p0-004
#   canonical_doc_effects: []
"""

TASK_RESEARCH_MD_TEMPLATE = """# Task Research State

current_stage: intake
research_stage: intake

## Stage Semantics

- **intake**: Task identified, not yet reviewed
- **source_review**: Documentation and architecture reviewed
- **code_map**: Relevant code surfaces identified
- **doctrine_alignment**: Aligned with governance doctrines
- **implementation_plan**: Approach defined
- **implementation**: Code changes in progress
- **verification**: Testing and validation
- **proof**: Proof artifact generation
- **closed**: Complete and archived

## WARNING

DO NOT INVENT line numbers or symbols.
Do NOT start implementation until research is complete.
"""

TASK_CHANGE_MAP_TEMPLATE = """# Change Map

status: not_started

# Change declaration - intent before modification
affected_surface: SubprocessPooling
action: extend  # extend | create | modify | refactor | remove | verify
doctrine_alignment: []

# Files to be affected - MUST be empty until inspected
files: []

# Line ranges - DO NOT INVENT LINE NUMBERS
# Use empty array until actual inspection
line_ranges: []

# Doctrine alignment entries
# Each must reference specific doctrine documents
doctrine_alignment: []

# Example doctrine alignment entry:
# - doctrine_doc: "Docs/governance/TIER_GOVERNANCE.md"
#   requirement: "Tier 2 must not depend on Tier 3"
#   alignment_status: compliant | non_compliant | needs_review
#   notes: "..."
"""

TASK_REASONING_MD_TEMPLATE = """# Reasoning

## Options Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|

## Constraints

- Tier boundaries must be respected
- No runtime source changes without proof
- All @_exported imports must be in Tier 1

## Tradeoffs

## Selected Approach

Not selected - research in progress

## Verification Requirements

- Proof artifact must be generated
- All validators must pass
- No runtime source mutations
"""

TASK_TIMELINE_YAML_TEMPLATE = """# Task Timeline
events: []

task_id: {task_id}
epic_id: {epic_id}
rollup_level: task
"""


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def get_date() -> str:
    from datetime import datetime
    return datetime.now().strftime("%Y-%m-%d")


def file_exists_with_content(filepath: Path) -> bool:
    if not filepath.exists():
        return False
    try:
        content = filepath.read_text().strip()
        return bool(content)
    except (IOError, OSError):
        return False


def read_yaml(filepath: Path) -> Optional[Dict[str, Any]]:
    try:
        with open(filepath, 'r') as f:
            return yaml.safe_load(f)
    except (FileNotFoundError, yaml.YAMLError):
        return None


def write_yaml(filepath: Path, data: Dict[str, Any]) -> None:
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, 'w') as f:
        yaml.dump(data, f, sort_keys=False, default_flow_style=False, width=120)


def find_epic_descriptors(td_root: Path) -> List[Path]:
    epics = []
    for status_dir in td_root.iterdir():
        if status_dir.is_dir():
            for epic_dir in status_dir.iterdir():
                if epic_dir.is_dir():
                    epic_yaml = epic_dir / "epic.yaml"
                    if epic_yaml.exists():
                        epics.append(epic_yaml)
    return epics


def get_epic_id_from_path(epic_path: Path) -> Optional[str]:
    parts = epic_path.parts
    for part in parts:
        if part.startswith("p0-") or part.startswith("p1-"):
            return part
    return None


def get_task_dirs_for_epic(epic_dir: Path) -> List[Path]:
    tasks_dir = epic_dir / "tasks"
    if not tasks_dir.exists():
        return []
    return [d for d in tasks_dir.iterdir() if d.is_dir()]


def get_task_id_from_path(task_dir: Path) -> str:
    return task_dir.name


# =============================================================================
# SCAN PHASE
# =============================================================================

def scan_epics(td_root: Path, status_filter: Optional[str] = None) -> List[Dict[str, Any]]:
    epics = find_epic_descriptors(td_root)
    results = []
    
    for epic_path in epics:
        epic_dir = epic_path.parent
        epic_id = get_epic_id_from_path(epic_path)
        if epic_id is None:
            continue
        
        status_dir = epic_dir.parent.name
        if status_filter and status_dir != status_filter:
            continue
        
        research_dir = epic_dir / "research"
        decisions_dir = epic_dir / "decisions"
        timeline_dir = epic_dir / "timeline"
        
        epic_files = {
            'research_log': research_dir / "research-log.md",
            'findings': research_dir / "findings.yaml",
            'file_map': research_dir / "file-map.yaml",
            'symbol_map': research_dir / "symbol-map.yaml",
            'open_questions': research_dir / "open-questions.yaml",
            'decision_log': decisions_dir / "decision-log.yaml",
            'timeline_md': timeline_dir / "timeline.md",
            'events_yaml': timeline_dir / "events.yaml",
        }
        
        missing_epic_files = {}
        for name, path in epic_files.items():
            if not file_exists_with_content(path):
                missing_epic_files[name] = path
        
        task_dirs = get_task_dirs_for_epic(epic_dir)
        missing_task_files = []
        
        for task_dir in task_dirs:
            task_id = get_task_id_from_path(task_dir)
            task_files = {
                'research_md': task_dir / "research.md",
                'change_map': task_dir / "change-map.yaml",
                'reasoning_md': task_dir / "reasoning.md",
                'timeline_yaml': task_dir / "timeline.yaml",
            }
            for name, path in task_files.items():
                if not file_exists_with_content(path):
                    missing_task_files.append({'task_id': task_id, 'name': name, 'path': path})
        
        if missing_epic_files or missing_task_files:
            results.append({
                'epic_id': epic_id,
                'epic_dir': epic_dir,
                'status': status_dir,
                'missing_epic_files': missing_epic_files,
                'missing_task_files': missing_task_files,
            })
    
    return results


# =============================================================================
# GENERATE PHASE
# =============================================================================

def generate_epic_file(path: Path, template: str, epic_id: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = template.format(date=get_date(), epic_id=epic_id)
    header = f"# Auto-generated by generate_td_research_scaffold.py\n# Epic: {epic_id}\n# Date: {get_date()}\n\n"
    path.write_text(header + content)


def generate_task_file(path: Path, template: str, task_id: str, epic_id: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = template.format(task_id=task_id, epic_id=epic_id)
    header = f"# Auto-generated by generate_td_research_scaffold.py\n# Task: {task_id}\n# Epic: {epic_id}\n# Date: {get_date()}\n\n"
    path.write_text(header + content)


def generate_scaffolding(
    epic_id: str,
    epic_dir: Path,
    missing_epic_files: Dict[str, Path],
    missing_task_files: List[Dict[str, Any]],
    overwrite: bool = False
) -> List[Path]:
    created = []
    
    epic_templates = {
        'research_log': EPIC_RESEARCH_LOG_TEMPLATE,
        'findings': EPIC_FINDINGS_TEMPLATE,
        'file_map': EPIC_FILE_MAP_TEMPLATE,
        'symbol_map': EPIC_SYMBOL_MAP_TEMPLATE,
        'open_questions': EPIC_OPEN_QUESTIONS_TEMPLATE,
        'decision_log': EPIC_DECISION_LOG_TEMPLATE,
        'timeline_md': EPIC_TIMELINE_MD_TEMPLATE,
        'events_yaml': EPIC_EVENTS_YAML_TEMPLATE,
    }
    
    for name, path in missing_epic_files.items():
        if path.exists() and not overwrite:
            continue
        template = epic_templates.get(name, "")
        generate_epic_file(path, template, epic_id)
        created.append(path)
    
    task_templates = {
        'research_md': TASK_RESEARCH_MD_TEMPLATE,
        'change_map': TASK_CHANGE_MAP_TEMPLATE,
        'reasoning_md': TASK_REASONING_MD_TEMPLATE,
        'timeline_yaml': TASK_TIMELINE_YAML_TEMPLATE,
    }
    
    for task_info in missing_task_files:
        task_id = task_info['task_id']
        name = task_info['name']
        path = task_info['path']
        
        if path.exists() and not overwrite:
            continue
        
        template = task_templates.get(name, "")
        generate_task_file(path, template, task_id, epic_id)
        created.append(path)
    
    return created


def seed_p0004_file_map(file_map_path: Path) -> None:
    """Seed P0-004 file-map.yaml with documented research targets."""
    targets = [
        {
            "path": "anigma/Package.swift",
            "exists": True,
            "role": "package_manifest",
            "tier": 3,
            "module": "AnigmaPackage",
            "relevant_symbols": [],
            "expected_action": "inspect",
            "rationale": "SubprocessPooling target is defined in Package.swift dependencies",
            "related_docs": ["Docs/P0_CRITICAL_PATH.md", "Docs/roadmaps/MASTER_ROADMAP_2026.md"],
            "related_tasks": ["p0-004"]
        },
        {
            "path": "anigma/Sources/SubprocessPooling/",
            "exists": True,
            "role": "subprocess_pooling_implementation",
            "tier": 2,
            "module": "SubprocessPooling",
            "relevant_symbols": [],
            "expected_action": "inspect",
            "rationale": "Primary implementation target for P0-004",
            "related_docs": ["Docs/architecture/maps/logic-flows/subprocess-pooling-planned-flow.mmd"],
            "related_tasks": ["p0-004"]
        },
        {
            "path": "anigma/Sources/AnigmaDaemonCore/",
            "exists": True,
            "role": "daemon_core",
            "tier": 2,
            "module": "AnigmaDaemonCore",
            "relevant_symbols": [],
            "expected_action": "inspect",
            "rationale": "Daemon core interfaces with pool lifecycle management",
            "related_docs": ["Docs/governance/TD_RESEARCH_AND_TIMELINE_DOCTRINE.md"],
            "related_tasks": ["p0-004"]
        },
        {
            "path": "anigma/Sources/AnigmaDaemon/",
            "exists": True,
            "role": "daemon_implementation",
            "tier": 3,
            "module": "AnigmaDaemon",
            "relevant_symbols": [],
            "expected_action": "inspect",
            "rationale": "Daemon policy and lifecycle management",
            "related_docs": ["Docs/governance/TD_RESEARCH_AND_TIMELINE_DOCTRINE.md"],
            "related_tasks": ["p0-004"]
        },
        {
            "path": "anigma/Sources/GovernanceCore/",
            "exists": True,
            "role": "governance_contracts",
            "tier": 1,
            "module": "GovernanceCore",
            "relevant_symbols": [],
            "expected_action": "inspect",
            "rationale": "Governance contracts that SubprocessPooling must respect",
            "related_docs": ["Docs/governance/TIER_GOVERNANCE.md"],
            "related_tasks": ["p0-004"]
        },
        {
            "path": "anigma/Sources/TelemetryCore/",
            "exists": True,
            "role": "telemetry_contracts",
            "tier": 1,
            "module": "TelemetryCore",
            "relevant_symbols": [],
            "expected_action": "inspect",
            "rationale": "Telemetry contracts for pool health monitoring",
            "related_docs": ["Docs/governance/TD_RESEARCH_AND_TIMELINE_DOCTRINE.md"],
            "related_tasks": ["p0-004"]
        },
        {
            "path": "anigma/Tests/",
            "exists": True,
            "role": "test_suite",
            "tier": 3,
            "module": "AnigmaPackageTests",
            "relevant_symbols": [],
            "expected_action": "inspect",
            "rationale": "Tests for SubprocessPooling functionality",
            "related_docs": ["Docs/manifests/verification-profiles.yaml"],
            "related_tasks": ["p0-004"]
        },
        {
            "path": "Docs/P0_CRITICAL_PATH.md",
            "exists": True,
            "role": "critical_path_documentation",
            "tier": None,
            "module": None,
            "relevant_symbols": [],
            "expected_action": "review",
            "rationale": "P0-004 is on the critical path",
            "related_docs": [],
            "related_tasks": ["p0-004"]
        },
        {
            "path": "Docs/roadmaps/MASTER_ROADMAP_2026.md",
            "exists": True,
            "role": "roadmap",
            "tier": None,
            "module": None,
            "relevant_symbols": [],
            "expected_action": "review",
            "rationale": "P0-004 appears in master roadmap",
            "related_docs": [],
            "related_tasks": ["p0-004"]
        }
    ]
    
    write_yaml(file_map_path, {'inspected_files': targets})


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Generate TD research scaffolding for epics and tasks'
    )
    parser.add_argument('--dry-run', action='store_true', help='Show what would be created')
    parser.add_argument('--write', action='store_true', help='Write files to disk')
    parser.add_argument('--overwrite', action='store_true', help='Overwrite existing non-empty files')
    parser.add_argument('--status', type=str, help='Filter by TD status')
    parser.add_argument('--epic', type=str, help='Filter by specific epic ID')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--seed-p0004', action='store_true', help='Seed P0-004 file-map')
    
    args = parser.parse_args()
    
    if not args.dry_run and not args.write:
        print("Error: Must specify either --dry-run or --write")
        sys.exit(1)
    
    if args.dry_run and args.write:
        print("Error: Cannot specify both --dry-run and --write")
        sys.exit(1)
    
    scan_results = scan_epics(TD_ROOT, status_filter=args.status)
    
    if args.epic:
        scan_results = [r for r in scan_results if r['epic_id'] == args.epic]
    
    if not scan_results:
        print("No epics need scaffolding.")
        if args.dry_run:
            print("=== DRY RUN MODE ===")
            print("No scaffolding needed - all files already exist with content.")
        sys.exit(0)
    
    total_files = 0
    
    if args.dry_run:
        print("=== DRY RUN MODE ===")
        print("The following files would be created:\n")
    
    for result in scan_results:
        epic_id = result['epic_id']
        epic_dir = result['epic_dir']
        missing_epic = result['missing_epic_files']
        missing_tasks = result['missing_task_files']
        
        count = len(missing_epic) + len(missing_tasks)
        total_files += count
        
        if args.dry_run:
            if missing_epic:
                print(f"  Epic {epic_id} ({result['status']}):")
                for name, path in missing_epic.items():
                    rel_path = path.relative_to(REPO_ROOT)
                    print(f"    - {rel_path}")
                for task_info in missing_tasks:
                    rel_path = task_info['path'].relative_to(REPO_ROOT)
                    print(f"    - {rel_path}")
        else:
            created = generate_scaffolding(
                epic_id, epic_dir, missing_epic, missing_tasks, args.overwrite
            )
            
            if args.seed_p0004 and epic_id == "p0-004":
                file_map_path = epic_dir / "research" / "file-map.yaml"
                if not file_map_path.exists() or args.overwrite:
                    seed_p0004_file_map(file_map_path)
                    created.append(file_map_path)
            
            if args.verbose:
                for path in created:
                    rel_path = path.relative_to(REPO_ROOT)
                    print(f"  Created: {rel_path}")
    
    if args.dry_run:
        print(f"\nTotal files to create: {total_files}")
    else:
        print(f"Created {total_files} files.")
        
        validate_exit = 0
        for result in scan_results:
            epic_dir = result['epic_dir']
            
            research_files = [
                epic_dir / "research" / "research-log.md",
                epic_dir / "research" / "findings.yaml",
                epic_dir / "research" / "file-map.yaml",
                epic_dir / "research" / "symbol-map.yaml",
                epic_dir / "research" / "open-questions.yaml",
                epic_dir / "decisions" / "decision-log.yaml",
                epic_dir / "timeline" / "timeline.md",
                epic_dir / "timeline" / "events.yaml",
            ]
            
            for f in research_files:
                if not f.exists() or f.read_text().strip() == "":
                    print(f"  WARNING: {f.relative_to(REPO_ROOT)} is empty or missing")
                    validate_exit = 1
            
            for task_dir in get_task_dirs_for_epic(epic_dir):
                task_files = [
                    task_dir / "research.md",
                    task_dir / "change-map.yaml",
                    task_dir / "reasoning.md",
                    task_dir / "timeline.yaml",
                ]
                for f in task_files:
                    if not f.exists() or f.read_text().strip() == "":
                        print(f"  WARNING: {f.relative_to(REPO_ROOT)} is empty or missing")
                        validate_exit = 1
        
        if args.verbose and validate_exit == 0:
            print("All scaffolding created successfully.")
        
        sys.exit(validate_exit)


if __name__ == "__main__":
    main()
