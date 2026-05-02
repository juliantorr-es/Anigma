#!/bin/bash
set -e

# Setup script for Claude Desktop MCP integration with anigmad
# Usage: bash Scripts/setup_claude_desktop.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$REPO_ROOT/.build/release"
INSTALL_PATH="${1:-/usr/local/bin}"
CLAUDE_CONFIG_DIR=~/"Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

echo "═══════════════════════════════════════════════════════════════"
echo "Claude Desktop MCP Setup for anigmad"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Step 1: Build anigmad
echo "Step 1/4: Building anigmad (release mode)..."
cd "$REPO_ROOT"
if swift build -c release --product anigmad -Xswiftc -suppress-warnings > /dev/null 2>&1; then
    echo "  ✓ Build successful"
else
    echo "  ✗ Build failed. Run: swift build -c release"
    exit 1
fi

# Step 2: Install binary
echo ""
echo "Step 2/4: Installing anigmad binary to $INSTALL_PATH..."
if [ ! -f "$BUILD_DIR/anigmad" ]; then
    echo "  ✗ Binary not found at $BUILD_DIR/anigmad"
    exit 1
fi

if [ "$INSTALL_PATH" = "/usr/local/bin" ]; then
    sudo cp "$BUILD_DIR/anigmad" "$INSTALL_PATH/anigmad"
    sudo chmod +x "$INSTALL_PATH/anigmad"
    echo "  ✓ Installed to $INSTALL_PATH/anigmad"
else
    mkdir -p "$INSTALL_PATH"
    cp "$BUILD_DIR/anigmad" "$INSTALL_PATH/anigmad"
    chmod +x "$INSTALL_PATH/anigmad"
    echo "  ✓ Installed to $INSTALL_PATH/anigmad"
fi

# Verify installation
if command -v anigmad &> /dev/null || [ -x "$INSTALL_PATH/anigmad" ]; then
    echo "  ✓ Binary is executable"
else
    echo "  ✗ Binary installation verification failed"
    exit 1
fi

# Step 3: Create Claude config directory
echo ""
echo "Step 3/4: Setting up Claude Desktop configuration..."
mkdir -p "$CLAUDE_CONFIG_DIR"
echo "  ✓ Claude config directory ready: $CLAUDE_CONFIG_DIR"

# Step 4: Update Claude Desktop config
echo ""
echo "Step 4/4: Adding daemon-backed MCP server to Claude Desktop config..."

# Read or create config
if [ -f "$CLAUDE_CONFIG_FILE" ]; then
    echo "  ℹ Found existing config at $CLAUDE_CONFIG_FILE"

    # Backup original
    BACKUP_FILE="$CLAUDE_CONFIG_FILE.backup.$(date +%s)"
    cp "$CLAUDE_CONFIG_FILE" "$BACKUP_FILE"
    echo "  ✓ Backed up to $BACKUP_FILE"

    # Update config (requires python3 for JSON manipulation)
    if command -v python3 &> /dev/null; then
        python3 << PYTHON_SCRIPT
import json
import sys

config_file = "$CLAUDE_CONFIG_FILE"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except FileNotFoundError:
    config = {}
except json.JSONDecodeError:
    print("  ✗ Invalid JSON in Claude config")
    sys.exit(1)

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['anigma'] = {
    'command': '$INSTALL_PATH/anigmad',
    'args': ['--mcp'],
    'disabled': False,
    'autoApprove': [
        'read_file',
        'list_artifacts',
        'list_models',
        'context_search',
        'get_system_health',
        'list_active_alerts',
        'database_query',
        'trace_query',
        'git_diff',
        'verify_evidence_chain'
    ],
    'env': {
        'ANIGMA_MCP_ENABLE': 'true',
        'ANIGMA_LOG_LEVEL': 'info'
    }
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("  ✓ Updated Claude Desktop config")
PYTHON_SCRIPT
    else
        echo "  ℹ Skipping auto-update (python3 not found)"
        echo "  → Manually merge: $REPO_ROOT/Docs/claude_desktop_config.json.template"
    fi
else
    echo "  ℹ Creating new config"
    cat "$REPO_ROOT/Docs/claude_desktop_config.json.template" > "$CLAUDE_CONFIG_FILE"
    sed -i '' "s|/usr/local/bin|$INSTALL_PATH|g" "$CLAUDE_CONFIG_FILE"
    echo "  ✓ Created Claude Desktop config"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Setup Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Completely quit Claude Desktop (Cmd+Q)"
echo "  2. Relaunch Claude Desktop"
echo "  3. Look for 'anigma' indicator in the bottom-right"
echo ""
echo "To verify:"
echo "  → Ask Claude: 'Show me the system health'"
echo "  → Claude should call get_system_health and return metrics"
echo ""
echo "Config file: $CLAUDE_CONFIG_FILE"
echo "Binary: $INSTALL_PATH/anigmad --mcp"
echo ""
echo "For troubleshooting, see:"
echo "  → $REPO_ROOT/Docs/CLAUDE_DESKTOP_SETUP.md"
echo ""
