#!/usr/bin/env python3
"""
SwiftLint Auto-Fix Script
Programmatically applies common SwiftLint fixes to the Anigma codebase.

Usage:
    python3 Scripts/swiftlint_auto_fix.py --dry-run          # Preview changes
    python3 Scripts/swiftlint_auto_fix.py --fix force_unwrap # Fix specific rule
    python3 Scripts/swiftlint_auto_fix.py --fix all          # Fix all rules
    python3 Scripts/swiftlint_auto_fix.py --stats            # Show violation stats

Author: Anigma Development Team
Date: 2026-01-11
"""

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import shutil


@dataclass
class Violation:
    """Represents a SwiftLint violation."""
    file: str
    line: int
    column: int
    severity: str
    rule_id: str
    message: str
    
    @classmethod
    def from_json(cls, data: dict) -> 'Violation':
        return cls(
            file=data['file'],
            line=data['line'],
            column=data.get('column', 0),
            severity=data['severity'],
            rule_id=data['rule_id'],
            message=data['reason']
        )


class SwiftLintFixer:
    """Automated SwiftLint violation fixer."""
    
    def __init__(self, repo_root: Path, dry_run: bool = False):
        self.repo_root = repo_root
        self.dry_run = dry_run
        self.fixes_applied = 0
        self.files_modified = set()
        
    def get_violations(self) -> List[Violation]:
        """Get all SwiftLint violations as structured data."""
        print("🔍 Running SwiftLint to detect violations...")
        
        try:
            result = subprocess.run(
                ['swiftlint', 'lint', '--reporter', 'json'],
                cwd=self.repo_root,
                capture_output=True,
                text=True
            )
            
            violations_data = json.loads(result.stdout)
            violations = [Violation.from_json(v) for v in violations_data]
            
            print(f"✅ Found {len(violations)} violations")
            return violations
            
        except json.JSONDecodeError as e:
            print(f"❌ Failed to parse SwiftLint output: {e}")
            return []
        except FileNotFoundError:
            print("❌ SwiftLint not found. Install with: brew install swiftlint")
            sys.exit(1)
    
    def get_violation_stats(self, violations: List[Violation]) -> Dict[str, int]:
        """Get violation counts by rule."""
        stats = {}
        for v in violations:
            stats[v.rule_id] = stats.get(v.rule_id, 0) + 1
        return dict(sorted(stats.items(), key=lambda x: x[1], reverse=True))
    
    def read_file(self, filepath: str) -> List[str]:
        """Read file and return lines."""
        path = Path(filepath)
        if not path.exists():
            return []
        return path.read_text().splitlines(keepends=True)
    
    def write_file(self, filepath: str, lines: List[str]):
        """Write lines to file."""
        if self.dry_run:
            return
        
        path = Path(filepath)
        path.write_text(''.join(lines))
        self.files_modified.add(filepath)
    
    def backup_file(self, filepath: str):
        """Create backup of file before modification."""
        if self.dry_run:
            return
        
        backup_path = Path(filepath).with_suffix('.swift.bak')
        shutil.copy2(filepath, backup_path)
    
    # ========================================================================
    # RULE FIXERS
    # ========================================================================
    
    def fix_force_unwrap(self, violations: List[Violation]) -> int:
        """Fix force unwrapping violations by converting to guard statements."""
        print("\n🔧 Fixing force unwrapping violations...")
        
        force_unwraps = [v for v in violations if v.rule_id == 'force_unwrapping']
        files_to_fix = {}
        
        # Group violations by file
        for v in force_unwraps:
            if v.file not in files_to_fix:
                files_to_fix[v.file] = []
            files_to_fix[v.file].append(v)
        
        fixed = 0
        for filepath, file_violations in files_to_fix.items():
            lines = self.read_file(filepath)
            if not lines:
                continue
            
            # Sort by line number (descending) to avoid index issues
            file_violations.sort(key=lambda v: v.line, reverse=True)
            
            for v in file_violations:
                if v.line > len(lines):
                    continue
                
                line_idx = v.line - 1
                line = lines[line_idx]
                
                # Pattern: variable = expression!
                match = re.search(r'(\w+)\s*=\s*(.+?)!(?:\s|$)', line)
                if match:
                    var_name = match.group(1)
                    expression = match.group(2).strip()
                    indent = len(line) - len(line.lstrip())
                    
                    # Generate guard statement
                    guard_stmt = (
                        f"{' ' * indent}guard let {var_name} = {expression} else {{\n"
                        f"{' ' * (indent + 4)}fatalError(\"Failed to unwrap {var_name}\")\n"
                        f"{' ' * indent}}}\n"
                    )
                    
                    if self.dry_run:
                        print(f"  📝 {filepath}:{v.line}")
                        print(f"     - {line.rstrip()}")
                        print(f"     + {guard_stmt.rstrip()}")
                    else:
                        lines[line_idx] = guard_stmt
                        fixed += 1
            
            if not self.dry_run and fixed > 0:
                self.backup_file(filepath)
                self.write_file(filepath, lines)
        
        print(f"✅ Fixed {fixed} force unwrapping violations")
        return fixed
    
    def fix_force_cast(self, violations: List[Violation]) -> int:
        """Fix force cast violations by converting to safe casts."""
        print("\n🔧 Fixing force cast violations...")
        
        force_casts = [v for v in violations if v.rule_id == 'force_cast']
        files_to_fix = {}
        
        for v in force_casts:
            if v.file not in files_to_fix:
                files_to_fix[v.file] = []
            files_to_fix[v.file].append(v)
        
        fixed = 0
        for filepath, file_violations in files_to_fix.items():
            lines = self.read_file(filepath)
            if not lines:
                continue
            
            file_violations.sort(key=lambda v: v.line, reverse=True)
            
            for v in file_violations:
                if v.line > len(lines):
                    continue
                
                line_idx = v.line - 1
                line = lines[line_idx]
                
                # Pattern: variable = expression as! Type
                match = re.search(r'(\w+)\s*=\s*(.+?)\s+as!\s+(\w+)', line)
                if match:
                    var_name = match.group(1)
                    expression = match.group(2).strip()
                    cast_type = match.group(3)
                    indent = len(line) - len(line.lstrip())
                    
                    # Generate guard statement with safe cast
                    guard_stmt = (
                        f"{' ' * indent}guard let {var_name} = {expression} as? {cast_type} else {{\n"
                        f"{' ' * (indent + 4)}fatalError(\"Failed to cast to {cast_type}\")\n"
                        f"{' ' * indent}}}\n"
                    )
                    
                    if self.dry_run:
                        print(f"  📝 {filepath}:{v.line}")
                        print(f"     - {line.rstrip()}")
                        print(f"     + {guard_stmt.rstrip()}")
                    else:
                        lines[line_idx] = guard_stmt
                        fixed += 1
            
            if not self.dry_run and fixed > 0:
                self.backup_file(filepath)
                self.write_file(filepath, lines)
        
        print(f"✅ Fixed {fixed} force cast violations")
        return fixed
    
    def fix_large_tuple(self, violations: List[Violation]) -> int:
        """Convert large tuples to structs (requires manual review)."""
        print("\n🔧 Analyzing large tuple violations...")
        
        large_tuples = [v for v in violations if v.rule_id == 'large_tuple']
        
        # This is complex and requires context, so we generate suggestions
        suggestions = []
        
        for v in large_tuples:
            lines = self.read_file(v.file)
            if not lines or v.line > len(lines):
                continue
            
            line = lines[v.line - 1]
            
            # Try to extract tuple pattern
            tuple_match = re.search(r'\(([^)]+)\)', line)
            if tuple_match:
                tuple_content = tuple_match.group(1)
                members = [m.strip() for m in tuple_content.split(',')]
                
                if len(members) > 2:
                    suggestions.append({
                        'file': v.file,
                        'line': v.line,
                        'original': line.strip(),
                        'members': members,
                        'suggestion': self._generate_struct_suggestion(members)
                    })
        
        if suggestions:
            print(f"📋 Found {len(suggestions)} large tuples that should be converted to structs")
            print("   (Manual review required - see generated suggestions)")
            
            # Write suggestions to file
            suggestions_file = self.repo_root / 'large_tuple_suggestions.json'
            if not self.dry_run:
                suggestions_file.write_text(json.dumps(suggestions, indent=2))
                print(f"   Suggestions written to: {suggestions_file}")
        
        return 0  # Manual fixes required
    
    def _generate_struct_suggestion(self, members: List[str]) -> str:
        """Generate struct suggestion from tuple members."""
        struct_name = "TupleReplacement"  # User should rename
        
        struct_def = f"struct {struct_name} {{\n"
        for i, member in enumerate(members):
            # Try to extract type if present
            if ':' in member:
                name, type_hint = member.split(':', 1)
                struct_def += f"    let {name.strip()}: {type_hint.strip()}\n"
            else:
                struct_def += f"    let member{i}: Type{i}  // TODO: Add proper type\n"
        struct_def += "}"
        
        return struct_def
    
    def fix_trailing_whitespace(self, violations: List[Violation]) -> int:
        """Remove trailing whitespace."""
        print("\n🔧 Fixing trailing whitespace...")
        
        trailing_ws = [v for v in violations if v.rule_id == 'trailing_whitespace']
        files_to_fix = set(v.file for v in trailing_ws)
        
        fixed = 0
        for filepath in files_to_fix:
            lines = self.read_file(filepath)
            if not lines:
                continue
            
            modified = False
            new_lines = []
            
            for line in lines:
                stripped = line.rstrip() + '\n' if line.endswith('\n') else line.rstrip()
                if stripped != line:
                    modified = True
                    fixed += 1
                new_lines.append(stripped)
            
            if modified and not self.dry_run:
                self.backup_file(filepath)
                self.write_file(filepath, new_lines)
        
        print(f"✅ Fixed {fixed} trailing whitespace violations")
        return fixed
    
    def fix_non_optional_string_data(self, violations: List[Violation]) -> int:
        """Fix non-optional string to data conversion."""
        print("\n🔧 Fixing non-optional string→data conversions...")
        
        conversions = [v for v in violations if v.rule_id == 'non_optional_string_data_conversion']
        files_to_fix = {}
        
        for v in conversions:
            if v.file not in files_to_fix:
                files_to_fix[v.file] = []
            files_to_fix[v.file].append(v)
        
        fixed = 0
        for filepath, file_violations in files_to_fix.items():
            lines = self.read_file(filepath)
            if not lines:
                continue
            
            for v in file_violations:
                if v.line > len(lines):
                    continue
                
                line_idx = v.line - 1
                line = lines[line_idx]
                
                # Pattern: string.data(using: .utf8)
                new_line = re.sub(
                    r'(\w+)\.data\(using:\s*\.utf8\)',
                    r'Data(\1.utf8)',
                    line
                )
                
                if new_line != line:
                    if self.dry_run:
                        print(f"  📝 {filepath}:{v.line}")
                        print(f"     - {line.rstrip()}")
                        print(f"     + {new_line.rstrip()}")
                    else:
                        lines[line_idx] = new_line
                        fixed += 1
            
            if not self.dry_run and fixed > 0:
                self.backup_file(filepath)
                self.write_file(filepath, lines)
        
        print(f"✅ Fixed {fixed} string→data conversions")
        return fixed
    
    def fix_closure_spacing(self, violations: List[Violation]) -> int:
        """Fix closure spacing violations."""
        print("\n🔧 Fixing closure spacing...")
        
        spacing_issues = [v for v in violations if v.rule_id == 'closure_spacing']
        files_to_fix = {}
        
        for v in spacing_issues:
            if v.file not in files_to_fix:
                files_to_fix[v.file] = []
            files_to_fix[v.file].append(v)
        
        fixed = 0
        for filepath, file_violations in files_to_fix.items():
            lines = self.read_file(filepath)
            if not lines:
                continue
            
            for v in file_violations:
                if v.line > len(lines):
                    continue
                
                line_idx = v.line - 1
                line = lines[line_idx]
                
                # Fix: { code } → { code }
                new_line = re.sub(r'\{(\S)', r'{ \1', line)  # Add space after {
                new_line = re.sub(r'(\S)\}', r'\1 }', new_line)  # Add space before }
                
                if new_line != line:
                    if self.dry_run:
                        print(f"  📝 {filepath}:{v.line}")
                        print(f"     - {line.rstrip()}")
                        print(f"     + {new_line.rstrip()}")
                    else:
                        lines[line_idx] = new_line
                        fixed += 1
            
            if not self.dry_run and fixed > 0:
                self.backup_file(filepath)
                self.write_file(filepath, lines)
        
        print(f"✅ Fixed {fixed} closure spacing violations")
        return fixed
    
    # ========================================================================
    # MAIN EXECUTION
    # ========================================================================
    
    def fix_all(self, violations: List[Violation]) -> int:
        """Apply all automated fixes."""
        total_fixed = 0
        
        # Order matters - do safest fixes first
        total_fixed += self.fix_trailing_whitespace(violations)
        total_fixed += self.fix_closure_spacing(violations)
        total_fixed += self.fix_non_optional_string_data(violations)
        total_fixed += self.fix_force_unwrap(violations)
        total_fixed += self.fix_force_cast(violations)
        total_fixed += self.fix_large_tuple(violations)
        
        return total_fixed
    
    def fix_rule(self, rule_id: str, violations: List[Violation]) -> int:
        """Fix specific rule violations."""
        rule_fixers = {
            'force_unwrapping': self.fix_force_unwrap,
            'force_cast': self.fix_force_cast,
            'large_tuple': self.fix_large_tuple,
            'trailing_whitespace': self.fix_trailing_whitespace,
            'non_optional_string_data_conversion': self.fix_non_optional_string_data,
            'closure_spacing': self.fix_closure_spacing,
        }
        
        if rule_id not in rule_fixers:
            print(f"❌ No automated fix available for rule: {rule_id}")
            return 0
        
        return rule_fixers[rule_id](violations)
    
    def print_summary(self):
        """Print summary of fixes applied."""
        print("\n" + "=" * 70)
        print("📊 SUMMARY")
        print("=" * 70)
        print(f"Total fixes applied: {self.fixes_applied}")
        print(f"Files modified: {len(self.files_modified)}")
        
        if self.files_modified:
            print("\nModified files:")
            for f in sorted(self.files_modified):
                print(f"  • {f}")
        
        if not self.dry_run:
            print("\n⚠️  Backup files created with .swift.bak extension")
            print("   Review changes and run tests before committing!")
        else:
            print("\n💡 This was a dry run. Use --apply to make changes.")


def main():
    parser = argparse.ArgumentParser(
        description='Automatically fix SwiftLint violations',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Preview all fixes
  python3 Scripts/swiftlint_auto_fix.py --dry-run
  
  # Fix specific rule
  python3 Scripts/swiftlint_auto_fix.py --fix force_unwrapping
  
  # Fix all rules
  python3 Scripts/swiftlint_auto_fix.py --fix all
  
  # Show violation statistics
  python3 Scripts/swiftlint_auto_fix.py --stats
        """
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without modifying files'
    )
    
    parser.add_argument(
        '--fix',
        choices=['all', 'force_unwrapping', 'force_cast', 'large_tuple', 
                 'trailing_whitespace', 'non_optional_string_data_conversion',
                 'closure_spacing'],
        help='Apply fixes for specific rule or all rules'
    )
    
    parser.add_argument(
        '--stats',
        action='store_true',
        help='Show violation statistics'
    )
    
    parser.add_argument(
        '--repo-root',
        type=Path,
        default=Path(__file__).parent.parent,
        help='Repository root directory'
    )
    
    args = parser.parse_args()
    
    # Determine repository root
    repo_root = args.repo_root.resolve()
    if not (repo_root / 'Package.swift').exists():
        print(f"❌ Not a valid repository root: {repo_root}")
        sys.exit(1)
    
    print("=" * 70)
    print("🔧 SwiftLint Auto-Fix Tool")
    print("=" * 70)
    print(f"Repository: {repo_root}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'APPLY FIXES'}")
    print()
    
    # Initialize fixer
    fixer = SwiftLintFixer(repo_root, dry_run=args.dry_run)
    
    # Get violations
    violations = fixer.get_violations()
    
    if not violations:
        print("✅ No violations found!")
        return 0
    
    # Show stats if requested
    if args.stats:
        stats = fixer.get_violation_stats(violations)
        print("\n📊 Violation Statistics:")
        print("-" * 70)
        for rule_id, count in stats.items():
            print(f"  {count:>6} | {rule_id}")
        print("-" * 70)
        print(f"  {len(violations):>6} | TOTAL")
        return 0
    
    # Apply fixes
    if args.fix:
        if args.fix == 'all':
            fixer.fixes_applied = fixer.fix_all(violations)
        else:
            fixer.fixes_applied = fixer.fix_rule(args.fix, violations)
        
        fixer.print_summary()
        return 0
    
    # Default: show help
    parser.print_help()
    return 0


if __name__ == '__main__':
    sys.exit(main())
