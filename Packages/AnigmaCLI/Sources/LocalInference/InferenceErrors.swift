import Foundation

// MARK: - MLX Errors

public enum MLXError: Error, LocalizedError {
    case notAvailable
    case modelNotFound(String)
    case modelNotLoaded
    case loadFailed(String)
    case inferenceFailed(String)
    case notImplemented

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "MLX framework not available. Ensure you're running on Apple Silicon with macOS 14+"
        case .modelNotFound(let path):
            return "MLX model not found at path: \(path)"
        case .modelNotLoaded:
            return "Model not loaded. Call loadModel() first."
        case .loadFailed(let reason):
            return "Failed to load MLX model: \(reason)"
        case .inferenceFailed(let reason):
            return "MLX inference failed: \(reason)"
        case .notImplemented:
            return "MLX feature not yet implemented"
        }
    }
}

// MARK: - llama.cpp Errors

public enum LlamaCppError: Error, LocalizedError {
    case notAvailable
    case modelNotFound(String)
    case modelNotLoaded
    case loadFailed(String)
    case inferenceFailed(String)
    case initializationFailed(String)
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "llama.cpp executable not found. Install via: brew install llama.cpp"
        case .modelNotFound(let path):
            return "Model not found at path: \(path)"
        case .modelNotLoaded:
            return "Model not loaded. Call loadModel() first."
        case .loadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .inferenceFailed(let reason):
            return "Inference failed: \(reason)"
        case .initializationFailed(let reason):
            return "Initialization failed: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}

// MARK: - Ollama Errors

public enum OllamaError: Error, LocalizedError {
    case serverNotAvailable
    case modelNotFound(String)
    case requestFailed(String)
    case decodingFailed(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .serverNotAvailable:
            return "Ollama server not running. Start with: ollama serve"
        case .modelNotFound(let name):
            return "Model '\(name)' not found. Pull with: ollama pull \(name)"
        case .requestFailed(let reason):
            return "Request failed: \(reason)"
        case .decodingFailed(let reason):
            return "Failed to decode response: \(reason)"
        case .invalidResponse:
            return "Invalid response from Ollama server"
        }
    }
}

// MARK: - Unified Inference Errors

public enum InferenceError: Error, LocalizedError {
    case backendNotAvailable(String)
    case allBackendsFailed
    case noBackendAvailable
    case notInitialized
    case notImplemented(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .backendNotAvailable(let backend):
            return "Backend not available: \(backend)"
        case .allBackendsFailed:
            return "All available backends failed to process the request"
        case .noBackendAvailable:
            return "No ML backend available. Install MLX, llama.cpp, or Ollama"
        case .notInitialized:
            return "Inference engine not initialized. Call initialize() first"
        case .notImplemented(let feature):
            return "Not implemented: \(feature)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        }
    }
}
