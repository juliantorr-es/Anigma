# Testing Doctrine

## Modern Swift Testing Standard

As of April 2026, Anigma has transitioned to the modern **Swift Testing** framework as the primary standard for all verification tasks.

### Core Principles
1.  **Macro-First**: Use `@Suite`, `@Test`, and `@Tag` instead of `XCTestCase` boilerplate.
2.  **Explicit Expectations**: Use `#expect(...)` and `#require(...)` for clear, readable assertions.
3.  **Async-Native**: Leverage native `async/await` support without `XCTestExpectation` complexity.
4.  **Hardware-Saturated Validation**: Tests must verify both portable contract compliance and native backend performance/integrity.

### Implementation Guide

#### New Test Suites
When creating new tests, use the following structure:

```swift
import Testing
@testable import YourModule

@Suite("Feature Name")
struct FeatureTests {
    @Test("Verifies specific behavior")
    func behaviorWorks() async throws {
        let result = try await someAsyncFunction()
        #expect(result.isValid)
    }
    
    @Test("Throws error on invalid input", .tags(.security))
    func errorHandling() async throws {
        await #expect(throws: YourError.self) {
            try await invalidOperation()
        }
    }
}
```

#### Legacy Transition
- **Do not** add new tests to existing `XCTestCase` files.
- When modifying a module with legacy tests, prioritize migrating them to `import Testing`.
- Both runners (XCTest and Swift Testing) are enabled; ensure that `swift test` output is monitored for both.

### Integration with Hardware Saturation
Verification of "saturated" components (e.g., those using Metal, Accelerate, or AVFoundation) must include:
- **Golden Vector Checks**: Compare native output against known portable fixtures.
- **Sequence Integrity**: Use `SaturatedLoggingRing` telemetry to verify execution order.
- **Memory Safety**: Verify that zero-copy handoffs don't result in leaks or double-frees.

---
*Portable by contract, verified by saturation.*
