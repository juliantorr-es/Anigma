import Testing
import Foundation
@testable import ModelRegistry

struct ModelRegistryTests {
    @Test func testModelRegistryStoreInitialization() async throws {
        let storagePath = "/tmp/anigma_models_test.db"
        let store = try await ModelRegistryStore(storagePath: storagePath)
        #expect(store != nil)
    }
}
