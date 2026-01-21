//
//  NoOpWorker.swift
//  AnigmaDaemonCore
//
//  Simple test worker that succeeds immediately with no outputs.
//  Used for testing receipt generation and verification.
//

import Foundation

/// No-op worker for testing
public struct NoOpWorker: JobWorker {
    public static let kind = "test.noop"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // Immediately succeed with no outputs
        return []
    }
}
