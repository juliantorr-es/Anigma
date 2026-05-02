# SwiftLint Remediation Plan

**Status**: 35,737 violations remaining after 421 automated fixes (1.16% reduction)  
**Created**: 2026-01-11  
**Last Updated**: 2026-02-09 (Roadmap refresh: `swiftlint-remediation-roadmap` lane)  
**Priority**: High (active backlog triage)

## Executive Summary

The Anigma codebase still has a large SwiftLint backlog after initial automation. Most low-risk formatting fixes are complete; remaining work is primarily manual and should be sequenced by risk reduction and delivery impact. This document now defines an actionable **P0/P1/P2** execution order aligned to observed counts in current reports.

## Observed Backlog Reality (Current Signals)

| Source | Signal |
|-------|--------|
| `swiftlint_master_execution_report.md` | 35,737 violations remain; automation fixed 421 total so far |
| `swiftlint_baseline.txt` | Backlog dominated by `explicit_type_interface` (22,527), `explicit_acl` (6,639), `explicit_top_level_acl` (1,244) |
| `swiftlint_baseline.txt` | Safety-critical rules still present (`force_unwrapping` 445, `force_cast` 57, `implicitly_unwrapped_optional` 58, `force_try` 23) |
| `swiftlint_execution_summary.md` + automation guide | Structural work remains large (`functions >6 params`: 237 raw / 92 filtered, `complex functions`: 2,770, `large files`: 1,481) |

## Prioritized Remediation Sequence (P0/P1/P2)

### P0 — Runtime Safety + Crash Risk (start here)
**Goal**: Eliminate unsafe runtime patterns before style and governance rules.

**Rules in scope**:
- `force_unwrapping`
- `force_cast`
- `implicitly_unwrapped_optional`
- `force_try`
- `non_optional_string_data_conversion`

**Execution**:
1. Run targeted dry-runs with `Scripts/swiftlint_auto_fix.py` for cast/unwrap categories.
2. Apply in small module batches (Core, Database, Platform first).
3. Require build verification after each batch.

**Ownership hint**: Runtime/core maintainers + one reviewer from module owner team.  
**Exit criteria**: Zero new P0 violations in touched files; no failing build introduced.

---

### P1 — Maintainability Hotspots (parallelizable after P0 is stable)
**Goal**: Reduce high-friction API and structural complexity.

**Rules/workstreams in scope**:
- `function_parameter_count` (use filtered plan with 92 in-repo candidates)
- `large_tuple`
- `cyclomatic_complexity`
- `file_length`
- `multiline_arguments` / `multiline_parameters` (when touched during refactors)

**Execution**:
1. Start with top-10 high-impact parameter offenders from filtered plan.
2. Refactor by module boundary, not by entire repository sweep.
3. Pair each refactor batch with tests/build and lint check.

**Ownership hint**: Feature/module owners (Contextum, CLI, registry/services) with architecture review for API shape changes.  
**Exit criteria**: Worst offenders removed; measurable drop in structural warnings in active modules.

---

### P2 — Governance and Style Debt (scheduled, not blocking P0/P1)
**Goal**: Tackle very large policy/style backlog without destabilizing delivery.

**Rules in scope**:
- `explicit_type_interface`
- `explicit_acl`
- `explicit_top_level_acl`
- remaining formatting consistency rules and custom policy rules

**Execution**:
1. Keep these rules deferred in baseline config while backlog remains >30k.
2. Enforce selectively on actively edited modules first.
3. Expand to repo-wide enforcement only after P0/P1 throughput is stable.

**Ownership hint**: Tech lead + domain maintainers for module-by-module activation decisions.  
**Exit criteria**: Module-scoped governance rollout agreed and documented before global enablement.

---

## Lane Execution Runbook (Recommended Order)

1. `./Scripts/ci/run-swiftlint.sh` (baseline snapshot)
2. Complete one P0 batch (casts/unwraps/force-try) and verify build.
3. Run `./Scripts/ci/run-swiftlint.sh` again to confirm no regressions.
4. Execute P1 top-10 maintainability refactors, then retest.
5. Log remaining P2 backlog and defer broad enforcement changes.

## Rule Playbooks (Detailed Patterns)

### 2.1 Force Unwrapping (445 baseline violations; 100 already auto-remediated)
**Priority**: 🔴 Critical

**Strategy**:
```bash
# Find all force unwraps
swiftlint --reporter json | jq '.[] | select(.rule_id == "force_unwrapping")'
```

**Refactoring Pattern**:
```swift
// ❌ Before
let value = dictionary["key"]!

// ✅ After
guard let value = dictionary["key"] else {
    throw AnigmaError.missingRequiredKey("key")
}
```

**Files to prioritize**:
- `AnigmaCore/` (core infrastructure)
- `DatabaseCore/` (data integrity)
- `PlatformCore/` (runtime stability)

---

### 2.2 Force Cast (57 baseline violations; 15 already auto-remediated)
**Priority**: 🔴 Critical

**Refactoring Pattern**:
```swift
// ❌ Before
let view = subview as! CustomView

// ✅ After
guard let view = subview as? CustomView else {
    logger.error("Expected CustomView, got \(type(of: subview))")
    return
}
```

---

### 2.3 Implicitly Unwrapped Optionals (58 baseline violations)
**Priority**: 🟡 High

**Refactoring Pattern**:
```swift
// ❌ Before
var delegate: SomeDelegate!

// ✅ After - Option 1: Lazy initialization
lazy var delegate: SomeDelegate = createDelegate()

// ✅ After - Option 2: Optional with guard
var delegate: SomeDelegate?
// ... later
guard let delegate = delegate else { return }
```

---

### Phase 3: Code Quality Issues (Week 4-6)
**Goal**: Improve maintainability and readability

#### 3.1 Function Parameter Count (237 raw findings, 92 filtered in-repo tasks)
**Priority**: 🟡 High

**Strategy**: Introduce parameter objects

**Refactoring Pattern**:
```swift
// ❌ Before (9 parameters)
func createSession(
    userId: String,
    workspaceId: String,
    mode: OperatingMode,
    trustTier: TrustTier,
    timeout: TimeInterval,
    retryCount: Int,
    enableLogging: Bool,
    metadata: [String: String],
    completion: @escaping (Result<Session, Error>) -> Void
)

// ✅ After
struct SessionConfiguration {
    let userId: String
    let workspaceId: String
    let mode: OperatingMode
    let trustTier: TrustTier
    let timeout: TimeInterval
    let retryCount: Int
    let enableLogging: Bool
    let metadata: [String: String]
}

func createSession(
    config: SessionConfiguration,
    completion: @escaping (Result<Session, Error>) -> Void
)
```

**Files to prioritize**:
- `DatabaseCore/MasterLedgerStore.swift`
- `ContextumModule/Database/ContextumDatabase.swift`
- API surface methods in `*Module/` packages

---

#### 3.2 Large Tuples (162 violations)
**Priority**: 🟡 High

**Refactoring Pattern**:
```swift
// ❌ Before
func getStats() -> (count: Int, resetAt: Date, isActive: Bool)

// ✅ After
struct Stats {
    let count: Int
    let resetAt: Date
    let isActive: Bool
}

func getStats() -> Stats
```

---

#### 3.3 Cyclomatic Complexity (173 violations)
**Priority**: 🟢 Medium

**Strategy**: Extract helper methods, use early returns

**Refactoring Pattern**:
```swift
// ❌ Before (complexity: 18)
func processEvent(_ event: Event) {
    if event.type == .userAction {
        if event.isValid {
            if event.hasPermission {
                // ... 20 more lines
            } else {
                // error handling
            }
        } else {
            // validation error
        }
    } else if event.type == .systemEvent {
        // ... another branch
    }
}

// ✅ After (complexity: 5)
func processEvent(_ event: Event) {
    switch event.type {
    case .userAction:
        processUserAction(event)
    case .systemEvent:
        processSystemEvent(event)
    }
}

private func processUserAction(_ event: Event) {
    guard event.isValid else {
        handleValidationError(event)
        return
    }
    
    guard event.hasPermission else {
        handlePermissionError(event)
        return
    }
    
    executeUserAction(event)
}
```

---

#### 3.4 File Length (354 violations)
**Priority**: 🟢 Medium

**Strategy**: Split large files by responsibility

**Candidates for splitting**:
```
AppStore.swift (1000+ lines)
  → AppStore+State.swift
  → AppStore+Actions.swift
  → AppStore+Reducers.swift

ContextumDatabase.swift (1441 lines)
  → ContextumDatabase+Queries.swift
  → ContextumDatabase+Mutations.swift
  → ContextumDatabase+Schema.swift
```

---

### Phase 4: Style & Formatting (Week 7-8)
**Goal**: Achieve consistent code style

#### 4.1 Multiline Function Chains (64 violations)
**Auto-fix**: Partial via `swiftformat`

```swift
// ❌ Before
let result = data.filter { $0.isValid }.map { $0.value }
    .compactMap { $0.id }

// ✅ After
let result = data
    .filter { $0.isValid }
    .map { $0.value }
    .compactMap { $0.id }
```

---

#### 4.2 Non-optional String→Data Conversion (37 violations)
**Priority**: 🟢 Low

```swift
// ❌ Before
let data = string.data(using: .utf8)!

// ✅ After
let data = Data(string.utf8)
```

---

## Implementation Workflow

### Step-by-Step Process

1. **Create a tracking branch**:
   ```bash
   git checkout -b swiftlint-remediation
   ```

2. **Run targeted fixes**:
   ```bash
   # Fix one rule at a time
   swiftlint --reporter json | \
     jq '.[] | select(.rule_id == "force_unwrapping")' | \
     jq -r '.file' | sort -u > force_unwrap_files.txt
   ```

3. **Batch refactor by module**:
   ```bash
   # Example: Fix all force unwraps in AnigmaCore
   for file in Packages/AnigmaCore/**/*.swift; do
     # Manual review and fix
     code "$file"
   done
   ```

4. **Verify after each batch**:
   ```bash
   swift build && swift test
   ./Scripts/ci/run-swiftlint.sh
   ```

5. **Commit incrementally**:
   ```bash
   git add Packages/AnigmaCore
   git commit -m "SwiftLint: Fix force unwrapping in AnigmaCore (15 files)"
   ```

---

## Automation Opportunities

### 1. SwiftFormat Integration
Install and configure `swiftformat` for auto-fixable style issues:

```bash
brew install swiftformat

# Create .swiftformat config
cat > .swiftformat << EOF
--swiftversion 5.9
--indent 4
--maxwidth 120
--wraparguments before-first
--wrapcollections before-first
EOF

# Run on codebase
swiftformat Sources/ Packages/
```

### 2. Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run SwiftLint on staged files
git diff --cached --name-only | grep ".swift$" | while read file; do
  swiftlint lint --path "$file" --quiet
  if [ $? -ne 0 ]; then
    echo "❌ SwiftLint failed for $file"
    exit 1
  fi
done
```

### 3. CI/CD Integration
Update `.github/workflows/ci.yml`:

```yaml
- name: SwiftLint
  run: |
    ./Scripts/ci/run-swiftlint.sh
    # Allow warnings, fail on errors only
    if [ $? -eq 2 ]; then
      exit 1
    fi
```

---

## Metrics & Tracking

### Weekly Progress Dashboard

| Week | Target Violations | Actual | % Reduction |
|------|------------------|--------|-------------|
| 0 (Baseline) | 36,158 | 36,158 | 0% |
| 1 (Config) | 3,000 | TBD | TBD |
| 2-3 (Critical) | 2,000 | TBD | TBD |
| 4-6 (Quality) | 1,000 | TBD | TBD |
| 7-8 (Style) | 500 | TBD | TBD |

### Success Criteria

- ✅ **Zero critical violations** (force unwrap, force cast)
- ✅ **<1,000 total violations** (97% reduction)
- ✅ **All new code passes SwiftLint** (CI enforcement)
- ✅ **No regressions** (build + test suite passes)

---

## Risk Mitigation

### Potential Issues

1. **Breaking Changes**: Refactoring may introduce bugs
   - **Mitigation**: Comprehensive test coverage, incremental commits

2. **Merge Conflicts**: Long-running branch diverges from main
   - **Mitigation**: Rebase frequently, coordinate with team

3. **Scope Creep**: Attempting too much at once
   - **Mitigation**: Strict phase boundaries, time-boxing

4. **Developer Fatigue**: Monotonous refactoring work
   - **Mitigation**: Rotate developers, celebrate milestones

---

## Recommended Execution

### Option A: Dedicated Sprint (Recommended)
- **Duration**: 2 weeks
- **Team**: 2 developers full-time
- **Focus**: Phases 1-3 only
- **Outcome**: 90% reduction in violations

### Option B: Background Work
- **Duration**: 8 weeks
- **Team**: 1 developer, 25% time allocation
- **Focus**: All phases, incremental
- **Outcome**: 95% reduction in violations

### Option C: Hybrid Approach
- **Week 1**: Dedicated sprint (Phases 1-2)
- **Weeks 2-8**: Background work (Phases 3-4)
- **Team**: 2 devs (week 1), 1 dev (weeks 2-8)
- **Outcome**: Best balance of speed and sustainability

---

## Next Actions

1. **Review this plan** with the team
2. **Choose execution option** (A, B, or C)
3. **Assign ownership** (who leads remediation?)
4. **Schedule kickoff** (when to start?)
5. **Create tracking ticket** in project management system
6. **Set up metrics dashboard** (weekly violation counts)

---

## Appendix: Quick Reference

### Most Common Fixes

```swift
// Force unwrap → Guard
let x = dict["key"]!
guard let x = dict["key"] else { throw Error.missingKey }

// Force cast → Guard
let view = subview as! MyView
guard let view = subview as? MyView else { return }

// IUO → Optional
var delegate: Delegate!
var delegate: Delegate?

// Large tuple → Struct
(Int, Date, Bool)
struct Stats { let count: Int; let date: Date; let active: Bool }

// Many params → Config object
func foo(a: A, b: B, c: C, d: D, e: E, f: F, g: G)
struct Config { let a: A; let b: B; ... }
func foo(config: Config)
```

### Useful Commands

```bash
# Count violations by rule
swiftlint --reporter json | jq -r '.[].rule_id' | sort | uniq -c | sort -rn

# Find files with most violations
swiftlint --reporter json | jq -r '.[].file' | sort | uniq -c | sort -rn | head -20

# Fix specific rule across codebase
swiftlint --fix --format --rule force_unwrapping

# Check single file
swiftlint lint --path Sources/AnigmaCore/World.swift
```

---

**Document Owner**: Development Team  
**Last Updated**: 2026-02-09  
**Next Review**: After first full P0 batch completion
