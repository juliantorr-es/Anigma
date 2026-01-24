//
//  FFmpegUtils.swift
//  PolytroposModule
//
//  FFmpeg command-line utilities for transcoding, proxy generation, and format support.
//  Used as a fallback for edge cases outside MLT or native renderer scope.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - FFmpeg Backend

/// FFmpeg-based renderer backend using ffmpeg command-line tool.
public actor FFmpegBackend: RendererBackend {
    public nonisolated let backendId = RendererBackendId.ffmpeg
    public nonisolated let displayName = "FFmpeg (Universal)"

    public nonisolated let capabilities = RendererCapabilities(
        supportedBackendVideoCodecs: BackendVideoCodec.allCases,
        supportedBackendAudioCodecs: BackendAudioCodec.allCases,
        supportedContainers: ContainerFormat.allCases,
        gpuAcceleration: true, // Via hardware encoders
        hardwareEncoding: true,
        maxBackendResolution: .uhd8k,
        supportsColorGrading: true,
        supportsAudioEffects: true,
        supportsTransitions: false, // Limited transition support
        supportsKeyframes: false    // No native keyframe support
    )

    /// Path to ffmpeg executable.
    private var ffmpegPath: String?

    /// Path to ffprobe executable.
    private var ffprobePath: String?

    /// Active processes.
    private var activeProcesses: [UUID: Process] = [:]

    /// Temp directory.
    private let tempDirectory: URL

    public init(ffmpegPath: String? = nil, ffprobePath: String? = nil) {
        self.ffmpegPath = ffmpegPath
        self.ffprobePath = ffprobePath
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("polytropos_ffmpeg", isDirectory: true)
    }

    public func isAvailable() async -> Bool {
        let path = ffmpegPath ?? findFFmpegPath()
        guard let path = path else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    private func findFFmpegPath() -> String? {
        let paths = [
            "/usr/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg"
        ]

        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func findFFprobePath() -> String? {
        let paths = [
            "/usr/bin/ffprobe",
            "/usr/local/bin/ffprobe",
            "/opt/homebrew/bin/ffprobe"
        ]

        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    public func render(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        configuration: ProExportConfiguration,
        progress: @Sendable @escaping (RenderProgress) -> Void
    ) async throws -> RenderResult {
        let jobId = UUID()
        let startTime = Date()

        progress(RenderProgress(jobId: jobId, phase: .preparing, progress: 0))

        // For complex timelines, FFmpeg needs a concat/filter approach
        // This is a simplified single-input implementation

        guard let firstTrack = timeline.videoTracks.first,
              let firstSegment = firstTrack.segments.first,
              let asset = assets[firstSegment.sourceAssetId] else {
            return RenderResult(
                jobId: jobId,
                success: false,
                renderTime: 0,
                error: RenderError(
                    code: "NO_INPUT",
                    message: "No video segments found"
                )
            )
        }

        let ffmpegExecutable = ffmpegPath ?? findFFmpegPath() ?? "/usr/local/bin/ffmpeg"

        // Determine output path
        let outputPath: String
        switch configuration.destination {
        case .file(let url):
            outputPath = url?.path ?? tempDirectory
                .appendingPathComponent("\(jobId)_output.mp4").path
        default:
            outputPath = tempDirectory
                .appendingPathComponent("\(jobId)_output.mp4").path
        }

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        // Build FFmpeg command
        var arguments = ["-y"] // Overwrite output
        arguments += ["-i", asset.filePath]

        // Trim to segment
        arguments += ["-ss", "\(firstSegment.sourceIn)"]
        arguments += ["-t", "\(firstSegment.sourceOut - firstSegment.sourceIn)"]

        // Video codec
        arguments += ffmpegVideoArgs(for: configuration.preset)

        // Audio
        if configuration.includeAudio {
            arguments += ["-c:a", "aac", "-b:a", "192k"]
        } else {
            arguments += ["-an"]
        }

        arguments += [outputPath]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegExecutable)
        process.arguments = arguments

        activeProcesses[jobId] = process

        let pipe = Pipe()
        process.standardError = pipe

        progress(RenderProgress(jobId: jobId, phase: .rendering, progress: 0.1))

        do {
            try process.run()
            process.waitUntilExit()

            activeProcesses.removeValue(forKey: jobId)

            let renderTime = Date().timeIntervalSince(startTime)

            if process.terminationStatus == 0 {
                let attrs = try? FileManager.default.attributesOfItem(atPath: outputPath)
                let fileSize = attrs?[.size] as? Int64

                progress(RenderProgress(jobId: jobId, phase: .completed, progress: 1.0))

                return RenderResult(
                    jobId: jobId,
                    success: true,
                    outputPath: outputPath,
                    outputSize: fileSize,
                    renderTime: renderTime
                )
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"

                return RenderResult(
                    jobId: jobId,
                    success: false,
                    renderTime: renderTime,
                    error: RenderError(
                        code: "FFMPEG_FAILED",
                        message: "FFmpeg exited with code \(process.terminationStatus)",
                        underlyingError: errorMessage
                    )
                )
            }
        } catch {
            activeProcesses.removeValue(forKey: jobId)
            return RenderResult(
                jobId: jobId,
                success: false,
                renderTime: Date().timeIntervalSince(startTime),
                error: RenderError(
                    code: "FFMPEG_PROCESS_ERROR",
                    message: error.localizedDescription
                )
            )
        }
    }

    public func cancelRender(jobId: UUID) async {
        if let process = activeProcesses[jobId] {
            process.terminate()
            activeProcesses.removeValue(forKey: jobId)
        }
    }

    public func generatePreview(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        atTime: TimeInterval,
        resolution: PreviewBackendResolution
    ) async throws -> PreviewFrame {
        guard let firstTrack = timeline.videoTracks.first,
              let segment = firstTrack.segments.first(where: {
                  atTime >= $0.timelineIn && atTime < $0.timelineOut
              }),
              let asset = assets[segment.sourceAssetId] else {
            throw RenderError(
                code: "NO_FRAME",
                message: "No video at requested time"
            )
        }

        let ffmpegExecutable = ffmpegPath ?? findFFmpegPath() ?? "/usr/local/bin/ffmpeg"

        let (width, height): (Int, Int)
        switch resolution {
        case .thumbnail(let maxDim):
            width = maxDim
            height = maxDim
        case .preview(let w, let h):
            width = w
            height = h
        case .full:
            width = asset.resolution?.width ?? 1920
            height = asset.resolution?.height ?? 1080
        }

        // Calculate source time within the clip
        let sourceTime = segment.sourceIn + (atTime - segment.timelineIn)

        let outputPath = tempDirectory
            .appendingPathComponent("preview_\(UUID()).png")

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegExecutable)
        process.arguments = [
            "-y",
            "-ss", "\(sourceTime)",
            "-i", asset.filePath,
            "-vframes", "1",
            "-vf", "scale=\(width):\(height):force_original_aspect_ratio=decrease",
            outputPath.path
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let imageData = try? Data(contentsOf: outputPath) else {
            throw RenderError(
                code: "PREVIEW_FAILED",
                message: "Failed to generate preview frame"
            )
        }

        // Clean up
        try? FileManager.default.removeItem(at: outputPath)

        return PreviewFrame(
            time: atTime,
            width: width,
            height: height,
            pixelData: imageData,
            pixelFormat: .rgba8
        )
    }

    private func ffmpegVideoArgs(for preset: ProExportPreset) -> [String] {
        switch preset {
        case .proresProxy, .prores422:
            return ["-c:v", "prores_ks", "-profile:v", "3"]
        case .dnxHD:
            return ["-c:v", "dnxhd", "-b:v", "120M"]
        case .youtube4k, .youtube1080p:
            return [
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "18",
                "-pix_fmt", "yuv420p"
            ]
        default:
            return [
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "23",
                "-pix_fmt", "yuv420p"
            ]
        }
    }
}

// MARK: - FFmpeg Invoker

/// Direct FFmpeg command invoker for specific tasks.
public actor FFmpegInvoker {

    private var ffmpegPath: String?
    private var ffprobePath: String?

    public init(ffmpegPath: String? = nil, ffprobePath: String? = nil) {
        self.ffmpegPath = ffmpegPath
        self.ffprobePath = ffprobePath
    }

    /// Run an FFmpeg command with arguments.
    public func run(arguments: [String]) async throws -> FFmpegResult {
        let ffmpeg = ffmpegPath ?? findExecutable("ffmpeg")
        guard let ffmpeg = ffmpeg else {
            throw FFmpegError.notInstalled
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(
            data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let stderr = String(
            data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        return FFmpegResult(
            exitCode: Int(process.terminationStatus),
            stdout: stdout,
            stderr: stderr
        )
    }

    /// Probe media file for metadata.
    public func probe(file: URL) async throws -> MediaProbeResult {
        let ffprobe = ffprobePath ?? findExecutable("ffprobe")
        guard let ffprobe = ffprobe else {
            throw FFmpegError.notInstalled
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobe)
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            file.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            throw FFmpegError.probeFailed
        }

        return try JSONDecoder().decode(MediaProbeResult.self, from: data)
    }

    /// Transcode file with given settings.
    public func transcode(
        input: URL,
        output: URL,
        settings: TranscodeSettings,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        var args = ["-y", "-i", input.path]

        // Video settings
        if let videoCodec = settings.videoCodec {
            args += ["-c:v", ffmpegCodecName(videoCodec)]
        }
        if let videoBitrate = settings.videoBitrate {
            args += ["-b:v", videoBitrate]
        }
        if let resolution = settings.resolution {
            args += ["-vf", "scale=\(resolution.width):\(resolution.height)"]
        }

        // Audio settings
        if let audioCodec = settings.audioCodec {
            args += ["-c:a", ffmpegBackendAudioCodecName(audioCodec)]
        }
        if let audioBitrate = settings.audioBitrate {
            args += ["-b:a", audioBitrate]
        }

        // Output
        args += [output.path]

        let result = try await run(arguments: args)

        if result.exitCode != 0 {
            throw FFmpegError.transcodeFailed(result.stderr)
        }
    }

    private func findExecutable(_ name: String) -> String? {
        let paths = [
            "/usr/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/homebrew/bin/\(name)"
        ]

        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func ffmpegCodecName(_ codec: BackendVideoCodec) -> String {
        switch codec {
        case .h264: return "libx264"
        case .h265: return "libx265"
        case .prores422, .prores422hq: return "prores_ks"
        case .prores4444: return "prores_ks"
        case .proresProxy: return "prores_ks"
        case .dnxhd, .dnxhr: return "dnxhd"
        case .vp9: return "libvpx-vp9"
        case .av1: return "libaom-av1"
        case .rawVideo: return "rawvideo"
        }
    }

    private func ffmpegBackendAudioCodecName(_ codec: BackendAudioCodec) -> String {
        switch codec {
        case .aac: return "aac"
        case .mp3: return "libmp3lame"
        case .pcm: return "pcm_s16le"
        case .flac: return "flac"
        case .opus: return "libopus"
        case .vorbis: return "libvorbis"
        case .ac3: return "ac3"
        case .eac3: return "eac3"
        }
    }
}

/// FFmpeg command result.
public struct FFmpegResult: Sendable {
    public var exitCode: Int
    public var stdout: String
    public var stderr: String

    public var success: Bool { exitCode == 0 }
}

/// FFmpeg errors.
public enum FFmpegError: Error {
    case notInstalled
    case probeFailed
    case transcodeFailed(String)
}

/// Transcode settings.
public struct TranscodeSettings: Sendable {
    public var videoCodec: BackendVideoCodec?
    public var videoBitrate: String?
    public var resolution: BackendResolution?
    public var frameRate: Double?
    public var audioCodec: BackendAudioCodec?
    public var audioBitrate: String?
    public var sampleRate: Int?

    public init(
        videoCodec: BackendVideoCodec? = nil,
        videoBitrate: String? = nil,
        resolution: BackendResolution? = nil,
        frameRate: Double? = nil,
        audioCodec: BackendAudioCodec? = nil,
        audioBitrate: String? = nil,
        sampleRate: Int? = nil
    ) {
        self.videoCodec = videoCodec
        self.videoBitrate = videoBitrate
        self.resolution = resolution
        self.frameRate = frameRate
        self.audioCodec = audioCodec
        self.audioBitrate = audioBitrate
        self.sampleRate = sampleRate
    }
}

/// Media probe result from FFprobe.
public struct MediaProbeResult: Codable, Sendable {
    public var format: FormatInfo?
    public var streams: [StreamInfo]?

    public struct FormatInfo: Codable, Sendable {
        public var filename: String?
        public var duration: String?
        public var size: String?
        public var bit_rate: String?
        public var format_name: String?
        public var format_long_name: String?
    }

    public struct StreamInfo: Codable, Sendable {
        public var index: Int?
        public var codec_name: String?
        public var codec_long_name: String?
        public var codec_type: String?
        public var width: Int?
        public var height: Int?
        public var r_frame_rate: String?
        public var sample_rate: String?
        public var channels: Int?
        public var duration: String?
        public var bit_rate: String?
    }
}

// MARK: - Proxy Generator

/// Proxy media generator using FFmpeg.
public actor ProxyGenerator {

    private let invoker: FFmpegInvoker
    private let tempDirectory: URL

    public init(ffmpegPath: String? = nil) {
        self.invoker = FFmpegInvoker(ffmpegPath: ffmpegPath)
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("polytropos_proxies", isDirectory: true)
    }

    /// Generate proxy for a media file.
    public func generateProxy(
        for input: URL,
        resolution: ProxyResolution,
        codec: ProxyCodec,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        let outputName = "\(input.deletingPathExtension().lastPathComponent)_proxy.\(proxyExtension(for: codec))"
        let output = tempDirectory.appendingPathComponent(outputName)

        let scale = resolution.scale

        var args = ["-y", "-i", input.path]

        // Scale filter
        args += ["-vf", "scale=iw*\(scale):ih*\(scale)"]

        // Video codec
        args += ["-c:v", ffmpegProxyCodec(codec)]
        args += ["-b:v", proxyBitrate(for: resolution)]

        // Audio
        args += ["-c:a", "aac", "-b:a", "128k"]

        // Fast encode settings
        if codec == .h264 {
            args += ["-preset", "ultrafast"]
        }

        args += [output.path]

        let result = try await invoker.run(arguments: args)

        guard result.success else {
            throw FFmpegError.transcodeFailed(result.stderr)
        }

        return output
    }

    private func proxyExtension(for codec: ProxyCodec) -> String {
        switch codec {
        case .h264, .hevc: return "mp4"
        case .proresProxy: return "mov"
        }
    }

    private func proxyBackendVideoCodec(for codec: ProxyCodec) -> BackendVideoCodec {
        switch codec {
        case .h264: return .h264
        case .hevc: return .h265
        case .proresProxy: return .proresProxy
        }
    }

    private func ffmpegProxyCodec(_ codec: ProxyCodec) -> String {
        switch codec {
        case .h264: return "libx264"
        case .hevc: return "libx265"
        case .proresProxy: return "prores_ks"
        }
    }

    private func proxyBitrate(for resolution: ProxyResolution) -> String {
        switch resolution {
        case .half: return "8M"
        case .quarter: return "4M"
        case .eighth: return "2M"
        }
    }
}

// MARK: - Concat Builder

/// Builds FFmpeg concat demuxer files for multi-clip timelines.
public struct FFmpegConcatBuilder {

    /// Build concat file for sequential clips.
    public static func buildConcatFile(
        clips: [(path: String, inPoint: TimeInterval, outPoint: TimeInterval)]
    ) -> String {
        var content = "ffconcat version 1.0\n\n"

        for clip in clips {
            content += "file '\(clip.path.replacingOccurrences(of: "'", with: "'\\''"))'\n"
            content += "inpoint \(clip.inPoint)\n"
            content += "outpoint \(clip.outPoint)\n"
            content += "\n"
        }

        return content
    }

    /// Build complex filter graph for multi-track timeline.
    public static func buildFilterGraph(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo]
    ) -> (inputs: [String], filterComplex: String) {
        var inputs: [String] = []
        var filters: [String] = []
        var inputIndex = 0
        var streamLabels: [String] = []

        // Collect all unique assets as inputs
        var assetInputMap: [EntityId: Int] = [:]

        for track in timeline.videoTracks {
            for segment in track.segments {
                if assetInputMap[segment.sourceAssetId] == nil {
                    if let asset = assets[segment.sourceAssetId] {
                        inputs.append(asset.filePath)
                        assetInputMap[segment.sourceAssetId] = inputIndex
                        inputIndex += 1
                    }
                }
            }
        }

        // Build trim and concat filters
        var clipIndex = 0
        for track in timeline.videoTracks {
            for segment in track.segments {
                guard let inputIdx = assetInputMap[segment.sourceAssetId] else {
                    continue
                }

                let label = "v\(clipIndex)"
                filters.append(
                    "[\(inputIdx):v]trim=start=\(segment.sourceIn):end=\(segment.sourceOut),setpts=PTS-STARTPTS[\(label)]"
                )
                streamLabels.append("[\(label)]")
                clipIndex += 1
            }
        }

        // Concat all clips
        if !streamLabels.isEmpty {
            filters.append(
                "\(streamLabels.joined())concat=n=\(streamLabels.count):v=1:a=0[outv]"
            )
        }

        return (inputs, filters.joined(separator: ";"))
    }
}
