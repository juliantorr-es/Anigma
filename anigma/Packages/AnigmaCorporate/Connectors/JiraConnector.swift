//
//  JiraConnector.swift
//  AnigmaCorporate
//
//  Created by Anigma Agent.
//

import Foundation
import AnigmaCore
import HarmoniaV2Surface
import AnigmaSystemSpine

public actor JiraConnector: ConnectorProtocol {
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
            inclusions: ["PROJ-1"],
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
            userId: "jira_user",
            grantedScopes: config.scopes
        )
    }

    public func sourceInventory() async throws -> [ExternalRef] {
        guard accessToken != nil else { return [] }
        return [
            ExternalRef(systemId: "jira", externalId: "PROJ-1", name: "Project Alpha", type: "project"),
            ExternalRef(systemId: "jira", externalId: "PROJ-2", name: "Project Beta", type: "project")
        ]
    }

    public func sync(track: SyncTrackSnapshot) async throws {
        guard let token = accessToken else { throw CorporateError.unauthorized("Not connected") }

        switch track.kind {
        case .browse:
            // Search for issues assigned to user or in specific projects
            // Using JQL
            var components = URLComponents(url: config.apiEndpoint.appendingPathComponent("search"), resolvingAgainstBaseURL: true)
            components?.queryItems = [
                URLQueryItem(name: "jql", value: "assignee = currentUser() ORDER BY updated DESC"),
                URLQueryItem(name: "fields", value: "summary,status,issuetype")
            ]

            guard let url = components?.url else {
                throw CorporateError.invalidConfiguration("Invalid URL")
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")

            let (_, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw CorporateError.networkError("Failed to search issues")
            }
            // Process data...

        default:
            break
        }
    }

    public func execute(intent: any GovernanceIntent) async throws -> Data {
        guard let token = accessToken else { throw CorporateError.unauthorized("Not connected") }

        if let createIntent = intent as? CreateIssueIntent {
            let receipt = try await createIssue(intent: createIntent, token: token)
            return try JSONEncoder().encode(receipt)
        }

        throw CorporateError.invalidConfiguration("Unsupported intent type: \(type(of: intent))")
    }

    private func createIssue(intent: CreateIssueIntent, token: ConnectorAccessToken) async throws -> ReceiptStruct {
        let url = config.apiEndpoint.appendingPathComponent("issue")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "fields": [
                "project": ["key": intent.projectKey],
                "summary": intent.summary,
                "description": intent.issueDescription,
                "issuetype": ["name": intent.issueType]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 201 else {
            throw CorporateError.networkError("Failed to create issue")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let key = json?["key"] as? String ?? ""

        return ReceiptStruct(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "anigma",
            action: "create_issue",
            status: .success,
            details: ["intent_id": intent.id.uuidString, "issue_key": key]
        )
    }
}
