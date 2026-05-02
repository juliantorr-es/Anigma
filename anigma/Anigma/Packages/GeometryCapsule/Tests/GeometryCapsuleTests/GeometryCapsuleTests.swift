import XCTest
import CapsuleCore
import TelemetryCore
@testable import VizAggregationCapsule

final class VizAggregationCapsuleTests: XCTestCase {
    
    var capsule: VizAggregationCapsule!
    var diagnostics: MockDiagnostics!
    
    override func setUp() async throws {
        diagnostics = MockDiagnostics()
        capsule = try VizAggregationCapsule(id: "test-capsule", diagnostics: diagnostics)
    }
    
    // MARK: - Edge Cases
    
    func testEmojiInput() async throws {
        let input = "🚀✨"
        let result = try await capsule.process(input)
        XCTAssertEqual(result, "✨🚀")
    }
    
    func testLongInput() async throws {
        let input = String(repeating: "x", count: 1024 * 1024)
        let result = try await capsule.process(input)
        XCTAssertEqual(result.count, 1024 * 1024)
    }
}
