//
//  BlackbaudConnector.swift
//  AnigmaCorporate
//
//  Connector for Blackbaud (Nonprofit/Fundraising).
//

import Foundation
import AnigmaSystemSpine
import AnigmaCore

public actor BlackbaudConnector: ConnectorProtocol {
    private let config: ConnectorConfig
    private var accessToken: ConnectorAccessToken?

    public init(config: ConnectorConfig) {
        self.config = config
    }

    public var identity: ConnectorIdentity {
        get async {
            return ConnectorIdentity(
                connectorType: .blackbaud,
                version: "1.0",
                clientId: config.clientId,
                tenantId: config.tenantId,
                userId: "fundraiser-1",
                grantedScopes: config.scopes
            )
        }
    }

    public var permissionScope: PermissionScope {
        get async {
            return PermissionScope(
                connectedSources: ["Raiser's Edge"],
                inclusions: ["/constituents"],
                exclusions: []
            )
        }
    }

    public var policyPosture: PolicyPosture {
        get async {
            return PolicyPosture(
                isLocalOnly: false,
                isNetworkAllowed: true,
                retentionPolicy: "default",
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
        throw CorporateError.unsupportedOperation("Blackbaud write-back not implemented")
    }

    public func sourceInventory() async throws -> [ExternalRef] {
        guard accessToken != nil else { return [] }
        return [
            ExternalRef(systemId: "blackbaud", externalId: "constituent-555", name: "Jane Doe", type: "constituent", metadata: [:])
        ]
    }
}
