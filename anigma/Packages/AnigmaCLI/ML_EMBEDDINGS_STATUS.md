# MLX Embeddings Integration - IN PROGRESS ⚠️

## Status: Build Issues - Requires ML Module Linking Strategy

Successfully created MLX Swift integration code, but encountering Cmlx module resolution issues during build.

## Issue Summary

The MLX Swift framework has a C module dependency (`Cmlx`) that requires special handling in SwiftPM:
- `AnigmaCLIML` target compiles successfully in isolation
- When linked as a dependency, transitive C module isn't found
- Conditional compilation with `#if canImport` doesn't prevent the module search

## Root Cause

MLX Swift's architecture:
```
mlx-swift-lm (package)
├── MLXLMCommon (Swift)
├── MLXEmbedders (Swift)
└── mlx-swift (dependency)
    ├── MLX (Swift)
    └── Cmlx (C module) ← Missing at link time
```

## Solutions to Explore

### Option 1: Make MLX a Top-Level Dependency (Recommended)
```swift
// In Package.swift dependencies:
.package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.18.0"),

// Then in target:
.product(name: "MLX", package: "mlx-swift"),
.product(name: "MLXNN", package: "mlx-swift"),
```

### Option 2: Use ML Worker Subprocess (Current Working Approach)
- Keep MLX in separate `ml-worker` executable
- anigma-cli shells out to ml-worker for embeddings
- Already working in HarmoniaSurface
- Trade-off: IPC overhead vs. clean module boundaries

### Option 3: Link Strategy with Linker Settings
```swift
.target(
    name: "AnigmaCLIML",
    dependencies: [...],
    linkerSettings: [
        .linkedFramework("Accelerate", .when(platforms: [.macOS])),
        .linkedLibrary("c++")
    ]
)
```

## Files Created (Ready for Integration)

### ✅ Complete Implementation
1. **MLXEmbeddingProvider.swift** - Local embedding generation
   - Actor-based thread safety
   - Batch processing with progress
   - Automatic model loading from HuggingFace
   - Supports bge-small, nomic-embed, gte-small, etc.

2. **MLXChatProvider.swift** - Local chat inference  
   - Actor-based thread safety
   - System prompts and temperature control
   - Supports Llama-3.1, Qwen, Phi-3.5, etc.

3. **CLIMLIntegration.swift** - Hybrid local/cloud orchestrator
   - Local-first with cloud fallback
   - Automatic model switching
   - Codebase indexing with embeddings
   - Hybrid search (FTS5 + vec0)

### 📋 Architecture (Designed, Not Yet Linked)

```
anigma-cli
├── MLXEmbeddingProvider ← Works in isolation
├── MLXChatProvider      ← Works in isolation  
├── CLIMLIntegration     ← Works with conditional compilation
└── [Build Error: Cmlx module not found]
```

## Immediate Next Steps

1. **Resolve Cmlx Module Linking**
   - Add `mlx-swift` as top-level dependency
   - Test build with explicit MLX product imports
   - Verify symbols are available

2. **Alternative: ML Worker Integration**
   - Use existing `ml-worker` executable
   - Shell out for embeddings/chat
   - Clean IPC boundary

3. **Test End-to-End**
   - Load embedding model
   - Generate embeddings
   - Index codebase
   - Hybrid search

## Performance Targets (When Working)

| Operation | Target | Hardware |
|-----------|--------|----------|
| Embed (bge-small) | 150-200 texts/s | M1 Pro |
| Chat (Qwen-4B) | 30-40 tok/s | M1 Pro |
| Hybrid Search | <50ms p95 | 100K chunks |

## Workaround for Now

Use cloud providers for embeddings:
- OpenAI `text-embedding-3-small`
- Cohere embeddings  
- Voyage AI code embeddings

Local MLX will be enabled once module linking is resolved.

---

**Status**: ⚠️ **Blocked on Module Linking**  
**Last Updated**: 2026-01-11  
**Next Action**: Add mlx-swift as top-level dependency OR use ml-worker subprocess

