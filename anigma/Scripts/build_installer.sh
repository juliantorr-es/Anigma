#!/bin/bash
set -euo pipefail

# Anigma Installer Build Script
# Builds macOS installer package with update detection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/release"
INSTALLER_DIR="$PROJECT_ROOT/ReleaseCandidate"
PAYLOAD_DIR="$INSTALLER_DIR/AnigmaInstaller"
SCRIPTS_DIR="$INSTALLER_DIR/scripts"
APP_BUNDLE="Anigma.app"
VERSION="1.0.0-rc$(date +%Y%m%d)"
PKG_NAME="AnigmaInstaller-${VERSION}.pkg"

echo "🏗️  Building Anigma Installer"
echo "Version: $VERSION"
echo ""

# Clean previous build
echo "🧹 Cleaning previous installer build..."
rm -rf "$PAYLOAD_DIR"
rm -rf "$SCRIPTS_DIR"
rm -f "$INSTALLER_DIR"/*.pkg

# Create directory structure
echo "📁 Creating installer structure..."
mkdir -p "$PAYLOAD_DIR"
mkdir -p "$SCRIPTS_DIR"

# Build release binaries if they don't exist
if [ ! -f "$BUILD_DIR/harmonia" ] || [ ! -f "$BUILD_DIR/anigmad" ] || [ ! -f "$BUILD_DIR/anigma-cli" ]; then
    echo "🔨 Building release binaries..."
    cd "$PROJECT_ROOT"
    swift build -c release --product harmonia
    swift build -c release --product anigmad  
    swift build -c release --product anigma-cli
    swift build -c release --product ml-worker
    swift build -c release --product doctrine
    swift build -c release --product cathedral
    swift build -c release --product contextum
    swift build -c release --product proper
    cd "$SCRIPT_DIR"
fi

# Build Mac app bundle
echo "📱 Building Anigma.app bundle..."
"$SCRIPT_DIR/build_mac_app.sh"

# Copy app bundle to installer payload
if [ -d "$BUILD_DIR/Anigma.app" ]; then
    echo "📦 Copying Anigma.app to installer..."
    mkdir -p "$PAYLOAD_DIR/Applications"
    cp -R "$BUILD_DIR/Anigma.app" "$PAYLOAD_DIR/Applications/"
    echo "  ✓ Anigma.app → /Applications/"
else
    echo "  ⚠️  Warning: Anigma.app not found, skipping"
fi

# Copy binaries
echo "🔧 Copying binaries..."
mkdir -p "$PAYLOAD_DIR/usr/local/bin"
for binary in harmonia anigmad anigma-cli ml-worker doctrine cathedral contextum proper; do
    if [ -f "$BUILD_DIR/$binary" ]; then
        cp "$BUILD_DIR/$binary" "$PAYLOAD_DIR/usr/local/bin/"
        chmod +x "$PAYLOAD_DIR/usr/local/bin/$binary"
        echo "  ✓ $binary → /usr/local/bin/"
    else
        echo "  ⚠️  Warning: $binary not found"
    fi
done

# Create version file
echo "📝 Creating version file..."
cat > "$PAYLOAD_DIR/usr/local/bin/VERSION.txt" << EOF
Anigma $VERSION
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Binaries: harmonia, anigmad, anigma-cli, ml-worker, doctrine, cathedral, contextum, proper
App Bundle: $APP_BUNDLE
EOF

# Create preinstall script
echo "📝 Creating preinstall script..."
cat > "$SCRIPTS_DIR/preinstall" << 'PREINSTALL'
#!/bin/bash
set -e

echo "🔍 Checking for existing Anigma installation..."

# Check if app bundle exists
if [ -d "/Applications/Anigma.app" ]; then
    echo "📦 Found existing Anigma.app"
    
    # Check if it's a release candidate
    if [ -f "/Applications/Anigma.app/Contents/Info.plist" ]; then
        EXISTING_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "/Applications/Anigma.app/Contents/Info.plist" 2>/dev/null || echo "unknown")
        echo "   Current version: $EXISTING_VERSION"
        
        # Backup existing app
        BACKUP_DIR="/tmp/anigma_backup_$(date +%s)"
        echo "💾 Backing up to: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        cp -R "/Applications/Anigma.app" "$BACKUP_DIR/"
        echo "$BACKUP_DIR" > /tmp/anigma_last_backup.txt
    fi
    
    # Stop any running instances
    echo "🛑 Stopping running Anigma instances..."
    killall Anigma 2>/dev/null || true
    sleep 1
fi

# Check for existing binaries
if [ -f "/usr/local/bin/harmonia" ]; then
    echo "🔧 Found existing binaries"
    HARMONIA_VERSION=$(/usr/local/bin/harmonia --version 2>/dev/null || echo "unknown")
    echo "   Harmonia version: $HARMONIA_VERSION"
fi

# Check for running daemon
if pgrep -x "anigmad" > /dev/null; then
    echo "🛑 Stopping anigmad daemon..."
    /usr/local/bin/harmonia daemon stop 2>/dev/null || killall anigmad 2>/dev/null || true
    sleep 2
fi

echo "✅ Pre-installation checks complete"
exit 0
PREINSTALL

# Create postinstall script
echo "📝 Creating postinstall script..."
cat > "$SCRIPTS_DIR/postinstall" << 'POSTINSTALL'
#!/bin/bash
set -e

echo "🎉 Completing Anigma installation..."

# Set proper permissions
echo "🔒 Setting permissions..."
chmod +x /usr/local/bin/harmonia 2>/dev/null || true
chmod +x /usr/local/bin/anigmad 2>/dev/null || true
chmod +x /usr/local/bin/anigma-cli 2>/dev/null || true
chmod +x /usr/local/bin/ml-worker 2>/dev/null || true
chmod +x /usr/local/bin/doctrine 2>/dev/null || true
chmod +x /usr/local/bin/cathedral 2>/dev/null || true
chmod +x /usr/local/bin/contextum 2>/dev/null || true
chmod +x /usr/local/bin/proper 2>/dev/null || true

# Remove quarantine attributes
echo "🔓 Removing quarantine attributes..."
xattr -d com.apple.quarantine /Applications/Anigma.app 2>/dev/null || true
xattr -d com.apple.quarantine /usr/local/bin/harmonia 2>/dev/null || true
xattr -d com.apple.quarantine /usr/local/bin/anigmad 2>/dev/null || true
xattr -d com.apple.quarantine /usr/local/bin/anigma-cli 2>/dev/null || true
xattr -d com.apple.quarantine /usr/local/bin/ml-worker 2>/dev/null || true
xattr -d com.apple.quarantine /usr/local/bin/doctrine 2>/dev/null || true
xattr -d com.apple.quarantine /usr/local/bin/cathedral 2>/dev/null || true
xattr -d com.apple.quarantine /usr/local/bin/contextum 2>/dev/null || true
xattr -d com.apple.quarantine /usr/local/bin/proper 2>/dev/null || true

# Verify installation
echo "✅ Verifying installation..."
if [ -f "/usr/local/bin/VERSION.txt" ]; then
    cat /usr/local/bin/VERSION.txt
fi

echo ""
echo "✨ Anigma installation complete!"
echo ""
echo "To get started:"
echo "  1. Open /Applications/Anigma.app"
echo "  2. Or use CLI: harmonia --help"
echo ""

# Offer to restore backup if this was an update
if [ -f "/tmp/anigma_last_backup.txt" ]; then
    BACKUP_DIR=$(cat /tmp/anigma_last_backup.txt)
    echo "💾 Previous installation backed up to: $BACKUP_DIR"
    echo "   Remove backup manually if not needed."
fi

exit 0
POSTINSTALL

# Make scripts executable
chmod +x "$SCRIPTS_DIR/preinstall"
chmod +x "$SCRIPTS_DIR/postinstall"

# Build package
echo "📦 Building installer package..."
pkgbuild \
    --root "$PAYLOAD_DIR" \
    --identifier "com.anigma.installer" \
    --version "$VERSION" \
    --install-location "/" \
    --scripts "$SCRIPTS_DIR" \
    "$INSTALLER_DIR/$PKG_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Installer package created successfully!"
    echo ""
    echo "📍 Location: $INSTALLER_DIR/$PKG_NAME"
    
    # Generate checksums
    echo "🔐 Generating checksums..."
    cd "$INSTALLER_DIR"
    shasum -a 256 "$PKG_NAME" > SHA256SUMS.txt
    
    # Generate package info
    echo "📄 Generating package contents..."
    pkgutil --payload-files "$PKG_NAME" > package_contents.txt
    
    # Update INSTALL.md
    sed -i '' "s/AnigmaInstaller-1\.0\.0-rc[0-9]*/AnigmaInstaller-$VERSION/g" INSTALL.md
    
    echo ""
    echo "📊 Package Information:"
    ls -lh "$PKG_NAME"
    echo ""
    echo "SHA256:"
    cat SHA256SUMS.txt
    echo ""
    echo "🚀 Ready to install with:"
    echo "   sudo installer -pkg $PKG_NAME -target /"
else
    echo "❌ Failed to build installer package"
    exit 1
fi

# Cleanup
rm -rf /tmp/expanded_pkg 2>/dev/null || true

echo ""
echo "✨ Build complete!"
