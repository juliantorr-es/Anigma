//
//  BiberWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// bib.process worker
/// Processes bibliography files using Biber.
public struct BiberWorker: JobWorker {
    public static let kind = "bib.process"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting Biber processing...\n", stderr)
        fflush(stderr)

        // inputs[0]: .bcf or .bib file
        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let biberPath = WorkerTooling.findTool(named: "biber")
        guard let biberPath = biberPath else {
            throw WorkerError.executionFailed("biber binary not found.")
        }

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "bib-process") { dir in
            let inputURL = dir.appendingPathComponent("input.bcf", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            let args = [
                "--input-directory", dir.path,
                "--output-directory", dir.path,
                inputURL.path
            ]

            let result = try WorkerTooling.runProcess(
                executable: biberPath,
                arguments: args,
                workingDirectory: dir
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed(
                    "Biber failed (\(result.exitCode)): \(result.stderr)")
            }

            // Biber produces .bbl files
            let outputURL = dir.appendingPathComponent("input.bbl", isDirectory: false)
            return try Data(contentsOf: outputURL)
        }

        fputs("Worker: Biber processing complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: "text/plain",
                kind: "derived"
            )
        ]
    }
}
