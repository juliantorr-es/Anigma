// swiftlint:disable explicit_type_interface
import XCTest
import HarmoniaMemory

internal final class HarmoniaMemoryTests: XCTestCase {
    internal func testCreateMemoryService() async throws {
        let config = MemoryConfig(databasePath: ":memory:", enableFTS: false)
        let service = try await HarmoniaMemory.createMemoryService(config: config)
        XCTAssertNotNil(service)
    }

    internal func testStoreAndRetrieveObservation() async throws {
        let config = MemoryConfig(databasePath: ":memory:", enableFTS: false)
        let service = try await HarmoniaMemory.createMemoryService(config: config)

        let observation = MemoryObservation(
            sessionId: "test-session",
            tenantId: "test-tenant",
            observationType: .toolCall,
            source: .cli,
            eventData: "{}",
            tags: ["test"]
        )

        try await service.storeObservation(observation)

        let results = try await service.searchObservations(query: "test", sessionId: "test-session")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, observation.id)
    }
}