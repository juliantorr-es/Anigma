#!/bin/bash

# Comprehensive build script for Anigma with all frameworks and plugins

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/enable_sccache.sh"
enable_sccache


echo "🔨 Starting comprehensive Anigma build..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf ./anigma/.build/arm64-apple-macosx/release/*.build
rm -rf ./anigma/Anigma/build/*

# Build all core libraries first
echo "📚 Building core libraries..."
cd ./anigma

# Build essential targets one by one to avoid the multiple producers issue
TARGETS=(
    "AnigmaFoundation"
    "CoreUtilities"
    "RendererKit"
    "DocumentRenderKit"
    "DocumentIRKit"
    "ObservabilityKit"
    "TelemetryCore"
    "AnigmaDaemonCore"
    "PlatformAdapters"
    "RuntimeOrchestrator"
    "AnigmaUI"
    "ObservatoriumModule"
)

for target in "${TARGETS[@]}"; do
    echo "  Building $target..."
    swift build -c release --target "$target" 2>&1 | grep -E "(error|Build of target)" | tail -5
    if [ $? -ne 0 ]; then
        echo "  ⚠️  Warning: Failed to build $target, continuing..."
    fi
done

echo "🎯 Building main executables..."

# Build executables
EXECUTABLES=(
    "anigmad"
)

for exec in "${EXECUTABLES[@]}"; do
    echo "  Building $exec..."
    swift build -c release --target "$exec" 2>&1 | grep -E "(error|Build of target)" | tail -5
    if [ $? -ne 0 ]; then
        echo "  ⚠️  Warning: Failed to build $exec, continuing..."
    fi
done

echo "📦 Creating app bundle structure..."

# Create app bundle structure
APP_BUNDLE="./anigma/Anigma/build/Anigma.app"
mkdir -p "$APP_BUNDLE/Contents/{MacOS,Resources,Frameworks,PlugIns,SharedSupport}"

# Copy main executable
if [ -f "./anigma/.build/arm64-apple-macosx/release/anigmad" ]; then
    cp "./anigma/.build/arm64-apple-macosx/release/anigmad" "$APP_BUNDLE/Contents/MacOS/"
    chmod +x "$APP_BUNDLE/Contents/MacOS/anigmad"
    echo "  ✓ Copied anigmad executable"
else
    echo "  ✗ Error: anigmad executable not found!"
fi

echo "🔗 Copying frameworks..."

# Find and copy all frameworks
FRAMEWORKS=$(find ./anigma/.build/arm64-apple-macosx/release -name "*.framework" -type d 2>/dev/null)
for framework in $FRAMEWORKS; do
    framework_name=$(basename "$framework")
    echo "  Copying $framework_name..."
    cp -R "$framework" "$APP_BUNDLE/Contents/Frameworks/"
done

echo "🔗 Copying dynamic libraries..."

# Find and copy all dylibs
DYLIBS=$(find ./anigma/.build/arm64-apple-macosx/release -name "*.dylib" -type f 2>/dev/null)
for dylib in $DYLIBS; do
    dylib_name=$(basename "$dylib")
    echo "  Copying $dylib_name..."
    cp "$dylib" "$APP_BUNDLE/Contents/Frameworks/"
done

echo "📄 Creating Info.plist..."

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Anigma</string>
    <key>CFBundleExecutable</key>
    <string>anigmad</string>
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

echo "🎨 Creating app icon..."

# Create app icon
if [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]; then
    sips -s format png -z 512 512 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns --out "$APP_BUNDLE/Contents/Resources/AppIcon.png"
    echo "  ✓ Created AppIcon.png"
fi

echo "📋 Creating PkgInfo..."

echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "✅ App bundle created successfully!"
echo "📍 Location: $APP_BUNDLE"
echo ""
echo "Bundled components:"
echo "  Executables:"
ls -lh "$APP_BUNDLE/Contents/MacOS/" | grep -v "^d" | awk '{print "    " $9 " (" $5 ")"}'
echo "  Frameworks:"
ls -lh "$APP_BUNDLE/Contents/Frameworks/" | grep -v "^d" | awk '{print "    " $9 " (" $5 ")"}'
echo ""
echo "To run the daemon:"
echo "  open \"$APP_BUNDLE\""
