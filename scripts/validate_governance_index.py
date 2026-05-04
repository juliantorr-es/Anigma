#!/usr/bin/env python3
"""
Validate Governance Runtime Index against schema and business rules.

This script ensures the generated governance index is valid and can be safely
consumed by the daemon at runtime.
"""

import json
import sys
import os
from pathlib import Path
from typing import Dict, List, Any
from jsonschema import validate, ValidationError
import yaml

# Add project root to path for imports
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


def load_schema() -> Dict[str, Any]:
    """Load the governance runtime index schema."""
    schema_path = PROJECT_ROOT / "Docs" / "schemas" / "governance-runtime-index.schema.json"
    
    try:
        with open(schema_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Error loading schema: {e}")
        raise


def load_index(index_path: Path) -> Dict[str, Any]:
    """Load the governance runtime index."""
    try:
        with open(index_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Error loading index: {e}")
        raise


def validate_schema(index: Dict[str, Any], schema: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Validate index against JSON schema."""
    errors = []
    
    try:
        validate(instance=index, schema=schema)
        print("✅ Schema validation passed")
        return errors
    except ValidationError as e:
        error_msg = f"Schema validation failed: {e.message}"
        if e.path:
            error_msg += f" at {'/'.join(str(p) for p in e.path)}"
        errors.append({
            "code": "SCHEMA-001",
            "message": error_msg,
            "severity": "ERROR",
            "details": {
                "validator": e.validator,
                "validator_value": e.validator_value,
                "instance": e.instance
            }
        })
        return errors


def validate_business_rules(index: Dict[str, Any]) -> Dict[str, List[Dict[str, Any]]]:
    """Validate business rules that can't be expressed in JSON schema."""
    results = {
        "warnings": [],
        "errors": []
    }
    
    # Rule 1: All task IDs must be unique
    task_ids = [task['id'] for task in index.get('td_tasks', [])]
    if len(task_ids) != len(set(task_ids)):
        duplicates = [task_id for task_id in task_ids if task_ids.count(task_id) > 1]
        results["errors"].append({
            "code": "BR-001",
            "message": f"Duplicate task IDs found: {', '.join(duplicates)}",
            "severity": "ERROR"
        })
    
    # Rule 2: All source files must exist
    source_files = index.get('source_files', {})
    for file_type, file_list in source_files.items():
        if isinstance(file_list, list):
            for file_path in file_list:
                if not os.path.exists(file_path):
                    results["errors"].append({
                        "code": "BR-002",
                        "message": f"Source file not found: {file_path}",
                        "severity": "ERROR",
                        "details": {
                            "file_type": file_type,
                            "file_path": file_path
                        }
                    })
    
    # Rule 3: TD registry must contain tasks
    td_tasks = index.get('td_tasks', [])
    if len(td_tasks) == 0:
        results["errors"].append({
            "code": "BR-003",
            "message": "No TD tasks found in index",
            "severity": "ERROR"
        })
    
    # Rule 4: All tasks must have required fields
    required_task_fields = ['id', 'title', 'priority', 'type', 'lane', 'status']
    for task in td_tasks:
        for field in required_task_fields:
            if field not in task or not task[field]:
                results["errors"].append({
                    "code": "BR-004",
                    "message": f"Task {task.get('id', 'unknown')} missing required field: {field}",
                    "severity": "ERROR",
                    "details": {
                        "task_id": task.get('id', 'unknown'),
                        "missing_field": field
                    }
                })
    
    # Rule 5: Governance policies must have required fields
    required_policy_fields = ['id', 'title', 'source_file']
    for policy in index.get('governance_policies', []):
        for field in required_policy_fields:
            if field not in policy or not policy[field]:
                results["errors"].append({
                    "code": "BR-005",
                    "message": f"Policy {policy.get('id', 'unknown')} missing required field: {field}",
                    "severity": "ERROR",
                    "details": {
                        "policy_id": policy.get('id', 'unknown'),
                        "missing_field": field
                    }
                })
    
    # Rule 6: Check that source files are relative to project root
    for file_type, file_list in source_files.items():
        if isinstance(file_list, list):
            for file_path in file_list:
                if not file_path.startswith(str(PROJECT_ROOT)):
                    results["warnings"].append({
                        "code": "BR-006",
                        "message": f"Source file path may not be relative to project root: {file_path}",
                        "severity": "WARNING",
                        "details": {
                            "file_type": file_type,
                            "file_path": file_path
                        }
                    })
    
    return results


def validate_against_td_registry(index: Dict[str, Any]) -> Dict[str, List[Dict[str, Any]]]:
    """Validate that index tasks match the TD registry."""
    results = {
        "warnings": [],
        "errors": []
    }
    
    # Load the original TD registry
    registry_path = index['source_files']['td_registry']
    try:
        with open(registry_path, 'r', encoding='utf-8') as f:
            registry_data = yaml.safe_load(f)
    except Exception as e:
        results["errors"].append({
            "code": "TD-001",
            "message": f"Could not load TD registry: {e}",
            "severity": "ERROR"
        })
        return results
    
    # Compare task counts
    registry_tasks = registry_data.get('tasks', [])
    index_tasks = index.get('td_tasks', [])
    
    if len(registry_tasks) != len(index_tasks):
        results["errors"].append({
            "code": "TD-002",
            "message": f"Task count mismatch: registry has {len(registry_tasks)}, index has {len(index_tasks)}",
            "severity": "ERROR",
            "details": {
                "registry_count": len(registry_tasks),
                "index_count": len(index_tasks)
            }
        })
    
    # Check that all registry tasks are in the index
    registry_ids = {task['id'] for task in registry_tasks}
    index_ids = {task['id'] for task in index_tasks}
    
    missing_ids = registry_ids - index_ids
    if missing_ids:
        results["errors"].append({
            "code": "TD-003",
            "message": f"Tasks in registry but missing from index: {', '.join(missing_ids)}",
            "severity": "ERROR",
            "details": {
                "missing_ids": list(missing_ids)
            }
        })
    
    extra_ids = index_ids - registry_ids
    if extra_ids:
        results["warnings"].append({
            "code": "TD-004",
            "message": f"Tasks in index but not in registry: {', '.join(extra_ids)}",
            "severity": "WARNING",
            "details": {
                "extra_ids": list(extra_ids)
            }
        })
    
    return results


def main():
    """Main entry point."""
    # Default index path
    index_path = PROJECT_ROOT / ".build" / "governance-runtime-index.json"
    
    # Allow override via command line
    if len(sys.argv) > 1:
        index_path = Path(sys.argv[1])
    
    print(f"🔍 Validating governance index at: {index_path}")
    
    try:
        # Load schema and index
        schema = load_schema()
        index = load_index(index_path)
        
        # Validate schema
        schema_errors = validate_schema(index, schema)
        
        # Validate business rules
        business_results = validate_business_rules(index)
        
        # Validate against TD registry
        td_results = validate_against_td_registry(index)
        
        # Combine all results
        all_errors = schema_errors + business_results["errors"] + td_results["errors"]
        all_warnings = business_results["warnings"] + td_results["warnings"]
        
        # Print summary
        print(f"\n📊 Validation Summary:")
        print(f"   - Errors: {len(all_errors)}")
        print(f"   - Warnings: {len(all_warnings)}")
        
        if all_errors:
            print("\n❌ Validation Errors:")
            for error in all_errors:
                print(f"   - [{error['code']}] {error['message']}")
                if 'details' in error:
                    print(f"     Details: {error['details']}")
        
        if all_warnings:
            print("\n⚠️  Validation Warnings:")
            for warning in all_warnings:
                print(f"   - [{warning['code']}] {warning['message']}")
                if 'details' in warning:
                    print(f"     Details: {warning['details']}")
        
        # Determine overall validity
        is_valid = len(all_errors) == 0
        
        if is_valid:
            print("\n✅ Governance index is valid!")
            return 0
        else:
            print(f"\n❌ Governance index is invalid with {len(all_errors)} errors")
            return 1
            
    except Exception as e:
        print(f"❌ Fatal error during validation: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
