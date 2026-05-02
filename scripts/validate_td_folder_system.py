#!/usr/bin/env python3
"""
validate_td_folder_system.py

Validates the Docs/td/ folder system structure for task descriptors.
This is the new validator for the folder-based task documentation system.

Exit codes:
  0 = All validations passed
  1 = Validation errors found (actionable)

Usage:
    python3 Scripts/validate_td_folder_system.py
    python3 Scripts/validate_td_folder_system.py --verbose
    python3 Scripts/validate_td_folder_system.py --check-proofs
"""

import argparse
import os
import re
import sys
import yaml
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# =============================================================================
# Configuration
# =============================================================================

REPO_ROOT = Path(__file__).parent.parent.absolute()
TD_DIR = REPO_ROOT / "Docs" / "td"
PROOFS_DIR = REPO_ROOT / "Docs" / "proofs"
REGISTRY_PATH = REPO_ROOT / "Docs" / "td" / "td-task-registry.yaml"

# Valid status directories
VALID_STATUS_DIRS = {
    "done", "in_progress", "ready", "in_review", "blocked", "archived"
}

# Valid file types in descriptor folders
VALID_DESCRIPTOR_FILES = {".md", ".yaml"}

# Required files for epics
REQUIRED_EPIC_FILES = {"epic.md", "epic.yaml"}

# Required files for tasks
REQUIRED_TASK_FILES = {"task.md", "task.yaml"}

STANDALONE_TASKS = {
    "p0-003",
    "p1-validate-tiers-green-gate",
    "p1-documentation-artifacts-completion",
    "p1-td-source-of-truth-recovery",
    "p1-public-history-excision",
}


class ValidationError:
    """Represents a single validation error."""
    
    def __init__(self, rule_id: str, message: str, severity: str = "ERROR", path: Optional[str] = None):
        self.rule_id = rule_id
        self.message = message
        self.severity = severity
        self.path = path
    
    def __str__(self) -> str:
        prefix = f"[{self.severity}]" if self.severity != "ERROR" else "[X]"
        location = f" at {self.path}" if self.path else ""
        return f"{prefix} {self.rule_id}: {self.message}{location}"


class ValidationResult:
    """Collects validation results."""
    
    def __init__(self):
        self.errors: List[ValidationError] = []
        self.warnings: List[ValidationError] = []
        self.infos: List[ValidationError] = []
        self.counts: Dict[str, int] = {"epics": 0, "tasks": 0, "files": 0}
    
    def add_error(self, rule_id: str, message: str, path: Optional[str] = None):
        self.errors.append(ValidationError(rule_id, message, "ERROR", path))
    
    def add_warning(self, rule_id: str, message: str, path: Optional[str] = None):
        self.warnings.append(ValidationError(rule_id, message, "WARNING", path))
    
    def add_info(self, rule_id: str, message: str, path: Optional[str] = None):
        self.infos.append(ValidationError(rule_id, message, "INFO", path))
    
    def is_valid(self) -> bool:
        return len(self.errors) == 0
    
    def exit_code(self) -> int:
        return 0 if self.is_valid() else 1


def load_registry() -> Optional[Dict[str, Any]]:
    """Load the task registry YAML."""
    if not REGISTRY_PATH.exists():
        return None
    try:
        with open(REGISTRY_PATH, 'r') as f:
            return yaml.safe_load(f)
    except yaml.YAMLError:
        return None


def get_task_map(registry: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    """Get map of task_id -> task_data."""
    return {t["id"]: t for t in registry.get("tasks", [])}


def is_epic_task(task: Dict[str, Any]) -> bool:
    """Check if task is an epic (has children)."""
    return bool(task.get("children"))


def status_dir_to_key(dirname: str) -> str:
    """Convert directory name to status key."""
    mapping = {
        "done": "complete",
        "in_progress": "in_progress",
        "ready": "ready",
        "in_review": "in_review",
        "blocked": "blocked",
        "archived": "archived",
    }
    return mapping.get(dirname, dirname)


# =============================================================================
# Validation Rules
# =============================================================================


def rule_fd_001_structure(result: ValidationResult) -> None:
    """FD-001: Status directories must exist and be directories."""
    for status_dir in VALID_STATUS_DIRS:
        dir_path = TD_DIR / status_dir
        if not dir_path.exists():
            result.add_warning("FD-001", f"Status directory '{status_dir}' does not exist")


def rule_fd_002_epic_files(result: ValidationResult) -> None:
    """FD-002: Each epic folder must have epic.md and epic.yaml."""
    if not TD_DIR.exists():
        result.add_error("FD-002", "Docs/td/ directory does not exist")
        return
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        for item in status_path.iterdir():
            if not item.is_dir() or item.name.startswith('.'):
                continue
            
            # Check for epic descriptor files
            epic_yaml = item / "epic.yaml"
            epic_md = item / "epic.md"
            
            if epic_yaml.exists() and epic_md.exists():
                result.counts["epics"] += 1
                result.counts["files"] += 2
            elif epic_yaml.exists() or epic_md.exists():
                missing = []
                if not epic_yaml.exists():
                    missing.append("epic.yaml")
                if not epic_md.exists():
                    missing.append("epic.md")
                result.add_error("FD-002", f"Epic {item.name} missing: {', '.join(missing)}", str(item))
            else:
                # Check for task descriptor files (standalone task as epic)
                task_yaml = item / "task.yaml"
                task_md = item / "task.md"
                if task_yaml.exists() and task_md.exists():
                    result.counts["tasks"] += 1
                    result.counts["files"] += 2
                elif task_yaml.exists() or task_md.exists():
                    missing = []
                    if not task_yaml.exists():
                        missing.append("task.yaml")
                    if not task_md.exists():
                        missing.append("task.md")
                    result.add_error("FD-002", f"Task {item.name} missing: {', '.join(missing)}", str(item))


def rule_fd_003_child_tasks(result: ValidationResult) -> None:
    """FD-003: Epic folders with children must have tasks/ subdirectory with task descriptors."""
    if not TD_DIR.exists():
        return
    
    registry = load_registry()
    if not registry:
        result.add_warning("FD-003", "Cannot validate child tasks without registry")
        return
    
    task_map = get_task_map(registry)
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        for epic_dir in status_path.iterdir():
            if not epic_dir.is_dir():
                continue
            
            epic_yaml = epic_dir / "epic.yaml"
            if not epic_yaml.exists():
                continue
            
            # Load epic to check for children
            try:
                with open(epic_yaml, 'r') as f:
                    epic_data = yaml.safe_load(f)
            except:
                continue
            
            children = epic_data.get("tasks", []) or epic_data.get("children", [])
            if not children:
                continue
            
            tasks_dir = epic_dir / "tasks"
            if not tasks_dir.exists():
                result.add_error("FD-003", f"Epic {epic_data.get('id', 'unknown')} has children but no tasks/ directory", str(epic_dir))
                continue
            
            # Check each child has task descriptors
            for child_id in children:
                child_dir = tasks_dir / child_id
                task_yaml = child_dir / "task.yaml"
                task_md = child_dir / "task.md"
                
                if task_yaml.exists() and task_md.exists():
                    result.counts["tasks"] += 1
                    result.counts["files"] += 2
                elif task_yaml.exists() or task_md.exists():
                    missing = []
                    if not task_yaml.exists():
                        missing.append("task.yaml")
                    if not task_md.exists():
                        missing.append("task.md")
                    result.add_error("FD-003", f"Child task {child_id} missing: {', '.join(missing)}", str(child_dir))
                else:
                    if child_dir.exists():
                        result.add_error("FD-003", f"Child task {child_id} directory exists but has no descriptors", str(child_dir))
                    else:
                        result.add_warning("FD-003", f"Child task {child_id} not in filesystem (check registry)", str(epic_dir))


def rule_fd_004_status_match(result: ValidationResult) -> None:
    """FD-004: YAML status must match directory status."""
    if not TD_DIR.exists():
        return
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        expected_status = status_dir_to_key(status_dir)
        
        for item in status_path.iterdir():
            if not item.is_dir():
                continue
            
            # Check epic.yaml
            epic_yaml = item / "epic.yaml"
            if epic_yaml.exists():
                try:
                    with open(epic_yaml, 'r') as f:
                        data = yaml.safe_load(f)
                    yaml_status = (data.get("status") or "").lower()
                    if yaml_status not in ("complete", "completed", "done") and expected_status == "complete":
                        result.add_warning("FD-004", f"epic.yaml status '{yaml_status}' may not match directory '{status_dir}'", str(epic_yaml))
                except:
                    result.add_error("FD-004", f"Cannot parse epic.yaml", str(epic_yaml))
            
            # Check task.yaml files
            tasks_dir = item / "tasks"
            if tasks_dir.exists():
                for task_dir in tasks_dir.iterdir():
                    if not task_dir.is_dir():
                        continue
                    task_yaml = task_dir / "task.yaml"
                    if task_yaml.exists():
                        try:
                            with open(task_yaml, 'r') as f:
                                data = yaml.safe_load(f)
                            yaml_status = (data.get("status") or "").lower()
                            if yaml_status not in ("complete", "completed", "done") and expected_status == "complete":
                                result.add_warning("FD-004", f"task.yaml status '{yaml_status}' may not match directory '{status_dir}'", str(task_yaml))
                        except:
                            result.add_error("FD-004", f"Cannot parse task.yaml", str(task_yaml))


def rule_fd_005_unique_ids(result: ValidationResult) -> None:
    """FD-005: All task IDs must be unique across all descriptor files."""
    if not TD_DIR.exists():
        return
    
    all_ids: Set[str] = set()
    duplicates: Dict[str, List[str]] = {}
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        for item in status_path.iterdir():
            if not item.is_dir():
                continue
            
            # Check epic.yaml
            epic_yaml = item / "epic.yaml"
            if epic_yaml.exists():
                try:
                    with open(epic_yaml, 'r') as f:
                        data = yaml.safe_load(f)
                    task_id = data.get("id")
                    if task_id:
                        if task_id in all_ids:
                            duplicates.setdefault(task_id, []).append(str(epic_yaml))
                        else:
                            all_ids.add(task_id)
                except:
                    pass
            
            # Check task.yaml files
            tasks_dir = item / "tasks"
            if tasks_dir.exists():
                for task_dir in tasks_dir.iterdir():
                    if not task_dir.is_dir():
                        continue
                    task_yaml = task_dir / "task.yaml"
                    if task_yaml.exists():
                        try:
                            with open(task_yaml, 'r') as f:
                                data = yaml.safe_load(f)
                            task_id = data.get("id")
                            if task_id:
                                if task_id in all_ids:
                                    duplicates.setdefault(task_id, []).append(str(task_yaml))
                                else:
                                    all_ids.add(task_id)
                        except:
                            pass
    
    for task_id, paths in duplicates.items():
        result.add_error("FD-005", f"Duplicate ID '{task_id}' found in: {', '.join(paths)}")


def get_relative_proof_path(proof_path: str) -> str:
    """Extract relative path from proof path. Handles both relative and absolute paths."""
    if proof_path.startswith("Docs/proofs/"):
        return proof_path[len("Docs/proofs/"):]
    return proof_path


def rule_fd_006_proof_paths(result: ValidationResult, check_proofs_exist: bool = True) -> None:
    """FD-006: Proof paths must be valid and point to Docs/proofs/."""
    if not TD_DIR.exists():
        return
    
    if not PROOFS_DIR.exists():
        result.add_warning("FD-006", f"Docs/proofs/ directory does not exist")
        return
    
    all_proofs: Set[str] = set()
    invalid_proofs: List[Tuple[str, str]] = []
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        for item in status_path.iterdir():
            if not item.is_dir():
                continue
            
            # Check epic.yaml proofs
            epic_yaml = item / "epic.yaml"
            if epic_yaml.exists():
                try:
                    with open(epic_yaml, 'r') as f:
                        data = yaml.safe_load(f)
                    proofs = data.get("proofs", []) or data.get("proof", [])
                    for proof_path in proofs:
                        all_proofs.add(proof_path)
                        relative_path = get_relative_proof_path(proof_path)
                        if not proof_path.startswith("Docs/proofs/"):
                            invalid_proofs.append((str(epic_yaml), proof_path))
                        elif check_proofs_exist and not (PROOFS_DIR / relative_path).exists():
                            result.add_error("FD-006", f"Proof file does not exist: {proof_path}", str(epic_yaml))
                except:
                    pass
            
            # Check task.yaml proofs
            tasks_dir = item / "tasks"
            if tasks_dir.exists():
                for task_dir in tasks_dir.iterdir():
                    if not task_dir.is_dir():
                        continue
                    task_yaml = task_dir / "task.yaml"
                    if task_yaml.exists():
                        try:
                            with open(task_yaml, 'r') as f:
                                data = yaml.safe_load(f)
                            for proof_path in data.get("proof", []):
                                all_proofs.add(proof_path)
                                relative_path = get_relative_proof_path(proof_path)
                                if not proof_path.startswith("Docs/proofs/"):
                                    invalid_proofs.append((str(task_yaml), proof_path))
                                elif check_proofs_exist and not (PROOFS_DIR / relative_path).exists():
                                    result.add_error("FD-006", f"Proof file does not exist: {proof_path}", str(task_yaml))
                        except:
                            pass
    
    for yaml_path, proof_path in invalid_proofs:
        result.add_warning("FD-006", f"Proof path should start with 'Docs/proofs/': {proof_path}", yaml_path)


def rule_fd_007_source_docs(result: ValidationResult) -> None:
    """FD-007: Source docs paths must exist."""
    if not TD_DIR.exists():
        return
    
    invalid_docs: List[Tuple[str, str]] = []
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        for item in status_path.iterdir():
            if not item.is_dir():
                continue
            
            # Check epic.yaml source_docs
            epic_yaml = item / "epic.yaml"
            if epic_yaml.exists():
                try:
                    with open(epic_yaml, 'r') as f:
                        data = yaml.safe_load(f)
                    for doc_path in data.get("source_docs", []):
                        full_path = REPO_ROOT / doc_path
                        if not full_path.exists():
                            invalid_docs.append((str(epic_yaml), doc_path))
                except:
                    pass
            
            # Check task.yaml source_docs
            tasks_dir = item / "tasks"
            if tasks_dir.exists():
                for task_dir in tasks_dir.iterdir():
                    if not task_dir.is_dir():
                        continue
                    task_yaml = task_dir / "task.yaml"
                    if task_yaml.exists():
                        try:
                            with open(task_yaml, 'r') as f:
                                data = yaml.safe_load(f)
                            for doc_path in data.get("source_docs", []):
                                full_path = REPO_ROOT / doc_path
                                if not full_path.exists():
                                    invalid_docs.append((str(task_yaml), doc_path))
                        except:
                            pass
    
    for yaml_path, doc_path in invalid_docs:
        result.add_warning("FD-007", f"Source doc does not exist: {doc_path}", yaml_path)


def rule_fd_008_yaml_valid(result: ValidationResult) -> None:
    """FD-008: All YAML files must be valid YAML and parse successfully."""
    if not TD_DIR.exists():
        return
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        for root, dirs, files in os.walk(status_path):
            for file in files:
                if file.endswith('.yaml'):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r') as f:
                            yaml.safe_load(f)
                    except yaml.YAMLError as e:
                        result.add_error("FD-008", f"Invalid YAML: {e}", str(file_path))
                    except Exception as e:
                        result.add_error("FD-008", f"Cannot read file: {e}", str(file_path))


def rule_fd_009_verification_profiles(result: ValidationResult) -> None:
    """FD-009: Verification profiles referenced in descriptors must exist in verification-profiles.yaml."""
    profiles_manifest = REPO_ROOT / "Docs" / "manifests" / "verification-profiles.yaml"
    
    if not profiles_manifest.exists():
        result.add_warning("FD-009", "verification-profiles.yaml not found, skipping profile validation")
        return
    
    # Load verification profiles
    try:
        with open(profiles_manifest, 'r') as f:
            profiles_data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        result.add_error("FD-009", f"Cannot parse verification-profiles.yaml: {e}")
        return
    
    valid_profiles = set()
    if "profiles" in profiles_data:
        for profile in profiles_data["profiles"]:
            valid_profiles.add(profile.get("id", ""))
    
    if not valid_profiles:
        result.add_warning("FD-009", "No profiles found in verification-profiles.yaml")
        return
    
    # Check all epic and task descriptors
    invalid_profiles: List[Tuple[str, str, str]] = []
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        for root, dirs, files in os.walk(status_path):
            for file in files:
                if file.endswith('.yaml'):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r') as f:
                            descriptor = yaml.safe_load(f) or {}
                        
                        profiles = descriptor.get("verification_profiles", [])
                        if profiles:
                            for profile_id in profiles:
                                if profile_id not in valid_profiles:
                                    invalid_profiles.append((str(file_path), str(descriptor.get("id", "unknown")), profile_id))
                    except yaml.YAMLError:
                        pass
    
    for file_path, task_id, profile_id in invalid_profiles:
        result.add_error("FD-009", f"Task '{task_id}' references unknown verification profile '{profile_id}'", file_path)


def rule_fd_010_gc_policy(result: ValidationResult) -> None:
    """FD-010: GC policies in descriptors must be valid."""
    valid_gc_policies = {"retain_all", "compact_on_complete", "compact_on_done", "archive_only"}
    valid_context_policies = {"eager", "lazy", "on_demand", "minimal"}
    active_statuses = {"new", "ready", "in_progress", "in_review"}
    
    invalid_gc: List[Tuple[str, str, str]] = []
    invalid_context: List[Tuple[str, str, str]] = []
    active_aggressive: List[Tuple[str, str, str]] = []
    
    for status_dir in VALID_STATUS_DIRS:
        status_path = TD_DIR / status_dir
        if not status_path.exists():
            continue
        
        for root, dirs, files in os.walk(status_path):
            for file in files:
                if file.endswith('.yaml'):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r') as f:
                            descriptor = yaml.safe_load(f) or {}
                        
                        task_id = descriptor.get("id", "unknown")
                        status = descriptor.get("status", "")
                        
                        # Check gc_policy
                        gc_policy = descriptor.get("gc_policy")
                        if gc_policy and gc_policy not in valid_gc_policies:
                            invalid_gc.append((str(file_path), task_id, gc_policy))
                        
                        # Check context_load_policy
                        context_policy = descriptor.get("context_load_policy")
                        if context_policy and context_policy not in valid_context_policies:
                            invalid_context.append((str(file_path), task_id, context_policy))
                        
                        # Check active tasks don't have aggressive GC
                        if status in active_statuses and gc_policy in ["compact_on_done", "archive_only"]:
                            active_aggressive.append((str(file_path), task_id, gc_policy))
                    except yaml.YAMLError:
                        pass
    
    for file_path, task_id, policy in invalid_gc:
        result.add_error("FD-010", f"Task '{task_id}' has invalid gc_policy '{policy}'", file_path)
    
    for file_path, task_id, policy in invalid_context:
        result.add_error("FD-010", f"Task '{task_id}' has invalid context_load_policy '{policy}'", file_path)
    
    for file_path, task_id, policy in active_aggressive:
        result.add_error("FD-010", f"Active task '{task_id}' (status: {status_dir}) has aggressive gc_policy '{policy}'", file_path)


# =============================================================================
# Main
# =============================================================================


def run_validation(check_proofs_exist: bool = True, verbose: bool = False) -> ValidationResult:
    """Run all validation rules. Returns ValidationResult."""
    result = ValidationResult()
    
    # Run all validation rules
    rule_fd_001_structure(result)
    rule_fd_002_epic_files(result)
    rule_fd_003_child_tasks(result)
    rule_fd_004_status_match(result)
    rule_fd_005_unique_ids(result)
    rule_fd_006_proof_paths(result, check_proofs_exist)
    rule_fd_007_source_docs(result)
    rule_fd_008_yaml_valid(result)
    rule_fd_009_verification_profiles(result)
    rule_fd_010_gc_policy(result)
    
    # Print results if verbose
    if verbose:
        if result.infos:
            print("\nINFO:")
            for info in result.infos:
                print(f"  {info}")
        
        if result.warnings:
            print("\nWARNINGS:")
            for warning in result.warnings:
                print(f"  {warning}")
    
    return result


def print_results(result: ValidationResult, verbose: bool = False) -> None:
    """Print validation results."""
    print(f"\n{'='*70}")
    print("VALIDATION RESULTS")
    print(f"{'='*70}")
    
    # Counts
    print(f"\nDescriptor Counts:")
    print(f"  Epics: {result.counts['epics']}")
    print(f"  Tasks: {result.counts['tasks']}")
    print(f"  Files: {result.counts['files']}")
    
    # Errors
    if result.errors:
        print(f"\n[FAILED] {len(result.errors)} error(s):")
        for error in result.errors:
            print(f"  {error}")
    
    # Warnings
    if result.warnings:
        print(f"\n[WARNED] {len(result.warnings)} warning(s):")
        for warning in result.warnings:
            print(f"  {warning}")
    
    # Success
    if result.is_valid() and not result.warnings:
        print(f"\n[PASSED] All validations passed")
    elif result.is_valid():
        print(f"\n[PASSED] No errors (warnings exist)")
    else:
        print(f"\n[FAILED] Validation failed")
    
    print(f"\n{'='*70}")


def main():
    parser = argparse.ArgumentParser(
        description="Validate Docs/td/ folder system structure"
    )
    parser.add_argument(
        "--no-proof-check",
        action="store_true",
        default=False,
        help="Skip checking if proof files actually exist"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        default=False,
        help="Verbose output"
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        default=False,
        help="Only print pass/fail and exit code"
    )
    
    args = parser.parse_args()
    verbose = args.verbose and not args.quiet
    
    # Run validation
    result = run_validation(
        check_proofs_exist=not args.no_proof_check,
        verbose=verbose
    )
    
    # Print results
    if args.quiet:
        if result.is_valid():
            print("VALIDATION PASSED")
        else:
            print("VALIDATION FAILED")
    else:
        print_results(result, verbose=verbose)
    
    sys.exit(result.exit_code())


if __name__ == "__main__":
    main()
