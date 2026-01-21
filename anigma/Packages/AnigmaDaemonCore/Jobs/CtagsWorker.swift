//
//  CtagsWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// code.index worker
/// Extracts symbols from source code files using Universal Ctags.
public struct CtagsWorker: JobWorker {
    public static let kind = "code.index"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting Ctags indexing...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let ctagsConfig = CtagsConfig.decode(from: config)
        let ctagsPath =
            WorkerTooling.findTool(named: "ctags")
            ?? WorkerTooling.findTool(named: "universal-ctags")
        guard let ctagsPath = ctagsPath else {
            throw WorkerError.executionFailed(
                "ctags/universal-ctags binary not found; install Universal Ctags.")
        }

        let outputTags = try WorkerTooling.withTemporaryDirectory(prefix: "code-index") { dir in
            let inputURL = dir.appendingPathComponent("input.src", isDirectory: false)
            let tagsURL = dir.appendingPathComponent("tags", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            var args = [
                "-f", tagsURL.path,
                "--output-format=\(ctagsConfig.format)"
            ]

            if ctagsConfig.recursive {
                args.append("-R")
            }

            args.append(inputURL.path)

            let result = try WorkerTooling.runProcess(
                executable: ctagsPath,
                arguments: args,
                workingDirectory: dir
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed(
                    "Ctags failed (\(result.exitCode)): \(result.stderr)")
            }

            return try Data(contentsOf: tagsURL)
        }

        fputs("Worker: Ctags indexing complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputTags,
                mediaType: "text/plain",  // Or application/x-ctags
                kind: "derived"
            )
        ]
    }
}

private struct CtagsConfig: Codable {
    let format: String  // "u-ctags", "e-ctags", "json"
    let recursive: Bool

    static let `default` = CtagsConfig(
        format: "u-ctags",
        recursive: false
    )

    static func decode(from data: Data) -> CtagsConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(CtagsConfig.self, from: data)) ?? .default
    }
}
