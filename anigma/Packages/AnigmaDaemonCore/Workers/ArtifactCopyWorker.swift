//
//  ArtifactCopyWorker.swift
//  AnigmaDaemonCore
//
//  Worker for artifact.copy job kind (minimal vertical slice).
//

import Foundation

/// artifact.copy worker
/// Copies an artifact from input to output (trivial job for testing)
public struct ArtifactCopyWorker: JobWorker {
    public static let kind = "artifact.copy"

    public init() {}

    /// Execute artifact.copy job
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // Validate inputs
        guard inputs.count == 1 else {
            throw WorkerError.invalidInputCount(expected: 1, got: inputs.count)
        }

        let input = inputs[0]
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        // For artifact.copy, output is identical to input
        return [
            JobOutputPayload(
                data: payload,
                mediaType: input.mediaType,
                kind: "derived"
            )
        ]
    }
}

/// Worker errors
public enum WorkerError: Error, LocalizedError {
    case invalidInputCount(expected: Int, got: Int)
    case missingInputData(hash: String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInputCount(let expected, let got):
            return "Invalid input count: expected \(expected), got \(got)"
        case .missingInputData(let hash):
            return "Missing input data for hash: \(hash)"
        case .executionFailed(let detail):
            return "Execution failed: \(detail)"
        }
    }
}
