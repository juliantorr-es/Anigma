#!/bin/bash
# AnigmaDaemonSimple Uninstallation Script
# Removes the daemon and all associated files

set -e

echo "🗑️  Uninstalling AnigmaDaemonSimple..."

# Stop and unload LaunchAgent
echo "Stopping daemon..."
if launchctl list | grep -q "com.anigma.daemon"; then
    launchctl unload "$HOME/Library/LaunchAgents/com.anigma.daemon.plist" 2>/dev/null || true
    echo "✅ Daemon stopped"
else
    echo "⚠️  Daemon not running"
fi

# Kill any remaining daemon processes
pkill -f "anigmad" 2>/dev/null || true
sleep 1

# Remove LaunchAgent
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.anigma.daemon.plist"
if [ -f "$LAUNCH_AGENT_PLIST" ]; then
    rm -f "$LAUNCH_AGENT_PLIST"
    echo "✅ Removed LaunchAgent: $LAUNCH_AGENT_PLIST"
else
    echo "⚠️  LaunchAgent not found"
fi

# Remove daemon binary from common locations
echo "Removing daemon binaries..."
BIN_LOCATIONS=(
    "/usr/local/bin/anigmad"
    "$HOME/.local/bin/anigmad"
    "/opt/homebrew/bin/anigmad"
)

for bin_path in "${BIN_LOCATIONS[@]}"; do
    if [ -f "$bin_path" ]; then
        rm -f "$bin_path"
        echo "✅ Removed binary: $bin_path"
    fi
done

# Ask about removing configuration and data
echo ""
read -p "Remove configuration and data? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Remove application support directory
    APP_SUPPORT_DIR="$HOME/Library/Application Support/AnigmaDaemon"
    if [ -d "$APP_SUPPORT_DIR" ]; then
        rm -rf "$APP_SUPPORT_DIR"
        echo "✅ Removed application support directory: $APP_SUPPORT_DIR"
    else
        echo "⚠️  Application support directory not found"
    fi
    
    # Remove logs directory
    LOGS_DIR="$HOME/Library/Logs/AnigmaDaemon"
    if [ -d "$LOGS_DIR" ]; then
        rm -rf "$LOGS_DIR"
        echo "✅ Removed logs directory: $LOGS_DIR"
    else
        echo "⚠️  Logs directory not found"
    fi
    
    # Remove temporary files
    TEMP_FILES=(
        "/tmp/com.anigma.daemon.log"
        "/tmp/com.anigma.daemon.err"
    )
    
    for temp_file in "${TEMP_FILES[@]}"; do
        if [ -f "$temp_file" ]; then
            rm -f "$temp_file"
            echo "✅ Removed temp file: $temp_file"
        fi
    done
else
    echo "⚠️  Configuration and data preserved"
    echo "   - Application Support: $HOME/Library/Application Support/AnigmaDaemon"
    echo "   - Logs: $HOME/Library/Logs/AnigmaDaemon"
fi

# Clean up PATH in shell config (if we added it)
SHELL_CONFIG="$HOME/.zshrc"
if [ -f "$SHELL_CONFIG" ]; then
    # Remove our PATH addition if present
    if grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_CONFIG"; then
        # Use sed to remove the line
        sed -i '' '/export PATH="\$HOME\/.local\/bin:\$PATH"/d' "$SHELL_CONFIG"
        echo "✅ Removed PATH addition from $SHELL_CONFIG"
    fi
fi

echo ""
echo "✅ Uninstallation completed!"
echo ""
echo "Note: If you installed with the system package installer, you may need to run:"
echo "  sudo pkgutil --forget com.anigma.daemon"
echo ""
echo "To reinstall, run ./install.sh again."
