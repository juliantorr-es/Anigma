#!/usr/bin/env python3
"""
Generate Governance Runtime Index from Docs/, TD task records, schemas, and manifests.

This script creates a machine-readable JSON index suitable for daemon startup ingestion,
eliminating the need for runtime Markdown/YAML traversal.
"""

import json
import yaml
import os
import hashlib
import subprocess
from datetime import datetime
from typing import Dict, List, Any, Optional
from pathlib import Path
import sys

# Add project root to path for imports
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


def get_git_commit_info() -> Dict[str, Any]:
    """Get current git commit information."""
    try:
        # Get commit hash
        hash_result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT
        )
        commit_hash = hash_result.stdout.strip() if hash_result.returncode == 0 else "unknown"

        # Get commit timestamp
        timestamp_result = subprocess.run(
            ["git", "show", "-s", "--format=%ci", "HEAD"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT
        )
        commit_timestamp = timestamp_result.stdout.strip() if timestamp_result.returncode == 0 else datetime.utcnow().isoformat()

        # Get commit message
        message_result = subprocess.run(
            ["git", "show", "-s", "--format=%B", "HEAD"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT
        )
        commit_message = message_result.stdout.strip() if message_result.returncode == 0 else ""

        return {
            "hash": commit_hash,
            "timestamp": commit_timestamp,
            "message": commit_message
        }
    except Exception as e:
        print(f"Warning: Could not get git commit info: {e}")
        return {
            "hash": "unknown",
            "timestamp": datetime.utcnow().isoformat(),
            "message": ""
        }


def find_source_files() -> Dict[str, List[str]]:
    """Find all relevant source files for governance index."""
    docs_dir = PROJECT_ROOT / "Docs"
    
    source_files = {
        "td_registry": str(docs_dir / "td" / "td-task-registry.yaml"),
        "governance_docs": [],
        "schemas": [],
        "manifests": []
    }

    # Find governance docs
    governance_dir = docs_dir / "governance"
    if governance_dir.exists():
        for file_path in governance_dir.glob("*.md"):
            source_files["governance_docs"].append(str(file_path))

    # Find schemas
    schemas_dir = docs_dir / "schemas"
    if schemas_dir.exists():
        for file_path in schemas_dir.glob("*.json"):
            source_files["schemas"].append(str(file_path))

    # Find manifests
    manifests_dir = docs_dir / "manifests"
    if manifests_dir.exists():
        for file_path in manifests_dir.glob("*.yaml"):
            source_files["manifests"].append(str(file_path))

    return source_files


def extract_governance_policies(source_files: Dict[str, List[str]]) -> List[Dict[str, Any]]:
    """Extract governance policies from documentation files."""
    policies = []
    
    # Extract from TD source of truth doctrine
    td_doctrine_path = Path(source_files["governance_docs"][0]) if source_files["governance_docs"] else None
    if td_doctrine_path and "TD_SOURCE_OF_TRUTH_DOCTRINE" in str(td_doctrine_path):
        try:
            with open(td_doctrine_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            policies.append({
                "id": "td-source-of-truth",
                "title": "TD Source of Truth Doctrine",
                "description": "Establishes Docs/ as the durable source of truth and TD as the local execution queue",
                "source_file": str(td_doctrine_path),
                "validation_rules": [
                    {
                        "id": "SRC-001",
                        "name": "Registry Coverage",
                        "severity": "ERROR",
                        "description": "Every non-ad-hoc TD task must have a registry entry"
                    },
                    {
                        "id": "SRC-002", 
                        "name": "Schema Compliance",
                        "severity": "ERROR",
                        "description": "Every registry task must validate against td-task.schema.json"
                    },
                    {
                        "id": "SRC-003",
                        "name": "Proof Existence", 
                        "severity": "ERROR",
                        "description": "Every completed task must have a proof artifact in Docs/proofs/"
                    }
                ]
            })
        except Exception as e:
            print(f"Warning: Could not extract TD doctrine policy: {e}")

    # Extract from verification profiles
    verification_profiles_path = None
    for doc_path in source_files["governance_docs"]:
        if "VERIFICATION_PROFILES" in doc_path:
            verification_profiles_path = Path(doc_path)
            break
            
    if verification_profiles_path:
        try:
            with open(verification_profiles_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            policies.append({
                "id": "verification-profiles",
                "title": "Verification Profiles",
                "description": "Defines verification profiles and compliance requirements",
                "source_file": str(verification_profiles_path),
                "validation_rules": [
                    {
                        "id": "VER-001",
                        "name": "Profile Validation",
                        "severity": "ERROR",
                        "description": "All verification profiles must pass validation"
                    }
                ]
            })
        except Exception as e:
            print(f"Warning: Could not extract verification profiles policy: {e}")

    return policies


def load_td_task_registry(registry_path: str) -> Dict[str, Any]:
    """Load TD task registry YAML file."""
    try:
        with open(registry_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    except Exception as e:
        print(f"Error loading TD task registry: {e}")
        raise


def extract_td_tasks(registry_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Extract TD tasks from registry data."""
    tasks = []
    
    for task_data in registry_data.get('tasks', []):
        task = {
            "id": task_data.get('id', ''),
            "title": task_data.get('title', ''),
            "priority": task_data.get('priority', 'P1'),
            "type": task_data.get('type', 'task'),
            "lane": task_data.get('lane', ''),
            "status": task_data.get('status', 'ready'),
            "description": task_data.get('description', ''),
            "source_docs": task_data.get('source_docs', []),
            "acceptance": task_data.get('acceptance', []),
            "proof": task_data.get('proof', []),
            "parent": task_data.get('parent'),
            "children": task_data.get('children', []),
            "non_goals": task_data.get('non_goals', [])
        }
        tasks.append(task)
    
    return tasks


def generate_index() -> Dict[str, Any]:
    """Generate the complete governance runtime index."""
    print("📊 Generating Governance Runtime Index...")
    
    # Get source commit info
    commit_info = get_git_commit_info()
    print(f"🔗 Source commit: {commit_info['hash']}")
    
    # Find source files
    source_files = find_source_files()
    print(f"📁 Found {len(source_files['governance_docs'])} governance docs")
    print(f"📁 Found {len(source_files['schemas'])} schemas")
    print(f"📁 Found {len(source_files['manifests'])} manifests")
    
    # Extract governance policies
    governance_policies = extract_governance_policies(source_files)
    print(f"🏛️  Extracted {len(governance_policies)} governance policies")
    
    # Load and extract TD tasks
    registry_data = load_td_task_registry(source_files['td_registry'])
    td_tasks = extract_td_tasks(registry_data)
    print(f"📋 Extracted {len(td_tasks)} TD tasks")
    
    # Create index structure
    index = {
        "version": "1.0.0",
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "source_commit": commit_info,
        "source_files": source_files,
        "governance_policies": governance_policies,
        "td_tasks": td_tasks,
        "validation_results": {
            "is_valid": True,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "validator_version": "1.0.0",
            "warnings": [],
            "errors": []
        },
        "metadata": {
            "generator_version": "1.0.0",
            "generator_timestamp": datetime.utcnow().isoformat() + "Z",
            "repository": "Anigma_clean",
            "additional_notes": "Generated from Docs/ and TD task records"
        }
    }
    
    return index


def validate_index(index: Dict[str, Any]) -> bool:
    """Validate the generated index."""
    print("🔍 Validating governance index...")
    
    validation_results = index.get('validation_results', {})
    warnings = validation_results.get('warnings', [])
    errors = validation_results.get('errors', [])
    
    # Check for duplicate task IDs
    task_ids = [task['id'] for task in index.get('td_tasks', [])]
    if len(task_ids) != len(set(task_ids)):
        duplicates = [task_id for task_id in task_ids if task_ids.count(task_id) > 1]
        errors.append({
            "code": "VAL-001",
            "message": f"Duplicate task IDs found: {', '.join(duplicates)}",
            "severity": "ERROR"
        })
    
    # Check that all source files exist
    source_files = index.get('source_files', {})
    for file_list in source_files.values():
        if isinstance(file_list, list):
            for file_path in file_list:
                if not os.path.exists(file_path):
                    warnings.append({
                        "code": "VAL-002",
                        "message": f"Source file not found: {file_path}",
                        "severity": "WARNING"
                    })
    
    # Update validation results
    validation_results['is_valid'] = len(errors) == 0
    validation_results['timestamp'] = datetime.utcnow().isoformat() + "Z"
    validation_results['warnings'] = warnings
    validation_results['errors'] = errors
    
    index['validation_results'] = validation_results
    
    if errors:
        print(f"❌ Validation failed with {len(errors)} errors")
        for error in errors:
            print(f"   - {error['code']}: {error['message']}")
        return False
    else:
        print(f"✅ Validation passed with {len(warnings)} warnings")
        for warning in warnings:
            print(f"   - {warning['code']}: {warning['message']}")
        return True


def write_index(index: Dict[str, Any], output_path: Path):
    """Write the index to a JSON file."""
    print(f"💾 Writing governance index to {output_path}")
    
    # Ensure directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Write JSON file
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Successfully wrote governance index to {output_path}")


def main():
    """Main entry point."""
    try:
        # Generate index
        index = generate_index()
        
        # Validate index
        is_valid = validate_index(index)
        
        if not is_valid:
            print("❌ Governance index validation failed")
            sys.exit(1)
        
        # Write index
        output_path = PROJECT_ROOT / ".build" / "governance-runtime-index.json"
        write_index(index, output_path)
        
        print("🎉 Governance Runtime Index generation complete!")
        print(f"📊 Index contains:")
        print(f"   - {len(index['governance_policies'])} governance policies")
        print(f"   - {len(index['td_tasks'])} TD tasks")
        print(f"   - {len(index['source_files']['schemas'])} schemas")
        print(f"   - {len(index['source_files']['manifests'])} manifests")
        
    except Exception as e:
        print(f"❌ Error generating governance index: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
