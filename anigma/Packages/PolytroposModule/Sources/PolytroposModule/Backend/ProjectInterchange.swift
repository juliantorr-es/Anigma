//
//  ProjectInterchange.swift
//  PolytroposModule
//
//  Project interchange formats for import/export to external NLEs.
//  Supports MLT XML, EDL, FCPXML, and AAF formats.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Interchange Format Protocol

/// Protocol for project interchange format handlers.
public protocol ProjectInterchangeFormat: Sendable {
    /// Format identifier.
    static var formatId: InterchangeFormatId { get }

    /// Human-readable name.
    static var displayName: String { get }

    /// File extension.
    static var fileExtension: String { get }

    /// Export timeline to this format.
    static func export(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        metadata: ProjectMetadata
    ) throws -> Data

    /// Import from this format to Polytropos timeline.
    static func `import`(data: Data) throws -> InterchangeImportResult
}

/// Interchange format identifier.
public struct InterchangeFormatId: Hashable, Codable, Sendable {
    public let rawValue: String

    public static let mltXML = InterchangeFormatId(rawValue: "mlt_xml")
    public static let edl = InterchangeFormatId(rawValue: "edl")
    public static let fcpxml = InterchangeFormatId(rawValue: "fcpxml")
    public static let aaf = InterchangeFormatId(rawValue: "aaf")
    public static let otio = InterchangeFormatId(rawValue: "otio")  // OpenTimelineIO

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Project metadata for export.
public struct ProjectMetadata: Codable, Sendable {
    public var projectName: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var frameRate: Double
    public var resolution: ExportResolution
    public var author: String?
    public var notes: String?

    public init(
        projectName: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        frameRate: Double = 24,
        resolution: ExportResolution = .hd1080,
        author: String? = nil,
        notes: String? = nil
    ) {
        self.projectName = projectName
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.frameRate = frameRate
        self.resolution = resolution
        self.author = author
        self.notes = notes
    }
}

/// Result of import operation.
public struct InterchangeImportResult: Sendable {
    public var timeline: MultiTrackTimelineComponent?
    public var assets: [ImportedAssetInfo]
    public var markers: [TimelineMarker]
    public var metadata: ProjectMetadata?
    public var warnings: [ImportWarning]
    public var errors: [ImportError]

    public var success: Bool {
        timeline != nil && errors.isEmpty
    }

    public init(
        timeline: MultiTrackTimelineComponent? = nil,
        assets: [ImportedAssetInfo] = [],
        markers: [TimelineMarker] = [],
        metadata: ProjectMetadata? = nil,
        warnings: [ImportWarning] = [],
        errors: [ImportError] = []
    ) {
        self.timeline = timeline
        self.assets = assets
        self.markers = markers
        self.metadata = metadata
        self.warnings = warnings
        self.errors = errors
    }
}

/// Imported asset info (before matching to actual files).
public struct ImportedAssetInfo: Sendable {
    public var originalPath: String
    public var clipName: String
    public var duration: TimeInterval
    public var resolution: ExportResolution?
    public var frameRate: Double?

    public init(
        originalPath: String,
        clipName: String,
        duration: TimeInterval,
        resolution: ExportResolution? = nil,
        frameRate: Double? = nil
    ) {
        self.originalPath = originalPath
        self.clipName = clipName
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
    }
}

/// Import warning.
public struct ImportWarning: Sendable {
    public var code: String
    public var message: String
    public var context: String?

    public init(code: String, message: String, context: String? = nil) {
        self.code = code
        self.message = message
        self.context = context
    }
}

/// Import error.
public struct ImportError: Error, Sendable {
    public var code: String
    public var message: String
    public var context: String?

    public init(code: String, message: String, context: String? = nil) {
        self.code = code
        self.message = message
        self.context = context
    }
}

// MARK: - MLT XML Format

/// MLT XML interchange format.
public struct MLTXMLFormat: ProjectInterchangeFormat {
    public static let formatId = InterchangeFormatId.mltXML
    public static let displayName = "MLT XML"
    public static let fileExtension = "mlt"

    public static func export(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        metadata: ProjectMetadata
    ) throws -> Data {
        var xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <mlt LC_NUMERIC="C" version="7.0.0" producer="polytropos" title="\(escapeXML(metadata.projectName))">
              <profile
                description="\(metadata.resolution.width)x\(metadata.resolution.height) @ \(metadata.frameRate)fps"
                width="\(metadata.resolution.width)"
                height="\(metadata.resolution.height)"
                progressive="1"
                frame_rate_num="\(Int(metadata.frameRate * 1000))"
                frame_rate_den="1000"
                colorspace="709"
              />

            """

        // Add producers for each asset
        var producerIndex = 0
        var assetProducerMap: [EntityId: String] = [:]

        for (entityId, asset) in assets {
            let producerId = "producer\(producerIndex)"
            assetProducerMap[entityId] = producerId

            xml += """
                  <producer id="\(producerId)" in="00:00:00.000" out="\(formatMLTTime(asset.duration, fps: metadata.frameRate))">
                    <property name="resource">\(escapeXML(asset.filePath))</property>
                    <property name="mlt_service">avformat</property>
                    <property name="length">\(asset.duration)</property>
                """

            if let res = asset.resolution {
                xml += """

                        <property name="meta.media.width">\(res.width)</property>
                        <property name="meta.media.height">\(res.height)</property>
                    """
            }

            xml += """

                  </producer>

                """
            producerIndex += 1
        }

        // Create playlists for each track
        var trackIndex = 0
        var trackIds: [String] = []

        for track in timeline.videoTracks {
            let playlistId = "playlist\(trackIndex)"
            trackIds.append(playlistId)

            xml += """
                  <playlist id="\(playlistId)">
                    <property name="shotcut:name">\(escapeXML(track.name))</property>

                """

            for segment in track.segments {
                guard let producerId = assetProducerMap[segment.sourceAssetId] else {
                    continue
                }

                let inTime = formatMLTTime(segment.sourceIn, fps: metadata.frameRate)
                let outTime = formatMLTTime(segment.sourceOut, fps: metadata.frameRate)

                xml += """
                        <entry producer="\(producerId)" in="\(inTime)" out="\(outTime)" />

                    """
            }

            xml += """
                  </playlist>

                """
            trackIndex += 1
        }

        // Create tractor (multitrack container)
        xml += """
              <tractor id="tractor0" in="00:00:00.000">
                <multitrack>

            """

        for trackId in trackIds {
            xml += """
                      <track producer="\(trackId)" />

                """
        }

        xml += """
                </multitrack>
              </tractor>
            </mlt>
            """

        guard let data = xml.data(using: .utf8) else {
            throw ImportError(code: "ENCODING_FAILED", message: "Failed to encode XML")
        }

        return data
    }

    public static func `import`(data: Data) throws -> InterchangeImportResult {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw ImportError(code: "INVALID_ENCODING", message: "Data is not valid UTF-8")
        }

        // Basic XML parsing - in production use XMLParser
        var result = InterchangeImportResult()
        result.warnings.append(
            ImportWarning(
                code: "PARTIAL_IMPORT",
                message: "MLT import is basic - some features may not be preserved"
            ))

        // Extract producers (assets)
        let producerPattern =
            #"<producer[^>]*id="([^"]*)"[^>]*>[\s\S]*?<property name="resource">([^<]*)</property>[\s\S]*?</producer>"#

        if let regex = try? NSRegularExpression(pattern: producerPattern, options: []) {
            let matches = regex.matches(
                in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))

            for match in matches {
                if let resourceRange = Range(match.range(at: 2), in: xmlString) {
                    let path = String(xmlString[resourceRange])
                    result.assets.append(
                        ImportedAssetInfo(
                            originalPath: path,
                            clipName: URL(fileURLWithPath: path).lastPathComponent,
                            duration: 0  // Would need to probe
                        ))
                }
            }
        }

        return result
    }

    private static func formatMLTTime(_ seconds: TimeInterval, fps: Double) -> String {
        let totalFrames = Int(seconds * fps)
        let frames = totalFrames % Int(fps)
        let secs = (totalFrames / Int(fps)) % 60
        let mins = (totalFrames / Int(fps) / 60) % 60
        let hours = totalFrames / Int(fps) / 3600

        return String(
            format: "%02d:%02d:%02d.%03d", hours, mins, secs, Int(Double(frames) / fps * 1000))
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

// MARK: - EDL Format

/// CMX 3600 EDL interchange format.
public struct EDLFormat: ProjectInterchangeFormat {
    public static let formatId = InterchangeFormatId.edl
    public static let displayName = "CMX 3600 EDL"
    public static let fileExtension = "edl"

    public static func export(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        metadata: ProjectMetadata
    ) throws -> Data {
        var edl = "TITLE: \(metadata.projectName)\n"
        edl += "FCM: NON-DROP FRAME\n\n"

        var eventNumber = 1

        for track in timeline.videoTracks {
            for segment in track.segments {
                guard let asset = assets[segment.sourceAssetId] else {
                    continue
                }

                let clipName = URL(fileURLWithPath: asset.filePath)
                    .deletingPathExtension()
                    .lastPathComponent
                    .prefix(8)
                    .uppercased()
                    .padding(toLength: 8, withPad: " ", startingAt: 0)

                let srcIn = formatTimecode(segment.sourceIn, fps: metadata.frameRate)
                let srcOut = formatTimecode(segment.sourceOut, fps: metadata.frameRate)
                let recIn = formatTimecode(segment.timelineIn, fps: metadata.frameRate)
                let recOut = formatTimecode(segment.timelineOut, fps: metadata.frameRate)

                // Event line
                edl += String(format: "%03d  ", eventNumber)
                edl += "\(clipName) "
                edl += "V     C        "
                edl += "\(srcIn) \(srcOut) \(recIn) \(recOut)\n"

                // Source file comment
                edl +=
                    "* FROM CLIP NAME: \(URL(fileURLWithPath: asset.filePath).lastPathComponent)\n"
                edl += "* SOURCE FILE: \(asset.filePath)\n"
                edl += "\n"

                eventNumber += 1
            }
        }

        guard let data = edl.data(using: .utf8) else {
            throw ImportError(code: "ENCODING_FAILED", message: "Failed to encode EDL")
        }

        return data
    }

    public static func `import`(data: Data) throws -> InterchangeImportResult {
        guard let edlString = String(data: data, encoding: .utf8) else {
            throw ImportError(code: "INVALID_ENCODING", message: "Data is not valid UTF-8")
        }

        var result = InterchangeImportResult()
        var _: [ProClipSegment] = []

        let lines = edlString.components(separatedBy: .newlines)
        var currentSourceFile: String?

        for line in lines {
            // Extract title
            if line.hasPrefix("TITLE:") {
                let title = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                result.metadata = ProjectMetadata(projectName: title)
            }

            // Extract source file from comment
            if line.hasPrefix("* SOURCE FILE:") || line.hasPrefix("* FROM CLIP NAME:") {
                currentSourceFile = line.components(separatedBy: ":").last?
                    .trimmingCharacters(in: .whitespaces)
            }

            // Parse event line (starts with 3 digit number)
            let eventPattern =
                #"^(\d{3})\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d{2}:\d{2}:\d{2}:\d{2})\s+(\d{2}:\d{2}:\d{2}:\d{2})\s+(\d{2}:\d{2}:\d{2}:\d{2})\s+(\d{2}:\d{2}:\d{2}:\d{2})"#

            if let regex = try? NSRegularExpression(pattern: eventPattern),
                let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                // Parse timecodes
                func extractTimecode(_ groupIndex: Int) -> TimeInterval? {
                    guard let range = Range(match.range(at: groupIndex), in: line) else {
                        return nil
                    }
                    return parseTimecode(String(line[range]))
                }

                if let srcIn = extractTimecode(5),
                    let srcOut = extractTimecode(6),
                    extractTimecode(7) != nil,
                    extractTimecode(8) != nil {

                    if let sourceFile = currentSourceFile {
                        result.assets.append(
                            ImportedAssetInfo(
                                originalPath: sourceFile,
                                clipName: sourceFile,
                                duration: srcOut - srcIn
                            ))
                    }

                    // Note: We can't create full ProClipSegment without EntityId
                    // This would need to be resolved later when matching assets
                }

                currentSourceFile = nil
            }
        }

        result.warnings.append(
            ImportWarning(
                code: "EDL_IMPORT_PARTIAL",
                message: "EDL import requires matching source files to complete"
            ))

        return result
    }

    private static func formatTimecode(_ seconds: TimeInterval, fps: Double = 24) -> String {
        let totalFrames = Int(seconds * fps)
        let frames = totalFrames % Int(fps)
        let secs = (totalFrames / Int(fps)) % 60
        let mins = (totalFrames / Int(fps) / 60) % 60
        let hours = totalFrames / Int(fps) / 3600

        return String(format: "%02d:%02d:%02d:%02d", hours, mins, secs, frames)
    }

    private static func parseTimecode(_ tc: String, fps: Double = 24) -> TimeInterval? {
        let parts = tc.split(separator: ":")
        guard parts.count == 4,
            let hours = Int(parts[0]),
            let mins = Int(parts[1]),
            let secs = Int(parts[2]),
            let frames = Int(parts[3])
        else {
            return nil
        }

        let totalSeconds = Double(hours * 3600 + mins * 60 + secs) + Double(frames) / fps
        return totalSeconds
    }
}

// MARK: - FCPXML Format

/// Final Cut Pro X XML interchange format.
public struct FCPXMLFormat: ProjectInterchangeFormat {
    public static let formatId = InterchangeFormatId.fcpxml
    public static let displayName = "Final Cut Pro XML"
    public static let fileExtension = "fcpxml"

    public static func export(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        metadata: ProjectMetadata
    ) throws -> Data {
        // FCPXML is complex - this is a basic implementation
        var xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE fcpxml>
            <fcpxml version="1.10">
              <resources>

            """

        // Add format
        xml += """
                <format id="r1" name="FFVideoFormat\(metadata.resolution.height)p\(Int(metadata.frameRate))" />

            """

        // Add assets
        var assetIndex = 1
        var assetIdMap: [EntityId: String] = [:]

        for (entityId, asset) in assets {
            let assetId = "r\(assetIndex + 1)"
            assetIdMap[entityId] = assetId

            xml += """
                    <asset id="\(assetId)" name="\(escapeXML(URL(fileURLWithPath: asset.filePath).lastPathComponent))" src="file://\(escapeXML(asset.filePath))" duration="\(formatFCPDuration(asset.duration, fps: metadata.frameRate))" hasVideo="1" hasAudio="1" />

                """
            assetIndex += 1
        }

        xml += """
              </resources>
              <library>
                <event name="Polytropos Export">
                  <project name="\(escapeXML(metadata.projectName))">
                    <sequence format="r1">
                      <spine>

            """

        // Add clips
        for track in timeline.videoTracks {
            for segment in track.segments {
                guard let assetId = assetIdMap[segment.sourceAssetId] else {
                    continue
                }

                let duration = formatFCPDuration(segment.timelineDuration, fps: metadata.frameRate)
                let start = formatFCPDuration(segment.sourceIn, fps: metadata.frameRate)

                xml += """
                                <asset-clip ref="\(assetId)" duration="\(duration)" start="\(start)" />

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

        guard let data = xml.data(using: .utf8) else {
            throw ImportError(code: "ENCODING_FAILED", message: "Failed to encode FCPXML")
        }

        return data
    }

    public static func `import`(data: Data) throws -> InterchangeImportResult {
        var result = InterchangeImportResult()
        result.warnings.append(
            ImportWarning(
                code: "FCPXML_IMPORT_NOT_IMPLEMENTED",
                message: "FCPXML import is not yet implemented"
            ))
        return result
    }

    private static func formatFCPDuration(_ seconds: TimeInterval, fps: Double) -> String {
        let frames = Int(seconds * fps)
        return "\(frames)/\(Int(fps))s"
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - OpenTimelineIO Format

/// OpenTimelineIO interchange format.
public struct OTIOFormat: ProjectInterchangeFormat {
    public static let formatId = InterchangeFormatId.otio
    public static let displayName = "OpenTimelineIO"
    public static let fileExtension = "otio"

    public static func export(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        metadata: ProjectMetadata
    ) throws -> Data {
        // OTIO uses JSON format
        var otio: [String: Any] = [
            "OTIO_SCHEMA": "Timeline.1",
            "name": metadata.projectName,
            "global_start_time": NSNull(),
            "tracks": [] as [[String: Any]]
        ]

        // Convert tracks
        var tracks: [[String: Any]] = []

        for track in timeline.videoTracks {
            var otioTrack: [String: Any] = [
                "OTIO_SCHEMA": "Track.1",
                "name": track.name,
                "kind": "Video",
                "children": [] as [[String: Any]]
            ]

            var children: [[String: Any]] = []

            for segment in track.segments {
                guard let asset = assets[segment.sourceAssetId] else { continue }

                children.append([
                    "OTIO_SCHEMA": "Clip.1",
                    "name": URL(fileURLWithPath: asset.filePath).lastPathComponent,
                    "source_range": [
                        "OTIO_SCHEMA": "TimeRange.1",
                        "start_time": [
                            "OTIO_SCHEMA": "RationalTime.1",
                            "value": segment.sourceIn,
                            "rate": metadata.frameRate
                        ],
                        "duration": [
                            "OTIO_SCHEMA": "RationalTime.1",
                            "value": segment.timelineDuration,
                            "rate": metadata.frameRate
                        ]
                    ],
                    "media_reference": [
                        "OTIO_SCHEMA": "ExternalReference.1",
                        "target_url": asset.filePath
                    ]
                ])
            }

            otioTrack["children"] = children
            tracks.append(otioTrack)
        }

        otio["tracks"] = [
            "OTIO_SCHEMA": "Stack.1",
            "children": tracks
        ]

        let data = try JSONSerialization.data(withJSONObject: otio, options: .prettyPrinted)
        return data
    }

    public static func `import`(data: Data) throws -> InterchangeImportResult {
        var result = InterchangeImportResult()
        result.warnings.append(
            ImportWarning(
                code: "OTIO_IMPORT_NOT_IMPLEMENTED",
                message: "OpenTimelineIO import is not yet implemented"
            ))
        return result
    }
}

// MARK: - Interchange Service

/// Service for managing project interchange operations.
public actor ProjectInterchangeService {

    /// Available formats.
    private let formats: [InterchangeFormatId: any ProjectInterchangeFormat.Type] = [
        .mltXML: MLTXMLFormat.self,
        .edl: EDLFormat.self,
        .fcpxml: FCPXMLFormat.self,
        .otio: OTIOFormat.self
    ]

    public init() {}

    /// Get available export formats.
    public func availableFormats() -> [(id: InterchangeFormatId, name: String, ext: String)] {
        formats.map { (id: $0.key, name: $0.value.displayName, ext: $0.value.fileExtension) }
    }

    /// Export project to specified format.
    public func export(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        metadata: ProjectMetadata,
        format: InterchangeFormatId,
        outputPath: URL
    ) async throws {
        guard let formatType = formats[format] else {
            throw ImportError(code: "UNKNOWN_FORMAT", message: "Unknown format: \(format.rawValue)")
        }

        let data = try formatType.export(timeline: timeline, assets: assets, metadata: metadata)
        try data.write(to: outputPath)
    }

    /// Import project from file.
    public func importProject(
        from path: URL
    ) async throws -> InterchangeImportResult {
        let ext = path.pathExtension.lowercased()

        // Find format by extension
        guard let formatType = formats.values.first(where: { $0.fileExtension == ext }) else {
            throw ImportError(code: "UNKNOWN_FORMAT", message: "Unknown file extension: \(ext)")
        }

        let data = try Data(contentsOf: path)
        return try formatType.import(data: data)
    }

    /// Attempt to resolve imported assets to actual files.
    public func resolveAssets(
        importResult: InterchangeImportResult,
        searchPaths: [URL]
    ) async -> [(asset: ImportedAssetInfo, resolvedPath: URL?)] {
        var resolved: [(ImportedAssetInfo, URL?)] = []

        for asset in importResult.assets {
            var foundPath: URL?

            // Try original path first
            if FileManager.default.fileExists(atPath: asset.originalPath) {
                foundPath = URL(fileURLWithPath: asset.originalPath)
            } else {
                // Search in provided paths
                let filename = URL(fileURLWithPath: asset.originalPath).lastPathComponent

                for searchPath in searchPaths {
                    let candidatePath = searchPath.appendingPathComponent(filename)
                    if FileManager.default.fileExists(atPath: candidatePath.path) {
                        foundPath = candidatePath
                        break
                    }
                }
            }

            resolved.append((asset, foundPath))
        }

        return resolved
    }
}
