#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build/release"
APP_NAME="AnigmaBinariesTest"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "=========================================="
echo "Creating Test Bundle for Binaries"
echo "=========================================="
echo ""

# Determine the correct build output path
BIN_PATH=""
for candidate in \
    "$PROJECT_ROOT/.build/arm64-apple-macosx/release" \
    "$PROJECT_ROOT/.build/x86_64-apple-macosx/release" \
    "$PROJECT_ROOT/.build/release" \
    "$PROJECT_ROOT/.build/arm64-apple-macosx/debug" \
    "$PROJECT_ROOT/.build/x86_64-apple-macosx/debug" \
    "$PROJECT_ROOT/.build/debug"
do
    if [ -f "$candidate/harmonia" ] || [ -f "$candidate/anigmad" ] || [ -f "$candidate/ml-worker" ]; then
        BIN_PATH="$candidate"
        break
    fi
done

if [ -z "$BIN_PATH" ]; then
    echo "No build output found with bundled binaries in .build"
    exit 1
fi

echo "[1/3] Creating app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Create a simple launcher script
cat > "$MACOS/$APP_NAME" << 'LAUNCHER'
#!/bin/bash
# Simple launcher to show available binaries

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Anigma Binaries Test Bundle"
echo "=========================================="
echo ""
echo "Available binaries:"
echo ""

for binary in "$BUNDLE_DIR"/*; do
    if [ -x "$binary" ] && [ -f "$binary" ] && [ "$(basename "$binary")" != "AnigmaBinariesTest" ]; then
        NAME="$(basename "$binary")"
        SIZE="$(du -h "$binary" | awk '{print $1}')"
        echo "  - $NAME ($SIZE)"
    fi
done

echo ""
echo "To run a binary:"
echo "  $BUNDLE_DIR/<binary-name> <arguments>"
echo ""
echo "Examples:"
echo "  $BUNDLE_DIR/harmonia --help"
echo ""
LAUNCHER

chmod +x "$MACOS/$APP_NAME"

echo "[2/3] Copying binaries..."

BINARIES=(
    "anigmad"
    "harmonia"
    "ml-worker"
)

COPIED_COUNT=0

for binary in "${BINARIES[@]}"; do
    if [ -f "$BIN_PATH/$binary" ]; then
        echo "  ✓ $binary"
        cp "$BIN_PATH/$binary" "$MACOS/"
        chmod +x "$MACOS/$binary"
        ((COPIED_COUNT++))
    else
        echo "  ⚠️  $binary (not found)"
    fi
done

PDFIUM_LIB="$PROJECT_ROOT/Vendor/lib/libpdfium.dylib"
if [ -f "$PDFIUM_LIB" ]; then
    echo "  ✓ libpdfium.dylib"
    cp "$PDFIUM_LIB" "$MACOS/libpdfium.dylib"
else
    echo "  ⚠️  libpdfium.dylib (not found)"
fi

TESTING_FRAMEWORK="/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework"
if [ -d "$TESTING_FRAMEWORK" ]; then
    echo "  ✓ Testing.framework"
    rm -rf "$MACOS/Testing.framework"
    cp -R "$TESTING_FRAMEWORK" "$MACOS/Testing.framework"
else
    echo "  ⚠️  Testing.framework (not found)"
fi

echo ""
echo "[3/3] Creating Info.plist..."

cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>AnigmaBinariesTest</string>
    <key>CFBundleIdentifier</key>
    <string>com.anigma.binaries-test</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Anigma Binaries Test</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "APPL????" > "$CONTENTS/PkgInfo"

echo ""
echo "=========================================="
echo "✓ Test bundle created successfully!"
echo "=========================================="
echo ""
echo "Location: $APP_BUNDLE"
echo "Bundled: $COPIED_COUNT binaries"
echo ""
echo "To run the launcher:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "Or run binaries directly:"
echo "  \"$APP_BUNDLE/Contents/MacOS/harmonia\" --help"
echo ""
