//
//  SalesforceConnector.swift
//  AnigmaCorporate
//
//  Created by Anigma Agent.
//

import Foundation
import AnigmaCore
import HarmoniaModule
import AnigmaSystemSpine

public actor SalesforceConnector: ConnectorProtocol {
    public let config: ConnectorConfig
    private var accessToken: ConnectorAccessToken?
    private let session: URLSession

    // Governance State
    private var _identity: ConnectorIdentity
    private var _permissionScope: PermissionScope
    private var _policyPosture: PolicyPosture

    public var identity: ConnectorIdentity { get { _identity } }
    public var permissionScope: PermissionScope { get { _permissionScope } }
    public var policyPosture: PolicyPosture { get { _policyPosture } }

    public init(config: ConnectorConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session

        self._identity = ConnectorIdentity(
            connectorType: config.type,
            version: "1.0.0",
            clientId: config.clientId,
            tenantId: config.tenantId,
            userId: "pending",
            grantedScopes: config.scopes
        )
        self._permissionScope = PermissionScope(
            connectedSources: [],
            inclusions: ["Account", "Opportunity"],
            exclusions: []
        )
        self._policyPosture = PolicyPosture(
            isLocalOnly: false,
            isNetworkAllowed: true,
            retentionPolicy: "default",
            allowDerivedArtifacts: true
        )
    }

    public func connect() async throws {
        let token = try await config.resolveAccessToken()
        self.accessToken = token

        self._identity = ConnectorIdentity(
            connectorType: config.type,
            version: "1.0.0",
            clientId: config.clientId,
            tenantId: config.tenantId,
            userId: "sf_user",
            grantedScopes: config.scopes
        )
    }

    public func sourceInventory() async throws -> [ExternalRef] {
        guard accessToken != nil else { return [] }
        return [
            ExternalRef(systemId: "salesforce", externalId: "001xxxxxx", name: "Acme Corp", type: "Account"),
            ExternalRef(systemId: "salesforce", externalId: "006xxxxxx", name: "Big Deal", type: "Opportunity")
        ]
    }

    public func sync(track: SyncTrackSnapshot) async throws {
        guard let token = accessToken else { throw CorporateError.unauthorized("Not connected") }

        switch track.kind {
        case .browse:
            // Query recent Accounts and Opportunities
            let query = "SELECT Id, Name, Type FROM Account ORDER BY LastModifiedDate DESC LIMIT 20"

            let url = config.apiEndpoint.appendingPathComponent("services/data/v57.0/query").appending(queryItems: [URLQueryItem(name: "q", value: query)])

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            let (_, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw CorporateError.networkError("Failed to query Salesforce")
            }
            // Process data...

        default:
            break
        }
    }

    public func execute(intent: any GovernanceIntent) async throws -> Data {
        guard let token = accessToken else { throw CorporateError.unauthorized("Not connected") }

        if let updateIntent = intent as? UpdateRecordIntent {
            let receipt = try await updateRecord(intent: updateIntent, token: token)
            return try JSONEncoder().encode(receipt)
        }

        throw CorporateError.invalidConfiguration("Unsupported intent type: \(type(of: intent))")
    }

    private func updateRecord(intent: UpdateRecordIntent, token: ConnectorAccessToken) async throws -> ReceiptStruct {
        // Assuming recordId is SObject ID. We need to know the SObject Type.
        // For this prototype, we'll try to infer or assume Account if not specified in intent (which it isn't).
        // In a real app, UpdateRecordIntent should probably have an objectType field.
        // I'll assume "Account" for now as a fallback, or try to parse it from ID if possible (Salesforce IDs have prefixes).
        // 001 is Account.

        let objectType = intent.recordId.hasPrefix("001") ? "Account" : "Opportunity" // Simplified heuristic

        let url = config.apiEndpoint.appendingPathComponent("services/data/v57.0/sobjects/\(objectType)/\(intent.recordId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONSerialization.data(withJSONObject: intent.fields)

        let (_, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 204 else {
            throw CorporateError.networkError("Failed to update record")
        }

        return ReceiptStruct(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "anigma",
            action: "update_salesforce",
            status: .success,
            details: ["intent_id": intent.id.uuidString, "record_id": intent.recordId]
        )
    }
}
