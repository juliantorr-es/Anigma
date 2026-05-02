import Testing
@testable import AnigmaPrimitives
import Foundation

struct EntityIdTests {
    @Test func testEntityIdUniqueness() {
        let id1 = EntityId()
        let id2 = EntityId()
        #expect(id1 != id2)
    }
}
