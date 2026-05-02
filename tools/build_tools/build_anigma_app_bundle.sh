#!/bin/bash

# Build script for creating a complete Anigma.app bundle
# This script builds the necessary components and packages them into a proper app bundle

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/enable_sccache.sh"
enable_sccache


echo "🔨 Starting Anigma App Bundle Build..."
echo ""

# Configuration
PROJECT_ROOT="./anigma"
BUILD_DIR="$PROJECT_ROOT/.build/arm64-apple-macosx/release"
APP_BUNDLE="$PROJECT_ROOT/Anigma/build/Anigma.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"
PLUGINS="$CONTENTS/PlugIns"
SHARED_SUPPORT="$CONTENTS/SharedSupport"

echo "Configuration:"
echo "  Project Root: $PROJECT_ROOT"
echo "  Build Directory: $BUILD_DIR"
echo "  App Bundle: $APP_BUNDLE"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR/*.build"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS" "$PLUGINS" "$SHARED_SUPPORT"

# Build strategy: Build essential components one by one
cd "$PROJECT_ROOT"

echo "📚 Building core components..."
echo ""

# Build AnigmaFoundation first (has no dependencies)
echo "[1/8] Building AnigmaFoundation..."
if swift build -c release --target AnigmaFoundation 2>&1 | grep -q "Build of target"; then
    echo "  ✓ AnigmaFoundation built successfully"
else
    echo "  ✗ Failed to build AnigmaFoundation"
    exit 1
fi

# Build CoreUtilities
echo "[2/8] Building CoreUtilities..."
if swift build -c release --target CoreUtilities 2>&1 | grep -q "Build of target"; then
    echo "  ✓ CoreUtilities built successfully"
else
    echo "  ✗ Failed to build CoreUtilities"
    exit 1
fi

# Build AnigmaDaemonCore
echo "[3/8] Building AnigmaDaemonCore..."
if swift build -c release --target AnigmaDaemonCore 2>&1 | grep -q "Build of target"; then
    echo "  ✓ AnigmaDaemonCore built successfully"
else
    echo "  ✗ Failed to build AnigmaDaemonCore"
    exit 1
fi

# Build TelemetryCore
echo "[4/8] Building TelemetryCore..."
if swift build -c release --target TelemetryCore 2>&1 | grep -q "Build of target"; then
    echo "  ✓ TelemetryCore built successfully"
else
    echo "  ✗ Failed to build TelemetryCore"
    exit 1
fi

# Build PlatformAdapters
echo "[5/8] Building PlatformAdapters..."
if swift build -c release --target PlatformAdapters 2>&1 | grep -q "Build of target"; then
    echo "  ✓ PlatformAdapters built successfully"
else
    echo "  ✗ Failed to build PlatformAdapters"
    exit 1
fi

# Build RuntimeOrchestrator
echo "[6/8] Building RuntimeOrchestrator..."
if swift build -c release --target RuntimeOrchestrator 2>&1 | grep -q "Build of target"; then
    echo "  ✓ RuntimeOrchestrator built successfully"
else
    echo "  ✗ Failed to build RuntimeOrchestrator"
    exit 1
fi

# Build AnigmaUI
echo "[7/8] Building AnigmaUI..."
if swift build -c release --target AnigmaUI 2>&1 | grep -q "Build of target"; then
    echo "  ✓ AnigmaUI built successfully"
else
    echo "  ✗ Failed to build AnigmaUI"
    exit 1
fi

# Build ObservatoriumModule
echo "[8/8] Building ObservatoriumModule..."
if swift build -c release --target ObservatoriumModule 2>&1 | grep -q "Build of target"; then
    echo "  ✓ ObservatoriumModule built successfully"
else
    echo "  ✗ Failed to build ObservatoriumModule"
    exit 1
fi

echo ""
echo "🎯 Building main executables..."
echo ""

# Build the daemon
echo "[1/2] Building anigmad..."
if swift build -c release --target anigmad 2>&1 | grep -q "Build of target"; then
    echo "  ✓ anigmad built successfully"
else
    echo "  ✗ Failed to build anigmad"
    exit 1
fi

# Build the main app
echo "[2/2] Building AnigmaAppMac..."
if swift build -c release --target AnigmaAppMac 2>&1 | grep -q "Build of target"; then
    echo "  ✓ AnigmaAppMac built successfully"
else
    echo "  ✗ Failed to build AnigmaAppMac"
    exit 1
fi

echo ""
echo "📦 Packaging app bundle..."
echo ""

# Copy main executable
if [ -f "$BUILD_DIR/AnigmaAppMac" ]; then
    cp "$BUILD_DIR/AnigmaAppMac" "$MACOS/AnigmaAppMac"
    chmod +x "$MACOS/AnigmaAppMac"
    echo "  ✓ Copied AnigmaAppMac executable"
else
    echo "  ✗ Error: AnigmaAppMac executable not found!"
    echo "  Looking in: $BUILD_DIR"
    ls -la "$BUILD_DIR" | head -20
    exit 1
fi

# Copy daemon executable
if [ -f "$BUILD_DIR/anigmad" ]; then
    cp "$BUILD_DIR/anigmad" "$MACOS/anigmad"
    chmod +x "$MACOS/anigmad"
    echo "  ✓ Copied anigmad executable"
else
    echo "  ✗ Error: anigmad executable not found!"
    exit 1
fi

echo ""
echo "🔗 Copying frameworks and libraries..."
echo ""

# Find and copy all frameworks
FRAMEWORKS_FOUND=$(find "$BUILD_DIR" -name "*.framework" -type d 2>/dev/null)
if [ -n "$FRAMEWORKS_FOUND" ]; then
    for framework in $FRAMEWORKS_FOUND; do
        framework_name=$(basename "$framework")
        echo "  Copying framework: $framework_name..."
        cp -R "$framework" "$FRAMEWORKS/"
    done
    echo "  ✓ Copied $(echo "$FRAMEWORKS_FOUND" | wc -w) frameworks"
else
    echo "  ⚠️  No frameworks found (this is expected for Swift Package Manager builds)"
fi

# Find and copy all dylibs
DYLIBS_FOUND=$(find "$BUILD_DIR" -name "*.dylib" -type f 2>/dev/null)
if [ -n "$DYLIBS_FOUND" ]; then
    for dylib in $DYLIBS_FOUND; do
        dylib_name=$(basename "$dylib")
        echo "  Copying library: $dylib_name..."
        cp "$dylib" "$FRAMEWORKS/"
    done
    echo "  ✓ Copied $(echo "$DYLIBS_FOUND" | wc -w) libraries"
else
    echo "  ⚠️  No dynamic libraries found"
fi

echo ""
echo "📄 Creating app metadata..."
echo ""

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Anigma</string>
    <key>CFBundleExecutable</key>
    <string>AnigmaAppMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.anigma.app</string>
    <key>CFBundleName</key>
    <string>Anigma</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
PLIST

echo "  ✓ Created Info.plist"

# Create PkgInfo
echo "APPL????" > "$CONTENTS/PkgInfo"
echo "  ✓ Created PkgInfo"

# Create app icon
if [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]; then
    sips -s format png -z 512 512 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns --out "$RESOURCES/AppIcon.png"
    echo "  ✓ Created AppIcon.png"
fi

echo ""
echo "=========================================="
echo "✅ Anigma App Bundle Created Successfully!"
echo "=========================================="
echo ""
echo "Location: $APP_BUNDLE"
echo ""
echo "Bundled Components:"
echo "  Executables:"
for file in "$MACOS"/*; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "    - $(basename "$file") ($size)"
    fi
done
echo "  Frameworks:"
if [ "$(ls -A "$FRAMEWORKS")" ]; then
    for item in "$FRAMEWORKS"/*; do
        if [ -d "$item" ]; then
            size=$(du -sh "$item" | cut -f1)
            echo "    - $(basename "$item") ($size)"
        fi
    done
else
    echo "    (none - using dynamic linking)"
fi
echo ""
echo "To run the application:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "To run the daemon:"
echo "  $APP_BUNDLE/Contents/MacOS/anigmad"
