#!/bin/bash
# AnigmaDaemonSimple Installation Script
# Installs the daemon to /usr/local/bin and sets up LaunchAgent

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_BINARY="$SCRIPT_DIR/anigmad"

# Check if running as root (for system-wide installation)
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Running without sudo. Will install to user directories only."
    echo "   For system-wide installation, run with: sudo ./install.sh"
    USER_INSTALL=true
else
    USER_INSTALL=false
fi

echo "🚀 Installing AnigmaDaemonSimple..."

# Check if daemon binary exists
if [ ! -f "$DAEMON_BINARY" ]; then
    echo "Error: Daemon binary not found at $DAEMON_BINARY"
    echo "Please run build_daemon.sh first to build the daemon."
    exit 1
fi

# Stop existing daemon if running
echo "Checking for existing daemon..."
if launchctl list | grep -q "com.anigma.daemon"; then
    echo "Stopping existing daemon..."
    launchctl unload "$HOME/Library/LaunchAgents/com.anigma.daemon.plist" 2>/dev/null || true
    sleep 2
fi

# Kill any running daemon processes
pkill -f "anigmad" 2>/dev/null || true
sleep 1

# Install daemon binary
echo "Installing daemon binary..."
if [ "$USER_INSTALL" = true ]; then
    # User installation to ~/.local/bin
    LOCAL_BIN="$HOME/.local/bin"
    mkdir -p "$LOCAL_BIN"
    cp "$DAEMON_BINARY" "$LOCAL_BIN/anigmad"
    chmod +x "$LOCAL_BIN/anigmad"
    echo "✅ Daemon installed to: $LOCAL_BIN/anigmad"
    
    # Add to PATH if not already
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        echo "Adding $LOCAL_BIN to PATH in ~/.zshrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
else
    # System installation to /usr/local/bin
    cp "$DAEMON_BINARY" /usr/local/bin/anigmad
    chmod +x /usr/local/bin/anigmad
    echo "✅ Daemon installed to: /usr/local/bin/anigmad"
fi

# Create application support directory
echo "Creating application support directories..."
APP_SUPPORT_DIR="$HOME/Library/Application Support/AnigmaDaemon"
LOGS_DIR="$HOME/Library/Logs/AnigmaDaemon"
mkdir -p "$APP_SUPPORT_DIR"
mkdir -p "$LOGS_DIR"

# Copy default configuration if none exists
if [ ! -f "$APP_SUPPORT_DIR/config.json" ]; then
    echo "Creating default configuration..."
    if [ -f "$SCRIPT_DIR/config/default.json" ]; then
        cp "$SCRIPT_DIR/config/default.json" "$APP_SUPPORT_DIR/config.json"
    else
        # Create minimal config
        cat > "$APP_SUPPORT_DIR/config.json" << 'CONFIGEOF'
{
    "server_port": 8080,
    "log_level": "info",
    "auto_start": true
}
CONFIGEOF
    fi
    echo "✅ Configuration created at: $APP_SUPPORT_DIR/config.json"
    echo "⚠️  Note: You need to generate an API key using ./generate_api_key.sh"
else
    echo "✅ Using existing configuration at: $APP_SUPPORT_DIR/config.json"
fi

# Create LaunchAgent plist
echo "Creating LaunchAgent..."
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENT_DIR"

LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/com.anigma.daemon.plist"

# Determine binary path for LaunchAgent
if [ "$USER_INSTALL" = true ]; then
    DAEMON_PATH="$HOME/.local/bin/anigmad"
else
    DAEMON_PATH="/usr/local/bin/anigmad"
fi

cat > "$LAUNCH_AGENT_PLIST" << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.anigma.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>__DAEMON_PATH__</string>
        <string>--config</string>
        <string>__CONFIG_PATH__</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>__LOGS_PATH__/daemon.log</string>
    <key>StandardErrorPath</key>
    <string>__LOGS_PATH__/daemon.err</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>Nice</key>
    <integer>1</integer>
    <key>SoftResourceLimits</key>
    <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
    </dict>
</dict>
</plist>
PLISTEOF

# Replace placeholders
sed -i '' "s|__DAEMON_PATH__|$DAEMON_PATH|g" "$LAUNCH_AGENT_PLIST"
sed -i '' "s|__CONFIG_PATH__|$APP_SUPPORT_DIR/config.json|g" "$LAUNCH_AGENT_PLIST"
sed -i '' "s|__LOGS_PATH__|$LOGS_DIR|g" "$LAUNCH_AGENT_PLIST"

echo "✅ LaunchAgent created at: $LAUNCH_AGENT_PLIST"

# Load LaunchAgent
echo "Loading LaunchAgent..."
launchctl load "$LAUNCH_AGENT_PLIST"

# Wait a moment for daemon to start
sleep 2

# Verify installation
echo "Verifying installation..."
if launchctl list | grep -q "com.anigma.daemon"; then
    echo "✅ Daemon successfully installed and running!"
    
    # Check if daemon is responding
    echo "Checking daemon status..."
    sleep 3
    if curl -s http://localhost:8080/health 2>/dev/null | grep -q "ok"; then
        echo "✅ Daemon API is responding on http://localhost:8080"
    else
        echo "⚠️  Daemon installed but API not responding yet (may need to generate API key)"
    fi
else
    echo "⚠️  Daemon installed but not running. Check logs: $LOGS_DIR/daemon.err"
fi

echo ""
echo "🎉 Installation completed!"
echo ""
echo "Next steps:"
echo "1. Generate an API key: ./generate_api_key.sh"
echo "2. Configure the daemon: Edit $APP_SUPPORT_DIR/config.json"
echo "3. View logs: tail -f $LOGS_DIR/daemon.log"
echo "4. Restart daemon: launchctl unload $LAUNCH_AGENT_PLIST && launchctl load $LAUNCH_AGENT_PLIST"
echo ""
echo "To uninstall: ./uninstall.sh"
echo ""
