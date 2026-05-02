import Foundation
import AnigmaNativeShims
import MediaFingerprintNative

// MARK: - Media Types

public enum MediaType: UInt8, Sendable, Codable {
    case unknown = 0
    case image = 1
    case audio = 2
    case video = 3
}

// MARK: - Fingerprint Algorithms

public enum FingerprintAlgorithm: UInt8, Sendable, Codable {
    case averageHash = 0
    case differenceHash = 1
    case waveletHash = 2
    case perceptualHash = 3
    case chromaprint = 4
    case motionVector = 5
}

// MARK: - Media Metadata

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

// MARK: - Fingerprint Result

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

// MARK: - Similarity Configuration

public struct SimilarityConfiguration: Sendable {
    public let similarityThreshold: Double
    public let useHammingDistance: Bool
    public let enablePartialMatching: Bool
    public let partialMatchThreshold: Double
    
    public init(
        similarityThreshold: Double = 0.85,
        useHammingDistance: Bool = true,
        enablePartialMatching: Bool = true,
        partialMatchThreshold: Double = 0.65
    ) {
        self.similarityThreshold = similarityThreshold
        self.useHammingDistance = useHammingDistance
        self.enablePartialMatching = enablePartialMatching
        self.partialMatchThreshold = partialMatchThreshold
    }
    
    public static let `default` = SimilarityConfiguration()
}

// MARK: - Similarity Result

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

// MARK: - Image Fingerprint Configuration

public struct ImageFingerprintConfiguration: Sendable {
    public let hashSize: UInt32
    public let resizeWidth: UInt32
    public let resizeHeight: UInt32
    public let highFrequencyBoost: Bool
    public let determinismTier: UInt32
    
    public init(
        hashSize: UInt32 = 64,
        resizeWidth: UInt32 = 64,
        resizeHeight: UInt32 = 64,
        highFrequencyBoost: Bool = false,
        determinismTier: UInt32 = 1
    ) {
        self.hashSize = hashSize
        self.resizeWidth = resizeWidth
        self.resizeHeight = resizeHeight
        self.highFrequencyBoost = highFrequencyBoost
        self.determinismTier = determinismTier
    }
    
    public static let `default` = ImageFingerprintConfiguration()
    
    internal func toCStruct() -> anigma_image_fingerprint_config_t {
        anigma_image_fingerprint_config_t(
            hash_size: hashSize,
            resize_width: resizeWidth,
            resize_height: resizeHeight,
            high_frequency_boost: highFrequencyBoost,
            determinism_tier: determinismTier
        )
    }
    
    internal init(from cConfig: anigma_image_fingerprint_config_t) {
        self.hashSize = cConfig.hash_size
        self.resizeWidth = cConfig.resize_width
        self.resizeHeight = cConfig.resize_height
        self.highFrequencyBoost = cConfig.high_frequency_boost
        self.determinismTier = cConfig.determinism_tier
    }
}

// MARK: - Audio Fingerprint Configuration

public struct AudioFingerprintConfiguration: Sendable {
    public let sampleRate: UInt32
    public let windowSize: UInt32
    public let hopSize: UInt32
    public let numCoefficients: UInt32
    public let fingerprintSize: UInt32
    public let determinismTier: UInt32
    
    public init(
        sampleRate: UInt32 = 44100,
        windowSize: UInt32 = 1024,
        hopSize: UInt32 = 512,
        numCoefficients: UInt32 = 13,
        fingerprintSize: UInt32 = 32,
        determinismTier: UInt32 = 1
    ) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.hopSize = hopSize
        self.numCoefficients = numCoefficients
        self.fingerprintSize = fingerprintSize
        self.determinismTier = determinismTier
    }
    
    public static let `default` = AudioFingerprintConfiguration()
    
    internal func toCStruct() -> anigma_audio_fingerprint_config_t {
        anigma_audio_fingerprint_config_t(
            sample_rate: sampleRate,
            window_size: windowSize,
            prototype_id: 0,
            hop_size: hopSize,
            num_coefficients: numCoefficients,
            fingerprint_size: fingerprintSize,
            determinism_tier: determinismTier
        )
    }
    
    internal init(from cConfig: anigma_audio_fingerprint_config_t) {
        self.sampleRate = cConfig.sample_rate
        self.windowSize = cConfig.window_size
        self.hopSize = cConfig.hop_size
        self.numCoefficients = cConfig.num_coefficients
        self.fingerprintSize = cConfig.fingerprint_size
        self.determinismTier = cConfig.determinism_tier
    }
}

// MARK: - Video Fingerprint Configuration

public struct VideoFingerprintConfiguration: Sendable {
    public let frameSampleRate: UInt32
    public let keyframeInterval: UInt32
    public let motionThreshold: UInt32
    public let fingerprintSize: UInt32
    public let determinismTier: UInt32
    
    public init(
        frameSampleRate: UInt32 = 30,
        keyframeInterval: UInt32 = 30,
        motionThreshold: UInt32 = 10,
        fingerprintSize: UInt32 = 128,
        determinismTier: UInt32 = 1
    ) {
        self.frameSampleRate = frameSampleRate
        self.keyframeInterval = keyframeInterval
        self.motionThreshold = motionThreshold
        self.fingerprintSize = fingerprintSize
        self.determinismTier = determinismTier
    }
    
    public static let `default` = VideoFingerprintConfiguration()
    
    internal func toCStruct() -> anigma_video_fingerprint_config_t {
        anigma_video_fingerprint_config_t(
            frame_sample_rate: frameSampleRate,
            keyframe_interval: keyframeInterval,
            motion_threshold: motionThreshold,
            fingerprint_size: fingerprintSize,
            determinism_tier: determinismTier
        )
    }
    
    internal init(from cConfig: anigma_video_fingerprint_config_t) {
        self.frameSampleRate = cConfig.frame_sample_rate
        self.keyframeInterval = cConfig.keyframe_interval
        self.motionThreshold = cConfig.motion_threshold
        self.fingerprintSize = cConfig.fingerprint_size
        self.determinismTier = cConfig.determinism_tier
    }
}

// MARK: - Similarity Configuration Extension

extension SimilarityConfiguration {
    internal func toCStruct() -> anigma_similarity_config_t {
        anigma_similarity_config_t(
            similarity_threshold: similarityThreshold,
            use_hamming_distance: useHammingDistance,
            enable_partial_matching: enablePartialMatching,
            partial_match_threshold: partialMatchThreshold
        )
    }
    
    internal init(from cConfig: anigma_similarity_config_t) {
        self.similarityThreshold = cConfig.similarity_threshold
        self.useHammingDistance = cConfig.use_hamming_distance
        self.enablePartialMatching = cConfig.enable_partial_matching
        self.partialMatchThreshold = cConfig.partial_match_threshold
    }
}