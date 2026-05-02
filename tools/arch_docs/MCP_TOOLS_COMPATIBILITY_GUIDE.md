# MCP Tools Compatibility Guide

## 🎯 Yes! Both CodeGraph and Cursor Indexing are Fully Compatible with Gemini CLI and Other AI Tools

Both MCP servers use the **standard Model Context Protocol (MCP)** and can be connected to Gemini CLI, Claude Desktop, Cursor, and other MCP-compatible tools.

## 🔧 Compatibility Matrix

| Tool | CodeGraph MCP | Cursor Indexing | Gemini CLI | Claude Desktop | Cursor IDE | Continue.dev |
|------|--------------|----------------|------------|---------------|------------|-------------|
| **Protocol** | ✅ MCP | ✅ MCP | ✅ MCP | ✅ MCP | ✅ MCP | ✅ MCP |
| **Transport** | HTTP/SSE | HTTP/SSE | ✅ Both | ✅ Both | ✅ Both | ✅ Both |
| **Python** | ✅ Native | ✅ Native | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Multi-language** | ✅ 20+ | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Local LLMs** | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |

## 🚀 Connecting to Gemini CLI

### 1. Add CodeGraph MCP Server to Gemini CLI

```bash
# Add the CodeGraph server
gemini mcp add codegraph \
  --url http://localhost:8080 \
  --name "CodeGraph Anigma Server" \
  --description "Architecture analysis for Anigma codebase"

# Verify it's added
gemini mcp list
```

### 2. Add Cursor Indexing MCP Server to Gemini CLI

```bash
# Add the Cursor Indexing server
gemini mcp add cursor-indexing \
  --url http://localhost:8000 \
  --name "Cursor Semantic Search" \
  --description "Fast semantic search for Anigma codebase"

# Check available tools
gemini mcp tools
```

### 3. Using the Tools in Gemini CLI

```bash
# Use CodeGraph for architecture analysis
gemini "Analyze the architecture of AnigmaMCPModule using @impact_analysis"

# Use Cursor Indexing for semantic search
gemini "Find all references to SystemPhase using @search_code"

# Combine both tools
gemini "First search for HarmoniaModule usage with @search_code, then analyze its impact with @impact_analysis"
```

## 🎛️ Configuration Examples

### Gemini CLI Configuration (`~/.gemini/config.json`)

```json
{
  "mcpServers": {
    "codegraph": {
      "url": "http://localhost:8080",
      "name": "CodeGraph Anigma Server",
      "description": "Architecture and impact analysis",
      "trust": "trusted"
    },
    "cursor-indexing": {
      "url": "http://localhost:8000",
      "name": "Cursor Semantic Search",
      "description": "Fast code search and retrieval",
      "trust": "trusted"
    }
  },
  "defaultMcpServer": "codegraph"
}
```

### Claude Desktop Configuration (`~/.cursor/mcp.json`)

```json
{
  "mcpServers": {
    "codegraph-anigma": {
      "url": "http://localhost:8080/sse",
      "description": "CodeGraph MCP Server for architecture analysis"
    },
    "cursor-semantic": {
      "url": "http://localhost:8000/sse",
      "description": "Cursor Indexing for fast semantic search"
    }
  }
}
```

## 🔄 Tool Integration Examples

### Example 1: Architecture Analysis with CodeGraph

```bash
# Ask Gemini to analyze module relationships
gemini "Show me the architecture diagram of AnigmaMCPModule using @community_detection"

# Find all dependencies of a specific file
gemini "What are the dependencies of Sources/HarmoniaModule.swift? Use @impact_analysis"
```

### Example 2: Semantic Search with Cursor Indexing

```bash
# Find code related to a specific concept
gemini "Show me all code related to MCP timeout handling using @search_code"

# Find similar implementations
gemini "Find code similar to the HarmoniaModule initialization pattern using @search_code"
```

### Example 3: Combined Workflow

```bash
# Multi-step analysis
gemini """
1. First, find all references to SystemPhase using @search_code from cursor-indexing
2. Then analyze the impact of changing SystemPhase using @impact_analysis from codegraph
3. Finally, show me the architecture diagram of affected modules using @community_detection
"""
```

## 🛡️ Security and Trust

### Trust Levels

```bash
# Add server with specific trust level
gemini mcp add codegraph --url http://localhost:8080 --trust trusted

# Available trust levels:
# - "untrusted": Limited access, sandboxed execution
# - "trusted": Full access to configured tools
# - "system": System-level access (use with caution)
```

### Environment Variables

```bash
# Set environment variables for MCP servers
export CODEGRAPH_TOKEN="your_token_here"
export CURSOR_INDEXING_TOKEN="another_token"

# Add server with environment variables
gemini mcp add codegraph --url http://localhost:8080 --env CODEGRAPH_TOKEN
```

## 🔧 Advanced Configuration

### Multiple Projects

```json
{
  "mcpServers": {
    "codegraph-anigma": {
      "url": "http://localhost:8080",
      "projects": ["Anigma_clean"]
    },
    "codegraph-other": {
      "url": "http://localhost:8081",
      "projects": ["/path/to/other/project"]
    }
  }
}
```

### Custom Tool Aliases

```json
{
  "toolAliases": {
    "find_code": "cursor-indexing@search_code",
    "analyze_impact": "codegraph@impact_analysis",
    "show_arch": "codegraph@community_detection"
  }
}
```

## 🚀 Performance Optimization

### Caching

```bash
# Enable caching for MCP servers
gemini config set mcp.cache.enabled true
gemini config set mcp.cache.ttl 3600  # 1 hour cache
```

### Parallel Tool Execution

```bash
# Enable parallel tool execution
gemini config set mcp.parallelTools true
gemini config set mcp.maxParallel 3
```

## 🐛 Troubleshooting

### Server Connection Issues

```bash
# Check if server is running
curl -v http://localhost:8080

# Check Gemini CLI connection
gemini mcp test codegraph

# View detailed logs
gemini mcp logs codegraph --verbose
```

### Tool Discovery Problems

```bash
# Refresh tool definitions
gemini mcp refresh codegraph

# List available tools
gemini mcp tools codegraph

# Check tool schemas
gemini mcp schema codegraph@impact_analysis
```

### Permission Errors

```bash
# Check trust settings
gemini mcp trust list

# Increase trust level
gemini mcp trust codegraph trusted

# Check file access permissions
ls -la /Users/user/Developer/GitHub/Anigma_clean
```

## 📚 Reference: Available Tools

### CodeGraph MCP Server Tools

| Tool | Description | Gemini Example |
|------|-------------|----------------|
| `@symbol_lookup` | Find symbol definitions and references | `"Find SystemPhase usage with @symbol_lookup"` |
| `@reference_tracking` | Track symbol usage across codebase | `"Where is HarmoniaModule used? @reference_tracking"` |
| `@impact_analysis` | Analyze change impact | `"What breaks if I modify MCPClientSession? @impact_analysis"` |
| `@context_retrieval` | Get function/method context | `"Show me initializeHarmonia context @context_retrieval"` |
| `@community_detection` | Find related modules | `"Show architecture around AnigmaMCPModule @community_detection"` |

### Cursor Indexing MCP Server Tools

| Tool | Description | Gemini Example |
|------|-------------|----------------|
| `@search_code` | Semantic code search | `"Find MCP timeout handling @search_code"` |
| `@file_search` | Search within specific files | `"Search in AnigmaMCPServer.swift for timeout @file_search"` |
| `@similar_code` | Find similar code patterns | `"Find code like HarmoniaModule init @similar_code"` |

## 🎯 Best Practices

### 1. Tool Chaining
```bash
# Chain tools for complex workflows
gemini "First @search_code for timeout, then @impact_analysis on results"
```

### 2. Context Management
```bash
# Set working directory context
gemini context set /Users/user/Developer/GitHub/Anigma_clean

# Use context in queries
gemini "Analyze current directory architecture with @community_detection"
```

### 3. Session Management
```bash
# Save tool sessions
gemini session save architecture_analysis

# Load previous sessions
gemini session load architecture_analysis
```

## 🔄 Integration with Other Tools

### VS Code with Gemini Extension

```json
// settings.json
{
  "gemini.mcpServers": {
    "codegraph": {
      "url": "http://localhost:8080",
      "enabled": true
    },
    "cursor-indexing": {
      "url": "http://localhost:8000",
      "enabled": true
    }
  }
}
```

### Continue.dev Configuration

```json
// continue config.json
{
  "models": [{
    "title": "Gemini with CodeGraph",
    "provider": "gemini",
    "mcpServers": [
      "http://localhost:8080",
      "http://localhost:8000"
    ]
  }]
}
```

## 🎉 Success! You're Ready to Go

**Your setup is fully compatible with:**
- ✅ Gemini CLI
- ✅ Claude Desktop
- ✅ Cursor IDE
- ✅ Continue.dev
- ✅ Any other MCP-compatible tool

**Next steps:**
1. Start both servers (ports 8000 and 8080)
2. Configure your preferred AI tool
3. Start using `@search_code` and `@impact_analysis` tools
4. Chain tools for powerful workflows

The MCP protocol ensures seamless integration across all these tools! 🚀