import XCTest
@testable import AnigmaMCPModule

final class AdaptiveThrottleTests: XCTestCase {

    func testGreenZoneAcceptsAll() async {
        let throttle = AdaptiveThrottle()

        // At 50% load, all priorities should be accepted
        let priorities: [RequestPriority] = [.critical, .high, .normal, .low]
        for priority in priorities {
            let decision = await throttle.evaluateRequest(priority: priority, queueLoad: 0.5)
            XCTAssertTrue(decision.accept)
            XCTAssertEqual(decision.throttleHint.loadZone, .green)
        }
    }

    func testYellowZoneAcceptsAllWithReason() async {
        let throttle = AdaptiveThrottle()

        // At 80% load (Yellow), all should be accepted but with a reason
        let decision = await throttle.evaluateRequest(priority: .normal, queueLoad: 0.8)
        XCTAssertTrue(decision.accept)
        XCTAssertEqual(decision.throttleHint.loadZone, .yellow)
        XCTAssertNotNil(decision.reason)
    }

    func testRedZoneThrottling() async {
        let throttle = AdaptiveThrottle()

        // At 90% load (Red): High/Critical accepted, Normal/Low rejected
        let critical = await throttle.evaluateRequest(priority: .critical, queueLoad: 0.9)
        XCTAssertTrue(critical.accept)

        let high = await throttle.evaluateRequest(priority: .high, queueLoad: 0.9)
        XCTAssertTrue(high.accept)

        let normal = await throttle.evaluateRequest(priority: .normal, queueLoad: 0.9)
        XCTAssertFalse(normal.accept)

        let low = await throttle.evaluateRequest(priority: .low, queueLoad: 0.9)
        XCTAssertFalse(low.accept)
    }

    func testBlackZoneThrottling() async {
        let throttle = AdaptiveThrottle()

        // At 98% load (Black): Only Critical accepted
        let critical = await throttle.evaluateRequest(priority: .critical, queueLoad: 0.98)
        XCTAssertTrue(critical.accept)

        let high = await throttle.evaluateRequest(priority: .high, queueLoad: 0.98)
        XCTAssertFalse(high.accept)
    }
}
