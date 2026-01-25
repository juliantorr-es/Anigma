//
//  ModelRegistry.swift
//  HarmoniaModule
//
//  Central registry for available models and their capabilities.
//  Maps models to backends, capabilities, and resource requirements.
//

@preconcurrency import Foundation
import AnigmaCore

// MARK: - Capability Profile

/// What a model can do.
public struct CapabilityProfile: Sendable, Codable {
    /// Task types this model supports.
    public let supportedTasks: Set<InferenceTaskKind>

    /// Maximum context window in tokens.
    public let maxContextWindow: Int

    /// Languages supported.
    public let languages: Set<String>

    /// Whether the model supports tool/function calling.
    public let supportsToolCalling: Bool

    /// Whether the model supports vision/image input.
    public let supportsVision: Bool

    /// Quality tier of this model.
    public let qualityTier: QualityTier

    /// Additional capability flags.
    public let capabilities: Set<String>

    public init(
        supportedTasks: Set<InferenceTaskKind>,
        maxContextWindow: Int,
        languages: Set<String> = ["en"],
        supportsToolCalling: Bool = false,
        supportsVision: Bool = false,
        qualityTier: QualityTier,
        capabilities: Set<String> = []
    ) {
        self.supportedTasks = supportedTasks
        self.maxContextWindow = maxContextWindow
        self.languages = languages
        self.supportsToolCalling = supportsToolCalling
        self.supportsVision = supportsVision
        self.qualityTier = qualityTier
        self.capabilities = capabilities
    }
}

// MARK: - Resource Profile

/// Hardware and resource requirements for a model.
public struct ResourceProfile: Sendable, Codable {
    /// Estimated VRAM required in GB.
    public let vramRequired: Double

    /// Estimated RAM required in GB.
    public let ramRequired: Double

    /// Preferred device type.
    public let preferredDevice: DevicePreference

    /// Expected tokens per second on reference hardware.
    public let expectedTokensPerSecond: Double

    /// Parameter count in billions.
    public let parameterCount: Double

    /// Quantization level (if any).
    public let quantization: String?

    public init(
        vramRequired: Double,
        ramRequired: Double,
        preferredDevice: DevicePreference = .gpu,
        expectedTokensPerSecond: Double,
        parameterCount: Double,
        quantization: String? = nil
    ) {
        self.vramRequired = vramRequired
        self.ramRequired = ramRequired
        self.preferredDevice = preferredDevice
        self.expectedTokensPerSecond = expectedTokensPerSecond
        self.parameterCount = parameterCount
        self.quantization = quantization
    }
}

/// Preferred compute device.
public enum DevicePreference: String, Sendable, Codable {
    case cpu
    case gpu
    case ane         // Apple Neural Engine
    case any
}

// MARK: - Model Descriptor

/// Complete description of a runnable model.
public struct ModelDescriptor: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let family: String
    public let version: String
    public let backend: BackendKind
    public let format: ModelFormat
    public let capabilities: CapabilityProfile
    public let resources: ResourceProfile
    /// Optional embedding dimension if the model supports embeddings.
    public let embeddingDimension: Int?
    /// Provenance data for evidence hashing.
    public let provenance: ModelProvenance?
    public let storageLocation: URL?
    public let remoteEndpoint: URL?
    public let isEnabled: Bool
    public let costTier: CostTier
    public let privacyTier: InferencePrivacyLevel

    public init(
        id: String,
        displayName: String,
        family: String,
        version: String,
        backend: BackendKind,
        format: ModelFormat,
        capabilities: CapabilityProfile,
        resources: ResourceProfile,
        embeddingDimension: Int? = nil,
        provenance: ModelProvenance? = nil,
        storageLocation: URL? = nil,
        remoteEndpoint: URL? = nil,
        isEnabled: Bool = true,
        costTier: CostTier = .free,
        privacyTier: InferencePrivacyLevel = .internal
    ) {
        self.id = id
        self.displayName = displayName
        self.family = family
        self.version = version
        self.backend = backend
        self.format = format
        self.capabilities = capabilities
        self.resources = resources
        self.embeddingDimension = embeddingDimension
        self.provenance = provenance
        self.storageLocation = storageLocation
        self.remoteEndpoint = remoteEndpoint
        self.isEnabled = isEnabled
        self.costTier = costTier
        self.privacyTier = privacyTier
    }

    public static func == (lhs: ModelDescriptor, rhs: ModelDescriptor) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Provenance details for model artifacts and binaries.
public struct ModelProvenance: Sendable, Codable, Hashable {
    public let modelHash: String?
    public let tokenizerHash: String?
    public let binaryHash: String?
    public let source: String?

    public init(
        modelHash: String? = nil,
        tokenizerHash: String? = nil,
        binaryHash: String? = nil,
        source: String? = nil
    ) {
        self.modelHash = modelHash
        self.tokenizerHash = tokenizerHash
        self.binaryHash = binaryHash
        self.source = source
    }
}

// MARK: - Model Registry

/// Central registry for managing available models.
public actor ModelRegistry {
    /// All registered models.
    private var models: [String: ModelDescriptor] = [:]

    /// Per-tenant model availability overrides.
    private var tenantOverrides: [String: Set<String>] = [:]

    /// Per-tenant disabled models.
    private var tenantDisabled: [String: Set<String>] = [:]

    public init() {
        // Initialize with built-in models to ensure routing works out of the box
        models = Dictionary(uniqueKeysWithValues: Self.builtInModels().map { ($0.id, $0) })
    }

    // MARK: - Registration

    /// Registers a model in the registry.
    public func register(_ model: ModelDescriptor) {
        models[model.id] = model
    }

    /// Unregisters a model.
    public func unregister(id: String) {
        models.removeValue(forKey: id)
    }

    /// Gets a model by ID.
    public func get(id: String) -> ModelDescriptor? {
        models[id]
    }

    /// Lists all registered models.
    public func listAll() -> [ModelDescriptor] {
        Array(models.values)
    }

    // MARK: - Tenant Configuration

    /// Enables a model for a specific tenant.
    public func enableForTenant(_ modelId: String, tenantId: String) {
        var enabled = tenantOverrides[tenantId] ?? []
        enabled.insert(modelId)
        tenantOverrides[tenantId] = enabled

        var disabled = tenantDisabled[tenantId] ?? []
        disabled.remove(modelId)
        tenantDisabled[tenantId] = disabled
    }

    /// Disables a model for a specific tenant.
    public func disableForTenant(_ modelId: String, tenantId: String) {
        var disabled = tenantDisabled[tenantId] ?? []
        disabled.insert(modelId)
        tenantDisabled[tenantId] = disabled
    }

    /// Checks if a model is available for a tenant.
    public func isAvailable(_ modelId: String, forTenant tenantId: String) -> Bool {
        guard let model = models[modelId], model.isEnabled else {
            return false
        }

        // Check tenant-specific disabling
        if tenantDisabled[tenantId]?.contains(modelId) == true {
            return false
        }

        return true
    }

    // MARK: - Resolution

    /// Finds models matching the given task and constraints.
    public func findCandidates(
        for task: InferenceTask,
        tenantId: String
    ) -> [ModelDescriptor] {
        let constraints = task.constraints

        return models.values.filter { model in
            // Must be enabled and available for tenant
            guard model.isEnabled && isAvailableSync(model.id, forTenant: tenantId) else {
                return false
            }

            // Must support the task type
            guard model.capabilities.supportedTasks.contains(task.kind) else {
                return false
            }

            // Check local-only constraint
            if constraints.localOnly && model.backend == .remoteAPI {
                return false
            }

            // Check privacy level
            if !isPrivacyCompatible(model.privacyTier, with: constraints.privacyLevel) {
                return false
            }

            // Check quality tier
            if let minQuality = constraints.minQualityTier,
               model.capabilities.qualityTier < minQuality {
                return false
            }

            // Check cost tier
            if let maxCost = constraints.maxCostTier,
               model.costTier > maxCost {
                return false
            }

            // Check context window
            if let minContext = constraints.minContextWindow,
               model.capabilities.maxContextWindow < minContext {
                return false
            }

            // Check preferred families
            if let families = constraints.preferredFamilies,
               !families.isEmpty,
               !families.contains(model.family) {
                return false
            }

            // Check required capabilities
            if let required = constraints.requiredCapabilities {
                for cap in required {
                    if cap == "tool_calling" && !model.capabilities.supportsToolCalling {
                        return false
                    }
                    if cap == "vision" && !model.capabilities.supportsVision {
                        return false
                    }
                    if !model.capabilities.capabilities.contains(cap) &&
                       cap != "tool_calling" && cap != "vision" {
                        return false
                    }
                }
            }

            return true
        }.sorted { lhs, rhs in
            // Sort by quality tier (higher is better) then by speed
            if lhs.capabilities.qualityTier != rhs.capabilities.qualityTier {
                return lhs.capabilities.qualityTier > rhs.capabilities.qualityTier
            }
            return lhs.resources.expectedTokensPerSecond > rhs.resources.expectedTokensPerSecond
        }
    }

    /// Selects the best model for a task.
    public func selectBest(
        for task: InferenceTask,
        tenantId: String
    ) -> ModelDescriptor? {
        let candidates = findCandidates(for: task, tenantId: tenantId)
        return candidates.first
    }

    // MARK: - Private Helpers

    private func isAvailableSync(_ modelId: String, forTenant tenantId: String) -> Bool {
        guard let model = models[modelId], model.isEnabled else {
            return false
        }
        if tenantDisabled[tenantId]?.contains(modelId) == true {
            return false
        }
        return true
    }

    private func isPrivacyCompatible(
        _ modelPrivacy: InferencePrivacyLevel,
        with dataPrivacy: InferencePrivacyLevel
    ) -> Bool {
        // Model must be at least as private as the data requires
        let privacyOrder: [InferencePrivacyLevel] = [.public, .internal, .sensitive, .restricted]
        guard let modelIndex = privacyOrder.firstIndex(of: modelPrivacy),
              let dataIndex = privacyOrder.firstIndex(of: dataPrivacy) else {
            return false
        }
        return modelIndex >= dataIndex
    }

    // MARK: - Built-in Models

    private static func builtInModels() -> [ModelDescriptor] {
        // MLX Embeddings (local)
        let mlxEmbed = ModelDescriptor(
            id: "mlx-community/bge-small-en-v1.5-4bit",
            displayName: "MLX BGE Small EN v1.5 (4bit, 384d)",
            family: "bge-small-en-v1.5",
            version: "4bit",
            backend: .mlx,
            format: .mlx,
            capabilities: CapabilityProfile(
                supportedTasks: [.embed],
                maxContextWindow: 8192,
                languages: ["en"],
                supportsToolCalling: false,
                qualityTier: .small
            ),
            resources: ResourceProfile(
                vramRequired: 2.0,
                ramRequired: 4.0,
                expectedTokensPerSecond: 500.0,
                parameterCount: 0.1,
                quantization: "fp16"
            ),
            embeddingDimension: 384,
            provenance: ModelProvenance(
                modelHash: nil,
                tokenizerHash: nil,
                binaryHash: nil,
                source: "hf:mlx-community/bge-small-en-v1.5-4bit"
            ),
            costTier: .free,
            privacyTier: .restricted
        )
        // Qwen3 4B (MLX)
        let mlxQwen = ModelDescriptor(
            id: "mlx-community/Qwen3-4B-4bit",
            displayName: "Qwen3 4B (MLX 4bit)",
            family: "qwen",
            version: "3.0",
            backend: .mlx,
            format: .mlx,
            capabilities: CapabilityProfile(
                supportedTasks: [.chat, .summarize, .codeGeneration, .codeExplanation, .classify],
                maxContextWindow: 128_000,
                languages: ["en", "es", "fr", "de", "zh"],
                supportsToolCalling: true,
                qualityTier: .small
            ),
            resources: ResourceProfile(
                vramRequired: 4.0,
                ramRequired: 8.0,
                expectedTokensPerSecond: 45.0,
                parameterCount: 4.0,
                quantization: "4bit"
            ),
            provenance: ModelProvenance(
                modelHash: nil,
                tokenizerHash: nil,
                binaryHash: nil,
                source: "hf:mlx-community/Qwen3-4B-4bit"
            ),
            costTier: .free,
            privacyTier: .restricted
        )

        // Llama 3.1 8B (llama.cpp)
        let llama3 = ModelDescriptor(
            id: "llama-3.1-8b-gguf",
            displayName: "Llama 3.1 8B (GGUF)",
            family: "llama",
            version: "3.1",
            backend: .llamaCpp,
            format: .gguf,
            capabilities: CapabilityProfile(
                supportedTasks: [.chat, .summarize, .codeGeneration, .toolCall, .classify, .extraction],
                maxContextWindow: 128_000,
                languages: ["en", "es", "fr", "de", "it", "pt", "zh", "ja", "ko"],
                supportsToolCalling: true,
                qualityTier: .base
            ),
            resources: ResourceProfile(
                vramRequired: 6.0,
                ramRequired: 12.0,
                expectedTokensPerSecond: 35.0,
                parameterCount: 8.0,
                quantization: "Q4_K_M"
            ),
            embeddingDimension: 4096,
            costTier: .free,
            privacyTier: .restricted
        )

        // DeepSeek R1 8B (Ollama)
        let deepseekR1 = ModelDescriptor(
            id: "deepseek-r1-8b-ollama",
            displayName: "DeepSeek R1 8B (Ollama)",
            family: "deepseek",
            version: "r1",
            backend: .ollama,
            format: .ollama,
            capabilities: CapabilityProfile(
                supportedTasks: [.chat, .codeGeneration, .codeExplanation, .summarize],
                maxContextWindow: 64_000,
                languages: ["en", "zh"],
                supportsToolCalling: false,
                qualityTier: .base,
                capabilities: ["reasoning", "math"]
            ),
            resources: ResourceProfile(
                vramRequired: 6.0,
                ramRequired: 12.0,
                expectedTokensPerSecond: 30.0,
                parameterCount: 8.0,
                quantization: "Q4_0"
            ),
            costTier: .free,
            privacyTier: .restricted
        )

        // Nomic Embed (for embeddings)
        let nomicEmbed = ModelDescriptor(
            id: "nomic-embed-text-v1.5",
            displayName: "Nomic Embed Text v1.5",
            family: "nomic",
            version: "1.5",
            backend: .ollama,
            format: .ollama,
            capabilities: CapabilityProfile(
                supportedTasks: [.embed],
                maxContextWindow: 8192,
                languages: ["en"],
                qualityTier: .small
            ),
            resources: ResourceProfile(
                vramRequired: 1.0,
                ramRequired: 2.0,
                expectedTokensPerSecond: 500.0,
                parameterCount: 0.137
            ),
            embeddingDimension: 768,
            costTier: .free,
            privacyTier: .restricted
        )

        // Qwen2.5 Coder 7B
        let qwenCoder = ModelDescriptor(
            id: "qwen2.5-coder-7b",
            displayName: "Qwen2.5 Coder 7B",
            family: "qwen",
            version: "2.5",
            backend: .ollama,
            format: .ollama,
            capabilities: CapabilityProfile(
                supportedTasks: [.codeGeneration, .codeExplanation, .chat],
                maxContextWindow: 32_768,
                languages: ["en", "zh"],
                supportsToolCalling: true,
                qualityTier: .base,
                capabilities: ["code", "refactoring"]
            ),
            resources: ResourceProfile(
                vramRequired: 5.0,
                ramRequired: 10.0,
                expectedTokensPerSecond: 40.0,
                parameterCount: 7.0,
                quantization: "Q4_K_M"
            ),
            costTier: .free,
            privacyTier: .restricted
        )

        // DeepSeek Chat (cloud, OpenAI-compatible)
        let deepseekChat = ModelDescriptor(
            id: "deepseek-chat",
            displayName: "DeepSeek Chat (Cloud)",
            family: "deepseek",
            version: "chat",
            backend: .remoteAPI,
            format: .remote,
            capabilities: CapabilityProfile(
                supportedTasks: [.chat, .summarize, .codeGeneration, .codeExplanation],
                maxContextWindow: 128_000,
                languages: ["en", "zh"],
                supportsToolCalling: true,
                qualityTier: .base
            ),
            resources: ResourceProfile(
                vramRequired: 0.0,
                ramRequired: 0.0,
                preferredDevice: .any,
                expectedTokensPerSecond: 0.0,
                parameterCount: 0.0
            ),
            embeddingDimension: nil,
            provenance: ModelProvenance(source: "https://api.deepseek.com"),
            remoteEndpoint: URL(string: "https://api.deepseek.com/v1"),
            costTier: .metered,
            privacyTier: .restricted
        )

        // DeepSeek Embeddings placeholder (fail-closed until provider adds support)
        let deepseekEmbed = ModelDescriptor(
            id: "deepseek-embed-placeholder",
            displayName: "DeepSeek Embeddings (Not Supported)",
            family: "deepseek",
            version: "embed",
            backend: .remoteAPI,
            format: .remote,
            capabilities: CapabilityProfile(
                supportedTasks: [.embed],
                maxContextWindow: 8192,
                languages: ["en"],
                supportsToolCalling: false,
                qualityTier: .base
            ),
            resources: ResourceProfile(
                vramRequired: 0.0,
                ramRequired: 0.0,
                preferredDevice: .any,
                expectedTokensPerSecond: 0.0,
                parameterCount: 0.0
            ),
            embeddingDimension: nil,
            provenance: ModelProvenance(source: "https://api.deepseek.com/v1"),
            remoteEndpoint: URL(string: "https://api.deepseek.com/v1"),
            isEnabled: false, // fail-closed until provider announces embeddings
            costTier: .metered,
            privacyTier: .restricted
        )

        return [
            mlxEmbed,
            mlxQwen,
            llama3,
            deepseekR1,
            nomicEmbed,
            qwenCoder,
            deepseekChat,
            deepseekEmbed
        ]
    }
}

// MARK: - Registry Statistics

extension ModelRegistry {
    /// Gets statistics about registered models.
    public func statistics() -> RegistryStatistics {
        let allModels = Array(models.values)

        let byBackend = Dictionary(grouping: allModels) { $0.backend }
            .mapValues { $0.count }

        let byQuality = Dictionary(grouping: allModels) { $0.capabilities.qualityTier }
            .mapValues { $0.count }

        let enabledCount = allModels.filter { $0.isEnabled }.count

        return RegistryStatistics(
            totalModels: allModels.count,
            enabledModels: enabledCount,
            modelsByBackend: byBackend,
            modelsByQuality: byQuality
        )
    }
}

/// Statistics about the model registry.
public struct RegistryStatistics: Sendable {
    public let totalModels: Int
    public let enabledModels: Int
    public let modelsByBackend: [BackendKind: Int]
    public let modelsByQuality: [QualityTier: Int]
}
