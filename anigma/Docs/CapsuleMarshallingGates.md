# Capsule Marshalling Gates

## Overview

Capsule marshalling gates are automated enforcement mechanisms that ensure the "Swift governs, C++ computes" architecture is maintained. They verify compliance with the Capsule Standard Policy, enforce performance budgets, and verify determinism.

## Static Analysis Rules

### SwiftLint Custom Rules

The following custom SwiftLint rules are defined in `Configs/swiftlint-capsule.yml`:

| Rule Name | Pattern | Severity | Purpose | Approved Shape |
|-----------|---------|----------|---------|----------------|
| `capsule_string_usage` | `\bString\b` (typeidentifier) | Error | Detect usage of `String` type in capsule boundaries | Use `UnsafePointer<CChar>` or `CapsuleBuffer` |
| `capsule_json_marshalling` | `\bJSONEncoder\b|\bJSONDecoder\b` | Error | Detect JSON serialization in performance‑critical modules | Use binary serialization |
| `capsule_per_item_abi_call` | `for\s+\w+\s+in\s+.*\{[^}]*anigma_[a-z_]*\([^}]*\}` | Warning | Detect per‑item ABI calls inside loops | Use batch APIs |

These rules are applied to Swift files in:
- `Packages/CapsuleCore/Sources/**/*.swift`
- `Packages/AnigmaNativeShims/Sources/**/*.swift`
- `Packages/TypographyKit/Sources/**/*.swift`
- `Sources/ContextumModule/**/*.swift`
- `Sources/**/*Capsule*.swift`

### C++ ABI Boundary Checks

The script `Scripts/ci/check‑capsule‑abi.sh` validates C++ code in `Native/Shims/` to ensure compliance with the following requirements:

1. **C-compatible types in headers** – Use `const char*` or `anigma_buffer_t` instead of `std::string`.
2. **Safe ABI boundary** – Ensure `throw` statements are caught at the ABI boundary to prevent uncaught C++ exceptions.
3. **Pointers for C signatures** – Use pointers instead of C++ references.
4. **`extern "C"` wrapping** – All public C headers must wrap declarations in `extern "C"`.

## Benchmark Gates

### CapsuleBenchmark Protocol

Capsules that require performance validation should conform to the `CapsuleBenchmark` protocol (defined in `CapsuleCore`). The protocol provides:

- Standardized benchmarking with telemetry collection
- Marshalling budget validation
- Iteration‑based timing

### MarshallingBudgets

`MarshallingBudgets` define limits for key operations:

| Budget | Description | Default (strict) |
|--------|-------------|-------------------|
| `maxABICalls` | Maximum number of ABI calls per operation | 2 |
| `maxStringConversions` | Maximum string conversions (should be zero) | 0 |
| `maxBytesCopied` | Maximum bytes copied | 1 MiB |
| `maxBufferAllocations` | Maximum buffer allocations | 1 |

Pre‑defined budgets:
- `MarshallingBudgets.strict` – for performance‑critical capsules
- `MarshallingBudgets.lenient` – for import/export boundaries
- `MarshallingBudgets.vectorCapsule`, `searchCapsule`, `compressionCapsule` – category‑specific budgets

### Running Benchmarks

The CI workflow `benchmark‑capsules.yml` runs capsule benchmarks weekly and on every PR. Benchmarks are executed via `Scripts/ci/benchmark‑capsules.sh`, which:

1. Builds `CapsuleCore`
2. Discovers and runs all `CapsuleBenchmark` conformances
3. Validates telemetry against the capsule’s budgets
4. Reports compliance status and remediation steps for any budget breaches.

## CI Enforcement

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `validate‑capsules.yml` | PR / push to `main` | Run static analysis (SwiftLint, ABI checks) and validation scripts |
| `benchmark‑capsules.yml` | PR / push to `main` + weekly | Run performance benchmarks and budget validation |
| `determinism‑check.yml` | PR / push to `main` + weekly | Verify Tier 1 capsule determinism (bitwise identical outputs) |

### Validation Scripts

- `Scripts/validate_capsules.swift` – Swift‑side pattern detection (e.g., `String` initializations, JSON usage)
- `Scripts/check_marshalling_budgets.swift` – Budget validation using `MarshallingTelemetry`
- `Scripts/ci/check‑capsule‑abi.sh` – C++ ABI boundary checks
- `Scripts/ci/check‑determinism.sh` – Determinism verification

## Determinism Tiers

Capsules must declare a determinism tier in their header:

```c
#define ANIGMA_CAPSULE_TIER TIER_1  // Bitwise identical across runs
// or
#define ANIGMA_CAPSULE_TIER TIER_2  // Epsilon‑stable (numerically stable)
```

**Tier 1 (Bitwise)** – Use for evidence, hashing, and receipts. This tier requires identical output for identical input across runs, architectures, and compiler versions.

**Tier 2 (Epsilon‑stable)** – Use for vector/layout operations where floating‑point differences are acceptable within a defined epsilon.

The determinism check workflow verifies that:
1. Every capsule header includes `ANIGMA_CAPSULE_TIER`
2. Tier 1 capsules pass golden‑corpus tests (bitwise reproducibility)

## Examples of Compliant Shapes

### Swift-Side Compliance

- **Constraint**: `JSONEncoder`/`Decoder` must not be used in performance-critical capsule boundaries.
- **Approved Shape**: Use canonical binary serialization via `CanonicalEncoder`.
- **Correct Layer**: Tier 2/3 marshalling boundary.
- **Example**:
```swift
// ✅ Approved Shape: Use canonical binary serialization
let buffer = try CanonicalEncoder.encode(data)
```

### C++-Side Compliance

- **Constraint**: `std::string` must not appear in public C headers.
- **Approved Shape**: Use C-compatible types like `const char*` or `anigma_buffer_t`.
- **Correct Layer**: Tier 3 native ABI boundary.
- **Example**:
```cpp
// ✅ Approved Shape: Use C-compatible types
anigma_status_t process(const char* input, size_t input_len,
                        char** output, size_t* output_len);
```

### Performance Budget Compliance

- **Constraint**: ABI calls and string conversions must stay within defined performance budgets.
- **Approved Shape**: Batch operations to reduce ABI calls and use pointer-based marshalling to avoid string conversions.
- **Correct Layer**: Tier 2 marshalling infrastructure.
- **Refactor Path**: If budgets are breached, optimize the capsule via batch APIs or zero-copy marshalling before requesting a budget adjustment.

## Performance Budgeting Guide

### Setting Budgets

1. **Identify the capsule’s category** (vector, search, compression, etc.) and use the corresponding pre‑defined budget.
2. **Profile the capsule** with realistic workloads using `MarshallingTelemetry`.
3. **Set budgets** slightly above the observed maximums to allow for normal variation.
4. **Document the rationale** for each budget in the capsule’s header.

### Budget Escalation

If a capsule legitimately needs higher limits:
1. **First**, attempt to optimize the capsule (batch APIs, zero‑copy marshalling, etc.)
2. **If optimization is insufficient**, propose a budget increase via a PR with:
   - Profiling data showing the need
   - Explanation why the limit cannot be lowered
   - Approval from the performance governance team

## Integration with Existing CI

The capsule gates integrate with the existing contract‑enforcement system. The summary report of each validation run is uploaded as an artifact (`capsule‑validation‑report.md`, `capsule‑benchmark‑results`, `determinism‑report`).

## Adding a New Capsule

When implementing a new capsule, follow these steps to ensure it passes the gates:

1. **Header declaration** – Include `ANIGMA_CAPSULE_TIER` and wrap all public functions in `extern "C"`.
2. **Swift wrapper** – Use `CapsuleHandle` and `CapsuleBuffer`; avoid `String` and JSON.
3. **Benchmark** – Conform to `CapsuleBenchmark` and define appropriate budgets.
4. **Golden tests** – For Tier 1 capsules, add test inputs and expected outputs to `Tests/CapsuleCoreTests/GoldenCorpus`.
5. **Run validation locally** – Execute `./Scripts/ci/run‑swiftlint‑capsule.sh` and `./Scripts/ci/check‑capsule‑abi.sh` before submitting a PR.

## Troubleshooting

### SwiftLint Findings

If SwiftLint reports an architectural violation:
- Use the approved shape (e.g., `CapsuleBuffer` instead of `String`).
- If you believe this is a false positive, you can exclude the file in `Configs/swiftlint‑capsule.yml` (use sparingly) or add a `// swiftlint:disable:next` comment.

### Benchmark Adjustments

If benchmarks report budget violations:
- Examine the telemetry snapshot to identify the metric breach.
- Optimize the capsule (e.g., reduce ABI calls via batching).
- If the current budget is unrealistic for the capsule’s purpose, propose a budget adjustment

### Determinism Verification

If determinism tests report drift:
- Ensure the capsule uses only deterministic algorithms (exclude random numbers or system‑time dependencies).
- For Tier 2 capsules, verify that differences remain within the defined epsilon.
- Ensure the golden corpus remains the source of truth for bitwise reproducibility.

## Future Enhancements

- **Automated budget suggestion** – derive budgets from profiling data
- **Capsule maturity model** – classify capsules by compliance level
- **Integration with receipt governance** – automatically include telemetry in receipts
- **Visual dashboards** – track marshalling metrics over time

---

*Last updated: 2026‑01‑12*