# Capsule Integration Strategy

## 1. Phased Rollout

Capsules will be integrated into the codebase in three phases to minimize risk and ensure stability.

### Phase A: Non‑Critical Paths (Offline Indexing)

- **Capsules**: ChunkingCapsule, LayoutEngineCapsule
- **Workflows**: Background indexing (`CLIIndexManager`, `ContextumModule` auto‑indexing)
- **Rationale**: These workflows are tolerant of failures; errors can be logged and Swift fallback used.

### Phase B: Critical‑Path Performance (Receipt Generation)

- **Capsules**: CompressionCapsule, TextPipelineCapsule
- **Workflows**: Receipt serialization, evidence hashing, canonical normalization
- **Rationale**: These operations require deterministic output (Tier 1). Capsules must be thoroughly validated before deployment.

### Phase C: Optional Capabilities (Media Analysis)

- **Capsules**: MediaFingerprintCapsule
- **Workflows**: Media deduplication, similarity search
- **Rationale**: This capsule is optional; the system can operate without it.

## 2. Feature Flags

Each capsule will be controlled by a runtime feature flag, allowing gradual rollout and easy disablement.

### 2.1 Configuration Source

Flags will be read from:
1. Environment variable (`ANIGMA_CAPSULE_[NAME]=1|0`)
2. Configuration file (`capsules.toml`)
3. Default: enabled if dependency available, otherwise disabled.

### 2.2 Swift Wrapper Implementation

```swift
public actor [Name]Capsule {
    private static let isEnabled: Bool = {
        #if ANIGMA_HAVE_DEPENDENCY
        return Environment.flag("ANIGMA_CAPSULE_[NAME]", default: true)
        #else
        return false
        #endif
    }()

    private let fallbackImpl: FallbackImplementation?

    public init() throws {
        guard Self.isEnabled else {
            throw CapsuleError.dependencyUnavailable
        }
        // ... initialize native handle
    }

    public func operation(input: Data) throws -> Data {
        if Self.isEnabled {
            return try nativeOperation(input)
        } else {
            // Use Swift fallback
            return try fallbackImpl.operation(input)
        }
    }
}
```

## 3. Migration Paths from Swift Implementations

### 3.1 Parallel Implementation

- Keep the existing Swift implementation as a fallback.
- Add a configuration switch to select between capsule and Swift.
- Run both in CI to compare outputs and performance.

### 3.2 Gradual Replacement

1. **Step 1**: Add capsule wrapper alongside existing Swift API (marked `@_spi(Experimental)`).
2. **Step 2**: Use capsule in internal tests and benchmarks.
3. **Step 3**: Enable capsule for a subset of users (canary).
4. **Step 4**: After validation, replace Swift implementation with capsule (keeping fallback for dependency‑missing cases).
5. **Step 5**: Eventually deprecate Swift implementation (if capsule is stable and universally available).

## 4. Error Handling and Fallback

### 4.1 Error Types

- `CapsuleError.dependencyUnavailable`: Required system library missing.
- `CapsuleError.determinismViolation`: Tier 1 capsule produced non‑identical output (caught by golden tests).
- `CapsuleError.budgetExceeded`: Marshalling budget violated (telemetry).

### 4.2 Fallback Behavior

When a capsule fails or is unavailable, the system should:

1. **Log** a structured error with severity `warning` (non‑critical) or `error` (critical).
2. **Fall back** to Swift implementation if one exists.
3. **Degrade gracefully**: For optional capsules (e.g., MediaFingerprint), skip the operation and continue.

## 5. Validation and Monitoring

### 5.1 Golden‑Corpus Tests

- Each Tier 1 capsule must have a set of golden‑corpus test inputs and expected outputs.
- Tests run in CI and compare capsule output byte‑for‑byte with golden files.
- Any divergence fails the build and requires investigation.

### 5.2 Performance Benchmarks

- Benchmarks compare capsule vs. Swift implementation on realistic workloads.
- Marshalling telemetry is collected and validated against budgets.
- Benchmarks run weekly to detect regressions.

### 5.3 Runtime Telemetry

Capsule wrappers will collect `anigma_capsule_telemetry_t` metrics and emit them to the system’s observability pipeline (`ObservatoriumModule`). Key metrics:

- `abi_calls`, `bytes_copied`, `buffer_allocations`
- `total_duration_ns`
- Violations of marshalling budgets trigger alerts.

## 6. Rollback Plan

If a capsule causes regressions:

1. **Immediate rollback**: Disable capsule via feature flag (environment variable).
2. **Root‑cause analysis**: Investigate using telemetry and logs.
3. **Fix and re‑enable**: After fixing, re‑enable for canary users.

## 7. Documentation Updates

- Update `Docs/CapsuleMarshallingGates.md` with new capsule‑specific gates.
- Add integration examples to relevant module READMEs.
- Document dependency installation instructions for each platform.

## 8. Success Criteria

A capsule is considered successfully integrated when:

- ✅ Passes all golden‑corpus tests (Tier 1 determinism).
- ✅ Meets performance budgets in benchmarks.
- ✅ No regressions in existing integration tests.
- ✅ Deployed to production with zero critical incidents for two weeks.
- ✅ Fallback rate (capsule unavailable) < 1% (where fallback exists).

---

*Last updated: 2026‑01‑12*  
*Author: opencode*  
*Status: Draft for review*