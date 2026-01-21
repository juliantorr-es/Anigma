import XCTest

@testable import AnigmaAppMac

final class ResilienceTests: XCTestCase {
    func testWithRetrySuccess() async throws {
        var attempts = 0
        let result = try await withRetry(maxAttempts: 3, initialDelay: 0.1) {
            attempts += 1
            return "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 1)
    }

    func testWithRetryFailure() async throws {
        var attempts = 0
        do {
            _ = try await withRetry(maxAttempts: 3, initialDelay: 0.1) {
                attempts += 1
                throw NSError(domain: "test", code: 1)
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(attempts, 3)
        }
    }
}
