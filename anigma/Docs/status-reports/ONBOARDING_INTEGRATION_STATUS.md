# Anigma CLI Onboarding & Cloud Provider Integration Status

## Overview
This document tracks the implementation of the onboarding flow and cloud provider integrations for anigma-cli.

## ✅ Completed Components

### 1. Cloud Provider Implementations
**Location:** `Packages/AnigmaCLI/Providers/CloudProviders.swift`

**Implemented Providers:**
- ✅ OpenAI (chat + embeddings)
- ✅ Anthropic Claude (chat only)
- ✅ DeepSeek (chat, OpenAI-compatible API)
- ✅ Google Gemini (chat, native API)

**Features:**
- Unified `CloudProvider` protocol
- Request/Response types with usage tracking
- Error handling and validation
- API key authentication
- Streaming support scaffolding
- `CloudProviderFactory` for dynamic instantiation

**Pending:**
- ✅ Basic streaming (returns full response)
- ⏳ True SSE/streaming implementation
- ⏳ Vercel AI provider
- ⏳ Hugging Face provider
- ⏳ Ollama Cloud provider
- ⏳ Amazon Bedrock provider

### 2. Onboarding Flow
**Location:** `Packages/AnigmaCLI/Onboarding/OnboardingFlow.swift`

**Implemented Features:**
- ✅ System benchmarking (CPU, RAM, GPU detection)
- ✅ Model tier recommendations (heavy/medium/light/minimal)
- ✅ Interactive provider API key setup
- ✅ Secure API key storage (.env file)
- ✅ Local model recommendations based on system
- ✅ Model selection with auto-download flags
- ✅ Configuration persistence (JSON)
- ✅ Codebase analysis integration
- ✅ Beautiful CLI banner and progress indicators

**System Benchmark Features:**
- CPU core detection
- Physical memory detection
- GPU availability (macOS Metal detection)
- Automatic tier assignment:
  - **Heavy:** 64GB+ RAM + GPU → 70B models
  - **Medium:** 32GB+ RAM → 13B-30B models
  - **Light:** 16GB+ RAM → 7B-8B models
  - **Minimal:** <16GB RAM → 3B models

**Provider Setup Flow:**
- Detects existing environment variables
- Interactive API key prompts with prefix validation
- Stores keys in `~/.anigma-cli/.env`
- Supports: OpenAI, Anthropic, DeepSeek, Gemini, Vercel, HF, Ollama Cloud

**Model Recommendations:**
- Tier-based model selection
- RAM estimation per model
- Auto-download flags for recommended models
- Download URL references
- Models include:
  - Chat: Llama 3.1 (8B/70B), DeepSeek Coder 33B, Phi 3.5 Mini
  - Code: Qwen 2.5 7B Coder
  - Embeddings: All-MiniLM-L6-v2

**Pending:**
- ⏳ Actual model download implementation
- ⏳ Keychain integration (macOS) for secure API key storage
- ⏳ Model verification after download
- ⏳ Background indexing during onboarding

### 3. CLI Commands
**Location:** `Packages/AnigmaCLI/Executable/Commands.swift`

**Implemented Commands:**

#### `anigma-cli init`
- ✅ Full onboarding flow integration
- ✅ Force re-initialization flag (`--force`)
- ✅ Non-interactive mode (`--non-interactive`)
- ✅ Workspace path configuration
- ✅ Configuration check and creation
- ✅ Database initialization
- ✅ Results summary display

#### `anigma-cli chat`
- ✅ Interactive chat loop
- ✅ Configuration loading
- ✅ Component initialization (database, ML, providers)
- ✅ Initial message flag (`--message`)
- ✅ Model selection (`--model`)
- ✅ Command system (`/search`, `/explain`, `/refactor`, `/quit`)
- ✅ Error handling and display

**Chat Commands:**
- ✅ `/search <query>` - Semantic codebase search
- ⏳ `/explain <file>` - File/concept explanation (scaffold)
- ⏳ `/refactor <target>` - Refactoring suggestions (scaffold)
- ⏳ `/index` - Trigger indexing (scaffold)
- ✅ `/help` - Command help
- ✅ `/quit` - Exit chat

#### `anigma-cli mcp-server`
- ✅ Server mode skeleton
- ✅ Configuration check
- ⏳ MCP protocol implementation

**Pending:**
- ⏳ Full MCP server stdio/http modes
- ⏳ Tool execution integration
- ⏳ Streaming chat responses
- ⏳ Context management

### 4. Existing Infrastructure Integration
**Leveraged Components:**
- ✅ `CodebaseDigestor` - Analyzes project structure, languages, build system
- ✅ `ProviderRegistry` - Discovers local/cloud/CLI providers
- ✅ `CLIMLIntegration` - ML worker integration, embeddings, chat
- ✅ `CLIDatabaseActor` - SQLite database with FTS5 + vector support
- ✅ `CLIIndexManager` - Codebase chunk indexing
- ✅ `CLIHybridRetrieval` - Lexical + vector search

## 📁 File Structure

```
Packages/AnigmaCLI/
├── Core/                        # Existing core types
├── Database/                    # Database layer
│   ├── CLIDatabaseActor.swift
│   ├── CLIIndexManager.swift
│   └── CLIHybridRetrieval.swift
├── Onboarding/                  # NEW
│   ├── CodebaseDigestor.swift   # Existing (codebase analysis)
│   └── OnboardingFlow.swift     # NEW (main onboarding)
├── Providers/                   # Provider infrastructure
│   ├── ProviderRegistry.swift   # Existing (provider discovery)
│   ├── CLIMLIntegration.swift   # Existing (ML integration)
│   └── CloudProviders.swift     # NEW (cloud APIs)
├── Executable/
│   ├── main.swift               # Existing (entry point)
│   └── Commands.swift           # NEW (init/chat/mcp commands)
├── Eventing/                    # Event stream
├── Governance/                  # Policy gates
├── Orchestrator/                # Task orchestration
└── Router/                      # Route selection
```

## 🏗️ Architecture

### Onboarding Flow Sequence

```
anigma-cli init
    │
    ├─→ 1. Print Banner
    │
    ├─→ 2. System Benchmark
    │     ├─ CPU cores (ProcessInfo)
    │     ├─ RAM detection (ProcessInfo.physicalMemory)
    │     ├─ GPU detection (Metal on macOS)
    │     └─ Tier assignment
    │
    ├─→ 3. Provider Setup
    │     ├─ Check existing env vars
    │     ├─ Interactive API key prompts
    │     ├─ Validate key prefixes
    │     └─ Store in ~/.anigma-cli/.env
    │
    ├─→ 4. Model Recommendations
    │     ├─ Tier-based model list
    │     ├─ Display with RAM requirements
    │     ├─ Auto-download flagging
    │     └─ User confirmation
    │
    ├─→ 5. Codebase Analysis
    │     ├─ Scan files (CodebaseDigestor)
    │     ├─ Detect build system
    │     ├─ Extract dependencies
    │     ├─ Identify modules
    │     └─ Generate explanation
    │
    ├─→ 6. Index Prompt
    │     └─ Optional: trigger indexing
    │
    └─→ 7. Save Configuration
          ├─ Write ~/.anigma-cli/config.json
          └─ Display summary
```

### Chat Flow Sequence

```
anigma-cli chat
    │
    ├─→ 1. Check Initialization
    │     └─ Verify ~/.anigma-cli/config.json
    │
    ├─→ 2. Load Configuration
    │     ├─ Providers
    │     ├─ Local models
    │     └─ Benchmark summary
    │
    ├─→ 3. Initialize Components
    │     ├─ Database (CLIDatabaseActor)
    │     ├─ Provider Registry
    │     ├─ Index Manager
    │     ├─ Hybrid Retrieval
    │     └─ ML Integration
    │
    └─→ 4. Interactive Loop
          ├─ Read user input
          ├─ Handle /commands
          ├─ Send to MLIntegration.chat()
          │   ├─ Try local ML worker
          │   └─ Fallback to cloud provider
          └─ Display response
```

## 🧪 Testing Strategy

### Manual Testing Checklist

- [ ] `anigma-cli init` - First run
  - [ ] Banner displays
  - [ ] System benchmark runs
  - [ ] Provider setup prompts
  - [ ] Model recommendations display
  - [ ] Codebase analysis completes
  - [ ] Config saves to `~/.anigma-cli/config.json`

- [ ] `anigma-cli init --force` - Re-initialization
  - [ ] Warns about existing config
  - [ ] Re-runs all steps

- [ ] `anigma-cli init --non-interactive` - Automated setup
  - [ ] Skips prompts
  - [ ] Uses defaults
  - [ ] Saves minimal config

- [ ] `anigma-cli chat` - Interactive mode
  - [ ] Loads configuration
  - [ ] Displays provider/model info
  - [ ] Accepts user messages
  - [ ] Calls ML integration
  - [ ] Displays responses

- [ ] `anigma-cli chat --message "Hello"` - Single message
  - [ ] Sends message
  - [ ] Displays response
  - [ ] Exits

- [ ] Chat commands
  - [ ] `/search <query>` - Searches codebase
  - [ ] `/help` - Shows help
  - [ ] `/quit` - Exits

### Integration Testing

- [ ] Provider API calls
  - [ ] OpenAI chat request
  - [ ] Anthropic chat request
  - [ ] DeepSeek chat request
  - [ ] Google Gemini chat request
  - [ ] Error handling for missing keys

- [ ] Database operations
  - [ ] Database creation
  - [ ] Schema initialization
  - [ ] Index creation
  - [ ] Hybrid search

- [ ] ML Worker integration
  - [ ] Local inference call
  - [ ] Embedding generation
  - [ ] Cloud fallback

## 🐛 Known Issues

1. **Build Dependencies:**
   - Need to verify all imports resolve correctly
   - May need to add missing targets to Package.swift

2. **API Key Storage:**
   - Currently using `.env` file (plain text)
   - Should migrate to macOS Keychain for production

3. **Model Download:**
   - Download logic not implemented
   - Placeholder messages shown

4. **Streaming:**
   - Cloud providers return full response, not streaming
   - Need SSE/chunked response handling

5. **MCP Server:**
   - Protocol implementation pending
   - Stdio/HTTP modes scaffolded only

## 🔄 Next Steps

### High Priority
1. ✅ Complete cloud provider implementations
2. ✅ Integrate onboarding into main CLI
3. ⏳ Test full init → chat flow
4. ⏳ Fix any build errors
5. ⏳ Implement model download

### Medium Priority
6. ⏳ Add Keychain API key storage (macOS)
7. ⏳ Implement true streaming responses
8. ⏳ Complete MCP server protocol
9. ⏳ Add remaining cloud providers (Vercel, HF, Ollama Cloud)
10. ⏳ Background indexing during onboarding

### Low Priority
11. ⏳ `/explain` command implementation
12. ⏳ `/refactor` command implementation
13. ⏳ Advanced model management (update, remove)
14. ⏳ Multi-workspace support
15. ⏳ Chat history persistence

## 📊 Progress Summary

| Component | Status | Files | Lines |
|-----------|--------|-------|-------|
| Cloud Providers | ✅ Core Done | 1 | ~600 |
| Onboarding Flow | ✅ Core Done | 1 | ~500 |
| CLI Commands | ✅ Core Done | 1 | ~400 |
| Integration Tests | ⏳ Pending | 0 | 0 |
| Documentation | ✅ This file | 1 | ~400 |

**Total Progress:** ~70% of onboarding + provider infrastructure complete

## 🚀 Usage Examples

### First-time setup:
```bash
# Initialize with full onboarding
anigma-cli init

# Follow prompts:
# 1. System benchmark runs automatically
# 2. Enter API keys (or skip)
# 3. Confirm model downloads
# 4. Codebase analysis runs
# 5. Configuration saved
```

### Quick non-interactive setup:
```bash
anigma-cli init --non-interactive --workspace /path/to/project
```

### Start coding:
```bash
# Interactive chat
anigma-cli chat

> How does authentication work in this codebase?
Assistant: [response using RAG + LLM]

> /search JWT token
[Results from semantic search]

> /quit
```

### Single query:
```bash
anigma-cli chat --message "Explain the database schema" --model llama-3.1-8b-instruct
```

## 📝 Configuration File Format

**Location:** `~/.anigma-cli/config.json`

```json
{
  "benchmark": {
    "availableRAM": 32,
    "cpuCores": 10,
    "gpuAvailable": true,
    "tier": "Light (7B-8B models)",
    "totalRAM": 64
  },
  "localModels": [
    "llama-3.1-8b-instruct",
    "qwen-2.5-7b-coder",
    "all-minilm-l6-v2"
  ],
  "providers": [
    "OpenAI",
    "Anthropic"
  ],
  "version": 1
}
```

**Environment File:** `~/.anigma-cli/.env`

```bash
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
DEEPSEEK_API_KEY=sk-...
```

---

**Last Updated:** 2026-01-10  
**Status:** Ready for integration testing and refinement
