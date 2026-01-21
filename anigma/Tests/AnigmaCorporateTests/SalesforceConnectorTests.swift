import XCTest
import AnigmaSystemSpine
@testable import AnigmaCorporate

final class MockTokenProvider: ConnectorTokenProvider {
    func accessToken(for config: ConnectorConfig) async throws -> ConnectorAccessToken {
        return ConnectorAccessToken(value: "mock-token", tokenType: "Bearer", expiresAt: Date().addingTimeInterval(3600))
    }
}

final class SalesforceConnectorTests: XCTestCase {
    var session: URLSession!
    var config: ConnectorConfig!

    override func setUp() {
        super.setUp()
        session = .mock
        config = ConnectorConfig(
            type: .salesforce,
            tenantId: "test-tenant",
            clientId: "test-client",
            clientSecret: nil,
            scopes: ["api"],
            apiEndpoint: URL(string: "https://test.salesforce.com")!,
            tokenProvider: MockTokenProvider()
        )
    }

    func testConnectUpdatesIdentity() async throws {
        let connector = SalesforceConnector(config: config, session: session)

        try await connector.connect()

        let identity = await connector.identity
        XCTAssertEqual(identity.userId, "sf_user")
        XCTAssertEqual(identity.connectorType, .salesforce)
    }

    func testSyncPerformQuery() async throws {
        let connector = SalesforceConnector(config: config, session: session)
        try await connector.connect()

        // Mocking the query response
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.host, "test.salesforce.com")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer mock-token")

            let json = """
            {
                "totalSize": 1,
                "done": true,
                "records": [
                    { "attributes": { "type": "Account" }, "Id": "0011", "Name": "Mock Account" }
                ]
            }
            """.data(using: .utf8)!
            guard let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                fatalError("Failed to unwrap response")
            }
            return (response, json)
        }

        let track = SyncTrackSnapshot(
            id: UUID(),
            kind: .browse,
            externalId: "root",
            checkpoint: nil,
            metadata: [:]
        )

        // This will trigger theswitch in sync() for .browse
        try await connector.sync(track: track)

        // Success is implicit if no error thrown
    }

    func testExecuteUpdateRecord() async throws {
        let connector = SalesforceConnector(config: config, session: session)
        try await connector.connect()

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertTrue(request.url!.path.contains("/sobjects/Account/001_id"))

            guard let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil) else {
                fatalError("Failed to unwrap response")
            }
            return (response, nil)
        }

        let intent = UpdateRecordIntent(
            id: UUID(),
            recordId: "001_id",
            fields: ["Name": "New Name"],
            description: "Update account name"
        )

        let data = try await connector.execute(intent: intent)
        let receipt = try JSONDecoder().decode(ReceiptStruct.self, from: data)

        XCTAssertEqual(receipt.status, .success)
        XCTAssertEqual(receipt.details["record_id"], "001_id")
    }
}
