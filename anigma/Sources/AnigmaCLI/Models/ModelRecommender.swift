import Foundation

/// Recommends optimal models based on system capabilities
struct ModelRecommender {
    static func recommend(for benchmark: BenchmarkResults) -> [ModelRecommendation] {
        var recommendations: [ModelRecommendation] = []

        // Embedding model (always needed)
        recommendations.append(selectEmbeddingModel(for: benchmark))

        // Chat models based on system tier
        if benchmark.isHighEnd {
            recommendations.append(contentsOf: highEndChatModels())
        } else if benchmark.isMidRange {
            recommendations.append(contentsOf: midRangeChatModels())
        } else {
            recommendations.append(contentsOf: lowEndChatModels())
        }

        // Code-specific model
        if benchmark.memory.totalGB >= 8 {
            recommendations.append(codeModel(for: benchmark))
        }

        return recommendations
    }

    private static func selectEmbeddingModel(for benchmark: BenchmarkResults) -> ModelRecommendation {
        if benchmark.hasAppleSilicon {
            return ModelRecommendation(
                id: "nomic-embed-text",
                name: "Nomic Embed Text",
                type: .embedding,
                sizeGB: 0.5,
                description: "High-quality embeddings optimized for Apple Silicon",
                url: "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF",
                fileName: "nomic-embed-text-v1.5.Q8_0.gguf",
                quantization: "Q8_0"
            )
        } else {
            return ModelRecommendation(
                id: "all-minilm-l6-v2",
                name: "All-MiniLM-L6-v2",
                type: .embedding,
                sizeGB: 0.08,
                description: "Fast, efficient embeddings for any system",
                url: "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2",
                fileName: "model.gguf",
                quantization: "fp16"
            )
        }
    }

    private static func highEndChatModels() -> [ModelRecommendation] {
        [
            ModelRecommendation(
                id: "qwen2.5-72b",
                name: "Qwen 2.5 72B",
                type: .chat,
                sizeGB: 42.0,
                description: "Frontier-class reasoning and code generation",
                url: "https://huggingface.co/Qwen/Qwen2.5-72B-Instruct-GGUF",
                fileName: "qwen2.5-72b-instruct-q4_k_m.gguf",
                quantization: "Q4_K_M"
            ),
            ModelRecommendation(
                id: "llama-3.3-70b",
                name: "Llama 3.3 70B",
                type: .chat,
                sizeGB: 40.0,
                description: "Excellent general-purpose performance",
                url: "https://huggingface.co/meta-llama/Llama-3.3-70B-Instruct-GGUF",
                fileName: "llama-3.3-70b-instruct-q4_k_m.gguf",
                quantization: "Q4_K_M"
            )
        ]
    }

    private static func midRangeChatModels() -> [ModelRecommendation] {
        [
            ModelRecommendation(
                id: "qwen2.5-14b",
                name: "Qwen 2.5 14B",
                type: .chat,
                sizeGB: 8.5,
                description: "Strong coding and reasoning in smaller package",
                url: "https://huggingface.co/Qwen/Qwen2.5-14B-Instruct-GGUF",
                fileName: "qwen2.5-14b-instruct-q4_k_m.gguf",
                quantization: "Q4_K_M"
            ),
            ModelRecommendation(
                id: "llama-3.1-8b",
                name: "Llama 3.1 8B",
                type: .chat,
                sizeGB: 4.7,
                description: "Fast, capable, well-rounded assistant",
                url: "https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct-GGUF",
                fileName: "llama-3.1-8b-instruct-q4_k_m.gguf",
                quantization: "Q4_K_M"
            )
        ]
    }

    private static func lowEndChatModels() -> [ModelRecommendation] {
        [
            ModelRecommendation(
                id: "phi-3.5-mini",
                name: "Phi 3.5 Mini",
                type: .chat,
                sizeGB: 2.3,
                description: "Compact but capable, great for basic tasks",
                url: "https://huggingface.co/microsoft/Phi-3.5-mini-instruct-gguf",
                fileName: "Phi-3.5-mini-instruct-q4.gguf",
                quantization: "Q4"
            ),
            ModelRecommendation(
                id: "gemma-2-2b",
                name: "Gemma 2 2B",
                type: .chat,
                sizeGB: 1.6,
                description: "Ultra-efficient Google model",
                url: "https://huggingface.co/google/gemma-2-2b-it-GGUF",
                fileName: "gemma-2-2b-it-q4_k_m.gguf",
                quantization: "Q4_K_M"
            )
        ]
    }

    private static func codeModel(for benchmark: BenchmarkResults) -> ModelRecommendation {
        if benchmark.isHighEnd {
            return ModelRecommendation(
                id: "deepseek-coder-33b",
                name: "DeepSeek Coder 33B",
                type: .code,
                sizeGB: 19.0,
                description: "Specialized code generation and analysis",
                url: "https://huggingface.co/deepseek-ai/deepseek-coder-33b-instruct-GGUF",
                fileName: "deepseek-coder-33b-instruct.Q4_K_M.gguf",
                quantization: "Q4_K_M"
            )
        } else {
            return ModelRecommendation(
                id: "qwen2.5-coder-7b",
                name: "Qwen 2.5 Coder 7B",
                type: .code,
                sizeGB: 4.4,
                description: "Efficient code-focused model",
                url: "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF",
                fileName: "qwen2.5-coder-7b-instruct-q4_k_m.gguf",
                quantization: "Q4_K_M"
            )
        }
    }
}

struct ModelRecommendation: Codable {
    let id: String
    let name: String
    let type: ModelType
    let sizeGB: Double
    let description: String
    let url: String
    let fileName: String
    let quantization: String
}

enum ModelType: String, Codable {
    case embedding
    case chat
    case code
}
