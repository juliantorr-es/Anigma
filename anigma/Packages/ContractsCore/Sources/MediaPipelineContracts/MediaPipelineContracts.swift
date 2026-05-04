import Foundation
import ContractsCore

/// Minimal artifact-store contract required by MediaCore media decode executors.
public protocol MediaArtifactStore: Sendable {
    func storeRaw(_ data: Data, typeName: String, preferredID: String?) async throws -> String
    func loadRaw(_ id: String) async throws -> (data: Data, typeName: String)
}
