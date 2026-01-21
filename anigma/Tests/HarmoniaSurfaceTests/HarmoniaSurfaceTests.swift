// swiftlint:disable explicit_type_interface
import XCTest
import HarmoniaSurface

internal final class HarmoniaSurfaceTests: XCTestCase {
    internal func testConcurrencyControllerInitialization() {
        let controller = ConcurrencyController()
        XCTAssertNotNil(controller)
    }

    internal func testConcurrencyControllerStats() async {
        let controller = ConcurrencyController()
        let stats = await controller.stats()
        XCTAssertEqual(stats.limits[.chat], 3)
        XCTAssertEqual(stats.limits[.reasoner], 2)
        XCTAssertEqual(stats.limits[.oracle], 1)
    }

    internal func testRecordRequest() async {
        let controller = ConcurrencyController()
        await controller.recordRequest(.chat)
        let stats = await controller.stats()
        XCTAssertEqual(stats.inFlight[.chat], 1)
    }
}