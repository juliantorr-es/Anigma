# Performance Guardrails Quick Reference

## Quick Start

### Run Guardrails
```bash
anigma/Scripts/run_performance_guardrails.sh .          # Default mode
anigma/Scripts/run_performance_guardrails.sh . strict   # CI/CD
```

### Record Metrics in Your Code
```swift
let guardrails = RegressionGuardrails(configuration: .default)

// Allocation tracking
guardrails.recordCapsuleAllocation(
    operationName: "my_operation",
    size: UInt64(dataSize)
)

// Batch efficiency
guardrails.recordBatchEfficiency(
    operationName: "my_operation",
    individualTime: ms1,
    batchTime: ms2,
    itemCount: count
)

// Cross-language calls
guardrails.recordCrossLanguageCallMetrics(
    operationName: "my_operation",
    callTypes: ["swift_to_c": 1, "c_to_swift": 1],
    durationMs: ms
)
```

## Guardrail Thresholds

### Default Mode
| Metric | Threshold | Severity |
|--------|-----------|----------|
| Allocation deviation | ≤15% | Warning |
| Max allocations/op | ≤3 | Warning |
| Batch speedup | ≥1.2x | Warning |
| FFI calls/op | ≤5 | Warning |
| Call frequency | ≤0.1 calls/ms | Warning |

### Strict Mode (CI/CD)
| Metric | Threshold | Severity |
|--------|-----------|----------|
| Allocation deviation | ≤5% | Failure |
| Max allocations/op | ≤1 | Failure |
| Batch speedup | ≥1.5x | Failure |
| FFI calls/op | ≤2 | Failure |
| Call frequency | ≤0.05 calls/ms | Failure |

## Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Speedup < 1.2x | Missing fusion | Profile hot path |
| Allocation count > 3 | Loop creating capsules | Use batch API |
| Call volume > 5 | O(n) FFI calls | Batch FFI calls |
| High variance | System contention | Run isolated |

## Configuration Modes

```swift
.default    // Development: 15% tolerance
.strict     // CI/CD: 5% tolerance, fail on breach
.relaxed    // Initial development: 30% tolerance
```

## Test Entry Points

- `PerformanceRegressionGuardrailsTests.swift` - 9 comprehensive tests
  - Allocation bounds
  - Batch efficiency
  - Cross-language call volume
  - Hot path fusion
  - Full workload integration

## Check Results

### Success
```
✓ Capsule allocation test passed: 1 allocations for 100 nodes
✓ Batch efficiency [100 items]: 2.34x speedup (min: 1.30x)
✓ Cross-language call volume test passed: 2 calls, 0.005 calls/ms
```

### Regression
```
✗ Batch operation did not meet efficiency requirement
  Speedup: 0.95x (expected min: 1.04x)
  Action: Profile operation, verify hot-path fusion is applied
```

## Integration with CI/CD

Add to GitHub Actions:
```yaml
- name: Performance guardrails
  run: anigma/Scripts/run_performance_guardrails.sh . strict
  if: github.event_name == 'pull_request'
```

## When to Use Each Mode

| Mode | When | Use Case |
|------|------|----------|
| default | Local development & testing | Daily work |
| strict | CI/CD, before merge | PR checks, regressions |
| relaxed | Initial development | Early prototyping |

## Key Files

| File | Purpose |
|------|---------|
| `RegressionGuardrails.swift` | Core framework (actors, types) |
| `PerformanceRegressionGuardrailsTests.swift` | Test suite |
| `run_performance_guardrails.sh` | CI/CD runner |
| `PERFORMANCE_GUARDRAILS_GUIDE.md` | Full documentation |

## Understanding Metrics

### Capsule Allocation
- **What**: Count of memory allocations per operation
- **Why**: Batch operations should allocate 1 final result, not N intermediate copies
- **Goal**: Keep allocations O(1) regardless of input size

### Batch Efficiency (Speedup)
- **What**: Ratio of individual time to batch time
- **Why**: Batching should reduce overhead
- **Goal**: ≥1.2x improvement over individual operations

### Cross-Language Call Volume
- **What**: Count of FFI transitions (Swift ↔ C/Objective-C)
- **Why**: FFI overhead is high; minimize boundary crossings
- **Goal**: Keep call count O(1), not O(n)

### Hot Path Fusion
- **What**: Intermediate allocations in performance-critical paths
- **Why**: Fused operations combine logic to eliminate allocations
- **Goal**: ≤2 intermediate allocations per fused operation

## Performance Baseline (M1 Mac)

| Operation | Size | Speedup |
|-----------|------|---------|
| addNodes | 10 | 1.45x |
| addNodes | 100 | 2.05x |
| getWorldTransforms | 100 | 2.18x |

*Note: Speedups vary by system. Use relative comparison, not absolute times.*

## Adding New Operations

1. Implement batch API
2. Add test to `PerformanceRegressionGuardrailsTests`
3. Verify speedup ≥1.2x (strict: ≥1.5x)
4. Measure and record baseline
5. Commit baseline to repo

## Documentation

- Full guide: `PERFORMANCE_GUARDRAILS_GUIDE.md`
- Architecture details in source files
- Example tests in `PerformanceRegressionGuardrailsTests.swift`

---

**Last updated**: 2025-02  
**Mode versions**: default, strict, relaxed
