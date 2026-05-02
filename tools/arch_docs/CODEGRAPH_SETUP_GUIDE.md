# CodeGraph MCP Server Setup Guide

## 🚀 Quick Start

### 1. Run the setup script
```bash
./setup_codegraph.sh
```

### 2. Index your Anigma codebase
```bash
cd ~/codegraph-mcp
source .venv/bin/activate
codegraph-mcp index /Users/user/Developer/GitHub/Anigma_clean --full
```

### 3. Start the server
```bash
codegraph-mcp start --port 8080
```

### 4. Configure your MCP client
Add this to your MCP client configuration:
```json
{
  "mcpServers": {
    "codegraph-anigma": {
      "url": "http://localhost:8080",
      "description": "CodeGraph MCP Server for Anigma codebase"
    }
  }
}
```

## 📋 Detailed Setup Instructions

### Prerequisites
- Python 3.10+ (you have 3.13.2 ✅)
- Git
- ~2GB disk space for indexing

### Installation Steps

1. **Create project directory:**
   ```bash
   mkdir -p ~/codegraph-mcp
   cd ~/codegraph-mcp
   ```

2. **Clone the repository:**
   ```bash
   git clone https://github.com/nahisaho/CodeGraphMCPServer.git .
   ```

3. **Set up virtual environment:**
   ```bash
   python3.13 -m venv .venv
   source .venv/bin/activate
   ```

4. **Install dependencies:**
   ```bash
   pip install --upgrade pip
   pip install -e ".[dev]"
   ```

### Indexing Your Codebase

**Full index (first time):**
```bash
codegraph-mcp index /Users/user/Developer/GitHub/Anigma_clean --full
```

**Incremental index (subsequent runs):**
```bash
codegraph-mcp index /Users/user/Developer/GitHub/Anigma_clean
```

**Index multiple projects:**
```bash
codegraph-mcp index /path/to/project1 /path/to/project2
```

### Running the Server

**HTTP mode (recommended):**
```bash
codegraph-mcp start --port 8080
```

**Stdio mode (for direct AI tool integration):**
```bash
codegraph-mcp serve --repo /Users/user/Developer/GitHub/Anigma_clean
```

### Server Management

**Check server status:**
```bash
codegraph-mcp status
```

**Stop server:**
```bash
codegraph-mcp stop
```

**View logs:**
```bash
tail -f ~/codegraph-mcp/codegraph.log
```

## 🔧 Configuration

Edit `codegraph_config.json` to customize:
- **Port:** Change from 8080 if needed
- **Projects:** Add multiple codebases
- **Languages:** Specify which languages to index
- **Ignore patterns:** Customize file exclusion

## 🎯 Available Tools

### 1. Symbol Lookup
Find definitions and references of functions, classes, variables
```
@symbol_lookup {"symbol": "HarmoniaModule", "project": "Anigma"}
```

### 2. Reference Tracking
Find all places where a symbol is used
```
@reference_tracking {"symbol": "SystemPhase", "project": "Anigma"}
```

### 3. Impact Analysis
Analyze blast radius of code changes
```
@impact_analysis {"file": "Sources/HarmoniaModule.swift", "project": "Anigma"}
```

### 4. Context Retrieval
Get full context for functions/methods
```
@context_retrieval {"function": "initializeHarmonia", "project": "Anigma"}
```

### 5. Community Detection
Find related modules and architecture patterns
```
@community_detection {"module": "AnigmaMCPModule", "project": "Anigma"}
```

## 💡 Tips

### Running in background
```bash
nohup codegraph-mcp start --port 8080 > codegraph.log 2>&1 &
```

### Automatic startup
Add to your `.zshrc` or `.bashrc`:
```bash
alias start-codegraph='cd ~/codegraph-mcp && source .venv/bin/activate && codegraph-mcp start --port 8080'
```

### Monitoring
```bash
# Check memory usage
ps aux | grep codegraph

# Check port usage
lsof -i :8080
```

## 🔄 Integration with Existing Setup

**Complementary to your current tools:**
- **Cursor indexing (port 8000):** Fast semantic search
- **CodeGraph (port 8080):** Architecture and impact analysis
- **Code Pathfinder (port 8081):** Natural language queries

All can run simultaneously!

## 🚫 Troubleshooting

**Port already in use:**
```bash
lsof -i :8080
kill <PID>
```

**Indexing issues:**
```bash
codegraph-mcp index --debug /path/to/project
```

**Dependency conflicts:**
```bash
rm -rf .venv && python3.13 -m venv .venv && source .venv/bin/activate && pip install -e ".[dev]"
```

## 📚 Resources

- **Official Docs:** https://github.com/nahisaho/CodeGraphMCPServer
- **PyPI Package:** https://pypi.org/project/codegraph-mcp-server/
- **MCP Registry:** Search for `codegraph-mcp-server`

---

🎉 **Ready to explore your codebase like never before!** 🚀