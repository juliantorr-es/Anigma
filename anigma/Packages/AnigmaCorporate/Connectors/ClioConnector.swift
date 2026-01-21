//
//  ClioConnector.swift
//  AnigmaCorporate
//
//  Connector for Clio (Legal Practice Management).
//

import Foundation
import AnigmaSystemSpine
import AnigmaCore

public actor ClioConnector: ConnectorProtocol {
    private let config: ConnectorConfig
    private var accessToken: ConnectorAccessToken?

    public init(config: ConnectorConfig) {
        self.config = config
    }

    public var identity: ConnectorIdentity {
        get async {
            return ConnectorIdentity(
                connectorType: .clio,
                version: "1.0",
                clientId: config.clientId,
                tenantId: config.tenantId,
                userId: "lawyer-1",
                grantedScopes: config.scopes
            )
        }
    }

    public var permissionScope: PermissionScope {
        get async {
            return PermissionScope(
                connectedSources: ["Clio Matters"],
                inclusions: ["/matters"],
                exclusions: []
            )
        }
    }

    public var policyPosture: PolicyPosture {
        get async {
            return PolicyPosture(
                isLocalOnly: false,
                isNetworkAllowed: true,
                retentionPolicy: "legal-hold",
                allowDerivedArtifacts: true
            )
        }
    }

    public func connect() async throws {
        let token = try await config.resolveAccessToken()
        self.accessToken = token
    }

    public func sync(track: SyncTrackSnapshot) async throws {
        guard accessToken != nil else { throw CorporateError.authenticationFailed("Not connected") }
    }

    public func execute(intent: any GovernanceIntent) async throws -> Data {
        throw CorporateError.unsupportedOperation("Clio write-back not implemented")
    }

    public func sourceInventory() async throws -> [ExternalRef] {
        guard accessToken != nil else { return [] }
        return [
            ExternalRef(systemId: "clio", externalId: "matter-123", name: "Smith v. Jones", type: "matter", metadata: [:])
        ]
    }
}
