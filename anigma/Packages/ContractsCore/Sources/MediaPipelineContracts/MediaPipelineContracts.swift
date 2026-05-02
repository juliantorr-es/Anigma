import Foundation
import FoundationContracts
import ContractsCore

/// Neutral interface target for media pipeline decoupling.
public protocol SaturationSubstrateProtocol: Sendable {
    func process(surface: MediaSurface, lane: MediaLane, contract: any MediaContract) async throws -> MediaSurface
}

/// Minimal artifact-store contract required by MediaCore media decode executors.
public protocol MediaArtifactStore: Sendable {
    func storeRaw(_ data: Data, typeName: String, preferredID: String?) async throws -> String
    func loadRaw(_ id: String) async throws -> (data: Data, typeName: String)
}
