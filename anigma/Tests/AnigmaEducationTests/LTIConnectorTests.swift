import XCTest
import AnigmaSystemSpine
@testable import AnigmaEducation

final class LTIConnectorTests: XCTestCase {

    func testIdentityInitialization() async throws {
        let account = IntegrationAccount(
            id: UUID(),
            accountId: "edu-123",
            tenantId: "ccsf",
            provider: "canvas",
            authType: "oauth2"
        )
        // Note: JobEngine is an actor in AnigmaSystemSpine
        let jobEngine = JobEngine()

        let connector = LTIConnector(account: account, jobEngine: jobEngine)

        let identity = await connector.identity
        XCTAssertEqual(identity.connectorType, .lti)
        XCTAssertEqual(identity.tenantId, "ccsf")
        XCTAssertEqual(identity.clientId, "edu-123")
    }

    func testSourceInventory() async throws {
        let account = IntegrationAccount(
            id: UUID(),
            accountId: "edu-123",
            tenantId: "ccsf",
            provider: "canvas",
            authType: "oauth2"
        )
        let jobEngine = JobEngine()
        let connector = LTIConnector(account: account, jobEngine: jobEngine)

        let inventory = try await connector.sourceInventory()
        XCTAssertEqual(inventory.count, 2)
        XCTAssertEqual(inventory.first?.name, "Intro to CS")
    }
}
