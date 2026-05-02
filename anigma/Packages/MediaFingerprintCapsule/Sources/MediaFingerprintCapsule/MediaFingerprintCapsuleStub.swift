import Foundation
import CryptoKit

public enum MediaType: UInt8, Sendable, Codable {
    case unknown = 0
    case image = 1
    case audio = 2
    case video = 3
}

public enum FingerprintAlgorithm: UInt8, Sendable, Codable {
    case averageHash = 0
    case differenceHash = 1
    case waveletHash = 2
    case perceptualHash = 3
    case chromaprint = 4
    case motionVector = 5
}

public struct MediaMetadata: Sendable {
    public let mediaType: MediaType
    public let fileSize: UInt64
    public let width: UInt32
    public let height: UInt32
    public let durationMs: UInt32
    public let bitRate: UInt32
    public let sampleRate: UInt32
    public let format: String
    public let codec: String

    public init(
        mediaType: MediaType,
        fileSize: UInt64,
        width: UInt32 = 0,
        height: UInt32 = 0,
        durationMs: UInt32 = 0,
        bitRate: UInt32 = 0,
        sampleRate: UInt32 = 0,
        format: String,
        codec: String
    ) {
        self.mediaType = mediaType
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.durationMs = durationMs
        self.bitRate = bitRate
        self.sampleRate = sampleRate
        self.format = format
        self.codec = codec
    }
}

public struct FingerprintResult: Sendable {
    public let algorithm: FingerprintAlgorithm
    public let hashSize: UInt32
    public let hashData: Data
    public let confidence: Double
    public let processingTimeMs: UInt64

    public init(
        algorithm: FingerprintAlgorithm,
        hashSize: UInt32,
        hashData: Data,
        confidence: Double,
        processingTimeMs: UInt64
    ) {
        self.algorithm = algorithm
        self.hashSize = hashSize
        self.hashData = hashData
        self.confidence = confidence
        self.processingTimeMs = processingTimeMs
    }
}

public struct ImageFingerprintConfiguration: Sendable {
    public let hashSize: UInt32
    public init(hashSize: UInt32 = 64) {
        self.hashSize = hashSize
    }

    public static let `default` = ImageFingerprintConfiguration()
    public func validate() throws {}
}

public struct AudioFingerprintConfiguration: Sendable {
    public let fingerprintSize: UInt32
    public init(fingerprintSize: UInt32 = 32) {
        self.fingerprintSize = fingerprintSize
    }

    public static let `default` = AudioFingerprintConfiguration()
    public func validate() throws {}
}

public struct VideoFingerprintConfiguration: Sendable {
    public let fingerprintSize: UInt32
    public init(fingerprintSize: UInt32 = 64) {
        self.fingerprintSize = fingerprintSize
    }

    public static let `default` = VideoFingerprintConfiguration()
    public func validate() throws {}
}

public struct SimilarityResult: Sendable {
    public let similarityScore: Double
    public let hammingDistance: UInt32
    public let isDuplicate: Bool
    public let isPartialMatch: Bool

    public init(
        similarityScore: Double,
        hammingDistance: UInt32,
        isDuplicate: Bool,
        isPartialMatch: Bool
    ) {
        self.similarityScore = similarityScore
        self.hammingDistance = hammingDistance
        self.isDuplicate = isDuplicate
        self.isPartialMatch = isPartialMatch
    }
}

public enum MediaFingerprintError: Error, Sendable {
    case invalidInput
}

public final class MediaFingerprintCapsuleWrapper: @unchecked Sendable {
    private let imageConfig: ImageFingerprintConfiguration
    private let audioConfig: AudioFingerprintConfiguration
    private let videoConfig: VideoFingerprintConfiguration

    public var imageConfiguration: ImageFingerprintConfiguration { imageConfig }
    public var audioConfiguration: AudioFingerprintConfiguration { audioConfig }
    public var videoConfiguration: VideoFingerprintConfiguration { videoConfig }

    public init(
        imageConfig: ImageFingerprintConfiguration? = nil,
        audioConfig: AudioFingerprintConfiguration? = nil,
        videoConfig: VideoFingerprintConfiguration? = nil,
        diagnostics: Any? = nil
    ) throws {
        _ = diagnostics
        self.imageConfig = imageConfig ?? .default
        self.audioConfig = audioConfig ?? .default
        self.videoConfig = videoConfig ?? .default
    }

    public func reset() throws {}

    public static func detectMediaType(
        _ data: Data,
        diagnostics: Any? = nil
    ) throws -> MediaType {
        _ = diagnostics
        guard !data.isEmpty else { return .unknown }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) || data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .image
        }
        if data.starts(with: [0x49, 0x44, 0x33]) || data.starts(with: [0xFF, 0xFB]) {
            return .audio
        }
        return .video
    }

    public func analyzeMedia(_ data: Data, mediaType: MediaType = .unknown) throws -> MediaMetadata {
        let resolvedType = mediaType == .unknown ? (try Self.detectMediaType(data)) : mediaType

        return MediaMetadata(
            mediaType: resolvedType,
            fileSize: UInt64(data.count),
            width: 0,
            height: 0,
            durationMs: 0,
            bitRate: 0,
            sampleRate: 0,
            format: "stub",
            codec: "stub"
        )
    }

    public func generateImageFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .perceptualHash
    ) throws -> FingerprintResult {
        try makeFingerprint(data: data, algorithm: algorithm, hashBits: imageConfig.hashSize)
    }

    public func generateAudioFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .chromaprint
    ) throws -> FingerprintResult {
        try makeFingerprint(data: data, algorithm: algorithm, hashBits: audioConfig.fingerprintSize)
    }

    public func generateVideoFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .motionVector
    ) throws -> FingerprintResult {
        try makeFingerprint(data: data, algorithm: algorithm, hashBits: videoConfig.fingerprintSize)
    }

    public func compareFingerprints(
        _ lhs: FingerprintResult,
        _ rhs: FingerprintResult,
        threshold: Double = 0.85
    ) -> SimilarityResult {
        let distance = hammingDistance(lhs.hashData, rhs.hashData)
        let bits = max(lhs.hashData.count, rhs.hashData.count) * 8
        let similarity = bits > 0 ? 1.0 - (Double(distance) / Double(bits)) : 0.0

        return SimilarityResult(
            similarityScore: max(0.0, min(1.0, similarity)),
            hammingDistance: UInt32(distance),
            isDuplicate: similarity >= threshold,
            isPartialMatch: similarity >= 0.65
        )
    }

    public func batchCompareFingerprints(
        query: FingerprintResult,
        candidates: [FingerprintResult],
        threshold: Double = 0.85
    ) -> [SimilarityResult] {
        candidates.map { compareFingerprints(query, $0, threshold: threshold) }
    }

    private func makeFingerprint(
        data: Data,
        algorithm: FingerprintAlgorithm,
        hashBits: UInt32
    ) throws -> FingerprintResult {
        guard !data.isEmpty else {
            throw MediaFingerprintError.invalidInput
        }

        let start = Date()
        let digest = Data(SHA256.hash(data: data))
        let byteCount = Int(max(8, hashBits / 8))
        let hashData = Data(digest.prefix(byteCount))
        let elapsedMs = UInt64(Date().timeIntervalSince(start) * 1000)

        return FingerprintResult(
            algorithm: algorithm,
            hashSize: UInt32(hashData.count * 8),
            hashData: hashData,
            confidence: 0.7,
            processingTimeMs: elapsedMs
        )
    }

    private func hammingDistance(_ lhs: Data, _ rhs: Data) -> Int {
        let maxCount = max(lhs.count, rhs.count)
        var distance = 0

        for index in 0..<maxCount {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            distance += Int((a ^ b).nonzeroBitCount)
        }

        return distance
    }
}
