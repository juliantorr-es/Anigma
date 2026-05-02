#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/enable_sccache.sh"
enable_sccache

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

# Step 1: Build launcher app and any optional companion binaries
echo "[1/5] Building launcher and optional companion binaries..."
cd "$PROJECT_ROOT"

REQUIRED_PRODUCT="anigma-app"
OPTIONAL_PRODUCTS=(
    "anigmad"
    "harmonia"
    "ml-worker"
)

echo "  Building $REQUIRED_PRODUCT..."
swift build -c release --product "$REQUIRED_PRODUCT" 2>&1 | grep -v "warning:" || {
    echo "  ✗ Error: failed to build required product $REQUIRED_PRODUCT"
    exit 1
}

for product in "${OPTIONAL_PRODUCTS[@]}"; do
    echo "  Building optional $product..."
    if ! swift build -c release --product "$product" 2>&1 | grep -v "warning:"; then
        echo "  ⚠️  Warning: Failed to build optional product $product"
    fi
done

echo ""
echo "[2/5] Creating app bundle structure..."

# Create app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Step 2: Determine the correct build output path
BIN_PATH=""
for candidate in \
    "$PROJECT_ROOT/.build/arm64-apple-macosx/release" \
    "$PROJECT_ROOT/.build/x86_64-apple-macosx/release" \
    "$PROJECT_ROOT/.build/release" \
    "$PROJECT_ROOT/.build/arm64-apple-macosx/debug" \
    "$PROJECT_ROOT/.build/x86_64-apple-macosx/debug" \
    "$PROJECT_ROOT/.build/debug"
do
    if [ -f "$candidate/anigma-app" ] || [ -f "$candidate/anigmad" ] || [ -f "$candidate/harmonia" ] || [ -f "$candidate/ml-worker" ]; then
        BIN_PATH="$candidate"
        break
    fi
done

if [ -z "$BIN_PATH" ]; then
    echo "No build output found with app binaries in .build"
    exit 1
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

PDFIUM_LIB="$PROJECT_ROOT/Vendor/lib/libpdfium.dylib"
if [ -f "$PDFIUM_LIB" ]; then
    echo "  ✓ Copying libpdfium.dylib..."
    cp "$PDFIUM_LIB" "$BIN_PATH/libpdfium.dylib"
    chmod +w "$BIN_PATH/libpdfium.dylib"
    install_name_tool -id "@executable_path/libpdfium.dylib" "$BIN_PATH/libpdfium.dylib" 2>/dev/null || true
    cp "$PDFIUM_LIB" "$MACOS/libpdfium.dylib"
    chmod +w "$MACOS/libpdfium.dylib"
    install_name_tool -id "@executable_path/libpdfium.dylib" "$MACOS/libpdfium.dylib" 2>/dev/null || true
else
    echo "  ⚠️  Warning: libpdfium.dylib not found (skipping)"
fi

TESTING_FRAMEWORK="/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework"
if [ -d "$TESTING_FRAMEWORK" ]; then
    echo "  ✓ Copying Testing.framework..."
    rm -rf "$BIN_PATH/Testing.framework"
    cp -R "$TESTING_FRAMEWORK" "$BIN_PATH/Testing.framework"
    rm -rf "$MACOS/Testing.framework"
    cp -R "$TESTING_FRAMEWORK" "$MACOS/Testing.framework"
else
    echo "  ⚠️  Warning: Testing.framework not found (skipping)"
fi

echo "  ✓ Rewriting bundled library paths for launcher..."
if [ -f "$MACOS/$APP_NAME" ]; then
    chmod +w "$MACOS/$APP_NAME"
    install_name_tool -change "./libpdfium.dylib" "@executable_path/libpdfium.dylib" "$MACOS/$APP_NAME" 2>/dev/null || true
fi

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
