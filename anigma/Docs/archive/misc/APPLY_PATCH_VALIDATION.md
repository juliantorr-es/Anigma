# Apply Patch Tool - Swift Code Validation

## Overview

The `apply_patch` tool now includes **pre-flight validation** that checks Swift code for concurrency violations, Sendable conformance issues, data races, and best practices **before** permanently applying patches. This provides AI agents with immediate, actionable feedback to write better, safer code.

## What Gets Validated

### 1. **Strict Concurrency Checking** ✅
- Detects Swift 6 concurrency violations
- Identifies unsafe concurrent access patterns
- Flags missing `async/await` in concurrent contexts

### 2. **Sendable Conformance** ✅
- Detects types that should conform to `Sendable`
- Identifies non-Sendable types crossing actor boundaries
- Suggests where to add `Sendable` conformance

### 3. **Actor Isolation** ✅
- Detects incorrect actor-isolated access
- Identifies missing `await` for actor-isolated properties
- Flags `nonisolated` misuse

### 4. **Data Race Detection** ✅
- Detects potential data races at compile time
- Identifies shared mutable state without protection
- Suggests actor-based solutions

### 5. **Compilation Errors & Warnings** ✅
- Full Swift compiler diagnostics
- Type errors, missing imports, etc.
- All standard compilation issues

### 6. **Style & Best Practices** ✅
- SwiftLint integration (if available)
- Common anti-patterns detection:
  - `@unchecked Sendable` without comments
  - `DispatchQueue` usage (prefer actors)
  - Force unwrapping (`!`) without guards
  - And more...

## How It Works

### Validation Pipeline

```
1. Patch Applied → 2. Content Verified → 3. Swift Validation → 4. Result/Rollback
                                               ↓
                                    ┌──────────┴──────────┐
                                    │                     │
                              Compile Check      Pattern Analysis
                            (strict concurrency)  (anti-patterns)
                                    │                     │
                                    └──────────┬──────────┘
                                               ↓
                                        Issues Found?
                                               ↓
                                    Yes → Rollback (if enabled)
                                    No  → Patch Accepted
```

### Compiler Flags Used

The validation runs `swift build` with these flags:

```bash
-Xswiftc -strict-concurrency=complete
-Xswiftc -enable-actor-data-race-checks
-Xswiftc -warn-concurrency
-Xswiftc -enable-upcoming-feature -Xswiftc StrictConcurrency
```

This ensures **maximum safety** for Swift 6 concurrency.

## Usage

### Default Behavior (Validation Enabled)

```json
{
  "tool": "apply_patch",
  "arguments": {
    "patch": "diff --git a/Sources/MyFile.swift ...",
    "rollback_on_failure": true
  }
}
```

**Result:** Patch is validated. If validation fails, changes are **automatically rolled back**.

### Skip Validation (Not Recommended)

```json
{
  "tool": "apply_patch",
  "arguments": {
    "patch": "diff --git a/Sources/MyFile.swift ...",
    "skip_validation": true
  }
}
```

**Use case:** Emergency fixes, non-Swift files, or when you know validation will fail but want the patch anyway.

## Output Format

### Success Response

```json
{
  "patchId": "abc-123",
  "exitCode": 0,
  "snapshots": [...],
  "verifications": [...],
  "validation": {
    "isValid": true,
    "compilationSucceeded": true,
    "issues": [],
    "suggestions": [],
    "buildOutput": "Build succeeded"
  },
  "rollback": null,
  "error": null
}
```

### Failure Response with Validation Issues

```json
{
  "patchId": "abc-123",
  "exitCode": 0,
  "snapshots": [...],
  "verifications": [...],
  "validation": {
    "isValid": false,
    "compilationSucceeded": false,
    "issues": [
      {
        "type": "sendable_conformance",
        "severity": "error",
        "filePath": "Sources/MyFile.swift",
        "line": 42,
        "column": 8,
        "message": "Type 'MyClass' does not conform to the 'Sendable' protocol",
        "rawOutput": "Sources/MyFile.swift:42:8: error: Type 'MyClass' does not conform to the 'Sendable' protocol"
      },
      {
        "type": "actor_isolation",
        "severity": "error",
        "filePath": "Sources/MyFile.swift",
        "line": 55,
        "column": 16,
        "message": "Actor-isolated property 'counter' cannot be referenced from a non-isolated context",
        "rawOutput": "Sources/MyFile.swift:55:16: error: Actor-isolated property 'counter' cannot be referenced from a non-isolated context"
      }
    ],
    "suggestions": [
      {
        "issueType": "sendable_conformance",
        "filePath": "Sources/MyFile.swift",
        "line": 42,
        "description": "Add Sendable conformance to the type declaration",
        "exampleFix": "// Change:\nstruct MyType { ... }\n\n// To:\nstruct MyType: Sendable { ... }\n\n// Or for classes with mutable state, use an actor:\nactor MyType { ... }",
        "automaticFixAvailable": true
      },
      {
        "issueType": "actor_isolation",
        "filePath": "Sources/MyFile.swift",
        "line": 55,
        "description": "Access actor-isolated property asynchronously or mark caller as nonisolated",
        "exampleFix": "// Option 1: Use await\nlet value = await myActor.property\n\n// Option 2: Mark as nonisolated if safe\nnonisolated func myMethod() { ... }",
        "automaticFixAvailable": false
      }
    ],
    "buildOutput": "[Full compiler output here]"
  },
  "rollback": {
    "performed": true,
    "restoredFiles": ["Sources/MyFile.swift"],
    "reason": "swift_validation_failed"
  },
  "error": null
}
```

## Issue Types

| Type | Description | Example Fix |
|------|-------------|-------------|
| `strict_concurrency` | General concurrency violation | Add `async/await`, use actors |
| `sendable_conformance` | Type needs `Sendable` | Add `: Sendable` to declaration |
| `actor_isolation` | Incorrect actor access | Use `await` or `nonisolated` |
| `data_race` | Potential data race | Protect state with actor |
| `compilation_error` | Standard compile error | Fix syntax, types, imports |
| `compilation_warning` | Compiler warning | Address the warning |
| `style_violation` | SwiftLint violation | Follow style guide |
| `best_practice` | Anti-pattern detected | Use recommended pattern |

## For AI Agents

When you receive validation failures, the response includes:

1. **Exact line numbers** - Know precisely where the issue is
2. **Clear error messages** - Understand what's wrong
3. **Fix suggestions** - Get concrete examples of how to fix it
4. **Code snippets** - See the problematic code

### Example Agent Workflow

```
Agent: Apply patch to add new feature
  ↓
Tool: Patch applied successfully
  ↓
Tool: Running Swift validation...
  ↓
Tool: ❌ Validation failed:
      - Line 42: Missing Sendable conformance
      - Line 55: Actor isolation violation
  ↓
Tool: Rolling back changes...
  ↓
Agent: Reads validation.suggestions
  ↓
Agent: Generates new patch with fixes:
      - Added ': Sendable' to struct
      - Added 'await' before actor property access
  ↓
Agent: Apply corrected patch
  ↓
Tool: ✅ Validation passed - patch accepted
```

## Configuration

### Enable/Disable Validation

**In ApplyPatchTool:**
```swift
let tool = ApplyPatchTool(
    repoRoot: "/path/to/repo",
    enablePreFlightValidation: true  // default
)
```

**Via MCP:**
```json
{
  "skip_validation": false  // default
}
```

### Rollback Behavior

| Condition | Rollback? |
|-----------|-----------|
| Patch fails to apply | ✅ Yes (if `rollback_on_failure: true`) |
| Content verification fails | ✅ Yes (if `rollback_on_failure: true`) |
| Swift validation fails | ✅ Yes (if `rollback_on_failure: true`) |
| All checks pass | ❌ No (patch accepted) |

## Performance

| Operation | Typical Time |
|-----------|--------------|
| Small patch (1 file) | ~2-5 seconds |
| Medium patch (3-5 files) | ~5-10 seconds |
| Large patch (10+ files) | ~10-30 seconds |

Validation time depends on:
- Number of Swift files affected
- Project compilation complexity
- Swift compiler performance

## Best Practices

### For AI Agents

1. **Always review validation output** - Don't ignore it
2. **Apply suggestions** - They're concrete and actionable
3. **Iterate quickly** - Fix issues and resubmit
4. **Learn patterns** - Similar fixes often work for similar issues

### For Developers

1. **Keep validation enabled** - It catches bugs early
2. **Use `skip_validation` sparingly** - Only when necessary
3. **Fix issues properly** - Don't work around validation
4. **Monitor validation logs** - They're in the audit trail

## Troubleshooting

### "Validation timeout"

**Cause:** Large project taking too long to compile
**Solution:**
- Split patches into smaller chunks
- Use `skip_validation` for non-critical changes
- Increase timeout (requires code change)

### "SwiftLint not found"

**Cause:** SwiftLint not installed
**Impact:** Style checking skipped (not critical)
**Solution:** `brew install swiftlint` (optional)

### "False positive on @unchecked Sendable"

**Cause:** Legitimate use without comment
**Solution:** Add a comment explaining why it's safe:
```swift
final class MyClass: @unchecked Sendable { // Safe: all state is immutable
    private let value: String
}
```

## Future Enhancements

Planned improvements:

- [ ] Automatic fixes for common issues (e.g., add `Sendable`)
- [ ] Stack overflow detection (recursion analysis)
- [ ] Memory leak detection
- [ ] Performance regression detection
- [ ] Custom validation rules via Doctrine
- [ ] Parallel validation for multiple files

## Related Documentation

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Sendable Types](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
- [Actor Isolation](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
- [CLAUDE.md](../CLAUDE.md) - Project overview

## Summary

The enhanced `apply_patch` tool now provides **production-grade safety** by validating Swift code before accepting patches. This helps AI agents write correct, concurrent, and safe Swift code from the start, with clear guidance on how to fix any issues that arise.

**Key Benefits:**
- ✅ Catches concurrency bugs before they're committed
- ✅ Enforces Sendable correctness
- ✅ Prevents data races
- ✅ Provides actionable fix suggestions
- ✅ Automatic rollback on failure
- ✅ Complete audit trail
