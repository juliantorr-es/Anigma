# Anigma Testing Doctrine

**Document ID:** TESTING-DOCTRINE-2026-001  
**Version:** 1.0  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-03  

---

## Purpose

This doctrine defines Anigma's testing philosophy, test framework migration policy, deterministic test receipt policy, proof artifact policy, and validation expectations. It formalizes Anigma's existing requirement for focused testing, filtered validation, integration proof for substrate/pipeline changes, and proof artifacts before P0 review.

**RULE:** Tests are evidence producers, not just pass/fail gates. All testing infrastructure decisions must align with this doctrine.

---

## 1. Core Testing Principles

### 1.1 Tests as Evidence Producers
- **Tests produce evidence**, not just pass/fail signals.
- Each test must document what behavior it validates.
- Passing tests must generate stable, machine-readable receipts for agent debugging and audit trails.
- Failing tests must clearly classify the failure (compile blocker, test failure, integration failure, environment failure, doctrine violation, or flaky behavior).

### 1.2 Determinism Requirement
- Tests must be deterministic: same input, same output, every time.
- No wall-clock time, no random seeds, no filesystem ordering, no nondeterministic collections.
- Test data must be stable and version-controlled.
- Flaky tests are doctrine violations and must be fixed before merge.

### 1.3 Narrowness and Clarity
- Tests must be narrow, focused, and explain what they validate.
- Do not test implementation details with no behavioral meaning.
- Do not create fake progress by asserting intermediate state mutations.
- Each test case must have a clear behavioral assertion.

### 1.4 Agent Debuggability
- Tests must support agent debugging through stable machine-readable receipts.
- Receipts must name the test source file, target under test, and validated behaviors.
- Debug hints must be stable and useful for agent triage.
- Test output must avoid unbounded raw logs; use structured diagnostics.

### 1.5 Runtime Boundary
- Test infrastructure (test harnesses, receipt writers, artifact helpers) must not leak into production runtime code.
- Test support packages must be separated from production packages.
- No test-only flags or conditional compilation in production code paths.

---

## 2. Framework Policy

### 2.1 Framework Preference
- **New tests should prefer Swift Testing.**
- XCTest remains allowed during migration.
- Swift Testing and XCTest may coexist in the same codebase.
- Migrations must be incremental, one low-risk test target at a time.

### 2.2 Migration Constraints
- Do NOT migrate all test targets in one pass.
- Do NOT combine test migrations with unrelated compile recovery efforts (separate tasks with clear scope).
- Migrations must maintain backward compatibility: existing XCTest tests continue to run.
- Do NOT use migration as an opportunity to loosen assertions or hide failures.

### 2.3 Swift Testing Discovery and Environment
- **Source-Grounded Insight:** SwiftPM manages test discovery for `swift-testing` natively via `TestingSupport.swift` and `SwiftTestCommand.swift`. It injects the `swiftTestingPath` framework dependencies at runtime.
- **Artifact Control:** Because SwiftPM's built-in test runner lacks native support for Anigma's JSON receipt schemas, our custom receipt writer (`TestReceiptWriter`) relies strictly on environment variables (`ANIGMA_TEST_ARTIFACTS_DIR`) to direct structured artifacts out of the test process.
- **Discovery Method:** Rely on `swift test` finding `@Test` macros natively. Do not implement manual test discovery loops for `swift-testing` code.

### 2.4 Adoption
- Use `@Test`, `#expect`, `#require`, and Swift Testing traits where useful.
- Use deterministic test data (no random initialization).
- Emit debug/proof artifacts only behind explicit environment flag or test helper.

---

## 3. Focused Validation Policy

### 3.1 Validation Scope
- Use **filtered test runs** for modified targets and dependent targets.
- Use **broad BackendReadiness or integration suites** only after narrow target validation passes.
- For **MediaCore**, **AnigmaPipeline**, **SaturationSubstrate**, or **zero-copy paths**, require integration proof after narrow validation.
- Do NOT use full-suite runs as a substitute for targeted diagnosis.

### 3.2 Test Filter Usage
- Prefer `swift test --filter <AffectedTarget>` over broad test runs.
- Run narrow validation before broad suites.
- Document filter criteria in commit messages and proof artifacts.

### 3.3 Integration Proof
- Substrate/pipeline changes must be validated with integration tests.
- Proof artifacts must document:
  - Which narrow tests passed
  - Which integration tests passed
  - Which behaviors were validated end-to-end
  - Any environment-specific notes

---

## 4. Deterministic JSON Test Receipt Policy

### 4.1 Receipt Generation
Each migrated Swift Testing test source file **must generate one deterministic agent-readable JSON receipt** every time it runs.

**Receipt Generation Rule:**
- One receipt per test source file
- One receipt per test run
- Same filename on every run
- Overwrites previous receipt

### 4.2 Filename Contract
The JSON filename **must match the Swift test source filename**:

| Swift Source | JSON Receipt |
|---|---|
| `SaturationInferenceCoreTests.swift` | `SaturationInferenceCoreTests.json` |
| `SaturatedModelRegistryTests.swift` | `SaturatedModelRegistryTests.json` |

**Constraints:**
- Do NOT create timestamped filenames (no `SaturationInferenceCoreTests-2026-05-03T09-44.json`).
- Do NOT append run numbers (no `SaturationInferenceCoreTests_run_001.json`).
- Do NOT use UUID-based artifact names.
- Do NOT accumulate artifacts by default.

### 4.3 Default Output Path
```
.build/anigma-test-artifacts/<TestTarget>/<TestFileName>.json
```

**Example:**
```
.build/anigma-test-artifacts/SaturationInferenceCoreTests/SaturationInferenceCoreTests.json
```

### 4.4 Optional Explicit Output Path
If `ANIGMA_TEST_ARTIFACTS_DIR` environment variable is set:
```
ANIGMA_TEST_ARTIFACTS_DIR=/custom/path
→ /custom/path/<TestTarget>/<TestFileName>.json
```

**Preserve target subdirectories** unless explicitly disabled.

**Example:**
```
ANIGMA_TEST_ARTIFACTS_DIR=Docs/proofs/generated
→ Docs/proofs/generated/SaturationInferenceCoreTests/SaturationInferenceCoreTests.json
```

### 4.5 Overwrite Policy
- **Every test run overwrites the same JSON file.**
- No accumulation, no versioning, no run history.
- Atomic writes ensure consistency.

### 4.6 JSON Schema: `anigma.test.receipt.v1`

#### Required Fields

```json
{
  "schema": "anigma.test.receipt.v1",
  "testTarget": "SaturationInferenceCoreTests",
  "sourceFile": "SaturationInferenceCoreTests.swift",
  "artifactFile": ".build/anigma-test-artifacts/SaturationInferenceCoreTests/SaturationInferenceCoreTests.json",
  "status": "passed",
  "summary": "All test cases passed; 5 test(s) executed, 0 failed, 0 skipped",
  "validatedBehaviors": [
    "correct inference on deterministic data",
    "expected performance bounds met",
    "no memory leaks in saturation loop"
  ],
  "debugHintsForAgents": [
    "See validatedBehaviors for confirmed functionality.",
    "Check diagnostics.failed for failure details.",
    "Review relatedFiles for implementation under test."
  ],
  "relatedFiles": [
    "Packages/SaturationInferenceCore/Tests/SaturationInferenceCoreTests/SaturationInferenceCoreTests.swift",
    "Packages/SaturationInferenceCore/Sources/SaturationInferenceCore/SaturatedInference.swift"
  ],
  "diagnostics": {
    "testCount": 5,
    "passed": 5,
    "failed": 0,
    "skipped": 0,
    "durationSeconds": 2.341
  },
  "canonicalPromotion": {
    "eligible": true,
    "promotedTo": null,
    "promotionGate": "manual_review"
  }
}
```

#### Field Definitions

| Field | Type | Required | Description |
|---|---|---|---|
| `schema` | String | Yes | Fixed: `"anigma.test.receipt.v1"` |
| `testTarget` | String | Yes | Target name (e.g., `SaturationInferenceCoreTests`) |
| `sourceFile` | String | Yes | Source filename (e.g., `SaturationInferenceCoreTests.swift`) |
| `artifactFile` | String | Yes | Path to this receipt file (relative or absolute) |
| `status` | Enum | Yes | One of: `passed`, `failed`, `error`, `skipped` |
| `summary` | String | Yes | Human-readable summary (test count, pass/fail counts) |
| `validatedBehaviors` | Array[String] | Yes | List of validated behaviors (sorted) |
| `debugHintsForAgents` | Array[String] | Yes | Stable debugging hints for agents (sorted) |
| `relatedFiles` | Array[String] | Yes | Source files under test (sorted) |
| `diagnostics` | Object | Yes | Test execution metrics |
| `diagnostics.testCount` | Integer | Yes | Total test count |
| `diagnostics.passed` | Integer | Yes | Passed count |
| `diagnostics.failed` | Integer | Yes | Failed count |
| `diagnostics.skipped` | Integer | Yes | Skipped count |
| `diagnostics.durationSeconds` | Number | Yes | Execution duration (no wall-clock times) |
| `canonicalPromotion` | Object | Yes | Promotion metadata |
| `canonicalPromotion.eligible` | Boolean | Yes | Can this be promoted to Docs/proofs/? |
| `canonicalPromotion.promotedTo` | String or Null | Yes | Path if promoted, or null |
| `canonicalPromotion.promotionGate` | String | Yes | Gate type: `manual_review`, `ci_gate`, or `blocked` |

### 4.7 Determinism Guarantees

All receipts must be deterministic:

- ✓ **Stable filenames** (based on source file name only)
- ✓ **Sorted JSON keys** (alphabetical order)
- ✓ **Stable array ordering** (by test name or alphabetical)
- ✓ **No wall-clock timestamps** (use relative durations only)
- ✓ **No absolute local paths** (relative paths only)
- ✓ **No nondeterministic collections** (no set/dict ordering variation)
- ✓ **Atomic writes** (no partial writes, all-or-nothing)
- ✓ **Parent directories auto-created** (receipt writer handles this)

### 4.8 Failed Test Receipts

When tests fail, the receipt must classify the failure:

```json
{
  "schema": "anigma.test.receipt.v1",
  "status": "failed",
  "summary": "Test failure: 5 total, 1 failed, 0 skipped",
  "failureClassification": "test_failure",
  "failureDetails": {
    "testName": "test_inference_with_deterministic_data",
    "assertionMessage": "Expected 0.95 <= actualAccuracy (0.84) <= 1.0",
    "stackTrace": "..."
  },
  "diagnostics": {
    "testCount": 5,
    "passed": 4,
    "failed": 1,
    "skipped": 0,
    "durationSeconds": 2.115
  },
  ...
}
```

**Failure Classifications:**
- `compile_blocker` — Test target does not compile
- `test_failure` — One or more test assertions failed
- `integration_failure` — Test passed in isolation but failed in integration
- `environment_failure` — Test depends on missing environment setup
- `doctrine_violation` — Test or receipt violates this doctrine
- `flaky_behavior` — Test passed sometimes, failed other times

---

## 5. Docs/proofs Policy

### 5.1 Curated Evidence
- **Curated Docs/proofs/*.md files remain human-reviewed evidence.**
- Tests must NOT write directly to `Docs/proofs/*.md`.
- Proof artifacts are decisions and validation reports, not test output dumps.

### 5.2 Generated Artifacts Directory
- Tests may write JSON receipts to `Docs/proofs/generated/` **only if** `ANIGMA_TEST_ARTIFACTS_DIR` explicitly points there.
- `Docs/proofs/generated/` is a staging area for promoted test artifacts.
- Default behavior writes to `.build/anigma-test-artifacts/` (not Docs/).

### 5.3 Promotion Workflow
1. Test runs and writes receipt to `.build/anigma-test-artifacts/<TestTarget>/<TestFileName>.json` (default).
2. Optional: Use `Scripts/promote_test_artifacts.py` to move receipts to `Docs/proofs/generated/`.
3. Optional: Manually curate receipts into `Docs/proofs/` as human-reviewed evidence.
4. **Promotion requires explicit gate:** manual review, CI check, or automation.

### 5.4 Directory Structure

```
Docs/proofs/
├── *.md                              # Curated human-reviewed proofs
├── generated/                        # Staged test artifacts (promoted or temporary)
│   ├── SaturationInferenceCoreTests/
│   │   └── SaturationInferenceCoreTests.json
│   └── SaturatedModelRegistryTests/
│       └── SaturatedModelRegistryTests.json
└── (no tests write here by default)

.build/anigma-test-artifacts/        # Default test artifact output
├── SaturationInferenceCoreTests/
│   └── SaturationInferenceCoreTests.json
└── SaturatedModelRegistryTests/
    └── SaturatedModelRegistryTests.json
```

---

## 6. TestReceiptWriter Policy

### 6.1 Placement
- `TestReceiptWriter` belongs in **test support packages**, not production runtime packages.
- Test support must be separated from production code.
- No conditional compilation or test-only flags in production.

### 6.2 API Contract

```swift
public struct TestReceiptWriter {
    /// Derive artifact filename from #file parameter
    /// Example: "/path/SaturationInferenceCoreTests.swift" -> "SaturationInferenceCoreTests.json"
    public static func write(
        receipt: TestReceipt,
        sourceFile: String = #file,
        testTarget: String,
        outputDir: String? = nil
    ) throws
    
    /// Finalize test receipt after all assertions complete
    public static func finalize(
        receipt: inout TestReceipt,
        durationSeconds: TimeInterval
    )
}
```

### 6.3 Implementation Requirements

- **Filename derivation:** Extract filename from `#file` parameter (e.g., `/path/SaturationInferenceCoreTests.swift` → `SaturationInferenceCoreTests.json`).
- **Atomic writes:** Use atomic file operations (e.g., write-to-temp, rename).
- **Directory creation:** Create parent directories if needed.
- **Path normalization:** Normalize paths (remove `..`, resolve symlinks).
- **JSON serialization:** Sort keys alphabetically, stable ordering for arrays.
- **Overwrite behavior:** Always overwrite existing files; no append or versioning.

### 6.4 Environment Variable Support

```bash
# Default: write to .build/anigma-test-artifacts/
swift test --target SaturationInferenceCoreTests

# Custom directory with target subdirs preserved
ANIGMA_TEST_ARTIFACTS_DIR=Docs/proofs/generated \
  swift test --target SaturationInferenceCoreTests

# Read from environment in test code:
let artifactDir = ProcessInfo.processInfo.environment["ANIGMA_TEST_ARTIFACTS_DIR"] ?? ".build/anigma-test-artifacts"
```

---

## 7. Failure Classification Policy

All test failures must be classified:

| Classification | Remediation | CI Action |
|---|---|---|
| `compile_blocker` | Fix source code; do not merge | Fail build |
| `test_failure` | Fix test or implementation | Fail build |
| `integration_failure` | Add environment setup or integration test | Fail build |
| `environment_failure` | Document and fix environment | Fail or warn |
| `doctrine_violation` | Refactor test/receipt to comply | Fail build |
| `flaky_behavior` | Fix nondeterminism; rerun until stable | Fail build, rerun |

---

## 8. Acceptance Criteria for Testing Changes

Any testing infrastructure change must prove:

1. **Backward Compatibility**
   - Existing XCTest tests still run and pass.
   - No changes to test semantics or assertion meanings.
   - No loosening of assertions.

2. **Deterministic Receipt Generation**
   - One migrated test generates `<TestFileName>.json`.
   - Receipt follows `anigma.test.receipt.v1` schema.
   - All fields are populated and sorted.

3. **Overwrite Behavior**
   - Re-running test overwrites the same JSON file.
   - No timestamped filenames or run numbers.
   - No artifact accumulation by default.

4. **Docs/proofs Integrity**
   - Curated `Docs/proofs/*.md` is not mutated.
   - `Docs/proofs/generated/` exists but is empty by default.
   - Promotion requires explicit environment variable or script.

5. **Production Boundary**
   - No test infrastructure in production packages.
   - No conditional compilation in runtime code.
   - Test support is clearly separated.

6. **Validation Sequence**
   - Narrow target validation passes before broad suites.
   - Proof artifacts document validated behaviors.
   - Failure classification is clear.

---

## 9. Relationship to CI/CD

This doctrine aligns with and clarifies evidence expectations for:

- **anigma doctor** — Validates codebase state before tests run.
- **validate_exported_imports.py** — Enforces import boundaries.
- **validate_no_cycles.py** — Detects dependency cycles.
- **validate_tiers.py** — Validates tier boundary dependencies.
- **swift test --filter \<AffectedTarget\>** — Runs narrow test suite.
- **BackendReadiness scripts** — Validates end-to-end integration.

**The doctrine does not replace these gates; it clarifies what evidence they require.**

---

## 10. Cross-Links and Related Documents

### Canonical References
- [DOCTRINE_INDEX.md](../architecture/DOCTRINE_INDEX.md) — Canonical doctrine registry
- [VERIFICATION_PROFILES.md](./VERIFICATION_PROFILES.md) — Test verification and profiling
- [GIT_COMMIT_AND_REMOTE_DOCTRINE.md](./GIT_COMMIT_AND_REMOTE_DOCTRINE.md) — Commit evidence policy
- [TIER_GOVERNANCE.md](./TIER_GOVERNANCE.md) — Tier boundary validation

### Implementation Guidance
- [Swift Testing documentation](https://developer.apple.com/documentation/testing)
- [Determinism in Testing — Best Practices](../reference/determinism-in-testing.md) (if exists)

### Related Tasks
- TD: Migrate Anigma test proof surfaces from XCTest to Swift Testing
- P0: BackendReadiness integration suite validation
- TD: TestReceiptWriter implementation and integration

---

## 11. Glossary

| Term | Definition |
|---|---|
| **Test Receipt** | Deterministic JSON file generated by each test run, containing schema, behaviors, diagnostics, and promotion metadata. |
| **Proof Artifact** | Human-reviewed evidence of completed work (code review notes, integration test results, architecture decisions). |
| **Test Target** | Swift package test target (e.g., `SaturationInferenceCoreTests`). |
| **Evidence Producer** | Test that generates actionable, machine-readable output (receipts, logs, metrics) for agent/human triage. |
| **Doctrine Violation** | Test or receipt that violates policies in this doctrine (e.g., nondeterminism, production leakage, ambiguous assertions). |
| **Filtered Test Run** | Narrow test execution using `swift test --filter <AffectedTarget>` instead of full suite. |
| **Promotion** | Moving test artifacts from `.build/anigma-test-artifacts/` to `Docs/proofs/generated/` or curated `Docs/proofs/`. |

---

## 12. Doctrine Version History

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-05-03 | Initial doctrine: core principles, framework policy, receipt policy, Docs/proofs policy, acceptance criteria. |

---

**Status:** ACTIVE  
**Next Review:** 2026-08-03 (after first Swift Testing migration completes)
