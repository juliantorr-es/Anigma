---
title: "Task System: Implementation Phase Guide"
description: "What to do during the implementation phase of TD task development"
audience: ["developers", "contributors", "all"]
complexity: "intermediate"
estimated_time: "15min"
keywords: ["tasks", "td", "implementation", "phase", "coding", "development"]
status: "stable"
last_updated: "2026-04-16"
---

# Task System: Implementation Phase Guide

During the **Implementation Phase**, your job is to build what was designed, following the plan from the design phase.

## What Happens in Implementation Phase

1. **Execute the Plan** - Implement tasks in order
2. **Track Progress** - Use TD to keep work visible
3. **Verify Work** - Test and validate each task
4. **Communicate Status** - Log progress regularly
5. **Handle Blockers** - Escalate and coordinate when stuck

## Key Activities

### Implementation Tasks

**1. Task Execution**
- Follow the acceptance criteria from design
- Implement in phases as planned
- Create pull requests for code review
- Update documentation as you go

**2. Progress Tracking**
- Use `td log` to record daily progress
- Use `td start` when beginning a task
- Use heartbeat logging to show activity
- Mark tasks done when complete

**3. Quality Verification**
- Run tests to verify functionality
- Get code reviewed by teammates
- Ensure documentation is updated
- Check performance requirements

**4. Blocker Management**
- Identify blockers immediately
- Document in TD with `td log`
- Link to related tasks
- Escalate if needed

**5. Task Handoff**
- Use `td handoff` at end of work
- Document what was completed
- List remaining work
- Explain any decisions made

## Example Implementation Tasks

### Example 1: Implement API Changes

**Task**: `td-296849 "Implement URL API consistency refactor"`

**Implementation Flow**:
```
1. Create new URLPathResolver protocol
2. Implement first concrete resolver
3. Create unit tests (coverage > 85%)
4. Implement remaining resolvers
5. Integration testing
6. Update docs
7. Code review and merge
```

**Progress Logging**:
```bash
# Day 1: Start task and create protocol
td start td-296849
td log td-296849 "HEARTBEAT: Created URLPathResolver protocol and unit test scaffolds; next: implement first resolver"

# Day 2: First resolver done
td log td-296849 "HEARTBEAT: First resolver (FileURLPathResolver) complete with 92% tests passing; next: implement DatabaseURLPathResolver"

# Day 4: All resolvers done, testing integration
td log td-296849 "HEARTBEAT: All 5 resolvers implemented and unit tested (88% coverage); next: integration tests and doc updates"

# Day 6: Ready for review
td log td-296849 "Ready for code review; all tests passing, docs updated, see PR #1234"
```

**Task Completion**:
```bash
td handoff td-296849 \
  --done "Implemented URLPathResolver with 5 concrete implementations (FileURL, DatabaseURL, NetworkURL, MemoryURL, CacheURL). All unit tests pass (88% coverage). Updated docs and examples." \
  --remaining "Integration tests with production data scheduled for next task" \
  --decision "Used protocol-based design for extensibility; chose 5 implementations based on usage frequency from research phase" \
  --uncertain "Performance under high throughput not yet tested; may need optimization after integration testing"
```

### Example 2: Test Infrastructure Implementation

**Task**: `td-276544 "Implement modular test harness core"`

**Implementation Flow**:
```
1. Set up test runner scaffolding
2. Implement test discovery mechanism
3. Add assertion library integration
4. Create test execution engine
5. Write comprehensive test suite
6. Create documentation and examples
```

**Verification Points**:
```swift
// Test that test discovery works
func testDiscoveryFindsAllTests() {
    let runner = TestRunner()
    let tests = runner.discover()
    XCTAssertGreaterThan(tests.count, 0)
}

// Test that assertions work
func testAssertionResults() {
    let result = runAssertion(expected: true, actual: true)
    XCTAssertTrue(result.passed)
}
```

### Example 3: Schema Migration Implementation

**Task**: `td-265235 "Migrate data to new persistence layer"`

**Implementation Steps**:
```
1. Create migration tool with validation
2. Test with synthetic data (small set)
3. Test with staging data (realistic load)
4. Perform migration in controlled environment
5. Validate data integrity post-migration
6. Prepare rollback procedures
7. Monitor production migration (if applicable)
```

**Verification Checklist**:
```
- [ ] Migration tool handles 100% of data
- [ ] No data loss or corruption
- [ ] Schema validation passes
- [ ] Performance acceptable (< 2 hrs for full dataset)
- [ ] Rollback procedure tested and verified
- [ ] All error cases handled gracefully
- [ ] Operators trained on migration procedures
```

## How to Structure Implementation Work

### Daily Work Log Template

```bash
# Start of day
td start <task-id>

# Mid-day checkpoint (every 2-3 hours)
td log <task-id> "PROGRESS: [What completed], [What's next]"

# End of day
td log <task-id> "EOD: [Summary], [Blockers?], [Tomorrow: X]"

# Next day if still working
td log <task-id> "HEARTBEAT: Continuing from yesterday, next: [specific step]"
```

### Code Review Integration

When submitting for review:

```bash
td log <task-id> "Code ready for review: PR #1234. All tests pass, coverage >85%, docs updated. See PR for changes."
```

### Handling Blockers

If blocked:

```bash
td log <task-id> "BLOCKED: Waiting on td-XXXXX (dependency). Current blocker: [specific issue]. Est. resolution: [date/condition]"

# Then link to blocker
td block <task-id> <blocker-task-id>
```

## Implementation Patterns

### Pattern 1: Small, Frequent Tasks

✅ **Preferred**: Multiple 2-3 day tasks with clear handoffs
```
- Task 1: Implement feature X (3 days)
- Task 2: Test feature X (2 days)
- Task 3: Integrate with system (3 days)
```

❌ **Avoid**: Single 10-day task with ambiguous completion
```
- Task 1: Implement feature X including testing and integration (10 days)
```

### Pattern 2: Verification at Every Step

Each task should verify its work:

```bash
# After implementing
swift build   # Compiles?

# After unit testing
swift test TestModuleX   # Tests pass?

# After integration
./run_integration_tests.sh  # Integration works?

# After docs
./verify_docs.sh  # Docs build and render correctly?
```

### Pattern 3: Continuous Integration

Commit frequently to catch issues early:

```bash
git add <files>
git commit -m "feat: implement URLPathResolver protocol

- Created URLPathResolver protocol with 3 methods
- Implemented FileURLPathResolver
- Added 12 unit tests (coverage: 92%)

See td-296849"
```

## Linking to TD in Code

### Commit Messages

```
feat: implement URLPathResolver protocol

- Created URLPathResolver protocol with 3 methods
- Implemented FileURLPathResolver
- Added 12 unit tests (coverage: 92%)

Implements design from td-296848
See implementation task: td-296849
```

### Code Comments

Only comment when truly needed:

```swift
// URLPathResolver design: see td-296848
public protocol URLPathResolver {
    func resolve_url_path(from: String) throws -> URLPath
}
```

### Pull Request Description

```
## Implementation of td-296849

### Changes
- Created URLPathResolver protocol
- Implemented 5 concrete resolvers
- Added 88+ unit tests

### Verification
- [x] All tests pass (88% coverage)
- [x] Docs updated in Docs/concepts/url-handling.md
- [x] Examples added to Docs/examples/

See design: td-296848
See research: td-296847
```

## Progress Checkpoints

Use these checkpoints to track progress:

| Checkpoint | What to Verify | Command |
|------------|----------------|---------|
| Code Compiles | Build succeeds | `swift build` |
| Tests Pass | Unit tests passing | `swift test` |
| Coverage OK | Test coverage > 80% | `swift test --collect-coverage` |
| Integration Works | System still works | `run_integration_tests.sh` |
| Docs Updated | Documentation current | `./verify_docs.sh` |
| Code Reviewed | Approved by reviewer | Check PR status |
| Task Complete | Acceptance criteria met | All checkboxes pass |

## Finishing Implementation

When work is done:

```bash
# 1. Final verification
swift build
swift test

# 2. Log final status
td log <task-id> "COMPLETE: All tests passing (88% coverage), docs updated, ready for review. See PR #1234"

# 3. Request review or handoff
td handoff <task-id> \
  --done "[Detailed description of what was delivered]" \
  --remaining "[Any follow-up work needed]" \
  --decision "[Key implementation decisions]" \
  --uncertain "[Open questions or risks]"
```

## Anti-Patterns to Avoid

❌ **Don't ignore test failures** - Fix them immediately
❌ **Don't skip verification steps** - Test before handoff
❌ **Don't go dark** - Log progress daily
❌ **Don't commit directly to main** - Use pull requests and code review
❌ **Don't defer documentation** - Update docs as you code
❌ **Don't ignore performance regressions** - Verify performance targets

## Real Task Examples

### Current Implementation Tasks

| Task ID | Title | Epic | Design Task | Status |
|---------|-------|------|-------------|--------|
| td-296849 | Implement URL API refactor | Architecture | td-296848 | ✅ Done |
| td-276544 | Implement test harness core | Testing | td-276543 | 🟡 In Progress |

### Success Example

`td-296847` (Research) → `td-296848` (Design) → `td-296849` (Impl) ✅

Result: New URLPathResolver API implemented, all tests passing, docs updated.

---

## Related Guides

- [Task System Reference](../reference/task-system-reference.md) - Understand the full task system
- [Research Phase Guide](./task-system-research-phase.md) - What to do during research
- [Design Phase Guide](./task-system-design-phase.md) - What to do during design

---

See also:
- [Back to Development Guide](./README.md)
- [Back to Docs Home](../README.md)
