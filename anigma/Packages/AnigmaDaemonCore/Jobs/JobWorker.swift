//
//  JobWorker.swift
//  AnigmaDaemonCore
//
//  Protocol for job execution workers.
//

import Foundation

/// Protocol for job execution workers
public protocol JobWorker: Sendable {
    /// The job kind this worker handles (e.g. "artifact.copy")
    static var kind: String { get }

    /// Execute the job
    /// - Parameters:
    ///   - inputs: Input artifact references
    ///   - config: Job-specific configuration data
    ///   - vaultData: Map of input hashes to their decrypted content
    /// - Returns: List of output payloads to ingest into the vault
    func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload]
}

/// Base class for workers to share common functionality
open class BaseWorker {
    public init() {}

    /// Common error handling or utility methods can be added here
}
