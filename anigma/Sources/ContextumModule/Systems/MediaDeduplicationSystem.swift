import Foundation
import CapsuleCore
import DatabaseCore
import AnigmaNativeShims
import MediaFingerprintCapsule

public struct MediaDeduplicationSystem {
    public struct MediaFingerprint: Codable, Sendable {
        public let fingerprintId: String
        public let sourceId: String
        public let mediaType: MediaType
        public let algorithm: FingerprintAlgorithm
        public let hashData: Data
        public let hashSize: UInt32
        public let confidence: Double
        public let durationMs: UInt32?
        public let width: UInt32?
        public let height: UInt32?
        public let fileSize: UInt64
        public let format: String?
        public let createdAt: Date

        public init(
            fingerprintId: String,
            sourceId: String,
            mediaType: MediaType,
            algorithm: FingerprintAlgorithm,
            hashData: Data,
            hashSize: UInt32,
            confidence: Double,
            durationMs: UInt32? = nil,
            width: UInt32? = nil,
            height: UInt32? = nil,
            fileSize: UInt64,
            format: String? = nil,
            createdAt: Date = Date()
        ) {
            self.fingerprintId = fingerprintId
            self.sourceId = sourceId
            self.mediaType = mediaType
            self.algorithm = algorithm
            self.hashData = hashData
            self.hashSize = hashSize
            self.confidence = confidence
            self.durationMs = durationMs
            self.width = width
            self.height = height
            self.fileSize = fileSize
            self.format = format
            self.createdAt = createdAt
        }
    }

    public struct DuplicateMatch: Codable, Sendable {
        public let sourceId: String
        public let fingerprintId: String
        public let similarity: Float
        public let hammingDistance: UInt32
        public let isExactDuplicate: Bool
        public let isNearDuplicate: Bool

        public init(
            sourceId: String,
            fingerprintId: String,
            similarity: Float,
            hammingDistance: UInt32,
            isExactDuplicate: Bool,
            isNearDuplicate: Bool
        ) {
            self.sourceId = sourceId
            self.fingerprintId = fingerprintId
            self.similarity = similarity
            self.hammingDistance = hammingDistance
            self.isExactDuplicate = isExactDuplicate
            self.isNearDuplicate = isNearDuplicate
        }
    }

    public struct DuplicateDetectionResult: Sendable {
        public let fingerprint: MediaFingerprint
        public let duplicates: [DuplicateMatch]
        public let hasDuplicates: Bool
        public let exactDuplicate: DuplicateMatch?
        public let nearDuplicates: [DuplicateMatch]
        public let detectionMethod: DetectionMethod
        public let processingTimeMs: UInt64

        public init(
            fingerprint: MediaFingerprint,
            duplicates: [DuplicateMatch],
            hasDuplicates: Bool,
            exactDuplicate: DuplicateMatch?,
            nearDuplicates: [DuplicateMatch],
            detectionMethod: DetectionMethod,
            processingTimeMs: UInt64
        ) {
            self.fingerprint = fingerprint
            self.duplicates = duplicates
            self.hasDuplicates = hasDuplicates
            self.exactDuplicate = exactDuplicate
            self.nearDuplicates = nearDuplicates
            self.detectionMethod = detectionMethod
            self.processingTimeMs = processingTimeMs
        }
    }

    public enum DetectionMethod: String, Sendable {
        case capsule
        case hashFallback
        case metadataOnly
    }

    public enum DeduplicationError: Error, Sendable {
        case invalidMediaData
        case fingerprintGenerationFailed(String)
        case databaseError(String)
        case capsuleUnavailable
        case unsupportedMediaType(MediaType)
    }

    private let database: ContextumDatabase
    private let capsule: MediaFingerprintCapsuleWrapper?
    private let fallbackHashAlgorithm: String

    public static let shared: MediaDeduplicationSystem? = nil

    public init(
        database: ContextumDatabase,
        capsule: MediaFingerprintCapsuleWrapper? = nil,
        fallbackHashAlgorithm: String = "SHA256"
    ) {
        self.database = database
        self.capsule = capsule
        self.fallbackHashAlgorithm = fallbackHashAlgorithm
    }

    @discardableResult
    public func generateFingerprint(
        for data: Data,
        mediaType: MediaType,
        sourceId: String
    ) async throws -> MediaFingerprint {
        guard !data.isEmpty else {
            throw DeduplicationError.invalidMediaData
        }

        let detectedType = mediaType == .unknown
            ? try MediaFingerprintCapsuleWrapper.detectMediaType(data)
            : mediaType

        guard detectedType != .unknown else {
            throw DeduplicationError.unsupportedMediaType(mediaType)
        }

        let fingerprintId = UUID().uuidString
        let startTime = UInt64(Date().timeIntervalSince1970 * 1000)

        if let capsule = self.capsule {
            return try await generateFingerprintWithCapsule(
                data: data,
                mediaType: detectedType,
                sourceId: sourceId,
                fingerprintId: fingerprintId,
                startTime: startTime
            )
        } else {
            return try await generateFingerprintWithHashFallback(
                data: data,
                mediaType: detectedType,
                sourceId: sourceId,
                fingerprintId: fingerprintId,
                startTime: startTime
            )
        }
    }

    private func generateFingerprintWithCapsule(
        data: Data,
        mediaType: MediaType,
        sourceId: String,
        fingerprintId: String,
        startTime: UInt64
    ) async throws -> MediaFingerprint {
        let algorithm: FingerprintAlgorithm
        let fingerprintResult: FingerprintResult

        switch mediaType {
        case .image:
            algorithm = .perceptualHash
            fingerprintResult = try capsule.generateImageFingerprint(data, algorithm: algorithm)
        case .audio:
            algorithm = .chromaprint
            fingerprintResult = try capsule.generateAudioFingerprint(data, algorithm: algorithm)
        case .video:
            algorithm = .motionVector
            fingerprintResult = try capsule.generateVideoFingerprint(data, algorithm: algorithm)
        case .unknown:
            throw DeduplicationError.unsupportedMediaType(mediaType)
        }

        let metadata = try? capsule.analyzeMedia(data, mediaType: mediaType)

        return MediaFingerprint(
            fingerprintId: fingerprintId,
            sourceId: sourceId,
            mediaType: mediaType,
            algorithm: algorithm,
            hashData: fingerprintResult.hashData,
            hashSize: fingerprintResult.hashSize,
            confidence: fingerprintResult.confidence,
            durationMs: metadata.map { $0.durationMs },
            width: metadata.map { $0.width },
            height: metadata.map { $0.height },
            fileSize: UInt64(data.count),
            format: metadata?.format,
            createdAt: Date()
        )
    }

    private func generateFingerprintWithHashFallback(
        data: Data,
        mediaType: MediaType,
        sourceId: String,
        fingerprintId: String,
        startTime: UInt64
    ) async throws -> MediaFingerprint {
        let hashData: Data
        let hashSize: UInt32

        switch fallbackHashAlgorithm {
        case "SHA256":
            let hash = Insecure.SHA256.hash(data: data)
            hashData = Data(hash)
            hashSize = UInt32(hash.count * 8)
        case "SHA512":
            let hash = SHA512.hash(data: data)
            hashData = Data(hash)
            hashSize = UInt32(hash.count * 8)
        default:
            let hash = Insecure.SHA256.hash(data: data)
            hashData = Data(hash)
            hashSize = UInt32(hash.count * 8)
        }

        return MediaFingerprint(
            fingerprintId: fingerprintId,
            sourceId: sourceId,
            mediaType: mediaType,
            algorithm: .perceptualHash,
            hashData: hashData,
            hashSize: hashSize,
            confidence: 0.5,
            fileSize: UInt64(data.count),
            createdAt: Date()
        )
    }

    public func findDuplicates(
        for fingerprint: MediaFingerprint,
        threshold: Float = 0.85,
        limit: Int = 100
    ) async throws -> DuplicateDetectionResult {
        let startTime = UInt64(Date().timeIntervalSince1970 * 1000)

        let existingFingerprints = try await database.getMediaFingerprints(
            mediaType: fingerprint.mediaType,
            limit: limit * 2
        )

        guard !existingFingerprints.isEmpty else {
            return DuplicateDetectionResult(
                fingerprint: fingerprint,
                duplicates: [],
                hasDuplicates: false,
                exactDuplicate: nil,
                nearDuplicates: [],
                detectionMethod: .metadataOnly,
                processingTimeMs: UInt64(Date().timeIntervalSince1970 * 1000) - startTime
            )
        }

        var allMatches: [DuplicateMatch] = []

        if let capsule = self.capsule {
            allMatches = try await findDuplicatesWithCapsule(
                fingerprint: fingerprint,
                existingFingerprints: existingFingerprints,
                threshold: threshold
            )
        } else {
            allMatches = findDuplicatesWithHashFallback(
                fingerprint: fingerprint,
                existingFingerprints: existingFingerprints,
                threshold: threshold
            )
        }

        let exactDuplicate = allMatches.first { $0.isExactDuplicate }
        let nearDuplicates = allMatches.filter { $0.isNearDuplicate && !$0.isExactDuplicate }

        return DuplicateDetectionResult(
            fingerprint: fingerprint,
            duplicates: allMatches,
            hasDuplicates: !allMatches.isEmpty,
            exactDuplicate: exactDuplicate,
            nearDuplicates: nearDuplicates,
            detectionMethod: capsule != nil ? .capsule : .hashFallback,
            processingTimeMs: UInt64(Date().timeIntervalSince1970 * 1000) - startTime
        )
    }

    private func findDuplicatesWithCapsule(
        fingerprint: MediaFingerprint,
        existingFingerprints: [MediaFingerprint],
        threshold: Float
    ) async throws -> [DuplicateMatch] {
        guard let capsule = self.capsule else {
            return findDuplicatesWithHashFallback(
                fingerprint: fingerprint,
                existingFingerprints: existingFingerprints,
                threshold: threshold
            )
        }

        let queryFingerprint = FingerprintResult(
            algorithm: fingerprint.algorithm,
            hashSize: fingerprint.hashSize,
            hashData: fingerprint.hashData,
            confidence: fingerprint.confidence,
            processingTimeMs: 0
        )

        let candidateFingerprints = existingFingerprints.map { existing in
            FingerprintResult(
                algorithm: existing.algorithm,
                hashSize: existing.hashSize,
                hashData: existing.hashData,
                confidence: existing.confidence,
                processingTimeMs: 0
            )
        }

        let similarityConfig = SimilarityConfiguration(
            similarityThreshold: Double(threshold),
            useHammingDistance: true,
            enablePartialMatching: true,
            partialMatchThreshold: Double(threshold * 0.75)
        )

        let similarityResults: [SimilarityResult]
        do {
            similarityResults = try capsule.batchCompareFingerprints(
                queryFingerprint: queryFingerprint,
                candidateFingerprints: candidateFingerprints,
                config: similarityConfig
            )
        } catch {
            return findDuplicatesWithHashFallback(
                fingerprint: fingerprint,
                existingFingerprints: existingFingerprints,
                threshold: threshold
            )
        }

        var matches: [DuplicateMatch] = []
        for (index, existing) in existingFingerprints.enumerated() {
            guard index < similarityResults.count else { break }
            let result = similarityResults[index]

            if result.similarityScore >= Double(threshold) || result.isDuplicate {
                let similarity = Float(result.similarityScore)
                let isExactDuplicate = result.isDuplicate || result.hammingDistance <= 2
                let isNearDuplicate = similarity >= threshold && !isExactDuplicate

                matches.append(DuplicateMatch(
                    sourceId: existing.sourceId,
                    fingerprintId: existing.fingerprintId,
                    similarity: similarity,
                    hammingDistance: result.hammingDistance,
                    isExactDuplicate: isExactDuplicate,
                    isNearDuplicate: isNearDuplicate
                ))
            }
        }

        return matches
    }

    private func findDuplicatesWithHashFallback(
        fingerprint: MediaFingerprint,
        existingFingerprints: [MediaFingerprint],
        threshold: Float
    ) -> [DuplicateMatch] {
        var matches: [DuplicateMatch] = []

        for existing in existingFingerprints {
            if fingerprint.hashData == existing.hashData {
                matches.append(DuplicateMatch(
                    sourceId: existing.sourceId,
                    fingerprintId: existing.fingerprintId,
                    similarity: 1.0,
                    hammingDistance: 0,
                    isExactDuplicate: true,
                    isNearDuplicate: false
                ))
            } else {
                let hammingDistance = calculateHammingDistance(
                    fingerprint.hashData,
                    existing.hashData
                )
                let maxBits = max(fingerprint.hashSize, existing.hashSize)
                let similarity = maxBits > 0 ? 1.0 - (Float(hammingDistance) / Float(maxBits)) : 0.0

                if similarity >= threshold {
                    matches.append(DuplicateMatch(
                        sourceId: existing.sourceId,
                        fingerprintId: existing.fingerprintId,
                        similarity: similarity,
                        hammingDistance: hammingDistance,
                        isExactDuplicate: false,
                        isNearDuplicate: similarity >= threshold * 0.9
                    ))
                }
            }
        }

        return matches
    }

    public func isDuplicate(
        of fingerprint: MediaFingerprint,
        existingFingerprints: [MediaFingerprint],
        threshold: Float = 0.85
    ) -> Bool {
        guard !existingFingerprints.isEmpty else { return false }

        if let capsule = self.capsule {
            let queryFingerprint = FingerprintResult(
                algorithm: fingerprint.algorithm,
                hashSize: fingerprint.hashSize,
                hashData: fingerprint.hashData,
                confidence: fingerprint.confidence,
                processingTimeMs: 0
            )

            for existing in existingFingerprints {
                let candidateFingerprint = FingerprintResult(
                    algorithm: existing.algorithm,
                    hashSize: existing.hashSize,
                    hashData: existing.hashData,
                    confidence: existing.confidence,
                    processingTimeMs: 0
                )

                do {
                    let result = try capsule.compareFingerprints(
                        queryFingerprint,
                        candidateFingerprint
                    )

                    if result.isDuplicate || result.similarityScore >= Double(threshold) {
                        return true
                    }
                } catch {
                    continue
                }
            }
        } else {
            for existing in existingFingerprints {
                if fingerprint.hashData == existing.hashData {
                    return true
                }

                let hammingDistance = calculateHammingDistance(
                    fingerprint.hashData,
                    existing.hashData
                )
                let maxBits = max(fingerprint.hashSize, existing.hashSize)
                let similarity = maxBits > 0 ? 1.0 - (Float(hammingDistance) / Float(maxBits)) : 0.0

                if similarity >= threshold {
                    return true
                }
            }
        }

        return false
    }

    private func calculateHammingDistance(_ data1: Data, _ data2: Data) -> UInt32 {
        let bytes1 = [UInt8](data1)
        let bytes2 = [UInt8](data2)
        let length = min(bytes1.count, bytes2.count)

        var distance: UInt32 = 0
        for i in 0..<length {
            distance += UInt32((bytes1[i] ^ bytes2[i]).nonzeroBitCount)
        }

        distance += UInt32(abs(bytes1.count - bytes2.count) * 8)
        return distance
    }

    public func storeFingerprint(_ fingerprint: MediaFingerprint) async throws {
        try await database.insertMediaFingerprint(fingerprint)
    }

    public func storeFingerprints(_ fingerprints: [MediaFingerprint]) async throws {
        for fingerprint in fingerprints {
            try await storeFingerprint(fingerprint)
        }
    }

    public func deleteFingerprints(for sourceId: String) async throws {
        try await database.deleteMediaFingerprints(sourceId: sourceId)
    }

    public func getFingerprints(for sourceId: String) async throws -> [MediaFingerprint] {
        try await database.getMediaFingerprintsBySourceId(sourceId: sourceId)
    }

    public func checkForDuplicates(
        mediaData: Data,
        mediaType: MediaType,
        sourceId: String,
        threshold: Float = 0.85
    ) async throws -> DuplicateDetectionResult {
        let fingerprint = try await generateFingerprint(
            for: mediaData,
            mediaType: mediaType,
            sourceId: sourceId
        )

        let result = try await findDuplicates(for: fingerprint, threshold: threshold)

        return result
    }
}

extension ContextumDatabase {
    public struct MediaFingerprintRecord: Sendable {
        public let fingerprintId: String
        public let sourceId: String
        public let mediaType: String
        public let algorithm: String
        public let hashData: Data
        public let hashSize: Int
        public let confidence: Double
        public let durationMs: Int?
        public let width: Int?
        public let height: Int?
        public let fileSize: Int64
        public let format: String?
        public let createdAt: Int64

        public init(
            fingerprintId: String,
            sourceId: String,
            mediaType: String,
            algorithm: String,
            hashData: Data,
            hashSize: Int,
            confidence: Double,
            durationMs: Int?,
            width: Int?,
            height: Int?,
            fileSize: Int64,
            format: String?,
            createdAt: Int64
        ) {
            self.fingerprintId = fingerprintId
            self.sourceId = sourceId
            self.mediaType = mediaType
            self.algorithm = algorithm
            self.hashData = hashData
            self.hashSize = hashSize
            self.confidence = confidence
            self.durationMs = durationMs
            self.width = width
            self.height = height
            self.fileSize = fileSize
            self.format = format
            self.createdAt = createdAt
        }
    }

    public func migrateMediaFingerprints() async throws {
        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS media_fingerprints (
                fingerprint_id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                media_type TEXT NOT NULL,
                algorithm TEXT NOT NULL,
                hash_data BLOB NOT NULL,
                hash_size INTEGER NOT NULL,
                confidence REAL NOT NULL,
                duration_ms INTEGER,
                width INTEGER,
                height INTEGER,
                file_size INTEGER NOT NULL,
                format TEXT,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (source_id) REFERENCES contextum_sources(source_id)
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_media_fingerprints_source_id
            ON media_fingerprints(source_id);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_media_fingerprints_media_type
            ON media_fingerprints(media_type);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_media_fingerprints_created_at
            ON media_fingerprints(created_at);
            """)
    }

    public func insertMediaFingerprint(_ fingerprint: MediaDeduplicationSystem.MediaFingerprint) async throws {
        let sql = """
            INSERT INTO media_fingerprints (
                fingerprint_id, source_id, media_type, algorithm, hash_data, hash_size,
                confidence, duration_ms, width, height, file_size, format, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

        _ = try await dbActor.executeAsync(sql, parameters: [
            .text(fingerprint.fingerprintId),
            .text(fingerprint.sourceId),
            .text(fingerprint.mediaType.rawValue.description),
            .text(fingerprint.algorithm.rawValue.description),
            .blob(fingerprint.hashData),
            .int(Int(fingerprint.hashSize)),
            .double(fingerprint.confidence),
            fingerprint.durationMs.map { .int(Int($0)) } ?? .null,
            fingerprint.width.map { .int(Int($0)) } ?? .null,
            fingerprint.height.map { .int(Int($0)) } ?? .null,
            .int64(Int64(fingerprint.fileSize)),
            fingerprint.format.map { .text($0) } ?? .null,
            .int64(Int64(fingerprint.createdAt.timeIntervalSince1970))
        ])
    }

    public func getMediaFingerprints(
        mediaType: MediaFingerprintCapsule.MediaType,
        limit: Int = 100
    ) async throws -> [MediaDeduplicationSystem.MediaFingerprint] {
        let rows = try await dbActor.query(
            """
            SELECT * FROM media_fingerprints
            WHERE media_type = ?
            ORDER BY created_at DESC
            LIMIT ?;
            """,
            parameters: [
                .text(mediaType.rawValue.description),
                .int(limit)
            ]
        )

        return rows.compactMap { row -> MediaDeduplicationSystem.MediaFingerprint? in
            guard let fingerprintId = row.string(for: "fingerprint_id"),
                  let sourceId = row.string(for: "source_id"),
                  let hashData = row.data(for: "hash_data") else {
                return nil
            }

            guard let mediaTypeRaw = row.string(for: "media_type"),
                  let mediaType = MediaFingerprintCapsule.MediaType(rawValue: UInt8(mediaTypeRaw) ?? 0) else {
                return nil
            }

            guard let algorithmRaw = row.string(for: "algorithm"),
                  let algorithm = MediaFingerprintCapsule.FingerprintAlgorithm(rawValue: UInt8(algorithmRaw) ?? 0) else {
                return nil
            }

            return MediaDeduplicationSystem.MediaFingerprint(
                fingerprintId: fingerprintId,
                sourceId: sourceId,
                mediaType: mediaType,
                algorithm: algorithm,
                hashData: hashData,
                hashSize: UInt32(row.int(for: "hash_size") ?? 0),
                confidence: row.double(for: "confidence") ?? 0.0,
                durationMs: row.int(for: "duration_ms").map { UInt32($0) },
                width: row.int(for: "width").map { UInt32($0) },
                height: row.int(for: "height").map { UInt32($0) },
                fileSize: UInt64(row.int64(for: "file_size") ?? 0),
                format: row.string(for: "format"),
                createdAt: Date(timeIntervalSince1970: TimeInterval(row.int64(for: "created_at") ?? 0))
            )
        }
    }

    public func getMediaFingerprintsBySourceId(sourceId: String) async throws -> [MediaDeduplicationSystem.MediaFingerprint] {
        let rows = try await dbActor.query(
            "SELECT * FROM media_fingerprints WHERE source_id = ?;",
            parameters: [.text(sourceId)]
        )

        return rows.compactMap { row -> MediaDeduplicationSystem.MediaFingerprint? in
            guard let fingerprintId = row.string(for: "fingerprint_id"),
                  let hashData = row.data(for: "hash_data") else {
                return nil
            }

            guard let mediaTypeRaw = row.string(for: "media_type"),
                  let mediaType = MediaFingerprintCapsule.MediaType(rawValue: UInt8(mediaTypeRaw) ?? 0) else {
                return nil
            }

            guard let algorithmRaw = row.string(for: "algorithm"),
                  let algorithm = MediaFingerprintCapsule.FingerprintAlgorithm(rawValue: UInt8(algorithmRaw) ?? 0) else {
                return nil
            }

            return MediaDeduplicationSystem.MediaFingerprint(
                fingerprintId: fingerprintId,
                sourceId: sourceId,
                mediaType: mediaType,
                algorithm: algorithm,
                hashData: hashData,
                hashSize: UInt32(row.int(for: "hash_size") ?? 0),
                confidence: row.double(for: "confidence") ?? 0.0,
                durationMs: row.int(for: "duration_ms").map { UInt32($0) },
                width: row.int(for: "width").map { UInt32($0) },
                height: row.int(for: "height").map { UInt32($0) },
                fileSize: UInt64(row.int64(for: "file_size") ?? 0),
                format: row.string(for: "format"),
                createdAt: Date(timeIntervalSince1970: TimeInterval(row.int64(for: "created_at") ?? 0))
            )
        }
    }

    public func deleteMediaFingerprints(sourceId: String) async throws {
        _ = try await dbActor.executeAsync(
            "DELETE FROM media_fingerprints WHERE source_id = ?;",
            parameters: [.text(sourceId)]
        )
    }
}
