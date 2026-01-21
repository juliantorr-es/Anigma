# Anigma CLI Installation & Usage Guide

## Quick Install

### Build from Source

```bash
# 1. Clone the repository (if you haven't already)
cd /Users/user/Developer/GitHub/Anigma

# 2. Build the CLI
swift build -c release --product anigma-cli

# 3. Create symlink for easy access
sudo ln -sf $(pwd)/.build/release/anigma-cli /usr/local/bin/anigma

# 4. Verify installation
anigma --version
```

## First Launch - Onboarding

On first launch, Anigma CLI will guide you through setup:

```bash
# Start the onboarding process
anigma init
```

The onboarding will:
1. **Choose AI Provider** - Select from DeepSeek, OpenAI, Anthropic, Google, etc.
2. **Enter API Key** - Securely store your API credentials
3. **System Benchmark** - Test hardware capabilities
4. **Model Recommendations** - Suggest optimal local models
5. **Download Models** - Install recommended MLX/llama.cpp models
6. **Index Codebase** - Build vector embeddings for RAG
7. **Maturity Assessment** - Analyze project and suggest improvements

## Basic Usage

### Interactive Chat
```bash
# Start interactive chat session
anigma chat

# Chat with codebase context (RAG-powered)
anigma chat --rag

# Use specific model
anigma chat --model deepseek-chat
anigma chat --model local-mlx-llama-3.1-8b
```

### Codebase Operations
```bash
# Index current directory
anigma index .

# Search codebase semantically
anigma search "authentication logic"

# Run maturity assessment
anigma assess

# Apply suggested improvements
anigma improve --interactive
```

### Model Management
```bash
# List available models
anigma models list

# Download a model
anigma models download llama-3.1-8b-instruct

# Check model status
anigma models status
```

### Configuration
```bash
# View current config
anigma config show

# Change provider
anigma config set-provider anthropic

# Update API key
anigma config set-key
```

## Directory Structure

After installation, Anigma creates:

```
~/.anigma/
├── config.json          # Provider settings, API keys
├── anigma.db           # SQLite database with FTS5 + vector storage
├── models/             # Downloaded local models
│   ├── mlx/           # MLX models
│   └── gguf/          # llama.cpp models
├── cache/             # Embeddings cache
└── logs/              # Runtime logs
```

## Requirements

- **macOS 14+** (for Metal/MLX support)
- **Swift 5.9+**
- **Xcode 15+** (for building)
- **8GB+ RAM** (16GB+ recommended for local models)
- **10GB+ disk space** (for models)

## Optional Dependencies

### For Local Inference (Recommended)

1. **MLX** (Apple Silicon native):
   ```bash
   pip install mlx
   ```

2. **llama.cpp** (CPU/GPU):
   ```bash
   brew install llama.cpp
   ```

### For Development

```bash
# Install all dev dependencies
swift package resolve
```

## Troubleshooting

### Build Errors
```bash
# Clean build
swift package clean
rm -rf .build

# Rebuild
swift build -c release --product anigma-cli
```

### Database Issues
```bash
# Reset database (will re-index)
rm ~/.anigma/anigma.db
anigma init
```

### Model Download Failures
```bash
# Clear cache and retry
rm -rf ~/.anigma/cache
anigma models download <model-name>
```

## Advanced Usage

### Custom Model Paths
```bash
# Use custom MLX model
anigma chat --model-path ~/models/my-custom-model

# Use custom GGUF model
anigma chat --model-path ~/models/model.gguf --backend llama-cpp
```

### RAG Configuration
```bash
# Adjust RAG parameters
anigma chat --rag --top-k 10 --similarity-threshold 0.7

# Re-index with specific extensions
anigma index . --extensions swift,md,txt
```

### Batch Operations
```bash
# Process multiple files
anigma analyze src/**/*.swift --output report.json

# Batch code improvements
anigma improve --auto --target src/
```

## Integration with Existing Tools

### VS Code
Add to `.vscode/tasks.json`:
```json
{
  "label": "Anigma Chat",
  "type": "shell",
  "command": "anigma chat --rag"
}
```

### Git Hooks
Add to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
anigma assess --quick --exit-on-critical
```

## Next Steps

1. Complete onboarding: `anigma init`
2. Try interactive chat: `anigma chat`
3. Index your project: `anigma index .`
4. Explore improvements: `anigma assess`

For more help: `anigma --help` or visit the documentation.
