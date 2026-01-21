//
//  InkscapeWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// vector.convert worker
/// Converts between vector formats or renders vectors to raster using Inkscape (headless).
public struct InkscapeWorker: JobWorker {
    public static let kind = "vector.convert"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting Inkscape operation...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let vectorConfig = InkscapeConfig.decode(from: config)
        let inkscapePath = WorkerTooling.findTool(named: "inkscape")
        guard let inkscapePath = inkscapePath else {
            throw WorkerError.executionFailed("inkscape binary not found.")
        }

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "vector-convert") { dir in
            let inputURL = dir.appendingPathComponent("input.svg", isDirectory: false)
            let outputURL = dir.appendingPathComponent(
                "output.\(vectorConfig.to)", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            var args = [
                inputURL.path,
                "--export-filename=\(outputURL.path)"
            ]

            if let dpi = vectorConfig.dpi {
                args.append("--export-dpi=\(dpi)")
            }

            if let area = vectorConfig.exportArea {
                args.append("--export-area=\(area)")
            }

            let result = try WorkerTooling.runProcess(
                executable: inkscapePath,
                arguments: args,
                workingDirectory: dir
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed(
                    "Inkscape failed (\(result.exitCode)): \(result.stderr)")
            }

            return try Data(contentsOf: outputURL)
        }

        fputs("Worker: Inkscape operation complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: vectorConfig.targetMime,
                kind: "derived"
            )
        ]
    }
}

private struct InkscapeConfig: Codable {
    let to: String  // "pdf", "png", "svg", "eps"
    let targetMime: String
    let dpi: Int?
    let exportArea: String?  // e.g. "page", "drawing"

    static let `default` = InkscapeConfig(
        to: "pdf",
        targetMime: "application/pdf",
        dpi: nil,
        exportArea: nil
    )

    static func decode(from data: Data) -> InkscapeConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(InkscapeConfig.self, from: data)) ?? .default
    }
}
