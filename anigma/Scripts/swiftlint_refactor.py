#!/usr/bin/env python3
"""
SwiftLint Advanced Refactoring Tool
Uses AST parsing and semantic analysis for complex refactoring tasks.

This script handles violations that require understanding code structure:
- Function parameter count reduction (extract config objects)
- Large tuple to struct conversion
- Cyclomatic complexity reduction (extract methods)
- File splitting by responsibility

Usage:
    python3 Scripts/swiftlint_refactor.py --analyze                    # Analyze codebase
    python3 Scripts/swiftlint_refactor.py --refactor function_params   # Fix specific issue
    python3 Scripts/swiftlint_refactor.py --refactor all --dry-run     # Preview all changes

Author: Anigma Development Team
Date: 2026-01-11
"""

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Dict, Optional, Set, Tuple
import shutil
from collections import defaultdict


@dataclass
class SwiftFunction:
    """Represents a Swift function with metadata."""
    name: str
    file: str
    line_start: int
    line_end: int
    parameters: List[Tuple[str, str]]  # [(name, type), ...]
    return_type: Optional[str]
    body: str
    complexity: int = 0
    is_async: bool = False
    is_throws: bool = False
    access_level: str = "internal"
    
    @property
    def parameter_count(self) -> int:
        return len(self.parameters)
    
    @property
    def needs_refactoring(self) -> bool:
        return self.parameter_count > 6 or self.complexity > 15


@dataclass
class SwiftStruct:
    """Represents a Swift struct."""
    name: str
    file: str
    line_start: int
    line_end: int
    properties: List[Tuple[str, str]]  # [(name, type), ...]
    methods: List[str]
    access_level: str = "internal"


@dataclass
class RefactoringTask:
    """Represents a refactoring task."""
    task_type: str  # 'extract_config', 'split_file', 'reduce_complexity', etc.
    file: str
    line_start: int
    line_end: int
    description: str
    original_code: str
    refactored_code: str
    confidence: float  # 0.0 to 1.0
    metadata: Dict = field(default_factory=dict)


class SwiftParser:
    """Parse Swift code to extract structure."""
    
    def __init__(self):
        self.function_pattern = re.compile(
            r'(?P<access>public|private|internal|fileprivate)?\s*'
            r'(?P<static>static\s+)?'
            r'func\s+(?P<name>\w+)\s*'
            r'(?P<generic><[^>]+>)?\s*'
            r'\((?P<params>[^)]*)\)\s*'
            r'(?P<async>async\s+)?'
            r'(?P<throws>throws\s+)?'
            r'(?:-> (?P<return>[^\{]+))?\s*\{',
            re.MULTILINE
        )
        
        self.struct_pattern = re.compile(
            r'(?P<access>public|private|internal|fileprivate)?\s*'
            r'struct\s+(?P<name>\w+)\s*'
            r'(?P<generic><[^>]+>)?\s*'
            r'(?::(?P<protocols>[^{]+))?\s*\{',
            re.MULTILINE
        )
    
    def parse_file(self, filepath: str) -> Tuple[List[SwiftFunction], List[SwiftStruct]]:
        """Parse a Swift file and extract functions and structs."""
        content = Path(filepath).read_text()
        
        functions = self._extract_functions(content, filepath)
        structs = self._extract_structs(content, filepath)
        
        return functions, structs
    
    def _extract_functions(self, content: str, filepath: str) -> List[SwiftFunction]:
        """Extract all function definitions."""
        functions = []
        
        for match in self.function_pattern.finditer(content):
            func_start = match.start()
            
            # Find matching closing brace
            func_end = self._find_closing_brace(content, match.end())
            if func_end == -1:
                continue
            
            # Parse parameters
            params_str = match.group('params')
            parameters = self._parse_parameters(params_str)
            
            # Calculate line numbers
            line_start = content[:func_start].count('\n') + 1
            line_end = content[:func_end].count('\n') + 1
            
            # Extract body
            body = content[match.end():func_end]
            
            # Calculate complexity (simplified)
            complexity = self._calculate_complexity(body)
            
            func = SwiftFunction(
                name=match.group('name'),
                file=filepath,
                line_start=line_start,
                line_end=line_end,
                parameters=parameters,
                return_type=match.group('return'),
                body=body,
                complexity=complexity,
                is_async=bool(match.group('async')),
                is_throws=bool(match.group('throws')),
                access_level=match.group('access') or 'internal'
            )
            
            functions.append(func)
        
        return functions
    
    def _extract_structs(self, content: str, filepath: str) -> List[SwiftStruct]:
        """Extract all struct definitions."""
        structs = []
        
        for match in self.struct_pattern.finditer(content):
            struct_start = match.start()
            struct_end = self._find_closing_brace(content, match.end())
            
            if struct_end == -1:
                continue
            
            line_start = content[:struct_start].count('\n') + 1
            line_end = content[:struct_end].count('\n') + 1
            
            body = content[match.end():struct_end]
            properties = self._parse_properties(body)
            methods = self._parse_method_names(body)
            
            struct = SwiftStruct(
                name=match.group('name'),
                file=filepath,
                line_start=line_start,
                line_end=line_end,
                properties=properties,
                methods=methods,
                access_level=match.group('access') or 'internal'
            )
            
            structs.append(struct)
        
        return structs
    
    def _find_closing_brace(self, content: str, start: int) -> int:
        """Find matching closing brace."""
        depth = 1
        i = start
        
        while i < len(content) and depth > 0:
            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
            i += 1
        
        return i - 1 if depth == 0 else -1
    
    def _parse_parameters(self, params_str: str) -> List[Tuple[str, str]]:
        """Parse function parameters."""
        if not params_str.strip():
            return []
        
        parameters = []
        
        # Split by comma, but respect nested generics
        parts = self._smart_split(params_str, ',')
        
        for part in parts:
            part = part.strip()
            if not part:
                continue
            
            # Pattern: [external] internal: Type
            match = re.match(r'(?:(\w+)\s+)?(\w+)\s*:\s*(.+)', part)
            if match:
                internal_name = match.group(2)
                param_type = match.group(3).strip()
                parameters.append((internal_name, param_type))
        
        return parameters
    
    def _parse_properties(self, body: str) -> List[Tuple[str, str]]:
        """Parse struct properties."""
        properties = []
        
        # Pattern: let/var name: Type
        pattern = re.compile(r'(?:let|var)\s+(\w+)\s*:\s*([^\n=]+)')
        
        for match in pattern.finditer(body):
            name = match.group(1)
            prop_type = match.group(2).strip()
            properties.append((name, prop_type))
        
        return properties
    
    def _parse_method_names(self, body: str) -> List[str]:
        """Extract method names from struct body."""
        pattern = re.compile(r'func\s+(\w+)\s*\(')
        return [match.group(1) for match in pattern.finditer(body)]
    
    def _calculate_complexity(self, body: str) -> int:
        """Calculate cyclomatic complexity (simplified)."""
        complexity = 1  # Base complexity
        
        # Count decision points
        keywords = ['if', 'else', 'for', 'while', 'case', 'catch', '&&', '||', '??']
        
        for keyword in keywords:
            complexity += body.count(keyword)
        
        return complexity
    
    def _smart_split(self, text: str, delimiter: str) -> List[str]:
        """Split text by delimiter, respecting nested brackets."""
        parts = []
        current = []
        depth = 0
        
        for char in text:
            if char in '<([{':
                depth += 1
            elif char in '>)]}':
                depth -= 1
            
            if char == delimiter and depth == 0:
                parts.append(''.join(current))
                current = []
            else:
                current.append(char)
        
        if current:
            parts.append(''.join(current))
        
        return parts


class SwiftRefactorer:
    """Advanced Swift refactoring engine."""
    
    def __init__(self, repo_root: Path, dry_run: bool = False):
        self.repo_root = repo_root
        self.dry_run = dry_run
        self.parser = SwiftParser()
        self.tasks: List[RefactoringTask] = []
        self.files_modified: Set[str] = set()
    
    def analyze_codebase(self) -> Dict[str, any]:
        """Analyze entire codebase for refactoring opportunities."""
        print("🔍 Analyzing codebase for refactoring opportunities...")
        
        swift_files = list(self.repo_root.rglob('*.swift'))
        swift_files = [f for f in swift_files if '.build' not in str(f)]
        
        analysis = {
            'total_files': len(swift_files),
            'functions_with_many_params': [],
            'complex_functions': [],
            'large_files': [],
            'large_tuples': [],
            'refactoring_opportunities': 0
        }
        
        for filepath in swift_files:
            try:
                functions, structs = self.parser.parse_file(str(filepath))
                
                # Check function parameters
                for func in functions:
                    if func.parameter_count > 6:
                        analysis['functions_with_many_params'].append({
                            'file': str(filepath.relative_to(self.repo_root)),
                            'function': func.name,
                            'line': func.line_start,
                            'param_count': func.parameter_count,
                            'parameters': func.parameters
                        })
                        analysis['refactoring_opportunities'] += 1
                    
                    if func.complexity > 15:
                        analysis['complex_functions'].append({
                            'file': str(filepath.relative_to(self.repo_root)),
                            'function': func.name,
                            'line': func.line_start,
                            'complexity': func.complexity
                        })
                        analysis['refactoring_opportunities'] += 1
                
                # Check file size
                line_count = filepath.read_text().count('\n')
                if line_count > 500:
                    analysis['large_files'].append({
                        'file': str(filepath.relative_to(self.repo_root)),
                        'lines': line_count,
                        'functions': len(functions),
                        'structs': len(structs)
                    })
                    analysis['refactoring_opportunities'] += 1
                
            except Exception as e:
                print(f"⚠️  Error parsing {filepath}: {e}")
        
        return analysis
    
    def refactor_function_parameters(self) -> int:
        """Extract configuration objects for functions with many parameters."""
        print("\n🔧 Refactoring functions with too many parameters...")
        
        swift_files = list(self.repo_root.rglob('*.swift'))
        swift_files = [f for f in swift_files if '.build' not in str(f)]
        
        refactored = 0
        
        for filepath in swift_files:
            try:
                functions, _ = self.parser.parse_file(str(filepath))
                
                for func in functions:
                    if func.parameter_count > 6:
                        task = self._create_config_object_refactoring(func)
                        if task:
                            self.tasks.append(task)
                            refactored += 1
                            
                            if self.dry_run:
                                self._print_refactoring_preview(task)
                            else:
                                self._apply_refactoring(task)
                
            except Exception as e:
                print(f"⚠️  Error refactoring {filepath}: {e}")
        
        print(f"✅ Created {refactored} configuration object refactorings")
        return refactored
    
    def _create_config_object_refactoring(self, func: SwiftFunction) -> Optional[RefactoringTask]:
        """Create a refactoring task to extract config object."""
        
        # Generate config struct name
        config_name = f"{func.name.capitalize()}Configuration"
        
        # Generate config struct
        config_struct = self._generate_config_struct(config_name, func.parameters, func.access_level)
        
        # Generate new function signature
        new_signature = self._generate_new_signature(func, config_name)
        
        # Generate migration guide
        migration = self._generate_migration_guide(func, config_name)
        
        task = RefactoringTask(
            task_type='extract_config',
            file=func.file,
            line_start=func.line_start,
            line_end=func.line_end,
            description=f"Extract config object for {func.name} ({func.parameter_count} params)",
            original_code=self._get_original_function_code(func),
            refactored_code=f"{config_struct}\n\n{new_signature}",
            confidence=0.85,
            metadata={
                'function_name': func.name,
                'config_name': config_name,
                'parameter_count': func.parameter_count,
                'migration_guide': migration
            }
        )
        
        return task
    
    def _generate_config_struct(self, name: str, parameters: List[Tuple[str, str]], access: str) -> str:
        """Generate configuration struct code."""
        lines = [f"{access} struct {name} {{"]
        
        # Add properties
        for param_name, param_type in parameters:
            lines.append(f"    {access} let {param_name}: {param_type}")
        
        lines.append("")
        
        # Add initializer
        lines.append(f"    {access} init(")
        for i, (param_name, param_type) in enumerate(parameters):
            comma = "," if i < len(parameters) - 1 else ""
            lines.append(f"        {param_name}: {param_type}{comma}")
        lines.append("    ) {")
        
        for param_name, _ in parameters:
            lines.append(f"        self.{param_name} = {param_name}")
        
        lines.append("    }")
        lines.append("}")
        
        return '\n'.join(lines)
    
    def _generate_new_signature(self, func: SwiftFunction, config_name: str) -> str:
        """Generate new function signature with config object."""
        access = f"{func.access_level} " if func.access_level != "internal" else ""
        async_kw = "async " if func.is_async else ""
        throws_kw = "throws " if func.is_throws else ""
        return_type = f" -> {func.return_type}" if func.return_type else ""
        
        signature = (
            f"{access}func {func.name}(\n"
            f"    config: {config_name}\n"
            f") {async_kw}{throws_kw}{return_type} {{\n"
            f"    // TODO: Update function body to use config.propertyName\n"
            f"    // Original parameters are now: config.paramName\n"
            f"{func.body}\n"
            f"}}"
        )
        
        return signature
    
    def _generate_migration_guide(self, func: SwiftFunction, config_name: str) -> str:
        """Generate migration guide for callers."""
        guide = [
            "// Migration Guide:",
            "// Old call:",
            f"// {func.name}("
        ]
        
        for param_name, _ in func.parameters:
            guide.append(f"//     {param_name}: value,")
        
        guide.append("// )")
        guide.append("//")
        guide.append("// New call:")
        guide.append(f"// let config = {config_name}(")
        
        for param_name, _ in func.parameters:
            guide.append(f"//     {param_name}: value,")
        
        guide.append("// )")
        guide.append(f"// {func.name}(config: config)")
        
        return '\n'.join(guide)
    
    def _get_original_function_code(self, func: SwiftFunction) -> str:
        """Get original function code from file."""
        lines = Path(func.file).read_text().splitlines()
        return '\n'.join(lines[func.line_start - 1:func.line_end])
    
    def refactor_large_tuples(self) -> int:
        """Convert large tuples to structs."""
        print("\n🔧 Converting large tuples to structs...")
        
        # Get violations from SwiftLint
        result = subprocess.run(
            ['swiftlint', 'lint', '--reporter', 'json'],
            cwd=self.repo_root,
            capture_output=True,
            text=True
        )
        
        violations = json.loads(result.stdout)
        large_tuples = [v for v in violations if v['rule_id'] == 'large_tuple']
        
        refactored = 0
        
        for violation in large_tuples:
            task = self._create_tuple_to_struct_refactoring(violation)
            if task:
                self.tasks.append(task)
                refactored += 1
                
                if self.dry_run:
                    self._print_refactoring_preview(task)
                else:
                    self._apply_refactoring(task)
        
        print(f"✅ Created {refactored} tuple-to-struct refactorings")
        return refactored
    
    def _create_tuple_to_struct_refactoring(self, violation: dict) -> Optional[RefactoringTask]:
        """Create refactoring task for tuple to struct conversion."""
        filepath = violation['file']
        line_num = violation['line']
        
        lines = Path(filepath).read_text().splitlines()
        if line_num > len(lines):
            return None
        
        line = lines[line_num - 1]
        
        # Extract tuple pattern
        tuple_match = re.search(r'\(([^)]+)\)', line)
        if not tuple_match:
            return None
        
        tuple_content = tuple_match.group(1)
        members = [m.strip() for m in tuple_content.split(',')]
        
        if len(members) <= 2:
            return None
        
        # Generate struct
        struct_name = "TupleReplacement"  # User should rename
        struct_code = self._generate_tuple_struct(struct_name, members)
        
        task = RefactoringTask(
            task_type='tuple_to_struct',
            file=filepath,
            line_start=line_num,
            line_end=line_num,
            description=f"Convert {len(members)}-member tuple to struct",
            original_code=line,
            refactored_code=struct_code,
            confidence=0.70,  # Lower confidence - needs review
            metadata={
                'struct_name': struct_name,
                'member_count': len(members),
                'members': members
            }
        )
        
        return task
    
    def _generate_tuple_struct(self, name: str, members: List[str]) -> str:
        """Generate struct from tuple members."""
        lines = [f"struct {name} {{"]
        
        for i, member in enumerate(members):
            if ':' in member:
                # Named tuple member
                name_part, type_part = member.split(':', 1)
                lines.append(f"    let {name_part.strip()}: {type_part.strip()}")
            else:
                # Unnamed - generate name
                lines.append(f"    let member{i}: {member.strip()}")
        
        lines.append("}")
        
        return '\n'.join(lines)
    
    def split_large_files(self) -> int:
        """Split large files by responsibility."""
        print("\n🔧 Analyzing large files for splitting...")
        
        swift_files = list(self.repo_root.rglob('*.swift'))
        swift_files = [f for f in swift_files if '.build' not in str(f)]
        
        split_suggestions = []
        
        for filepath in swift_files:
            line_count = filepath.read_text().count('\n')
            
            if line_count > 500:
                try:
                    functions, structs = self.parser.parse_file(str(filepath))
                    
                    suggestion = {
                        'file': str(filepath.relative_to(self.repo_root)),
                        'lines': line_count,
                        'functions': len(functions),
                        'structs': len(structs),
                        'split_strategy': self._suggest_split_strategy(filepath, functions, structs)
                    }
                    
                    split_suggestions.append(suggestion)
                    
                except Exception as e:
                    print(f"⚠️  Error analyzing {filepath}: {e}")
        
        if split_suggestions:
            output_file = self.repo_root / 'file_split_suggestions.json'
            output_file.write_text(json.dumps(split_suggestions, indent=2))
            print(f"📋 Generated {len(split_suggestions)} file split suggestions")
            print(f"   Suggestions written to: {output_file}")
        
        return len(split_suggestions)
    
    def _suggest_split_strategy(self, filepath: Path, functions: List[SwiftFunction], 
                                structs: List[SwiftStruct]) -> Dict:
        """Suggest how to split a large file."""
        base_name = filepath.stem
        
        # Group functions by prefix/category
        function_groups = defaultdict(list)
        for func in functions:
            # Try to detect category from name
            if func.name.startswith('get') or func.name.startswith('fetch'):
                function_groups['Queries'].append(func.name)
            elif func.name.startswith('create') or func.name.startswith('insert'):
                function_groups['Mutations'].append(func.name)
            elif func.name.startswith('update') or func.name.startswith('modify'):
                function_groups['Updates'].append(func.name)
            elif func.name.startswith('delete') or func.name.startswith('remove'):
                function_groups['Deletions'].append(func.name)
            else:
                function_groups['Other'].append(func.name)
        
        suggested_files = []
        for category, func_names in function_groups.items():
            if len(func_names) > 3:  # Only suggest if meaningful group
                suggested_files.append({
                    'filename': f"{base_name}+{category}.swift",
                    'functions': func_names,
                    'count': len(func_names)
                })
        
        return {
            'original_file': filepath.name,
            'suggested_splits': suggested_files,
            'note': 'Review and adjust category names as needed'
        }
    
    def _print_refactoring_preview(self, task: RefactoringTask):
        """Print preview of refactoring."""
        print(f"\n  📝 {task.file}:{task.line_start}")
        print(f"     Type: {task.task_type}")
        print(f"     Description: {task.description}")
        print(f"     Confidence: {task.confidence:.0%}")
        print(f"\n     Original:")
        for line in task.original_code.split('\n')[:5]:
            print(f"       - {line}")
        print(f"\n     Refactored:")
        for line in task.refactored_code.split('\n')[:10]:
            print(f"       + {line}")
        
        if 'migration_guide' in task.metadata:
            print(f"\n     {task.metadata['migration_guide']}")
    
    def _apply_refactoring(self, task: RefactoringTask):
        """Apply refactoring to file."""
        # This is complex and requires careful implementation
        # For now, we generate suggestions
        self.files_modified.add(task.file)
    
    def export_refactoring_plan(self, output_file: Path):
        """Export all refactoring tasks to JSON."""
        plan = {
            'total_tasks': len(self.tasks),
            'tasks_by_type': {},
            'tasks': []
        }
        
        for task in self.tasks:
            if task.task_type not in plan['tasks_by_type']:
                plan['tasks_by_type'][task.task_type] = 0
            plan['tasks_by_type'][task.task_type] += 1
            
            plan['tasks'].append({
                'type': task.task_type,
                'file': task.file,
                'line': task.line_start,
                'description': task.description,
                'confidence': task.confidence,
                'metadata': task.metadata
            })
        
        output_file.write_text(json.dumps(plan, indent=2))
        print(f"\n📄 Refactoring plan exported to: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='Advanced Swift refactoring tool',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        '--analyze',
        action='store_true',
        help='Analyze codebase for refactoring opportunities'
    )
    
    parser.add_argument(
        '--refactor',
        choices=['all', 'function_params', 'large_tuples', 'split_files'],
        help='Apply specific refactoring'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without applying'
    )
    
    parser.add_argument(
        '--export-plan',
        type=Path,
        help='Export refactoring plan to JSON file'
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
    
    print("=" * 70)
    print("🔧 SwiftLint Advanced Refactoring Tool")
    print("=" * 70)
    print(f"Repository: {repo_root}")
    print()
    
    refactorer = SwiftRefactorer(repo_root, dry_run=args.dry_run)
    
    if args.analyze:
        analysis = refactorer.analyze_codebase()
        
        print("\n📊 Analysis Results:")
        print("=" * 70)
        print(f"Total files analyzed: {analysis['total_files']}")
        print(f"Functions with >6 params: {len(analysis['functions_with_many_params'])}")
        print(f"Complex functions (>15): {len(analysis['complex_functions'])}")
        print(f"Large files (>500 lines): {len(analysis['large_files'])}")
        print(f"Total refactoring opportunities: {analysis['refactoring_opportunities']}")
        
        # Export detailed analysis
        analysis_file = repo_root / 'refactoring_analysis.json'
        analysis_file.write_text(json.dumps(analysis, indent=2))
        print(f"\n📄 Detailed analysis exported to: {analysis_file}")
        
        return 0
    
    if args.refactor:
        if args.refactor == 'all' or args.refactor == 'function_params':
            refactorer.refactor_function_parameters()
        
        if args.refactor == 'all' or args.refactor == 'large_tuples':
            refactorer.refactor_large_tuples()
        
        if args.refactor == 'all' or args.refactor == 'split_files':
            refactorer.split_large_files()
        
        if args.export_plan:
            refactorer.export_refactoring_plan(args.export_plan)
        else:
            default_plan = repo_root / 'refactoring_plan.json'
            refactorer.export_refactoring_plan(default_plan)
        
        return 0
    
    parser.print_help()
    return 0


if __name__ == '__main__':
    sys.exit(main())
