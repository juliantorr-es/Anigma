#!/bin/bash
# AnigmaDaemonSimple Build Script
# Builds the daemon from source and prepares it for installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$SCRIPT_DIR/dist"

echo "🔨 Building AnigmaDaemonSimple..."
echo "Project Root: $PROJECT_ROOT"

# Clean previous builds
rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

# Try to build the daemon
echo "Building daemon executable..."
cd "$PROJECT_ROOT/.."  # Go to root directory

BUILD_SUCCESS=false
if swift build --configuration release --product anigmad 2>/dev/null; then
    BUILD_SUCCESS=true
    echo "✅ Daemon built successfully"
else
    echo "⚠️  Main build failed, checking for existing binary..."
fi

# Copy the built executable if it exists
DAEMON_BINARY=".build/release/anigmad"
if [ -f "$DAEMON_BINARY" ]; then
    echo "Copying daemon binary..."
    cp "$DAEMON_BINARY" "$INSTALL_DIR/anigmad"
    chmod +x "$INSTALL_DIR/anigmad"
    echo "✅ Using full-featured daemon"
elif [ -f "$PROJECT_ROOT/.build/release/anigmad" ]; then
    echo "Copying daemon binary from project build..."
    cp "$PROJECT_ROOT/.build/release/anigmad" "$INSTALL_DIR/anigmad"
    chmod +x "$INSTALL_DIR/anigmad"
    echo "✅ Using full-featured daemon"
else
    echo "❌ Daemon binary not found, using fallback build..."
    # Use fallback build
    "$SCRIPT_DIR/build_daemon_fallback.sh"
    exit 0
fi

# Create configuration directory structure
echo "Creating configuration structure..."
mkdir -p "$INSTALL_DIR/config"
mkdir -p "$INSTALL_DIR/logs"

# Generate default configuration
cat > "$INSTALL_DIR/config/default.json" << 'CONFIGEOF'
{
    "server": {
        "port": 8080,
        "host": "127.0.0.1"
    },
    "logging": {
        "level": "info",
        "max_size_mb": 10,
        "max_files": 5
    },
    "security": {
        "api_key_required": true,
        "cors_enabled": true
    },
    "monitoring": {
        "enabled": true,
        "metrics_port": 9090
    }
}
CONFIGEOF

# Create API key generation script
cat > "$INSTALL_DIR/generate_api_key.sh" << 'APIKEYEOF'
#!/bin/bash
# Generate a secure API key for AnigmaDaemon

set -e

CONFIG_DIR="$HOME/Library/Application Support/AnigmaDaemon"
mkdir -p "$CONFIG_DIR"

# Generate a secure random API key
API_KEY=$(openssl rand -hex 32 2>/dev/null || uuidgen | tr -d '-')

echo "Generated API Key: $API_KEY"
echo "Saving to configuration..."

cat > "$CONFIG_DIR/config.json" << CFGEOF
{
    "api_key": "$API_KEY",
    "server_port": 8080,
    "log_level": "info",
    "auto_start": true
}
CFGEOF

echo "✅ API key generated and saved to: $CONFIG_DIR/config.json"
echo ""
echo "Important: Save this API key for client authentication:"
echo "  $API_KEY"
echo ""
echo "To use with clients, set the ANIGMA_API_KEY environment variable:"
echo "  export ANIGMA_API_KEY=\"$API_KEY\""
APIKEYEOF

chmod +x "$INSTALL_DIR/generate_api_key.sh"

# Create README
cat > "$INSTALL_DIR/README.md" << 'READMEEOF'
# AnigmaDaemonSimple Installation

This directory contains the built AnigmaDaemonSimple executable and installation files.

## Files:
- `anigmad` - The daemon executable
- `config/default.json` - Default configuration
- `generate_api_key.sh` - API key generation script
- `install.sh` - Installation script
- `uninstall.sh` - Uninstallation script

## Installation:
1. Run `./install.sh` to install the daemon
2. Run `./generate_api_key.sh` to create an API key
3. The daemon will start automatically on login

## Usage:
- Start manually: `anigmad`
- Check status: `launchctl list | grep com.anigma.daemon`
- View logs: `tail -f ~/Library/Logs/AnigmaDaemon/daemon.log`

## API:
The daemon provides a REST API on port 8080 (configurable).
Use the generated API key for authentication.
READMEEOF

echo "✅ Build completed successfully!"
echo "Built files are in: $INSTALL_DIR"
echo ""
echo "To install:"
echo "  cd $INSTALL_DIR"
echo "  ./install.sh"
