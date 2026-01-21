//
//  PandocWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// doc.convert worker
/// Converts documents between formats using Pandoc.
public struct PandocWorker: JobWorker {
    public static let kind = "doc.convert"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting Pandoc conversion...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let convertConfig = PandocConvertConfig.decode(from: config)
        let pandocPath = WorkerTooling.findTool(named: "pandoc")
        guard let pandocPath = pandocPath else {
            throw WorkerError.executionFailed(
                "pandoc binary not found; install Pandoc.")
        }

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "doc-convert") { dir in
            let inputURL = dir.appendingPathComponent("input", isDirectory: false)
            let outputURL = dir.appendingPathComponent(
                "output.\(convertConfig.to)", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            var args = [
                inputURL.path,
                "-f", convertConfig.from,
                "-t", convertConfig.to,
                "-o", outputURL.path
            ]

            // Add custom arguments (e.g., --standalone, --toc)
            for arg in convertConfig.extraArgs {
                args.append(arg)
            }

            let result = try WorkerTooling.runProcess(
                executable: pandocPath,
                arguments: args,
                workingDirectory: dir
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed(
                    "Pandoc failed (\(result.exitCode)): \(result.stderr)")
            }

            return try Data(contentsOf: outputURL)
        }

        fputs("Worker: Pandoc conversion complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: convertConfig.targetMime,
                kind: "derived"
            )
        ]
    }
}

private struct PandocConvertConfig: Codable {
    let from: String
    let to: String
    let targetMime: String
    let extraArgs: [String]

    static let `default` = PandocConvertConfig(
        from: "markdown",
        to: "html",
        targetMime: "text/html",
        extraArgs: ["--standalone"]
    )

    static func decode(from data: Data) -> PandocConvertConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(PandocConvertConfig.self, from: data)) ?? .default
    }
}
