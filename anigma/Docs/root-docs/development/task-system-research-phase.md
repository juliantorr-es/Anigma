---
title: "Task System: Research Phase Guide"
description: "What to do during the research phase of TD task development"
audience: ["developers", "contributors", "all"]
complexity: "intermediate"
estimated_time: "15min"
keywords: ["tasks", "td", "research", "phase", "discovery", "planning"]
status: "stable"
last_updated: "2026-04-16"
---

# Task System: Research Phase Guide

During the **Research Phase**, your job is to investigate, understand, and document the problem space before implementation begins.

## What Happens in Research Phase

1. **Define the Problem** - Understand what needs to be solved
2. **Gather Context** - Collect all relevant information
3. **Identify Constraints** - Find blockers, dependencies, and limitations
4. **Document Findings** - Create artifacts that guide implementation

## Key Activities

### Investigation Tasks

**1. Problem Decomposition**
- Break large problems into smaller, concrete pieces
- Identify sub-problems that can be solved independently
- Map dependencies between problems

**2. Context Gathering**
- Review related documentation
- Check existing implementations
- Understand current architecture and design
- Interview stakeholders if needed

**3. Constraint Identification**
- List technical constraints
- Document performance requirements
- Note compatibility requirements
- Identify timing dependencies

**4. Research Artifact Creation**
Research artifacts are **never** committed to code. They live in task descriptions and linked external documents:

- **Decision records** - Why a particular approach was chosen
- **Architecture sketches** - Design diagrams and flows
- **Feasibility assessments** - Can this be done? What's the cost?
- **Risk analysis** - What could go wrong?
- **Examples and references** - Links to similar work

## Example Research Tasks

### Example 1: API Governance Audit

**Task**: `td-296847 "Audit API surface for inconsistencies"`

**Research Activities**:
```
1. Scan all public types and functions across modules
2. Document naming patterns (camelCase vs snake_case)
3. Identify 10+ inconsistencies with examples
4. Classify by severity (breaking vs cosmetic)
5. Create fix priority matrix
```

**Output**: Decision record in TD task description:
```markdown
## Findings

### Naming Inconsistencies (8 found)
- URLParser vs url_parser (2 instances)
- HTTPClient vs http_client (3 instances)

### Severity Classification
- Breaking: Would require major refactor (5)
- Non-breaking: Simple rename (3)

### Recommendation
Fix non-breaking first in Phase 1
```

### Example 2: Dependency Analysis

**Task**: `td-256789 "Analyze HarmoniaModule fan-in/fan-out"`

**Research Activities**:
```
1. Map all dependencies TO HarmoniaModule
2. Map all dependencies FROM HarmoniaModule
3. Identify circular dependencies
4. Calculate coupling metrics
5. Rank by impact for refactoring
```

**Output**: Dependency matrix in decision record:
```
Dependencies FROM HarmoniaModule (19 current, target: <15)
- ToType1: 8 references (reducible to 2)
- ToType2: 5 references (core, keep)
- ToType3: 3 references (unused, remove)
- ToType4: 3 references (core, keep)
```

### Example 3: Test Coverage Analysis

**Task**: `td-245892 "Assess test coverage for runtime contracts"`

**Research Activities**:
```
1. Measure current test coverage
2. Identify high-risk code paths (untested)
3. Document test capability gaps
4. Prioritize what needs testing
5. Estimate testing effort
```

**Output**: Coverage matrix in decision record:
```
Current Coverage: 42%
Critical Untested Paths:
- Contract violation handling (4 paths)
- Resource cleanup (2 paths)
- Error recovery (3 paths)

Estimated effort: 20 days to reach 85%
```

## How to Structure Research

### Research Plan Template

```markdown
## Research Task: [Title]

### Problem Statement
What are we trying to understand?

### Key Questions
1. How does X currently work?
2. What are the constraints on Y?
3. What examples exist for Z?

### Investigation Approach
1. [Specific step 1]
2. [Specific step 2]
3. [Specific step 3]

### Success Criteria
- [ ] Question 1 answered with evidence
- [ ] Question 2 answered with examples
- [ ] Question 3 answered with recommendations

### Decision Record
(Filled in as findings emerge)

### Blockers for Implementation Phase
- Are there unknowns preventing implementation?
- What needs to be resolved first?
```

## Linking to TD

When creating research tasks, include:

**In Task Description**:
- Link to related epic: `See epic: td-333894`
- Link to design phase: `Design phase: td-256789`
- Acceptance criteria with concrete outputs

**In Research Artifacts**:
- Cross-reference back to TD: "See td-245892 for complete analysis"
- Include task ID in all decision records
- Link examples to original code

## Transitioning to Design Phase

Research is done when:

1. ✅ All key questions answered
2. ✅ Constraints documented
3. ✅ Trade-offs understood
4. ✅ Implementation blockers identified

**Mark task as Ready for Design**:
```bash
td log <task-id> "READY FOR DESIGN: All research complete, dependencies identified, see decision record"
```

This signals implementation phase can begin.

## Anti-Patterns to Avoid

❌ **Don't code during research** - Keep research separate from implementation
❌ **Don't make permanent decisions** - Keep options open
❌ **Don't create partial artifacts** - Complete findings before handoff
❌ **Don't skip constraint identification** - Surprises during implementation are expensive
❌ **Don't research in isolation** - Share findings, get feedback

## Real Task Examples

### Current Research Tasks

| Task ID | Title | Epic | Status |
|---------|-------|------|--------|
| td-296847 | Audit API surface for inconsistencies | Architecture | ✅ Done |
| td-245892 | Assess test coverage gaps | Testing | 🟡 In Progress |
| td-256789 | Analyze HarmoniaModule dependencies | Harmonia Migration | ✅ Done |

### How They Linked to Implementation

Example: `td-296847` (Research) → `td-296848` (Design) → `td-296849` (Implementation)

Each task links backward/forward to show the progression.

---

## Related Guides

- [Task System Reference](../reference/task-system-reference.md) - Understand the full task system
- [Design Phase Guide](./task-system-design-phase.md) - What to do during design
- [Implementation Phase Guide](./task-system-implementation-phase.md) - What to do during implementation

---

See also:
- [Back to Development Guide](./README.md)
- [Back to Docs Home](../README.md)
