//
//  MemoryLeakWorker.swift
//  AnigmaDaemonCore
//

import Foundation

public struct MemoryLeakWorker: JobWorker {
    public static let kind = "test.memory_leak"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: intentionally leaking memory...\n", stderr)
        fflush(stderr)

        var leak: [[UInt8]] = []
        for _ in 0..<100 {
            leak.append(Array(repeating: 0, count: 10 * 1024 * 1024))  // 10MB chunks
            fputs("Worker: allocated \(leak.count * 10)MB\n", stderr)
            fflush(stderr)
            try? await Task.sleep(for: .milliseconds(100))
        }

        return []
    }
}
