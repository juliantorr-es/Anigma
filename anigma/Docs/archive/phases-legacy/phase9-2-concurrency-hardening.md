# Phase 9.2 Concurrency Hardening Plan

## Overview

Phase 9.2 hardens the Phase 9.1 system for concurrent, multi-threaded execution. This ensures that determinism guarantees hold under parallel enumeration, scoring, and candidate generation.

## Goals

1. **Actor isolation**: All shared state protected by actor isolation
2. **Deterministic ordering**: Concurrent results merge deterministically
3. **Work stealing safety**: Parallel tasks maintain stage isolation
4. **Stress tested**: Concurrency under load validated in CI

## Key Components

### 1. Concurrent Target Enumeration

```swift
public actor ConcurrentTargetEnumerator: Sendable {
    /// Enumerate targets with concurrent processing of components.
    /// Results are deterministically merged by targetId.
    public func enumerateParallel(
        from irStore: IRStore,
        scope: String,
        concurrencyLevel: Int
    ) async throws -> [EnumeratedTarget]
}
```

Implementation details:
- Partition components by scope
- Evaluate each partition in parallel task groups
- Merge results with deterministic ordering (targetId sort)
- Ensure final ranking is identical to sequential version

### 2. Parallel Scoring Pipeline

```swift
public actor ParallelScoringPipeline: Sendable {
    /// Score targets in parallel, maintaining deterministic ordering.
    public func scoreTargets(
        _ targets: [EnumeratedTarget],
        policy: ScoringPolicy,
        concurrencyLevel: Int
    ) async throws -> [EnumeratedTarget]
}
```

Implementation details:
- Batch targets for parallel scoring
- Use actor-isolated scoring function
- Sort results deterministically after parallel evaluation
- Ensure scores are identical to sequential scoring

### 3. Per-Target Work Isolation

```swift
public actor PerTargetWorkActor: Sendable {
    /// Isolated work context for a single target.
    /// Prevents cross-target state pollution.
    public func executeForTarget(
        _ targetId: String,
        _ work: (TargetWorkContext) async throws -> Void
    ) async throws
}
```

Implementation details:
- Create actor per target for candidate generation
- Prevent target-to-target communication
- Enforce single-commit per target
- Isolate validation results

### 4. Deterministic Merge Strategy

```swift
public struct DeterministicMerge {
    /// Merge concurrent results into canonical order.
    /// Key invariant: result is identical regardless of execution order.
    public static func merge<T: Comparable>(
        _ results: [[T]]
    ) -> [T]
}
```

Implementation details:
- Flatten all concurrent results
- Sort by deterministic key (targetId for targets)
- Remove duplicates using stable comparison
- Verify result matches sequential version

## Concurrency Safety Guarantees

### Invariants Preserved

1. **Stage 0 determinism**: Enumeration order identical in parallel and sequential
2. **Single-commit per run**: Enforced across all parallel tasks
3. **Evidence chain integrity**: Evidence digests unchanged under concurrency
4. **Scoring consistency**: Scores identical across concurrent and sequential runs

### Guarantees Under Stress

- **Race condition safety**: No data races under contention
- **Deadlock freedom**: No circular dependencies between actors
- **Work fairness**: All tasks eventually complete
- **Result determinism**: Output identical across execution orders

## Testing Strategy

### Unit Tests

```swift
// Concurrency isolation tests
func testActorIsolationPerTarget()       // Per-target work isolation
func testConcurrentEnumeration()          // Parallel enumeration correctness
func testParallelScoringConsistency()    // Parallel vs sequential scoring
func testDeterministicMerge()             // Merge produces canonical order

// Stress tests
func testHighConcurrencyEnumeration()     // 100+ concurrent tasks
func testResourceExhaustion()             // System under memory pressure
func testTaskCancellation()               // Graceful cancellation handling
```

### Concurrency Fixtures

```swift
// Reproducible parallel execution scenarios
ConcurrencyFixture {
    // Run enumeration with varying concurrency levels
    for level in [1, 2, 4, 8, 16] {
        let result1 = try await enumerate(concurrency: level)
        let result2 = try await enumerate(concurrency: level)
        assert(result1 == result2)  // Deterministic despite concurrency
    }
}
```

### CI Integration

```bash
# Run all tests with thread sanitizer enabled
swift test --target HarmoniaModuleTests -Xswiftc -sanitize=thread

# Run concurrency stress tests
swift test --target HarmoniaModuleTests --filter Phase9ConcurrencyTests
```

## Implementation Timeline

### Week 1: Core Infrastructure
- [ ] Implement ConcurrentTargetEnumerator
- [ ] Add parallel scoring pipeline
- [ ] Create per-target work actor
- [ ] Implement deterministic merge

### Week 2: Testing & Validation
- [ ] Unit tests for all components
- [ ] Concurrency fixtures
- [ ] Stress tests under load
- [ ] Thread sanitizer validation

### Week 3: CI Integration & Documentation
- [ ] Update CI for concurrency testing
- [ ] Document concurrency guarantees
- [ ] Write migration guide
- [ ] Performance benchmarking

## Risk Mitigation

### Deadlock Prevention
- No nested actor acquisition (enforce via type system)
- All actor calls are non-blocking
- Timeout guards on long-running tasks

### Race Condition Prevention
- All shared state behind actors
- No unsafe mutability escapes
- Comprehensive thread sanitizer runs

### Determinism Under Concurrency
- Explicit merge ordering rules
- Canonical sorting after parallel evaluation
- Deterministic merge test fixtures

## Performance Expectations

### Improvements
- **Enumeration**: 4-8x speedup with 8 concurrent tasks
- **Scoring**: 2-4x speedup with parallel evaluation
- **Candidate generation**: Proportional to target count and concurrency level

### Overhead
- Actor messaging overhead: <1% for typical task count
- Merge cost: O(n log n) for n targets
- Evidence collection: Negligible impact

## Backwards Compatibility

- Sequential execution still supported (concurrencyLevel=1)
- Results identical between sequential and concurrent
- No API breaking changes

## Future Enhancements (Phase 9.3+)

1. **Dynamic concurrency tuning**: Adjust task count based on system resources
2. **Adaptive work stealing**: Balance load across available cores
3. **Caching optimizations**: Reuse scored targets across enumeration runs
4. **Distributed execution**: Multi-machine deterministic enumeration

## Conclusion

Phase 9.2 hardens Phase 9.1 for safe, deterministic concurrent execution. The actor-isolated architecture ensures that parallelism preserves all determinism guarantees while providing significant performance improvements.