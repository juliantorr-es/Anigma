# SwiftPM Test Behavior

**Source Repository:** `swiftlang/swift-package-manager`
**Commit:** `770f14b0a593399b78787ecd728f35e870c4cf6e`
**Key File:** `Sources/Commands/Utilities/TestingSupport.swift`
**Key Symbols:** `getSwiftTestingSuites` (L196)

## Test Discovery and Framework Support
SwiftPM has integrated support for `swift-testing`. In `Sources/Commands/Utilities/TestingSupport.swift` (L196), `getSwiftTestingSuites` executes test products to natively discover tests (e.g., using `--list-tests` on Linux or a bundled testing helper on macOS). SwiftPM injects the `swiftTestingPath` framework dependencies at runtime.

This confirms SwiftPM and `swift test` have full path attachment and macro discovery support for Swift Testing.

## Anigma Doctrine Takeaways
- **Swift Testing Migration:** Anigma's test suites can rely on `swift test` transparently finding `@Test` macros natively. There is no need to implement custom test discovery loops for `swift-testing` code.
- **Artifact Support:** While SwiftPM / `swift test` has native Swift Testing path attachment support, it does not support Anigma's custom `anigma.test.receipt.v1` JSON receipt schema. Therefore, Anigma's `TestReceiptWriter` remains explicitly required to direct structured artifacts out of the test process via the `ANIGMA_TEST_ARTIFACTS_DIR` environment variable.
