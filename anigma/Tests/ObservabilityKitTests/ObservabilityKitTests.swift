// swiftlint:disable explicit_type_interface
import XCTest
@testable import ObservabilityKit

internal final class ObservabilityKitTests: XCTestCase {
    internal func testSharedInstance() {
        let shared = NativeObservability.shared
        XCTAssertNotNil(shared)
    }

    internal func testLogLevelMapping() {
        let levels: [LogLevel] = [.debug, .info, .warn, .error, .critical]
        for level in levels {
            // Ensure mapping does not crash
            _ = level.native
        }
    }

    internal func testLogDoesNotCrash() {
        let logger = NativeObservability()
        logger.log(level: .info, message: "Test message", fields: [:])
    }

    internal func testLogWithFieldsDoesNotCrash() {
        let logger = NativeObservability()
        logger.log(level: .warn, message: "Test with fields", fields: ["key": "value"])
    }
}