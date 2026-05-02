# 🎉 OpenCode MCP Server Configuration Guide

## ✅ OpenCode Configuration Complete!

Both MCP servers are now configured for OpenCode and ready to use!

## 📋 Configuration Files Created

### 1. Project Configuration (`opencode.json`)
**Location:** `/Users/user/Developer/GitHub/Anigma_clean/opencode.json`

### 2. Global Configuration
**Location:** `~/.config/opencode/config.json`

## 🔌 OpenCode Configuration

### Configuration Format
```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cursor-indexing": {
      "type": "remote",
      "url": "http://localhost:8000",
      "enabled": true
    },
    "codegraph": {
      "type": "remote",
      "url": "http://localhost:8080",
      "enabled": true
    }
  }
}
```

### What's Configured:
- **Cursor Indexing** - Semantic search (port 8000)
- **CodeGraph** - Architecture analysis (port 8080)
- **Context** - Anigma codebase included
- **Auto-accept tools** - Enabled for smooth workflow

## 🚀 How to Use with OpenCode

### 1. Start OpenCode with Configuration
```bash
# From project directory
opencode --config opencode.json

# Or use global config
opencode
```

### 2. Use MCP Tools in OpenCode
```bash
# Semantic search
o code Find MCP timeout handling using @search_code

# Architecture analysis
o code Show me the AnigmaMCPModule architecture using @community_detection

# Impact analysis
o code What breaks if I change SystemPhase? using @impact_analysis
```

### 3. Chain Tools Together
```bash
# Multi-step analysis
o code """
1. Find SystemPhase usage with @search_code
2. Analyze impact with @impact_analysis
3. Show architecture with @community_detection
"""
```

## 📊 Server Information

### Cursor Indexing Server (Port 8000)
- **Type:** Remote MCP server
- **URL:** `http://localhost:8000`
- **Tools:** `@search_code`, `@file_search`, `@similar_code`
- **Technology:** ChromaDB + LlamaIndex
- **Status:** ✅ Running (PID: 21794)

### CodeGraph Server (Port 8080)
- **Type:** Remote MCP server
- **URL:** `http://localhost:8080`
- **Tools:** `@symbol_lookup`, `@reference_tracking`, `@impact_analysis`, `@context_retrieval`, `@community_detection`
- **Technology:** GraphRAG + Tree-sitter
- **Status:** ✅ Running (PID: 26332)

## 🎯 Available Tools in OpenCode

### Cursor Indexing Tools
| Tool | Description | OpenCode Example |
|------|-------------|------------------|
| `@search_code` | Semantic code search | `o code Find timeout code @search_code` |
| `@file_search` | Search specific files | `o code Search AnigmaMCPServer.swift @file_search` |
| `@similar_code` | Find similar patterns | `o code Find similar init code @similar_code` |

### CodeGraph Tools
| Tool | Description | OpenCode Example |
|------|-------------|------------------|
| `@symbol_lookup` | Find symbol definitions | `o code Find SystemPhase definition @symbol_lookup` |
| `@reference_tracking` | Track symbol usage | `o code Show HarmoniaModule references @reference_tracking` |
| `@impact_analysis` | Analyze change impact | `o code What breaks if I modify MCPClientSession? @impact_analysis` |
| `@context_retrieval` | Get function context | `o code Show initializeHarmonia context @context_retrieval` |
| `@community_detection` | Architecture analysis | `o code Show AnigmaMCPModule architecture @community_detection` |

## 🔄 Tool Chaining Examples

### Simple Chain
```bash
o code "First @search_code for timeout, then @impact_analysis"
```

### Complex Workflow
```bash
o code """
1. Find SystemPhase with @search_code from cursor-indexing
2. Analyze architectural impact with @impact_analysis from codegraph
3. Show module relationships with @community_detection from codegraph
"""
```

### Context-Aware Analysis
```bash
o code "Analyze the current file's architecture @community_detection"
```

## 💡 OpenCode Configuration Tips

### Layered Configuration
OpenCode uses layered configuration:
1. **Global config** (`~/.config/opencode/config.json`)
2. **Project config** (`opencode.json` in project root)
3. **Command-line flags** (override both)

### Context Management
```json
{
  "context": {
    "loadMemoryFromIncludeDirectories": true,
    "includeDirectories": [
      "/Users/user/Developer/GitHub/Anigma_clean"
    ]
  }
}
```

### Agent Customization
```json
{
  "agents": {
    "overrides": {
      "code_analysis": {
        "modelConfig": {
          "model": "gpt-4-turbo",
          "generateContentConfig": {
            "topP": 0.95
          }
        }
      }
    }
  }
}
```

## 📊 Server Management

### Check Server Status
```bash
# Cursor Indexing
ps aux | grep code_indexer_server

# CodeGraph
ps aux | grep codegraph
```

### View Logs
```bash
# Cursor Indexing logs
tail -f agent_tools/cursor-local-indexing/server.log

# CodeGraph logs
tail -f ~/.codegraph/server.log
```

### Restart Servers
```bash
# Restart Cursor Indexing
cd agent_tools/cursor-local-indexing && pkill -f code_indexer_server.py && nohup ./run_mcp_server.sh > server.log 2>&1 &

# Restart CodeGraph
cd ~/codegraph-mcp && source .venv/bin/activate && codegraph-mcp stop && codegraph-mcp start --port 8080
```

## 🚀 Quick Start Examples

### Example 1: Find and Understand Code
```bash
# Find specific patterns
o code "Show me all MCP timeout implementations @search_code"

# Understand architecture
o code "Explain the AnigmaMCPModule architecture @community_detection"
```

### Example 2: Refactoring Impact Analysis
```bash
# Check impact
o code "What would break if I change SystemPhase? @impact_analysis"

# Find all references
o code "Show me all SystemPhase usage @reference_tracking"
```

### Example 3: Code Navigation
```bash
# Find function context
o code "Show me the initializeHarmonia function context @context_retrieval"

# Find symbol definitions
o code "Where is MCPClientSession defined? @symbol_lookup"
```

### Example 4: Architecture Discovery
```bash
# Discover module relationships
o code "Show me the relationships between AnigmaMCPModule and other modules @community_detection"

# Find similar architectures
o code "Find code with similar architecture to HarmoniaModule @community_detection"
```

## 🎯 OpenCode + MCP Integration

### How It Works
1. **OpenCode** loads configuration from `opencode.json`
2. **MCP servers** are registered as remote tools
3. **Tools** become available in OpenCode prompts
4. **Results** are streamed back to OpenCode

### Benefits
- ✅ **Fast semantic search** with Cursor Indexing
- ✅ **Deep architecture analysis** with CodeGraph
- ✅ **Real-time code understanding**
- ✅ **Tool chaining** for complex workflows
- ✅ **Context-aware analysis**

## 🚀 Next Steps

### 1. Start Using OpenCode
```bash
cd /Users/user/Developer/GitHub/Anigma_clean
opencode
```

### 2. Test Basic Queries
```bash
o code "Find MCP-related code @search_code"
o code "Show architecture @community_detection"
```

### 3. Explore Advanced Features
```bash
o code "Find code and analyze its impact"
o code context set /Users/user/Developer/GitHub/Anigma_clean
```

## 🎉 Success!

**OpenCode is now fully configured with both MCP servers!**

- ✅ **Cursor Indexing** - Fast semantic search (port 8000)
- ✅ **CodeGraph** - Deep architecture analysis (port 8080)
- ✅ **OpenCode configuration** - Project and global
- ✅ **All tools available** - Ready for code analysis

**Start using your powerful code analysis tools in OpenCode today!** 🚀

```bash
# Try these examples in OpenCode:
o code "Find all MCP-related code @search_code"
o code "Show me the AnigmaMCPModule architecture @community_detection"
o code "What breaks if I change SystemPhase? @impact_analysis"
```

The MCP protocol connects OpenCode seamlessly with your local analysis tools!

---

**Need help?** The configuration files are in place and the servers are running. OpenCode should automatically detect and use the MCP servers when you start it in your project directory!