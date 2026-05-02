# MCP Tools Installation Guide

## 🎯 Overview

This guide provides step-by-step instructions for installing AI-powered MCP (Model Context Protocol) tools that enhance agent capabilities with semantic codebase understanding.

## 🔧 Prerequisites Fixed

✅ **Python Environment**: Clean virtualenv created at `~/mcp_tools/mcp_env`
- Python 3.9.6
- Pip 26.0.1
- Isolated from system conflicts

✅ **Node.js**: v20.17.0 (for MCP-Codebase-Browser)

✅ **Shell Configuration**: Updated `.zshrc` with proper PATH

## 🚀 Installation Steps

### 1. Activate Virtual Environment

```bash
cd /Users/user/Developer/GitHub/Anigma_clean
source ~/mcp_tools/mcp_env/bin/activate
```

Verify:
```bash
which python  # Should show: /Users/user/mcp_tools/mcp_env/bin/python
which pip     # Should show: /Users/user/mcp_tools/mcp_env/bin/pip
```

### 2. Run Installation Script

```bash
./install_mcp_tools.sh
```

This will install:
- **MCP-Codebase-Browser** (Node.js)
- **Kontxt** (Python + Gemini)
- **Cursor Local Indexing** (Python + ChromaDB)

### 3. Post-Installation Setup

#### For Kontxt:
1. Edit `~/mcp_tools/kontxt/kontxt_config.json`
2. Add your Gemini API key
3. Test: `python3 kontxt_server.py --config kontxt_config.json`

#### For Cursor Local Indexing:
1. Review `~/mcp_tools/cursor-local-indexing/cursor_config.json`
2. Adjust paths if needed
3. Test: `python3 cursor_server.py --config cursor_config.json`

### 4. Integrate with MCP Client

Configure your AI agent (Cursor, Claude Code, etc.) to connect to:
- **Kontxt**: `stdio` transport
- **Cursor Indexing**: `http://localhost:8080` (default)

## 📚 Tool Documentation

### MCP-Codebase-Browser
- **Purpose**: Codebase navigation and analysis
- **Command**: `codebase-mcp`
- **Repository**: https://github.com/DeDeveloper23/codebase-mcp

### Kontxt
- **Purpose**: Semantic code search with Gemini
- **Command**: `python3 kontxt_server.py --config kontxt_config.json`
- **Repository**: https://github.com/reyneill/kontxt
- **Requires**: Gemini API key

### Cursor Local Indexing
- **Purpose**: ChromaDB-powered semantic search
- **Command**: `python3 cursor_server.py --config cursor_config.json`
- **Repository**: https://github.com/LuotoCompany/cursor-local-indexing
- **Database**: ChromaDB (local vector store)

## 🎓 Usage Examples

### Query Codebase Semantically
```bash
# Activate environment
source ~/mcp_tools/mcp_env/bin/activate

# Start Kontxt server
cd ~/mcp_tools/kontxt
python3 kontxt_server.py --config kontxt_config.json &

# Query from your AI agent
# "Find all network requests in the codebase"
# "Explain the authentication flow"
```

### Index Codebase for Search
```bash
# Start Cursor indexing server
cd ~/mcp_tools/cursor-local-indexing
python3 cursor_server.py --config cursor_config.json &

# Your agent can now perform semantic searches
```

### Navigate Codebase Structure
```bash
# Use MCP-Codebase-Browser
codebase-mcp

# Follow prompts to analyze:
# - Project structure
# - Dependency graph
# - Architecture patterns
```

## 🔍 Troubleshooting

### Python Environment Issues
```bash
# Reactivate clean environment
source ~/mcp_tools/mcp_env/bin/activate

# Check versions
python --version  # Should be 3.9.6
pip --version     # Should be 26.0.1
```

### Dependency Conflicts
```bash
# Recreate virtualenv if needed
rm -rf ~/mcp_tools/mcp_env
/usr/bin/python3 -m virtualenv ~/mcp_tools/mcp_env
source ~/mcp_tools/mcp_env/bin/activate
```

### Node.js Issues
```bash
# Verify Node.js
node --version  # Should be v20.17.0
npm --version   # Should be 10.8.1+
```

## 📊 Comparison: Current vs MCP Tools

| Feature | Current System | MCP Tools |
|---------|---------------|----------|
| **Search** | Keyword-based (`rg`) | Semantic understanding |
| **Navigation** | File-based (`fd`) | Concept-based |
| **Context** | Manual inspection | AI-generated |
| **Scale** | File-by-file | Whole codebase |
| **Integration** | CLI tools | AI agents |

## 🎯 Recommendations

1. **Start with Kontxt** if you have Gemini API access
2. **Use Cursor Indexing** for local semantic search
3. **Add MCP-Codebase-Browser** for architectural analysis
4. **Combine all three** for comprehensive codebase understanding

## 📖 References

- [MCP Specification](https://mcp.aibase.com/)
- [Kontxt Documentation](https://github.com/reyneill/kontxt)
- [Cursor Local Indexing](https://github.com/LuotoCompany/cursor-local-indexing)
- [MCP-Codebase-Browser](https://github.com/DeDeveloper23/codebase-mcp)

---

**Status**: ✅ Ready for installation
**Next Step**: Run `./install_mcp_tools.sh` after activating virtualenv
