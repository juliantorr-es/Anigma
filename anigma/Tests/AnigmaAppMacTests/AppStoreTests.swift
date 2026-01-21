import XCTest

@testable import AnigmaAppMac
@testable import AnigmaClientKit
@testable import AnigmaHostKit

final class AppStoreTests: XCTestCase {
    @MainActor
    func testInitialState() {
        let store = AppStore()
        XCTAssertTrue(store.isInitializing)
        XCTAssertEqual(store.daemonStatus, "Unknown")
        XCTAssertTrue(store.workspaces.isEmpty)
    }

    @MainActor
    func testFiltering() {
        _ = AppStore()
        // Mock some jobs
        // Since AppStore uses client internally, we might need to mock the client or authority
        // For simple logic tests, we can use the published properties

        // This is a placeholder for more comprehensive mock-based tests
    }
}
