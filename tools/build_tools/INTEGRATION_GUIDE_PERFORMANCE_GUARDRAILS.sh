#!/bin/bash
# Integration guide: Adding performance guardrails to existing test workflows

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║           PERFORMANCE GUARDRAILS INTEGRATION GUIDE                        ║
║                                                                           ║
║  Quick integration for existing Anigma test pipelines                    ║
╚═══════════════════════════════════════════════════════════════════════════╝

## 1. BASIC INTEGRATION (5 minutes)

### Step 1: Run guardrails locally
$ cd /Users/user/Developer/GitHub/Anigma_clean
$ anigma/Scripts/run_performance_guardrails.sh .

Expected output:
✓ Capsule allocation test passed: 1 allocations for 100 nodes
✓ Batch efficiency [100 items]: 2.34x speedup (min: 1.30x)
✓ Cross-language call volume test passed: 2 calls, 0.005 calls/ms

### Step 2: Commit baseline
$ git add .performance-guardrails-baseline.json
$ git commit -m "Add performance guardrails baseline"

### Step 3: Include in normal test runs
$ swift test --filter "PerformanceRegressionGuardrailsTests"

## 2. CI/CD INTEGRATION (10 minutes)

### Option A: GitHub Actions

Add to .github/workflows/test.yml:

---
name: Tests with Performance Guardrails

on: [push, pull_request]

jobs:
  performance:
    runs-on: macos-14-xlarge  # Important: use consistent runner
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Swift
        uses: swift-actions/setup-swift@v1
        with:
          swift-version: '6.0'
      
      - name: Performance guardrails (default)
        if: github.event_name == 'push'
        run: anigma/Scripts/run_performance_guardrails.sh . default
      
      - name: Performance guardrails (strict)
        if: github.event_name == 'pull_request'
        run: anigma/Scripts/run_performance_guardrails.sh . strict
        continue-on-error: false  # Fail on regression in PR
      
      - name: Upload report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: performance-reports
          path: |
            .performance-guardrails-report.json
            .performance-guardrails-baseline.json
---

### Option B: Local pre-commit hook

Create .git/hooks/pre-commit:

---
#!/bin/bash
# Pre-commit hook: Run performance guardrails

echo "Running performance guardrails..."
anigma/Scripts/run_performance_guardrails.sh . default

if [ $? -ne 0 ]; then
    echo "Performance guardrails failed. Commit aborted."
    exit 1
fi

exit 0
---

$ chmod +x .git/hooks/pre-commit

### Option C: Manual CI script

Create scripts/test-with-performance.sh:

---
#!/bin/bash
set -e

echo "Running unit tests..."
swift test -c debug

echo "Running performance guardrails..."
anigma/Scripts/run_performance_guardrails.sh . strict

echo "All tests passed!"
---

## 3. EXISTING TEST COMPATIBILITY

### Works with existing tests:
✓ SceneGraphCapsuleBatchBenchmarks.swift
✓ SceneGraphCapsuleBenchmarks.swift
✓ SceneGraphCapsuleTests.swift
✓ All other XCTest suites

### Parallel execution:
$ swift test --parallel  # All tests run in parallel

### Filtering existing tests + guardrails:
$ swift test --filter "Batch"  # Runs batch-related tests

## 4. RECORDING METRICS IN YOUR CODE

### In SceneGraphCapsule operations:

```swift
public func addNodes(_ nodes: [SceneNode], to graph: SceneGraph) async throws -> SceneGraph {
    let guardrails = RegressionGuardrails(configuration: .default)
    
    let start = CFAbsoluteTimeGetCurrent()
    let result = try performBatchAddition(nodes, to: graph)
    let duration = CFAbsoluteTimeGetCurrent() - start
    
    // Record for monitoring
    guardrails.recordBatchEfficiency(
        operationName: "addNodes",
        individualTime: estimateIndividualTime(nodes.count),  // Estimate
        batchTime: duration * 1000,
        itemCount: nodes.count
    )
    
    return result
}
```

### In other capsule operations:

```swift
// Capsule allocation tracking
guardrails.recordCapsuleAllocation(
    operationName: "myOperation",
    size: UInt64(MemoryLayout<MyType>.stride * count)
)

// Cross-language call tracking
guardrails.recordCrossLanguageCallMetrics(
    operationName: "myOperation",
    callTypes: ["swift_to_c": 1, "c_to_swift": 1],
    durationMs: durationMs
)
```

## 5. MONITORING & INTERPRETATION

### Check current status:
$ cat .performance-guardrails-report.json | jq .

### Compare with baseline:
$ diff <(jq .guardrails .performance-guardrails-baseline.json) \
       <(jq .guardrails .performance-guardrails-report.json)

### If guardrails fail:

1. Read the error message carefully
2. Profile with Instruments (Time Profiler)
3. Check for:
   - Missing batch API (allocation count too high)
   - Missing hot-path fusion (speedup too low)
   - O(n) FFI calls (call volume scaling with input)
4. Fix the issue
5. Re-run guardrails
6. Update baseline if appropriate

## 6. ADVANCED: CUSTOM THRESHOLDS

### For specific operations:

```swift
// Stricter for crypto operations
let cryptoConfig = GuardrailConfiguration(
    capsuleAllocationThreshold: 2.0,
    maxCapsuleAllocationsPerOperation: 1,
    batchEfficiencyThreshold: 2.0,  // Must be 2x faster!
    minBatchSize: 100,
    // ... other settings
)

let cryptoGuardrails = RegressionGuardrails(configuration: cryptoConfig)
```

### For performance-critical sections:

```swift
// Mark hot paths
if configuration == .strict {
    // Apply strict thresholds
    let hotPathConfig = GuardrailConfiguration.strict
    // ... verify hot path meets thresholds
}
```

## 7. TROUBLESHOOTING

### Tests won't compile
→ Check imports: `@testable import CoreUtilities`
→ Verify RegressionGuardrails.swift is in package sources

### Tests timeout
→ Reduce item counts in PerformanceRegressionGuardrailsTests
→ Run with -O optimization: `swift test -c release`

### High variance between runs
→ Close other applications
→ Disable Spotlight: System Preferences → Siri & Spotlight → disable indexing
→ Use release build: `swift test -c release`
→ Run in isolated environment (CI/CD)

### Baseline doesn't match
→ Different hardware: Baselines are hardware-specific
→ System load: Run tests in isolation
→ Update baseline: `mv .performance-guardrails-report.json .performance-guardrails-baseline.json`

## 8. QUICK COMMAND REFERENCE

# Run guardrails with default configuration
anigma/Scripts/run_performance_guardrails.sh .

# Run with strict mode (CI/CD)
anigma/Scripts/run_performance_guardrails.sh . strict

# Run just one test
swift test --filter "testBatchEfficiencySpeedup"

# Run with detailed output
swift test -v --filter "PerformanceRegressionGuardrailsTests"

# Run in release mode (faster)
swift test -c release --filter "PerformanceRegressionGuardrailsTests"

# Run with parallel execution
swift test --parallel

# Check guardrails report
cat .performance-guardrails-report.json | jq

# Create new baseline
mv .performance-guardrails-report.json .performance-guardrails-baseline.json
git add .performance-guardrails-baseline.json

## 9. DOCUMENTATION LINKS

Full Guide:
  $ open anigma/PERFORMANCE_GUARDRAILS_GUIDE.md

Quick Reference:
  $ open anigma/PERFORMANCE_GUARDRAILS_QUICK_REF.md

Implementation Details:
  $ open PERFORMANCE_GUARDRAILS_IMPLEMENTATION.md

## 10. SUCCESS CHECKLIST

Before committing performance changes:

□ Run guardrails locally: anigma/Scripts/run_performance_guardrails.sh . default
□ Check that batch speedup ≥ 1.2x
□ Verify allocation count ≤ 3
□ Confirm cross-language calls ≤ 5
□ Review full output for warnings
□ Compare with baseline (no major regressions)
□ Document any threshold changes
□ Add test case if new operation
□ Update baseline if optimization applied
□ Commit baseline with PR

═══════════════════════════════════════════════════════════════════════════

For questions: See PERFORMANCE_GUARDRAILS_GUIDE.md

EOF
