# Anigma CLI - Quick Start Guide

## 🚀 Build & Run

```bash
# Build the CLI
swift build --product anigma-cli

# Run commands
.build/debug/anigma-cli --help
```

## 📦 What's Implemented

### ✅ ML Backends (Fully Working)
1. **MLX Backend** - Python subprocess integration
2. **llama.cpp Backend** - Native binary integration  
3. **Hybrid Provider** - Auto-selects best backend

### ✅ Database (Fully Working)
- FTS5 full-text search
- Vector embeddings storage
- Run/step tracking
- Hybrid retrieval

### ✅ Commands (Ready to Test)
- `init` - Onboarding with provider setup
- `index` - Codebase indexing
- `search` - Semantic search
- `chat` - Interactive session (stub)

## 🧪 Testing the ML Backends

### Test MLX Backend
```bash
# 1. Install MLX (macOS Apple Silicon only)
pip3 install mlx mlx-lm

# 2. Verify installation
python3 -c "import mlx.core; import mlx.nn; print('MLX ready')"

# 3. Test via CLI
.build/debug/anigma-cli init
# Select "Download local models (MLX)"
```

### Test llama.cpp Backend
```bash
# 1. Install llama.cpp
brew install llama.cpp
# Or build from source: https://github.com/ggerganov/llama.cpp

# 2. Verify binaries
which llama-cli llama-embedding

# 3. Download a GGUF model
mkdir -p ~/.cache/anigma-cli/models
cd ~/.cache/anigma-cli/models
curl -L -O https://huggingface.co/TheBloke/all-MiniLM-L6-v2-GGUF/resolve/main/all-MiniLM-L6-v2.Q4_K_M.gguf

# 4. Test via CLI
.build/debug/anigma-cli init
# Select "Use existing local model"
```

### Test Fallback Mode (No Dependencies)
```bash
# Works without MLX or llama.cpp
.build/debug/anigma-cli init
# Uses hash-based embeddings for development
```

## 🔧 Environment Variables

```bash
# Custom Python with MLX
export PYTHON=/opt/homebrew/bin/python3

# Custom llama.cpp path
export LLAMA_CPP_PATH=/usr/local/bin

# Custom model cache
export ANIGMA_MODEL_CACHE=~/my-models
```

## 📂 File Structure

```
Packages/AnigmaCLI/
├── Sources/
│   ├── AnigmaCLICore/        # Foundation types
│   ├── LocalInference/        # MLX/llama.cpp backends
│   ├── CloudProviders/        # OpenAI, Anthropic, etc.
│   └── Executable/            # CLI commands
├── Database/                  # SQLite + FTS5 + vectors
├── ML/                        # Model management
├── Onboarding/                # First-run setup
├── Indexing/                  # Codebase digestion
└── Tests/                     # Unit tests

Key Files:
- ML/NativeMLXBridge.swift          → MLX integration
- ML/NativeLlamaCppBridge.swift     → llama.cpp integration
- ML/ModelManager.swift             → Downloads & caching
- Database/CLIDatabaseActor.swift   → SQLite + FTS5
- Onboarding/OnboardingFlow.swift   → First-run setup
```

## 🎯 Common Tasks

### Add a New Cloud Provider
1. Create `Sources/CloudProviders/YourProviderChatProvider.swift`
2. Implement `ChatProvider` protocol
3. Add to `CloudProviderRegistry.swift`
4. Add to onboarding options

### Add a New Model
1. Update `ModelManager.swift` → `downloadModel()`
2. Add model spec to `recommendedModels()`
3. Test download and loading

### Modify Database Schema
1. Update `CLIDatabaseActor.swift` → `setupDatabase()`
2. Increment schema version
3. Add migration in `migrateIfNeeded()`

## 🐛 Troubleshooting

### MLX Not Found
```bash
# Check Python installation
which python3
python3 -c "import mlx.core"

# Install MLX
pip3 install mlx mlx-lm

# Set custom Python path
export PYTHON=/path/to/python3
```

### llama.cpp Not Found
```bash
# Install via Homebrew
brew install llama.cpp

# Or set custom path
export LLAMA_CPP_PATH=/path/to/llama-cli

# Verify binaries
llama-cli --version
llama-embedding --help
```

### Build Errors
```bash
# Clean build
swift package clean
swift build --product anigma-cli

# Check Swift version (need 5.9+)
swift --version

# Update dependencies
swift package update
```

### Database Issues
```bash
# Check database location
ls -la ~/.local/share/anigma-cli/

# Reset database (WARNING: deletes data)
rm -rf ~/.local/share/anigma-cli/cli.db*

# Re-initialize
.build/debug/anigma-cli init
```

## 📊 Performance Tips

### Faster Indexing
- Use MLX on Apple Silicon (fastest)
- Use llama.cpp with quantized models (good balance)
- Increase batch size in `CLIIndexManager`

### Reduce Memory Usage
- Use smaller embedding models (MiniLM-L6-v2)
- Use quantized GGUF models (Q4_K_M)
- Limit concurrent embeddings

### Faster Search
- Create FTS5 indexes on large codebases
- Use lexical search first, then vector search
- Limit result count

## 🔬 Development Workflow

```bash
# 1. Make changes
vim Packages/AnigmaCLI/ML/NativeMLXBridge.swift

# 2. Build
swift build --product anigma-cli

# 3. Test manually
.build/debug/anigma-cli init

# 4. Run tests
swift test --filter AnigmaCLITests

# 5. Check with governance
./Scripts/harmonia.sh swift6
./Scripts/harmonia.sh security
```

## 📚 Key Documentation

- `STATUS_SUMMARY.md` - Overall project status
- `ML_INTEGRATION_STATUS.md` - ML backend details
- `COMPLETE_INTEGRATION_STATUS.md` - Component checklist
- `BUILD_STATUS.md` - Build configuration

## 🤝 Contributing

1. Check `STATUS_SUMMARY.md` for current priorities
2. Pick a task from "Next Steps" section
3. Follow Swift 6 concurrency guidelines
4. Add tests for new features
5. Update documentation

## ⚡ Quick Commands

```bash
# Full rebuild
swift package clean && swift build --product anigma-cli

# Run with verbose logging
.build/debug/anigma-cli --verbose init

# Test a specific component
swift test --filter MLXBackendTests

# Profile memory usage
leaks --atExit -- .build/debug/anigma-cli index .

# Check binary size
ls -lh .build/debug/anigma-cli

# Create release build
swift build --product anigma-cli -c release
```

---

**Last Updated:** 2026-01-11  
**Build Status:** ✅ Clean (0 errors, 0 warnings)  
**Ready For:** Integration testing with real models
