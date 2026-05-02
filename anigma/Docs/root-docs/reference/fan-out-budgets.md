# Fan-Out Budgets Implementation (td-93f670)

## Task Status

**Task ID:** td-93f670  
**Epic:** td-f9576a (Compilation Surface Reduction)  
**Date:** 2026-04-14  
**Status:** IN PROGRESS - Policy Framework Complete

## Policy Definition

### Fan-Out Budget Purpose

Fan-out (dependencies per module) directly impacts compilation surface:
- High fan-out = module depends on many others = complex compilation graph
- Complex compilation graph = longer builds, higher Signal 4 risk
- Budget enforcement = predictable compilation performance

### Fan-Out Budget Tiers

Based on SIGNAL4_VULNERABILITY_MATRIX.md vulnerability scoring:

| Module Tier | Max Fan-Out | Justification | Example Modules |
|-------------|-------------|---------------|--------------------|
| **V0 Bottleneck** | ≤ 6 | Active bottleneck; must be split | HarmoniaV2Surface → target: ≤ 6 |
| **V1 Severe** | ≤ 10 | Foundation or critical aggregator | AnigmaCore (4), CapsuleCore (2), RLMModule (20→target:10) |
| **V2 Elevated** | ≤ 15 | Standard feature or moderate aggregator | AnigmaEvents (1), DatabaseCore (2) |
| **V3 Watchlist** | ≤ 20 | Typical feature module | ContextumModule (17), AnigmaCLILocalInference (11) |
| **V4 Low Risk** | ≤ 25 | Low-impact module | Most other modules |

### How Budgets Work

1. **Metric:** Count direct dependencies in Package.swift `.target(name: ..., dependencies: [...])`
2. **Ceiling:** Module tier determines maximum allowed fan-out
3. **Escalation:** If a module would exceed budget, split or defer feature

**Example:**

```swift
// Current state (violates V0 budget of 6)
.target(
  name: "HarmoniaV2Surface",
  dependencies: [
    "HarmoniaV2Contracts", "ContextumModule", "RLMModule",
    "DatabaseCore", "GovernanceCore", "CapsuleCore", "TelemetryCore",
    "AnigmaEvents", "AnigmaCore"
  ]  // 9 dependencies - exceeds V0 budget of 6
)

// Target state (meets V0 budget of 6)
.target(
  name: "HarmoniaV2Surface",
  dependencies: [
    "HarmoniaV2Contracts",    // contracts layer
    "HarmoniaV2Implementation",  // internal composition
    "GovernanceCore",         // external contract
    "TelemetryCore",          // cross-cutting
    "DatabaseCore",           // data layer
    "CapsuleCore"             // execution
  ]  // 6 dependencies - meets budget
)
```

## Current Module Budget Status

### V0 Modules (Target: ≤ 6 fan-out)

| Module | Current Fan-Out | Budget | Status | Action |
|--------|-----------------|--------|--------|--------|
| HarmoniaV2Surface | 9 | 6 | ❌ EXCEEDS | Split into contracts + impl (td-f846b9) |

### V1 Modules (Target: ≤ 10 fan-out)

| Module | Current Fan-Out | Budget | Status | Action |
|--------|-----------------|--------|--------|--------|
| AnigmaCore | 4 | 10 | ✅ OK | Monitor |
| AnigmaDaemonCore | 41 | 10 | ❌ EXCEEDS | Major refactor needed (separate task) |
| AnigmaMCPModule | 18 | 10 | ❌ EXCEEDS | Split server/tool implementations |
| ContextumModule | 17 | 10 | ❌ EXCEEDS | Split ingestion/search/memory lanes |
| ContractsCore | 3 | 10 | ✅ OK | Monitor |
| HarmoniaCLI | 27 | 10 | ❌ EXCEEDS | Move shared CLI contracts out |
| HarmoniaModule | 34 | 10 | ❌ EXCEEDS | Continue surface shrink |
| RLMModule | 20 | 10 | ❌ EXCEEDS | Split runtime model from impl |

### V2 Modules (Target: ≤ 15 fan-out)

| Module | Current Fan-Out | Budget | Status | Action |
|--------|-----------------|--------|--------|--------|
| AnigmaCLILocalInference | 11 | 15 | ✅ OK | Monitor |
| DevelopumModule | 10 | 15 | ✅ OK | Monitor |
| (others) | ≤ 15 | 15 | ✅ OK | Standard review |

## Budget Enforcement Mechanism

### 1. Automated Detection

**Script:** `check_fanout_budgets.sh`

```bash
#!/bin/bash
# Check each module's dependencies against budget

rg 'name: "([^"]+)".*dependencies: \[([^\]]+)\]' --multiline \
  anigma/Package.swift | while read line; do
  module=$(echo "$line" | cut -d'"' -f2)
  deps=$(echo "$line" | sed 's/.*dependencies: \[//' | sed 's/\].*//' | \
         grep -o '"[^"]*"' | wc -l)
  tier=$(get_tier "$module")
  budget=$(get_budget "$tier")
  
  if [ "$deps" -gt "$budget" ]; then
    echo "❌ $module: $deps dependencies exceeds $tier budget of $budget"
  else
    echo "✅ $module: $deps dependencies (budget: $budget)"
  fi
done
```

### 2. TD Policy Enforcement

**Rule:** Any PR that increases a module's fan-out:
- Must justify why it's necessary
- Must update this budget tracking document
- V0/V1 modules automatically flagged for review

### 3. Architecture Review Gate

For modules approaching budget limits:
- Flag in code review if adding new dependencies
- Require architecture approval for V0 modules
- Mandatory split discussion if exceeding budget

## Enforcement Template for TD

**For each module exceeding budget:**

```
## {Module} Fan-Out Budget Violation

**Module:** {ModuleName}  
**Tier:** {V0|V1|V2|V3|V4}  
**Budget:** {MaxDeps}  
**Current:** {ActualDeps}  
**Exceeded By:** {ActualDeps - MaxDeps}

### Root Cause
[Why dependencies grew]

### Remediation Plan
1. [Action 1]
2. [Action 2]
3. [Action 3]

### Expected Result
- New fan-out: {TargetDeps}
- Meets budget: ✅/❌
```

## Action Plan by Priority

### Priority 1: V0 Modules (Immediate)

- [ ] **HarmoniaV2Surface** - Execute split per td-f846b9 (target: 6 deps)

### Priority 2: V1 Modules (Urgent)

- [ ] **AnigmaDaemonCore** (41 → target: 10) - Create separate task for major refactor
- [ ] **HarmoniaModule** (34 → target: 10) - Continue existing surface shrink
- [ ] **HarmoniaCLI** (27 → target: 10) - Move CLI contracts to separate module
- [ ] **RLMModule** (20 → target: 10) - Split model from implementations
- [ ] **AnigmaMCPModule** (18 → target: 10) - Isolate server/tool implementations
- [ ] **ContextumModule** (17 → target: 10) - Split lanes (ingestion/search/memory)

### Priority 3: V2 Modules (Monitor)

- All currently under 15 deps - no immediate action
- Add to quarterly review cycle

## Validation Evidence

### Before: Budget Violations

```
From SIGNAL4_VULNERABILITY_MATRIX.md:
- AnigmaDaemonCore: 41 (exceeds V1 budget of 10 by 31 deps)
- HarmoniaModule: 34 (exceeds V1 budget of 10 by 24 deps)
- HarmoniaCLI: 27 (exceeds V1 budget of 10 by 17 deps)
- RLMModule: 20 (exceeds V1 budget of 10 by 10 deps)
- ContextumModule: 17 (exceeds V1 budget of 10 by 7 deps)
- AnigmaMCPModule: 18 (exceeds V1 budget of 10 by 8 deps)
```

### After: Target State

After all priority tasks complete:
```
- HarmoniaV2Surface: ≤ 6 (V0) ✅ td-f846b9
- All V1 modules: ≤ 10 (V1) ✅ Multiple tasks
- All V2 modules: ≤ 15 (V2) ✅ Monitor only
```

## Artifacts Created

- This document: FAN_OUT_BUDGETS_ENFORCEMENT.md
- Enforcement template (above)
- Priority action plan (above)

## Artifacts Needed for Submission

- [ ] Automated detection script (check_fanout_budgets.sh)
- [ ] TD policy statement with enforcement rules
- [ ] Budget table updated with current status
- [ ] Links to child tasks for each violation
- [ ] Build validation after each budget-reducing refactor

## Next Steps

1. Create automated budget checking script
2. Document TD policy for budget enforcement
3. Create child tasks for Priority 2 modules
4. Validate anigma/Package.swift matches budget policy
5. Submit with complete enforcement artifacts

---

**Status:** IN PROGRESS - Policy Framework Complete  
**Evidence Level:** Policy defined, action plan complete, implementation pending  
**Blocker:** None - ready to execute  
**Validation Needed:** Build results after refactors
