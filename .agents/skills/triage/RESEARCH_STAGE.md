# Research Stage - Agent Task Workflow

**Document ID:** RESEARCH-STAGE-2026-001  
**Version:** 1.0  
**Status:** ACTIVE  
**Last Updated:** 2026-05-01  
**Owner:** Anigma Architecture Team  

---

## 📋 Executive Summary

This document defines a **mandatory Research & Analysis stage** that agents MUST complete before implementing any task from the TD tracker. This stage ensures agents gather all necessary context, identify all affected components, and verify feasibility before writing any code.

**Purpose:** Eliminate rework, prevent missed edge cases, ensure doctrine compliance, and provide complete context for implementation.

**Rule:** No agent may begin implementation without first completing and documenting the Research stage.

---

## 🔬 Research Stage Overview

### When It Happens
- **After:** `td start <id>` (task claimed)
- **Before:** Any code implementation
- **Duration:** Should not exceed 25% of estimated task time

### What It Produces
- Comprehensive research summary documenting all affected components
- Verification that all dependencies are available
- Confirmation of architecture/doctrine compliance
- Risk assessment and mitigation plan

### Where It's Documented
- Posted as the **first** `td log` entry for the task
- Format: Markdown with clear structure
- Template: See [Research Template](#-research-template) below

---

## 🎯 Why Research Stage Exists

### Problems It Solves

| Problem | Solution |
|---------|----------|
| Multiple passes over codebase | Single, thorough research pass |
| Discovering issues mid-implementation | Identify all issues upfront |
| Incomplete understanding of scope | Full context before coding |
| Missing dependencies | Verify all requirements early |
| Doctrine violations | Check compliance before implementation |
| Gold-plating / out-of-scope work | Explicit scope boundaries documented |
| Forgotten edge cases | All edge cases identified in research |

### Benefits

1. **Reduced Rework**: 60-80% reduction in "oops, I missed something" iterations
2. **Faster Implementation**: No context-switching back to research during coding
3. **Higher Quality**: All edge cases and constraints known upfront
4. **Better Estimates**: Full scope understood before work begins
5. **Doctrine Compliance**: Architecture rules verified early
6. **Resumable Work**: Research summary allows another agent to pick up where left off

---

## 📝 Research Template

Copy and complete this template for every task. Post as first `td log` entry.

```markdown
## Research Complete for <task-id>

**Category:** enhancement / bug / refactor  
**Task:** [One-line summary from Agent Brief]  
**Research Date:** [YYYY-MM-DD]  
**Research Duration:** [X minutes/hours]  

---

### ✅ Affected Components Analysis

#### Variables & Constants
| Name | Location | Current Value/Type | Required Change | Impact |
|------|----------|-------------------|-----------------|--------|
| `varName` | `Module/File.swift` | `Type = value` | Description | High/Medium/Low |

#### Methods & Functions
| Name | Signature | Location | Change Type | Impact |
|------|-----------|----------|-------------|--------|
| `funcName()` | `(Params) -> Return` | `Module/File.swift` | Add/Modify/Remove | High/Medium/Low |

#### Types & Protocols
| Name | Kind | Location | Change | Impact |
|------|------|----------|--------|--------|
| `TypeName` | Protocol/Struct/Enum/Class | `Module/File.swift` | New/Modified | High/Medium/Low |

#### Libraries & Packages
| Package | Current Version | Required Version | Purpose | Impact |
|---------|-----------------|------------------|---------|--------|
| `PackageName` | `x.y.z` | `a.b.c` | Description | High/Medium/Low |

#### Modules
- `ModuleA` - Primary changes
- `ModuleB` - Secondary changes (tests, integration)
- `ModuleC` - Dependencies

#### Cores/Subsystems
- `CoreName` - Description of impact
- `SubsystemName` - Description of impact

---

### 🔗 Dependencies & Blockers

**This Task Depends On:**
- ✅ `td-xxxxx` - [Description] - Status: COMPLETE
- ⏳ `td-yyyyy` - [Description] - Status: IN_PROGRESS
- ❌ `td-zzzzz` - [Description] - Status: NOT STARTED (BLOCKER)

**This Task Blocks:**
- `td-aaaaa` - [Description]
- `td-bbbbb` - [Description]

**Required Infrastructure:**
- `SubprocessManager` (from td-a84da2) - ✅ Available
- `UnifiedMemoryPool` (from Phase 1) - ✅ Available

---

### 🏗️ Architecture & Doctrine Compliance

**Tier Analysis:**
- [ ] Task primarily affects Tier 1 (Contracts) - portable types only
- [ ] Task primarily affects Tier 2 (Authorities/Registries) - may use platform types internally
- [ ] Task primarily affects Tier 3 (Backend Executors) - may import platform frameworks
- [ ] Cross-tier changes - verify no Tier 1 platform imports

**Doctrine Compliance Checklist:**
- [ ] No platform framework imports in Tier 1
- [ ] All platform-specific code in Tier 3
- [ ] Proper receipts emitted for significant operations
- [ ] `Sendable` conformance where required
- [ ] Contract-based interfaces, not file-path-based
- [ ] Backward compatible changes (or migration plan)

**Portability:**
- [ ] Linux equivalents noted (if applicable)
- [ ] Windows equivalents noted (if applicable)
- [ ] Fallback behavior explicit

---

### ⚠️ Risks & Considerations

1. **Risk:** [Description] - **Mitigation:** [Plan] - **Likelihood:** High/Medium/Low
2. **Risk:** [Description] - **Mitigation:** [Plan] - **Likelihood:** High/Medium/Low

**Performance Impact:**
- [ ] No performance impact expected
- [ ] Performance improvement expected: [Description]
- [ ] Performance degradation possible: [Description] - **Mitigation:** [Plan]

**Breaking Changes:**
- [ ] No breaking changes
- [ ] Breaking changes identified: [List] - **Migration Plan:** [Description]

---

### 🧪 Test Strategy

**Existing Tests to Update:**
- `TestFile.swift` - Test X needs update for new behavior
- `IntegrationTests.swift` - New test cases needed

**New Tests Required:**
- [ ] Unit tests for new functionality
- [ ] Integration tests for new interactions
- [ ] Performance tests (if applicable)
- [ ] Doctrine compliance tests

**Test Coverage Target:** [X]% (default: 95%+)

---

### ✅ Research Verification

**Checklist:**
- [ ] All acceptance criteria from Agent Brief understood
- [ ] All key interfaces identified and located
- [ ] All dependencies confirmed as available (or blockers noted)
- [ ] No architecture/doctrine violations identified
- [ ] Scope boundaries clear (see Agent Brief "Out of scope")
- [ ] All edge cases identified
- [ ] Risk assessment complete
- [ ] Test strategy defined

**Research Status:** ✅ COMPLETE / ⚠️ BLOCKED / ❌ CANNOT PROCEED

**Next Step:** Implementation / Waiting on dependencies / Needs clarification

---

**Research completed by:** [Agent Session ID]  
**Research approved:** [Maintainer confirmation if needed]
```

---

## 🎓 Research Guidelines

### What to Research

#### 1. **Codebase Structure**
- Locate all files that import or use the types mentioned in "Key interfaces"
- Identify all call sites of functions that need modification
- Find all implementations of protocols that need conformance
- Map the dependency graph for affected modules

#### 2. **Current State**
- Read the existing implementation of all affected components
- Understand the current data flow
- Identify existing tests and their coverage
- Check for similar patterns already in the codebase

#### 3. **Architecture**
- Verify tier placement (Tier 1, 2, or 3)
- Check for platform-specific code in wrong tiers
- Identify required receipts and proofs
- Verify contract compliance

#### 4. **Dependencies**
- Check if required packages are in Package.swift
- Verify version requirements
- Identify any circular dependencies
- Check for conflicting requirements

#### 5. **Tests**
- Identify existing tests that will break
- Find test patterns to follow
- Identify gaps in test coverage
- Locate test utilities that can be reused

### What NOT to Do in Research
- ❌ Don't write any implementation code
- ❌ Don't modify any files
- ❌ Don't skip the research summary
- ❌ Don't proceed without understanding all acceptance criteria
- ❌ Don't ignore doctrine compliance checks

---

## 📊 Research Quality Checklist

Before marking research as complete:

1. **Completeness**
   - [ ] All categories filled (Variables, Methods, Types, Libraries, Modules, Cores)
   - [ ] No "TBD" or "TODO" items remaining
   - [ ] All acceptance criteria addressed

2. **Accuracy**
   - [ ] All file locations verified to exist
   - [ ] All type names match actual codebase
   - [ ] All dependencies confirmed

3. **Clarity**
   - [ ] Research summary is readable and well-structured
   - [ ] Technical terms are used correctly
   - [ ] Impact assessments are justified

4. **Actionability**
   - [ ] Implementation can proceed directly from research
   - [ ] No additional research needed during implementation
   - [ ] All blockers clearly identified

---

## 🔄 Integration with Existing Workflow

### Full Workflow with Research Stage

```
┌─────────────────────────────────────────────────────────┐
│                    TD TASK LIFECYCLE                      │
├─────────────────────────────────────────────────────────┤
│                                                              │
│  0. DISCOVERY                                        1. RESEARCH  │
│     ┌─────────────────┐                              ┌─────────────┐│
│     │ Find task       │──────────────────────────►│ Research    ││
│     │ td list         │                              │ codebase   ││
│     └─────────────────┘                              │ document    ││
│                                                   └─────────────┘│
│                                                          │         │
│                                                          ▼         │
│  2. IMPLEMENTATION                                       3. HANDOFF  │
│     ┌─────────────────┐                              ┌─────────────┐│
│     │ Write code      │◄──────────────────────────│ td handoff ││
│     │ Based on        │                              │ (REQUIRED)  ││
│     │ research        │                              └─────────────┘│
│     └─────────────────┘                                        │         │
│                          │                                         │         │
│                          ▼                                         ▼         │
│  4. REVIEW                    5. APPROVAL                         │
│     ┌─────────────────┐              ┌─────────────────────┐      │
│     │ td review       │──────────────│ td approve          │      │
│     │ Submit for      │              │ (different session) │      │
│     │ review          │              └─────────────────────┘      │
│     └─────────────────┘                                        │
│                                                              │
└─────────────────────────────────────────────────────────┘
```

### TD Commands with Research

```bash
# 0. Find and claim task
 td next                    # See highest priority task
 td start <id>              # Claim the task

# 1. RESEARCH STAGE (NEW - REQUIRED)
 td log """
## Research Complete for <id>

[Research summary here - use template above]
"""

# 2. Implementation
# ... write code based on research ...
 td log "Implementation: 50% complete - X done"

# 3. Handoff (REQUIRED before stopping)
 td handoff <id> -d "Done: X, Y, Z" -r "Remaining: A, B" -u "Uncertain: C"

# 4. Review
 td review <id>

# 5. Approval (different session)
 td approve <id>
```

---

## 📚 Related Documents

- [Agent Brief Template](AGENT-BRIEF.md) - How to write task specifications
- [Triage Skill](SKILL.md) - Full triage workflow
- [TD Usage](https://github.com/Anigma/td) - TD CLI commands
- [Platform Backend Portability Doctrine](../../Docs/architecture/PLATFORM_BACKEND_PORTABILITY_DOCTRINE.md)
- [Constructive Doctrine Style Guide](../../Docs/architecture/CONSTRUCTIVE_DOCTRINE_STYLE_GUIDE.md)

---

## 🎯 Success Metrics

Tracking the impact of the Research stage:

| Metric | Target | Measurement |
|--------|--------|-------------|
| Rework rate | < 5% | Tasks requiring second pass |
| Research duration | < 25% of total | Time spent in research vs implementation |
| Doctrine violations | 0 | Post-implementation audits |
| Acceptance criteria pass rate | 100% | First review pass rate |
| Agent confidence | High | Agent feedback surveys |

---

## ✅ Approval

**Status:** ACTIVE  
**Effective Date:** 2026-05-01  
**Next Review:** 2026-06-01  

**Approvers:**
- Architecture Lead: _______________  Date: _________
- Engineering Manager: _____________  Date: _________

---

*This document is part of the Anigma triage skills. For questions or updates, see the triage skill documentation.*
