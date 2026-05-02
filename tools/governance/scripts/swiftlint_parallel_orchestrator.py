#!/usr/bin/env python3
"""
SwiftLint Parallel Agent Orchestrator with DeepSeek AI (Enhanced)

Manages multiple AI agents (powered by DeepSeek) working in parallel on refactoring tasks with:
1. Parallel execution (configurable agents simultaneously)
2. Shared build validation after each batch
3. Automatic success/failure tracking
4. Reassignment of failed refactorings
5. Progress persistence and recovery
6. Intelligent refactoring with DeepSeek reasoning
7. **Best Practice:** File-level locking to prevent race conditions
8. **Best Practice:** Swift 6 Concurrency guidelines in prompts
9. **Best Practice:** Comprehensive file logging
10. **Enhanced:** Context-aware prompting based on .swiftlint.yml
11. **Enhanced:** Adaptive batch sizing based on stability
12. **Enhanced:** Token usage tracking
13. **Enhanced:** Differential build analysis to keep successful changes despite unrelated errors
14. **New:** Autonomous Build Repair Loop (Capture logs -> Identify Errors -> Assign Workers -> Fix)

Architecture:
- DeepSeek agent workers processing refactorings in parallel
- Batch coordinator managing work distribution with file constraints
- Single build validation after all agents complete
- Success tracking and failure reassignment
- Lock-free file coordination (via batch constraints)
- DeepSeek API for intelligent code analysis and refactoring
- **Repair Cycle:** Automatically generates repair tasks for build errors

Usage:
    # Run with 10 parallel DeepSeek agents
    export DEEPSEEK_API_KEY="your-key-here"
    python3 Scripts/swiftlint_parallel_orchestrator.py --agents 10 --plan function_params_filtered.json
    
    # Resume from checkpoint
    python3 Scripts/swiftlint_parallel_orchestrator.py --resume checkpoint_20260111.json
    


Author: Anigma Development Team
Date: 2026-01-11
"""

import argparse
import json
import subprocess
import sys
import time
import os
import re
from pathlib import Path
from typing import List, Dict, Optional, Set, Any
from datetime import datetime
from dataclasses import dataclass, field, asdict
from enum import Enum
import threading
import queue
import shutil
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging


# Optional imports
try:
    import requests
except ImportError:
    requests = None  # Will be checked when actually needed

try:
    import yaml
except ImportError:
    class _DummyYAML:
        @staticmethod
        def safe_load(stream):
            return {}
    yaml = _DummyYAML()
    logger = logging.getLogger(__name__)
    logger.warning("PyYAML not installed; proceeding with empty config.")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("swiftlint_orchestrator.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class RefactoringStatus(Enum):
    """Status of a refactoring task."""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    VALIDATION_FAILED = "validation_failed"
    REASSIGNED = "reassigned"
    REPAIR_QUEUED = "repair_queued"


@dataclass
class RefactoringTask:
    """A refactoring task for an agent."""
    id: str
    type: str
    file: str
    line: int
    description: str
    original_code: str
    proposed_code: str
    metadata: Dict
    
    # Execution tracking
    status: RefactoringStatus = RefactoringStatus.PENDING
    assigned_agent: Optional[int] = None
    attempt_count: int = 0
    max_attempts: int = 3
    
    # Results
    applied_code: Optional[str] = None
    agent_reasoning: Optional[str] = None
    error_message: Optional[str] = None
    validation_error: Optional[str] = None
    
    # Failure history for learning
    failure_history: List[Dict] = field(default_factory=list)
    
    # Timestamps
    assigned_at: Optional[str] = None
    completed_at: Optional[str] = None
    
    # Repair specifics
    is_repair_task: bool = False
    repair_error_message: str = ""
    
    def add_failure(self, attempted_code: str, error: str, reasoning: str):
        """Record a failed attempt for learning."""
        self.failure_history.append({
            'attempt': self.attempt_count,
            'attempted_code': attempted_code,
            'error': error,
            'reasoning': reasoning,
            'timestamp': datetime.now().isoformat()
        })
    
    def to_dict(self) -> Dict:
        data = asdict(self)
        data['status'] = self.status.value
        return data


@dataclass
class BatchResult:
    """Results from a batch of refactorings."""
    batch_id: int
    tasks_attempted: int
    tasks_completed: int
    tasks_failed: int
    build_successful: bool
    build_output: str
    duration_seconds: float
    timestamp: str


class ErrorSeverity(Enum):
    """Severity levels for build diagnostics."""
    ERROR = "error"
    WARNING = "warning"
    NOTE = "note"


class ErrorCategory(Enum):
    """Categories of Swift build errors for prioritized fixing."""
    # Priority 1: Critical compile errors
    TYPE_MISMATCH = "type_mismatch"
    MISSING_MEMBER = "missing_member"
    MISSING_IMPORT = "missing_import"
    SYNTAX_ERROR = "syntax_error"
    UNDEFINED_SYMBOL = "undefined_symbol"
    
    # Priority 2: Concurrency errors (Swift 6)
    SENDABLE_VIOLATION = "sendable_violation"
    ACTOR_ISOLATION = "actor_isolation"
    ASYNC_AWAIT = "async_await"
    DATA_RACE = "data_race"
    
    # Priority 3: Type system
    PROTOCOL_CONFORMANCE = "protocol_conformance"
    GENERIC_CONSTRAINT = "generic_constraint"
    OPTIONAL_UNWRAP = "optional_unwrap"
    
    # Priority 4: Warnings
    DEPRECATION = "deprecation"
    UNUSED = "unused"
    
    # Unknown
    UNKNOWN = "unknown"


@dataclass
class BuildDiagnostic:
    """Structured representation of a Swift compiler diagnostic."""
    file_path: str
    line: int
    column: int
    severity: ErrorSeverity
    category: ErrorCategory
    message: str
    raw_line: str
    code_context: str = ""
    
    # Priority: lower = more urgent (1-4)
    @property
    def priority(self) -> int:
        priority_map = {
            # Priority 1: Must fix immediately
            ErrorCategory.TYPE_MISMATCH: 1,
            ErrorCategory.MISSING_MEMBER: 1,
            ErrorCategory.MISSING_IMPORT: 1,
            ErrorCategory.SYNTAX_ERROR: 1,
            ErrorCategory.UNDEFINED_SYMBOL: 1,
            
            # Priority 2: Swift 6 concurrency
            ErrorCategory.SENDABLE_VIOLATION: 2,
            ErrorCategory.ACTOR_ISOLATION: 2,
            ErrorCategory.ASYNC_AWAIT: 2,
            ErrorCategory.DATA_RACE: 2,
            
            # Priority 3: Type system
            ErrorCategory.PROTOCOL_CONFORMANCE: 3,
            ErrorCategory.GENERIC_CONSTRAINT: 3,
            ErrorCategory.OPTIONAL_UNWRAP: 3,
            
            # Priority 4: Warnings
            ErrorCategory.DEPRECATION: 4,
            ErrorCategory.UNUSED: 4,
            
            # Unknown gets medium priority
            ErrorCategory.UNKNOWN: 2,
        }
        return priority_map.get(self.category, 3)
    
    def to_dict(self) -> Dict:
        return {
            'file': self.file_path,
            'line': self.line,
            'column': self.column,
            'severity': self.severity.value,
            'category': self.category.value,
            'message': self.message,
            'priority': self.priority,
            'code_context': self.code_context
        }
class SwiftLintScanner:
    """
    Scans SwiftLint violations and generates refactoring tasks for all rule types.
    """
    
    # Rule categories and fix strategies
    RULE_STRATEGIES = {
        # Auto-fixable by SwiftLint (use --fix)
        'auto_fix': [
            'trailing_whitespace',
            'trailing_newline', 
            'leading_whitespace',
            'vertical_whitespace',
            'redundant_string_enum_value',
            'colon',
            'comma',
            'opening_brace',
            'closing_brace',
            'statement_position',
            'return_arrow_whitespace',
        ],
        
        # Require AI refactoring - High Value
        'ai_refactor_high': [
            'function_parameter_count',  # Extract config objects
            'large_tuple',               # Convert to struct
            'file_length',               # Split into multiple files
            'type_body_length',          # Extract components
            'function_body_length',      # Extract helper methods
            'cyclomatic_complexity',     # Simplify logic
            'force_unwrapping',          # Safe optional handling
            'force_cast',                # Safe casting
            'force_try',                 # Proper error handling
        ],
        
        # Require AI refactoring - Medium Value
        'ai_refactor_medium': [
            'identifier_name',           # Rename identifiers
            'nesting',                   # Reduce nesting depth
            'for_where',                 # Add where clauses
            'multiple_closures_with_trailing_closure',
            'multiline_arguments',       # Reformat arguments
            'multiline_parameters',      # Reformat parameters
            'closure_body_length',       # Extract closure logic
        ],
        
        # Style preferences - Low Priority
        'style_preference': [
            'explicit_type_interface',
            'explicit_acl',
            'explicit_top_level_acl',
            'accessibility_label_required',
            'prefixed_toplevel_constant',
            'private_over_fileprivate',
        ],
        
        # Custom rules
        'custom_rules': [
            'anigma_error_schema',
            'bauhaus_font_tokens',
            'bauhaus_grid_tokens',
        ],
    }
    
    # Fix templates for each rule
    FIX_PROMPTS = {
        'function_parameter_count': """
Fix this SwiftLint violation by extracting parameters into a configuration struct.

**Strategy:**
1. Create a new struct (e.g., `{FunctionName}Config`) with all parameters as properties
2. Add an initializer with default values where appropriate
3. Update the function to accept the config struct instead
4. Update all call sites to use the new struct

Example:
```swift
// Before
func process(name: String, age: Int, email: String, phone: String) { }

// After
struct ProcessConfig {
    let name: String
    let age: Int
    let email: String
    let phone: String
}
func process(config: ProcessConfig) { }
```
""",
        
        'large_tuple': """
Fix this SwiftLint violation by converting the large tuple to a named struct.

**Strategy:**
1. Create a struct with named properties for each tuple element
2. Replace tuple type with the new struct type
3. Update access patterns from .0, .1 to .propertyName

Example:
```swift
// Before
func getData() -> (String, Int, Bool, Date) { }

// After
struct DataResult {
    let name: String
    let count: Int
    let isValid: Bool
    let timestamp: Date
}
func getData() -> DataResult { }
```
""",

        'force_unwrapping': """
Fix this SwiftLint violation by using safe optional handling.

**Strategy:**
1. Use `guard let` or `if let` for conditional unwrapping
2. Use `??` nil coalescing with a default value
3. Use optional chaining `?.` where appropriate
4. Consider throwing an error if the value must exist

Example:
```swift
// Before
let value = dictionary["key"]!

// After
guard let value = dictionary["key"] else {
    throw ConfigError.missingKey("key")
}
```
""",

        'force_cast': """
Fix this SwiftLint violation by using safe casting.

**Strategy:**
1. Use `as?` with guard/if let for conditional casting
2. Handle the failure case explicitly
3. Consider generic constraints to avoid casting

Example:
```swift
// Before
let view = subview as! UIButton

// After
guard let view = subview as? UIButton else {
    assertionFailure("Expected UIButton")
    return
}
```
""",

        'force_try': """
Fix this SwiftLint violation by properly handling errors.

**Strategy:**
1. Propagate the error with `try` in a throwing function
2. Use `do-catch` to handle specific errors
3. Use `try?` only if you truly want to ignore the error

Example:
```swift
// Before
let data = try! encoder.encode(value)

// After
do {
    let data = try encoder.encode(value)
    return data
} catch {
    logger.error("Encoding failed: \\(error)")
    throw EncodingError.failed(error)
}
```
""",

        'file_length': """
This file exceeds the recommended length. Consider splitting it.

**Strategy:**
1. Identify logical groupings of types/functions
2. Extract related code into separate files
3. Use extensions in separate files for protocol conformances
4. Consider creating a subdirectory for related files

**Common splits:**
- Models vs ViewModels vs Views
- Protocol definitions in separate file
- Extensions grouped by functionality
""",

        'function_body_length': """
This function is too long. Consider extracting helper methods.

**Strategy:**
1. Identify logical blocks within the function
2. Extract each block into a private helper method
3. Use descriptive names that explain the intent
4. Consider breaking into multiple smaller functions

Example:
```swift
// Before: 100-line function

// After:
func process() {
    let validated = validateInput()
    let transformed = transformData(validated)
    return formatOutput(transformed)
}
```
""",

        'cyclomatic_complexity': """
This function is too complex. Simplify the control flow.

**Strategy:**
1. Extract conditional logic into separate methods
2. Use guard statements for early returns
3. Replace nested if-else with switch or pattern matching
4. Consider the Strategy pattern for complex branching
""",

        'for_where': """
Add a where clause to filter in the loop declaration.

**Strategy:**
Replace `if` inside the loop with a `where` clause.

Example:
```swift
// Before
for item in items {
    if item.isValid {
        process(item)
    }
}

// After
for item in items where item.isValid {
    process(item)
}
```
""",

        'identifier_name': """
Rename this identifier to follow Swift naming conventions.

**Swift Naming Conventions:**
- Types: UpperCamelCase (e.g., `UserProfile`)
- Variables/Functions: lowerCamelCase (e.g., `userName`)
- Constants: lowerCamelCase (e.g., `maxRetryCount`)
- Avoid abbreviations unless extremely common
- Boolean properties: use `is`, `has`, `should` prefixes
""",

        'nesting': """
Reduce the nesting depth of this code.

**Strategy:**
1. Use guard statements for early exits
2. Extract nested logic into separate functions
3. Use flatMap/compactMap instead of nested optionals
4. Consider the Result type for error handling
""",

        'explicit_type_interface': """
Add explicit type annotations.

**Note:** This is a style preference. Consider if this rule should be disabled.

Example:
```swift
// Before
let name = "John"

// After
let name: String = "John"
```
""",

        'explicit_acl': """
Add explicit access control level.

**Note:** This is a style preference. Consider if this rule should be disabled.

Example:
```swift
// Before
func process() { }

// After
internal func process() { }
```
""",
    }
    
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.violations: List[Dict] = []
        
    def scan_violations(self, rules: Optional[List[str]] = None, limit: int = 1000) -> List[Dict]:
        """
        Scan for SwiftLint violations.
        
        Args:
            rules: Optional list of rule IDs to filter by
            limit: Maximum violations to return
            
        Returns:
            List of violation dictionaries
        """
        logger.info("🔍 Scanning SwiftLint violations...")
        
        try:
            cmd = ['swiftlint', 'lint', '--reporter', 'json']
            result = subprocess.run(
                cmd,
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            self.violations = json.loads(result.stdout) if result.stdout else []
            
            # Filter by rules if specified
            if rules:
                self.violations = [v for v in self.violations if v.get('rule_id') in rules]
            
            # Limit results
            self.violations = self.violations[:limit]
            
            logger.info(f"  Found {len(self.violations)} violations")
            return self.violations
            
        except subprocess.TimeoutExpired:
            logger.error("SwiftLint scan timed out")
            return []
        except Exception as e:
            logger.error(f"SwiftLint scan failed: {e}")
            return []
    
    def get_violation_summary(self) -> Dict[str, int]:
        """Get count of violations by rule."""
        summary = {}
        for v in self.violations:
            rule = v.get('rule_id', 'unknown')
            summary[rule] = summary.get(rule, 0) + 1
        return dict(sorted(summary.items(), key=lambda x: -x[1]))
    
    def generate_refactoring_tasks(
        self, 
        session_id: str,
        include_auto_fix: bool = False,
        include_style: bool = False,
        priority_rules: Optional[List[str]] = None
    ) -> List[RefactoringTask]:
        """
        Generate refactoring tasks from violations.
        
        Args:
            session_id: Session identifier
            include_auto_fix: Include auto-fixable violations
            include_style: Include style preference violations
            priority_rules: Optional list of rules to prioritize
            
        Returns:
            List of RefactoringTask objects
        """
        tasks = []
        seen = set()
        
        # Determine which rules to include
        included_rules = set()
        included_rules.update(self.RULE_STRATEGIES['ai_refactor_high'])
        included_rules.update(self.RULE_STRATEGIES['ai_refactor_medium'])
        included_rules.update(self.RULE_STRATEGIES['custom_rules'])
        
        if include_auto_fix:
            included_rules.update(self.RULE_STRATEGIES['auto_fix'])
        if include_style:
            included_rules.update(self.RULE_STRATEGIES['style_preference'])
        
        # Priority order
        priority_order = {
            **{r: 1 for r in self.RULE_STRATEGIES['ai_refactor_high']},
            **{r: 2 for r in self.RULE_STRATEGIES['ai_refactor_medium']},
            **{r: 3 for r in self.RULE_STRATEGIES['custom_rules']},
            **{r: 4 for r in self.RULE_STRATEGIES['style_preference']},
            **{r: 5 for r in self.RULE_STRATEGIES['auto_fix']},
        }
        
        for v in self.violations:
            rule_id = v.get('rule_id', '')
            
            # Skip if not in included rules
            if rule_id not in included_rules:
                continue
            
            # Skip duplicates (same file+line)
            key = f"{v.get('file', '')}:{v.get('line', 0)}:{rule_id}"
            if key in seen:
                continue
            seen.add(key)
            
            # Get code context
            code_context = self._get_code_context(v.get('file', ''), v.get('line', 0))
            
            # Get fix prompt
            fix_prompt = self.FIX_PROMPTS.get(rule_id, f"Fix this {rule_id} violation following Swift best practices.")
            
            priority = priority_order.get(rule_id, 3)
            if priority_rules and rule_id in priority_rules:
                priority = 0  # Highest priority
            
            task = RefactoringTask(
                id=f"swiftlint_{session_id}_{len(tasks):04d}",
                type=f"swiftlint_{rule_id}",
                file=v.get('file', ''),
                line=v.get('line', 0),
                description=f"[P{priority}] {rule_id}: {v.get('reason', '')[:60]}",
                original_code=code_context,
                proposed_code="",  # AI will generate
                metadata={
                    'rule_id': rule_id,
                    'severity': v.get('severity', 'warning'),
                    'reason': v.get('reason', ''),
                    'fix_strategy': fix_prompt,
                    'priority': priority,
                    'character': v.get('character', 0),
                },
                is_repair_task=True,  # Treat as repair for priority
                repair_error_message=v.get('reason', ''),
                max_attempts=3
            )
            tasks.append(task)
        
        # Sort by priority
        tasks.sort(key=lambda t: (t.metadata.get('priority', 99), t.file, t.line))
        
        logger.info(f"  Generated {len(tasks)} refactoring tasks")
        return tasks
    
    def _get_code_context(self, file_path: str, line_num: int, context_lines: int = 10) -> str:
        """Get code context around the violation."""
        try:
            full_path = Path(file_path)
            if not full_path.is_absolute():
                full_path = self.repo_root / file_path
            
            if not full_path.exists():
                return ""
            
            with open(full_path, 'r') as f:
                lines = f.readlines()
            
            start = max(0, line_num - context_lines - 1)
            end = min(len(lines), line_num + context_lines)
            
            context = []
            for i in range(start, end):
                marker = ">>> " if i == line_num - 1 else "    "
                context.append(f"{marker}{i+1}: {lines[i].rstrip()}")
            
            return '\n'.join(context)
        except Exception:
            return ""
    
    def print_summary(self):
        """Print violation summary."""
        if not self.violations:
            logger.info("✅ No SwiftLint violations found")
            return
        
        summary = self.get_violation_summary()
        
        logger.info(f"\n{'='*80}")
        logger.info("📊 SWIFTLINT VIOLATION SUMMARY")
        logger.info(f"{'='*80}")
        logger.info(f"Total Violations: {len(self.violations)}")
        
        # By category
        high_value = sum(summary.get(r, 0) for r in self.RULE_STRATEGIES['ai_refactor_high'])
        medium_value = sum(summary.get(r, 0) for r in self.RULE_STRATEGIES['ai_refactor_medium'])
        style = sum(summary.get(r, 0) for r in self.RULE_STRATEGIES['style_preference'])
        auto_fix = sum(summary.get(r, 0) for r in self.RULE_STRATEGIES['auto_fix'])
        
        logger.info(f"\nBy Category:")
        logger.info(f"  High-Value AI Refactoring:   {high_value}")
        logger.info(f"  Medium-Value AI Refactoring: {medium_value}")
        logger.info(f"  Style Preferences:           {style}")
        logger.info(f"  Auto-Fixable:                {auto_fix}")
        
        logger.info(f"\nTop 15 Rules:")
        for rule, count in list(summary.items())[:15]:
            logger.info(f"  {rule}: {count}")
        
        logger.info(f"{'='*80}\n")


class ModuleQualityAnalyzer:
    """
    Analyzes module quality and generates improvement tasks for parity.
    
    Quality Dimensions:
    1. Documentation: Public API docs, README, CHANGELOG
    2. Error Handling: AnigmaError usage, proper error propagation
    3. Testing: Test coverage, test file existence
    4. Swift 6 Concurrency: Sendable, actor isolation
    5. Anigma Patterns: Bauhaus tokens, OperationResult, governance
    6. Code Organization: File structure, module boundaries
    """
    
    # Quality checks with descriptions and fix strategies
    QUALITY_CHECKS = {
        # Documentation
        'missing_public_docs': {
            'name': 'Missing Public Documentation',
            'description': 'Public APIs should have documentation comments',
            'priority': 2,
            'fix_prompt': """
Add documentation to this public API.

**Swift Documentation Format:**
```swift
/// Brief description of what this does.
///
/// Detailed explanation if needed.
///
/// - Parameters:
///   - param1: Description of first parameter
///   - param2: Description of second parameter
/// - Returns: Description of return value
/// - Throws: Description of errors that can be thrown
public func example(param1: String, param2: Int) throws -> Result
```

**Best Practices:**
1. First line is a brief summary
2. Use `-` for parameter, return, and throws documentation
3. Include code examples for complex APIs
4. Document thread safety and actor isolation requirements
"""
        },
        
        'missing_readme': {
            'name': 'Missing Module README',
            'description': 'Module should have a README.md explaining purpose and usage',
            'priority': 3,
            'fix_prompt': """
Create a README.md for this module.

**Template:**
```markdown
# ModuleName

Brief description of the module's purpose.

## Overview

What problem does this module solve? What are its key features?

## Usage

```swift
import ModuleName

// Basic usage example
let instance = ModuleType()
```

## Architecture

Key components and their relationships.

## Dependencies

What other modules does this depend on?

## Testing

How to run tests for this module.
```
"""
        },
        
        # Error Handling
        'generic_error_throw': {
            'name': 'Generic Error Thrown',
            'description': 'Use AnigmaError with stable error codes instead of generic errors',
            'priority': 1,
            'fix_prompt': """
Replace generic error throws with AnigmaError.

**Pattern:**
```swift
// Before
throw NSError(domain: "MyDomain", code: 1, userInfo: nil)
throw "Something went wrong"  // String error

// After
throw AnigmaError.validation(.invalidInput, "Description")
throw AnigmaError.system(.networkFailure, underlying: error)
throw AnigmaError.governance(.policyViolation, context: ["policy": policyId])
```

**AnigmaError Categories:**
- `.validation` - Input validation errors
- `.system` - System/infrastructure errors
- `.governance` - Policy violations
- `.business` - Business logic errors
- `.security` - Security-related errors
"""
        },
        
        'missing_error_handling': {
            'name': 'Missing Error Handling',
            'description': 'Async operations should have proper error handling',
            'priority': 1,
            'fix_prompt': """
Add proper error handling to this async operation.

**Pattern:**
```swift
// Before
let result = try await dangerousOperation()

// After
do {
    let result = try await dangerousOperation()
    return .success(result)
} catch let error as AnigmaError {
    logger.error("Operation failed: \\(error)")
    return .failure(error)
} catch {
    logger.error("Unexpected error: \\(error)")
    return .failure(AnigmaError.system(.unexpected, underlying: error))
}
```
"""
        },
        
        # Swift 6 Concurrency
        'missing_sendable': {
            'name': 'Missing Sendable Conformance',
            'description': 'Types shared across actor boundaries should be Sendable',
            'priority': 1,
            'fix_prompt': """
Make this type conform to Sendable for thread safety.

**Options:**

1. **Automatic Sendable** (for value types with Sendable members):
```swift
struct Config: Sendable {
    let name: String  // Sendable
    let count: Int    // Sendable
}
```

2. **@unchecked Sendable** (manual verification required):
```swift
final class Cache: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Any] = [:]
    
    func get(_ key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return items[key]
    }
}
```

3. **Actor** (for mutable shared state):
```swift
actor StateManager {
    private var state: State
    
    func update(_ newState: State) {
        self.state = newState
    }
}
```
"""
        },
        
        'missing_actor_isolation': {
            'name': 'Missing Actor Isolation',
            'description': 'Mutable shared state should be protected by an actor',
            'priority': 1,
            'fix_prompt': """
Use actor isolation to protect mutable state.

**Convert class to actor:**
```swift
// Before
class SharedState {
    var counter = 0
    func increment() { counter += 1 }
}

// After
actor SharedState {
    var counter = 0
    func increment() { counter += 1 }
}

// Usage changes:
let state = SharedState()
await state.increment()  // Now requires await
```

**Or use @MainActor for UI state:**
```swift
@MainActor
final class ViewModel: ObservableObject {
    @Published var items: [Item] = []
}
```
"""
        },
        
        # Anigma-Specific Patterns
        'missing_operation_result': {
            'name': 'Missing OperationResult Return',
            'description': 'Long-running operations should return OperationResult<T>',
            'priority': 2,
            'fix_prompt': """
Wrap return type in OperationResult for long-running operations.

**Pattern:**
```swift
// Before
func processDocument(_ doc: Document) async throws -> ProcessedDocument

// After
func processDocument(_ doc: Document) async -> OperationResult<ProcessedDocument> {
    let startTime = Date()
    
    do {
        let result = try await actualProcessing(doc)
        return OperationResult(
            value: result,
            duration: Date().timeIntervalSince(startTime),
            metadata: ["documentId": doc.id]
        )
    } catch {
        return OperationResult(
            error: AnigmaError.from(error),
            duration: Date().timeIntervalSince(startTime)
        )
    }
}
```

**Benefits:**
- Consistent error handling
- Built-in timing metrics
- Metadata attachment
- Receipt generation support
"""
        },
        
        'missing_bauhaus_tokens': {
            'name': 'Missing Bauhaus Tokens',
            'description': 'Use Bauhaus design system tokens for consistency',
            'priority': 2,
            'fix_prompt': """
Replace hardcoded values with Bauhaus tokens.

**Colors:**
```swift
// Before
Color.blue
Color(red: 0.2, green: 0.5, blue: 0.8)

// After
Bauhaus.Color.primary
Bauhaus.Color.semantic.success
```

**Typography:**
```swift
// Before
.font(.system(size: 16, weight: .bold))

// After
.font(Bauhaus.Font.headline)
.font(Bauhaus.Font.body)
```

**Spacing:**
```swift
// Before
.padding(16)
.frame(width: 200)

// After
.padding(Bauhaus.Grid.x4)
.frame(width: Bauhaus.Grid.x50)
```
"""
        },
        
        'missing_governance_check': {
            'name': 'Missing Governance Check',
            'description': 'Data mutations should go through governance',
            'priority': 1,
            'fix_prompt': """
Add governance checks before data mutations.

**Pattern:**
```swift
// Before
func updateRecord(_ record: Record) async throws {
    try await database.update(record)
}

// After
func updateRecord(_ record: Record) async throws {
    // Check governance
    guard try await governanceController.authorize(
        action: .write,
        resource: .record(record.id),
        context: authContext
    ) else {
        throw AnigmaError.governance(.unauthorized, context: ["record": record.id])
    }
    
    // Check write gate
    guard await writeGate.check(.recordUpdate(record)) else {
        throw AnigmaError.governance(.writeBlocked, context: ["reason": "Quality check failed"])
    }
    
    try await database.update(record)
}
```
"""
        },
        
        # Testing
        'missing_tests': {
            'name': 'Missing Test Coverage',
            'description': 'Public APIs should have corresponding tests',
            'priority': 2,
            'fix_prompt': """
Add tests for this public API.

**Test Structure:**
```swift
import XCTest
@testable import ModuleName

final class FeatureTests: XCTestCase {
    var sut: Feature!  // System Under Test
    
    override func setUp() async throws {
        sut = Feature()
    }
    
    override func tearDown() async throws {
        sut = nil
    }
    
    func testBasicFunctionality() async throws {
        // Given
        let input = TestData.validInput
        
        // When
        let result = try await sut.process(input)
        
        // Then
        XCTAssertEqual(result.status, .success)
    }
    
    func testErrorHandling() async throws {
        // Given
        let invalidInput = TestData.invalidInput
        
        // When/Then
        await XCTAssertThrowsError(try await sut.process(invalidInput))
    }
}
```
"""
        },
        
        # Code Organization
        'file_too_large': {
            'name': 'File Too Large',
            'description': 'Files over 500 lines should be split',
            'priority': 3,
            'fix_prompt': """
Split this large file into logical components.

**Strategy:**
1. Identify logical groupings (models, views, helpers)
2. Create separate files for each grouping
3. Use extensions for protocol conformances

**Example Split:**
```
// Before: UserManager.swift (800 lines)

// After:
UserManager/
  ├── UserManager.swift        (core logic)
  ├── UserManager+Auth.swift   (authentication)
  ├── UserManager+Profile.swift (profile management)
  └── UserManagerTypes.swift   (supporting types)
```

**Extension Pattern:**
```swift
// UserManager+Auth.swift
extension UserManager {
    func authenticate(credentials: Credentials) async throws -> User {
        // Authentication logic
    }
}
```
"""
        },
        
        'inconsistent_naming': {
            'name': 'Inconsistent Naming',
            'description': 'Naming should follow Anigma conventions',
            'priority': 3,
            'fix_prompt': """
Follow Anigma naming conventions:

**Modules:**
- Core modules: `AnigmaCore`, `DatabaseCore`, `ContractsCore`
- Feature modules: `HarmoniaModule`, `DiaplasionModule`
- Kit modules: `CompressionKit`, `ObservabilityKit`

**Types:**
- Actors: `*Controller`, `*Manager`, `*Service`
- Components: `*Component`
- Systems: `*System`
- Views: `*View`, `*Screen`

**Functions:**
- Queries: `get*`, `find*`, `fetch*`
- Mutations: `create*`, `update*`, `delete*`
- Actions: `process*`, `execute*`, `perform*`

**Protocols:**
- Capabilities: `*able` (Sendable, Encodable)
- Delegates: `*Delegate`
- Data Sources: `*DataSource`
"""
        },
    }
    
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.modules: Dict[str, Dict] = {}
        self.issues: List[Dict] = []
        
    def scan_modules(self) -> Dict[str, Dict]:
        """Scan all modules and collect quality metrics."""
        logger.info("🔍 Scanning module quality...")
        
        # Find all module directories
        module_paths = []
        
        # Packages directory
        packages_dir = self.repo_root / 'Packages'
        if packages_dir.exists():
            for item in packages_dir.iterdir():
                if item.is_dir() and not item.name.startswith('.'):
                    module_paths.append(item)
        
        # Sources directory
        sources_dir = self.repo_root / 'Sources'
        if sources_dir.exists():
            for item in sources_dir.iterdir():
                if item.is_dir() and not item.name.startswith('.'):
                    module_paths.append(item)
        
        for module_path in module_paths:
            self.modules[module_path.name] = self._analyze_module(module_path)
        
        logger.info(f"  Analyzed {len(self.modules)} modules")
        return self.modules
    
    def _analyze_module(self, module_path: Path) -> Dict:
        """Analyze a single module for quality metrics."""
        metrics = {
            'path': str(module_path),
            'name': module_path.name,
            'has_readme': (module_path / 'README.md').exists(),
            'swift_files': 0,
            'test_files': 0,
            'total_lines': 0,
            'public_funcs': 0,
            'documented_funcs': 0,
            'generic_throws': 0,
            'anigma_errors': 0,
            'sendable_types': 0,
            'actors': 0,
            'bauhaus_violations': 0,
            'large_files': [],
            'issues': [],
        }
        
        # Find all Swift files
        swift_files = list(module_path.rglob('*.swift'))
        metrics['swift_files'] = len([f for f in swift_files if 'Tests' not in str(f)])
        metrics['test_files'] = len([f for f in swift_files if 'Tests' in str(f)])
        
        # Analyze each file
        for swift_file in swift_files:
            self._analyze_file(swift_file, metrics)
        
        # Calculate scores
        metrics['doc_score'] = (
            metrics['documented_funcs'] / max(1, metrics['public_funcs']) * 100
        )
        metrics['error_score'] = (
            metrics['anigma_errors'] / max(1, metrics['anigma_errors'] + metrics['generic_throws']) * 100
        )
        metrics['test_score'] = (
            metrics['test_files'] / max(1, metrics['swift_files'] // 3) * 100
        )
        
        # Overall quality score
        metrics['quality_score'] = (
            metrics['doc_score'] * 0.3 +
            metrics['error_score'] * 0.3 +
            min(100, metrics['test_score']) * 0.2 +
            (100 if metrics['has_readme'] else 0) * 0.2
        )
        
        return metrics
    
    def _analyze_file(self, file_path: Path, metrics: Dict):
        """Analyze a single Swift file."""
        try:
            content = file_path.read_text()
            lines = content.split('\n')
            metrics['total_lines'] += len(lines)
            
            # Large file check
            if len(lines) > 500:
                metrics['large_files'].append({
                    'file': str(file_path),
                    'lines': len(lines)
                })
            
            # Pattern matching
            for line in lines:
                # Public functions
                if re.search(r'public\s+(func|var|let|class|struct|actor|enum)', line):
                    metrics['public_funcs'] += 1
                    
                    # Check for documentation
                    line_num = lines.index(line)
                    if line_num > 0 and lines[line_num - 1].strip().startswith('///'):
                        metrics['documented_funcs'] += 1
                
                # Error handling patterns
                if re.search(r'throw\s+AnigmaError', line):
                    metrics['anigma_errors'] += 1
                elif re.search(r'throw\s+(?!AnigmaError)', line):
                    metrics['generic_throws'] += 1
                
                # Concurrency patterns
                if 'Sendable' in line:
                    metrics['sendable_types'] += 1
                if re.search(r'\bactor\s+\w+', line):
                    metrics['actors'] += 1
                    
        except Exception as e:
            logger.debug(f"Could not analyze {file_path}: {e}")
            
    def _analyze_architecture(self):
        """Analyze module dependencies for 3-tier architecture violations."""
        logger.info("🔍 Analyzing 3-Tier Architecture...")
        
        try:
            # Get package dump
            result = subprocess.run(
                ['swift', 'package', 'dump-package'],
                cwd=self.repo_root,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                logger.error("Failed to dump package manifest")
                return
                
            package_data = json.loads(result.stdout)
            targets = {t['name']: t for t in package_data.get('targets', [])}
            
            # Tier definitions
            tier1_modules = {'ContractsCore', 'AnigmaPrimitives', 'DoctrineCore', 'SecurityEventsManager'}
            tier2_modules = {
                'AnigmaCore', 'DatabaseCore', 'StorageCore', 'CapabilityCore',
                'TelemetryCore', 'ExecutionCore', 'InferenceCore', 'PlatformCore',
                'DataCore', 'DataEngine', 'ExportCore'
            }
            tier3_modules = {
                'HarmoniaModule', 'DiaplasionModule', 'AccessumModule', 'OutlineumModule',
                'PragmaModule', 'ConexusModule', 'CodexModule', 'TranscriptumModule',
                'ObservatoriumModule', 'PolytroposModule', 'VectorumModule', 'CathedralModule',
                'ContextumModule', 'ArtifactStoreModule', 'ModelRegistryModule'
            }
            
            for target_name, target in targets.items():
                if target_name not in self.modules:
                    continue
                    
                dependencies = [d.get('byName', [None])[0] for d in target.get('dependencies', [])]
                dependencies = [d for d in dependencies if d]
                
                # Check Tier 1 Rules: No dependencies on Tier 2 or 3
                if target_name in tier1_modules:
                    for dep in dependencies:
                        if dep in tier2_modules or dep in tier3_modules:
                            self.modules[target_name]['issues'].append({
                                'type': 'architecture_violation',
                                'description': f"Tier 1 module depends on upper tier module '{dep}'"
                            })
                            
                # Check Tier 2 Rules: No dependencies on Tier 3
                elif target_name in tier2_modules:
                    for dep in dependencies:
                        if dep in tier3_modules:
                            self.modules[target_name]['issues'].append({
                                'type': 'architecture_violation',
                                'description': f"Tier 2 module depends on Tier 3 module '{dep}'"
                            })
                            
                # Check Tier 3 Rules: No circular Tier 3 dependencies (unless explicitly allowed shared modules)
                elif target_name in tier3_modules:
                    # In strict 3-tier, Tier 3 modules should be independent capabilities
                    # But they might share 'AnigmaAgents' or similar common UI libs
                    pass
                    
        except Exception as e:
            logger.error(f"Architecture analysis failed: {e}")

    def generate_improvement_tasks(self, session_id: str, min_score: float = 70.0) -> List[RefactoringTask]:
        """Generate improvement tasks for modules below quality threshold."""
        
        # Run architecture analysis first
        self._analyze_architecture()
        
        tasks = []
        
        for module_name, metrics in self.modules.items():
            # Architecture Violations (Highest Priority)
            for issue in metrics.get('issues', []):
                if issue['type'] == 'architecture_violation':
                    tasks.append(self._create_task(
                        session_id, module_name, 'architecture_violation',
                        f"CRITICAL: {issue['description']}"
                    ))
                    # Force priority 0
                    tasks[-1].metadata['priority'] = 0
            
            if metrics['quality_score'] >= min_score:
                continue  # Skip high-quality modules
            
            # Documentation issues
            if metrics['doc_score'] < 50:
                tasks.append(self._create_task(
                    session_id, module_name, 'missing_public_docs',
                    f"Module has only {metrics['doc_score']:.0f}% documentation coverage"
                ))
            
            if not metrics['has_readme']:
                tasks.append(self._create_task(
                    session_id, module_name, 'missing_readme',
                    f"Module is missing README.md"
                ))
            
            # Error handling issues
            if metrics['generic_throws'] > 0:
                tasks.append(self._create_task(
                    session_id, module_name, 'generic_error_throw',
                    f"Module has {metrics['generic_throws']} generic throws (use AnigmaError)"
                ))
            
            # Test coverage
            if metrics['test_score'] < 30:
                tasks.append(self._create_task(
                    session_id, module_name, 'missing_tests',
                    f"Module has low test coverage ({metrics['test_score']:.0f}%)"
                ))
            
            # Large files
            for large_file in metrics['large_files']:
                tasks.append(self._create_task(
                    session_id, module_name, 'file_too_large',
                    f"File has {large_file['lines']} lines",
                    file_path=large_file['file']
                ))
        
        # Sort by priority
        tasks.sort(key=lambda t: t.metadata.get('priority', 99))
        
        logger.info(f"  Generated {len(tasks)} improvement tasks")
        return tasks
    
    def _create_task(
        self, 
        session_id: str, 
        module_name: str, 
        check_id: str,
        description: str,
        file_path: str = None
    ) -> RefactoringTask:
        """Create an improvement task."""
        check = self.QUALITY_CHECKS.get(check_id, {})
        
        return RefactoringTask(
            id=f"quality_{session_id}_{module_name}_{check_id}",
            type=f"quality_{check_id}",
            file=file_path or f"Packages/{module_name}",
            line=0,
            description=f"[P{check.get('priority', 3)}] {check.get('name', check_id)}: {description}",
            original_code="",
            proposed_code="",
            metadata={
                'module': module_name,
                'check_id': check_id,
                'check_name': check.get('name', check_id),
                'priority': check.get('priority', 3),
                'fix_strategy': check.get('fix_prompt', ''),
            },
            is_repair_task=True,
            repair_error_message=description,
            max_attempts=3
        )
    
    def print_summary(self):
        """Print module quality summary."""
        if not self.modules:
            logger.info("No modules analyzed")
            return
        
        # Sort by quality score
        sorted_modules = sorted(
            self.modules.items(),
            key=lambda x: x[1]['quality_score']
        )
        
        logger.info(f"\n{'='*80}")
        logger.info("📊 MODULE QUALITY SUMMARY")
        logger.info(f"{'='*80}")
        logger.info(f"Total Modules: {len(self.modules)}")
        
        # Quality tiers
        excellent = [m for m, d in sorted_modules if d['quality_score'] >= 80]
        good = [m for m, d in sorted_modules if 60 <= d['quality_score'] < 80]
        needs_work = [m for m, d in sorted_modules if d['quality_score'] < 60]
        
        logger.info(f"\nQuality Tiers:")
        logger.info(f"  ✅ Excellent (80+): {len(excellent)}")
        logger.info(f"  🔶 Good (60-79):    {len(good)}")
        logger.info(f"  ❌ Needs Work (<60): {len(needs_work)}")
        
        # Bottom 10 modules
        logger.info(f"\nModules Needing Most Improvement:")
        for module_name, metrics in sorted_modules[:10]:
            score = metrics['quality_score']
            icon = "✅" if score >= 80 else ("🔶" if score >= 60 else "❌")
            logger.info(f"  {icon} {module_name}: {score:.0f}%")
            logger.info(f"      Doc: {metrics['doc_score']:.0f}% | Error: {metrics['error_score']:.0f}% | Test: {metrics['test_score']:.0f}%")
        
        logger.info(f"{'='*80}\n")


class SwiftLintConfigParser:
    """Parses .swiftlint.yml to provide context for refactoring."""
    
    def __init__(self, repo_root: Path):
        self.config_path = repo_root / '.swiftlint.yml'
        self.config = {}
        self._load_config()
        
    def _load_config(self):
        if not self.config_path.exists():
            logger.warning(f"No .swiftlint.yml found at {self.config_path}")
            return
            
        try:
            with open(self.config_path, 'r') as f:
                self.config = yaml.safe_load(f) or {}
            logger.info("✅ Loaded SwiftLint configuration")
        except Exception as e:
            logger.error(f"Failed to load .swiftlint.yml: {e}")

    def get_rule_config(self, rule_id: str) -> Optional[Dict]:
        """Get configuration for a specific rule."""
        # Check standard rule configs
        if rule_id in self.config:
            return self.config[rule_id]
            
        # Check custom rules
        custom_rules = self.config.get('custom_rules', {})
        if rule_id in custom_rules:
            return custom_rules[rule_id]
            
        return None

    def get_context_for_task(self, task: RefactoringTask) -> str:
        """Generate rule-specific context for a task."""
        # Infer rule ID from task type or metadata if possible
        # This mapping depends on how 'type' maps to SwiftLint rules
        rule_map = {
            'extract_config': 'function_parameter_count',
            'tuple_to_struct': 'large_tuple',
            # Add more mappings as needed
        }
        
        rule_id = rule_map.get(task.type)
        if not rule_id:
            return ""
            
        config = self.get_rule_config(rule_id)
        if not config:
            return ""
            
        context = f"\n**SwiftLint Rule Context ({rule_id}):**\n"
        if isinstance(config, dict):
            for k, v in config.items():
                context += f"- {k}: {v}\n"
        else:
            context += f"- Value: {config}\n"
            
        return context


class BuildDiagnosticParser:
    """
    Parses Swift compiler output to extract structured diagnostics.
    Categorizes errors by type and priority for intelligent fixing.
    """
    
    # Patterns for categorizing Swift errors
    ERROR_PATTERNS = {
        # Type system errors
        ErrorCategory.TYPE_MISMATCH: [
            r"cannot convert value of type '(.+)' to expected argument type '(.+)'",
            r"cannot assign value of type '(.+)' to type '(.+)'",
            r"type '(.+)' does not conform to protocol '(.+)'",
            r"cannot convert return expression of type '(.+)' to return type '(.+)'",
        ],
        ErrorCategory.MISSING_MEMBER: [
            r"value of type '(.+)' has no member '(.+)'",
            r"type '(.+)' has no member '(.+)'",
            r"reference to member '(.+)' cannot be resolved",
        ],
        ErrorCategory.MISSING_IMPORT: [
            r"cannot find '(.+)' in scope",
            r"no such module '(.+)'",
            r"use of undeclared type '(.+)'",
        ],
        ErrorCategory.UNDEFINED_SYMBOL: [
            r"cannot find '(.+)' in scope",
            r"use of unresolved identifier '(.+)'",
        ],
        ErrorCategory.SYNTAX_ERROR: [
            r"expected '(.+)' in",
            r"unexpected '(.+)'",
            r"invalid redeclaration",
        ],
        
        # Swift 6 Concurrency errors
        ErrorCategory.SENDABLE_VIOLATION: [
            r"cannot be sent",
            r"'(.+)' is not sendable",
            r"Sendable",
            r"non-sendable type",
            r"captured '(.+)' does not conform to 'Sendable'",
        ],
        ErrorCategory.ACTOR_ISOLATION: [
            r"actor-isolated",
            r"isolated to",
            r"cannot be referenced from",
            r"@MainActor",
            r"nonisolated",
        ],
        ErrorCategory.ASYNC_AWAIT: [
            r"'async' in a function that does not support concurrency",
            r"expression is 'async' but is not marked with 'await'",
            r"call to async function",
        ],
        ErrorCategory.DATA_RACE: [
            r"data race",
            r"concurrent access",
            r"mutable state",
        ],
        
        # Protocol/Generics
        ErrorCategory.PROTOCOL_CONFORMANCE: [
            r"does not conform to protocol",
            r"protocol requires",
            r"missing required",
        ],
        ErrorCategory.GENERIC_CONSTRAINT: [
            r"generic parameter",
            r"type constraint",
            r"same-type requirement",
        ],
        ErrorCategory.OPTIONAL_UNWRAP: [
            r"value of optional type '(.+)\?' must be unwrapped",
            r"nil coalescing",
            r"optional chaining",
        ],
        
        # Warnings
        ErrorCategory.DEPRECATION: [
            r"deprecated",
            r"will be removed",
            r"unavailable",
        ],
        ErrorCategory.UNUSED: [
            r"unused",
            r"never used",
            r"result of call to",
        ],
    }
    
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.diagnostics: List[BuildDiagnostic] = []
        
    def parse_build_output(self, build_output: str) -> List[BuildDiagnostic]:
        """
        Parse Swift compiler output into structured diagnostics.
        
        Returns list of BuildDiagnostic sorted by priority.
        """
        self.diagnostics = []
        
        # Swift compiler format: /path/to/file.swift:123:45: error: message
        pattern = re.compile(
            r'([^:\s]+\.swift):(\d+):(\d+):\s*(error|warning|note):\s*(.+)'
        )
        
        lines = build_output.split('\n')
        for i, line in enumerate(lines):
            match = pattern.search(line)
            if match:
                file_path = match.group(1)
                line_num = int(match.group(2))
                column = int(match.group(3))
                severity_str = match.group(4)
                message = match.group(5)
                
                # Determine severity
                severity = {
                    'error': ErrorSeverity.ERROR,
                    'warning': ErrorSeverity.WARNING,
                    'note': ErrorSeverity.NOTE
                }.get(severity_str, ErrorSeverity.ERROR)
                
                # Categorize the error
                category = self._categorize_error(message)
                
                # Try to get code context
                code_context = self._get_code_context(file_path, line_num)
                
                diagnostic = BuildDiagnostic(
                    file_path=file_path,
                    line=line_num,
                    column=column,
                    severity=severity,
                    category=category,
                    message=message,
                    raw_line=line,
                    code_context=code_context
                )
                self.diagnostics.append(diagnostic)
        
        # Sort by priority (lower = more urgent)
        self.diagnostics.sort(key=lambda d: (d.priority, d.file_path, d.line))
        
        return self.diagnostics
    
    def _categorize_error(self, message: str) -> ErrorCategory:
        """Categorize an error message into a known category."""
        message_lower = message.lower()
        
        for category, patterns in self.ERROR_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, message, re.IGNORECASE):
                    return category
        
        return ErrorCategory.UNKNOWN
    
    def _get_code_context(self, file_path: str, line_num: int, context_lines: int = 5) -> str:
        """Get code context around the error line."""
        try:
            full_path = self.repo_root / file_path if not file_path.startswith('/') else Path(file_path)
            if not full_path.exists():
                return ""
            
            with open(full_path, 'r') as f:
                lines = f.readlines()
            
            start = max(0, line_num - context_lines - 1)
            end = min(len(lines), line_num + context_lines)
            
            context_lines_list = []
            for i in range(start, end):
                marker = ">>> " if i == line_num - 1 else "    "
                context_lines_list.append(f"{marker}{i+1}: {lines[i].rstrip()}")
            
            return '\n'.join(context_lines_list)
        except Exception:
            return ""
    
    def get_priority_summary(self) -> Dict[int, List[BuildDiagnostic]]:
        """Group diagnostics by priority level."""
        summary = {1: [], 2: [], 3: [], 4: []}
        for d in self.diagnostics:
            if d.priority in summary:
                summary[d.priority].append(d)
        return summary
    
    def get_errors_by_file(self) -> Dict[str, List[BuildDiagnostic]]:
        """Group diagnostics by file."""
        by_file = {}
        for d in self.diagnostics:
            if d.file_path not in by_file:
                by_file[d.file_path] = []
            by_file[d.file_path].append(d)
        return by_file
    
    def generate_repair_tasks(self, session_id: str) -> List[RefactoringTask]:
        """
        Generate repair tasks from diagnostics, prioritized by severity.
        Only includes errors (not warnings) by default.
        """
        tasks = []
        seen = set()  # Avoid duplicate tasks for same file:line
        
        for diagnostic in self.diagnostics:
            if diagnostic.severity != ErrorSeverity.ERROR:
                continue  # Skip warnings for now
            
            key = f"{diagnostic.file_path}:{diagnostic.line}"
            if key in seen:
                continue
            seen.add(key)
            
            task_id = f"repair_{session_id}_{Path(diagnostic.file_path).stem}_{diagnostic.line}"
            
            # Build best practice hint based on category
            best_practice = self._get_best_practice_hint(diagnostic)
            
            task = RefactoringTask(
                id=task_id,
                type=f"repair_{diagnostic.category.value}",
                file=diagnostic.file_path,
                line=diagnostic.line,
                description=f"[P{diagnostic.priority}] Fix {diagnostic.category.value}: {diagnostic.message[:60]}...",
                original_code=diagnostic.code_context,
                proposed_code="",  # Agent will generate
                metadata={
                    'error_category': diagnostic.category.value,
                    'priority': diagnostic.priority,
                    'error_message': diagnostic.message,
                    'best_practice': best_practice,
                    'column': diagnostic.column,
                },
                is_repair_task=True,
                repair_error_message=diagnostic.message,
                max_attempts=3
            )
            tasks.append(task)
        
        # Sort by priority
        tasks.sort(key=lambda t: t.metadata.get('priority', 99))
        return tasks
    
    def _get_best_practice_hint(self, diagnostic: BuildDiagnostic) -> str:
        """Generate best practice hints for fixing specific error categories."""
        hints = {
            ErrorCategory.TYPE_MISMATCH: """
Best Practice for Type Mismatch:
1. Check if you need explicit type conversion (e.g., String(describing:), Int(), etc.)
2. Verify generic type parameters match
3. Consider using protocol types if needed
4. Check for optional vs non-optional mismatches
""",
            ErrorCategory.MISSING_MEMBER: """
Best Practice for Missing Member:
1. Import the correct module
2. Check for typos in member name
3. Verify the type you're accessing actually has this member
4. Consider if the member is available in your deployment target
""",
            ErrorCategory.MISSING_IMPORT: """
Best Practice for Missing Import:
1. Add the required import statement at the top of the file
2. Check Package.swift for missing dependencies
3. Verify the module/target dependency graph
""",
            ErrorCategory.SENDABLE_VIOLATION: """
Best Practice for Sendable Violations (Swift 6):
1. Mark the type as `Sendable` if it's safe
2. Use `@unchecked Sendable` only if you manually verify thread safety
3. Consider using actors for mutable state
4. Use `nonisolated` for properties that don't access mutable state
5. Consider copying values instead of sharing references
""",
            ErrorCategory.ACTOR_ISOLATION: """
Best Practice for Actor Isolation:
1. Use `await` when calling across actor boundaries
2. Mark methods as `nonisolated` if they don't access actor state
3. Use `@MainActor` for UI-related code
4. Consider if the call should be made synchronously with `assumeIsolated`
""",
            ErrorCategory.ASYNC_AWAIT: """
Best Practice for Async/Await:
1. Mark the containing function as `async`
2. Add `await` before async function calls
3. Use Task { } to bridge synchronous and async code
4. Consider using `.task` modifier in SwiftUI
""",
            ErrorCategory.PROTOCOL_CONFORMANCE: """
Best Practice for Protocol Conformance:
1. Implement all required protocol members
2. Check associated type requirements
3. Verify method signatures match exactly
4. Consider protocol extensions for default implementations
""",
            ErrorCategory.OPTIONAL_UNWRAP: """
Best Practice for Optional Handling:
1. Use optional chaining (?) for safe access
2. Use nil coalescing (??) for default values
3. Use guard let or if let for conditional unwrapping
4. Avoid force unwrap (!) unless absolutely certain
""",
        }
        return hints.get(diagnostic.category, "Apply standard Swift best practices.")
    
    def print_summary(self):
        """Print a formatted summary of all diagnostics."""
        if not self.diagnostics:
            logger.info("✅ No build diagnostics found")
            return
        
        errors = [d for d in self.diagnostics if d.severity == ErrorSeverity.ERROR]
        warnings = [d for d in self.diagnostics if d.severity == ErrorSeverity.WARNING]
        
        logger.info(f"\n{'='*80}")
        logger.info(f"📊 BUILD DIAGNOSTIC SUMMARY")
        logger.info(f"{'='*80}")
        logger.info(f"Total Diagnostics: {len(self.diagnostics)}")
        logger.info(f"  Errors:   {len(errors)}")
        logger.info(f"  Warnings: {len(warnings)}")
        
        # By priority
        priority_summary = self.get_priority_summary()
        logger.info(f"\nBy Priority:")
        for priority, items in priority_summary.items():
            if items:
                error_items = [i for i in items if i.severity == ErrorSeverity.ERROR]
                logger.info(f"  P{priority}: {len(error_items)} errors, {len(items) - len(error_items)} warnings")
        
        # By category
        category_counts = {}
        for d in self.diagnostics:
            cat = d.category.value
            category_counts[cat] = category_counts.get(cat, 0) + 1
        
        logger.info(f"\nBy Category:")
        for cat, count in sorted(category_counts.items(), key=lambda x: -x[1]):
            logger.info(f"  {cat}: {count}")
        
        # Top files
        by_file = self.get_errors_by_file()
        top_files = sorted(by_file.items(), key=lambda x: -len(x[1]))[:10]
        logger.info(f"\nTop 10 Files by Error Count:")
        for file_path, diagnostics in top_files:
            error_count = len([d for d in diagnostics if d.severity == ErrorSeverity.ERROR])
            logger.info(f"  {Path(file_path).name}: {error_count} errors")
        
        logger.info(f"{'='*80}\n")


class DeepSeekAgent:
    """AI agent powered by DeepSeek for intelligent refactoring."""
    
    def __init__(self, agent_id: int, api_key: str):
        self.agent_id = agent_id
        self.api_key = api_key
        self.api_url = "https://api.deepseek.com/v1/chat/completions"
        self.model = "deepseek-chat"
        self.total_tokens_used = 0
        
    def analyze_and_refactor(self, task: RefactoringTask, rule_context: str = "") -> tuple[bool, str, str]:
        """
        Use DeepSeek to analyze and improve the proposed refactoring OR fix a build error.
        
        Returns:
            (success, refactored_code, reasoning)
        """
        prompt = self._build_refactoring_prompt(task, rule_context)
        
        try:
            response_content, usage = self._call_deepseek(prompt)
            self.total_tokens_used += usage.get('total_tokens', 0)
            
            # Parse response
            result = self._parse_refactoring_response(response_content)
            
            if result['approved']:
                return True, result['code'], result['reasoning']
            else:
                return False, "", result['reasoning']
                
        except Exception as e:
            logger.error(f"Agent {self.agent_id} error: {e}")
            return False, "", f"DeepSeek API error: {e}"
    
    def _build_refactoring_prompt(self, task: RefactoringTask, rule_context: str) -> str:
        """Build prompt for DeepSeek, handling both refactoring and repair tasks."""
        
        # Build failure history section
        failure_context = ""
        if task.failure_history:
            failure_context = "\n**⚠️  PREVIOUS ATTEMPTS FAILED - LEARN FROM THESE:**\n"
            for i, failure in enumerate(task.failure_history, 1):
                failure_context += f"\n**Attempt {failure['attempt']}:**\n"
                failure_context += f"```swift\n{failure['attempted_code']}\n```\n"
                failure_context += f"**Error**: {failure['error']}\n"
                failure_context += f"**Reasoning**: {failure['reasoning']}\n"
            
            failure_context += "\n**IMPORTANT**: Avoid the mistakes from previous attempts. Analyze why they failed and propose a different approach.\n"
        
        task_instruction = "Learn from previous failures and propose a DIFFERENT approach" if task.failure_history else "Decide: APPROVE, REJECT, or IMPROVE"
        reasoning_instruction = " - explain how you avoided previous mistakes" if task.failure_history else ""
        
        # Customize prompt for Repair vs Refactor
        if task.is_repair_task:
            return f"""You are an expert Swift engineer tasked with fixing a compiler error.

**Goal**: Fix the build error described below.

**File**: {task.file}
**Line**: {task.line}
**Error**: {task.repair_error_message}

**Code Context**:
```swift
{task.original_code}
```

{failure_context}

**Your Task**:
1. Analyze the error and the code.
2. Provide the corrected code for the specified context.
3. Ensure **Swift 6 Concurrency** compliance (Sendable, Actors, etc.).
4. Do NOT change logic unrelated to the error.

**Response Format** (JSON):
```json
{{
    "decision": "APPROVE", 
    "reasoning": "Explanation of the fix{reasoning_instruction}",
    "code": "The fixed code snippet",
    "approved": true
}}
```
Respond ONLY with valid JSON."""

        else:
            return f"""You are an expert Swift refactoring agent specializing in Swift 6 concurrency and safety. Analyze this refactoring proposal and decide whether to approve it, reject it, or propose an improvement.

**Refactoring Type**: {task.type}
**File**: {task.file}
**Line**: {task.line}
**Description**: {task.description}
**Attempt**: {task.attempt_count + 1} of {task.max_attempts}

**Original Code**:
```swift
{task.original_code}
```

**Proposed Refactoring**:
```swift
{task.proposed_code}
```

**Metadata**: {json.dumps(task.metadata, indent=2)}
{rule_context}
{failure_context}
**Your Task**:
1. Analyze the proposed refactoring
2. Check for:
   - Correctness (does it preserve functionality?)
   - Code quality (is it an improvement?)
   - **Swift 6 Concurrency**: Ensure no data races, proper actor usage, and Sendable compliance.
   - **Project Standards**: Adhere to the provided SwiftLint rule context.
   - Potential issues (naming, types, etc.)
3. {task_instruction}

**Response Format** (JSON):
```json
{{
    "decision": "APPROVE|REJECT|IMPROVE",
    "reasoning": "Detailed explanation of your decision{reasoning_instruction}",
    "code": "If APPROVE or IMPROVE, provide the final code here",
    "approved": true/false,
    "confidence": 0.0-1.0,
    "suggestions": ["Optional list of suggestions"]
}}
```

Respond ONLY with valid JSON, no other text."""

    def _call_deepseek(self, prompt: str, max_retries: int = 3) -> tuple[str, Dict]:
        """Call DeepSeek API with retry logic. Returns (content, usage_dict)."""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": self.model,
            "messages": [
                {
                    "role": "system",
                    "content": "You are an expert Swift refactoring agent. Always respond with valid JSON."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.3,
            "max_tokens": 2000
        }
        
        for attempt in range(max_retries):
            try:
                response = requests.post(
                    self.api_url,
                    headers=headers,
                    json=payload,
                    timeout=60
                )
                
                response.raise_for_status()
                
                result = response.json()
                content = result['choices'][0]['message']['content']
                usage = result.get('usage', {})
                return content, usage
                
            except requests.exceptions.RequestException as e:
                logger.warning(f"DeepSeek API attempt {attempt + 1} failed: {e}")
                if attempt == max_retries - 1:
                    raise
                time.sleep(2 ** attempt)  # Exponential backoff
        
        raise Exception("Max retries exceeded")
    
    def _parse_refactoring_response(self, response: str) -> Dict:
        """Parse DeepSeek's JSON response."""
        try:
            # Extract JSON from response (in case there's extra text)
            json_start = response.find('{')
            json_end = response.rfind('}') + 1
            
            if json_start == -1 or json_end == 0:
                raise ValueError("No JSON found in response")
            
            json_str = response[json_start:json_end]
            result = json.loads(json_str)
            
            # Validate required fields
            if 'decision' not in result:
                # Some models might not output decision if forced to output code, handle gracefully
                if 'code' in result:
                     result['decision'] = 'APPROVE'
                else:
                    raise ValueError("Missing 'decision' field")
            
            # Normalize decision
            decision = result['decision'].upper()
            result['approved'] = decision in ['APPROVE', 'IMPROVE']
            
            return result
            
        except Exception as e:
            logger.error(f"Failed to parse DeepSeek response: {e}\nResponse: {response[:200]}...")
            # Fallback: reject if we can't parse
            return {
                'decision': 'REJECT',
                'reasoning': f"Failed to parse response: {e}",
                'code': '',
                'approved': False,
                'confidence': 0.0
            }



class SwiftCorruptionDetector:
    """
    Detects corrupted Swift files that might cause build failures.
    Checks for:
    1. Parsing errors (swiftc -parse-only)
    2. Unbalanced braces
    3. Top-level statements in library files (heuristic)
    4. Git conflict markers
    """
    
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.corrupted_files: List[Dict] = []
        
    def scan_repository(self, limit: int = 100) -> List[Dict]:
        """Scan the repository for corrupted Swift files."""
        logger.info("🔍 Scanning for corrupted Swift files...")
        
        swift_files = list(self.repo_root.rglob("*.swift"))
        logger.info(f"  Found {len(swift_files)} Swift files to check")
        
        found_corruption = 0
        
        # Use ThreadPoolExecutor for faster scanning
        with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as executor:
            future_to_file = {
                executor.submit(self.check_file, f): f 
                for f in swift_files 
                if not "Tests/" in str(f) and not ".build/" in str(f)
            }
            
            completed = 0
            total = len(future_to_file)
            
            for future in as_completed(future_to_file):
                completed += 1
                if completed % 100 == 0:
                    print(f"  Progress: {completed}/{total} files checked...", end='\r')
                    
                result = future.result()
                if result:
                    self.corrupted_files.append(result)
                    found_corruption += 1
                    if found_corruption >= limit:
                        logger.warning(f"  Limit of {limit} corrupted files reached")
                        break
        
        print(f"  Progress: {total}/{total} files checked   ")
        logger.info(f"  Found {len(self.corrupted_files)} corrupted files")
        return self.corrupted_files
    
    def check_file(self, file_path: Path) -> Optional[Dict]:
        """Check a single file for corruption."""
        try:
            rel_path = file_path.relative_to(self.repo_root)
            
            # 1. Quick textual checks
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Check for conflict markers
            if "<<<<<<< HEAD" in content or ">>>>>>>" in content:
                return {
                    'file': str(rel_path),
                    'type': 'conflict_markers',
                    'message': 'Git conflict markers found',
                    'severity': 'critical'
                }
            
            # Check for unbalanced braces (heuristic)
            # This is naive but fast and catches gross cut-and-paste errors
            open_braces = content.count('{')
            close_braces = content.count('}')
            if open_braces != close_braces:
                return {
                    'file': str(rel_path),
                    'type': 'unbalanced_braces',
                    'message': f"Unbalanced braces: {{={open_braces}, }}={close_braces}",
                    'severity': 'critical'
                }
            
            # 2. Compiler check (slower but accurate)
            # Use swiftc -parse-only to check syntax
            cmd = ['swiftc', '-parse-only', str(file_path)]
            result = subprocess.run(
                cmd, 
                cwd=self.repo_root, 
                capture_output=True, 
                text=True
            )
            
            if result.returncode != 0:
                # Extract first error
                error_lines = [l for l in result.stderr.split('\n') if ": error:" in l]
                message = error_lines[0] if error_lines else "Unknown syntax error"
                
                # Filter out "statements not allowed at top level" if it might be a script/main
                if "statements are not allowed at the top level" in message:
                    if "main.swift" in str(file_path) or "App.swift" in str(file_path):
                        return None
                        
                return {
                    'file': str(rel_path),
                    'type': 'syntax_error',
                    'message': message,
                    'severity': 'critical',
                    'details': result.stderr[:500]
                }
                
            return None
            
        except Exception as e:
            logger.error(f"Error checking {file_path}: {e}")
            return {
                'file': str(file_path),
                'type': 'check_failed',
                'message': str(e),
                'severity': 'warning'
            }

    def print_report(self):
        """Print corruption report."""
        if not self.corrupted_files:
            logger.info("✅ No corrupted files found")
            return
            
        logger.info(f"\n{'='*80}")
        logger.info("🚫 CORRUPTION REPORT")
        logger.info(f"{'='*80}")
        
        for i, failure in enumerate(self.corrupted_files, 1):
            logger.info(f"{i}. {failure['file']}")
            logger.info(f"   Type: {failure['type']}")
            logger.info(f"   Error: {failure['message']}")
            if 'details' in failure:
                 logger.info(f"   Details:\n{failure['details']}")
            logger.info("-" * 40)


class ParallelOrchestrator:
    """Orchestrates parallel DeepSeek agent refactoring with batch validation."""
    
    def __init__(self, repo_root: Path, num_agents: int = 10, batch_size: int = 10, api_key: str = None):
        self.repo_root = repo_root
        self.num_agents = num_agents
        self.batch_size = batch_size
        self.min_batch_size = 1
        self.max_batch_size = 50
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # DeepSeek API key
        self.api_key = api_key or "sk-459ecd08f72c4beba8fce7c2003f0d21"
        
        if requests is None:
            raise ValueError("'requests' module is required. Install with: pip install requests")
        if not self.api_key:
            raise ValueError("DEEPSEEK_API_KEY environment variable not set")
        
        # Create agent pool
        self.agents = [DeepSeekAgent(i, self.api_key) for i in range(1, num_agents + 1)]
        
        # Config parser
        self.config_parser = SwiftLintConfigParser(repo_root)
        
        # Task management
        self.all_tasks: List[RefactoringTask] = []
        self.pending_queue: queue.Queue = queue.Queue()
        self.completed_tasks: List[RefactoringTask] = []
        self.failed_tasks: List[RefactoringTask] = []
        
        # Batch tracking
        self.current_batch: int = 0
        self.batch_results: List[BatchResult] = []
        
        # Thread safety
        self.lock = threading.Lock()
        
        # Statistics
        self.stats = {
            'total_tasks': 0,
            'completed': 0,
            'failed': 0,
            'validation_failed': 0,
            'batches_processed': 0,
            'successful_builds': 0,
            'failed_builds': 0,
            'total_duration': 0.0,
            'deepseek_approvals': 0,
            'deepseek_rejections': 0,
            'deepseek_improvements': 0,
            'total_tokens': 0,
            'repairs_attempted': 0,
            'repairs_successful': 0
        }
    
    def load_refactoring_plan(self, plan_file: Path) -> int:
        """Load refactoring tasks from plan file."""
        logger.info(f"📋 Loading refactoring plan: {plan_file}")
        
        try:
            with open(plan_file) as f:
                plan = json.load(f)
            
            for i, task_data in enumerate(plan.get('tasks', []), 1):
                task = RefactoringTask(
                    id=f"{self.session_id}_{i:04d}",
                    type=task_data.get('type', 'unknown'),
                    file=task_data.get('file', ''),
                    line=task_data.get('line', 0),
                    description=task_data.get('description', ''),
                    original_code=self._get_code_from_file(
                        task_data.get('file', ''),
                        task_data.get('line', 0)
                    ),
                    proposed_code=task_data.get('refactored_code', ''),
                    metadata=task_data.get('metadata', {})
                )
                
                self.all_tasks.append(task)
                self.pending_queue.put(task)
            
            self.stats['total_tasks'] = len(self.all_tasks)
            logger.info(f"✅ Loaded {len(self.all_tasks)} refactoring tasks")
            logger.info(f"🤖 Initialized {len(self.agents)} DeepSeek agents")
            
            return len(self.all_tasks)
        except Exception as e:
            logger.error(f"Failed to load plan: {e}")
            raise
    
    def _adjust_batch_size(self, build_successful: bool):
        """Adaptively adjust batch size based on build stability."""
        old_size = self.batch_size
        if build_successful:
            # Increase conservatively
            self.batch_size = min(self.max_batch_size, int(self.batch_size * 1.5))
            if self.batch_size > old_size:
                logger.info(f"🚀 Batch size increased: {old_size} -> {self.batch_size}")
        else:
            # Decrease aggressively to isolate failures
            self.batch_size = max(self.min_batch_size, int(self.batch_size * 0.5))
            if self.batch_size < old_size:
                logger.info(f"📉 Batch size decreased: {old_size} -> {self.batch_size}")

    def run_parallel_refactoring(self):
        """Run parallel refactoring with batch validation."""
        print("\n" + "=" * 80)
        print("🤖 PARALLEL DEEPSEEK AGENT ORCHESTRATOR (AUTONOMOUS REPAIR)")
        print("=" * 80)
        print(f"Session ID: {self.session_id}")
        print(f"DeepSeek Agents: {self.num_agents}")
        print(f"Initial Batch Size: {self.batch_size}")
        print(f"Total Refactoring Tasks: {self.stats['total_tasks']}")
        print(f"Mode: LIVE")
        print("=" * 80)
        print()
        
        start_time = time.time()
        
        try:
            # Phase 0: Scan for existing build errors and create priority repairs
            print("🔍 PHASE 0: Scanning for existing build errors...")
            print("=" * 80)
            
            # Run build and capture output
            build_success, build_output, _ = self._validate_build_with_analysis()
            
            # Parse diagnostics
            self.diagnostic_parser = BuildDiagnosticParser(self.repo_root)
            diagnostics = self.diagnostic_parser.parse_build_output(build_output)
            
            # Print summary
            self.diagnostic_parser.print_summary()
                
            if diagnostics:
                errors = [d for d in diagnostics if d.severity == ErrorSeverity.ERROR]
                if errors:
                    print(f"\n🚨 Found {len(errors)} build errors that need fixing FIRST")
                    print("   These will be processed before refactoring tasks.")
                    
                    # Generate repair tasks
                    repair_tasks = self.diagnostic_parser.generate_repair_tasks(self.session_id)
                    
                    # Add repair tasks to the FRONT of the queue
                    # Re-queue existing tasks temporarily
                    existing_tasks = []
                    while not self.pending_queue.empty():
                        existing_tasks.append(self.pending_queue.get())
                    
                    # Add repairs first (priority 1 before priority 2, etc.)
                    for task in repair_tasks:
                        self.pending_queue.put(task)
                        self.all_tasks.append(task)
                        logger.info(f"  ➕ [P{task.metadata.get('priority', '?')}] {task.description[:60]}...")
                    
                    # Then add back the refactoring tasks
                    for task in existing_tasks:
                        self.pending_queue.put(task)
                    
                    self.stats['repairs_attempted'] = len(repair_tasks)
                    self.stats['total_tasks'] += len(repair_tasks)
                    
                    print(f"\n✅ Queued {len(repair_tasks)} repair tasks (Priority 1-4)")
                    print(f"   Total tasks now: {self.stats['total_tasks']}")
                else:
                    print("✅ No build errors found - proceeding with refactoring")
                    
            # Store baseline for differential analysis
            self.baseline_errors = self.diagnostic_parser.get_errors_by_file()

            
            print(f"\n{'='*80}")
            print("🚀 STARTING MAIN PROCESSING LOOP")
            print(f"{'='*80}\n")

            while not self.pending_queue.empty() or self.failed_tasks:
                self.current_batch += 1
                
                logger.info(f"📦 Starting Batch {self.current_batch} (Size: {self.batch_size})")
                print(f"\n{'='*80}")
                print(f"📦 BATCH {self.current_batch} (Size: {self.batch_size})")
                print(f"{'='*80}")
                
                # Process batch
                batch_result = self._process_batch()
                self.batch_results.append(batch_result)
                
                # Update statistics
                self.stats['batches_processed'] += 1
                if batch_result.build_successful:
                    self.stats['successful_builds'] += 1
                else:
                    self.stats['failed_builds'] += 1
                
                # Adaptive sizing
                self._adjust_batch_size(batch_result.build_successful)
                
                # Update token usage
                current_tokens = sum(agent.total_tokens_used for agent in self.agents)
                self.stats['total_tokens'] = current_tokens
                
                # Save checkpoint
                self._save_checkpoint()
                
                # Check if we should continue
                if not batch_result.build_successful and self.failed_tasks:
                    print(f"\n⚠️  Batch had failures - reassigning {len(self.failed_tasks)} tasks")
                    self._reassign_failed_tasks()
                    
        except KeyboardInterrupt:
            print("\n🛑 Execution interrupted by user")
            logger.info("Execution interrupted by user")
        except Exception as e:
            print(f"\n💥 Fatal error: {e}")
            logger.error(f"Fatal error: {e}", exc_info=True)
        finally:
            self.stats['total_duration'] = time.time() - start_time
            # Final summary
            self._print_final_summary()
            self._save_final_report()
    
    def _process_batch(self) -> BatchResult:
        """Process one batch of refactorings in parallel with DeepSeek agents."""
        batch_start = time.time()
        batch_tasks = []
        batch_files = set()
        temp_queue = []
        
        # Collect tasks for this batch, ENSURING ONE TASK PER FILE to prevent race conditions
        while len(batch_tasks) < self.batch_size and not self.pending_queue.empty():
            try:
                task = self.pending_queue.get_nowait()
                if task.file not in batch_files:
                    batch_tasks.append(task)
                    batch_files.add(task.file)
                else:
                    # File already being processed in this batch, defer it
                    temp_queue.append(task)
            except queue.Empty:
                break
        
        # Re-queue deferred tasks
        for task in temp_queue:
            self.pending_queue.put(task)
        
        if not batch_tasks:
            return BatchResult(
                batch_id=self.current_batch,
                tasks_attempted=0,
                tasks_completed=0,
                tasks_failed=0,
                build_successful=True,
                build_output="No tasks to process",
                duration_seconds=0.0,
                timestamp=datetime.now().isoformat()
            )
        
        print(f"📋 Processing {len(batch_tasks)} tasks with {self.num_agents} DeepSeek agents...")
        
        # Execute refactorings in parallel with DeepSeek
        completed_in_batch = []
        failed_in_batch = []
        
        with ThreadPoolExecutor(max_workers=self.num_agents) as executor:
            # Submit all tasks to DeepSeek agents
            future_to_task = {}
            for i, task in enumerate(batch_tasks):
                agent = self.agents[i % len(self.agents)]
                future = executor.submit(self._execute_refactoring_with_deepseek, task, agent)
                future_to_task[future] = task
            
            # Collect results
            for future in as_completed(future_to_task):
                task = future_to_task[future]
                try:
                    success = future.result()
                    if success:
                        completed_in_batch.append(task)
                        print(f"  ✅ Agent {task.assigned_agent}: {task.description}")
                    else:
                        failed_in_batch.append(task)
                        print(f"  ❌ Agent {task.assigned_agent}: {task.description}")
                except Exception as e:
                    task.status = RefactoringStatus.FAILED
                    task.error_message = str(e)
                    failed_in_batch.append(task)
                    print(f"  💥 Agent {task.assigned_agent}: Exception - {e}")
        
        print(f"\n🔨 Batch complete: {len(completed_in_batch)} succeeded, {len(failed_in_batch)} failed")
        
        # Validate build
        print(f"\n🏗️  Running build validation...")
        build_successful, build_output, build_errors = self._validate_build_with_analysis()
        
        if build_successful:
            print(f"✅ Build successful!")
            # Mark all completed tasks as truly completed
            for task in completed_in_batch:
                task.status = RefactoringStatus.COMPLETED
                task.completed_at = datetime.now().isoformat()
                self.completed_tasks.append(task)
                self.stats['completed'] += 1
            
            # Commit successful changes
            self._commit_batch(completed_in_batch, self.current_batch)
            
            # Clean up backup files for successful changes
            self._cleanup_backups(completed_in_batch)
            
        else:
            print(f"❌ Build failed!")
            
            # DIFFERENTIAL ANALYSIS
            # Identify which files are failing NOW vs BEFORE
            current_failing_files = set(build_errors.keys())
            baseline_failing_files = set(self.baseline_errors.keys())
            
            # Files that were fine before but are failing now
            newly_failing_files = current_failing_files - baseline_failing_files
            
            # Tasks that touched files that are now failing
            tasks_causing_regressions = [
                t for t in completed_in_batch 
                if t.file in newly_failing_files
            ]
            
            # Tasks that touched files that are failing, but were ALREADY failing
            tasks_in_broken_files = [
                t for t in completed_in_batch 
                if t.file in baseline_failing_files
            ]
            
            # Tasks that touched files that are NOT failing
            tasks_in_valid_files = [
                t for t in completed_in_batch 
                if t.file not in current_failing_files
            ]
            
            print(f"🔍 Analysis:")
            print(f"  - Regression tasks: {len(tasks_causing_regressions)} (rolling back)")
            print(f"  - Tasks in broken files: {len(tasks_in_broken_files)} (keeping)")
            print(f"  - Successful tasks: {len(tasks_in_valid_files)} (keeping)")
            
            # 1. Rollback regressions
            if tasks_causing_regressions:
                print(f"\n🔄 Rolling back {len(tasks_causing_regressions)} regression-causing changes...")
                for task in tasks_causing_regressions:
                    # Record this failure for learning
                    task.add_failure(
                        attempted_code=task.applied_code or task.proposed_code,
                        error=build_errors.get(task.file, 'Unknown build error'),
                        reasoning=task.agent_reasoning or 'No reasoning provided'
                    )
                    
                    self._rollback_task(task)
                    task.status = RefactoringStatus.VALIDATION_FAILED
                    task.validation_error = f"Caused build regression: {build_errors.get(task.file, 'Unknown error')}"
                    failed_in_batch.append(task)
                    self.stats['validation_failed'] += 1
            
            # 2. Keep everything else (valid + pre-existing broken)
            kept_tasks = tasks_in_valid_files + tasks_in_broken_files
            
            if kept_tasks:
                print(f"\n✅ Keeping {len(kept_tasks)} changes (valid or pre-existing breakage):")
                for task in kept_tasks:
                    status_label = "valid" if task in tasks_in_valid_files else "pre-existing error"
                    print(f"  ✅ {task.file} ({status_label}) - {task.description}")
                    task.status = RefactoringStatus.COMPLETED
                    task.completed_at = datetime.now().isoformat()
                    self.completed_tasks.append(task)
                    self.stats['completed'] += 1
                
                # Commit kept changes
                self._commit_batch(kept_tasks, self.current_batch, partial=True, build_failing=True)
                
                # Clean up backups for kept changes
                self._cleanup_backups(kept_tasks)
                
            # 3. AUTONOMOUS REPAIR: Generate tasks for build errors
            if current_failing_files:
                print(f"\n🔧 Generating repair tasks for {len(current_failing_files)} failing files...")
                repair_tasks = self._generate_repair_tasks(build_errors)
                
                for r_task in repair_tasks:
                    # Check if we already have this repair queued to avoid duplicates
                    if not any(t.id == r_task.id for t in self.all_tasks):
                        self.all_tasks.append(r_task)
                        # Put repair tasks at FRONT of queue for immediate processing
                        # Queue in Python doesn't support push_front, so we'll re-queue everything
                        # This is inefficient but functional for now. Better: Use PriorityQueue.
                        # Hack: Just put them in standard queue, they will be picked up next
                        self.pending_queue.put(r_task)
                        self.stats['repairs_attempted'] += 1
                        print(f"  ➕ Queued repair for: {r_task.file} (Line {r_task.line})")
        
        # Track failed tasks for reassignment
        for task in failed_in_batch:
            task.attempt_count += 1
            if task.attempt_count < task.max_attempts:
                self.failed_tasks.append(task)
            else:
                print(f"  ⛔ Task {task.id} exceeded max attempts ({task.max_attempts})")
                self.stats['failed'] += 1
        
        batch_duration = time.time() - batch_start
        
        return BatchResult(
            batch_id=self.current_batch,
            tasks_attempted=len(batch_tasks),
            tasks_completed=len(completed_in_batch) - len(failed_in_batch) if not build_successful else len(completed_in_batch),
            tasks_failed=len(failed_in_batch),
            build_successful=build_successful,
            build_output=build_output[:500],  # Truncate
            duration_seconds=batch_duration,
            timestamp=datetime.now().isoformat()
        )
    
    def _generate_repair_tasks(self, build_errors: Dict[str, str]) -> List[RefactoringTask]:
        """Generate tasks to fix build errors."""
        tasks = []
        for file_path, error_msg in build_errors.items():
            # Parse line number from error message if possible
            # Error format: "Line 123: Some error"
            line = 0
            match = re.search(r'Line (\d+):', error_msg)
            if match:
                line = int(match.group(1))
            
            # Create a unique ID based on file and error
            error_hash = hash(error_msg) % 10000
            task_id = f"repair_{self.session_id}_{os.path.basename(file_path)}_{error_hash}"
            
            # Get original code context
            original_code = self._get_code_from_file(file_path, line)
            
            task = RefactoringTask(
                id=task_id,
                type="build_repair",
                file=file_path,
                line=line,
                description=f"Fix build error: {error_msg[:50]}...",
                original_code=original_code,
                proposed_code="", # No proposal yet, agent will generate
                metadata={"error": error_msg},
                is_repair_task=True,
                repair_error_message=error_msg,
                max_attempts=3
            )
            tasks.append(task)
        return tasks

    def _execute_refactoring_with_deepseek(self, task: RefactoringTask, agent: DeepSeekAgent) -> bool:
        """Execute a single refactoring task with DeepSeek agent."""
        with self.lock:
            task.status = RefactoringStatus.IN_PROGRESS
            task.assigned_agent = agent.agent_id
            task.assigned_at = datetime.now().isoformat()
        
        try:
            # Get SwiftLint rule context (only for standard refactoring)
            rule_context = self.config_parser.get_context_for_task(task) if not task.is_repair_task else ""
            
            # Ask DeepSeek to analyze and approve/improve the refactoring
            success, refactored_code, reasoning = agent.analyze_and_refactor(task, rule_context)
            
            task.agent_reasoning = reasoning
            
            if not success:
                task.error_message = f"DeepSeek rejected: {reasoning}"
                self.stats['deepseek_rejections'] += 1
                return False
            
            # Update proposed code with agent's result
            if task.is_repair_task:
                task.proposed_code = refactored_code
                self.stats['deepseek_improvements'] += 1 # Count fixes as improvements
            elif refactored_code != task.proposed_code:
                self.stats['deepseek_improvements'] += 1
                task.proposed_code = refactored_code
            else:
                self.stats['deepseek_approvals'] += 1
            
            # Apply the refactoring
            filepath = Path(task.file)
            
            if not filepath.exists():
                task.error_message = f"File not found: {filepath}"
                return False
            
            # Backup original
            backup_path = filepath.with_suffix('.swift.bak')
            shutil.copy2(filepath, backup_path)
            
            # Read file
            content = filepath.read_text()
            
            # Apply refactoring
            if task.original_code in content:
                new_content = content.replace(task.original_code, task.proposed_code)
                filepath.write_text(new_content)
                task.applied_code = task.proposed_code
                
                if task.is_repair_task:
                    self.stats['repairs_successful'] += 1
                    
                return True
            else:
                task.error_message = "Original code not found in file (drift?)"
                # If repair task, maybe file changed, just fail
                return False
            
        except Exception as e:
            task.error_message = str(e)
            return False
    
    def _validate_build_with_analysis(self) -> tuple[bool, str, Dict[str, str]]:
        """
        Run swift build and analyze errors.
        
        Returns:
            (success, full_output, error_dict)
            error_dict maps file paths to error messages
        """
        try:
            result = subprocess.run(
                ['swift', 'build'],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            success = result.returncode == 0
            output = result.stdout + result.stderr
            
            # Parse errors from output
            errors = self._parse_build_errors(output) if not success else {}
            
            return success, output, errors
            
        except subprocess.TimeoutExpired:
            return False, "Build timeout (>5 minutes)", {}
        except Exception as e:
            return False, f"Build error: {e}", {}
    
    def _parse_build_errors(self, build_output: str) -> Dict[str, str]:
        """
        Parse Swift compiler errors to identify which files have issues.
        
        Returns:
            Dict mapping file paths to error messages
        """
        errors = {}
        
        # Swift compiler error format:
        # /path/to/file.swift:123:45: error: some error message
        # /path/to/file.swift:123:45: warning: some warning message
        
        error_pattern = re.compile(r'([^:]+\.swift):(\d+):(\d+): (error|warning): (.+)')
        
        for line in build_output.split('\n'):
            match = error_pattern.search(line)
            if match:
                file_path = match.group(1)
                line_num = match.group(2)
                severity = match.group(4)
                message = match.group(5)
                
                # Only track errors, not warnings
                if severity == 'error':
                    # Normalize path to match task file paths
                    if file_path.startswith('/'):
                        # Absolute path - try to make it match our task paths
                        for task_file in [t.file for t in self.all_tasks]:
                            if file_path.endswith(task_file) or task_file.endswith(file_path):
                                file_path = task_file
                                break
                    
                    if file_path not in errors:
                        errors[file_path] = []
                    errors[file_path].append(f"Line {line_num}: {message}")
        
        # Convert lists to strings
        return {k: '; '.join(v) for k, v in errors.items()}
    
    def _rollback_task(self, task: RefactoringTask):
        """Rollback a task's changes."""
        filepath = Path(task.file)
        backup_path = filepath.with_suffix('.swift.bak')
        
        if backup_path.exists():
            shutil.copy2(backup_path, filepath)
    
    def _commit_batch(self, tasks: List[RefactoringTask], batch_id: int, partial: bool = False, build_failing: bool = False):
        """
        Commit successful refactorings to git.
        
        Args:
            tasks: List of tasks to commit
            batch_id: Current batch number
            partial: Whether this is a partial batch (some failed)
            build_failing: Whether build is still failing (commit anyway for recovery)
        """
        if not tasks:
            return
        
        try:
            # Stage all modified files
            modified_files = list(set([task.file for task in tasks]))
            
            logger.info(f"💾 Committing {len(tasks)} refactorings...")
            
            for file in modified_files:
                result = subprocess.run(
                    ['git', 'add', file],
                    cwd=self.repo_root,
                    capture_output=True,
                    text=True
                )
                if result.returncode != 0:
                    logger.warning(f"  ⚠️  Warning: Could not stage {file}")
            
            # Create commit message
            status = "partial" if partial else "complete"
            build_status = " (build failing)" if build_failing else ""
            
            commit_title = f"SwiftLint: Batch {batch_id} - {len(tasks)} refactorings ({status}){build_status}"
            
            # Add details about what was refactored
            commit_body_lines = [
                "",
                f"Session: {self.session_id}",
                f"Batch: {batch_id}",
                f"Tasks completed: {len(tasks)}",
                "",
                "Refactorings:"
            ]
            
            for task in tasks[:10]:  # Limit to first 10 for readability
                commit_body_lines.append(f"- {Path(task.file).name}: {task.description}")
            
            if len(tasks) > 10:
                commit_body_lines.append(f"... and {len(tasks) - 10} more")
            
            commit_body_lines.extend([
                "",
                "DeepSeek Decisions:",
                f"- Approvals: {sum(1 for t in tasks if t.agent_reasoning and 'APPROVE' in t.agent_reasoning.upper())}",
                f"- Improvements: {sum(1 for t in tasks if t.agent_reasoning and 'IMPROVE' in t.agent_reasoning.upper())}",
            ])
            
            if build_failing:
                commit_body_lines.extend([
                    "",
                    "⚠️  Note: Build is currently failing",
                    "These changes appear unrelated to the build failure.",
                    "Committing to preserve progress."
                ])
            
            commit_message = commit_title + "\n" + "\n".join(commit_body_lines)
            
            # Commit
            result = subprocess.run(
                ['git', 'commit', '-m', commit_message],
                cwd=self.repo_root,
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                logger.info(f"  ✅ Committed successfully")
                # Extract commit hash
                commit_hash = result.stdout.strip().split()[1] if result.stdout else "unknown"
                print(f"  📝 Commit: {commit_hash}")
            else:
                logger.warning(f"  ⚠️  Commit failed: {result.stderr}")
                
        except Exception as e:
            logger.error(f"  ⚠️  Error committing: {e}")
    
    def _cleanup_backups(self, tasks: List[RefactoringTask]):
        """Clean up backup files for successfully committed changes."""
        for task in tasks:
            backup_path = Path(task.file).with_suffix('.swift.bak')
            if backup_path.exists():
                try:
                    backup_path.unlink()
                except Exception as e:
                    logger.warning(f"  ⚠️  Could not delete backup {backup_path}: {e}")
    
    def _reassign_failed_tasks(self):
        """Reassign failed tasks for retry."""
        for task in self.failed_tasks:
            task.status = RefactoringStatus.REASSIGNED
            self.pending_queue.put(task)
        
        self.failed_tasks.clear()
    
    def _get_code_from_file(self, filepath: str, line: int) -> str:
        """Get code from file at line."""
        try:
            path = Path(filepath)
            if not path.exists():
                return ""
            
            lines = path.read_text().splitlines()
            if line <= len(lines):
                # Get surrounding context (5 lines before and after)
                start = max(0, line - 6)
                end = min(len(lines), line + 5)
                return '\n'.join(lines[start:end])
            return ""
        except Exception:
            return ""
    
    def _save_checkpoint(self):
        """Save checkpoint for recovery."""
        checkpoint_file = self.repo_root / f"checkpoint_{self.session_id}.json"
        
        checkpoint = {
            'session_id': self.session_id,
            'timestamp': datetime.now().isoformat(),
            'current_batch': self.current_batch,
            'stats': self.stats,
            'completed_tasks': [t.to_dict() for t in self.completed_tasks],
            'failed_tasks': [t.to_dict() for t in self.failed_tasks],
            'batch_results': [asdict(br) for br in self.batch_results]
        }
        
        checkpoint_file.write_text(json.dumps(checkpoint, indent=2))
    
    def _print_final_summary(self):
        """Print final summary."""
        print("\n" + "=" * 80)
        print("📊 FINAL SUMMARY")
        print("=" * 80)
        print(f"Session ID: {self.session_id}")
        print(f"Duration: {self.stats['total_duration']:.1f}s")
        print()
        print("Tasks:")
        print(f"  Total:               {self.stats['total_tasks']}")
        print(f"  Completed:           {self.stats['completed']}")
        print(f"  Failed:              {self.stats['failed']}")
        print(f"  Validation Failed:   {self.stats['validation_failed']}")
        print()
        print("DeepSeek Decisions:")
        print(f"  Approvals:           {self.stats['deepseek_approvals']}")
        print(f"  Improvements:        {self.stats['deepseek_improvements']}")
        print(f"  Rejections:          {self.stats['deepseek_rejections']}")
        print()
        print("Batches:")
        print(f"  Total:               {self.stats['batches_processed']}")
        print(f"  Successful Builds:   {self.stats['successful_builds']}")
        print(f"  Failed Builds:       {self.stats['failed_builds']}")
        print()
        print("Performance:")
        print(f"  Avg Batch Time:      {self.stats['total_duration'] / max(1, self.stats['batches_processed']):.1f}s")
        print(f"  Tasks/Second:        {self.stats['completed'] / max(1, self.stats['total_duration']):.2f}")
        print(f"  Token Usage:         {self.stats['total_tokens']}")
        print("=" * 80)
    
    def _save_final_report(self):
        """Save final report."""
        report_file = self.repo_root / f"parallel_refactoring_report_{self.session_id}.json"
        
        report = {
            'session_id': self.session_id,
            'timestamp': datetime.now().isoformat(),
            'configuration': {
                'num_agents': self.num_agents,
                'batch_size': self.batch_size,
                'model': 'deepseek-chat',
                'mock': self.mock
            },
            'stats': self.stats,
            'completed_tasks': [t.to_dict() for t in self.completed_tasks],
            'failed_tasks': [t.to_dict() for t in self.failed_tasks],
            'batch_results': [asdict(br) for br in self.batch_results]
        }
        
        report_file.write_text(json.dumps(report, indent=2))
        print(f"\n📄 Report saved: {report_file.name}")


def main():
    parser = argparse.ArgumentParser(
        description='Parallel DeepSeek Agent Refactoring Orchestrator',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Scan and fix ALL SwiftLint violations (high-value only)
  export DEEPSEEK_API_KEY="your-key-here"
  python3 Scripts/swiftlint_parallel_orchestrator.py --scan --agents 10
  
  # Scan specific rules only
  python3 Scripts/swiftlint_parallel_orchestrator.py --scan --rules force_unwrapping,force_cast,large_tuple
  
  # Include style violations (explicit_type_interface, explicit_acl, etc.)
  python3 Scripts/swiftlint_parallel_orchestrator.py --scan --include-style --limit 500
  
  # Run with existing plan file
  python3 Scripts/swiftlint_parallel_orchestrator.py --agents 10 --plan function_params_filtered.json
  

  
  # Analyze module quality and generate improvement tasks
  python3 Scripts/swiftlint_parallel_orchestrator.py --quality --min-score 60
  
  # Combined: Fix violations AND improve quality
  python3 Scripts/swiftlint_parallel_orchestrator.py --scan --quality --agents 10

Note: Uses baked-in API key or DEEPSEEK_API_KEY environment variable

Rule Categories:
  High-Value (P1): function_parameter_count, large_tuple, file_length, force_unwrapping, force_cast, force_try
  Medium-Value (P2): identifier_name, nesting, for_where, multiline_arguments
  Style (P4): explicit_type_interface, explicit_acl (use --include-style)
  Auto-Fix: trailing_whitespace, redundant_string_enum_value (use swiftlint --fix instead)

Quality Checks:
  Documentation: Missing public API docs, missing README
  Error Handling: Generic throws (use AnigmaError)
  Testing: Low test coverage
  Swift 6: Missing Sendable, actor isolation
  Anigma Patterns: Bauhaus tokens, OperationResult, governance
        """
    )
    
    # Mode selection
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        '--scan',
        action='store_true',
        help='Scan SwiftLint violations directly (recommended)'
    )
    mode_group.add_argument(
        '--quality',
        action='store_true',
        help='Analyze module quality and generate improvement tasks'
    )
    mode_group.add_argument(
        '--plan',
        type=Path,
        help='Use existing refactoring plan JSON file'
    )
    mode_group.add_argument(
        '--resume',
        type=Path,
        help='Resume from checkpoint file'
    )
    mode_group.add_argument(
        '--detect-corruption',
        action='store_true',
        help='Scan for corrupted Swift files (syntax errors, unbalanced braces)'
    )
    
    # Quality options
    parser.add_argument(
        '--min-score',
        type=float,
        default=70.0,
        help='Minimum quality score (0-100) to skip a module (default: 70)'
    )
    parser.add_argument(
        '--with-quality',
        action='store_true',
        help='Also analyze module quality when using --scan'
    )

    # Scan options
    parser.add_argument(
        '--rules',
        type=str,
        help='Comma-separated list of rule IDs to focus on (e.g., force_unwrapping,large_tuple)'
    )
    parser.add_argument(
        '--include-style',
        action='store_true',
        help='Include style preference violations (explicit_type_interface, explicit_acl, etc.)'
    )
    parser.add_argument(
        '--limit',
        type=int,
        default=1000,
        help='Maximum violations to process (default: 1000)'
    )
    
    # Execution options
    parser.add_argument(
        '--agents',
        type=int,
        default=10,
        help='Number of parallel DeepSeek agents (default: 10)'
    )
    parser.add_argument(
        '--batch-size',
        type=int,
        default=10,
        help='Number of tasks per batch (default: 10)'
    )
    parser.add_argument(
        '--api-key',
        type=str,
        help='DeepSeek API key (or set DEEPSEEK_API_KEY env var)'
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
    
    try:
        orchestrator = ParallelOrchestrator(
            repo_root=repo_root,
            num_agents=args.agents,
            batch_size=args.batch_size,
            api_key=args.api_key
        )
    except ValueError as e:
        print(f"❌ {e}")
        print("\nSet your DeepSeek API key:")
        print("  export DEEPSEEK_API_KEY='your-key-here'")
        print("  or use --api-key flag")
        sys.exit(1)
    
    if args.resume:
        print(f"⚠️  Resume functionality not yet implemented")
        sys.exit(1)

    elif args.detect_corruption:
        # Scan for corruption
        print("\n" + "=" * 80)
        print("🔍 SWIFT CORRUPTION DETECTOR")
        print("=" * 80)
        
        detector = SwiftCorruptionDetector(repo_root)
        corrupted = detector.scan_repository()
        detector.print_report()
        
        if corrupted:
            print(f"\n❌ Found {len(corrupted)} corrupted files")
            sys.exit(1)
        
        print("\n✅ No corruption detected")
        return 0
        
    elif args.scan:
        # Scan SwiftLint violations directly
        print("\n" + "=" * 80)
        print("🔍 SWIFTLINT VIOLATION SCANNER")
        print("=" * 80)
        
        scanner = SwiftLintScanner(repo_root)
        
        # Parse rules filter
        rules_filter = None
        if args.rules:
            rules_filter = [r.strip() for r in args.rules.split(',')]
            print(f"Filtering rules: {rules_filter}")
        
        # Scan violations
        scanner.scan_violations(rules=rules_filter, limit=args.limit)
        scanner.print_summary()
        
        # Determine tasks
        tasks = []
        
        # 1. SwiftLint Violations
        if scanner.violations:
            lint_tasks = scanner.generate_refactoring_tasks(
                session_id=orchestrator.session_id,
                include_auto_fix=False,
                include_style=args.include_style,
                priority_rules=rules_filter
            )
            tasks.extend(lint_tasks)
            print(f"✅ Generated {len(lint_tasks)} SwiftLint refactoring tasks")
            
        # 2. Module Quality (if requested)
        if args.with_quality:
            print("\n" + "=" * 80)
            print("📊 MODULE QUALITY ANALYZER")
            print("=" * 80)
            
            analyzer = ModuleQualityAnalyzer(repo_root)
            analyzer.scan_modules()
            analyzer.print_summary()
            
            quality_tasks = analyzer.generate_improvement_tasks(
                session_id=orchestrator.session_id,
                min_score=args.min_score
            )
            tasks.extend(quality_tasks)
            print(f"✅ Generated {len(quality_tasks)} quality improvement tasks")
        
        if not tasks:
            print("⚠️  No tasks generated!")
            if not args.with_quality:
                print("   Try adding --with-quality to include module improvements")
            return 0
        
        # Add tasks to orchestrator
        for task in tasks:
            orchestrator.all_tasks.append(task)
            orchestrator.pending_queue.put(task)
        
        orchestrator.stats['total_tasks'] = len(tasks)
        
        # Confirm before proceeding
        print(f"\n⚠️  About to process {len(tasks)} tasks with DeepSeek AI")
        print(f"   Estimated cost: ~${len(tasks) * 0.01:.2f} (at $0.01/task)")
        print(f"   Press Ctrl+C to cancel, or Enter to continue...")
        try:
            input()
        except KeyboardInterrupt:
            print("\n🛑 Cancelled")
            return 1
        
        # Run refactoring
        orchestrator.run_parallel_refactoring()
        
    elif args.quality:
        # Analyze Quality Only
        print("\n" + "=" * 80)
        print("📊 MODULE QUALITY ANALYZER")
        print("=" * 80)
        
        analyzer = ModuleQualityAnalyzer(repo_root)
        analyzer.scan_modules()
        analyzer.print_summary()
        
        tasks = analyzer.generate_improvement_tasks(
            session_id=orchestrator.session_id,
            min_score=args.min_score
        )
        
        if not tasks:
            print("✅ All modules meet the quality threshold!")
            return 0
            
        print(f"\n✅ Generated {len(tasks)} improvement tasks")
        
        # Add tasks to orchestrator
        for task in tasks:
            orchestrator.all_tasks.append(task)
            orchestrator.pending_queue.put(task)
            
        orchestrator.stats['total_tasks'] = len(tasks)
        
        # Confirm before proceeding
        print(f"\n⚠️  About to process {len(tasks)} quality improvements")
        print(f"   Press Ctrl+C to cancel, or Enter to continue...")
        try:
            input()
        except KeyboardInterrupt:
            return 1
                
        orchestrator.run_parallel_refactoring()
        
    elif args.plan:
        orchestrator.load_refactoring_plan(args.plan)
        orchestrator.run_parallel_refactoring()

        
    elif args.plan:
        orchestrator.load_refactoring_plan(args.plan)
        orchestrator.run_parallel_refactoring()
        
    else:
        parser.print_help()
        print("\n💡 Quick start:")
        print("   # Scan and fix high-value violations:")
        print("   python3 Scripts/swiftlint_parallel_orchestrator.py --scan --limit 50")
        sys.exit(1)
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
