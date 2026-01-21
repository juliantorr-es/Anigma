//
//  QuickBooksConnector.swift
//  AnigmaCorporate
//
//  Connector for QuickBooks Online (Accounting).
//

import Foundation
import AnigmaSystemSpine
import AnigmaCore

public actor QuickBooksConnector: ConnectorProtocol {
    private let config: ConnectorConfig
    private var accessToken: ConnectorAccessToken?

    public init(config: ConnectorConfig) {
        self.config = config
    }

    public var identity: ConnectorIdentity {
        get async {
            return ConnectorIdentity(
                connectorType: .quickbooks,
                version: "1.0",
                clientId: config.clientId,
                tenantId: config.tenantId,
                userId: "accountant-1",
                grantedScopes: config.scopes
            )
        }
    }

    public var permissionScope: PermissionScope {
        get async {
            return PermissionScope(
                connectedSources: ["QuickBooks Company"],
                inclusions: ["/transactions"],
                exclusions: []
            )
        }
    }

    public var policyPosture: PolicyPosture {
        get async {
            return PolicyPosture(
                isLocalOnly: false,
                isNetworkAllowed: true,
                retentionPolicy: "7years",
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
        throw CorporateError.unsupportedOperation("QuickBooks write-back not implemented")
    }

    public func sourceInventory() async throws -> [ExternalRef] {
        guard accessToken != nil else { return [] }
        return [
            ExternalRef(systemId: "quickbooks", externalId: "invoice-1001", name: "Invoice #1001", type: "invoice", metadata: [:])
        ]
    }
}
