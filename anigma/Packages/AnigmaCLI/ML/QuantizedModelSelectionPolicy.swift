import Foundation

/// Deterministic policy for selecting quantized local MLX chat models.
public enum QuantizedModelSelectionPolicy {
    public enum Profile: String, Sendable {
        case latency
        case balanced
        case quality
    }

    public struct Context: Sendable {
        public let promptCharacters: Int
        public let maxTokens: Int
        public let physicalMemoryBytes: UInt64?
        public let profile: Profile
        public let isAppleSilicon: Bool
        public let explicitModelOverride: String?

        public init(
            promptCharacters: Int,
            maxTokens: Int,
            physicalMemoryBytes: UInt64?,
            profile: Profile,
            isAppleSilicon: Bool,
            explicitModelOverride: String?
        ) {
            self.promptCharacters = promptCharacters
            self.maxTokens = maxTokens
            self.physicalMemoryBytes = physicalMemoryBytes
            self.profile = profile
            self.isAppleSilicon = isAppleSilicon
            self.explicitModelOverride = explicitModelOverride
        }
    }

    public struct Decision: Sendable {
        public let modelID: String
        public let quantization: String
        public let reason: String
        public let profile: Profile
        public let memoryGB: Double?
        public let estimatedTokenBudget: Int
    }

    public static let stableDefaultModel = "mlx-community/Llama-3.2-3B-Instruct-4bit"

    public static func decide(context: Context) -> Decision {
        let estimatedBudget = estimateTokenBudget(promptCharacters: context.promptCharacters, maxTokens: context.maxTokens)
        let memoryGB = context.physicalMemoryBytes.map { Double($0) / 1_073_741_824.0 }

        if let explicit = normalizedOverride(context.explicitModelOverride) {
            return Decision(
                modelID: explicit,
                quantization: "4-bit",
                reason: "explicit override",
                profile: context.profile,
                memoryGB: memoryGB,
                estimatedTokenBudget: estimatedBudget
            )
        }

        guard context.isAppleSilicon else {
            return Decision(
                modelID: stableDefaultModel,
                quantization: "4-bit",
                reason: "non-Apple-Silicon fallback",
                profile: context.profile,
                memoryGB: memoryGB,
                estimatedTokenBudget: estimatedBudget
            )
        }

        let resolvedModel: String
        let resolvedReason: String

        switch context.profile {
        case .latency:
            if (memoryGB ?? 0) < 8 || estimatedBudget <= 1_024 {
                resolvedModel = "mlx-community/Phi-3.5-mini-instruct-4bit"
                resolvedReason = "latency profile + small budget/memory"
            } else {
                resolvedModel = stableDefaultModel
                resolvedReason = "latency profile + moderate workload"
            }
        case .balanced:
            if (memoryGB ?? 0) < 8 {
                resolvedModel = "mlx-community/Phi-3.5-mini-instruct-4bit"
                resolvedReason = "balanced profile + low memory"
            } else if (memoryGB ?? 0) >= 18, estimatedBudget >= 4_096 {
                resolvedModel = "mlx-community/Qwen2.5-7B-Instruct-4bit"
                resolvedReason = "balanced profile + high memory/large workload"
            } else {
                resolvedModel = stableDefaultModel
                resolvedReason = "balanced profile default tier"
            }
        case .quality:
            if (memoryGB ?? 0) >= 18 {
                resolvedModel = "mlx-community/Qwen2.5-7B-Instruct-4bit"
                resolvedReason = "quality profile + enough memory"
            } else {
                resolvedModel = stableDefaultModel
                resolvedReason = "quality profile fallback for memory"
            }
        }

        return Decision(
            modelID: resolvedModel,
            quantization: "4-bit",
            reason: resolvedReason,
            profile: context.profile,
            memoryGB: memoryGB,
            estimatedTokenBudget: estimatedBudget
        )
    }

    private static func normalizedOverride(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func estimateTokenBudget(promptCharacters: Int, maxTokens: Int) -> Int {
        let promptTokensEstimate = max(1, promptCharacters / 4)
        return promptTokensEstimate + maxTokens
    }
}

