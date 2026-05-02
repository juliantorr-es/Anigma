//
//  ImageMagickWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// image.transform worker
/// Processes raster images (resize, format conversion, normalization) using ImageMagick.
public struct ImageMagickWorker: JobWorker {
    public static let kind = "image.transform"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting ImageMagick operation...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let imageConfig = ImageMagickConfig.decode(from: config)
        let magickPath =
            WorkerTooling.findTool(named: "magick") ?? WorkerTooling.findTool(named: "convert")
        guard let magickPath = magickPath else {
            throw WorkerError.executionFailed("ImageMagick binary (magick or convert) not found.")
        }

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "image-transform") {
            dir in
            let inputURL = dir.appendingPathComponent("input", isDirectory: false)
            let outputURL = dir.appendingPathComponent(
                "output.\(imageConfig.targetExtension)", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            var args: [String] = []

            // ImageMagick 7 uses 'magick', IM6 uses 'convert'
            if magickPath.hasSuffix("magick") {
                // If it's IM7, the first arg can be 'convert' or we can just use the tool directly
            }

            args.append(inputURL.path)

            // Batch operations
            for op in imageConfig.operations {
                args.append(contentsOf: op.split(separator: " ").map(String.init))
            }

            args.append(outputURL.path)

            let result = try WorkerTooling.runProcess(
                executable: magickPath,
                arguments: args,
                workingDirectory: dir
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed(
                    "ImageMagick failed (\(result.exitCode)): \(result.stderr)")
            }

            return try Data(contentsOf: outputURL)
        }

        fputs("Worker: ImageMagick operation complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: imageConfig.targetMime,
                kind: "derived"
            )
        ]
    }
}

private struct ImageMagickConfig: Codable {
    let targetExtension: String
    let targetMime: String
    let operations: [String]  // e.g., ["-resize 800x600", "-quality 85"]

    static let `default` = ImageMagickConfig(
        targetExtension: "png",
        targetMime: "image/png",
        operations: ["-resize 1024x1024>"]
    )

    static func decode(from data: Data) -> ImageMagickConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(ImageMagickConfig.self, from: data)) ?? .default
    }
}
