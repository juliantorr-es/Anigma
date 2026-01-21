# SwiftLint Advanced Refactoring Tool

Intelligent Swift code refactoring using AST parsing and semantic analysis.

## Overview

This tool goes beyond simple pattern matching to perform **semantic refactoring** of complex Swift code violations:

- ✅ **Extract Configuration Objects** - Reduce function parameter counts
- ✅ **Convert Tuples to Structs** - Replace large tuples with proper types
- ✅ **Split Large Files** - Suggest file splitting strategies
- ✅ **Reduce Complexity** - Identify complex functions for refactoring
- ✅ **Generate Migration Guides** - Provide caller update instructions

## Quick Start

```bash
# Analyze codebase for refactoring opportunities
python3 Scripts/swiftlint_refactor.py --analyze

# Preview function parameter refactorings
python3 Scripts/swiftlint_refactor.py --refactor function_params --dry-run

# Apply all refactorings and export plan
python3 Scripts/swiftlint_refactor.py --refactor all --export-plan refactoring_plan.json
```

## Features

### 1. Codebase Analysis

Scans entire codebase and identifies:

```bash
python3 Scripts/swiftlint_refactor.py --analyze
```

**Output**:
```
📊 Analysis Results:
======================================================================
Total files analyzed: 1597
Functions with >6 params: 237
Complex functions (>15): 2770
Large files (>500 lines): 354
Total refactoring opportunities: 3361

📄 Detailed analysis exported to: refactoring_analysis.json
```

The JSON export contains:
- Functions with excessive parameters (name, file, line, param count)
- Complex functions (name, file, line, complexity score)
- Large files (path, line count, function/struct counts)

### 2. Function Parameter Extraction

Automatically generates configuration objects for functions with >6 parameters.

**Before**:
```swift
func createSession(
    userId: String,
    workspaceId: String,
    mode: OperatingMode,
    trustTier: TrustTier,
    timeout: TimeInterval,
    retryCount: Int,
    enableLogging: Bool,
    metadata: [String: String]
) async throws -> Session {
    // ...
}
```

**After** (generated):
```swift
public struct CreateSessionConfiguration {
    public let userId: String
    public let workspaceId: String
    public let mode: OperatingMode
    public let trustTier: TrustTier
    public let timeout: TimeInterval
    public let retryCount: Int
    public let enableLogging: Bool
    public let metadata: [String: String]
    
    public init(
        userId: String,
        workspaceId: String,
        mode: OperatingMode,
        trustTier: TrustTier,
        timeout: TimeInterval,
        retryCount: Int,
        enableLogging: Bool,
        metadata: [String: String]
    ) {
        self.userId = userId
        self.workspaceId = workspaceId
        self.mode = mode
        self.trustTier = trustTier
        self.timeout = timeout
        self.retryCount = retryCount
        self.enableLogging = enableLogging
        self.metadata = metadata
    }
}

public func createSession(
    config: CreateSessionConfiguration
) async throws -> Session {
    // TODO: Update function body to use config.propertyName
    // Original parameters are now: config.paramName
    // ...
}
```

**Migration Guide** (also generated):
```swift
// Migration Guide:
// Old call:
// createSession(
//     userId: value,
//     workspaceId: value,
//     mode: value,
//     trustTier: value,
//     timeout: value,
//     retryCount: value,
//     enableLogging: value,
//     metadata: value
// )
//
// New call:
// let config = CreateSessionConfiguration(
//     userId: value,
//     workspaceId: value,
//     mode: value,
//     trustTier: value,
//     timeout: value,
//     retryCount: value,
//     enableLogging: value,
//     metadata: value
// )
// createSession(config: config)
```

### 3. Tuple to Struct Conversion

Converts large tuples (>2 members) to proper struct types.

**Before**:
```swift
func getStats() -> (count: Int, resetAt: Date, isActive: Bool, lastUpdate: Date)
```

**After** (generated):
```swift
struct Stats {
    let count: Int
    let resetAt: Date
    let isActive: Bool
    let lastUpdate: Date
}

func getStats() -> Stats
```

### 4. File Splitting Suggestions

Analyzes large files and suggests splitting strategies based on function naming patterns.

**Example Output** (`file_split_suggestions.json`):
```json
{
  "file": "Packages/DatabaseCore/ContextumDatabase.swift",
  "lines": 1441,
  "functions": 87,
  "structs": 12,
  "split_strategy": {
    "original_file": "ContextumDatabase.swift",
    "suggested_splits": [
      {
        "filename": "ContextumDatabase+Queries.swift",
        "functions": ["getContext", "fetchHistory", "getRelated"],
        "count": 23
      },
      {
        "filename": "ContextumDatabase+Mutations.swift",
        "functions": ["createContext", "insertEvent", "createRelation"],
        "count": 18
      },
      {
        "filename": "ContextumDatabase+Updates.swift",
        "functions": ["updateContext", "modifyMetadata"],
        "count": 12
      }
    ],
    "note": "Review and adjust category names as needed"
  }
}
```

## Usage Examples

### Example 1: Analyze and Export

```bash
# Full analysis
python3 Scripts/swiftlint_refactor.py --analyze

# Review results
cat refactoring_analysis.json | jq '.functions_with_many_params | length'
# Output: 237

# See specific functions
cat refactoring_analysis.json | jq '.functions_with_many_params[] | select(.param_count > 8)'
```

### Example 2: Preview Function Refactorings

```bash
python3 Scripts/swiftlint_refactor.py --refactor function_params --dry-run
```

**Output**:
```
🔧 Refactoring functions with too many parameters...

  📝 Packages/DatabaseCore/MasterLedgerStore.swift:142
     Type: extract_config
     Description: Extract config object for recordToolCallEvent (9 params)
     Confidence: 85%

     Original:
       - func recordToolCallEvent(
       -     sessionId: String,
       -     toolName: String,
       -     parameters: [String: Any],
       -     ...

     Refactored:
       + public struct RecordToolCallEventConfiguration {
       +     public let sessionId: String
       +     public let toolName: String
       +     ...

✅ Created 237 configuration object refactorings
```

### Example 3: Apply Refactorings

```bash
# Apply function parameter refactorings
python3 Scripts/swiftlint_refactor.py --refactor function_params --export-plan function_params_plan.json

# Review the plan
cat function_params_plan.json | jq '.total_tasks'
# Output: 237

# Apply tuple refactorings
python3 Scripts/swiftlint_refactor.py --refactor large_tuples --export-plan tuples_plan.json

# Apply all
python3 Scripts/swiftlint_refactor.py --refactor all --export-plan complete_plan.json
```

### Example 4: File Splitting

```bash
python3 Scripts/swiftlint_refactor.py --refactor split_files

# Review suggestions
cat file_split_suggestions.json | jq '.[] | select(.lines > 1000)'
```

## Refactoring Plan Format

The exported JSON plan contains all refactoring tasks:

```json
{
  "total_tasks": 237,
  "tasks_by_type": {
    "extract_config": 237,
    "tuple_to_struct": 162,
    "split_file": 354
  },
  "tasks": [
    {
      "type": "extract_config",
      "file": "Packages/DatabaseCore/MasterLedgerStore.swift",
      "line": 142,
      "description": "Extract config object for recordToolCallEvent (9 params)",
      "confidence": 0.85,
      "metadata": {
        "function_name": "recordToolCallEvent",
        "config_name": "RecordToolCallEventConfiguration",
        "parameter_count": 9,
        "migration_guide": "// Migration Guide:\n// Old call:\n..."
      }
    }
  ]
}
```

## Workflow

### Recommended Process

1. **Analyze first**:
   ```bash
   python3 Scripts/swiftlint_refactor.py --analyze
   ```

2. **Review opportunities**:
   ```bash
   cat refactoring_analysis.json | jq '.functions_with_many_params | sort_by(.param_count) | reverse | .[0:10]'
   ```

3. **Preview refactorings**:
   ```bash
   python3 Scripts/swiftlint_refactor.py --refactor function_params --dry-run | less
   ```

4. **Export plan**:
   ```bash
   python3 Scripts/swiftlint_refactor.py --refactor all --export-plan plan.json
   ```

5. **Apply manually** (for now):
   - Review each task in `plan.json`
   - Copy generated code
   - Update callers using migration guides
   - Test thoroughly

6. **Track progress**:
   ```bash
   # Before
   python3 Scripts/swiftlint_auto_fix.py --stats > before.txt
   
   # Apply refactorings...
   
   # After
   python3 Scripts/swiftlint_auto_fix.py --stats > after.txt
   diff before.txt after.txt
   ```

## Advanced Features

### Custom Analysis

The tool parses Swift code to extract:

- **Function signatures** (name, parameters, return type, modifiers)
- **Struct definitions** (properties, methods)
- **Cyclomatic complexity** (simplified calculation)
- **Access levels** (public, private, internal, fileprivate)

### Confidence Scoring

Each refactoring task includes a confidence score:

- **0.85+**: High confidence - safe to apply
- **0.70-0.84**: Medium confidence - review recommended
- **<0.70**: Low confidence - manual review required

### Smart Grouping

File splitting uses intelligent grouping:

- Functions starting with `get`/`fetch` → Queries
- Functions starting with `create`/`insert` → Mutations
- Functions starting with `update`/`modify` → Updates
- Functions starting with `delete`/`remove` → Deletions

## Limitations

### Current Limitations

1. **No automatic application**: Generates refactoring plans, not direct code changes
2. **Simplified parsing**: Uses regex, not full Swift compiler
3. **No type inference**: Cannot resolve complex generic types
4. **No cross-file analysis**: Doesn't track caller locations

### Why Not Auto-Apply?

Refactoring is **semantic** and requires:
- Understanding business logic
- Updating all callers
- Maintaining API compatibility
- Testing edge cases

The tool provides **high-quality suggestions** that developers can review and apply.

## Integration

### With SwiftLint Auto-Fix

```bash
# 1. Apply simple fixes first
python3 Scripts/swiftlint_auto_fix.py --fix all

# 2. Analyze remaining issues
python3 Scripts/swiftlint_refactor.py --analyze

# 3. Generate refactoring plan
python3 Scripts/swiftlint_refactor.py --refactor all --export-plan plan.json

# 4. Apply refactorings manually
# (Review plan.json and implement changes)

# 5. Verify improvements
python3 Scripts/swiftlint_auto_fix.py --stats
```

### With CI/CD

```yaml
# .github/workflows/refactoring-analysis.yml
name: Refactoring Analysis

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  analyze:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Analyze codebase
        run: python3 Scripts/swiftlint_refactor.py --analyze
      
      - name: Upload analysis
        uses: actions/upload-artifact@v3
        with:
          name: refactoring-analysis
          path: refactoring_analysis.json
```

## Troubleshooting

### "Error parsing file"

Some files may have complex syntax. Check:
```bash
# Validate Swift syntax
swiftc -parse Packages/AnigmaCore/World.swift
```

### Large analysis time

The tool parses all Swift files. For faster analysis:
```bash
# Analyze specific directory
python3 Scripts/swiftlint_refactor.py --analyze --repo-root Packages/AnigmaCore
```

### Missing refactorings

Ensure SwiftLint is installed:
```bash
brew install swiftlint
swiftlint version
```

## Future Enhancements

Planned features:

- [ ] **Auto-apply mode** with caller updates
- [ ] **Full AST parsing** using SourceKit
- [ ] **Type inference** for better config generation
- [ ] **Cross-file analysis** to find all callers
- [ ] **Interactive mode** for reviewing each refactoring
- [ ] **Rollback support** with automatic backups
- [ ] **Complexity reduction** (extract methods)
- [ ] **Dead code detection** and removal

## See Also

- [SwiftLint Auto-Fix Tool](README_SWIFTLINT_AUTOFIX.md)
- [SwiftLint Remediation Plan](../Docs/development/swiftlint-remediation-plan.md)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

---

**Last Updated**: 2026-01-11  
**Maintainer**: Anigma Development Team
