#!/usr/bin/env python3
"""
td_bootstrap_from_docs.py

Bootstrap TD database from canonical Docs/td/td-task-registry.yaml.

This script implements the TD Source-of-Truth Doctrine (TD-DOCTRINE-2026-001):
- Docs/ is the durable source of truth
- TD is the local execution queue
- Bootstrap makes TD reconstructible from Docs/

Usage:
    python3 Scripts/td_bootstrap_from_docs.py --emit-commands    # Dry run
    python3 Scripts/td_bootstrap_from_docs.py --apply           # Import into TD
    python3 Scripts/td_bootstrap_from_docs.py --validate        # Validate current state
    python3 Scripts/td_bootstrap_from_docs.py --list-priority P0 # List P0 tasks

Exit codes:
    0 = Success
    1 = Error (invalid registry, missing files, etc.)
    2 = Warnings (non-blocking issues)
"""

import argparse
import json
import os
import subprocess
import sys
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent.absolute()
REGISTRY_PATH = REPO_ROOT / "Docs" / "td" / "td-task-registry.yaml"
TD_DIR = REPO_ROOT / "Docs" / "td"
TD_DB_DIR = REPO_ROOT / ".todos"

# -----------------------------------------------------------------------------
# Data Structures
# -----------------------------------------------------------------------------

class Task:
    """Represents a task from the registry."""
    
    def __init__(self, data: Dict[str, Any], registry_path: Path):
        self.data = data
        self.registry_path = registry_path
        
        # Required fields (per td-task.schema.json)
        self.id = data.get("id", "")
        self.title = data.get("title", "")
        self.status = data.get("status", "open")
        
        # Optional fields
        self.priority = data.get("priority", "P2")
        self.type = data.get("type", "task")
        self.lane = data.get("lane", "uncategorized")
        self.description = data.get("description", "")
        self.parent = data.get("parent", "")
        self.source_docs = data.get("source_docs", [])
        self.acceptance = data.get("acceptance", [])
        self.proof = data.get("proof", [])
        self.children = data.get("children", [])
        self.non_goals = data.get("non_goals", [])
        self.subtasks = data.get("subtasks", [])
        
        # Validate required fields
        if not self.id or not self.title:
            raise ValueError(f"Task missing required fields: {data}")
    
    def validate(self) -> List[str]:
        """Validate task against basic requirements. Returns list of errors."""
        errors = []
        
        if not self.id:
            errors.append("Missing required field: id")
        if not self.title:
            errors.append("Missing required field: title")
        if not self.status:
            errors.append("Missing required field: status")
        
        # Check that status is valid
        valid_statuses = ["new", "ready", "in_progress", "in_review", "complete", "completed", "blocked", "cancelled"]
        if self.status.lower() not in valid_statuses:
            errors.append(f"Invalid status: {self.status}. Must be one of: {valid_statuses}")
        
        return errors
    
    def to_td_create_command(self) -> List[str]:
        """Generate td create command for this task.
        
        td create [title] --type <type> --priority <priority> --labels <labels> --description <desc>
        Note: This td version doesn't support --id flag; IDs are auto-generated as td-<uuid>.
        We use --labels to include task_id: <id> so we can track it.
        Returns list of command arguments (no shell quoting needed, subprocess handles it).
        """
        parts = ["td", "create"]
        
        # Title (positional argument) - just the raw title, no quotes
        parts.append(self.title)
        
        # Type
        if self.type:
            parts.extend(["--type", self.type])
        
        # Priority
        if self.priority:
            parts.extend(["--priority", self.priority])
        
        # Labels/tags - include task_id for tracking
        tags = []
        if self.lane:
            tags.append(f"lane:{self.lane}")
        if self.parent:
            tags.append(f"parent:{self.parent}")
        # Always include task_id as a label for tracking
        tags.append(f"task_id:{self.id}")
        if tags:
            tag_str = ",".join(tags)
            parts.extend(["--labels", tag_str])
        
        # Description
        description_parts = []
        if self.description:
            description_parts.append(self.description)
        if self.acceptance:
            description_parts.append("")
            description_parts.append("Acceptance Criteria:")
            for item in self.acceptance:
                description_parts.append(f"  - {item}")
        if self.proof:
            description_parts.append("")
            description_parts.append("Proof:")
            for item in self.proof:
                description_parts.append(f"  - {item}")
        
        if description_parts:
            full_desc = "\n".join(description_parts)
            parts.extend(["--description", full_desc])
        
        return parts
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON output."""
        return {
            "id": self.id,
            "title": self.title,
            "priority": self.priority,
            "type": self.type,
            "status": self.status,
            "lane": self.lane,
            "description": self.description,
            "parent": self.parent,
            "source_docs": self.source_docs,
            "acceptance": self.acceptance,
            "proof": self.proof,
            "children": self.children,
        }


class Registry:
    """Represents the task registry from YAML file."""
    
    def __init__(self, path: Path):
        self.path = path
        self.data: Dict[str, Any] = {}
        self.tasks: List[Task] = []
        self.lanes: Dict[str, Dict[str, Any]] = {}
        self.loaded = False
    
    def load(self) -> List[str]:
        """Load registry from YAML file. Returns list of errors."""
        errors = []
        
        if not self.path.exists():
            errors.append(f"Registry file not found: {self.path}")
            return errors
        
        try:
            with open(self.path, 'r') as f:
                self.data = yaml.safe_load(f)
        except yaml.YAMLError as e:
            errors.append(f"YAML parse error: {e}")
            return errors
        except Exception as e:
            errors.append(f"Error reading registry: {e}")
            return errors
        
        if not self.data:
            errors.append("Registry file is empty")
            return errors
        
        # Load lanes
        self.lanes = self.data.get("lanes", {})
        
        # Load tasks
        tasks_data = self.data.get("tasks", [])
        for i, task_data in enumerate(tasks_data):
            try:
                task = Task(task_data, self.path)
                self.tasks.append(task)
            except ValueError as e:
                errors.append(f"Task {i}: {e}")
        
        self.loaded = True
        return errors
    
    def validate(self) -> List[str]:
        """Validate entire registry. Returns list of errors."""
        errors = []
        
        if not self.loaded:
            errors.append("Registry not loaded")
            return errors
        
        # Check for duplicate IDs
        ids = [t.id for t in self.tasks]
        duplicates = [id for id in ids if ids.count(id) > 1]
        if duplicates:
            errors.append(f"Duplicate task IDs: {set(duplicates)}")
        
        # Validate each task
        for task in self.tasks:
            task_errors = task.validate()
            errors.extend([f"Task {task.id}: {e}" for e in task_errors])
        
        # Check source_docs files exist
        for task in self.tasks:
            for doc_path in task.source_docs:
                full_path = REPO_ROOT / doc_path
                if not full_path.exists():
                    errors.append(f"Task {task.id}: source_doc not found: {doc_path}")
        
        # Check proof files exist for complete tasks
        for task in self.tasks:
            if task.status.lower() in ["complete", "completed"]:
                has_proof = False
                for proof_path in task.proof:
                    full_path = REPO_ROOT / proof_path
                    if full_path.exists():
                        has_proof = True
                        break
                if not has_proof and task.proof:
                    errors.append(f"Task {task.id}: proof file not found (status=complete but no valid proof path)")
        
        return errors
    
    def get_tasks_by_priority(self, priority: str) -> List[Task]:
        """Get tasks filtered by priority."""
        return [t for t in self.tasks if t.priority.upper() == priority.upper()]
    
    def get_tasks_by_status(self, status: str) -> List[Task]:
        """Get tasks filtered by status."""
        return [t for t in self.tasks if t.status.lower() == status.lower()]
    
    def get_tasks_by_lane(self, lane: str) -> List[Task]:
        """Get tasks filtered by lane."""
        return [t for t in self.tasks if t.lane == lane]


def load_tasks_from_descriptors(td_dir: Path = TD_DIR) -> Tuple[List[Task], List[str]]:
    """Load tasks by walking Docs/td/ folder structure and reading descriptor YAML files.
    
    Returns: (list of Task objects, list of errors)
    """
    tasks = []
    errors = []
    
    if not td_dir.exists():
        errors.append(f"TD directory not found: {td_dir}")
        return tasks, errors
    
    # Walk through status directories
    for status_dir in sorted(td_dir.iterdir()):
        if not status_dir.is_dir():
            continue
        if status_dir.name.startswith('.'):
            continue
        
        # For each epic/task directory
        for task_dir in sorted(status_dir.iterdir()):
            if not task_dir.is_dir():
                continue
            if task_dir.name.startswith('.'):
                continue
            
            # Check for epic.yaml
            epic_yaml = task_dir / "epic.yaml"
            if epic_yaml.exists():
                try:
                    with open(epic_yaml, 'r') as f:
                        epic_data = yaml.safe_load(f)
                    
                    # Create Task object from epic data
                    task = Task(epic_data, epic_yaml)
                    tasks.append(task)
                    
                    # Load child tasks from tasks/ subdirectory
                    tasks_dir = task_dir / "tasks"
                    if tasks_dir.exists():
                        for child_dir in sorted(tasks_dir.iterdir()):
                            if not child_dir.is_dir():
                                continue
                            child_yaml = child_dir / "task.yaml"
                            if child_yaml.exists():
                                try:
                                    with open(child_yaml, 'r') as f:
                                        child_data = yaml.safe_load(f)
                                    task = Task(child_data, child_yaml)
                                    tasks.append(task)
                                except Exception as e:
                                    errors.append(f"Error loading {child_yaml}: {e}")
                except Exception as e:
                    errors.append(f"Error loading {epic_yaml}: {e}")
            
            # Check for task.yaml (standalone task)
            task_yaml = task_dir / "task.yaml"
            if task_yaml.exists():
                try:
                    with open(task_yaml, 'r') as f:
                        task_data = yaml.safe_load(f)
                    task = Task(task_data, task_yaml)
                    tasks.append(task)
                except Exception as e:
                    errors.append(f"Error loading {task_yaml}: {e}")
    
    return tasks, errors


class DescriptorRegistry:
    """Registry that loads tasks from descriptor YAML files in Docs/td/ folder structure."""
    
    def __init__(self, td_dir: Path = TD_DIR):
        self.td_dir = td_dir
        self.tasks: List[Task] = []
        self.loaded = False
    
    def load(self) -> List[str]:
        """Load tasks from descriptor files. Returns list of errors."""
        self.tasks, errors = load_tasks_from_descriptors(self.td_dir)
        self.loaded = True
        return errors
    
    def validate(self) -> List[str]:
        """Validate all loaded tasks. Returns list of errors."""
        if not self.loaded:
            return ["Descriptor registry not loaded"]
        
        errors = []
        
        # Check for duplicate IDs
        ids = [t.id for t in self.tasks]
        duplicates = [id for id in ids if ids.count(id) > 1]
        if duplicates:
            errors.append(f"Duplicate task IDs: {set(duplicates)}")
        
        # Validate each task
        for task in self.tasks:
            task_errors = task.validate()
            errors.extend([f"Task {task.id}: {e}" for e in task_errors])
        
        return errors
    
    def get_tasks_by_priority(self, priority: str) -> List[Task]:
        """Get tasks filtered by priority."""
        return [t for t in self.tasks if t.priority.upper() == priority.upper()]
    
    def get_tasks_by_status(self, status: str) -> List[Task]:
        """Get tasks filtered by status."""
        return [t for t in self.tasks if t.status.lower() == status.lower()]
    
    def get_tasks_by_lane(self, lane: str) -> List[Task]:
        """Get tasks filtered by lane."""
        return [t for t in self.tasks if t.lane == lane]


# -----------------------------------------------------------------------------
# TD Database Interaction
# -----------------------------------------------------------------------------

def get_td_tasks() -> List[Dict[str, Any]]:
    """Get all tasks from TD database via td command (including closed ones)."""
    tasks = []
    
    try:
        # Use td list --all --json to include closed tasks
        result = subprocess.run(
            ["td", "list", "--all", "--json"],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT
        )
        if result.returncode == 0:
            try:
                data = json.loads(result.stdout)
                if isinstance(data, list):
                    tasks = data
                # elif data is None - empty list, no tasks
            except json.JSONDecodeError:
                pass
    except Exception:
        pass
    
    return tasks


def td_task_exists(task_id: str) -> bool:
    """Check if a task exists in TD database.
    
    The td CLI stores tasks with auto-generated IDs like td-xxxxxx.
    We check by looking for tasks with our task_id label (includes closed tasks).
    """
    try:
        # List all tasks including closed ones
        result = subprocess.run(
            ["td", "list", "--all", "--json"],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT
        )
        if result.returncode == 0:
            try:
                data = json.loads(result.stdout)
                if isinstance(data, list):
                    for task in data:
                        if isinstance(task, dict):
                            labels = task.get("labels", [])
                            if isinstance(labels, list):
                                if f"task_id:{task_id}" in labels:
                                    return True
                            elif isinstance(labels, str):
                                if f"task_id:{task_id}" in labels:
                                    return True
                            # Also check if the ID itself matches
                            if task.get("id", "") == task_id or task.get("id", "") == f"td-{task_id}":
                                return True
            except json.JSONDecodeError:
                pass
    except Exception:
        pass
    return False


def execute_td_command(cmd: List[str]) -> Tuple[bool, str, str]:
    """Execute a td command. Returns (success, stdout, stderr)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=REPO_ROOT
        )
        return (result.returncode == 0, result.stdout, result.stderr)
    except Exception as e:
        return (False, "", str(e))


# -----------------------------------------------------------------------------
# Main Functions
# -----------------------------------------------------------------------------

def emit_commands(registry: Registry, apply: bool = False, priority: Optional[str] = None) -> Tuple[List[str], List[str], int]:
    """
    Emit td commands to create tasks from registry.
    
    Returns: (created_commands, skipped_tasks, exit_code)
    """
    created_commands = []
    skipped = []
    errors = []
    
    tasks = registry.tasks
    if priority:
        tasks = registry.get_tasks_by_priority(priority)
    
    for task in tasks:
        # Check if task already exists in TD
        if td_task_exists(task.id):
            skipped.append(f"{task.id} ({task.title}) - already exists in TD")
            continue
        
        # Generate command
        cmd = task.to_td_create_command()
        cmd_str = " ".join(cmd)
        
        if apply:
            success, stdout, stderr = execute_td_command(cmd)
            if success:
                created_commands.append(f"✅ Created: {task.id} - {task.title}")
            else:
                errors.append(f"❌ Failed: {task.id}")
                errors.append(f"   Command: {cmd_str}")
                errors.append(f"   Error: {stderr}")
        else:
            created_commands.append(cmd_str)
    
    exit_code = 0
    if errors:
        exit_code = 1
    
    return created_commands, skipped, exit_code


def validate_registry(registry: Registry) -> Tuple[List[str], int]:
    """Validate registry against schema and file system. Returns (errors, exit_code)."""
    errors = registry.validate()
    exit_code = 0 if not errors else 1
    return errors, exit_code


def list_tasks(registry: Registry, priority: Optional[str] = None) -> List[str]:
    """List tasks from registry. Returns list of strings."""
    tasks = registry.tasks
    if priority:
        tasks = registry.get_tasks_by_priority(priority)
    
    lines = []
    for task in tasks:
        status_str = task.status.upper()
        priority_str = task.priority.upper()
        lane_str = task.lane
        
        # Truncate title if needed
        title = task.title
        if len(title) > 60:
            title = title[:57] + "..."
        
        lines.append(f"  {priority_str:4} | {status_str:12} | {task.id:12} | {lane_str:25} | {title}")
    
    return lines


def print_summary(task_count: int, created: int, skipped: int, errors: List[str]):
    """Print execution summary."""
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"  Tasks in registry:   {task_count}")
    if created:
        print(f"  Commands emitted:    {created}")
    if skipped:
        print(f"  Tasks skipped:       {len(skipped)}")
    if errors:
        print(f"  Errors:              {len(errors)}")
    print("=" * 70)


# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Bootstrap TD database from canonical Docs/td/td-task-registry.yaml",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Dry run: Show commands to create tasks
    python3 Scripts/td_bootstrap_from_docs.py --emit-commands

    # Apply: Actually create tasks in TD
    python3 Scripts/td_bootstrap_from_docs.py --apply

    # Validate registry
    python3 Scripts/td_bootstrap_from_docs.py --validate

    # List P0 tasks
    python3 Scripts/td_bootstrap_from_docs.py --list-priority P0
        """
    )
    
    parser.add_argument(
        "--emit-commands",
        action="store_true",
        help="Emit td commands without executing (dry run)"
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Execute td commands to create tasks"
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate registry without creating tasks"
    )
    parser.add_argument(
        "--list-priority",
        type=str,
        metavar="PRIORITY",
        help="List tasks by priority (P0, P1, P2, P3)"
    )
    parser.add_argument(
        "--list-lane",
        type=str,
        metavar="LANE",
        help="List tasks by lane"
    )
    parser.add_argument(
        "--list-status",
        type=str,
        metavar="STATUS",
        help="List tasks by status"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output"
    )
    parser.add_argument(
        "--registry",
        type=str,
        metavar="PATH",
        default=str(REGISTRY_PATH),
        help="Path to task registry YAML (default: Docs/td/td-task-registry.yaml)"
    )
    
    args = parser.parse_args()
    
    # Load registry
    registry_path = Path(args.registry)
    registry = Registry(registry_path)
    errors = registry.load()
    
    if errors:
        print("ERROR: Failed to load registry")
        for error in errors:
            print(f"  - {error}")
        sys.exit(1)
    
    # Validate if requested
    if args.validate:
        errors, exit_code = validate_registry(registry)
        if errors:
            print("VALIDATION FAILED")
            for error in errors:
                print(f"  - {error}")
            sys.exit(exit_code)
        else:
            print("✅ Registry validation passed")
            print(f"   Loaded {len(registry.tasks)} tasks from {registry.path}")
            sys.exit(0)
    
    # List tasks
    if args.list_priority:
        lines = list_tasks(registry, priority=args.list_priority)
        print(f"\nP{args.list_priority.upper()} Tasks ({len(lines)}):")
        print("-" * 70)
        print(f"  {'PRI':>4} | {'STATUS':>12} | {'ID':>12} | {'LANE':>25} | TITLE")
        print("-" * 70)
        for line in lines:
            print(line)
        sys.exit(0)
    
    if args.list_lane:
        tasks = registry.get_tasks_by_lane(args.list_lane)
        lines = list_tasks(registry, priority=None)
        filtered_lines = [l for l in lines if args.list_lane in l]
        print(f"\nLane: {args.list_lane} ({len(tasks)} tasks)")
        print("-" * 70)
        print(f"  {'PRI':>4} | {'STATUS':>12} | {'ID':>12} | {'LANE':>25} | TITLE")
        print("-" * 70)
        for line in filtered_lines:
            print(line)
        sys.exit(0)
    
    if args.list_status:
        tasks = registry.get_tasks_by_status(args.list_status)
        lines = []
        for task in tasks:
            status_str = task.status.upper()
            priority_str = task.priority.upper()
            lane_str = task.lane
            title = task.title[:57] + "..." if len(task.title) > 60 else task.title
            lines.append(f"  {priority_str:>4} | {status_str:>12} | {task.id:>12} | {lane_str:>25} | {title}")
        print(f"\nStatus: {args.list_status.upper()} ({len(tasks)} tasks)")
        print("-" * 70)
        print(f"  {'PRI':>4} | {'STATUS':>12} | {'ID':>12} | {'LANE':>25} | TITLE")
        print("-" * 70)
        for line in lines:
            print(line)
        sys.exit(0)
    
    # Default: Emit commands or apply
    if args.emit_commands or args.apply:
        created, skipped, exit_code = emit_commands(
            registry, 
            apply=args.apply,
            priority=args.list_priority
        )
        
        print(f"\nTasks in registry: {len(registry.tasks)}")
        
        if args.emit_commands:
            print("\nCommands to execute:")
            print("-" * 70)
            for i, cmd in enumerate(created, 1):
                print(f"  {i}. {cmd}")
            print("-" * 70)
        
        if args.apply:
            for msg in created:
                print(msg)
        
        if skipped:
            print("\nSkipped (already in TD):")
            for msg in skipped:
                print(f"  - {msg}")
        
        if args.apply and not created:
            print("\nNo new tasks to create (all exist or were skipped)")
        
        print_summary(len(registry.tasks), created, skipped, [])
        sys.exit(exit_code)
    
    # If no specific action, show help
    parser.print_help()
    sys.exit(0)


if __name__ == "__main__":
    main()
