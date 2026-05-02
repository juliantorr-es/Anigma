//
//  ConnectorManifest.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public enum ConnectorCapability: String, Codable, Sendable {
    case capture
    case browse
    case sync
    case writeBack
    case roster
    case gradePassback
}

public struct ConnectorScopeDefinition: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let isRequired: Bool

    public init(id: String, name: String, description: String, isRequired: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.isRequired = isRequired
    }
}

public struct ConnectorManifest: Codable, Sendable {
    public let id: String
    public let name: String
    public let providerType: String // e.g. "microsoft_graph", "google_workspace"
    public let capabilities: [ConnectorCapability]
    public let supportedSyncTracks: [SyncTrackType]
    public let scopes: [ConnectorScopeDefinition]
    public let repairRecipes: [RepairRecipe]

    public init(
        id: String,
        name: String,
        providerType: String,
        capabilities: [ConnectorCapability],
        supportedSyncTracks: [SyncTrackType],
        scopes: [ConnectorScopeDefinition],
        repairRecipes: [RepairRecipe]
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.capabilities = capabilities
        self.supportedSyncTracks = supportedSyncTracks
        self.scopes = scopes
        self.repairRecipes = repairRecipes
    }
}

public actor ConnectorRegistry {
    private var manifests: [String: ConnectorManifest] = [:] // ProviderType -> Manifest

    public init() {}

    public func register(manifest: ConnectorManifest) {
        manifests[manifest.providerType] = manifest
    }

    public func getManifest(providerType: String) -> ConnectorManifest? {
        return manifests[providerType]
    }

    public func getAllManifests() -> [ConnectorManifest] {
        return Array(manifests.values)
    }
}
