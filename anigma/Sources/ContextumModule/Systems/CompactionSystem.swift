import Foundation
import ContractsCore
import CompressionKit
import CapsuleCore
import OSLog

/// System for compacting storage with integrity preservation
public actor CompactionSystem {
    static let logger = Logger(subsystem: "com.anigma.ContextumModule", category: "CompactionSystem")
    private let database: ContextumDatabase
    private let telemetryDirectory: URL?
    private let maxSegmentSizeBytes: Int64
    private let maxSegmentAgeSeconds: TimeInterval

    public init(
        database: ContextumDatabase,
        telemetryDirectory: URL? = nil,
        maxSegmentSizeBytes: Int64 = 100 * 1024 * 1024,  // 100 MB default
        maxSegmentAgeSeconds: TimeInterval = 7 * 24 * 3600  // 7 days default
    ) {
        self.database = database
        self.telemetryDirectory = telemetryDirectory
        self.maxSegmentSizeBytes = maxSegmentSizeBytes
        self.maxSegmentAgeSeconds = maxSegmentAgeSeconds
    }

    /// Run compaction on database and telemetry logs
    public func runCompaction() async throws -> CompactionReport {
        let runID = UUID().uuidString
        let startTime = Date()

        // Compact database (VACUUM, optimize FTS)
        let dbStats = try await compactDatabase()

        // Compact/roll NDJSON telemetry segments
        let logStats = try await compactTelemetryLogs()

        let endTime = Date()

        return CompactionReport(
            runID: runID,
            startedAt: startTime,
            completedAt: endTime,
            databaseBytesReclaimed: dbStats,
            logSegmentsProcessed: logStats.0,
            logBytesReclaimed: logStats.1
        )
    }

    private func compactDatabase() async throws -> Int64 {
        let sizeBefore = try await database.getDatabaseSize()
        try await database.vacuum()
        try await database.optimizeFTS()
        let sizeAfter = try await database.getDatabaseSize()
        return max(0, sizeBefore - sizeAfter)
    }

    private func compactTelemetryLogs() async throws -> (segmentsProcessed: Int, bytesReclaimed: Int64) {
        guard let telemetryDir = telemetryDirectory else {
            Self.logger.info("No telemetry directory configured, skipping log compaction")
            return (0, 0)
        }

        // Ensure directory exists
        guard FileManager.default.fileExists(atPath: telemetryDir.path) else {
            Self.logger.warning("Telemetry directory does not exist: \(telemetryDir.path, privacy: .public)")
            return (0, 0)
        }

        var totalBytesReclaimed: Int64 = 0
        var segmentsProcessed = 0

        // Find all NDJSON telemetry segment files
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: telemetryDir,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }

        var segmentsToArchive: [(url: URL, size: Int64, age: TimeInterval)] = []

        let files = enumerator.allObjects.compactMap { $0 as? URL }

        // Scan for segments that need compaction
        for fileURL in files {
            // Only process .ndjson files
            guard fileURL.pathExtension == "ndjson" else { continue }

            do {
                let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = (attrs[FileAttributeKey.size] as? Int64) ?? 0
                let creationDate = (attrs[FileAttributeKey.creationDate] as? Date) ?? Date()
                let age = Date().timeIntervalSince(creationDate)

                // Archive if file is too large OR too old
                if fileSize > maxSegmentSizeBytes || age > maxSegmentAgeSeconds {
                    segmentsToArchive.append((url: fileURL, size: fileSize, age: age))
                }
            } catch {
                Self.logger.warning("Failed to get attributes for \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                continue
            }
        }

        // Archive segments by compressing them
        for segment in segmentsToArchive {
            do {
                let bytesReclaimed = try await archiveSegment(segment.url, originalSize: segment.size)
                totalBytesReclaimed += bytesReclaimed
                segmentsProcessed += 1

                Self.logger.info("Archived segment \(segment.url.lastPathComponent, privacy: .public) (reclaimed \(bytesReclaimed, privacy: .public) bytes)")
            } catch {
                Self.logger.error("Failed to archive segment \(segment.url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if segmentsProcessed > 0 {
            Self.logger.info("Compacted \(segmentsProcessed, privacy: .public) telemetry segments, reclaimed \(totalBytesReclaimed, privacy: .public) bytes")
        }

        return (segmentsProcessed, totalBytesReclaimed)
    }

    /// Archive a telemetry segment by compressing it and replacing the original
    private func archiveSegment(_ segmentURL: URL, originalSize: Int64) async throws -> Int64 {
        let fileManager = FileManager.default

        // Read original file
        let originalData = try Data(contentsOf: segmentURL)

        // Compress using CompressionCapsuleWrapper with zstd deterministic mode
        let compressedData: Data
        do {
            let config = CompressionConfig(
                algorithm: .zstd,
                mode: .deterministic,
                level: .default,
                bufferPoolSize: 0,
                determinismTier: 1 // ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
            )
            let compressor = try CompressionCapsule(config: config)
            compressedData = try await compressor.compress(originalData)
        } catch {
            // Fall back to Apple's compression if capsule fails
            Self.logger.warning(
                "Compression capsule failed for \(segmentURL.lastPathComponent, privacy: .public); falling back to zlib: \(error.localizedDescription, privacy: .public)"
            )
            guard let fallbackData = try? (originalData as NSData).compressed(using: .zlib) as Data else {
                throw NSError(domain: "CompactionSystem", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to compress segment: \(error)"
                ])
            }
            compressedData = fallbackData
        }

        // Create archived filename (add .zst extension for zstd)
        let archivedURL = segmentURL.deletingPathExtension().appendingPathExtension("ndjson.zst")

        // Write compressed data
        try compressedData.write(to: archivedURL)

        // Delete original
        try fileManager.removeItem(at: segmentURL)

        // Calculate bytes reclaimed (original size - compressed size)
        let bytesReclaimed = max(0, originalSize - Int64(compressedData.count))

        return bytesReclaimed
    }
}

/// Compaction report artifact
public struct CompactionReport: Codable, Sendable {
    public let runID: String
    public let startedAt: Date
    public let completedAt: Date
    public let databaseBytesReclaimed: Int64
    public let logSegmentsProcessed: Int
    public let logBytesReclaimed: Int64
}

extension ContextumDatabase {
    func vacuum() async throws {
        _ = try await database.executeAsync("VACUUM")
    }

    func optimizeFTS() async throws {
        _ = try await database.executeAsync("INSERT INTO fts_chunks(fts_chunks) VALUES('optimize')")
    }

    func getDatabaseSize() async throws -> Int64 {
        // Access database path from ContextumDatabase
        return await self.getDatabaseSizeInternal()
    }

    private func getDatabaseSizeInternal() async -> Int64 {
        guard let path = databasePath else {
            CompactionSystem.logger.warning("Database path not set, cannot calculate size")
            return 0
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = attrs[FileAttributeKey.size] as? Int64 {
                return fileSize
            } else {
                CompactionSystem.logger.warning("Could not read file size attribute from database")
                return 0
            }
        } catch {
            CompactionSystem.logger.error("Failed to get database size at '\(path, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return 0  // Return 0 instead of throwing to not break compaction
        }
    }
}
