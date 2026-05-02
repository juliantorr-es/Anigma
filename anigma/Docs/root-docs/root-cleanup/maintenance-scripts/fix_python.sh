#!/bin/bash
echo "🔧 Fixing Python environment..."

# 1. Remove pyenv from PATH temporarily
echo "export PATH=$(echo $PATH | tr ':' '\n' | grep -v pyenv | tr '\n' ':')" >> ~/.zshrc

# 2. Ensure system Python is first
echo "export PATH="/usr/bin:$PATH"" >> ~/.zshrc

# 3. Update pip
/usr/bin/python3 -m pip install --upgrade pip

# 4. Install virtualenv for isolation
echo "Installing virtualenv..."
/usr/bin/python3 -m pip install virtualenv

# 5. Create a clean virtual environment for MCP tools
echo "Creating clean virtual environment..."
cd ~/mcp_tools
/usr/bin/python3 -m virtualenv mcp_env

# 6. Activate and test
echo "Testing virtual environment..."
source ~/mcp_tools/mcp_env/bin/activate
python --version
pip --version

# 7. Add activation alias to zshrc
echo "" >> ~/.zshrc
echo "# MCP Tools Virtual Environment" >> ~/.zshrc
echo "alias mcp-env='source ~/mcp_tools/mcp_env/bin/activate'" >> ~/.zshrc

echo "✅ Python environment fixed!"
echo ""
echo "To use the clean Python environment:"
echo "1. Open new terminal or run: source ~/.zshrc"
echo "2. Activate MCP environment: mcp-env"
echo "3. Install MCP tools: ./install_mcp_tools.sh"
