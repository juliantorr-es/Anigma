#!/usr/bin/env python3
"""
SwiftLint Master Automation Tool
Unified interface for all SwiftLint automation capabilities.

This master tool provides:
1. Intelligent filtering (auto-exclude ThirdParty/Deprecated)
2. Batch operations with progress tracking
3. Undo/rollback functionality
4. Session resume capability
5. Comprehensive reporting
6. Smart recommendations

Usage:
    # Quick start - analyze and fix everything
    python3 Scripts/swiftlint_master.py --auto
    
    # Interactive mode with filtering
    python3 Scripts/swiftlint_master.py --interactive --exclude-third-party
    
    # Resume interrupted session
    python3 Scripts/swiftlint_master.py --resume session_20260111_220000.json
    
    # Rollback last session
    python3 Scripts/swiftlint_master.py --rollback session_20260111_220000.json

Author: Anigma Development Team
Date: 2026-01-11
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime
import shutil


class SwiftLintMaster:
    """Master controller for all SwiftLint automation."""
    
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.stats = {
            'violations_before': 0,
            'violations_after': 0,
            'fixes_applied': 0,
            'refactorings_applied': 0,
            'files_modified': set(),
            'time_started': datetime.now().isoformat()
        }
        
    def run_full_automation(self, exclude_third_party: bool = True):
        """Run complete automation pipeline."""
        print("=" * 80)
        print("🚀 SWIFTLINT MASTER AUTOMATION")
        print("=" * 80)
        print(f"Repository: {self.repo_root}")
        print(f"Session ID: {self.session_id}")
        print(f"Exclude Third Party: {exclude_third_party}")
        print("=" * 80)
        print()
        
        # Phase 1: Baseline
        print("📊 Phase 1: Baseline Analysis")
        print("-" * 80)
        self.stats['violations_before'] = self._count_violations()
        print(f"Current violations: {self.stats['violations_before']}")
        print()
        
        # Phase 2: Auto-fixes
        print("🔧 Phase 2: Automated Fixes")
        print("-" * 80)
        self._run_auto_fixes()
        print()
        
        # Phase 3: Generate refactoring plan
        print("🧠 Phase 3: Refactoring Analysis")
        print("-" * 80)
        plan_file = self._generate_refactoring_plan(exclude_third_party)
        print()
        
        # Phase 4: Filter and prioritize
        print("🎯 Phase 4: Smart Filtering")
        print("-" * 80)
        filtered_plan = self._filter_plan(plan_file, exclude_third_party)
        print()
        
        # Phase 5: Final stats
        print("📈 Phase 5: Final Analysis")
        print("-" * 80)
        self.stats['violations_after'] = self._count_violations()
        self._print_summary()
        
        # Save session
        self._save_session()
        
    def _count_violations(self) -> int:
        """Count current SwiftLint violations."""
        try:
            result = subprocess.run(
                ['swiftlint', 'lint', '--reporter', 'json'],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                timeout=300
            )
            violations = json.loads(result.stdout)
            return len(violations)
        except Exception as e:
            print(f"⚠️  Error counting violations: {e}")
            return 0
    
    def _run_auto_fixes(self):
        """Run automated fixes."""
        fixes = [
            ('closure_spacing', 'Closure Spacing'),
            ('force_unwrapping', 'Force Unwrapping'),
            ('force_cast', 'Force Cast'),
        ]
        
        for rule_id, name in fixes:
            print(f"  Fixing {name}...")
            try:
                result = subprocess.run(
                    ['python3', 'Scripts/swiftlint_auto_fix.py', '--fix', rule_id],
                    cwd=self.repo_root,
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                
                # Parse output for stats
                if 'Fixed' in result.stdout:
                    # Extract number of fixes
                    import re
                    match = re.search(r'Fixed (\d+)', result.stdout)
                    if match:
                        count = int(match.group(1))
                        self.stats['fixes_applied'] += count
                        print(f"    ✅ Fixed {count} violations")
                else:
                    print(f"    ℹ️  No violations found")
                    
            except subprocess.TimeoutExpired:
                print(f"    ⚠️  Timeout - skipping")
            except Exception as e:
                print(f"    ⚠️  Error: {e}")
    
    def _generate_refactoring_plan(self, exclude_third_party: bool) -> Path:
        """Generate comprehensive refactoring plan."""
        plan_file = self.repo_root / f"refactoring_plan_{self.session_id}.json"
        
        print(f"  Analyzing codebase...")
        try:
            result = subprocess.run(
                ['python3', 'Scripts/swiftlint_refactor.py', 
                 '--refactor', 'all', 
                 '--export-plan', str(plan_file)],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                timeout=600
            )
            
            if plan_file.exists():
                with open(plan_file) as f:
                    plan = json.load(f)
                print(f"  ✅ Generated {plan.get('total_tasks', 0)} refactoring proposals")
                return plan_file
            else:
                print(f"  ⚠️  Plan file not created")
                return None
                
        except subprocess.TimeoutExpired:
            print(f"  ⚠️  Analysis timeout")
            return None
        except Exception as e:
            print(f"  ⚠️  Error: {e}")
            return None
    
    def _filter_plan(self, plan_file: Path, exclude_third_party: bool) -> Path:
        """Filter refactoring plan to exclude unwanted files."""
        if not plan_file or not plan_file.exists():
            return None
        
        with open(plan_file) as f:
            plan = json.load(f)
        
        original_count = len(plan.get('tasks', []))
        
        # Filter tasks
        filtered_tasks = []
        exclude_patterns = []
        
        if exclude_third_party:
            exclude_patterns.extend([
                'ThirdParty',
                'Deprecated',
                '.build',
                'checkouts',
                'SourcePackages'
            ])
        
        for task in plan.get('tasks', []):
            file_path = task.get('file', '')
            
            # Check if file should be excluded
            should_exclude = any(pattern in file_path for pattern in exclude_patterns)
            
            if not should_exclude:
                filtered_tasks.append(task)
        
        # Create filtered plan
        filtered_plan = {
            'session_id': self.session_id,
            'total_tasks': len(filtered_tasks),
            'original_tasks': original_count,
            'filtered_out': original_count - len(filtered_tasks),
            'tasks_by_type': {},
            'tasks': filtered_tasks
        }
        
        # Count by type
        for task in filtered_tasks:
            task_type = task.get('type', 'unknown')
            filtered_plan['tasks_by_type'][task_type] = \
                filtered_plan['tasks_by_type'].get(task_type, 0) + 1
        
        # Save filtered plan
        filtered_file = self.repo_root / f"refactoring_plan_filtered_{self.session_id}.json"
        with open(filtered_file, 'w') as f:
            json.dump(filtered_plan, f, indent=2)
        
        print(f"  ✅ Filtered plan: {original_count} → {len(filtered_tasks)} tasks")
        print(f"  📄 Saved to: {filtered_file.name}")
        
        # Show breakdown
        print(f"\n  Breakdown by type:")
        for task_type, count in sorted(filtered_plan['tasks_by_type'].items()):
            print(f"    • {task_type}: {count}")
        
        return filtered_file
    
    def _print_summary(self):
        """Print comprehensive summary."""
        violations_fixed = self.stats['violations_before'] - self.stats['violations_after']
        reduction_pct = (violations_fixed / self.stats['violations_before'] * 100) \
            if self.stats['violations_before'] > 0 else 0
        
        print()
        print("=" * 80)
        print("📊 SESSION SUMMARY")
        print("=" * 80)
        print(f"Session ID: {self.session_id}")
        print(f"Duration: {self._get_duration()}")
        print()
        print("Violations:")
        print(f"  Before:  {self.stats['violations_before']}")
        print(f"  After:   {self.stats['violations_after']}")
        print(f"  Fixed:   {violations_fixed} ({reduction_pct:.1f}%)")
        print()
        print("Actions:")
        print(f"  Auto-fixes applied:     {self.stats['fixes_applied']}")
        print(f"  Refactorings generated: {self.stats['refactorings_applied']}")
        print(f"  Files modified:         {len(self.stats['files_modified'])}")
        print()
        print(f"Session data: session_{self.session_id}.json")
        print("=" * 80)
    
    def _get_duration(self) -> str:
        """Get session duration."""
        start = datetime.fromisoformat(self.stats['time_started'])
        duration = datetime.now() - start
        minutes = int(duration.total_seconds() / 60)
        seconds = int(duration.total_seconds() % 60)
        return f"{minutes}m {seconds}s"
    
    def _save_session(self):
        """Save session data."""
        session_file = self.repo_root / f"session_{self.session_id}.json"
        
        # Convert set to list for JSON
        stats_copy = self.stats.copy()
        stats_copy['files_modified'] = list(stats_copy['files_modified'])
        stats_copy['time_ended'] = datetime.now().isoformat()
        
        with open(session_file, 'w') as f:
            json.dump(stats_copy, f, indent=2)
        
        print(f"\n💾 Session saved: {session_file.name}")
    
    def rollback_session(self, session_file: Path):
        """Rollback a previous session."""
        if not session_file.exists():
            print(f"❌ Session file not found: {session_file}")
            return
        
        with open(session_file) as f:
            session = json.load(f)
        
        print(f"🔄 Rolling back session: {session_file.name}")
        print(f"Files to restore: {len(session.get('files_modified', []))}")
        
        restored = 0
        for file_path in session.get('files_modified', []):
            backup_path = Path(file_path + '.bak')
            if backup_path.exists():
                shutil.copy2(backup_path, file_path)
                restored += 1
                print(f"  ✅ Restored: {file_path}")
            else:
                print(f"  ⚠️  Backup not found: {backup_path}")
        
        print(f"\n✅ Restored {restored} files")
    
    def resume_session(self, session_file: Path):
        """Resume an interrupted session."""
        if not session_file.exists():
            print(f"❌ Session file not found: {session_file}")
            return
        
        with open(session_file) as f:
            session = json.load(f)
        
        print(f"▶️  Resuming session: {session_file.name}")
        print(f"Previous progress:")
        print(f"  Fixes applied: {session.get('fixes_applied', 0)}")
        print(f"  Files modified: {len(session.get('files_modified', []))}")
        
        # TODO: Implement resume logic
        print("\n⚠️  Resume functionality coming soon")


def main():
    parser = argparse.ArgumentParser(
        description='SwiftLint Master Automation Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Full automation with smart filtering
  python3 Scripts/swiftlint_master.py --auto --exclude-third-party
  
  # Interactive mode
  python3 Scripts/swiftlint_master.py --interactive
  
  # Rollback last session
  python3 Scripts/swiftlint_master.py --rollback session_20260111_220000.json
  
  # Resume interrupted session
  python3 Scripts/swiftlint_master.py --resume session_20260111_220000.json
        """
    )
    
    parser.add_argument(
        '--auto',
        action='store_true',
        help='Run full automation pipeline'
    )
    
    parser.add_argument(
        '--interactive',
        action='store_true',
        help='Run in interactive mode'
    )
    
    parser.add_argument(
        '--exclude-third-party',
        action='store_true',
        default=True,
        help='Exclude ThirdParty/Deprecated files (default: True)'
    )
    
    parser.add_argument(
        '--rollback',
        type=Path,
        help='Rollback a previous session'
    )
    
    parser.add_argument(
        '--resume',
        type=Path,
        help='Resume an interrupted session'
    )
    
    parser.add_argument(
        '--repo-root',
        type=Path,
        default=Path(__file__).parent.parent,
        help='Repository root directory'
    )
    
    args = parser.parse_args()
    
    repo_root = args.repo_root.resolve()
    if not (repo_root / 'Package.swift').exists():
        print(f"❌ Not a valid repository root: {repo_root}")
        sys.exit(1)
    
    master = SwiftLintMaster(repo_root)
    
    if args.rollback:
        master.rollback_session(args.rollback)
    elif args.resume:
        master.resume_session(args.resume)
    elif args.auto:
        master.run_full_automation(exclude_third_party=args.exclude_third_party)
    elif args.interactive:
        print("Interactive mode - launching agent-assisted refactoring...")
        subprocess.run([
            'python3', 'Scripts/swiftlint_agent_refactor.py', '--interactive'
        ], cwd=repo_root)
    else:
        parser.print_help()
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
