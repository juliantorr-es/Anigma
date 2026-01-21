//
//  MLTBridge.swift
//  PolytroposModule
//
//  MLT Framework bridge for legacy backend rendering and project interchange.
//  Converts Polytropos timeline/project to MLT XML format and invokes MLT/FFmpeg.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - MLT Backend

/// MLT-based renderer backend using melt command-line tool.
public actor MLTBackend: RendererBackend {
    public nonisolated let backendId = RendererBackendId.mlt
    public nonisolated let displayName = "MLT Framework (Legacy)"

    public nonisolated let capabilities = RendererCapabilities(
        supportedBackendVideoCodecs: [.h264, .h265, .prores422, .prores422hq, .dnxhd, .vp9],
        supportedBackendAudioCodecs: [.aac, .mp3, .pcm, .flac, .opus],
        supportedContainers: [.mp4, .mov, .mkv, .webm, .mxf],
        gpuAcceleration: false,
        hardwareEncoding: false,
        maxBackendResolution: .uhd8k,
        supportsColorGrading: true,
        supportsAudioEffects: true,
        supportsTransitions: true,
        supportsKeyframes: true
    )

    /// Path to melt executable.
    private var meltPath: String?

    /// Active render jobs.
    private var activeJobs: [UUID: Process] = [:]

    /// Temp directory for intermediate files.
    private let tempDirectory: URL

    public init(meltPath: String? = nil) {
        self.meltPath = meltPath
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("polytropos_mlt", isDirectory: true)
    }

    public func isAvailable() async -> Bool {
        // Check if melt is installed
        let path = meltPath ?? findMeltPath()
        guard let path = path else { return false }

        return FileManager.default.isExecutableFile(atPath: path)
    }

    private func findMeltPath() -> String? {
        // Common installation paths
        let paths = [
            "/usr/bin/melt",
            "/usr/local/bin/melt",
            "/opt/homebrew/bin/melt",
            "/Applications/Shotcut.app/Contents/MacOS/melt"
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

        // Create MLT XML project
        let mltXML = try MLTProjectAdapter.convert(
            timeline: timeline,
            assets: assets,
            configuration: configuration
        )

        // Write to temp file
        let xmlPath = tempDirectory.appendingPathComponent("\(jobId).mlt")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        try mltXML.write(to: xmlPath, atomically: true, encoding: .utf8)

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

        // Build melt command
        let meltExecutable = meltPath ?? findMeltPath() ?? "/usr/local/bin/melt"

        progress(RenderProgress(jobId: jobId, phase: .preparing, progress: 0))

        // Run melt process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: meltExecutable)
        process.arguments = [
            xmlPath.path,
            "-consumer", "avformat:\(outputPath)",
            "vcodec=\(mltCodecName(for: configuration.preset))",
            "acodec=aac",
            "real_time=-1" // Render as fast as possible
        ]

        activeJobs[jobId] = process

        let pipe = Pipe()
        process.standardError = pipe

        do {
            try process.run()

            progress(RenderProgress(jobId: jobId, phase: .rendering, progress: 0.1))

            // Wait for completion
            process.waitUntilExit()

            activeJobs.removeValue(forKey: jobId)

            let renderTime = Date().timeIntervalSince(startTime)

            if process.terminationStatus == 0 {
                // Get file size
                let attrs = try? FileManager.default.attributesOfItem(atPath: outputPath)
                let fileSize = attrs?[.size] as? Int64

                progress(RenderProgress(jobId: jobId, phase: .completed, progress: 1.0))

                return RenderResult(
                    jobId: jobId,
                    success: true,
                    outputPath: outputPath,
                    outputSize: fileSize,
                    renderTime: renderTime,
                    warnings: []
                )
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"

                progress(RenderProgress(jobId: jobId, phase: .failed, progress: 0))

                return RenderResult(
                    jobId: jobId,
                    success: false,
                    renderTime: renderTime,
                    error: RenderError(
                        code: "MLT_RENDER_FAILED",
                        message: "MLT render failed with exit code \(process.terminationStatus)",
                        underlyingError: errorMessage
                    )
                )
            }
        } catch {
            activeJobs.removeValue(forKey: jobId)

            return RenderResult(
                jobId: jobId,
                success: false,
                renderTime: Date().timeIntervalSince(startTime),
                error: RenderError(
                    code: "MLT_PROCESS_ERROR",
                    message: "Failed to run MLT: \(error.localizedDescription)"
                )
            )
        }
    }

    public func cancelRender(jobId: UUID) async {
        if let process = activeJobs[jobId] {
            process.terminate()
            activeJobs.removeValue(forKey: jobId)
        }
    }

    public func generatePreview(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        atTime: TimeInterval,
        resolution: PreviewBackendResolution
    ) async throws -> PreviewFrame {
        // MLT preview via melt frame extraction
        // This is a simplified implementation
        throw RenderError(
            code: "MLT_PREVIEW_NOT_IMPLEMENTED",
            message: "MLT preview generation not yet implemented"
        )
    }

    private func mltCodecName(for preset: ProExportPreset) -> String {
        switch preset {
        case .proresProxy, .prores422, .prores4444:
            return "prores_ks"
        case .dnxHD:
            return "dnxhd"
        default:
            return "libx264"
        }
    }
}

// MARK: - MLT Project Adapter

/// Converts Polytropos timeline to MLT XML format.
public struct MLTProjectAdapter {

    /// Convert timeline to MLT XML string.
    public static func convert(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        configuration: ProExportConfiguration
    ) throws -> String {
        var xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <mlt LC_NUMERIC="C" version="7.0.0" producer="polytropos">
          <profile description="automatic" />

        """

        // Add producers for each asset
        var producerIndex = 0
        var assetProducerMap: [EntityId: String] = [:]

        for (entityId, asset) in assets {
            let producerId = "producer\(producerIndex)"
            assetProducerMap[entityId] = producerId

            xml += """
              <producer id="\(producerId)" in="00:00:00.000" out="\(formatTime(asset.duration))">
                <property name="resource">\(escapeXML(asset.filePath))</property>
                <property name="mlt_service">avformat</property>
              </producer>

            """
            producerIndex += 1
        }

        // Create main playlist
        xml += """
          <playlist id="main_playlist">

        """

        // Add video track clips
        for track in timeline.videoTracks {
            for segment in track.segments {
                guard let producerId = assetProducerMap[segment.sourceAssetId] else {
                    continue
                }

                let inTime = formatTime(segment.sourceIn)
                let outTime = formatTime(segment.sourceOut)

                xml += """
            <entry producer="\(producerId)" in="\(inTime)" out="\(outTime)" />

        """
            }
        }

        xml += """
          </playlist>

        """

        // Create tractor (multitrack container)
        xml += """
          <tractor id="tractor0">
            <multitrack>
              <track producer="main_playlist" />
            </multitrack>
          </tractor>
        </mlt>
        """

        return xml
    }

    /// Parse MLT XML to Polytropos timeline (import).
    public static func parse(xml: String) throws -> MLTImportResult {
        // XML parsing implementation
        // This would use XMLParser or similar

        return MLTImportResult(
            timeline: nil,
            assets: [],
            warnings: ["MLT import not yet fully implemented"]
        )
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

/// Result of MLT import.
public struct MLTImportResult {
    public var timeline: MultiTrackTimelineComponent?
    public var assets: [MediaAssetInfo]
    public var warnings: [String]
}

// MARK: - MLT Clip Adapter

/// Adapter for individual clip conversion to/from MLT.
public struct MLTClipAdapter {

    /// Convert Polytropos clip to MLT producer element.
    public static func toProducer(
        segment: ProClipSegment,
        asset: MediaAssetInfo,
        producerId: String
    ) -> String {
        let duration = segment.sourceOut - segment.sourceIn

        return """
        <producer id="\(producerId)">
          <property name="resource">\(asset.filePath)</property>
          <property name="mlt_service">avformat</property>
          <property name="length">\(duration)</property>
        </producer>
        """
    }

    /// Convert MLT producer to Polytropos clip info.
    public static func fromProducer(
        properties: [String: String]
    ) -> (filePath: String, duration: TimeInterval)? {
        guard let resource = properties["resource"],
              let lengthStr = properties["length"],
              let length = TimeInterval(lengthStr) else {
            return nil
        }

        return (resource, length)
    }
}

// MARK: - MLT Filter Adapter

/// Adapter for effect/filter conversion to/from MLT filters.
public struct MLTFilterAdapter {

    /// Convert color grade to MLT color filter.
    public static func colorGradeToFilter(
        grade: ColorGradeComponent
    ) -> String {
        guard grade.isEnabled, grade.blendAmount > 0 else { return "" }

        var filters: [String] = []

        let primary = grade.primaryCorrection
        let contrast = clamp(1.0 + (primary.contrast / 100.0), min: 0.0, max: 2.0)
        let brightness = clamp(primary.exposure / 5.0, min: -1.0, max: 1.0)
        let saturationBoost = (primary.saturation + (primary.vibrance * 0.5)) / 100.0
        let saturation = clamp(1.0 + saturationBoost, min: 0.0, max: 3.0)

        if primary.exposure != 0 || primary.contrast != 0 || primary.saturation != 0 || primary.vibrance != 0 {
            filters.append("""
            <filter mlt_service="avfilter.eq">
              <property name="avfilter.eq">contrast=\(format(contrast)):brightness=\(format(brightness)):saturation=\(format(saturation))</property>
            </filter>
            """)
        }

        let wheels = grade.colorWheels
        if wheelHasAdjustment(wheels.lift) || wheelHasAdjustment(wheels.gamma) || wheelHasAdjustment(wheels.gain) {
            let shadows = colorBalanceTriplet(from: wheels.lift)
            let midtones = colorBalanceTriplet(from: wheels.gamma)
            let highlights = colorBalanceTriplet(from: wheels.gain)
            filters.append("""
            <filter mlt_service="avfilter.colorbalance">
              <property name="avfilter.colorbalance">rs=\(format(shadows.r)):gs=\(format(shadows.g)):bs=\(format(shadows.b)):rm=\(format(midtones.r)):gm=\(format(midtones.g)):bm=\(format(midtones.b)):rh=\(format(highlights.r)):gh=\(format(highlights.g)):bh=\(format(highlights.b))</property>
            </filter>
            """)
        }

        if let lut = grade.lutReference, lut.intensity > 0 {
            filters.append("""
            <filter mlt_service="avfilter.lut3d">
              <property name="avfilter.lut3d">file=\(lut.path)</property>
            </filter>
            """)
        }

        return filters.joined(separator: "\n")
    }

    /// Convert audio processing to MLT audio filter.
    public static func audioProcessingToFilter(
        processing: AudioProcessingComponent
    ) -> String {
        var filters = ""

        for effect in processing.effects {
            switch effect.effectType {
            case .parametricEQ, .graphicEQ:
                filters += "<filter mlt_service=\"avfilter.equalizer\">\n"
                // Add EQ properties
                filters += "</filter>\n"

            case .compressor:
                filters += "<filter mlt_service=\"avfilter.acompressor\">\n"
                // Add compressor properties
                filters += "</filter>\n"

            case .reverb:
                filters += "<filter mlt_service=\"avfilter.areverb\">\n"
                // Add reverb properties
                filters += "</filter>\n"

            case .delay:
                filters += "<filter mlt_service=\"avfilter.adelay\">\n"
                // Add delay properties
                filters += "</filter>\n"
            default:
                // Skip unsupported effect types
                continue
            }
        }

        return filters
    }
}

private func clamp(_ value: Double, min: Double, max: Double) -> Double {
    if value < min { return min }
    if value > max { return max }
    return value
}

private func format(_ value: Double) -> String {
    String(format: "%.4f", value)
}

private func wheelHasAdjustment(_ wheel: ColorWheelValue) -> Bool {
    wheel.hue != 0 || wheel.saturation != 0 || wheel.master != 0
}

private func colorBalanceTriplet(from wheel: ColorWheelValue) -> (r: Double, g: Double, b: Double) {
    let sat = clamp(wheel.saturation, min: 0, max: 1)
    let intensity = clamp(wheel.master, min: -1, max: 1)
    if sat == 0 || intensity == 0 {
        return (0, 0, 0)
    }

    let rgb = rgbFromHue(wheel.hue)
    return (
        r: clamp(rgb.r * sat * intensity, min: -1, max: 1),
        g: clamp(rgb.g * sat * intensity, min: -1, max: 1),
        b: clamp(rgb.b * sat * intensity, min: -1, max: 1)
    )
}

private func rgbFromHue(_ hue: Double) -> (r: Double, g: Double, b: Double) {
    let normalized = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    let c = 1.0
    let x = c * (1 - abs((normalized / 60).truncatingRemainder(dividingBy: 2) - 1))
    switch normalized {
    case 0..<60:
        return (c, x, 0)
    case 60..<120:
        return (x, c, 0)
    case 120..<180:
        return (0, c, x)
    case 180..<240:
        return (0, x, c)
    case 240..<300:
        return (x, 0, c)
    default:
        return (c, 0, x)
    }
}

// MARK: - MLT Export Service

/// Service for exporting Polytropos project to MLT XML file.
public actor MLTExportService {

    /// Export project to MLT XML file.
    public func exportToMLT(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        outputPath: URL
    ) async throws {
        let xml = try MLTProjectAdapter.convert(
            timeline: timeline,
            assets: assets,
            configuration: ProExportConfiguration()
        )

        try xml.write(to: outputPath, atomically: true, encoding: .utf8)
    }

    /// Import MLT XML file to Polytropos project.
    public func importFromMLT(
        inputPath: URL
    ) async throws -> MLTImportResult {
        let xml = try String(contentsOf: inputPath, encoding: .utf8)
        return try MLTProjectAdapter.parse(xml: xml)
    }
}

// MARK: - EDL/AAF Support Stubs

/// EDL (Edit Decision List) format support.
public struct EDLAdapter {

    /// Export timeline to CMX 3600 EDL format.
    public static func exportCMX3600(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo]
    ) -> String {
        var edl = "TITLE: Polytropos Export\n"
        edl += "FCM: NON-DROP FRAME\n\n"

        var eventNumber = 1

        for track in timeline.videoTracks {
            for segment in track.segments {
                guard let asset = assets[segment.sourceAssetId] else {
                    continue
                }

                let srcIn = formatTimecode(segment.sourceIn)
                let srcOut = formatTimecode(segment.sourceOut)
                let recIn = formatTimecode(segment.timelineIn)
                let recOut = formatTimecode(segment.timelineOut)

                edl += String(format: "%03d  ", eventNumber)
                edl += "AX       "
                edl += "V     C        "
                edl += "\(srcIn) \(srcOut) \(recIn) \(recOut)\n"
                edl += "* FROM CLIP NAME: \(URL(fileURLWithPath: asset.filePath).lastPathComponent)\n"
                edl += "\n"

                eventNumber += 1
            }
        }

        return edl
    }

    private static func formatTimecode(_ seconds: TimeInterval, fps: Double = 24) -> String {
        let totalFrames = Int(seconds * fps)
        let frames = totalFrames % Int(fps)
        let secs = (totalFrames / Int(fps)) % 60
        let mins = (totalFrames / Int(fps) / 60) % 60
        let hours = totalFrames / Int(fps) / 3600

        return String(format: "%02d:%02d:%02d:%02d", hours, mins, secs, frames)
    }
}

/// FCPXML format support.
public struct FCPXMLAdapter {

    /// Export to Final Cut Pro X XML format.
    public static func export(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo]
    ) -> String {
        let fps: Double = 30
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
          <resources>
        """

        var assetIndex = 1
        var assetRefs: [EntityId: String] = [:]

        for (id, asset) in assets {
            let assetId = "r\(assetIndex)"
            assetRefs[id] = assetId
            xml += """

                <asset id="\(assetId)" name="\(URL(fileURLWithPath: asset.filePath).lastPathComponent)" src="file://\(asset.filePath)" />
            """
            assetIndex += 1
        }

        xml += """

          </resources>
          <library>
            <event name="Polytropos">
              <project name="Polytropos Export">
                <sequence duration="\(formatFCPDuration(timelineDuration(timeline), fps: fps))" format="r1">
                  <spine>
        """

        if let track = timeline.videoTracks.first {
            for segment in track.segments {
                guard let assetId = assetRefs[segment.sourceAssetId] else { continue }
                let duration = formatFCPDuration(segment.timelineDuration, fps: fps)
                let start = formatFCPDuration(segment.timelineIn, fps: fps)
                let srcIn = formatFCPDuration(segment.sourceIn, fps: fps)
                let srcDur = formatFCPDuration(segment.sourceOut - segment.sourceIn, fps: fps)
                xml += """

                    <asset-clip ref="\(assetId)" duration="\(duration)" start="\(start)" offset="\(start)">
                      <adjust-conform type="none" />
                      <timeMap>
                        <timept time="0s" value="\(srcIn)" />
                        <timept time="\(duration)" value="\(srcDur)" />
                      </timeMap>
                    </asset-clip>
                """
            }
        }

        xml += """

                  </spine>
                </sequence>
              </project>
            </event>
          </library>
        </fcpxml>
        """

        return xml
    }

    private static func timelineDuration(_ timeline: MultiTrackTimelineComponent) -> TimeInterval {
        let durations = timeline.videoTracks.flatMap { track in
            track.segments.map { $0.timelineOut }
        }
        return durations.max() ?? 0
    }

    private static func formatFCPDuration(_ seconds: TimeInterval, fps: Double) -> String {
        let frames = Int(seconds * fps)
        return "\(frames)/\(Int(fps))s"
    }
}
