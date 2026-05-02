# CoreML Verification Suite

## Overview

The CoreML Verification Suite provides comprehensive testing and validation for the CoreML conversion pipeline. It includes four main components:

1. **Golden Tests** - Verify conversion correctness against expected outputs
2. **Performance Benchmarking** - Measure conversion performance across hardware targets
3. **Determinism Testing** - Ensure reproducible conversions across runs
4. **Regression Detection** - Detect performance and correctness regressions

## Architecture

### Core Components

- **`CoreMLVerificationSuite`** - Main orchestrator for all verification tasks
- **`GoldenTestSpec`** - Specification for golden tests with expected outputs
- **`PerformanceBenchmark`** - Configuration for performance benchmarks
- **`DeterminismTest`** - Configuration for determinism testing
- **`RegressionThresholds`** - Thresholds for regression detection

### Hardware Targets

The suite supports benchmarking across different hardware targets:
- **CPU** - CPU-only execution
- **GPU** - CPU + GPU execution
- **ANE** - CPU + Apple Neural Engine execution
- **ALL** - All available compute units

## Usage

### Command Line Interface

```bash
# Run verification with example configurations
model-registry verify run --generate-examples

# Generate configuration templates
model-registry verify generate

# List available reports
model-registry verify report --list

# View a specific report
model-registry verify report --name verification_demo_1234567890
```

### Programmatic Usage

```swift
import ModelRegistry

// Create verification suite
let workDir = URL(fileURLWithPath: "/tmp/coreml_verification")
let registry = InMemoryCoreMLRegistry()
let pipeline = CoreMLConversionPipeline(
    workDir: workDir,
    registry: registry
)

let suite = CoreMLVerificationSuite(
    pipeline: pipeline,
    goldenTestsPath: workDir.appendingPathComponent("golden_tests"),
    baselinePath: workDir.appendingPathComponent("baselines"),
    resultsPath: workDir.appendingPathComponent("results")
)

// Run golden tests
let goldenSpecs = [
    GoldenTestSpec(
        id: "test_bert",
        modelId: "bert-base-uncased",
        expectedOutputHash: "abc123...",
        expectedPlacement: "ANE"
    )
]

let goldenResults = await suite.runGoldenTests(goldenSpecs)

// Run performance benchmarks
let benchmarks = [
    PerformanceBenchmark(
        id: "benchmark_bert",
        modelId: "bert-base-uncased",
        iterations: 10
    )
]

let performanceMetrics = await suite.runPerformanceBenchmarks(benchmarks)

// Run determinism tests
let determinismTests = [
    DeterminismTest(
        id: "determinism_bert",
        modelId: "bert-base-uncased",
        runs: 5
    )
]

let determinismResults = await suite.runDeterminismTests(determinismTests)

// Detect regressions
let regressionReports = try await suite.detectRegressions(
    currentMetrics: performanceMetrics,
    baselineName: "v1.0.0"
)

// Generate report
let report = suite.generateVerificationReport(
    goldenResults: goldenResults,
    performanceMetrics: performanceMetrics,
    determinismResults: determinismResults,
    regressionReports: regressionReports
)
```

## Configuration Files

### Golden Tests Configuration (JSON)

```json
[
  {
    "id": "test_bert_int8",
    "modelId": "bert-base-uncased",
    "targetFormat": "mlprogram",
    "computeUnits": "cpuAndNeuralEngine",
    "quantization": "int8",
    "minOSVersion": "macos15",
    "expectedOutputHash": "REPLACE_WITH_ACTUAL_HASH",
    "expectedPlacement": "ANE",
    "tolerance": 0.0,
    "description": "BERT base model with INT8 quantization for ANE"
  }
]
```

### Performance Benchmarks Configuration (JSON)

```json
[
  {
    "id": "benchmark_bert_int8_ane",
    "modelId": "bert-base-uncased",
    "targetFormat": "mlprogram",
    "computeUnits": "cpuAndNeuralEngine",
    "quantization": "int8",
    "iterations": 10,
    "warmupIterations": 2,
    "expectedThroughput": 0.5,
    "maxLatency": 30.0,
    "memoryBudget": 2147483648
  }
]
```

### Determinism Tests Configuration (JSON)

```json
[
  {
    "id": "determinism_bert_int8",
    "modelId": "bert-base-uncased",
    "targetFormat": "mlprogram",
    "computeUnits": "cpuAndNeuralEngine",
    "quantization": "int8",
    "runs": 5,
    "requireExactMatch": true,
    "tolerance": 0.0
  }
]
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: CoreML Verification

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Build Model Registry
      run: swift build -c release --package-path Packages/ModelRegistry
    
    - name: Run Verification
      run: |
        cd Packages/ModelRegistry
        swift run model-registry verify run \
          --golden-tests tests/golden_tests.json \
          --benchmarks tests/benchmarks.json \
          --determinism tests/determinism_tests.json \
          --baseline v1.0.0
    
    - name: Upload Verification Report
      uses: actions/upload-artifact@v3
      with:
        name: verification-report
        path: /tmp/coreml_verification/results/
```

### Regression Detection in CI

The regression detection feature can be used to fail builds when performance degrades beyond acceptable thresholds:

```swift
let regressionReports = try await suite.detectRegressions(
    currentMetrics: performanceMetrics,
    baselineName: "production_baseline",
    thresholds: RegressionThresholds(
        maxPerformanceRegression: 10.0,  // Fail if >10% slower
        maxMemoryIncrease: 15.0,         // Fail if >15% more memory
        maxAccuracyRegression: 1.0,      // Fail if >1% accuracy loss
        minThroughput: 0.5               // Fail if <0.5 conversions/sec
    )
)

let failures = regressionReports.filter { $0.verdict == .fail }
if !failures.isEmpty {
    print("❌ Regression detected! Failing build.")
    for failure in failures {
        print("   - \(failure.testId): \(String(format: "%.1f", failure.regressionPercentage))% regression")
    }
    exit(1)
}
```

## Best Practices

### 1. Establish Baselines
- Run verification on known good versions to establish performance baselines
- Store baselines in version control alongside code
- Update baselines when intentional performance changes are made

### 2. Golden Test Management
- Start with a small set of critical models
- Update expected hashes after verifying conversions are correct
- Use tolerance values for floating-point comparisons
- Include models from different workload categories

### 3. Performance Testing
- Run benchmarks on consistent hardware
- Use warmup iterations to account for JIT compilation
- Test across all hardware targets (CPU, GPU, ANE)
- Set realistic thresholds based on production requirements

### 4. Determinism Assurance
- Test with `requireExactMatch: true` for critical models
- Run multiple repetitions (3-5 is usually sufficient)
- Investigate any non-determinism immediately

### 5. Regression Prevention
- Set conservative thresholds initially
- Gradually tighten thresholds as system stabilizes
- Use regression detection in CI to prevent performance degradation
- Alert on warnings as well as failures

## Example Workflow

### Step 1: Initial Setup
```bash
# Generate configuration templates
model-registry verify generate

# Run initial conversions to get expected hashes
model-registry convert bert-base-uncased --format mlprogram --quantization int8

# Update golden test config with actual hash
# Edit example_golden_tests.json
```

### Step 2: Establish Baseline
```bash
# Run verification to establish baseline
model-registry verify run \
  --golden-tests example_golden_tests.json \
  --benchmarks example_benchmarks.json

# Save baseline
cp /tmp/coreml_verification/baselines/*_baseline.json ./baselines/
```

### Step 3: Integrate with CI
```bash
# In CI pipeline, compare against baseline
model-registry verify run \
  --golden-tests tests/golden_tests.json \
  --benchmarks tests/benchmarks.json \
  --baseline production_baseline
```

## Troubleshooting

### Common Issues

1. **Golden test failures**
   - Verify model exists in registry
   - Check that expected hash matches actual conversion output
   - Ensure Python environment and coremltools are properly configured

2. **Performance regression alerts**
   - Check for system load during benchmarking
   - Verify consistent hardware configuration
   - Consider thermal throttling on mobile devices

3. **Non-deterministic conversions**
   - Ensure `skipCache: true` for determinism tests
   - Check for random number generation in conversion pipeline
   - Verify consistent Python environment

4. **Memory budget exceeded**
   - Adjust `memoryBudget` in benchmark configuration
   - Consider model size and quantization
   - Check for memory leaks in conversion pipeline

### Debugging Tips

- Use `--work-dir` to specify a clean working directory
- Enable verbose logging in the conversion pipeline
- Check intermediate files in the working directory
- Compare reports between different runs

## Extending the Suite

### Adding New Test Types

1. Create a new configuration type conforming to `Codable` and `Sendable`
2. Add corresponding methods to `CoreMLVerificationSuite`
3. Update report generation to include new test results
4. Add CLI commands if needed

### Custom Metrics

The `PerformanceMetrics` struct can be extended to include additional metrics:
- Energy consumption
- Disk I/O
- Network usage
- GPU memory bandwidth

### Integration with Other Systems

The verification suite can be integrated with:
- Monitoring systems (Prometheus, Datadog)
- Alerting systems (PagerDuty, OpsGenie)
- Data visualization (Grafana, Tableau)
- Test management systems

## Performance Considerations

- Golden tests should be fast (use small models for frequent testing)
- Performance benchmarks can be run less frequently
- Determinism tests are critical but can be run in parallel
- Regression detection should be fast enough for CI

## Security Considerations

- Golden test configurations may contain sensitive model information
- Performance baselines should be stored securely
- Verification results should be accessible only to authorized personnel
- Consider data classification when storing test artifacts

## Future Enhancements

Planned enhancements include:
- Distributed benchmarking across multiple machines
- Automated baseline updating
- Integration with model registry for automatic test generation
- Historical trend analysis
- Anomaly detection for performance metrics