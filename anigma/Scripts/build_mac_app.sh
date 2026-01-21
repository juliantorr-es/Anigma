#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build/release"
APP_NAME="Anigma"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "=========================================="
echo "Building Anigma Mac App Bundle"
echo "=========================================="
echo ""

# Step 1: Build all executables
echo "[1/5] Building all executable products..."
cd "$PROJECT_ROOT"

PRODUCTS=(
    "anigma-app"
    "anigmad"
    "harmonia"
    "ml-worker"
    "doctrine"
    "anigma-ast-services"
    "harmonia-surface"
    "outlineum-zine"
    "diaplasion-pipeline"
    "accessum-flow"
)

for product in "${PRODUCTS[@]}"; do
    echo "  Building $product..."
    if ! swift build -c release --product "$product" 2>&1 | grep -v "warning:"; then
        echo "  ⚠️  Warning: Failed to build $product (may not exist)"
    fi
done

echo ""
echo "[2/5] Creating app bundle structure..."

# Create app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Step 2: Determine the correct build output path
if [ -d "$PROJECT_ROOT/.build/arm64-apple-macosx/release" ]; then
    BIN_PATH="$PROJECT_ROOT/.build/arm64-apple-macosx/release"
elif [ -d "$PROJECT_ROOT/.build/x86_64-apple-macosx/release" ]; then
    BIN_PATH="$PROJECT_ROOT/.build/x86_64-apple-macosx/release"
else
    BIN_PATH="$PROJECT_ROOT/.build/release"
fi

echo "  Using binary path: $BIN_PATH"
echo ""

# Step 3: Copy main executable
echo "[3/5] Copying main executable..."
if [ -f "$BIN_PATH/anigma-app" ]; then
    cp "$BIN_PATH/anigma-app" "$MACOS/$APP_NAME"
    chmod +x "$MACOS/$APP_NAME"
    echo "  ✓ Main executable: $APP_NAME"
else
    echo "  ✗ Error: anigma-app executable not found!"
    exit 1
fi

echo ""
echo "[4/5] Copying additional binaries..."

BINARIES=(
    "anigmad"
    "harmonia"
    "ml-worker"
    "doctrine"
    "anigma-ast-services"
    "harmonia-surface"
    "outlineum-zine"
    "diaplasion-pipeline"
    "accessum-flow"
)

for binary in "${BINARIES[@]}"; do
    if [ -f "$BIN_PATH/$binary" ]; then
        echo "  ✓ Copying $binary..."
        cp "$BIN_PATH/$binary" "$MACOS/"
        chmod +x "$MACOS/$binary"
    else
        echo "  ⚠️  Warning: $binary not found (skipping)"
    fi
done

echo ""
echo "[5/5] Creating app metadata..."

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Anigma</string>
    <key>CFBundleIdentifier</key>
    <string>com.anigma.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
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
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$CONTENTS/PkgInfo"

# Create VERSION file with binary list
cat > "$MACOS/VERSION.txt" << EOF
Anigma v1.0.0
Build Date: $(date +"%Y-%m-%d %H:%M:%S")

Bundled Binaries:
EOF

for binary in "${BINARIES[@]}"; do
    if [ -f "$MACOS/$binary" ]; then
        echo "  - $binary" >> "$MACOS/VERSION.txt"
    fi
done

echo ""
echo "=========================================="
echo "✓ App bundle created successfully!"
echo "=========================================="
echo ""
echo "Location: $APP_BUNDLE"
echo ""
echo "Bundled binaries:"
ls -lh "$MACOS" | grep -v "^d" | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "To run the app:"
echo "  open \"$APP_BUNDLE\""
echo ""
