import XCTest
@testable import AnigmaMCPModule

final class MCPMetricsTests: XCTestCase {

    func testMetricRecording() async {
        let metrics = MCPMetrics()

        await metrics.recordToolExecution(toolName: "read_file", success: true, durationMs: 50, cacheHit: true)
        await metrics.recordToolExecution(toolName: "read_file", success: true, durationMs: 150, cacheHit: false)
        await metrics.recordToolExecution(toolName: "read_file", success: false, durationMs: 10, cacheHit: false)

        let toolMetrics = await metrics.getToolMetrics("read_file")
        XCTAssertNotNil(toolMetrics)
        XCTAssertEqual(toolMetrics?.callCount, 3)
        XCTAssertEqual(toolMetrics?.errorCount, 1)
        XCTAssertEqual(toolMetrics?.cacheHitCount, 1)
        XCTAssertEqual(toolMetrics?.cacheMissCount, 2)

        // Latency stats
        XCTAssertEqual(toolMetrics?.minLatencyMs, 10)
        XCTAssertEqual(toolMetrics?.maxLatencyMs, 150)
        XCTAssertEqual(toolMetrics?.avgLatencyMs, (50 + 150 + 10) / 3)
    }

    func testOverallMetrics() async {
        let metrics = MCPMetrics()

        await metrics.recordToolExecution(toolName: "tool1", success: true, durationMs: 10)
        await metrics.recordToolExecution(toolName: "tool2", success: false, durationMs: 20)

        let overall = await metrics.getOverallMetrics()
        XCTAssertEqual(overall.totalRequests, 2)
        XCTAssertEqual(overall.totalErrors, 1)
        XCTAssertEqual(overall.errorRate, 0.5)
    }
}
