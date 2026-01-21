//
//  LibassWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// media.subtitle worker
/// Renders or burns subtitles into video using FFmpeg + libass.
public struct LibassWorker: JobWorker {
    public static let kind = "media.subtitle"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting subtitle rendering...\n", stderr)
        fflush(stderr)

        // inputs[0]: video, inputs[1]: subtitles (optional)
        guard let videoInput = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let videoData = vaultData[videoInput.hash] else {
            throw WorkerError.missingInputData(hash: videoInput.hash)
        }

        let subtitleConfig = LibassConfig.decode(from: config)
        let ffmpegPath = WorkerTooling.findTool(named: "ffmpeg")
        guard let ffmpegPath = ffmpegPath else {
            throw WorkerError.executionFailed(
                "ffmpeg binary not found (required for subtitle burn-in).")
        }

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "media-subtitle") { dir in
            let videoURL = dir.appendingPathComponent("video.mp4", isDirectory: false)
            let outputURL = dir.appendingPathComponent("output.mp4", isDirectory: false)
            try videoData.write(to: videoURL, options: .atomic)

            var args = ["-i", videoURL.path]

            // Subtitle handling
            if inputs.count > 1, let subData = vaultData[inputs[1].hash] {
                let subURL = dir.appendingPathComponent("subtitles.ass", isDirectory: false)
                try subData.write(to: subURL, options: .atomic)
                // Use subtitles filter (requires libass build of ffmpeg)
                args.append("-vf")
                args.append("subtitles=\(subURL.path)")
            } else if let internalSub = subtitleConfig.internalStreamIndex {
                args.append("-vf")
                args.append("subtitles=\(videoURL.path):si=\(internalSub)")
            }

            // Encode options
            args.append("-c:v")
            args.append("libx264")  // Default to x264 for burn-in for now
            args.append("-preset")
            args.append("fast")
            args.append("-crf")
            args.append("23")
            args.append("-c:a")
            args.append("copy")  // Keep audio

            args.append(outputURL.path)

            let result = try WorkerTooling.runProcess(
                executable: ffmpegPath,
                arguments: args,
                workingDirectory: dir
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed(
                    "FFmpeg subtitle burn-in failed (\(result.exitCode)): \(result.stderr)")
            }

            return try Data(contentsOf: outputURL)
        }

        fputs("Worker: subtitle rendering complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: "video/mp4",
                kind: "derived"
            )
        ]
    }
}

private struct LibassConfig: Codable {
    let internalStreamIndex: Int?

    static let `default` = LibassConfig(internalStreamIndex: nil)

    static func decode(from data: Data) -> LibassConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(LibassConfig.self, from: data)) ?? .default
    }
}
