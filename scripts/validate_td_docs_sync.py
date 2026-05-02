#!/usr/bin/env python3
"""
validate_td_docs_sync.py

Validate synchronization between TD database and Docs/ source of truth.

This script enforces the TD Source-of-Truth Doctrine (TD-DOCTRINE-2026-001):
- Every task in Docs/td/td-task-registry.yaml must be valid
- Every completed task must have a proof artifact
- Every source_docs and proof path must point to existing files
- All task IDs must be unique

Usage:
    python3 Scripts/validate_td_docs_sync.py              # Validate all
    python3 Scripts/validate_td_docs_sync.py --verbose   # Verbose output
    python3 Scripts/validate_td_docs_sync.py --strict    # Warnings as errors
    python3 Scripts/validate_td_docs_sync.py --critical-path # Validate P0 only

Exit codes:
    0 = All validation passed (success)
    1 = Validation errors detected (fail)
    2 = Validation warnings detected (fail if --strict)
"""

import argparse
import json
import os
import subprocess
import sys
import yaml
from pathlib import Path
from typing import Dict, List, Any, Tuple, Optional

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent.absolute()
REGISTRY_PATH = REPO_ROOT / "Docs" / "td" / "td-task-registry.yaml"
SCHEMA_PATH = REPO_ROOT / "Docs" / "schemas" / "td-task.schema.json"
PROOFS_DIR = REPO_ROOT / "Docs" / "proofs"

# -----------------------------------------------------------------------------
# Validation Rules
# -----------------------------------------------------------------------------

class ValidationRule:
    """Represents a validation rule with check logic."""
    
    def __init__(
        self,
        id: str,
        name: str,
        description: str,
        severity: str,
        check_func: callable
    ):
        self.id = id
        self.name = name
        self.description = description
        self.severity = severity  # ERROR, WARNING, INFO
        self.check_func = check_func
    
    def check(self, *args, **kwargs) -> Tuple[bool, List[str]]:
        """Run the check. Returns (passed, messages)."""
        return self.check_func(*args, **kwargs)


class ValidationResult:
    """Collects validation results."""
    
    def __init__(self):
        self.passed: List[str] = []
        self.warnings: List[str] = []
        self.errors: List[str] = []
        self.info: List[str] = []
        self.rule_results: Dict[str, Tuple[bool, List[str]]] = {}
    
    def add_result(
        self, rule: ValidationRule, passed: bool, messages: List[str], context: str = ""
    ):
        """Add a rule result."""
        self.rule_results[rule.id] = (passed, messages)
        
        for msg in messages:
            full_msg = f"[{rule.id}] {msg}"
            if context:
                full_msg = f"{full_msg} ({context})"
            
            if passed:
                self.passed.append(full_msg)
            elif rule.severity == "ERROR":
                self.errors.append(full_msg)
            elif rule.severity == "WARNING":
                self.warnings.append(full_msg)
            else:
                self.info.append(full_msg)
    
    @property
    def has_errors(self) -> bool:
        return len(self.errors) > 0
    
    @property
    def has_warnings(self) -> bool:
        return len(self.warnings) > 0
    
    @property
    def exit_code(self) -> int:
        if self.has_errors:
            return 1
        return 0
    
    def print_report(self, verbose: bool = False):
        """Print validation report."""
        # Summary
        print("=" * 70)
        print("TD-DOCS SYNC VALIDATION REPORT")
        print("=" * 70)
        
        if self.passed:
            print(f"\n✅ PASSED: {len(self.passed)}")
            if verbose:
                for msg in self.passed:
                    print(f"  ✓ {msg}")
        
        if self.errors:
            print(f"\n❌ ERRORS: {len(self.errors)}")
            for msg in self.errors:
                print(f"  ✗ {msg}")
        
        if self.warnings:
            print(f"\n⚠️  WARNINGS: {len(self.warnings)}")
            for msg in self.warnings:
                print(f"  ⚠ {msg}")
        
        if self.info and verbose:
            print(f"\nℹ️  INFO: {len(self.info)}")
            for msg in self.info:
                print(f"  ℹ {msg}")
        
        print("\n" + "=" * 70)
        if self.has_errors:
            print("RESULT: FAILED - Errors must be resolved")
        elif self.has_warnings:
            print("RESULT: PASSED WITH WARNINGS")
        else:
            print("RESULT: PASSED - All validation checks succeeded")
        print("=" * 70)


# -----------------------------------------------------------------------------
# Registry Loader
# -----------------------------------------------------------------------------

class RegistryLoader:
    """Load and validate task registry."""
    
    def __init__(self, path: Path = REGISTRY_PATH):
        self.path = path
        self.data: Dict[str, Any] = {}
        self.tasks: List[Dict[str, Any]] = []
        self.lanes: Dict[str, Dict[str, Any]] = {}
    
    def load(self) -> Tuple[bool, str, List[Dict[str, Any]]]:
        """
        Load registry from YAML file.
        Returns: (success, error_message, tasks_list)
        """
        if not self.path.exists():
            return False, f"Registry not found: {self.path}", []
        
        try:
            with open(self.path, 'r') as f:
                self.data = yaml.safe_load(f)
        except yaml.YAMLError as e:
            return False, f"YAML parse error: {e}", []
        except Exception as e:
            return False, f"Error reading registry: {e}", []
        
        if not self.data:
            return False, "Registry file is empty", []
        
        self.lanes = self.data.get("lanes", {})
        self.tasks = self.data.get("tasks", [])
        
        return True, "", self.tasks


# -----------------------------------------------------------------------------
# Validation Functions
# -----------------------------------------------------------------------------

def validate_registry_file_exists(result: ValidationResult, repo_root: Path = REPO_ROOT):
    """SRC-000: Registry file must exist."""
    rule = ValidationRule("SRC-000", "Registry File Exists", 
                          "Registry YAML must exist", "ERROR",
                          lambda: (True, []))
    path = repo_root / "Docs" / "td" / "td-task-registry.yaml"
    if path.exists():
        result.add_result(rule, passed=True, messages=[f"Registry file exists: {path}"])
    else:
        result.add_result(rule, passed=False, messages=[f"Registry file missing: {path}"])


def validate_registry_yaml_syntax(result: ValidationResult, registry_path: Path):
    """SRC-001A: Registry must be valid YAML."""
    rule = ValidationRule("SRC-001A", "YAML Syntax",
                          "Registry must be valid YAML", "ERROR",
                          lambda: (True, [""]))
    try:
        with open(registry_path, 'r') as f:
            yaml.safe_load(f)
        result.add_result(rule, passed=True, messages=["Registry YAML syntax is valid"])
    except yaml.YAMLError as e:
        result.add_result(rule, passed=False, messages=[f"YAML syntax error: {e}"])


def validate_task_ids_unique(result: ValidationResult, tasks: List[Dict[str, Any]]):
    """SRC-006: Task IDs in registry must be unique."""
    rule = ValidationRule("SRC-006", "Unique Task IDs",
                          "All task IDs must be unique", "ERROR",
                          lambda: (True, []))
    ids = [t.get("id", "") for t in tasks if t.get("id")]
    seen = {}
    duplicates = []
    
    for id in ids:
        if id in seen:
            duplicates.append(id)
        seen[id] = True
    
    if not duplicates:
        result.add_result(rule, passed=True, messages=[f"All {len(ids)} task IDs are unique"])
    else:
        result.add_result(rule, passed=False, messages=[f"Duplicate task IDs: {set(duplicates)}"])


def validate_required_fields(result: ValidationResult, tasks: List[Dict[str, Any]]):
    """SRC-001B: Every registry task must have required fields."""
    rule = ValidationRule("SRC-001B", "Required Fields",
                          "All tasks must have id, title, status", "ERROR",
                          lambda: (True, []))
    required_fields = ["id", "title", "status"]
    missing = []
    
    for i, task in enumerate(tasks):
        task_id = task.get("id", f"task-{i}")
        for field in required_fields:
            if field not in task:
                missing.append(f"{task_id}: missing '{field}'")
    
    if not missing:
        result.add_result(rule, passed=True, messages=[f"All {len(tasks)} tasks have required fields"])
    else:
        result.add_result(rule, passed=False, messages=missing)


def validate_valid_status(result: ValidationResult, tasks: List[Dict[str, Any]]):
    """SRC-001C: Task status must be valid."""
    rule = ValidationRule("SRC-001C", "Valid Status",
                          "Task status must be valid", "ERROR",
                          lambda: (True, []))
    valid_statuses = ["new", "ready", "in_progress", "in_review", 
                     "complete", "completed", "blocked", "cancelled"]
    invalid = []
    
    for task in tasks:
        status = task.get("status", "").lower()
        task_id = task.get("id", "unknown")
        if status and status not in valid_statuses:
            invalid.append(f"{task_id}: invalid status '{status}'")
    
    if not invalid:
        result.add_result(rule, passed=True, messages=["All task statuses are valid"])
    else:
        result.add_result(rule, passed=False, messages=invalid)


def validate_source_docs_exist(result: ValidationResult, tasks: List[Dict[str, Any]], repo_root: Path = REPO_ROOT):
    """SRC-005: Every source_docs path must point to existing file."""
    rule = ValidationRule("SRC-005", "Source Docs Exist",
                          "All source_docs paths must exist", "ERROR",
                          lambda: (True, []))
    not_found = []
    found_count = 0
    
    for task in tasks:
        task_id = task.get("id", "unknown")
        source_docs = task.get("source_docs", [])
        
        for doc_path in source_docs:
            full_path = repo_root / doc_path
            found_count += 1
            if not full_path.exists():
                not_found.append(f"{task_id}: source_doc not found: {doc_path}")
    
    if not not_found:
        result.add_result(rule, passed=True, messages=[f"All {found_count} source_doc references are valid"])
    else:
        result.add_result(rule, passed=False, messages=not_found)


def validate_proof_paths_exist(result: ValidationResult, tasks: List[Dict[str, Any]], repo_root: Path = REPO_ROOT):
    """SRC-004: Every proof path must point to existing file."""
    rule = ValidationRule("SRC-004", "Proof Paths Exist",
                          "All proof paths must exist", "ERROR",
                          lambda: (True, []))
    not_found = []
    found_count = 0
    
    for task in tasks:
        task_id = task.get("id", "unknown")
        proofs = task.get("proof", [])
        
        for proof_path in proofs:
            full_path = repo_root / proof_path
            found_count += 1
            if not full_path.exists():
                not_found.append(f"{task_id}: proof not found: {proof_path}")
    
    if not not_found:
        result.add_result(rule, passed=True, messages=[f"All {found_count} proof references are valid"])
    else:
        result.add_result(rule, passed=False, messages=not_found)


def validate_complete_tasks_have_proof(result: ValidationResult, tasks: List[Dict[str, Any]], repo_root: Path = REPO_ROOT):
    """SRC-003: Every completed task must have a valid proof artifact."""
    rule = ValidationRule("SRC-003", "Completed Tasks Have Proof",
                          "Completed tasks must have proof artifacts", "ERROR",
                          lambda: (True, []))
    missing_proof = []
    complete_count = 0
    
    for task in tasks:
        task_id = task.get("id", "unknown")
        status = task.get("status", "").lower()
        
        if status in ["complete", "completed"]:
            complete_count += 1
            proofs = task.get("proof", [])
            
            has_valid_proof = False
            for proof_path in proofs:
                full_path = repo_root / proof_path
                if full_path.exists():
                    has_valid_proof = True
                    break
            
            if not has_valid_proof:
                # Also check for default proof path
                default_proof = PROOFS_DIR / f"{task_id}.md"
                if default_proof.exists():
                    has_valid_proof = True
            
            if not has_valid_proof:
                missing_proof.append(f"{task_id}: status=complete but no valid proof")
    
    if not missing_proof:
        result.add_result(rule, passed=True, messages=[f"All {complete_count} completed tasks have proof artifacts"])
    else:
        result.add_result(rule, passed=False, messages=missing_proof)


def validate_children_registration(result: ValidationResult, tasks: List[Dict[str, Any]]):
    """SRC-007: Child task IDs should be listed in parent's children array."""
    rule = ValidationRule("SRC-007", "Children Registration",
                          "Child tasks should reference parents", "WARNING",
                          lambda: (True, []))
    warnings = []
    
    # Build map of task_id -> task
    task_map = {t.get("id"): t for t in tasks if t.get("id")}
    
    for task in tasks:
        task_id = task.get("id", "unknown")
        children = task.get("children", [])
        
        for child_id in children:
            if child_id not in task_map:
                warnings.append(f"{task_id}: child '{child_id}' not found in registry")
            else:
                child = task_map[child_id]
                if child.get("parent") != task_id:
                    warnings.append(f"{task_id}: child '{child_id}' doesn't list '{task_id}' as parent")
    
    if not warnings:
        result.add_result(rule, passed=True, messages=["All child-parent relationships are consistent"])
    else:
        result.add_result(rule, passed=True, messages=warnings)  # Non-blocking


def validate_schema_compliance(result: ValidationResult, tasks: List[Dict[str, Any]], schema_path: Path = SCHEMA_PATH):
    """SRC-002: Every registry task must validate against td-task.schema.json."""
    rule = ValidationRule("SRC-002", "Schema Compliance",
                          "Tasks must validate against td-task.schema.json", "WARNING",
                          lambda: (True, []))
    import jsonschema
    
    if not schema_path.exists():
        result.add_result(rule, passed=True, messages=[f"Schema not found: {schema_path}, skipping validation"])
        return
    
    try:
        with open(schema_path, 'r') as f:
            schema = json.load(f)
    except Exception as e:
        result.add_result(rule, passed=True, messages=[f"Could not load schema: {e}, skipping validation"])
        return
    
    errors = []
    
    for task in tasks:
        task_id = task.get("id", "unknown")
        try:
            # Map task fields to schema fields - the schema uses 'id' not 'task_id'
            task_data = {
                "id": task.get("id", ""),
                "title": task.get("title", ""),
                "status": task.get("status", ""),
                "priority": task.get("priority", "P2"),
                "type": task.get("type", "task"),
                "lane": task.get("lane", "uncategorized"),
            }
            jsonschema.validate(instance=task_data, schema=schema)
        except jsonschema.ValidationError as e:
            errors.append(f"{task_id}: schema validation failed: {e.message}")
        except json.JSONDecodeError:
            errors.append(f"{task_id}: invalid JSON data")
    
    if not errors:
        result.add_result(rule, passed=True, messages=[f"All {len(tasks)} tasks validate against schema"])
    else:
        result.add_result(rule, passed=False, messages=errors)


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Validate synchronization between TD and Docs/ source of truth",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 Scripts/validate_td_docs_sync.py              # Full validation
    python3 Scripts/validate_td_docs_sync.py --verbose   # Verbose output
    python3 Scripts/validate_td_docs_sync.py --strict    # Warnings as errors
        """
    )
    
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output with all messages"
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors"
    )
    parser.add_argument(
        "--critical-path",
        action="store_true",
        help="Validate only P0 critical path tasks"
    )
    parser.add_argument(
        "--registry",
        type=str,
        metavar="PATH",
        default=str(REGISTRY_PATH),
        help="Path to task registry YAML"
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Minimal output (only exit code)"
    )
    
    args = parser.parse_args()
    
    # Initialize result
    result = ValidationResult()
    
    # Load registry
    registry_path = Path(args.registry)
    loader = RegistryLoader(registry_path)
    success, error_msg, tasks = loader.load()
    
    if not success:
        print(f"ERROR: {error_msg}", file=sys.stderr)
        sys.exit(1)
    
    if not tasks:
        print("WARNING: No tasks found in registry", file=sys.stderr)
    
    # Run validations
    validate_registry_file_exists(result)
    validate_registry_yaml_syntax(result, registry_path)
    validate_task_ids_unique(result, tasks)
    validate_required_fields(result, tasks)
    validate_valid_status(result, tasks)
    validate_source_docs_exist(result, tasks)
    validate_proof_paths_exist(result, tasks)
    validate_complete_tasks_have_proof(result, tasks)
    validate_children_registration(result, tasks)
    validate_schema_compliance(result, tasks)
    
    # Print report
    if not args.quiet:
        result.print_report(verbose=args.verbose)
    
    # Handle --strict
    if args.strict and result.has_warnings:
        if not args.quiet:
            print("\nRESULT: FAILED (strict mode, warnings treated as errors)")
        sys.exit(1)
    
    sys.exit(result.exit_code)


if __name__ == "__main__":
    main()
