#!/bin/bash
# One-Command Installer for AnigmaDaemonSimple
# Builds, installs, and configures the daemon in one step

set -e

echo "🚀 AnigmaDaemonSimple One-Command Installer"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for required tools
echo "Checking system requirements..."
if ! command -v swift &> /dev/null; then
    echo "❌ Swift compiler not found. Please install Xcode command line tools:"
    echo "   xcode-select --install"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "❌ curl not found. Please install curl."
    exit 1
fi

echo "✅ System requirements met"

# Build the daemon
echo ""
echo "Step 1: Building daemon..."
if [ -f "$SCRIPT_DIR/build_daemon.sh" ]; then
    bash "$SCRIPT_DIR/build_daemon.sh"
else
    echo "❌ Build script not found at $SCRIPT_DIR/build_daemon.sh"
    exit 1
fi

# Install the daemon
echo ""
echo "Step 2: Installing daemon..."
if [ -f "$SCRIPT_DIR/install.sh" ]; then
    # Ask for sudo if needed
    if [ "$EUID" -ne 0 ]; then
        echo "⚠️  Installation will be user-local (no sudo required)"
        echo "   For system-wide installation, run: sudo $SCRIPT_DIR/install.sh"
    fi
    
    bash "$SCRIPT_DIR/install.sh"
else
    echo "❌ Install script not found at $SCRIPT_DIR/install.sh"
    exit 1
fi

# Generate API key
echo ""
echo "Step 3: Generating API key..."
read -p "Generate API key now? (Y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "⚠️  Skipping API key generation"
    echo "   Run ./generate_api_key.sh later to create an API key"
else
    if [ -f "$SCRIPT_DIR/generate_api_key.sh" ]; then
        bash "$SCRIPT_DIR/generate_api_key.sh"
    else
        echo "❌ API key generation script not found"
        echo "   You'll need to manually create an API key"
    fi
fi

# Test installation
echo ""
echo "Step 4: Testing installation..."
read -p "Run installation test? (Y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "⚠️  Skipping installation test"
else
    if [ -f "$SCRIPT_DIR/test_installation.sh" ]; then
        bash "$SCRIPT_DIR/test_installation.sh"
    else
        echo "❌ Test script not found"
    fi
fi

echo ""
echo "🎉 Installation completed!"
echo ""
echo "Quick Start Guide:"
echo "=================="
echo "1. The daemon is now running in the background"
echo "2. It will auto-start on login"
echo "3. API is available at: http://localhost:8080"
echo ""
echo "Management Commands:"
echo "-------------------"
echo "• Check status:    launchctl list | grep com.anigma.daemon"
echo "• View logs:       tail -f ~/Library/Logs/AnigmaDaemon/daemon.log"
echo "• Restart daemon:  launchctl unload ~/Library/LaunchAgents/com.anigma.daemon.plist && launchctl load ~/Library/LaunchAgents/com.anigma.daemon.plist"
echo "• Stop daemon:     launchctl unload ~/Library/LaunchAgents/com.anigma.daemon.plist"
echo "• Uninstall:       ./uninstall.sh"
echo ""
echo "API Usage:"
echo "----------"
echo "• Health check:    curl http://localhost:8080/health"
echo "• Get status:      curl http://localhost:8080/status"
echo "• With API key:    curl -H 'X-API-Key: YOUR_API_KEY' http://localhost:8080/status"
echo ""
echo "Configuration:"
echo "--------------"
echo "• Config file:     ~/Library/Application Support/AnigmaDaemon/config.json"
echo "• Edit config:     nano ~/Library/Application Support/AnigmaDaemon/config.json"
echo "• Regenerate key:  ./generate_api_key.sh"
echo ""
echo "Need help? Check README.md for detailed documentation."
