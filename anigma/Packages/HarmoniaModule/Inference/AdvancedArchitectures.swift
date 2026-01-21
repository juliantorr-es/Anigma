//
//  AdvancedArchitectures.swift
//  HarmoniaModule
//
//  Advanced architecture profiles for next-gen transformers:
//  - GQA (Grouped Query Attention)
//  - MLA (Multi-head Latent Attention)
//  - Differential Attention
//  - Diffusion LM backends
//
//  This enables the Inference Plane to exploit architecture-specific
//  optimizations for latency, memory, and quantization stability.
//

import Foundation
import AnigmaCore

// MARK: - Attention Architecture Types

/// Types of attention mechanisms supported.
public enum AttentionArchitecture: String, Sendable, Codable, CaseIterable {
    /// Standard multi-head attention (quadratic KV cache).
    case standard

    /// Grouped Query Attention (shared KV across query groups).
    case gqa

    /// Multi-head Latent Attention (compressed/constant KV).
    case mla

    /// Differential Attention (noise-canceling dual attention).
    case differential

    /// Mixture of Experts with attention routing.
    case moe

    /// Linear/efficient attention variants.
    case linear

    /// Unknown/unspecified architecture.
    case unknown
}

/// Generation mode for inference.
public enum GenerationMode: String, Sendable, Codable {
    /// Standard left-to-right autoregressive.
    case autoregressive

    /// Diffusion-based iterative denoising.
    case diffusion

    /// Semi-autoregressive (block-wise diffusion).
    case semiAutoregressive

    /// Masked parallel generation.
    case maskedParallel

    /// Speculative decoding with draft model.
    case speculative
}

/// KV cache behavior profile.
public struct KVCacheProfile: Sendable, Codable {
    /// Bytes per token for KV cache.
    public let bytesPerToken: Int

    /// Whether KV is compressed (MLA-style).
    public let isCompressed: Bool

    /// Compression ratio if applicable.
    public let compressionRatio: Double?

    /// Maximum efficient context before degradation.
    public let efficientContextLimit: Int

    /// Whether cache can be shared across requests.
    public let supportsKVSharing: Bool

    /// Whether cache is suitable for network transfer.
    public let networkTransferFriendly: Bool

    public init(
        bytesPerToken: Int,
        isCompressed: Bool = false,
        compressionRatio: Double? = nil,
        efficientContextLimit: Int,
        supportsKVSharing: Bool = false,
        networkTransferFriendly: Bool = false
    ) {
        self.bytesPerToken = bytesPerToken
        self.isCompressed = isCompressed
        self.compressionRatio = compressionRatio
        self.efficientContextLimit = efficientContextLimit
        self.supportsKVSharing = supportsKVSharing
        self.networkTransferFriendly = networkTransferFriendly
    }

    // MARK: - Standard Profiles

    /// Standard attention KV profile (quadratic growth).
    public static let standard = KVCacheProfile(
        bytesPerToken: 256,  // Typical for 7B model
        efficientContextLimit: 8192
    )

    /// GQA profile (reduced KV heads).
    public static let gqa = KVCacheProfile(
        bytesPerToken: 64,   // 4x reduction typical
        efficientContextLimit: 32768,
        supportsKVSharing: true
    )

    /// MLA profile (heavily compressed).
    public static let mla = KVCacheProfile(
        bytesPerToken: 16,
        isCompressed: true,
        compressionRatio: 16.0,
        efficientContextLimit: 128000,
        supportsKVSharing: true,
        networkTransferFriendly: true
    )
}

/// Quantization stability profile.
public struct QuantizationProfile: Sendable, Codable {
    /// Tested bit widths with stability scores (0-1).
    public let stabilityByBitWidth: [Int: Double]

    /// Whether architecture uses techniques to reduce activation outliers.
    public let hasOutlierMitigation: Bool

    /// Recommended minimum bit width for production use.
    public let recommendedMinBits: Int

    /// Whether the model tolerates aggressive quantization well.
    public let quantizationFriendly: Bool

    public init(
        stabilityByBitWidth: [Int: Double],
        hasOutlierMitigation: Bool = false,
        recommendedMinBits: Int = 4,
        quantizationFriendly: Bool = true
    ) {
        self.stabilityByBitWidth = stabilityByBitWidth
        self.hasOutlierMitigation = hasOutlierMitigation
        self.recommendedMinBits = recommendedMinBits
        self.quantizationFriendly = quantizationFriendly
    }

    // MARK: - Standard Profiles

    /// Standard transformer quantization profile.
    public static let standard = QuantizationProfile(
        stabilityByBitWidth: [16: 1.0, 8: 0.95, 4: 0.85, 2: 0.5],
        recommendedMinBits: 4
    )

    /// Differential attention (better stability).
    public static let differential = QuantizationProfile(
        stabilityByBitWidth: [16: 1.0, 8: 0.98, 4: 0.92, 2: 0.7],
        hasOutlierMitigation: true,
        recommendedMinBits: 4,
        quantizationFriendly: true
    )
}

/// Long context behavior profile.
public struct LongContextProfile: Sendable, Codable {
    /// Context length at which quality starts degrading.
    public let degradationThreshold: Int

    /// Quality retention at maximum context (0-1).
    public let maxContextQualityRetention: Double

    /// Whether model uses positional interpolation/extrapolation.
    public let supportsContextExtension: Bool

    /// Needle-in-haystack retrieval score at long context.
    public let longContextRetrievalScore: Double

    /// Whether attention is sparse/efficient at long context.
    public let hasSparseAttention: Bool

    public init(
        degradationThreshold: Int,
        maxContextQualityRetention: Double,
        supportsContextExtension: Bool = false,
        longContextRetrievalScore: Double = 0.8,
        hasSparseAttention: Bool = false
    ) {
        self.degradationThreshold = degradationThreshold
        self.maxContextQualityRetention = maxContextQualityRetention
        self.supportsContextExtension = supportsContextExtension
        self.longContextRetrievalScore = longContextRetrievalScore
        self.hasSparseAttention = hasSparseAttention
    }
}

// MARK: - Architecture Profile

/// Complete architecture profile for a model.
public struct ArchitectureProfile: Sendable, Codable {
    /// Attention mechanism type.
    public let attentionType: AttentionArchitecture

    /// Generation mode.
    public let generationMode: GenerationMode

    /// KV cache characteristics.
    public let kvCache: KVCacheProfile

    /// Quantization behavior.
    public let quantization: QuantizationProfile

    /// Long context handling.
    public let longContext: LongContextProfile

    /// Specific architectural features.
    public let features: Set<ArchitectureFeature>

    /// Model-specific notes.
    public let notes: String?

    public init(
        attentionType: AttentionArchitecture,
        generationMode: GenerationMode = .autoregressive,
        kvCache: KVCacheProfile,
        quantization: QuantizationProfile,
        longContext: LongContextProfile,
        features: Set<ArchitectureFeature> = [],
        notes: String? = nil
    ) {
        self.attentionType = attentionType
        self.generationMode = generationMode
        self.kvCache = kvCache
        self.quantization = quantization
        self.longContext = longContext
        self.features = features
        self.notes = notes
    }

    // MARK: - Derived Properties

    /// Whether this architecture is suitable for long-running contexts.
    public var isLongContextFriendly: Bool {
        kvCache.isCompressed || attentionType == .mla || attentionType == .gqa
    }

    /// Whether this architecture is suitable for resource-constrained devices.
    public var isResourceFriendly: Bool {
        quantization.quantizationFriendly && kvCache.bytesPerToken <= 64
    }

    /// Whether this architecture produces fast structured output.
    public var isFastStructuredOutput: Bool {
        generationMode == .diffusion || generationMode == .maskedParallel
    }

    /// Suitability score for distributed inference (0-1).
    public var distributedInferenceSuitability: Double {
        var score = 0.5
        if kvCache.networkTransferFriendly { score += 0.2 }
        if kvCache.supportsKVSharing { score += 0.15 }
        if kvCache.isCompressed { score += 0.15 }
        return min(score, 1.0)
    }
}

/// Specific architectural features.
public enum ArchitectureFeature: String, Sendable, Codable, CaseIterable {
    case flashAttention
    case slidingWindow
    case rotaryEmbeddings
    case alibi
    case mixtureOfExperts
    case specDecodingSupport
    case prefixCaching
    case continuousBatching
    case tensorParallelism
    case pipelineParallelism
    case quantizationAware
    case earlyFusion
    case crossAttention
    case bidirectional
}

// MARK: - Diffusion LM Profiles

/// Profile specific to diffusion language models.
public struct DiffusionLMProfile: Sendable, Codable {
    /// Number of denoising steps.
    public let denoisingSteps: Int

    /// Whether supports variable step counts.
    public let variableSteps: Bool

    /// Minimum steps for acceptable quality.
    public let minQualitySteps: Int

    /// Expected tokens per second on reference hardware.
    public let expectedThroughput: Double

    /// Domains where diffusion excels.
    public let strongDomains: Set<DiffusionDomain>

    /// Whether supports fill-in-the-middle natively.
    public let supportsFIM: Bool

    /// Whether can produce streaming-like output.
    public let supportsProgressiveReveal: Bool

    public init(
        denoisingSteps: Int = 16,
        variableSteps: Bool = true,
        minQualitySteps: Int = 8,
        expectedThroughput: Double = 500,
        strongDomains: Set<DiffusionDomain> = [],
        supportsFIM: Bool = false,
        supportsProgressiveReveal: Bool = true
    ) {
        self.denoisingSteps = denoisingSteps
        self.variableSteps = variableSteps
        self.minQualitySteps = minQualitySteps
        self.expectedThroughput = expectedThroughput
        self.strongDomains = strongDomains
        self.supportsFIM = supportsFIM
        self.supportsProgressiveReveal = supportsProgressiveReveal
    }
}

/// Domains where diffusion LMs excel.
public enum DiffusionDomain: String, Sendable, Codable, CaseIterable {
    case code
    case json
    case structured
    case tables
    case infilling
    case multimodal
    case layout
    case formatting
}

// MARK: - Architecture Registry

/// Registry of known architecture profiles.
public actor ArchitectureRegistry {
    /// Known architecture profiles by model family.
    private var profiles: [String: ArchitectureProfile] = [:]

    /// Diffusion-specific profiles.
    private var diffusionProfiles: [String: DiffusionLMProfile] = [:]

    public init() {
        // Initialize with empty profiles
    }

    /// Gets architecture profile for a model.
    public func getProfile(for modelFamily: String) -> ArchitectureProfile? {
        return profiles[modelFamily.lowercased()]
    }

    /// Gets diffusion profile if applicable.
    public func getDiffusionProfile(for modelFamily: String) -> DiffusionLMProfile? {
        diffusionProfiles[modelFamily.lowercased()]
    }

    /// Registers a custom architecture profile.
    public func register(_ profile: ArchitectureProfile, for family: String) {
        profiles[family.lowercased()] = profile
    }

    /// Registers known architectures.
    private func registerKnownArchitectures() {
        // This will be implemented when needed
        // For now, just initialize with empty profiles
    }

    /// Gets all registered families.
    public func registeredFamilies() -> [String] {
        Array(profiles.keys)
    }
}

// MARK: - Architecture-Aware Scheduling

/// Scheduler hints based on architecture.
public struct ArchitectureSchedulingHints: Sendable {
    /// Preferred for long context tasks.
    public let longContextPreferred: Bool

    /// Preferred for fast structured output.
    public let fastStructuredPreferred: Bool

    /// Preferred for resource-constrained nodes.
    public let resourceConstrainedPreferred: Bool

    /// Preferred for distributed inference.
    public let distributedPreferred: Bool

    /// Minimum viable context for this task.
    public let requiredContext: Int

    /// Whether diffusion backend is acceptable.
    public let diffusionAcceptable: Bool

    public init(
        longContextPreferred: Bool = false,
        fastStructuredPreferred: Bool = false,
        resourceConstrainedPreferred: Bool = false,
        distributedPreferred: Bool = false,
        requiredContext: Int = 4096,
        diffusionAcceptable: Bool = false
    ) {
        self.longContextPreferred = longContextPreferred
        self.fastStructuredPreferred = fastStructuredPreferred
        self.resourceConstrainedPreferred = resourceConstrainedPreferred
        self.distributedPreferred = distributedPreferred
        self.requiredContext = requiredContext
        self.diffusionAcceptable = diffusionAcceptable
    }

    /// Derives hints from task characteristics.
    public static func from(task: InferenceTask) -> ArchitectureSchedulingHints {
        var longContext = false
        var fastStructured = false
        var requiredContext = 4096
        var diffusionOK = false

        // Analyze input for context needs
        switch task.input {
        case .text(let text):
            let estimatedTokens = text.count / 4
            longContext = estimatedTokens > 16000
            requiredContext = estimatedTokens + 2000
        case .messages(let messages):
            let totalContent = messages.map { $0.content.count }.reduce(0, +)
            let estimatedTokens = totalContent / 4
            longContext = estimatedTokens > 16000
            requiredContext = estimatedTokens + 2000
        case .batch(let texts):
            requiredContext = (texts.map { $0.count }.max() ?? 0) / 4 + 2000
        case .structured:
            requiredContext = 4096
        }

        // Determine if diffusion is suitable
        switch task.kind {
        case .codeGeneration, .extraction:
            fastStructured = true
            diffusionOK = true
        case .summarize:
            fastStructured = true
        default:
            break
        }

        return ArchitectureSchedulingHints(
            longContextPreferred: longContext,
            fastStructuredPreferred: fastStructured,
            requiredContext: requiredContext,
            diffusionAcceptable: diffusionOK
        )
    }
}

// MARK: - Architecture-Based Model Scoring

extension ModelDescriptor {
    /// Scores a model for a task based on architecture characteristics.
    public func architectureScore(
        for hints: ArchitectureSchedulingHints,
        profile: ArchitectureProfile?
    ) -> Double {
        guard let profile = profile else { return 0.5 }

        var score = 0.5

        // Long context preference
        if hints.longContextPreferred {
            if profile.isLongContextFriendly { score += 0.2 }
            if profile.longContext.degradationThreshold > hints.requiredContext {
                score += 0.1
            }
        }

        // Fast structured output
        if hints.fastStructuredPreferred && profile.isFastStructuredOutput {
            score += 0.25
        }

        // Resource constraints
        if hints.resourceConstrainedPreferred && profile.isResourceFriendly {
            score += 0.15
        }

        // Distributed suitability
        if hints.distributedPreferred {
            score += profile.distributedInferenceSuitability * 0.2
        }

        // Diffusion preference
        if hints.diffusionAcceptable && profile.generationMode == .diffusion {
            score += 0.2
        }

        return min(score, 1.0)
    }
}
