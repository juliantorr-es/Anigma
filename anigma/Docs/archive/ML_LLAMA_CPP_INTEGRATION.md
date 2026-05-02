# llama.cpp Integration for Anigma CLI

## Overview

The Anigma CLI now supports **dual local inference backends**:
- **MLX** - Apple Silicon optimized (Metal acceleration)
- **llama.cpp** - Cross-platform GGUF models

Both backends support inference and embeddings, with automatic fallback.

## Architecture

```
┌─────────────────────────────────────────┐
│   UnifiedInferenceProvider              │
│   ├─ MLX Backend (optional)             │
│   ├─ llama.cpp Backend (optional)       │
│   └─ Cloud Backend (separate)           │
└─────────────────────────────────────────┘
         │
         ├─► LlamaCppProvider (inference)
         ├─► LlamaCppEmbeddingProvider (embeddings)
         ├─► MLXChatProvider (inference)
         └─► MLXEmbeddingProvider (embeddings)
```

## Files Created

### Core Providers
1. **ML/LlamaCppProvider.swift** - Main llama.cpp inference engine
2. **ML/LlamaCppEmbeddingProvider.swift** - Embedding generation
3. **ML/UnifiedInferenceProvider.swift** - Unified API for both backends
4. **ML/LocalModelManager.swift** - Model download and management

### Features

#### LlamaCppProvider
- Token generation with temperature control
- Batched evaluation
- Context management (default 2048 tokens)
- Thread-optimized execution
- Embedding extraction

#### UnifiedInferenceProvider
- Auto-backend selection (MLX → llama.cpp → Cloud)
- Consistent API across backends
- Streaming support
- Configuration management

#### LocalModelManager
- Curated model catalog
- Progress-tracked downloads
- Backend-specific organization
- Size-based recommendations

## Model Catalog

### Chat Models (llama.cpp GGUF)
```swift
- Llama 3.2 3B Q4    (~2.1 GB)
- Qwen 2.5 7B Q4     (~4.4 GB) - Code optimized
- Phi 3.5 Mini Q4    (~2.2 GB)
```

### Chat Models (MLX)
```swift
- Llama 3.2 3B 4bit  (~3.2 GB)
- Qwen 2.5 7B 4bit   (~7.0 GB) - Code optimized
- Phi 3.5 Mini 4bit  (~3.8 GB)
```

### Embedding Models (llama.cpp)
```swift
- Nomic Embed Text   (~274 MB) - 768 dimensions
- BGE Small EN       (~134 MB) - 384 dimensions
```

## Usage

### Automatic Backend Selection

```swift
let provider = AutoInferenceProvider()
try await provider.initialize()

let response = try await provider.generate(
    prompt: "Explain dependency injection",
    maxTokens: 512,
    temperature: 0.7
)
```

### Explicit Backend

```swift
let config = UnifiedInferenceProvider.Config(
    backend: .llamacpp,
    modelPath: "/path/to/model.gguf",
    contextSize: 4096,
    threads: 8
)

let provider = UnifiedInferenceProvider(config: config)
try await provider.initialize()
```

### Model Download

```swift
let manager = LocalModelManager()

let model = LocalModelManager.recommendedModels.first { 
    $0.id == "qwen-2.5-7b-gguf" 
}!

let path = try await manager.downloadModel(model) { progress in
    print("Downloaded: \(Int(progress * 100))%")
}

print("Model at: \(path.path)")
```

### Embeddings

```swift
// Hybrid provider (MLX or llama.cpp)
let embedder = try await HybridEmbeddingProvider(
    preferMLX: false,
    modelPath: "/path/to/embedding-model.gguf"
)

let embedding = try await embedder.embed(text: "Hello world")
// Returns [Float] vector
```

## Building with llama.cpp

### Optional Dependency

llama.cpp is **optional**. The code compiles and runs without it:

```swift
#if canImport(llama)
// Use native llama.cpp
#else
// Graceful degradation or MLX fallback
#endif
```

### Installation Options

#### Option 1: System llama.cpp
```bash
brew install llama.cpp
```

#### Option 2: Manual Build
```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make
# Link to /usr/local/lib or set LIBRARY_PATH
```

#### Option 3: Swift Package (Future)
```swift
.package(url: "https://github.com/ggerganov/llama.cpp", .branch("master"))
```

## Model Storage

Models are organized by backend:

```
~/.anigma/models/
├── mlx/
│   ├── mlx-llama-3.2-3b.mlx
│   └── mlx-qwen-2.5-7b.mlx
├── llamacpp/
│   ├── llama-3.2-3b-gguf.gguf
│   ├── qwen-2.5-7b-gguf.gguf
│   └── nomic-embed-text-gguf.gguf
└── index.json
```

## Integration with Onboarding

The onboarding flow will:
1. Detect available backends (MLX, llama.cpp, cloud only)
2. Recommend models based on:
   - Available memory
   - Backend support
   - User requirements (chat, code, embeddings)
3. Download selected models with progress
4. Configure default backend

## Performance Notes

### llama.cpp
- **Pros**: Cross-platform, wide model support, quantization
- **Cons**: Slower than MLX on Apple Silicon
- **Best for**: GGUF models, CPU-only systems, Linux

### MLX
- **Pros**: Fastest on Apple Silicon, native Metal
- **Cons**: macOS only, fewer models
- **Best for**: Apple Silicon Macs, production speed

## Testing

```bash
# Test llama.cpp provider
swift run anigma-cli models list --backend llamacpp

# Download and test a model
swift run anigma-cli models download llama-3.2-3b-gguf
swift run anigma-cli chat --model llama-3.2-3b-gguf --backend llamacpp

# Test embeddings
swift run anigma-cli embed "test string" --model nomic-embed-text-gguf
```

## Error Handling

```swift
do {
    let provider = AutoInferenceProvider()
    try await provider.initialize()
} catch InferenceError.backendNotAvailable(let msg) {
    print("Backend unavailable: \(msg)")
} catch InferenceError.missingConfiguration(let msg) {
    print("Configuration error: \(msg)")
} catch {
    print("Initialization failed: \(error)")
}
```

## Future Enhancements

- [ ] GPU offloading control (llama.cpp metal backend)
- [ ] Model quantization pipeline
- [ ] LoRA adapter support
- [ ] Multi-GPU inference
- [ ] Model benchmarking suite
- [ ] Automatic model conversion (HF → GGUF)

## References

- llama.cpp: https://github.com/ggerganov/llama.cpp
- GGUF format: https://github.com/ggerganov/ggml/blob/master/docs/gguf.md
- MLX: https://github.com/ml-explore/mlx
- Model sources: https://huggingface.co/models?library=gguf
