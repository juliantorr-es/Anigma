# Local Inference Module

## Overview

Unified local ML inference system supporting multiple backends with automatic detection, intelligent fallback, and consistent API.

## Architecture

### UnifiedInferenceEngine (Primary Interface)

The main entry point that provides:
- **Auto-detection**: Automatically finds and configures available backends
- **Intelligent fallback**: Seamlessly switches between backends on failure
- **Consistent API**: Unified interface for generation and embeddings
- **Flexible configuration**: Per-backend configuration and preferences

### Supported Backends

1. **MLX Backend** (Apple Silicon optimized)
   - Native MLX framework integration
   - Hardware-accelerated inference on Apple Silicon
   - Optimal for M1/M2/M3 Macs

2. **llama.cpp Backend** (Cross-platform)
   - Process-based inference using llama-cli
   - Compatible with GGUF models
   - Works on any platform with llama.cpp installed

3. **Ollama Backend** (Local server)
   - REST API based inference
   - Supports model management
   - Easy model switching and updates

## Usage

### Basic Usage

```swift
// Auto-detect best backend
let config = UnifiedInferenceEngine.BackendConfig(
    modelPath: "/path/to/model",
    autoDetect: true,
    fallbackEnabled: true
)

let engine = UnifiedInferenceEngine(config: config)
try await engine.initialize()

// Generate text
let response = try await engine.generate(
    prompt: "Hello, world!",
    maxTokens: 100,
    temperature: 0.7
)

// Generate embeddings
let embedding = try await engine.embed(text: "Some text to embed")
```

### Preferred Backend

```swift
// Force specific backend
let config = UnifiedInferenceEngine.BackendConfig(
    modelPath: "/path/to/model",
    preferredBackend: .llamaCpp,
    fallbackEnabled: true
)
```

### Status Check

```swift
let status = await engine.getStatus()
print("Active: \(status.activeBackend)")
print("MLX available: \(status.mlxAvailable)")
print("llama.cpp available: \(status.llamacppAvailable)")
print("Ollama available: \(status.ollamaAvailable)")
```

## Implementation Details

### Auto-Detection Order

1. MLX (if Apple Silicon + macOS 14+)
2. llama.cpp (if llama-cli found in PATH)
3. Ollama (if server running on localhost:11434)

### Fallback Strategy

When a backend fails:
1. Try next available backend in priority order
2. Re-initialize with new backend
3. Retry the operation
4. Throw error only if all backends fail

### Thread Safety

All backends are implemented as `actor` types for safe concurrent access.

## Error Handling

```swift
do {
    let result = try await engine.generate(prompt: "test")
} catch InferenceError.notInitialized {
    // Engine not initialized
} catch InferenceError.backendNotAvailable(let name) {
    // Specific backend unavailable
} catch InferenceError.allBackendsFailed {
    // All backends failed
} catch {
    // Other errors
}
```

## Backend-Specific Configuration

### MLX Backend
- Requires: macOS 14+, Apple Silicon
- Models: MLX-optimized models
- Performance: Best for local inference on Mac

### llama.cpp Backend  
- Requires: llama-cli executable
- Models: GGUF format
- Installation: `brew install llama.cpp`

### Ollama Backend
- Requires: Ollama server running
- Models: Managed via `ollama pull <model>`
- Installation: Download from ollama.ai

## Integration Points

- Used by `OnboardingFlow` for initial model downloads
- Integrated with `RAGPipeline` for embeddings
- Cloud providers fall back to local inference
- Model manager tracks available backends

## Future Enhancements

- [ ] Streaming generation support
- [ ] Batch embedding optimization
- [ ] Model quantization options
- [ ] Performance benchmarking
- [ ] GPU memory management
- [ ] Multi-model parallel execution
