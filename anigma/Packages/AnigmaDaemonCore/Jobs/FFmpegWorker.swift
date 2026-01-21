//
//  FFmpegWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// media.transcode worker
/// Transcodes media, extracts thumbnails, or probes metadata using FFmpeg/FFprobe.
public struct FFmpegWorker: JobWorker {
    public static let kind = "media.transcode"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting FFmpeg operation...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let ffmpegConfig = FFmpegConfig.decode(from: config)
        let ffmpegPath = WorkerTooling.findTool(named: "ffmpeg")
        let ffprobePath = WorkerTooling.findTool(named: "ffprobe")

        guard let ffmpegPath = ffmpegPath else {
            throw WorkerError.executionFailed("ffmpeg binary not found.")
        }

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "media-transcode") {
            dir in
            let inputURL = dir.appendingPathComponent("input", isDirectory: false)
            // Use a specific extension for FFmpeg to auto-detect format correctly
            // Or use -f to force it. For now, we'll try to guess or use generic.
            try payload.write(to: inputURL, options: .atomic)

            var results: [Data] = []

            switch ffmpegConfig.mode {
            case .probe:
                guard let ffprobe = ffprobePath else {
                    throw WorkerError.executionFailed("ffprobe binary not found.")
                }
                let args = [
                    "-v", "quiet",
                    "-print_format", "json",
                    "-show_format",
                    "-show_streams",
                    inputURL.path
                ]
                let res = try WorkerTooling.runProcess(
                    executable: ffprobe, arguments: args, workingDirectory: dir)
                if res.exitCode != 0 {
                    throw WorkerError.executionFailed(
                        "ffprobe failed (\(res.exitCode)): \(res.stderr)")
                }
                results.append(res.stdout)

            case .thumbnail:
                let outputURL = dir.appendingPathComponent("thumb.jpg", isDirectory: false)
                let args = [
                    "-i", inputURL.path,
                    "-ss", ffmpegConfig.seek ?? "00:00:01",
                    "-vframes", "1",
                    "-q:v", "2",
                    outputURL.path
                ]
                let res = try WorkerTooling.runProcess(
                    executable: ffmpegPath, arguments: args, workingDirectory: dir)
                if res.exitCode != 0 {
                    throw WorkerError.executionFailed(
                        "ffmpeg thumbnail failed (\(res.exitCode)): \(res.stderr)")
                }
                results.append(try Data(contentsOf: outputURL))

            case .transcode:
                let outputURL = dir.appendingPathComponent(
                    "output.\(ffmpegConfig.targetExtension)", isDirectory: false)
                var args = ["-i", inputURL.path]

                // Video codec
                if let vcodec = ffmpegConfig.vcodec {
                    args.append("-c:v")
                    args.append(vcodec)
                }

                // Audio codec
                if let acodec = ffmpegConfig.acodec {
                    args.append("-c:a")
                    args.append(acodec)
                }

                // Extra args (e.g., -crf, -preset)
                for arg in ffmpegConfig.extraArgs {
                    args.append(arg)
                }

                args.append(outputURL.path)

                let res = try WorkerTooling.runProcess(
                    executable: ffmpegPath, arguments: args, workingDirectory: dir)
                if res.exitCode != 0 {
                    throw WorkerError.executionFailed(
                        "ffmpeg transcode failed (\(res.exitCode)): \(res.stderr)")
                }
                results.append(try Data(contentsOf: outputURL))
            }

            return results
        }

        fputs("Worker: FFmpeg operation complete\n", stderr)
        fflush(stderr)

        return outputData.map { data in
            JobOutputPayload(
                data: data,
                mediaType: ffmpegConfig.mode == .probe
                    ? "application/json"
                    : (ffmpegConfig.mode == .thumbnail ? "image/jpeg" : ffmpegConfig.targetMime),
                kind: "derived"
            )
        }
    }
}

private struct FFmpegConfig: Codable {
    enum Mode: String, Codable {
        case probe
        case thumbnail
        case transcode
    }

    let mode: Mode
    let seek: String?  // for thumbnail
    let targetExtension: String
    let targetMime: String
    let vcodec: String?
    let acodec: String?
    let extraArgs: [String]

    static let `default` = FFmpegConfig(
        mode: .thumbnail,
        seek: "00:00:01",
        targetExtension: "jpg",
        targetMime: "image/jpeg",
        vcodec: nil,
        acodec: nil,
        extraArgs: []
    )

    static func decode(from data: Data) -> FFmpegConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(FFmpegConfig.self, from: data)) ?? .default
    }
}
