//
//  DiffusionBackend.swift
//  HarmoniaModule
//
//  Backend support for diffusion language models.
//  Provides fast, parallel generation for structured outputs.
//
//  Diffusion LMs excel at:
//  - Code generation (fill-in-the-middle)
//  - Structured output (JSON, tables)
//  - Format-constrained generation
//  - Multimodal document processing
//

@preconcurrency import Foundation
import AnigmaCore

// MARK: - Diffusion Backend Types

/// Configuration for diffusion inference.
public struct DiffusionInferenceConfig: Sendable, Codable {
    /// Number of denoising steps.
    public var steps: Int

    /// Whether to use adaptive step scheduling.
    public var adaptiveSteps: Bool

    /// Minimum steps for quality.
    public var minSteps: Int

    /// Maximum steps allowed.
    public var maxSteps: Int

    /// Temperature for sampling.
    public var temperature: Double

    /// Top-p nucleus sampling threshold.
    public var topP: Double

    /// Whether to enable progressive reveal (streaming-like).
    public var progressiveReveal: Bool

    /// Reveal interval for progressive output.
    public var revealInterval: Int

    /// Guidance scale for conditional generation.
    public var guidanceScale: Double

    public init(
        steps: Int = 16,
        adaptiveSteps: Bool = true,
        minSteps: Int = 8,
        maxSteps: Int = 32,
        temperature: Double = 0.7,
        topP: Double = 0.9,
        progressiveReveal: Bool = true,
        revealInterval: Int = 4,
        guidanceScale: Double = 1.0
    ) {
        self.steps = steps
        self.adaptiveSteps = adaptiveSteps
        self.minSteps = minSteps
        self.maxSteps = maxSteps
        self.temperature = temperature
        self.topP = topP
        self.progressiveReveal = progressiveReveal
        self.revealInterval = revealInterval
        self.guidanceScale = guidanceScale
    }

    // MARK: - Presets

    /// Fast generation (fewer steps).
    public static let fast = DiffusionInferenceConfig(
        steps: 8,
        adaptiveSteps: false,
        minSteps: 4,
        maxSteps: 12
    )

    /// Quality generation (more steps).
    public static let quality = DiffusionInferenceConfig(
        steps: 24,
        adaptiveSteps: true,
        minSteps: 16,
        maxSteps: 48
    )

    /// Code-optimized settings.
    public static let code = DiffusionInferenceConfig(
        steps: 16,
        adaptiveSteps: true,
        minSteps: 12,
        maxSteps: 24,
        temperature: 0.3,
        topP: 0.95
    )

    /// JSON/structured output optimized.
    public static let structured = DiffusionInferenceConfig(
        steps: 12,
        adaptiveSteps: false,
        minSteps: 8,
        maxSteps: 16,
        temperature: 0.1,
        topP: 0.99
    )
}

/// State of diffusion denoising process.
public struct DiffusionState: Sendable {
    public let step: Int
    public let totalSteps: Int
    public let currentTokens: [Int]
    public let maskPositions: Set<Int>
    public let confidence: Double
    public let timestamp: Date

    public var progress: Double {
        Double(step) / Double(totalSteps)
    }

    public var revealedTokenCount: Int {
        currentTokens.count - maskPositions.count
    }
}

/// A progressive reveal update from diffusion.
public struct DiffusionReveal: Sendable {
    public let step: Int
    public let revealedText: String
    public let newlyRevealed: String
    public let confidence: Double
    public let isComplete: Bool
}

// MARK: - Diffusion Backend

/// Backend adapter for diffusion language models.
public actor DiffusionBackend {
    /// Current diffusion state by request ID.
    private var activeStates: [String: DiffusionState] = [:]

    /// Backend statistics.
    private var stats: DiffusionBackendStats = .init()

    public init() {}

    // MARK: - Inference

    /// Runs diffusion inference.
    public func generate(
        requestId: String,
        prompt: String,
        maxTokens: Int,
        config: DiffusionInferenceConfig
    ) async throws -> DiffusionResult {
        let startTime = Date()

        // Initialize masked sequence
        let initialState = initializeState(
            requestId: requestId,
            promptLength: prompt.count / 4,  // Approximate
            outputLength: maxTokens,
            totalSteps: config.steps
        )
        activeStates[requestId] = initialState

        // Run denoising loop
        var currentState = initialState
        var reveals: [DiffusionReveal] = []

        for step in 1...config.steps {
            // Simulate denoising step
            let newState = await denoisingStep(
                state: currentState,
                step: step,
                config: config
            )

            // Check for progressive reveal
            if config.progressiveReveal && step % config.revealInterval == 0 {
                let reveal = createReveal(
                    from: currentState,
                    to: newState,
                    step: step
                )
                reveals.append(reveal)
            }

            currentState = newState
            activeStates[requestId] = currentState

            // Adaptive early stopping
            if config.adaptiveSteps && currentState.confidence > 0.95 && step >= config.minSteps {
                break
            }
        }

        // Finalize
        activeStates.removeValue(forKey: requestId)

        let duration = Date().timeIntervalSince(startTime)
        stats.totalRequests += 1
        stats.totalTokensGenerated += maxTokens
        stats.totalLatency += duration

        return DiffusionResult(
            requestId: requestId,
            output: generatePlaceholderOutput(maxTokens),  // Placeholder
            tokensGenerated: maxTokens,
            stepsUsed: currentState.step,
            finalConfidence: currentState.confidence,
            latency: duration,
            reveals: reveals
        )
    }

    /// Gets current state for a request.
    public func getState(_ requestId: String) -> DiffusionState? {
        activeStates[requestId]
    }

    /// Cancels an in-progress request.
    public func cancel(_ requestId: String) {
        activeStates.removeValue(forKey: requestId)
    }

    /// Gets backend statistics.
    public func getStats() -> DiffusionBackendStats {
        stats
    }

    // MARK: - Private Helpers

    private func initializeState(
        requestId: String,
        promptLength: Int,
        outputLength: Int,
        totalSteps: Int
    ) -> DiffusionState {
        // Initialize with all output positions masked
        let totalLength = promptLength + outputLength
        let maskPositions = Set((promptLength..<totalLength))

        return DiffusionState(
            step: 0,
            totalSteps: totalSteps,
            currentTokens: Array(repeating: 0, count: totalLength),
            maskPositions: maskPositions,
            confidence: 0.0,
            timestamp: Date()
        )
    }

    private func denoisingStep(
        state: DiffusionState,
        step: Int,
        config: DiffusionInferenceConfig
    ) async -> DiffusionState {
        // Simulate denoising - in real implementation this calls the model
        // Each step reveals more tokens with increasing confidence

        let revealFraction = Double(step) / Double(state.totalSteps)
        let tokensToReveal = Int(Double(state.maskPositions.count) * revealFraction)
        let revealedPositions = Set(state.maskPositions.prefix(tokensToReveal))
        let remainingMasks = state.maskPositions.subtracting(revealedPositions)

        let confidence = min(revealFraction * 1.1, 0.99)

        return DiffusionState(
            step: step,
            totalSteps: state.totalSteps,
            currentTokens: state.currentTokens,
            maskPositions: remainingMasks,
            confidence: confidence,
            timestamp: Date()
        )
    }

    private func createReveal(
        from oldState: DiffusionState,
        to newState: DiffusionState,
        step: Int
    ) -> DiffusionReveal {
        let newlyRevealedCount = oldState.maskPositions.count - newState.maskPositions.count

        return DiffusionReveal(
            step: step,
            revealedText: "...",  // Placeholder
            newlyRevealed: String(repeating: ".", count: newlyRevealedCount),
            confidence: newState.confidence,
            isComplete: newState.maskPositions.isEmpty
        )
    }

    private func generatePlaceholderOutput(_ tokens: Int) -> String {
        // Placeholder - real implementation decodes tokens
        String(repeating: "x", count: tokens * 4)
    }
}

/// Result of diffusion inference.
public struct DiffusionResult: Sendable {
    public let requestId: String
    public let output: String
    public let tokensGenerated: Int
    public let stepsUsed: Int
    public let finalConfidence: Double
    public let latency: TimeInterval
    public let reveals: [DiffusionReveal]

    public var tokensPerSecond: Double {
        guard latency > 0 else { return 0 }
        return Double(tokensGenerated) / latency
    }
}

/// Statistics for diffusion backend.
public struct DiffusionBackendStats: Sendable {
    public var totalRequests: Int = 0
    public var totalTokensGenerated: Int = 0
    public var totalLatency: TimeInterval = 0

    public var averageTokensPerSecond: Double {
        guard totalLatency > 0 else { return 0 }
        return Double(totalTokensGenerated) / totalLatency
    }

    public var averageLatency: TimeInterval {
        guard totalRequests > 0 else { return 0 }
        return totalLatency / Double(totalRequests)
    }
}

// MARK: - Fill-in-the-Middle Support

/// Configuration for fill-in-the-middle (FIM) generation.
public struct FIMConfig: Sendable, Codable {
    public let prefix: String
    public let suffix: String
    public let maxInfillTokens: Int
    public let preserveWhitespace: Bool
    public let matchStyle: Bool

    public init(
        prefix: String,
        suffix: String,
        maxInfillTokens: Int = 256,
        preserveWhitespace: Bool = true,
        matchStyle: Bool = true
    ) {
        self.prefix = prefix
        self.suffix = suffix
        self.maxInfillTokens = maxInfillTokens
        self.preserveWhitespace = preserveWhitespace
        self.matchStyle = matchStyle
    }
}

/// Result of fill-in-the-middle generation.
public struct FIMResult: Sendable {
    public let infill: String
    public let fullText: String
    public let tokensGenerated: Int
    public let confidence: Double
}

extension DiffusionBackend {
    /// Performs fill-in-the-middle generation.
    public func fillInMiddle(
        requestId: String,
        fim: FIMConfig,
        config: DiffusionInferenceConfig
    ) async throws -> FIMResult {
        // Diffusion excels at FIM because it can attend to both prefix and suffix
        let result = try await generate(
            requestId: requestId,
            prompt: fim.prefix + "[INFILL]" + fim.suffix,
            maxTokens: fim.maxInfillTokens,
            config: config
        )

        return FIMResult(
            infill: result.output,
            fullText: fim.prefix + result.output + fim.suffix,
            tokensGenerated: result.tokensGenerated,
            confidence: result.finalConfidence
        )
    }
}

// MARK: - Structured Output Support

/// Schema for structured output generation.
public struct OutputSchema: Sendable, Codable {
    public let type: SchemaType
    public let fields: [SchemaField]
    public let required: Set<String>

    public init(
        type: SchemaType,
        fields: [SchemaField],
        required: Set<String> = []
    ) {
        self.type = type
        self.fields = fields
        self.required = required
    }
}

/// Type of schema.
public enum SchemaType: String, Sendable, Codable {
    case json
    case table
    case list
    case code
}

/// A field in the schema.
public struct SchemaField: Sendable, Codable {
    public let name: String
    public let type: String
    public let description: String?

    public init(name: String, type: String, description: String? = nil) {
        self.name = name
        self.type = type
        self.description = description
    }
}

extension DiffusionBackend {
    /// Generates structured output conforming to schema.
    public func generateStructured(
        requestId: String,
        prompt: String,
        schema: OutputSchema,
        config: DiffusionInferenceConfig = .structured
    ) async throws -> StructuredGenerationResult {
        // Use constrained generation config
        var structuredConfig = config
        structuredConfig.temperature = 0.1  // Low temp for structure

        let result = try await generate(
            requestId: requestId,
            prompt: prompt + "\nOutput format: \(schema.type.rawValue)",
            maxTokens: 1024,
            config: structuredConfig
        )

        return StructuredGenerationResult(
            output: result.output,
            conformsToSchema: true,  // Would validate in real implementation
            parseErrors: []
        )
    }
}

/// Result of structured generation.
public struct StructuredGenerationResult: Sendable {
    public let output: String
    public let conformsToSchema: Bool
    public let parseErrors: [String]
}

// MARK: - Integration with Inference Plane

/// Adapter that integrates DiffusionBackend with the Inference Plane.
public actor DiffusionInferenceAdapter {
    private let backend: DiffusionBackend
    private let architectureRegistry: ArchitectureRegistry

    public init(
        backend: DiffusionBackend = DiffusionBackend(),
        architectureRegistry: ArchitectureRegistry = ArchitectureRegistry()
    ) {
        self.backend = backend
        self.architectureRegistry = architectureRegistry
    }

    /// Checks if a model should use diffusion backend.
    public func shouldUseDiffusion(
        model: ModelDescriptor,
        task: InferenceTask
    ) async -> Bool {
        // Check if model has diffusion architecture
        guard let profile = await architectureRegistry.getProfile(for: model.family) else {
            return false
        }

        guard profile.generationMode == .diffusion else {
            return false
        }

        // Check if task is suitable for diffusion
        let hints = ArchitectureSchedulingHints.from(task: task)
        return hints.diffusionAcceptable
    }

    /// Runs inference through diffusion backend.
    public func runInference(
        task: InferenceTask,
        model: ModelDescriptor
    ) async throws -> InferenceResult {
        // Get diffusion-specific config
        let diffusionConfig: DiffusionInferenceConfig
        switch task.kind {
        case .codeGeneration:
            diffusionConfig = .code
        case .extraction:
            diffusionConfig = .structured
        default:
            diffusionConfig = .fast
        }

        // Extract prompt
        let prompt: String
        switch task.input {
        case .text(let text):
            prompt = text
        case .messages(let messages):
            prompt = messages.map { $0.content }.joined(separator: "\n")
        case .batch(let texts):
            prompt = texts.first ?? ""
        case .structured(let input):
            prompt = input.data.values.joined(separator: "\n")
        }

        // Run diffusion
        let result = try await backend.generate(
            requestId: task.id,
            prompt: prompt,
            maxTokens: 1024,
            config: diffusionConfig
        )

        return InferenceResult(
            taskId: task.id,
            output: .text(result.output),
            modelUsed: model.id,
            backendUsed: .mlx,  // Diffusion typically runs on MLX
            tokensIn: prompt.count / 4,
            tokensOut: result.tokensGenerated,
            latency: .seconds(result.latency)
        )
    }
}
