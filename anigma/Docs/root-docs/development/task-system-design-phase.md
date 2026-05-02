---
title: "Task System: Design Phase Guide"
description: "What to do during the design phase of TD task development"
audience: ["developers", "contributors", "all"]
complexity: "intermediate"
estimated_time: "15min"
keywords: ["tasks", "td", "design", "phase", "planning", "architecture"]
status: "stable"
last_updated: "2026-04-16"
---

# Task System: Design Phase Guide

During the **Design Phase**, your job is to create a detailed plan for implementation based on research findings.

## What Happens in Design Phase

1. **Choose an Approach** - Select the implementation strategy
2. **Create Design Specification** - Define what will be built
3. **Break Down Into Steps** - Create implementation tasks
4. **Document Trade-offs** - Explain why this design was chosen
5. **Identify Risks** - Surface potential problems before implementation

## Key Activities

### Design Tasks

**1. Approach Selection**
- Review research findings and constraints
- Compare candidate approaches
- Evaluate trade-offs (speed, maintainability, performance)
- Document the chosen approach and why

**2. Specification Creation**
- Write detailed design specification
- Create architecture diagrams
- Define interfaces and contracts
- Document error handling strategy

**3. Task Decomposition**
- Break design into implementation tasks
- Estimate effort for each task
- Identify task dependencies
- Plan parallel work streams

**4. Risk Documentation**
- Identify technical risks
- Plan mitigation strategies
- Document fallback approaches
- Note assumptions that need verification

## Example Design Tasks

### Example 1: API Redesign

**Task**: `td-296848 "Design new API consistency standard"`

**Design Activities**:
```
1. Review audit findings from research phase
2. Define naming conventions
3. Create type hierarchy
4. Write API design guide
5. Create example implementations
6. Plan migration strategy for breaking changes
```

**Output**: Design specification in TD task description:
```markdown
## Design: Consistent URL Handling API

### Chosen Approach
Standardize on snake_case for system APIs (following Swift naming conventions)

### API Contract
```swift
public protocol URLPathResolver {
    func resolve_url_path(from: String) throws -> URLPath
    func normalize_url_parameters(params: [String: String]) -> [String: String]
}
```

### Migration Plan
- Phase 1: Introduce new APIs alongside old ones
- Phase 2: Deprecate old APIs with warnings
- Phase 3: Remove old APIs in next major version

### Implementation Tasks
1. Create URLPathResolver protocol (3 days)
2. Implement 5 concrete resolvers (8 days)
3. Write integration tests (4 days)
4. Update docs (2 days)
```

### Example 2: Architecture Redesign

**Task**: `td-276543 "Design modular test infrastructure"`

**Design Activities**:
```
1. Document current test architecture pain points
2. Survey existing test frameworks
3. Design modular test approach
4. Create test harness specification
5. Plan phased implementation
```

**Output**: Architecture diagram and specification:
```
## Design: Modular Test Infrastructure

### Components
- TestCore: Basic test runner interface
- TestPlugins: Plugin system for custom assertions
- TestOrchestration: Multi-suite coordination
- TestReporting: Standardized reporting

### Phased Implementation
1. Core test runner (Phase 1)
2. Plugin system (Phase 2)
3. Orchestration layer (Phase 3)
```

### Example 3: Data Model Update

**Task**: `td-265234 "Design persistence layer refactor"`

**Design Activities**:
```
1. Review current data model schema
2. Analyze query performance bottlenecks
3. Design optimized schema
4. Create migration strategy
5. Plan backwards compatibility
```

**Output**: Database design specification:
```sql
-- New schema design
CREATE TABLE documents_v2 (
    id INTEGER PRIMARY KEY,
    content BLOB,
    metadata JSON,
    version INTEGER
);

-- Migration plan:
-- 1. Create v2 tables in parallel
-- 2. Copy data with transformation
-- 3. Update code to use v2
-- 4. Drop v1 after validation
```

## How to Structure Design

### Design Specification Template

```markdown
## Design: [Title]

### Problem Statement
What problem does this design solve?

### Constraints
- Timing: Must ship by [date]
- Compatibility: Must support [versions]
- Performance: Must handle [load]
- Technical: Must use [technology]

### Design Approach

#### Option A: [Approach Name]
**Pros**: 
- Benefit 1
- Benefit 2

**Cons**:
- Drawback 1
- Drawback 2

**Estimate**: [X] days

#### Option B: [Alternative Approach]
...

### Chosen Approach: [Selected Option]
**Rationale**: Why this approach balances the constraints

### Implementation Plan

#### Phase 1: Foundation
- [ ] Task 1: [Description] (Est: X days)
- [ ] Task 2: [Description] (Est: Y days)

#### Phase 2: Integration
- [ ] Task 3: [Description] (Est: Z days)
- [ ] Task 4: [Description] (Est: W days)

### Success Criteria
- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2
- [ ] Acceptance criterion 3

### Risk Mitigation
- Risk 1: [Potential issue] → Mitigation: [Strategy]
- Risk 2: [Potential issue] → Mitigation: [Strategy]

### Open Questions
- Question 1: [Needs clarification before implementation]
- Question 2: [Blocked on dependency X]
```

## Creating Implementation Tasks

Once design is approved, create implementation tasks:

**Task Format**:
```markdown
## Implementation: [Specific Component]

**Design Task**: td-296848

**Description**:
1. What this task delivers
2. How it relates to the design
3. Acceptance criteria (testable)

**Acceptance Criteria**:
- [ ] Functional requirement 1 works
- [ ] Code reviewed and approved
- [ ] Tests pass (coverage > 80%)
- [ ] Documentation updated
```

## Linking to TD

When creating design tasks:

**In Task Description**:
- Link to research task: `Research phase: td-296847`
- Link to epic: `See epic: td-333894`
- Include implementation tasks as children

**In Design Artifacts**:
- Reference decision record: "See td-296848 for design rationale"
- Link to architecture docs
- Include diagrams in task description

## Transitioning to Implementation Phase

Design is done when:

1. ✅ Approach clearly documented
2. ✅ Trade-offs documented
3. ✅ Implementation tasks created
4. ✅ Risk mitigation planned
5. ✅ All stakeholders aligned

**Mark task as Ready for Implementation**:
```bash
td log <task-id> "READY FOR IMPLEMENTATION: Design approved, all implementation tasks created, see design spec"
```

## Anti-Patterns to Avoid

❌ **Don't start coding yet** - Complete design review first
❌ **Don't over-design** - Keep it simple enough to iterate
❌ **Don't ignore trade-offs** - Document why you didn't choose other approaches
❌ **Don't create huge tasks** - Break into reasonable chunks (3-7 days max)
❌ **Don't assume implementation is obvious** - Write detailed specs

## Design Review Checklist

Before marking design complete, verify:

- [ ] Problem clearly stated
- [ ] Constraints documented
- [ ] All viable approaches evaluated
- [ ] Trade-offs documented
- [ ] Chosen approach justified
- [ ] Implementation tasks created
- [ ] Effort estimates reasonable
- [ ] Dependencies identified
- [ ] Risks identified with mitigations
- [ ] Stakeholders aligned

## Real Task Examples

### Current Design Tasks

| Task ID | Title | Epic | Linked Research | Status |
|---------|-------|------|-----------------|--------|
| td-296848 | Design API consistency standard | Architecture | td-296847 | ✅ Done |
| td-276543 | Design modular test infrastructure | Testing | td-245892 | 🟡 In Review |

### Progression Example

`td-245892` (Research: Test Coverage) → `td-276543` (Design) → `td-276544` (Impl)

Each task links backward to show progression.

---

## Related Guides

- [Task System Reference](../reference/task-system-reference.md) - Understand the full task system
- [Research Phase Guide](./task-system-research-phase.md) - What to do during research
- [Implementation Phase Guide](./task-system-implementation-phase.md) - What to do during implementation

---

See also:
- [Back to Development Guide](./README.md)
- [Back to Docs Home](../README.md)
