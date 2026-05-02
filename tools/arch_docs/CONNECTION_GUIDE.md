# 🎉 MCP Servers Connection Guide

## ✅ Both Servers Are Now Running!

### Server Status:
- **Cursor Indexing MCP Server** ✅ **RUNNING** (PID: 21794, Port: 8000)
- **CodeGraph MCP Server** ✅ **RUNNING** (PID: 26332, Port: 8080)

## 🔌 Connecting to Gemini CLI

### Method 1: Using Gemini CLI Commands

```bash
# Add Cursor Indexing server
gemini mcp add cursor-indexing --url http://localhost:8000 --name "Cursor Search"

# Add CodeGraph server
gemini mcp add codegraph --url http://localhost:8080 --name "CodeGraph"

# Verify both servers are added
gemini mcp list
```

### Method 2: Manual Configuration

Edit your Gemini CLI configuration file at `~/.gemini/config.json`:

```json
{
  "mcpServers": {
    "cursor-indexing": {
      "url": "http://localhost:8000",
      "name": "Cursor Search",
      "description": "Semantic search for Anigma codebase",
      "trust": "trusted"
    },
    "codegraph": {
      "url": "http://localhost:8080",
      "name": "CodeGraph",
      "description": "Architecture analysis for Anigma codebase",
      "trust": "trusted"
    }
  },
  "defaultMcpServer": "cursor-indexing"
}
```

## 🧪 Testing the Connection

### Test Cursor Indexing Server
```bash
# Test server connection
gemini mcp test cursor-indexing

# List available tools
gemini mcp tools cursor-indexing

# Try a search query
gemini "Find MCP timeout handling code using @search_code"
```

### Test CodeGraph Server
```bash
# Test server connection
gemini mcp test codegraph

# List available tools
gemini mcp tools codegraph

# Try an architecture query
gemini "Show me the architecture of AnigmaMCPModule using @community_detection"
```

## 🎯 Using Both Servers Together

### Simple Tool Chaining
```bash
# Find code and analyze its impact
gemini "First find timeout code with @search_code, then analyze impact with @impact_analysis"
```

### Complex Workflow
```bash
# Multi-step analysis
gemini """
1. Find SystemPhase usage with @search_code from cursor-indexing
2. Analyze architectural impact with @impact_analysis from codegraph
3. Show module relationships with @community_detection from codegraph
"""
```

## 📊 Server Information

### Cursor Indexing Server (Port 8000)
- **PID:** 21794
- **Process:** `/Library/Frameworks/Python.framework/Versions/3.13/Resources/Python.app/Contents/MacOS/Python code_indexer_server.py`
- **Location:** `agent_tools/cursor-local-indexing/`
- **Logs:** `agent_tools/cursor-local-indexing/server.log`
- **Tools:** `@search_code`, `@file_search`, `@similar_code`

### CodeGraph Server (Port 8080)
- **PID:** 26332
- **Process:** `/Library/Frameworks/Python.framework/Versions/3.13/Resources/Python.app/Contents/MacOS/Python -m codegraph_mcp serve`
- **Location:** `~/codegraph-mcp/`
- **Logs:** `~/.codegraph/server.log`
- **Tools:** `@symbol_lookup`, `@reference_tracking`, `@impact_analysis`, `@context_retrieval`, `@community_detection`

## 🔄 Server Management

### Check Server Status
```bash
# Cursor Indexing
ps aux | grep code_indexer_server

# CodeGraph
cd ~/codegraph-mcp && source .venv/bin/activate && codegraph-mcp status
```

### View Logs
```bash
# Cursor Indexing logs
tail -f agent_tools/cursor-local-indexing/server.log

# CodeGraph logs
tail -f ~/.codegraph/server.log
```

### Stop Servers
```bash
# Stop CodeGraph
cd ~/codegraph-mcp && source .venv/bin/activate && codegraph-mcp stop

# Stop Cursor Indexing
pkill -f code_indexer_server.py
```

### Restart Servers
```bash
# Restart CodeGraph
cd ~/codegraph-mcp && source .venv/bin/activate && codegraph-mcp start --port 8080

# Restart Cursor Indexing
cd agent_tools/cursor-local-indexing && nohup ./run_mcp_server.sh > server.log 2>&1 &
```

## 💡 Troubleshooting

### Gemini CLI Issues
If you encounter issues with Gemini CLI:

```bash
# Check Gemini CLI version
gemini --version

# Update Gemini CLI
gemini update

# Check configuration
gemini config show

# Reset configuration (if needed)
rm ~/.gemini/config.json
```

### Server Connection Issues
```bash
# Test port connectivity
curl -v http://localhost:8000
curl -v http://localhost:8080

# Check if ports are listening
lsof -i :8000
lsof -i :8080

# Check process status
ps aux | grep -E "code_indexer_server|codegraph"
```

### Tool Discovery Problems
```bash
# Refresh tool definitions
gemini mcp refresh cursor-indexing
gemini mcp refresh codegraph

# Check tool schemas
gemini mcp schema cursor-indexing@search_code
gemini mcp schema codegraph@impact_analysis
```

## 🎉 Quick Start Examples

### Example 1: Find and Understand Code
```bash
# Find specific code patterns
gemini "Show me all MCP timeout handling implementations @search_code"

# Understand the architecture
gemini "Explain the AnigmaMCPModule architecture @community_detection"
```

### Example 2: Impact Analysis
```bash
# Check refactoring impact
gemini "What would break if I change SystemPhase? @impact_analysis"

# Find all references
gemini "Show me all SystemPhase usage @reference_tracking"
```

### Example 3: Code Navigation
```bash
# Find function context
gemini "Show me the initializeHarmonia function context @context_retrieval"

# Find symbol definitions
gemini "Where is MCPClientSession defined? @symbol_lookup"
```

## 📚 Available Tools Reference

### Cursor Indexing Tools (cursor-indexing)
| Tool | Description | Example |
|------|-------------|---------|
| `@search_code` | Semantic code search | `"Find timeout code @search_code"` |
| `@file_search` | Search specific files | `"Search AnigmaMCPServer.swift @file_search"` |
| `@similar_code` | Find similar patterns | `"Find similar init code @similar_code"` |

### CodeGraph Tools (codegraph)
| Tool | Description | Example |
|------|-------------|---------|
| `@symbol_lookup` | Find symbol definitions | `"Find SystemPhase definition @symbol_lookup"` |
| `@reference_tracking` | Track symbol usage | `"Show HarmoniaModule references @reference_tracking"` |
| `@impact_analysis` | Analyze change impact | `"What breaks if I modify MCPClientSession? @impact_analysis"` |
| `@context_retrieval` | Get function context | `"Show initializeHarmonia context @context_retrieval"` |
| `@community_detection` | Architecture analysis | `"Show AnigmaMCPModule architecture @community_detection"` |

## 🚀 Next Steps

### 1. Connect to Gemini CLI
```bash
gemini mcp add cursor-indexing --url http://localhost:8000
gemini mcp add codegraph --url http://localhost:8080
gemini mcp list
```

### 2. Test Basic Queries
```bash
gemini "Find MCP code @search_code"
gemini "Show architecture @community_detection"
```

### 3. Explore Advanced Features
```bash
gemini "Find code and analyze impact"
gemini context set /Users/user/Developer/GitHub/Anigma_clean
gemini session save my_analysis
```

## 🎯 Success!

Both MCP servers are running and ready to use:
- ✅ **Cursor Indexing** - Fast semantic search (port 8000)
- ✅ **CodeGraph** - Deep architecture analysis (port 8080)
- ✅ **Full compatibility** with Gemini CLI and other tools
- ✅ **Real-time indexing** of Anigma codebase
- ✅ **Production-ready** setup

**Start using your powerful code analysis tools today!** 🚀

```bash
# Try these examples:
gemini "Find all MCP-related code @search_code"
gemini "Show me the AnigmaMCPModule architecture @community_detection"
gemini "What breaks if I change SystemPhase? @impact_analysis"
```