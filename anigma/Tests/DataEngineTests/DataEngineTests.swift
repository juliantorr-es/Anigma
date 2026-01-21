import XCTest
@testable import DataEngine
import DataCore

final class DataEngineTests: XCTestCase {
    func testIngestion() async throws {
        let engine = DataEngine()
        let url = URL(fileURLWithPath: "/tmp/test.csv")
        let artifact = try await engine.ingest(source: url)
        XCTAssertEqual(artifact.type, .raw)
    }

    func testGovernance() async throws {
        let policy = DataGovernancePolicy.strict
        let engine = DataEngine(policy: policy)

        // In a real test we'd verify that transforms require approval
        // For now we just verify we can init with policy
        _ = engine
    }

    func testCache() async throws {
        let engine = DataEngine()
        let viewSpec = ViewSpec(query: "SELECT 1", parameters: [:], filters: [], sort: [], sourceSnapshotId: "1")

        let result1 = try await engine.query(viewSpec: viewSpec)
        let result2 = try await engine.query(viewSpec: viewSpec)

        // In a real test with a mock cache, we'd verify result2 came from cache
        // Here we just verify they return artifacts
        XCTAssertEqual(result1.type, .tabularIR)
        XCTAssertEqual(result2.type, .tabularIR)
    }
}
