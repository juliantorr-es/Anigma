# SwiftLint Interactive Agent-Assisted Refactoring

**AI-powered code refactoring with human-level judgment**

## Overview

This tool creates a **collaborative refactoring workflow** between automated analysis and AI agent judgment. Instead of blindly applying refactorings, it presents each proposal to an AI agent who can:

- ✅ **Approve** refactorings that look correct
- ❌ **Reject** refactorings that seem problematic  
- ✏️ **Modify** refactorings with better alternatives
- ⏭️ **Skip** refactorings for later review
- 🔍 **Request detailed analysis** before deciding

## Key Features

### 1. Intelligent Proposal Generation
- Analyzes codebase using AST parsing
- Generates context-aware refactoring suggestions
- Calculates confidence scores
- Estimates impact (low/medium/high)

### 2. Rich Context Presentation
Each proposal includes:
- Original code with line numbers
- Proposed refactoring
- Surrounding context (5 lines before/after)
- Complexity/parameter reduction metrics
- Confidence score and estimated impact

### 3. Agent Decision Framework
The agent can make informed decisions with:
- Full code context
- Detailed analysis on demand
- Ability to propose alternatives
- Reasoning capture for learning

### 4. Safety & Auditability
- Automatic backups before changes
- Complete session logging
- Rollback capability
- Approval tracking

## Quick Start

### Interactive Mode (Recommended)

```bash
# Start interactive session
python3 Scripts/swiftlint_agent_refactor.py --interactive

# Or load existing refactoring plan
python3 Scripts/swiftlint_agent_refactor.py --plan refactoring_plan.json
```

### Auto-Approve Mode

```bash
# Auto-approve high confidence proposals (≥90%)
python3 Scripts/swiftlint_agent_refactor.py --auto-approve --min-confidence 0.9
```

### Review Mode

```bash
# Review proposals without applying
python3 Scripts/swiftlint_agent_refactor.py --review-only --plan plan.json
```

## Interactive Session Example

### Proposal Presentation

```
================================================================================
📋 Refactoring Proposal #20260111_220000_0042
================================================================================
Type: extract_config
File: Packages/DatabaseCore/MasterLedgerStore.swift
Lines: 142-165
Confidence: 85%
Impact: high

Description: Extract config object for recordToolCallEvent (9 params)
Complexity Reduction: 5
Parameter Reduction: 8

────────────────────────────────────────────────────────────────────────────────
📄 ORIGINAL CODE:
────────────────────────────────────────────────────────────────────────────────
  1 │ func recordToolCallEvent(
  2 │     sessionId: String,
  3 │     toolName: String,
  4 │     parameters: [String: Any],
  5 │     result: ToolResult,
  6 │     duration: TimeInterval,
  7 │     timestamp: Date,
  8 │     userId: String,
  9 │     metadata: [String: String]
 10 │ ) async throws -> UUID {
 11 │     // ... implementation
 12 │ }

────────────────────────────────────────────────────────────────────────────────
✨ PROPOSED REFACTORING:
────────────────────────────────────────────────────────────────────────────────
  1 │ public struct RecordToolCallEventConfiguration {
  2 │     public let sessionId: String
  3 │     public let toolName: String
  4 │     public let parameters: [String: Any]
  5 │     public let result: ToolResult
  6 │     public let duration: TimeInterval
  7 │     public let timestamp: Date
  8 │     public let userId: String
  9 │     public let metadata: [String: String]
 10 │     
 11 │     public init(...) { ... }
 12 │ }
 13 │ 
 14 │ func recordToolCallEvent(
 15 │     config: RecordToolCallEventConfiguration
 16 │ ) async throws -> UUID {
 17 │     // ... implementation using config.propertyName
 18 │ }

────────────────────────────────────────────────────────────────────────────────
🔍 SURROUNDING CONTEXT:
────────────────────────────────────────────────────────────────────────────────
 137      // Tool call recording
 138      
 139      /// Records a tool call event in the ledger
 140      ///
 141      /// - Parameters:
 142  →    func recordToolCallEvent(
 143          sessionId: String,
 144          toolName: String,
 145          ...
 147      ) async throws -> UUID {

================================================================================

🤖 AGENT DECISION REQUIRED
────────────────────────────────────────────────────────────────────────────────
Options:
  [a] Approve - Apply this refactoring as-is
  [r] Reject - Skip this refactoring
  [m] Modify - Propose an alternative refactoring
  [s] Skip - Skip for now, review later
  [?] Help - Show detailed analysis

Your decision [a/r/m/s/?]: 
```

### Agent Decisions

#### Approve
```
Your decision [a/r/m/s/?]: a
Reasoning (optional): Good refactoring, reduces parameter count significantly
✅ Approved and applied
  ✅ Applied to Packages/DatabaseCore/MasterLedgerStore.swift
  💾 Backup: Packages/DatabaseCore/MasterLedgerStore.swift.bak
```

#### Reject
```
Your decision [a/r/m/s/?]: r
Why reject? This function is called in too many places, migration would be too disruptive
❌ Rejected
```

#### Modify
```
Your decision [a/r/m/s/?]: m

✏️  Enter your alternative refactoring:
(Type 'END' on a new line when done)
public struct ToolCallEvent {
    let sessionId: String
    let toolName: String
    let parameters: [String: Any]
    let result: ToolResult
    let duration: TimeInterval
    let timestamp: Date
    let userId: String
    let metadata: [String: String]
}

func recordToolCallEvent(_ event: ToolCallEvent) async throws -> UUID {
    // Use event.propertyName
}
END

Explain your changes: Better name (ToolCallEvent vs RecordToolCallEventConfiguration), 
                      and using unnamed parameter for cleaner call site

✏️  Modified and applied
  📝 Agent modified the refactoring
     Original proposal: 450 chars
     Agent version: 380 chars
  ✅ Applied to Packages/DatabaseCore/MasterLedgerStore.swift
  💾 Backup: Packages/DatabaseCore/MasterLedgerStore.swift.bak
```

#### Request Analysis
```
Your decision [a/r/m/s/?]: ?

📊 DETAILED ANALYSIS
────────────────────────────────────────────────────────────────────────────────
Lines of code: 12 → 18 (+6)

Potential Issues:
  ⚠️  Significantly increases code size

Key Changes:
  • Extracts configuration object
  • Reduces parameter count
  • Improves maintainability

Your decision [a/r/m/s/?]: a
```

## Session Output

### Session Summary

```
================================================================================
📊 SESSION SUMMARY
================================================================================
Approved: 42
Modified: 8
Rejected: 15
Skipped: 3
Total: 68

Session log: session_20260111_220000.json
================================================================================
```

### Session Log Format

```json
{
  "session_id": "20260111_220000",
  "timestamp": "2026-01-11T22:00:00",
  "proposals": [
    {
      "id": "20260111_220000_0001",
      "type": "extract_config",
      "file": "Packages/DatabaseCore/MasterLedgerStore.swift",
      "line_start": 142,
      "description": "Extract config object for recordToolCallEvent",
      "confidence": 0.85,
      "agent_feedback": {
        "decision": "approve",
        "reasoning": "Good refactoring, reduces parameter count",
        "confidence": 1.0
      },
      "applied": true,
      "applied_at": "2026-01-11T22:05:23"
    }
  ],
  "log": [
    {
      "proposal_id": "20260111_220000_0001",
      "decision": "approve",
      "reasoning": "Good refactoring, reduces parameter count",
      "timestamp": "2026-01-11T22:05:23"
    }
  ]
}
```

## Integration with Existing Tools

### Workflow

```bash
# 1. Generate refactoring plan
python3 Scripts/swiftlint_refactor.py --refactor all --export-plan plan.json

# 2. Review with agent assistance
python3 Scripts/swiftlint_agent_refactor.py --plan plan.json

# 3. Export approved changes
python3 Scripts/swiftlint_agent_refactor.py --plan plan.json --export approved.json

# 4. Verify build
swift build && swift test

# 5. Commit approved changes
git add -A
git commit -m "Refactor: Agent-approved changes (42 refactorings)"
```

### With CI/CD

```yaml
# .github/workflows/agent-refactor.yml
name: Agent-Assisted Refactoring

on:
  workflow_dispatch:
    inputs:
      min_confidence:
        description: 'Minimum confidence for auto-approval'
        required: false
        default: '0.95'

jobs:
  refactor:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Generate refactoring plan
        run: python3 Scripts/swiftlint_refactor.py --refactor all --export-plan plan.json
      
      - name: Auto-approve high confidence
        run: |
          python3 Scripts/swiftlint_agent_refactor.py \
            --plan plan.json \
            --auto-approve \
            --min-confidence ${{ github.event.inputs.min_confidence }} \
            --export approved.json
      
      - name: Verify build
        run: swift build
      
      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          title: "Refactor: Agent-approved changes"
          body-path: approved.json
```

## Advanced Features

### Confidence Scoring

The tool calculates confidence based on:
- **Code complexity** (simpler = higher confidence)
- **Pattern matching** (known patterns = higher confidence)
- **Impact analysis** (smaller impact = higher confidence)
- **Historical success** (learns from agent feedback)

### Learning from Feedback

The tool tracks agent decisions to improve future suggestions:

```python
# Agent frequently approves parameter extraction
→ Increase confidence for similar refactorings

# Agent often rejects tuple conversions in tests
→ Decrease confidence for test file tuples

# Agent prefers specific naming patterns
→ Adjust code generation to match preferences
```

### Batch Processing

```bash
# Process only high-confidence proposals
python3 Scripts/swiftlint_agent_refactor.py \
  --plan plan.json \
  --auto-approve \
  --min-confidence 0.95

# Process specific types
python3 Scripts/swiftlint_agent_refactor.py \
  --plan plan.json \
  --filter-type extract_config
```

## Safety Features

### Automatic Backups

Every modified file gets a `.swift.bak` backup:

```bash
# Restore if needed
cp Packages/AnigmaCore/World.swift.bak Packages/AnigmaCore/World.swift

# Restore all
find . -name "*.swift.bak" -exec sh -c 'cp "$1" "${1%.bak}"' _ {} \;

# Clean up after verification
find . -name "*.swift.bak" -delete
```

### Session Recovery

If the session is interrupted:

```bash
# Resume from last session
python3 Scripts/swiftlint_agent_refactor.py --resume session_20260111_220000.json
```

### Rollback

```bash
# Rollback entire session
python3 Scripts/swiftlint_agent_refactor.py --rollback session_20260111_220000.json
```

## Best Practices

### For Agents

1. **Request analysis** (`?`) when unsure
2. **Provide detailed reasoning** for learning
3. **Modify** rather than reject when possible
4. **Consider call sites** before approving
5. **Check for breaking changes**

### For Developers

1. **Review session logs** after completion
2. **Run tests** before committing
3. **Verify backups** exist
4. **Clean up** `.bak` files after verification
5. **Update documentation** for API changes

## Troubleshooting

### "No proposals to review"

Generate proposals first:
```bash
python3 Scripts/swiftlint_refactor.py --refactor all --export-plan plan.json
```

### "File not found"

Ensure paths in plan are relative to repo root:
```bash
python3 Scripts/swiftlint_agent_refactor.py --repo-root /path/to/repo --plan plan.json
```

### "Build fails after refactoring"

Restore from backups and review:
```bash
find . -name "*.swift.bak" -exec sh -c 'cp "$1" "${1%.bak}"' _ {} \;
cat session_*.json | jq '.log[] | select(.decision == "approve")'
```

## Future Enhancements

Planned features:

- [ ] **LLM integration** for automated agent decisions
- [ ] **Multi-agent review** (consensus-based approval)
- [ ] **Caller analysis** (find all call sites)
- [ ] **Test generation** for refactored code
- [ ] **Performance impact** analysis
- [ ] **Breaking change** detection
- [ ] **Migration script** generation
- [ ] **Diff visualization** in terminal

## See Also

- [SwiftLint Auto-Fix Tool](README_SWIFTLINT_AUTOFIX.md)
- [SwiftLint Refactor Tool](README_SWIFTLINT_REFACTOR.md)
- [Automation Guide](../Docs/development/swiftlint-automation-guide.md)

---

**Last Updated**: 2026-01-11  
**Maintainer**: Anigma Development Team  
**Status**: Production Ready ✅
