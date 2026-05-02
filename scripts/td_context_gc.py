#!/usr/bin/env python3
"""
TD Context Garbage Collection Script

Performs garbage collection on TD task context artifacts based on
GC policies defined in Docs/manifests/td-context-gc-policy.yaml.

Usage:
    python3 Scripts/td_context_gc.py [--apply] [--task TASK_ID] [--lane LANE] 
           [--policy POLICY] [--verbose] [--dry-run]

Examples:
    # Dry run (default)
    python3 Scripts/td_context_gc.py

    # Apply changes
    python3 Scripts/td_context_gc.py --apply

    # Target specific task
    python3 Scripts/td_context_gc.py --task td-a84da2 --apply

    # Target specific lane
    python3 Scripts/td_context_gc.py --lane daemon-runtime-isolation

    # Verbose output
    python3 Scripts/td_context_gc.py --verbose
"""

import argparse
import os
import sys
import yaml
import glob
import shutil
import time
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Set, Tuple

# Paths
REPO_ROOT = Path(__file__).parent.parent.absolute()
GC_POLICY_PATH = REPO_ROOT / "Docs" / "manifests" / "td-context-gc-policy.yaml"
TD_ROOT = REPO_ROOT / "Docs" / "td"
LOGS_DIR = REPO_ROOT / "Docs" / "logs" / "gc"
ARCHIVED_DIR = TD_ROOT / "archived"

# Valid policies
VALID_GC_POLICIES = {"retain_all", "compact_on_complete", "compact_on_done", "archive_only"}
VALID_CONTEXT_POLICIES = {"eager", "lazy", "on_demand", "minimal"}

# Active statuses (should not be GC'd aggressively)
ACTIVE_STATUSES = {"new", "ready", "in_progress", "in_review"}


class GCConfig:
    """Loaded GC policy configuration."""
    
    def __init__(self, config_path: Path):
        self.config_path = config_path
        self.config = {}
        self.load()
    
    def load(self):
        """Load and validate the GC policy configuration."""
        if not self.config_path.exists():
            print(f"ERROR: GC policy file not found: {self.config_path}")
            sys.exit(1)
        
        with open(self.config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # Validate config
        self.validate()
    
    def validate(self):
        """Validate the GC policy configuration."""
        # Check required sections
        required_sections = ["default_policies", "protected_patterns", "cleanup_patterns"]
        for section in required_sections:
            if section not in self.config:
                print(f"WARNING: Missing required section: {section}")
        
        # Validate default_policies
        if "default_policies" in self.config:
            for priority in self.config["default_policies"]:
                if priority not in ["P0", "P1", "P2", "P3", "P4"]:
                    print(f"WARNING: Unknown priority: {priority}")
                policy = self.config["default_policies"][priority].get("gc_policy", "")
                if policy not in VALID_GC_POLICIES:
                    print(f"ERROR: Invalid gc_policy '{policy}' for priority {priority}")
                    sys.exit(1)
    
    def get_policy_for_task(self, task_info: Dict[str, Any]) -> Dict[str, Any]:
        """Get the effective GC policy for a task."""
        task_id = task_info.get("id", "")
        priority = task_info.get("priority", "P2")
        lane = task_info.get("lane", "")
        status = task_info.get("status", "")
        
        # Check task-specific overrides first
        if "task_overrides" in self.config and task_id in self.config["task_overrides"]:
            override = self.config["task_overrides"][task_id]
            return {
                "gc_policy": override.get("gc_policy", self.get_default_for_priority(priority)["gc_policy"]),
                "context_load_policy": override.get("context_load_policy", self.get_default_for_priority(priority)["context_load_policy"]),
                "reason": override.get("reason", "")
            }
        
        # Check lane policies
        if "lane_policies" in self.config and lane in self.config["lane_policies"]:
            lane_policy = self.config["lane_policies"][lane]
            status_filter = lane_policy.get("status_filter", [])
            if status in status_filter:
                return {
                    "gc_policy": lane_policy.get("gc_policy", self.get_default_for_priority(priority)["gc_policy"]),
                    "context_load_policy": lane_policy.get("context_load_policy", self.get_default_for_priority(priority)["context_load_policy"]),
                    "reason": lane_policy.get("rationale", "")
                }
        
        # Return default for priority
        return self.get_default_for_priority(priority)
    
    def get_default_for_priority(self, priority: str) -> Dict[str, Any]:
        """Get default policy for a priority level."""
        if "default_policies" in self.config and priority in self.config["default_policies"]:
            return self.config["default_policies"][priority]
        return {
            "gc_policy": "compact_on_done",
            "context_load_policy": "lazy",
            "rationale": "default fallback"
        }


class TDTask:
    """Represents a TD task with its descriptor and context."""
    
    def __init__(self, task_dir: Path):
        self.task_dir = task_dir
        self.task_id = task_dir.name
        self.task_yaml = task_dir / "task.yaml"
        self.descriptor = {}
        self.loads = False
        self.load_descriptor()
    
    def load_descriptor(self):
        """Load the task descriptor YAML."""
        if self.task_yaml.exists():
            try:
                with open(self.task_yaml, 'r') as f:
                    self.descriptor = yaml.safe_load(f) or {}
                self.loads = True
            except yaml.YAMLError as e:
                print(f"WARNING: Failed to parse {self.task_yaml}: {e}")
                self.loads = False
        else:
            print(f"WARNING: Missing descriptor: {self.task_yaml}")
            self.loads = False
    
    def get_gc_policy(self, config: GCConfig) -> Dict[str, Any]:
        """Get the effective GC policy for this task."""
        if not self.loads:
            return {"gc_policy": "retain_all", "context_load_policy": "lazy"}
        return config.get_policy_for_task(self.descriptor)
    
    def should_gc(self, config: GCConfig) -> bool:
        """Determine if this task should be considered for GC."""
        if not self.loads:
            return False
        
        policy = self.get_gc_policy(config)
        gc_policy = policy.get("gc_policy", "")
        status = self.descriptor.get("status", "")
        
        # retain_all never GCs
        if gc_policy == "retain_all":
            return False
        
        # Active tasks should not be compacted_hard
        if gc_policy in ["compact_on_done"] and status in ACTIVE_STATUSES:
            return False
        
        return True
    
    def get_gc_actions(self, config: GCConfig, dry_run: bool = True) -> List[Dict[str, Any]]:
        """Get the list of GC actions to perform on this task."""
        actions = []
        
        if not self.loads:
            return actions
        
        policy = self.get_gc_policy(config)
        gc_policy = policy.get("gc_policy", "")
        status = self.descriptor.get("status", "")
        
        # Determine if we should act based on triggers
        if not self.should_act_based_on_triggers(config):
            return actions
        
        if gc_policy == "archive_only":
            actions.append({
                "action": "archive",
                "target": str(self.task_dir),
                "archive_to": str(ARCHIVED_DIR / self.task_id),
                "reason": f"archive_only policy for {self.task_id}"
            })
        elif gc_policy == "compact_on_complete" and status == "complete":
            actions.extend(self.get_compact_actions(config, "complete"))
        elif gc_policy == "compact_on_done" and status in ["complete", "done"]:
            actions.extend(self.get_compact_actions(config, "done"))
        
        return actions
    
    def should_act_based_on_triggers(self, config: GCConfig) -> bool:
        """Check if GC should act based on time-based triggers."""
        if not self.loads:
            return False
        
        status = self.descriptor.get("status", "")
        completion_date = self.descriptor.get("completion_date")
        
        # If no completion date, use file modification time
        if not completion_date and self.task_yaml.exists():
            mtime = self.task_yaml.stat().st_mtime
            completion_date = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")
        
        if not completion_date:
            return False
        
        try:
            comp_date = datetime.strptime(completion_date, "%Y-%m-%d").date()
            today = datetime.now().date()
            days_since_complete = (today - comp_date).days
        except ValueError:
            return False
        
        # Check triggers
        triggers = config.config.get("gc_triggers", [])
        for trigger in triggers:
            trigger_status = trigger.get("status", "")
            min_days = trigger.get("min_duration_days", 0)
            
            if status == trigger_status and days_since_complete >= min_days:
                return True
        
        return False
    
    def get_compact_actions(self, config: GCConfig, level: str) -> List[Dict[str, Any]]:
        """Get cleanup actions for compact policies."""
        actions = []
        
        # Get all files in task directory
        all_files = []
        for root, dirs, files in os.walk(self.task_dir):
            for f in files:
                all_files.append(Path(root) / f)
        
        # Get protected patterns
        protected_patterns = config.config.get("protected_patterns", [])
        
        # Get cleanup patterns based on level
        cleanup_map = config.config.get("cleanup_patterns", {})
        
        if level == "complete":
            patterns_to_clean = cleanup_map.get("worktree", []) + cleanup_map.get("build", []) + cleanup_map.get("test", []) + cleanup_map.get("cache", [])
        else:  # done
            patterns_to_clean = cleanup_map.get("worktree", []) + cleanup_map.get("build", []) + cleanup_map.get("test", []) + cleanup_map.get("cache", []) + cleanup_map.get("analysis", [])
        
        for file_path in all_files:
            rel_path = str(file_path.relative_to(self.task_dir))
            
            # Check if protected
            if self.is_protected(rel_path, protected_patterns, config):
                continue
            
            # Check if matches cleanup pattern
            for pattern in patterns_to_clean:
                if self.path_matches_pattern(rel_path, pattern):
                    actions.append({
                        "action": "delete",
                        "target": str(file_path),
                        "reason": f"matches cleanup pattern: {pattern}"
                    })
                    break
        
        return actions
    
    def is_protected(self, rel_path: str, protected_patterns: List[str], config: GCConfig) -> bool:
        """Check if a path is protected from GC."""
        # Always protect task.yaml and epic.yaml
        if "task.yaml" in rel_path or "epic.yaml" in rel_path:
            return True
        
        for pattern in protected_patterns:
            if self.path_matches_pattern(rel_path, pattern):
                return True
        
        return False
    
    def path_matches_pattern(self, path: str, pattern: str) -> bool:
        """Check if a path matches a glob pattern."""
        # Convert glob pattern to a form we can check
        import fnmatch
        return fnmatch.fnmatch(path, pattern)


class GCLogger:
    """Logger for GC operations."""
    
    def __init__(self, log_dir: Path):
        self.log_dir = log_dir
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.entries = []
        self.start_time = datetime.now()
    
    def log(self, message: str, level: str = "INFO"):
        """Log a message."""
        timestamp = datetime.now().isoformat()
        entry = {"timestamp": timestamp, "level": level, "message": message}
        self.entries.append(entry)
        print(f"[{timestamp}] {level}: {message}")
    
    def save(self):
        """Save log to file."""
        if not self.entries:
            return
        
        log_file = self.log_dir / f"gc_{self.start_time.strftime('%Y%m%d_%H%M%S')}.yaml"
        with open(log_file, 'w') as f:
            yaml.dump({
                "start_time": self.start_time.isoformat(),
                "end_time": datetime.now().isoformat(),
                "entries": self.entries
            }, f, default_flow_style=False)
        print(f"Log saved to: {log_file}")


def find_all_tasks() -> List[Path]:
    """Find all task directories in Docs/td recursively."""
    tasks = []
    
    if not TD_ROOT.exists():
        return tasks
    
    # Walks all subdirectories of Docs/td and find task.yaml files
    for root, dirs, files in os.walk(TD_ROOT):
        root_path = Path(root)
        for f in files:
            if f == "task.yaml":
                task_dir = root_path
                # Verify it looks like a task directory (has task.yaml)
                if (task_dir / "task.yaml").exists():
                    tasks.append(task_dir)
    
    return tasks


def load_task_descriptor(task_dir: Path) -> Optional[Dict[str, Any]]:
    """Load a task descriptor from a directory."""
    task_yaml = task_dir / "task.yaml"
    if not task_yaml.exists():
        return None
    
    try:
        with open(task_yaml, 'r') as f:
            return yaml.safe_load(f) or {}
    except yaml.YAMLError:
        return None


def validate_descriptor(descriptor: Dict[str, Any], task_path: Path) -> List[str]:
    """Validate a task descriptor against GC-related schema constraints."""
    errors = []
    
    # Check gc_policy
    gc_policy = descriptor.get("gc_policy")
    if gc_policy and gc_policy not in VALID_GC_POLICIES:
        errors.append(f"Invalid gc_policy '{gc_policy}' in {task_path}")
    
    # Check context_load_policy
    context_policy = descriptor.get("context_load_policy")
    if context_policy and context_policy not in VALID_CONTEXT_POLICIES:
        errors.append(f"Invalid context_load_policy '{context_policy}' in {task_path}")
    
    # Check active tasks don't have aggressive GC
    status = descriptor.get("status", "")
    if status in ACTIVE_STATUSES and gc_policy in ["compact_on_done", "archive_only"]:
        errors.append(f"Active task {descriptor.get('id')} in {task_path} has aggressive gc_policy '{gc_policy}'")
    
    return errors


def main():
    parser = argparse.ArgumentParser(description="TD Context Garbage Collection")
    parser.add_argument("--apply", action="store_true", help="Apply changes (otherwise dry run)")
    parser.add_argument("--task", type=str, help="Target specific task ID")
    parser.add_argument("--lane", type=str, help="Target specific lane")
    parser.add_argument("--policy", type=str, help="Override GC policy")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--force", action="store_true", help="Force even if safety checks fail")
    parser.add_argument("--max-actions", type=int, default=100, help="Maximum number of actions to perform")
    
    args = parser.parse_args()
    
    # Initialize
    config = GCConfig(GC_POLICY_PATH)
    logger = GCLogger(LOGS_DIR)
    
    logger.log(f"Starting GC run (apply={args.apply})")
    logger.log(f"Policy file: {GC_POLICY_PATH}")
    
    # Find tasks
    all_task_dirs = find_all_tasks()
    logger.log(f"Found {len(all_task_dirs)} task directories")
    
    # Filter by task ID if specified
    if args.task:
        all_task_dirs = [d for d in all_task_dirs if d.name == args.task]
        if not all_task_dirs:
            logger.log(f"Task {args.task} not found", "WARNING")
            return
    
    # Filter by lane if specified
    if args.lane:
        filtered = []
        for task_dir in all_task_dirs:
            descriptor = load_task_descriptor(task_dir)
            if descriptor and descriptor.get("lane") == args.lane:
                filtered.append(task_dir)
        all_task_dirs = filtered
        logger.log(f"Filtered to {len(all_task_dirs)} tasks in lane {args.lane}")
    
    # Collect all actions
    all_actions = []
    validation_errors = []
    
    for task_dir in all_task_dirs:
        descriptor = load_task_descriptor(task_dir)
        
        if descriptor is None:
            logger.log(f"Skipping {task_dir} (no valid descriptor)", "WARNING")
            continue
        
        # Validate descriptor
        errors = validate_descriptor(descriptor, task_dir)
        if errors:
            validation_errors.extend(errors)
            continue
        
        # Create task object and get actions
        task = TDTask(task_dir)
        actions = task.get_gc_actions(config, dry_run=not args.apply)
        
        if args.policy:
            # Override policy for testing
            for action in actions:
                action["forced_policy"] = args.policy
        
        all_actions.extend(actions)
    
    # Report validation errors
    if validation_errors:
        logger.log("Validation Errors:")
        for error in validation_errors:
            logger.log(f"  - {error}", "ERROR")
        
        if not args.force:
            logger.log("Aborting due to validation errors. Use --force to override.", "ERROR")
            if args.apply:
                # Still save log
                logger.save()
            return
    
    # Report actions
    delete_actions = [a for a in all_actions if a["action"] == "delete"]
    archive_actions = [a for a in all_actions if a["action"] == "archive"]
    
    logger.log(f"\n=== GC Actions ===")
    logger.log(f"Total actions: {len(all_actions)}")
    logger.log(f"  Delete: {len(delete_actions)}")
    logger.log(f"  Archive: {len(archive_actions)}")
    
    if args.verbose:
        for action in all_actions:
            logger.log(f"  [{action['action']}] {action['target']}")
    
    # Apply actions if requested
    if args.apply and all_actions:
        logger.log(f"\n=== Applying {len(all_actions)} actions ===", "WARNING")
        
        # Safety check
        execution_limits = config.config.get("execution", {})
        max_actions = execution_limits.get("max_deletions_per_run", 1000)
        confirm = execution_limits.get("confirm_with_user", True)
        
        if confirm and len(all_actions) > 5 and not args.force:
            response = input(f"About to perform {len(all_actions)} actions. Continue? [y/N]: ")
            if response.lower() != "y":
                logger.log("Aborted by user.")
                return
        
        applied_count = 0
        error_count = 0
        
        for action in all_actions[:args.max_actions]:
            try:
                if action["action"] == "delete":
                    target_path = Path(action["target"])
                    if target_path.exists():
                        if args.verbose:
                            logger.log(f"Deleting: {target_path}")
                        # Actually delete
                        if target_path.is_file():
                            target_path.unlink()
                        elif target_path.is_dir():
                            shutil.rmtree(target_path)
                        logger.log(f"Deleted: {target_path}")
                        applied_count += 1
                
                elif action["action"] == "archive":
                    source = Path(action["target"])
                    dest = Path(action["archive_to"])
                    
                    if args.verbose:
                        logger.log(f"Archiving {source} -> {dest}")
                    
                    # Create archive directory
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    
                    # Move the directory
                    if source.exists():
                        shutil.move(str(source), str(dest))
                        
                        # Create meta file
                        meta_path = dest / "archived_meta.yaml"
                        meta = {
                            "original_path": str(action["target"]),
                            "archived_at": datetime.now().isoformat(),
                            "archived_by": "td_context_gc.py",
                            "reason": action.get("reason", "GC policy archive_only"),
                            "task_id": source.name
                        }
                        with open(meta_path, 'w') as f:
                            yaml.dump(meta, f)
                        
                        logger.log(f"Archived: {source} -> {dest}")
                        applied_count += 1
                
            except Exception as e:
                logger.log(f"ERROR applying action: {action.get('target')}: {e}", "ERROR")
                error_count += 1
        
        logger.log(f"\n=== Results ===")
        logger.log(f"Applied: {applied_count}")
        logger.log(f"Errors: {error_count}")
        logger.log(f"Remaining: {len(all_actions) - applied_count}")
    
    # Save log
    logger.save()
    
    logger.log("GC run complete.")


if __name__ == "__main__":
    # Ensure we're in the right directory
    os.chdir(REPO_ROOT)
    main()
