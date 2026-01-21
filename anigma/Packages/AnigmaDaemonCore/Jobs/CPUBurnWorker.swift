//
//  CPUBurnWorker.swift
//  AnigmaDaemonCore
//

import Foundation

public struct CPUBurnWorker: JobWorker {
    public static let kind = "test.cpu_burn"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: intentionally burning CPU...\n", stderr)
        fflush(stderr)

        let start = Date()
        while Date().timeIntervalSince(start) < 120 {
            _ = (0..<1_000_000).map { $0 * $0 }
            // Yield to allow Task cancellation or other work
            await Task.yield()
        }

        return []
    }
}
