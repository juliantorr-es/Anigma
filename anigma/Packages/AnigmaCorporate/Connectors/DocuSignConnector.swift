//
//  DocuSignConnector.swift
//  AnigmaCorporate
//
//  Created by Anigma Agent.
//

import Foundation
import AnigmaCore
import HarmoniaV2Surface
import AnigmaSystemSpine

public actor DocuSignConnector: ConnectorProtocol {
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
            inclusions: ["/"],
            exclusions: []
        )
        self._policyPosture = PolicyPosture(
            isLocalOnly: false,
            isNetworkAllowed: true,
            retentionPolicy: "legal-hold",
            allowDerivedArtifacts: false
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
            userId: "ds_user",
            grantedScopes: config.scopes
        )
    }

    public func sourceInventory() async throws -> [ExternalRef] {
        guard accessToken != nil else { return [] }
        return [
            ExternalRef(systemId: "docusign", externalId: "inbox", name: "Inbox", type: "folder"),
            ExternalRef(systemId: "docusign", externalId: "sent", name: "Sent", type: "folder")
        ]
    }

    public func sync(track: SyncTrackSnapshot) async throws {
        guard let token = accessToken else { throw CorporateError.unauthorized("Not connected") }

        switch track.kind {
        case .browse:
            // List status changes (envelopes changed in last 30 days)
            var components = URLComponents(url: config.apiEndpoint.appendingPathComponent("envelopes"), resolvingAgainstBaseURL: true)

            let dateFormatter = ISO8601DateFormatter()
            let fromDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago

            components?.queryItems = [
                URLQueryItem(name: "from_date", value: dateFormatter.string(from: fromDate)),
                URLQueryItem(name: "status", value: "sent,delivered,completed,declined,voided")
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
                throw CorporateError.networkError("Failed to list envelopes")
            }
            // Process data...

        default:
            break
        }
    }

    public func execute(intent: any GovernanceIntent) async throws -> Data {
        guard let token = accessToken else { throw CorporateError.unauthorized("Not connected") }

        if let sendIntent = intent as? SendEnvelopeIntent {
            let receipt = try await sendEnvelope(intent: sendIntent, token: token)
            return try JSONEncoder().encode(receipt)
        }

        throw CorporateError.invalidConfiguration("Unsupported intent type: \(type(of: intent))")
    }

    private func sendEnvelope(intent: SendEnvelopeIntent, token: ConnectorAccessToken) async throws -> ReceiptStruct {
        let url = config.apiEndpoint.appendingPathComponent("envelopes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "templateId": intent.templateId,
            "emailSubject": intent.subject,
            "status": "sent",
            "templateRoles": intent.recipients.map { ["email": $0, "name": $0, "roleName": "Signer"] }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 201 else {
            throw CorporateError.networkError("Failed to send envelope")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let envelopeId = json?["envelopeId"] as? String ?? ""

        return ReceiptStruct(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "anigma",
            action: "send_envelope",
            status: .success,
            details: ["intent_id": intent.id.uuidString, "envelope_id": envelopeId]
        )
    }
}
