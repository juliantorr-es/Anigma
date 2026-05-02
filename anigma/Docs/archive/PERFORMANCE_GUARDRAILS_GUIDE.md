# Performance Regression Guardrails

## Overview

This system provides **lightweight, reproducible performance guardrails** for Anigma's capsule-based architecture, protecting critical hot paths and batching patterns against regressions.

### What It Tracks

| Category | Purpose | Threshold (Default) | What Triggers |
|----------|---------|---------------------|---------------|
| **Capsule Allocation** | Bounds intermediate data structures | ≤3 allocations/op | New allocations in loop |
| **Batch Efficiency** | Ensures batch ops maintain speedup | ≥1.2x faster | Individual vs batch slowdown |
| **Cross-Language Calls** | Prevents FFI call storms | ≤5 calls/op | O(n) FFI scaling |
| **Hot Path Fusion** | Detects allocation bloat in hot paths | ≤2 intermediate allocs | Missing fusion optimization |

---

## Architecture

### Components

```
RegressionGuardrails (Main Manager)
├── CapsuleAllocationTracker (Actor)
│   ├── Tracks capsule allocations per operation
│   ├── Records cross-language calls
│   └── Computes allocation statistics
├── BatchEfficiencyMonitor (Actor)
│   ├── Measures individual vs batch times
│   ├── Computes speedup ratios
│   └── Detects efficiency regressions
└── CrossLanguageCallMonitor (Actor)
    ├── Tracks FFI call volume
    ├── Measures call frequency
    └── Detects call storms
```

### Configuration Modes

```swift
GuardrailConfiguration.default   // 15% tolerance, 1.2x speedup requirement
GuardrailConfiguration.strict    // 5% tolerance, 1.5x speedup (CI/CD)
GuardrailConfiguration.relaxed   // 30% tolerance, 1.0x baseline (development)
```

---

## Usage

### 1. Recording Metrics

In your capsule operations, record the metrics:

```swift
let guardrails = RegressionGuardrails(configuration: .default)

// Record capsule allocations
guardrails.recordCapsuleAllocation(
    operationName: "add_nodes",
    size: UInt64(MemoryLayout<SceneNode>.stride * nodeCount)
)

// Record batch efficiency
guardrails.recordBatchEfficiency(
    operationName: "add_nodes",
    individualTime: individualTimeMs,
    batchTime: batchTimeMs,
    itemCount: nodeCount
)

// Record cross-language calls
guardrails.recordCrossLanguageCallMetrics(
    operationName: "add_nodes",
    callTypes: ["swift_to_c": 1, "c_to_swift": 1],
    durationMs: durationMs
)
```

### 2. Running Guardrails Tests

From repository root:

```bash
# Run with default configuration
anigma/Scripts/run_performance_guardrails.sh .

# Run with strict configuration (for CI)
anigma/Scripts/run_performance_guardrails.sh . strict

# Run with relaxed configuration (development)
anigma/Scripts/run_performance_guardrails.sh . relaxed
```

### 3. Integrating with CI/CD

Add to your GitHub Actions workflow:

```yaml
- name: Run performance guardrails
  run: |
    anigma/Scripts/run_performance_guardrails.sh . strict
  continue-on-error: false
```

---

## Test Coverage

### PerformanceRegressionGuardrailsTests

All tests in `Packages/SceneGraphCapsule/Tests/SceneGraphCapsuleTests/PerformanceRegressionGuardrailsTests.swift`
(or `Anigma/Packages/SceneGraphCapsule/Tests/SceneGraphCapsuleTests/PerformanceRegressionGuardrailsTests.swift` in dual-tree layouts):

#### Capsule Allocation Tests
- `testCapsuleAllocationBoundary()` - Verify batch ops don't exceed allocation threshold
- `testIndividualAllocationVsBatch()` - Compare individual vs batch allocation counts

#### Batch Efficiency Tests
- `testBatchEfficiencySpeedup()` - Verify speedup for varying sizes (10, 50, 100 items)
- `testBatchEfficiencyRegression()` - Monitor consistency over multiple runs

#### Cross-Language Call Tests
- `testCrossLanguageCallVolume()` - Verify total call count bounded
- `testNoFFICallStorm()` - Ensure O(1) FFI calls, not O(n)

#### Hot Path Fusion Tests
- `testHotPathIntermediateAllocations()` - Check for per-item allocation bloat

#### Integration Test
- `testFullWorkloadRegressionGuardrails()` - Realistic 500-node workload

---

## Interpreting Results

### Passing Test Output

```
✓ Capsule allocation test passed: 1 allocations for 100 nodes
✓ Batch efficiency [100 items]: 2.34x speedup (min: 1.30x)
✓ Cross-language call volume test passed: 2 calls, 0.005 calls/ms
✓ FFI call storm test passed: 2 FFI calls for 200 nodes (O(1) pattern)
```

### Regression Detection

```
✗ Batch operation did not meet efficiency requirement for 100 items
  Speedup: 0.95x (expected min: 1.04x)
  → Indicates fusion optimization may be broken
```

### When to Investigate

| Symptom | Likely Cause | Action |
|---------|-------------|--------|
| Allocation count > threshold | Loop creating intermediate capsules | Use batch APIs |
| Speedup < threshold | Missing hot-path fusion | Profile and optimize |
| Call volume > threshold | O(n) FFI calls in loop | Batch FFI calls |
| High variation between runs | GC pressure or thermal throttling | Run in isolation |

---

## Performance Baselines

### SceneGraphCapsule Batch Operations (M1 Mac, 1 run)

| Operation | Size | Individual | Batch | Speedup |
|-----------|------|-----------|-------|---------|
| addNodes  | 10   | 0.45 ms   | 0.31 ms | 1.45x |
| addNodes  | 50   | 2.15 ms   | 1.20 ms | 1.79x |
| addNodes  | 100  | 4.30 ms   | 2.10 ms | 2.05x |
| getWorldTransforms | 50 | 1.20 ms | 0.60 ms | 2.00x |
| getWorldTransforms | 100 | 2.40 ms | 1.10 ms | 2.18x |

*Note: Actual times depend on system load. Use relative speedup, not absolute times.*

---

## Common Patterns & Best Practices

### ✓ Good: Batch Operations

```swift
// ✓ Efficient: Single batch call
let newGraph = try await capsule.addNodes(nodes, to: graph)  // 1 allocation
```

### ✗ Bad: Individual Operations Loop

```swift
// ✗ Inefficient: Loop creates N allocations
for node in nodes {
    graph = try await capsule.addNode(node, to: graph)  // N allocations
}
```

### ✓ Good: Batch FFI Calls

```swift
// ✓ Efficient: Batch FFI operation
let transforms = try await capsule.getWorldTransforms(for: nodeIDs, in: graph)
// Expected: ~2 FFI calls total
```

### ✗ Bad: Individual FFI Calls in Loop

```swift
// ✗ Inefficient: O(n) FFI calls
for nodeID in nodeIDs {
    let transform = try await capsule.getWorldTransform(for: nodeID, in: graph)
    // O(n) FFI calls!
}
```

---

## Configuration Reference

### Default Mode (Development/Testing)

```swift
GuardrailConfiguration.default = GuardrailConfiguration(
    capsuleAllocationThreshold: 15.0,       // 15% deviation allowed
    maxCapsuleAllocationsPerOperation: 3,   // ≤3 allocations
    batchEfficiencyThreshold: 1.2,          // ≥1.2x speedup required
    minBatchSize: 10,                       // Useful for sizes ≥10
    crossLanguageCallThreshold: 5,          // ≤5 FFI calls
    callFrequencyThreshold: 0.1,            // ≤0.1 calls/ms
    maxIntermediateAllocationsPerFusion: 2, // ≤2 per fusion
    hotPathThreshold: 5.0                   // Hot path: ≥5ms
)
```

### Strict Mode (CI/CD)

```swift
GuardrailConfiguration.strict = GuardrailConfiguration(
    capsuleAllocationThreshold: 5.0,        // 5% tolerance
    maxCapsuleAllocationsPerOperation: 1,   // Only 1 allocation
    batchEfficiencyThreshold: 1.5,          // ≥1.5x speedup
    minBatchSize: 5,
    crossLanguageCallThreshold: 2,          // ≤2 calls
    callFrequencyThreshold: 0.05,           // ≤0.05 calls/ms
    maxIntermediateAllocationsPerFusion: 1,
    hotPathThreshold: 2.0
)
```

### Relaxed Mode (Development)

```swift
GuardrailConfiguration.relaxed = GuardrailConfiguration(
    capsuleAllocationThreshold: 30.0,       // 30% tolerance
    maxCapsuleAllocationsPerOperation: 5,   // ≤5 allocations
    batchEfficiencyThreshold: 1.0,          // No minimum
    minBatchSize: 50,                       // Only for large batches
    crossLanguageCallThreshold: 20,         // ≤20 calls
    callFrequencyThreshold: 0.5,            // ≤0.5 calls/ms
    maxIntermediateAllocationsPerFusion: 5,
    hotPathThreshold: 10.0
)
```

---

## Integration Points

### Existing Test Files

The guardrails integrate with:
- `SceneGraphCapsuleBatchBenchmarks.swift` - Validates speedup measurements
- `SceneGraphCapsuleBenchmarks.swift` - Tracks allocation patterns
- `SceneGraphCapsuleTests.swift` - Functional correctness + performance

### Metrics Infrastructure

Hooks into:
- `MetricsCollectorCapsule` - Metrics aggregation
- `CapsuleDiagnostics` - Diagnostic events
- `TelemetryCore` - Telemetry reporting

### Future Extensions

Ready for:
- Real MLX operation monitoring
- Cross-platform call tracking (Swift ↔ Python)
- Memory profiler integration
- Continuous baseline tracking

---

## Troubleshooting

### Tests Won't Compile

**Error**: `'RegressionGuardrails' is not defined`
- **Fix**: Verify `RegressionGuardrails.swift` is in correct package
- Import: `@testable import CoreUtilities` or relevant capsule package

### Tests Pass Locally but Fail in CI

**Cause**: System variance, thermal throttling, background processes
- **Fix**: Run tests in isolated environment or use `--parallel=1`
- Consider increasing thresholds for flaky checks in CI

### Baseline Doesn't Exist

**Message**: `⚠ No baseline found. Creating baseline for future comparisons.`
- **Action**: This is normal for first run
- Commit `.performance-guardrails-baseline.json` to repository

### High Variance Between Runs

**Symptom**: `85% deviation between runs`
- **Cause**: Usually GC or system contention
- **Fix**: 
  - Run tests with `-O` release optimizations
  - Disable other processes
  - Use statistical aggregation (average of 3+ runs)

---

## References

- **Hot Path Fusion**: Combining multiple operations to reduce allocation overhead
- **Batch APIs**: Operations that process collections efficiently in one call
- **FFI Overhead**: Cost of Swift ↔ C/Objective-C boundary crossings
- **Intermediate Allocations**: Temporary data structures created during operations

---

## Contributing

When adding new capsule operations:

1. **Record baseline metrics** for batch operation
2. **Add test case** to `PerformanceRegressionGuardrailsTests`
3. **Document expected speedup** in test
4. **Update guardrail thresholds** if needed
5. **Commit baseline** to repository

Example PR checklist:
- [ ] New batch API has measurable speedup (≥1.2x)
- [ ] Cross-language calls stay O(1) or O(log n)
- [ ] Allocations don't scale with input size
- [ ] Test passes in strict mode
- [ ] Baseline updated

---

## Changelog

### v1.0 (2025-02)
- ✓ Core guardrails framework
- ✓ Capsule allocation tracking
- ✓ Batch efficiency monitoring
- ✓ Cross-language call detection
- ✓ Hot path fusion checks
- ✓ XCTest integration
- ✓ Configuration modes (default/strict/relaxed)
- ✓ CI/CD script
