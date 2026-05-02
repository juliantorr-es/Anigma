# 🚀 MCP Tools Cheat Sheet

## 🔌 Connecting Servers

### Add to Gemini CLI
```bash
gemini mcp add codegraph --url http://localhost:8080 --name "CodeGraph"
gemini mcp add cursor --url http://localhost:8000 --name "Cursor Indexing"
```

### List Servers
```bash
gemini mcp list
```

### Test Connection
```bash
gemini mcp test codegraph
```

## 🔍 CodeGraph Tools (Port 8080)

### Architecture Analysis
```bash
gemini "Show architecture of AnigmaMCPModule using @community_detection"
```

### Impact Analysis
```bash
gemini "What breaks if I change SystemPhase? Use @impact_analysis"
```

### Symbol Lookup
```bash
gemini "Find all references to HarmoniaModule using @symbol_lookup"
```

### Context Retrieval
```bash
gemini "Show me the context of initializeHarmonia using @context_retrieval"
```

## 🔎 Cursor Indexing Tools (Port 8000)

### Semantic Search
```bash
gemini "Find MCP timeout handling code using @search_code"
```

### Similar Code
```bash
gemini "Find code like HarmoniaModule init using @similar_code"
```

### File Search
```bash
gemini "Search for timeout in AnigmaMCPServer.swift using @file_search"
```

## 🔗 Chaining Tools

### Simple Chain
```bash
gemini "First @search_code for timeout, then @impact_analysis on results"
```

### Complex Workflow
```bash
gemini """
1. Find SystemPhase with @search_code
2. Analyze impact with @impact_analysis  
3. Show architecture with @community_detection
"""
```

## 🎛️ Configuration

### Set Default Server
```bash
gemini config set defaultMcpServer codegraph
```

### Enable Caching
```bash
gemini config set mcp.cache.enabled true
```

### Parallel Execution
```bash
gemini config set mcp.parallelTools true
```

## 📊 Server Management

### Start Servers
```bash
# CodeGraph (port 8080)
cd ~/codegraph-mcp && source .venv/bin/activate
codegraph-mcp start --port 8080

# Cursor Indexing (port 8000) - already running!
```

### Check Status
```bash
gemini mcp status codegraph
```

### Refresh Tools
```bash
gemini mcp refresh codegraph
```

### List Available Tools
```bash
gemini mcp tools
```

## 💡 Common Patterns

### Find and Analyze
```bash
gemini "Find all MCP-related code and analyze its architecture"
```

### Refactoring Impact
```bash
gemini "What's the impact of renaming MCPClientSession?"
```

### Architecture Discovery
```bash
gemini "Show me the module relationships in AnigmaMCPModule"
```

### Code Navigation
```bash
gemini "Take me to the HarmoniaModule initialization code"
```

## 🚀 Quick Examples

### Example 1: Understanding a Module
```bash
gemini "Explain AnigmaMCPModule architecture and show key dependencies"
```

### Example 2: Finding Bugs
```bash
gemini "Find potential issues in MCP timeout handling across the codebase"
```

### Example 3: Refactoring Preparation
```bash
gemini "Analyze the impact of splitting HarmoniaModule into smaller components"
```

### Example 4: Learning the Codebase
```bash
gemini "Show me the most important files in the AnigmaMCPModule and their relationships"
```

## 🎯 Pro Tips

### Set Context First
```bash
gemini context set /Users/user/Developer/GitHub/Anigma_clean/anigma
```

### Use Aliases
```bash
# In your config:
"toolAliases": {
  "arch": "codegraph@community_detection",
  "find": "cursor@search_code",
  "impact": "codegraph@impact_analysis"
}

# Then use:
gemini "Show architecture with @arch"
```

### Save Sessions
```bash
gemini session save refactoring_analysis
gemini session load refactoring_analysis
```

### Background Mode
```bash
# Run servers in background
nohup codegraph-mcp start --port 8080 > codegraph.log 2>&1 &
```

## 🐛 Troubleshooting

### Server not found
```bash
curl -v http://localhost:8080
gemini mcp test codegraph
```

### Tools not loading
```bash
gemini mcp refresh codegraph
gemini mcp tools
```

### Slow responses
```bash
gemini config set mcp.timeout 60
gemini config set mcp.cache.ttl 3600
```

### Permission issues
```bash
gemini mcp trust codegraph trusted
```

## 📚 Quick Reference

| Command | Description |
|---------|-------------|
| `gemini mcp add <name> --url <url>` | Add MCP server |
| `gemini mcp list` | List all servers |
| `gemini mcp tools` | List available tools |
| `gemini "query with @tool"` | Use MCP tool |
| `gemini mcp refresh <name>` | Refresh tool definitions |
| `gemini mcp test <name>` | Test server connection |
| `gemini config set defaultMcpServer <name>` | Set default server |

## 🎉 Power Combinations

### 1. Find + Analyze
```bash
gemini "Find timeout code and analyze its impact"
```

### 2. Search + Architecture
```bash
gemini "Search for MCP modules and show their architecture"
```

### 3. Context + References
```bash
gemini "Show me HarmoniaModule context and all its references"
```

### 4. Impact + Similar
```bash
gemini "Analyze impact of SystemPhase changes and find similar patterns"
```

**Remember:** Both servers work together seamlessly! 🚀