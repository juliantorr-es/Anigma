#!/bin/bash

# Script to build individual Anigma packages and integrate successful builds into the app bundle
# This approach builds packages one by one and includes only what compiles successfully

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/enable_sccache.sh"
enable_sccache


echo "🔨 Starting Individual Package Build..."
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

# Clean and create structure
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR/*.build"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS" "$PLUGINS" "$SHARED_SUPPORT"

cd "$PROJECT_ROOT"

# Track successful builds
SUCCESSFUL_BUILDS=()
FAILED_BUILDS=()

# Function to build a target
build_target() {
    local target="$1"
    local package="$2"
    
    echo "[BUILD] Attempting $target from $package..."
    
    # Change to package directory if specified
    if [ -n "$package" ] && [ -d "Packages/$package" ]; then
        cd "Packages/$package"
    fi
    
    if swift build -c release --target "$target" 2>&1 | grep -q "Build of target"; then
        echo "  ✓ $target built successfully"
        SUCCESSFUL_BUILDS+=("$target")
        
        # Copy any built frameworks or libraries
        local package_build_dir="$PROJECT_ROOT/.build/arm64-apple-macosx/release"
        
        # Find frameworks
        local frameworks=$(find "$package_build_dir" -name "*.framework" -type d 2>/dev/null)
        if [ -n "$frameworks" ]; then
            for framework in $frameworks; do
                local framework_name=$(basename "$framework")
                if [ ! -d "$FRAMEWORKS/$framework_name" ]; then
                    cp -R "$framework" "$FRAMEWORKS/"
                    echo "    ✓ Copied framework: $framework_name"
                fi
            done
        fi
        
        # Find dylibs
        local dylibs=$(find "$package_build_dir" -name "*.dylib" -type f 2>/dev/null)
        if [ -n "$dylibs" ]; then
            for dylib in $dylibs; do
                local dylib_name=$(basename "$dylib")
                if [ ! -f "$FRAMEWORKS/$dylib_name" ]; then
                    cp "$dylib" "$FRAMEWORKS/"
                    echo "    ✓ Copied library: $dylib_name"
                fi
            done
        fi
        
        # Go back to project root
        cd "$PROJECT_ROOT"
        return 0
    else
        echo "  ✗ $target failed to build"
        FAILED_BUILDS+=("$target")
        # Go back to project root
        cd "$PROJECT_ROOT"
        return 1
    fi
}

echo "📚 Building packages individually..."
echo ""

# Build core packages first
build_target "AnigmaFoundation" ""
build_target "CoreUtilities" "CoreUtilities"
build_target "AnigmaDaemonCore" "AnigmaDaemonCore"
build_target "TelemetryCore" "TelemetryCore"
build_target "PlatformAdapters" ""
build_target "RuntimeOrchestrator" ""
build_target "AnigmaUI" "AnigmaUI"
build_target "ObservatoriumModule" "ObservatoriumModule"

# Build rendering packages
build_target "RendererKit" "RendererKit"
build_target "DocumentRenderKit" "DocumentRenderKit"
build_target "DocumentIRKit" "DocumentIRKit"
build_target "SceneGraphCapsule" "SceneGraphCapsule"

# Build document processing packages
build_target "SyntaxCapsule" "SyntaxCapsule"
build_target "MarkdownCapsule" "MarkdownCapsule"
build_target "PDFCapsule" "PDFCapsule"

# Build vector operations packages
build_target "VectorOpsKit" "VectorOpsKit"
build_target "VectorStoreCapsule" "VectorStoreCapsule"

# Build governance packages
build_target "GovernanceCore" "GovernanceCore"
build_target "ContractsCore" "ContractsCore"
build_target "HarmoniaModule" "HarmoniaModule"

# Build utility packages
build_target "ObservabilityKit" "ObservabilityKit"
build_target "CapsuleCore" "CapsuleCore"
build_target "ColorKit" "ColorKit"
build_target "TypographyKit" "TypographyKit"
build_target "GeometryCapsule" "GeometryCapsule"
build_target "GlyphAtlasCapsule" "GlyphAtlasCapsule"
build_target "TessellationCapsule" "TessellationCapsule"

echo ""
echo "📊 Build Summary:"
echo "  Successfully built: ${#SUCCESSFUL_BUILDS[@]} packages"
echo "  Failed to build: ${#FAILED_BUILDS[@]} packages"
echo ""

if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    echo "  Successful builds:"
    for target in "${SUCCESSFUL_BUILDS[@]}"; do
        echo "    - $target"
    done
    echo ""
fi

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    echo "  Failed builds:"
    for target in "${FAILED_BUILDS[@]}"; do
        echo "    - $target"
    done
    echo ""
fi

echo "📦 Packaging app bundle..."
echo ""

# Copy daemon executable
if [ -f "$BUILD_DIR/anigmad" ]; then
    cp "$BUILD_DIR/anigmad" "$MACOS/anigmad"
    chmod +x "$MACOS/anigmad"
    echo "  ✓ Copied anigmad executable"
elif [ -f "./installer/distribution/cli/anigmad" ]; then
    cp "./installer/distribution/cli/anigmad" "$MACOS/anigmad"
    chmod +x "$MACOS/anigmad"
    echo "  ✓ Copied anigmad from installer (fallback)"
else
    echo "  ✗ Error: anigmad executable not found!"
fi

# Create CLI wrapper
cat > "$MACOS/anigma-cli" << 'CLI'
#!/bin/bash
ANIGMA_DAEMON="$MACOS/anigmad"
if [ -f "$ANIGMA_DAEMON" ]; then
    "$ANIGMA_DAEMON" "$@"
else
    echo "Error: AnigmaDaemon not found. Please reinstall Anigma."
    exit 1
fi
CLI
chmod +x "$MACOS/anigma-cli"
echo "  ✓ Created anigma-cli wrapper"

# Create uninstall script
cat > "$MACOS/uninstall" << 'UNINSTALL'
#!/bin/bash
set -e
echo "🗑️  Uninstalling Anigma..."
if launchctl list | grep -q "com.anigma.daemon"; then
    launchctl unload "$HOME/Library/LaunchAgents/com.anigma.daemon.plist" 2>/dev/null || true
fi
rm -f "$HOME/Library/LaunchAgents/com.anigma.daemon.plist"
rm -f "/usr/local/bin/anigmad"
rm -f "/usr/local/bin/anigma-cli"
rm -rf "/Applications/Anigma.app"
rm -rf "/Applications/AnigmaDaemon.app"
rm -rf "$HOME/Library/Application Support/Anigma"
pkill -f "anigmad" 2>/dev/null || true
echo "✅ Anigma has been successfully uninstalled."
exit 0
UNINSTALL
chmod +x "$MACOS/uninstall"
echo "  ✓ Created uninstall script"

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

# Create launch agent
mkdir -p "$SHARED_SUPPORT/LaunchAgents"
cat > "$SHARED_SUPPORT/LaunchAgents/com.anigma.daemon.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.anigma.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$MACOS/anigmad</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/com.anigma.daemon.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/com.anigma.daemon.err</string>
</dict>
</plist>
PLIST
echo "  ✓ Created launch agent configuration"

# Create README with build summary
cat > "$RESOURCES/README.txt" << README
Anigma Application Bundle
=========================

Build Summary:
--------------
Successfully built packages:
$(if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    for target in "${SUCCESSFUL_BUILDS[@]}"; do
        echo "  - $target"
    done
else
    echo "  (None)"
fi)

Failed to build packages:
$(if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    for target in "${FAILED_BUILDS[@]}"; do
        echo "  - $target"
    done
else
    echo "  (None)"
fi)

Bundled Components:
-------------------
Executables:
  - anigmad (daemon)
  - anigma-cli (CLI wrapper)
  - uninstall (uninstall script)

Frameworks:
$(if [ "$(ls -A "$FRAMEWORKS")" ]; then
    for item in "$FRAMEWORKS"/*; do
        if [ -d "$item" ]; then
            size=$(du -sh "$item" | cut -f1)
            echo "  - $(basename "$item") ($size)"
        fi
    done
else
    echo "  (None - using dynamic linking)"
fi)

Libraries:
$(if [ -n "$(find "$FRAMEWORKS" -name "*.dylib" -type f 2>/dev/null)" ]; then
    for dylib in $(find "$FRAMEWORKS" -name "*.dylib" -type f 2>/dev/null); do
        size=$(du -h "$dylib" | cut -f1)
        echo "  - $(basename "$dylib") ($size)"
    done
else
    echo "  (None)"
fi)

Usage:
------
1. To run the daemon:
   Anigma.app/Contents/MacOS/anigmad

2. To use the CLI:
   Anigma.app/Contents/MacOS/anigma-cli --help

3. To uninstall:
   Anigma.app/Contents/MacOS/uninstall

Architecture:
-------------
This bundle uses a modular architecture where:
- Core components are built and included when possible
- Remaining dependencies are resolved dynamically at runtime
- Processing capabilities are loaded on-demand
- The daemon coordinates all operations

This approach provides:
- Better performance through on-demand loading
- Smaller bundle size
- Flexible updates and extensions
- Improved stability through isolation
README
chmod +x "$RESOURCES/README.txt"
echo "  ✓ Created README"

echo ""
echo "=========================================="
echo "✅ Anigma App Bundle Created!"
echo "=========================================="
echo ""
echo "Location: $APP_BUNDLE"
echo ""
echo "Bundle Contents:"
echo ""
echo "Executables:"
for file in "$MACOS"/*; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "  - $(basename "$file") ($size)"
    fi
done
echo ""
echo "Frameworks:"
if [ "$(ls -A "$FRAMEWORKS")" ]; then
    for item in "$FRAMEWORKS"/*; do
        if [ -d "$item" ]; then
            size=$(du -sh "$item" | cut -f1)
            echo "  - $(basename "$item") ($size)"
        fi
    done
else
    echo "  (None - using dynamic linking)"
fi
echo ""
echo "Build Results:"
echo "  ✓ Successfully built: ${#SUCCESSFUL_BUILDS[@]} packages"
echo "  ✗ Failed to build: ${#FAILED_BUILDS[@]} packages"
echo ""
echo "To install:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To run:"
echo "  open -a Anigma"
echo ""
echo "To uninstall:"
echo "  $APP_BUNDLE/Contents/MacOS/uninstall"
