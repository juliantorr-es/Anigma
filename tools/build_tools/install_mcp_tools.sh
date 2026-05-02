#!/bin/bash
# MCP Tools Installation Script
# Installs AI-powered codebase knowledge tools

echo "🔧 Installing MCP Tools for Agent Knowledge Base..."
echo ""

# Create installation directory
mkdir -p ~/mcp_tools
cd ~/mcp_tools

echo "1️⃣ Installing MCP-Codebase-Browser..."
echo "   Repository: https://github.com/DeDeveloper23/codebase-mcp"
echo ""

if [ -d "codebase-mcp" ]; then
    echo "   ✅ Already cloned"
else
    git clone https://github.com/DeDeveloper23/codebase-mcp.git
    if [ $? -eq 0 ]; then
        echo "   ✅ Cloned successfully"
    else
        echo "   ❌ Clone failed"
    fi
fi

cd codebase-mcp

# Check for Node.js
if command -v node &> /dev/null; then
    echo "   Node.js found: $(node --version)"
    npm install
    if [ $? -eq 0 ]; then
        echo "   ✅ Dependencies installed"
        npm run build
        if [ $? -eq 0 ]; then
            echo "   ✅ Build successful"
            npm install -g .
            if [ $? -eq 0 ]; then
                echo "   ✅ Installed globally"
            else
                echo "   ❌ Global install failed (may need sudo)"
            fi
        else
            echo "   ❌ Build failed"
        fi
    else
        echo "   ❌ Dependency install failed"
    fi
else
    echo "   ❌ Node.js not found - required for MCP-Codebase-Browser"
fi

echo ""
echo "2️⃣ Installing Kontxt..."
echo "   Repository: https://github.com/reyneill/kontxt"
echo ""

cd ~/mcp_tools

if [ -d "kontxt" ]; then
    echo "   ✅ Already cloned"
else
    git clone https://github.com/reyneill/kontxt.git
    if [ $? -eq 0 ]; then
        echo "   ✅ Cloned successfully"
    else
        echo "   ❌ Clone failed"
    fi
fi

cd kontxt

# Check for Python
if command -v python3 &> /dev/null; then
    echo "   Python found: $(python3 --version)"
    
    # Check pip
    if python3 -m pip --version &> /dev/null; then
        echo "   pip found"
        
        # Install requirements
        python3 -m pip install -r requirements.txt
        if [ $? -eq 0 ]; then
            echo "   ✅ Dependencies installed"
            
            # Create config template
            cat > kontxt_config.json << 'KONFIG'
{
    "repo_path": "/Users/user/Developer/GitHub/Anigma_clean",
    "transport": "stdio",
    "gemini_api_key": "YOUR_API_KEY_HERE"
}
KONFIG
            echo "   ✅ Config template created (add your Gemini API key)"
        else
            echo "   ❌ Dependency install failed"
        fi
    else
        echo "   ❌ pip not found"
    fi
else
    echo "   ❌ Python not found - required for Kontxt"
fi

echo ""
echo "3️⃣ Installing Cursor Local Indexing..."
echo "   Repository: https://github.com/LuotoCompany/cursor-local-indexing"
echo ""

cd ~/mcp_tools

if [ -d "cursor-local-indexing" ]; then
    echo "   ✅ Already cloned"
else
    git clone https://github.com/LuotoCompany/cursor-local-indexing.git
    if [ $? -eq 0 ]; then
        echo "   ✅ Cloned successfully"
    else
        echo "   ❌ Clone failed"
    fi
fi

cd cursor-local-indexing

# Check for Python
if command -v python3 &> /dev/null; then
    echo "   Python found: $(python3 --version)"
    
    # Check pip
    if python3 -m pip --version &> /dev/null; then
        echo "   pip found"
        
        # Install requirements
        python3 -m pip install -r requirements.txt
        if [ $? -eq 0 ]; then
            echo "   ✅ Dependencies installed (this may take a while)"
            
            # Create config template
            cat > cursor_config.json << 'KONFIG'
{
    "codebase_path": "/Users/user/Developer/GitHub/Anigma_clean",
    "index_name": "anigma_codebase",
    "persist_directory": "~/mcp_tools/cursor_index"
}
KONFIG
            echo "   ✅ Config template created"
        else
            echo "   ❌ Dependency install failed"
        fi
    else
        echo "   ❌ pip not found"
    fi
else
    echo "   ❌ Python not found - required for Cursor Local Indexing"
fi

echo ""
echo "📋 Installation Summary:"
echo ""
echo "MCP-Codebase-Browser:"
echo "   - Location: ~/mcp_tools/codebase-mcp"
echo "   - Command: codebase-mcp"
echo "   - Status: $(command -v codebase-mcp &> /dev/null && echo "✅ Installed" || echo "❌ Not installed")"
echo ""
echo "Kontxt:"
echo "   - Location: ~/mcp_tools/kontxt"
echo "   - Command: python3 kontxt_server.py --config kontxt_config.json"
echo "   - Requirements: Python 3.10+, Gemini API key"
echo "   - Status: $(command -v python3 &> /dev/null && echo "✅ Ready" || echo "❌ Python missing")"
echo ""
echo "Cursor Local Indexing:"
echo "   - Location: ~/mcp_tools/cursor-local-indexing"
echo "   - Command: python3 cursor_server.py --config cursor_config.json"
echo "   - Requirements: Python 3.10+, ChromaDB"
echo "   - Status: $(command -v python3 &> /dev/null && echo "✅ Ready" || echo "❌ Python missing")"
echo ""
echo "🎯 Next Steps:"
echo "1. Add Gemini API key to kontxt_config.json"
echo "2. Review cursor_config.json settings"
echo "3. Test each tool individually"
echo "4. Integrate with your MCP client (Cursor, Claude Code, etc.)"
echo ""
echo "📚 Documentation:"
echo "- MCP-Codebase-Browser: https://github.com/DeDeveloper23/codebase-mcp"
echo "- Kontxt: https://github.com/reyneill/kontxt"
echo "- Cursor Local Indexing: https://github.com/LuotoCompany/cursor-local-indexing"
