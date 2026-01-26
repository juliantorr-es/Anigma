# Phase 0: Shared Contracts & Enforcement Gates

**Status:** Foundation Layer (Non-negotiable)  
**Gate Requirement:** CI must fail if contracts are violated  
**Merge Requirement:** All Phase 0 contracts merged to main before Phase 1 begins

This document defines the five shared contracts that enable parallel execution without collision. Each contract is owned by one agent and consumed by all downstream phases.

---

## Contract 1: Error Reporting (Agent B Owns)

### Canonical Error Model

All capsules MUST use this error type for user-facing failures:

```swift
/// Canonical capsule error type (Swift side)
public enum CapsuleError: Error, Sendable {
    /// Configuration validation failed before operation
    case invalidConfiguration(reason: String)
    
    /// Runtime operation failed with recoverable state
    case operationFailed(code: UInt32, message: String, context: [String: String])
    
    /// Resource exhausted (memory, handles, connections, disk)
    case resourceExhausted(resource: String, limit: String)
    
    /// Input data format or constraints violated
    case invalidInput(field: String, constraint: String)
    
    /// Underlying native library returned error
    case nativeError(code: Int32, libraryName: String)
    
    /// Timeout or deadline exceeded
    case timeout(operation: String, deadline: TimeInterval)
    
    case internalError(details: String)  // Only for bugs
}
```

### C++ Bridge

```c
typedef enum {
    ANIGMA_CAPSULE_ERR_OK = 0,
    ANIGMA_CAPSULE_ERR_INVALID_CONFIG = 1,
    ANIGMA_CAPSULE_ERR_OPERATION_FAILED = 2,
    ANIGMA_CAPSULE_ERR_RESOURCE_EXHAUSTED = 3,
    ANIGMA_CAPSULE_ERR_INVALID_INPUT = 4,
    ANIGMA_CAPSULE_ERR_NATIVE_ERROR = 5,
    ANIGMA_CAPSULE_ERR_TIMEOUT = 6,
    ANIGMA_CAPSULE_ERR_INTERNAL = 7,
} anigma_capsule_error_code_t;

typedef struct {
    anigma_capsule_error_code_t code;
    const char* message;          // max 256 bytes
    const char* context;          // JSON blob, max 512 bytes
} anigma_capsule_error_t;
```

### Enforcement Rule (CI)

**GATE_ERROR_MODEL**: Any `throw SomeRandomError()` or `NSError(...)` in a capsule public API is a CI failure with output:

```
❌ GATE_ERROR_MODEL FAILED
   File: Packages/FooCapsule/Sources/FooCapsule.swift:42
   Reason: Public API throws non-canonical error type
   Fix: Use CapsuleError, or add suppression with explicit justification
```

### Rationale

- Errors are part of the contract, not implementation detail
- Serialization to daemon logs requires predictable structure
- Correlation with diagnostics spans requires code uniformity

---

## Contract 2: Diagnostics Observability (Agent C Owns)

### Canonical Diagnostics API

All capsules MUST emit structured events through this interface:

```swift
/// Standard diagnostics event source for capsules
public protocol CapsuleDiagnostics: Sendable {
    /// Emit a diagnostic event tied to a job/correlation ID
    func event(
        level: DiagnosticLevel,      // .debug, .info, .warning, .error
        category: String,             // e.g., "textpipeline.unicode", "pdf.render"
        message: String,
        correlationID: String,        // Job ID or request ID
        duration: TimeInterval?,      // If measuring an operation
        tags: [String: String]?       // Custom metadata
    )
    
    /// Mark the start of a traced operation (returns token for span)
    func beginSpan(
        name: String,
        category: String,
        correlationID: String
    ) -> DiagnosticSpan
}

public protocol DiagnosticSpan: Sendable {
    func end(status: SpanStatus)
    func addTag(key: String, value: String)
}

public enum DiagnosticLevel: String, Sendable {
    case debug, info, warning, error
}

public enum SpanStatus: String, Sendable {
    case ok, failed, timeout
}
```

### Required Redaction Rules

```swift
/// Patterns that MUST be redacted before emission
public struct DiagnosticRedactionRules: Sendable {
    // Always redacted:
    static let passwords = #"password\s*=\s*[^\s]+"#
    static let secrets = #"secret\s*=\s*[^\s]+"#
    static let apiKeys = #"api[_-]?key\s*=\s*[^\s]+"#
    static let tokens = #"token\s*=\s*[^\s]+"#
    
    // Never logged (structural data):
    static let neverLog = ["userData", "embeddings", "modelWeights"]
}
```

### Correlation ID Propagation (Shared with Agent G)

- Every job in the daemon gets a UUID correlation ID at entry
- Daemon passes correlation ID to capsule init or per-operation call
- Capsule emits all diagnostics with that correlation ID
- Daemon collects spans by correlation ID into one receipt

### Enforcement Rule (CI)

**GATE_DIAGNOSTICS_CONFORMANCE**: Any capsule source file that uses `print()`, `NSLog()`, or `os_log()` directly is CI failure:

```
❌ GATE_DIAGNOSTICS_CONFORMANCE FAILED
   File: Packages/FooCapsule/Sources/FooCapsule.swift:123
   Reason: Direct logging detected; use CapsuleDiagnostics instead
   Fix: Replace print/NSLog with diagnostics.event(...)
```

### Rationale

- Centralized observability enables correlation across daemon jobs
- Redaction rules prevent accidental secret leakage
- Structured tags enable dashboards and analysis

---

## Contract 3: Testing Harness (Agent F Owns)

### Minimum Test Surface by Tier

**Tier 5 and Tier 3 Capsules** must include at least these test categories:

1. **Contract Tests** (Assert error types and messages match spec)
   ```swift
   func testInvalidInputErrorMessage() {
       XCTAssertThrowsError(try capsule.operation(invalid)) { error in
           XCTAssertTrue(error is CapsuleError)
           if case .invalidInput(let field, let constraint) = error as? CapsuleError {
               XCTAssert(field == "expectedField")
           }
       }
   }
   ```

2. **Golden Tests** (Deterministic byte-level comparison)
   ```swift
   func testOutputIsCanonical() {
       let output = try capsule.process(input)
       let golden = loadGolden("textpipeline_unicode_nfkc.golden")
       XCTAssertEqual(output, golden)
   }
   ```

3. **Edge Case Tests** (Empty, massive, malformed inputs)
   ```swift
   func testEmptyInput() { }
   func testMaxSizeInput() { }
   func testMalformedEncoding() { }
   ```

### Golden Test Storage

```
Packages/FooCapsule/Tests/
├── Golden/
│   ├── textpipeline_unicode_nfkc.golden
│   ├── pdf_extraction_simple.golden
│   └── README.md (documents corpus version)
├── FooCapsuleTests.swift
└── FooCapsuleGoldenTests.swift
```

### CI Enforcement Rule

**GATE_TEST_COVERAGE**: 
- Tier 5 capsules: CI fails if test count < 15 or coverage < 80%
- Tier 3 capsules: CI fails if test count < 10 or coverage < 60%
- Tier 2+ capsules: optional in Phase 0, enforced later

Report format (required for each PR):
```
✅ GATE_TEST_COVERAGE PASSED
   MediaFingerprintCapsule: 24 tests, 82% coverage, 3 golden
   VectorIndexCapsule: 15 tests, 71% coverage, 2 golden
```

### Rationale

- Golden tests catch determinism regressions
- Contract tests prevent error type drift
- Coverage gates prevent untested paths

---

## Contract 4: Build Hygiene (Agent E Owns)

### Forbidden Patterns (Hardcoded Paths, Undocumented Flags)

**Blocked Patterns:**

```swift
// ❌ BANNED: Hardcoded paths
"/opt/homebrew/lib/libicu.a"
"/usr/local/opt/..."
Environment.HOME + "/Libraries/..."

// ❌ BANNED: Undocumented linker flags without justification
.unsafeFlags(["-Wl,--some-flag"])  // No comment explaining why
.linkedLibrary("mysterious_lib")   // Where does it come from?

// ✅ ALLOWED: Well-documented external dependencies
.binaryTarget(name: "zstd", ...)   // From swiftpm registry
.unsafeFlags(["-strict-concurrency=minimal"])  // CI gating reason
```

### Linker Configuration Template

Every target binding C++ must declare:

```swift
.target(
    name: "FooCapsule",
    dependencies: [...],
    linkerSettings: [
        // EXTERNAL_DEP: zstd (from homebrew or pkg-config)
        // REASON: Compression library, 2-5x faster than Swift
        // BUILD_ENV: MacOS 13+, Linux x86_64 (tested)
        .linkedLibrary("z"),
        .linkedLibrary("zstd"),
        
        // UNSAFE_FLAG: Concurrency bypass for FFmpeg C API
        // REASON: FFmpeg is not Sendable, wrapped in actor
        // REVIEW: Approved by concurrency lead
        .unsafeFlags(["-Xcc", "-Wno-error=deprecated-declarations"]),
    ]
)
```

### CI Enforcement Rule

**GATE_BUILD_HYGIENE**: 

```bash
# Check 1: No hardcoded /opt/homebrew paths
if grep -r "/opt/homebrew" Package.swift; then
    FAIL "Hardcoded homebrew path detected"
fi

# Check 2: Every unsafeFlags has a justification comment
if grep -B2 "unsafeFlags\|linkedLibrary" Package.swift | grep -v "^--" | grep -v "REASON\|EXTERNAL_DEP"; then
    FAIL "Linker setting missing justification comment"
fi
```

Report:
```
✅ GATE_BUILD_HYGIENE PASSED
   No hardcoded paths detected
   All linker settings documented
   Dependencies: zstd, ICU, PDFium (via system pkg-config)
```

### Rationale

- Reproducible builds require documented dependencies
- Hardcoded paths break on different machines
- Undocumented flags are tech debt

---

## Contract 5: Capsule Tier Enforcement (Agent A Owns)

### Tier Validation Rules

A capsule's tier is determined by its minimum operational surface:

**Tier 5 (Production Ready):**
- ✅ 80%+ test coverage (golden + contract + edge case)
- ✅ All public APIs use CapsuleError
- ✅ All operations emit CapsuleDiagnostics events
- ✅ Zero hardcoded paths or undocumented linker flags
- ✅ Zero @unchecked Sendable in public API

**Tier 3 (Core Functional):**
- ✅ 60%+ test coverage (at least golden + contract tests)
- ✅ All public APIs use CapsuleError
- ✅ Core operations emit CapsuleDiagnostics events
- ✅ Documented dependencies and linker flags
- ✅ Minimal @unchecked Sendable (justified in code)

**Tier 2 (Scaffolding):**
- ✅ 40%+ test coverage (basic contract tests)
- ✅ Error handling partially standardized
- ✅ Some diagnostics instrumentation
- ⚠️ May have some hardcoded paths (planned for future cleanup)

**Tier 1 (Specification):**
- ✅ Exists and compiles
- ✅ No requirement for tests or diagnostics yet
- ⚠️ Blocked from daemon registration

### CI Enforcement Rule

**GATE_TIER_VALIDATION**:

```bash
# Tier validation script
for capsule in $(ls Packages/); do
    TIER=$(grep "tier:" Packages/$capsule/MANIFEST.toml || echo "unknown")
    
    if [[ "$TIER" == "tier: 5" ]]; then
        require_coverage 80 $capsule || FAIL
        require_error_model $capsule || FAIL
        require_diagnostics $capsule || FAIL
    elif [[ "$TIER" == "tier: 3" ]]; then
        require_coverage 60 $capsule || FAIL
        require_error_model $capsule || FAIL
    fi
done
```

Every capsule must have a MANIFEST file:

```toml
[metadata]
name = "TextPipelineCapsule"
tier = 3
owner = "Agent H"

[requirements]
min_test_coverage = 0.60
min_error_conformance = true
diagnostics_instrumentation = true

[readiness]
status = "ready_for_phase_1"
merged_at = "2026-01-27"
```

### Rationale

- Tier is observable, not aspirational
- Blocks stubs from poisoning integration work
- Owner is accountable for gate compliance

---

## Phase 0 Merge Gate (Agent A Controls)

Before Phase 1 starts, **all five contracts must be**:

1. ✅ Defined in code (not just documents)
2. ✅ Enforced by CI (not advisory)
3. ✅ Merged to main
4. ✅ In effect for new commits

The Phase 0 PR itself must demonstrate:

- ✅ One sample capsule (e.g., MediaFingerprintCapsule) passing all gates
- ✅ CI job succeeds and shows the gate reports
- ✅ One commit shows CI **failing** on a violation, then passing on fix

```
Before: ❌ GATE_ERROR_MODEL failed (throwing NSError)
After:  ✅ GATE_ERROR_MODEL passed (using CapsuleError)
```

### Merge Criteria

- [ ] All five contract definitions in code
- [ ] CI jobs implement gates (not just warnings)
- [ ] Sample capsule passes all gates
- [ ] Enforcement documentation in repo
- [ ] No Phase 1 work begins until Phase 0 gate is merged

---

## How Phases 1-5 Use These Contracts

Each downstream phase assumes these contracts are **locked and enforced**:

- **Phase 1** (Testing Harness): Builds on Contract 3 (testing) and extends CI
- **Phase 2** (Observability): Builds on Contract 2 (diagnostics) and wires daemon integration
- **Phase 3** (Swift 6): Builds on Contract 1 (error handling) with concurrency wrappers
- **Phase 4** (Benchmarks): Builds on Contract 3 (tests) with perf harness
- **Phase 5** (Vertical Slice): Uses all five contracts to coordinate agent work

---

## Agent Coordination Rules

### Weekly Sync Points

- **Monday 10 AM:** Phase leads agree on contract changes (no PRs until agreed)
- **Wednesday 2 PM:** Merge blockers (who's waiting on whom)
- **Friday 4 PM:** Week readiness (what's blocked, what's unblocked next week)

### Merge Order (Dependency Chain)

1. Agents B, C, E push to branches (parallel)
2. Agent A creates main PR including B, C, E as dependencies
3. Agent D creates capsule template PR once B, C exist
4. Once A, B, C, D, E are merged → Phase 0 gate is live
5. Phase 1 can kick off only after Phase 0 gate is merged

---

## Next Steps

- [ ] Agent A creates CI enforcement scaffolding (day 1)
- [ ] Agents B, C, E push branches with contract implementations (day 1-2)
- [ ] Agent D creates template after B, C merge (day 2-3)
- [ ] Phase 0 PR ready for merge review (day 3-4)
- [ ] Phase 0 gate live and enforced (day 4)
- [ ] Phase 1 kickoff (day 5)

---

**Document Owner:** Agent A (CI Gatekeeper)  
**Last Updated:** 2026-01-27  
**Status:** Draft → Ready for Implementation
