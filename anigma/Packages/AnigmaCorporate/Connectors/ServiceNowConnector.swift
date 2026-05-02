//
//  ServiceNowConnector.swift
//  AnigmaCorporate
//
//  Created by Anigma Agent.
//

import Foundation
import AnigmaCore
import HarmoniaV2Surface
import AnigmaSystemSpine

public actor ServiceNowConnector: ConnectorProtocol {
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
            inclusions: ["incident"],
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
            userId: "sn_user",
            grantedScopes: config.scopes
        )
    }

    public func sourceInventory() async throws -> [ExternalRef] {
        guard accessToken != nil else { return [] }
        return [
            ExternalRef(systemId: "servicenow", externalId: "incident", name: "Incidents", type: "table"),
            ExternalRef(systemId: "servicenow", externalId: "change_request", name: "Change Requests", type: "table")
        ]
    }

    public func sync(track: SyncTrackSnapshot) async throws {
        guard let token = accessToken else { throw CorporateError.unauthorized("Not connected") }

        switch track.kind {
        case .browse:
            // Fetch incidents assigned to user or open
            // Simplified query
            var components = URLComponents(url: config.apiEndpoint.appendingPathComponent("now/table/incident"), resolvingAgainstBaseURL: true)
            components?.queryItems = [
                URLQueryItem(name: "sysparm_query", value: "active=true"),
                URLQueryItem(name: "sysparm_fields", value: "sys_id,number,short_description,state"),
                URLQueryItem(name: "sysparm_limit", value: "50")
            ]

            guard let url = components?.url else {
                throw CorporateError.invalidConfiguration("Invalid URL")
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            let (_, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw CorporateError.networkError("Failed to fetch incidents")
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
        // Assuming recordId is table/sys_id format or we default to incident
        // For simplicity, assuming incident table
        let url = config.apiEndpoint.appendingPathComponent("now/table/incident/\(intent.recordId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONSerialization.data(withJSONObject: intent.fields)

        let (_, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw CorporateError.networkError("Failed to update record")
        }

        return ReceiptStruct(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "anigma",
            action: "update_record",
            status: .success,
            details: ["intent_id": intent.id.uuidString, "record_id": intent.recordId]
        )
    }
}
