#!/usr/bin/env python3
"""
analyze_build_errors.py
Advanced build error analysis and fix suggestion tool
"""

import re
import json
import sys
from collections import defaultdict, Counter
from dataclasses import dataclass
from typing import List, Dict, Optional
from pathlib import Path

@dataclass
class BuildError:
    """Represents a single build error"""
    file: str
    line: int
    column: int
    message: str
    error_type: str
    context_before: List[str]
    context_after: List[str]
    
    def __repr__(self):
        return f"{self.file}:{self.line}:{self.column} - {self.error_type}: {self.message}"

class BuildErrorAnalyzer:
    """Analyzes Swift build errors and suggests fixes"""
    
    ERROR_PATTERNS = {
        'ambiguous_type': r"ambiguous use of '([^']+)'",
        'cannot_find_type': r"cannot find type '([^']+)'",
        'no_member': r"value of type '([^']+)' has no member '([^']+)'",
        'type_mismatch': r"cannot convert value of type '([^']+)' to expected argument type '([^']+)'",
        'missing_argument': r"missing argument for parameter '([^']+)'",
        'extra_argument': r"extra argument '([^']+)' in call",
        'initializer_error': r"incorrect argument label in call \(have '([^']+)', expected '([^']+)'\)",
    }
    
    def __init__(self, raw_output_file: str):
        self.raw_output_file = raw_output_file
        self.errors: List[BuildError] = []
        self.error_counts: Dict[str, int] = defaultdict(int)
        self.file_errors: Dict[str, List[BuildError]] = defaultdict(list)
        
    def parse_errors(self):
        """Parse raw build output into structured errors"""
        with open(self.raw_output_file, 'r') as f:
            lines = f.readlines()
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Match error line pattern: file.swift:line:column: error: message
            match = re.match(r'^(.+?):(\d+):(\d+):\s+error:\s+(.+)$', line)
            if match:
                file_path = match.group(1)
                line_num = int(match.group(2))
                column = int(match.group(3))
                message = match.group(4).strip()
                
                # Classify error type
                error_type = self._classify_error(message)
                
                # Get context
                context_before = [lines[j].rstrip() for j in range(max(0, i-2), i)]
                context_after = []
                j = i + 1
                while j < len(lines) and j < i + 4:
                    if re.match(r'^.+:\d+:\d+:', lines[j]):
                        break
                    context_after.append(lines[j].rstrip())
                    j += 1
                
                error = BuildError(
                    file=file_path,
                    line=line_num,
                    column=column,
                    message=message,
                    error_type=error_type,
                    context_before=context_before,
                    context_after=context_after
                )
                
                self.errors.append(error)
                self.error_counts[error_type] += 1
                self.file_errors[file_path].append(error)
            
            i += 1
    
    def _classify_error(self, message: str) -> str:
        """Classify error by pattern matching"""
        for error_type, pattern in self.ERROR_PATTERNS.items():
            if re.search(pattern, message):
                return error_type
        return 'other'
    
    def generate_report(self) -> str:
        """Generate a detailed analysis report"""
        report = []
        report.append("=" * 80)
        report.append("ANIGMA BUILD ERROR ANALYSIS")
        report.append("=" * 80)
        report.append("")
        
        # Summary
        report.append(f"Total Errors: {len(self.errors)}")
        report.append(f"Affected Files: {len(self.file_errors)}")
        report.append("")
        
        # Error type breakdown
        report.append("ERROR BREAKDOWN BY TYPE")
        report.append("-" * 80)
        for error_type, count in sorted(self.error_counts.items(), key=lambda x: -x[1]):
            percentage = (count / len(self.errors) * 100) if self.errors else 0
            report.append(f"  {error_type.replace('_', ' ').title()}: {count} ({percentage:.1f}%)")
        report.append("")
        
        # Top affected files
        report.append("TOP 10 FILES WITH MOST ERRORS")
        report.append("-" * 80)
        sorted_files = sorted(self.file_errors.items(), key=lambda x: -len(x[1]))[:10]
        for file_path, errors in sorted_files:
            short_path = Path(file_path).name
            report.append(f"  {short_path}: {len(errors)} errors")
        report.append("")
        
        # Suggested fixes by error type
        report.append("SUGGESTED FIXES")
        report.append("=" * 80)
        report.append("")
        
        fixes = self._generate_fixes()
        for fix_category, suggestions in fixes.items():
            if suggestions:
                report.append(f"### {fix_category}")
                report.append("")
                for suggestion in suggestions:
                    report.append(f"  • {suggestion}")
                report.append("")
        
        # Detailed errors
        report.append("DETAILED ERRORS (First 20)")
        report.append("=" * 80)
        report.append("")
        
        for i, error in enumerate(self.errors[:20], 1):
            report.append(f"{i}. {error}")
            report.append(f"   File: {Path(error.file).name}")
            if error.context_after:
                report.append(f"   Context: {error.context_after[0][:60]}...")
            report.append("")
        
        return "\n".join(report)
    
    def _generate_fixes(self) -> Dict[str, List[str]]:
        """Generate fix suggestions based on error patterns"""
        fixes = defaultdict(list)
        
        # Analyze ambiguous types
        ambiguous_types = []
        for error in self.errors:
            if error.error_type == 'ambiguous_type':
                match = re.search(r"ambiguous use of '([^']+)'", error.message)
                if match:
                    ambiguous_types.append(match.group(1))
        
        if ambiguous_types:
            type_counts = Counter(ambiguous_types)
            fixes["Type Ambiguity Fixes"].append(
                "Multiple types with same name found. Use fully qualified names:"
            )
            for type_name, count in type_counts.most_common(5):
                fixes["Type Ambiguity Fixes"].append(
                    f"  Replace '{type_name}' with 'ModuleName.{type_name}' ({count} occurrences)"
                )
                fixes["Type Ambiguity Fixes"].append(
                    f"  Try: AnigmaHostMac.{type_name} or ExportCore.{type_name}"
                )
        
        # Analyze missing members
        missing_members = []
        for error in self.errors:
            if error.error_type == 'no_member':
                match = re.search(r"value of type '([^']+)' has no member '([^']+)'", error.message)
                if match:
                    type_name = match.group(1)
                    member_name = match.group(2)
                    missing_members.append((type_name, member_name))
        
        if missing_members:
            fixes["Missing Member Fixes"].append(
                "Types are missing expected properties/methods. Possible causes:"
            )
            fixes["Missing Member Fixes"].append(
                "  - API changed in dependency (check module documentation)"
            )
            fixes["Missing Member Fixes"].append(
                "  - Using wrong type (check type name)"
            )
            
            for type_name, member_name in set(missing_members)[:5]:
                fixes["Missing Member Fixes"].append(
                    f"  Type '{type_name}' is missing '{member_name}'"
                )
        
        # Analyze initializer errors
        init_errors = [e for e in self.errors if error.error_type == 'initializer_error']
        if init_errors:
            fixes["Initializer Fixes"].append(
                "Initializer signatures have changed. Update call sites:"
            )
            for error in init_errors[:3]:
                fixes["Initializer Fixes"].append(
                    f"  {Path(error.file).name}:{error.line} - {error.message}"
                )
        
        # General recommendations
        fixes["General Recommendations"].append(
            "1. Fix errors in order - many errors cascade from earlier ones"
        )
        fixes["General Recommendations"].append(
            "2. Focus on files with most errors first"
        )
        fixes["General Recommendations"].append(
            "3. Check BINARY_BUNDLE_COMPLETE.md for known issues"
        )
        fixes["General Recommendations"].append(
            "4. Consider creating typealiases for commonly ambiguous types"
        )
        
        return fixes
    
    def export_json(self, output_file: str):
        """Export analysis as JSON"""
        data = {
            "total_errors": len(self.errors),
            "affected_files": len(self.file_errors),
            "error_counts": dict(self.error_counts),
            "top_files": [
                {"file": file, "error_count": len(errors)}
                for file, errors in sorted(self.file_errors.items(), key=lambda x: -len(x[1]))[:10]
            ],
            "errors": [
                {
                    "file": error.file,
                    "line": error.line,
                    "column": error.column,
                    "type": error.error_type,
                    "message": error.message
                }
                for error in self.errors[:50]  # Limit to first 50 for JSON size
            ]
        }
        
        with open(output_file, 'w') as f:
            json.dump(data, f, indent=2)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_build_errors.py <raw_build_output.txt>")
        print("")
        print("This script performs advanced analysis of Swift build errors.")
        sys.exit(1)
    
    raw_output = sys.argv[1]
    
    if not Path(raw_output).exists():
        print(f"Error: File not found: {raw_output}")
        print("")
        print("Run this first:")
        print("  bash capture_build_errors.sh")
        sys.exit(1)
    
    print("🔍 Analyzing build errors...")
    print("")
    
    analyzer = BuildErrorAnalyzer(raw_output)
    analyzer.parse_errors()
    
    if not analyzer.errors:
        print("✅ No errors found!")
        sys.exit(0)
    
    # Generate and print report
    report = analyzer.generate_report()
    print(report)
    
    # Save detailed report
    report_file = "build_errors_analysis.txt"
    with open(report_file, 'w') as f:
        f.write(report)
    
    # Export JSON
    json_file = "build_errors_analysis.json"
    analyzer.export_json(json_file)
    
    print("")
    print("=" * 80)
    print("📊 Reports Generated:")
    print("=" * 80)
    print(f"  Text report: {report_file}")
    print(f"  JSON data:   {json_file}")
    print("")
    print("Next: Review the 'SUGGESTED FIXES' section above")
    print("")

if __name__ == "__main__":
    main()
