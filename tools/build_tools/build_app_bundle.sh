#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/enable_sccache.sh"
enable_sccache


echo "=== Building Phase 3 Prototype as .app Bundle ==="

# Build the executable
echo "1. Building executable..."
cd "$(dirname "$0")/anigma"
swift build --product anigma-app -c debug

# Create .app bundle structure
echo "2. Creating .app bundle..."
APP_NAME="AnigmaPrototype.app"
BUILD_DIR=".build/debug"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME"

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy executable
echo "3. Copying executable..."
cp "$BUILD_DIR/anigma-app" "$BUNDLE_DIR/Contents/MacOS/AnigmaPrototype"

# Copy Info.plist
echo "4. Copying Info.plist..."
cp "../anigma/Sources/AnigmaAppMac/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"

# Make executable
chmod +x "$BUNDLE_DIR/Contents/MacOS/AnigmaPrototype"

echo ""
echo "✅ App bundle created: $BUNDLE_DIR"
echo ""
echo "To launch:"
echo "  open $BUNDLE_DIR"
echo ""
echo "Or from Xcode: Build normally, then run this script, then open the .app"
