#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build/release"
BUNDLE_DIR="$BUILD_DIR/AnigmaBinaries"

echo "=========================================="
echo "Bundling Anigma Binaries"
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
    if [ -f "$candidate/anigmad" ] || [ -f "$candidate/harmonia" ] || [ -f "$candidate/ml-worker" ]; then
        BIN_PATH="$candidate"
        break
    fi
done

if [ -z "$BIN_PATH" ]; then
    echo "No build output found with bundled binaries in .build"
    exit 1
fi

echo "Using binary path: $BIN_PATH"
echo ""

# Create bundle directory
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# List of binaries to bundle
BINARIES=(
    "anigmad"
    "harmonia"
    "ml-worker"
)

echo "Copying binaries..."
COPIED_COUNT=0

for binary in "${BINARIES[@]}"; do
    if [ -f "$BIN_PATH/$binary" ]; then
        echo "  ✓ $binary ($(du -h "$BIN_PATH/$binary" | awk '{print $1}'))"
        cp "$BIN_PATH/$binary" "$BUNDLE_DIR/"
        chmod +x "$BUNDLE_DIR/$binary"
        ((COPIED_COUNT++))
    else
        echo "  ⚠️  $binary (not found, skipping)"
    fi
done

PDFIUM_LIB="$PROJECT_ROOT/Vendor/lib/libpdfium.dylib"
if [ -f "$PDFIUM_LIB" ]; then
    echo "  ✓ libpdfium.dylib"
    cp "$PDFIUM_LIB" "$BUNDLE_DIR/libpdfium.dylib"
    chmod +w "$BUNDLE_DIR/libpdfium.dylib"
    install_name_tool -id "@executable_path/libpdfium.dylib" "$BUNDLE_DIR/libpdfium.dylib" 2>/dev/null || true
else
    echo "  ⚠️  libpdfium.dylib (not found, skipping)"
fi

TESTING_FRAMEWORK="/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework"
if [ -d "$TESTING_FRAMEWORK" ]; then
    echo "  ✓ Testing.framework"
    rm -rf "$BUNDLE_DIR/Testing.framework"
    cp -R "$TESTING_FRAMEWORK" "$BUNDLE_DIR/Testing.framework"
else
    echo "  ⚠️  Testing.framework (not found, skipping)"
fi

# Create VERSION file
cat > "$BUNDLE_DIR/VERSION.txt" << EOF
Anigma Binaries v1.0.0
Build Date: $(date +"%Y-%m-%d %H:%M:%S")
Architecture: $(uname -m)

Bundled Binaries ($COPIED_COUNT total):
EOF

for binary in "${BINARIES[@]}"; do
    if [ -f "$BUNDLE_DIR/$binary" ]; then
        SIZE=$(du -h "$BUNDLE_DIR/$binary" | awk '{print $1}')
        echo "  - $binary ($SIZE)" >> "$BUNDLE_DIR/VERSION.txt"
    fi
done

# Create README
cat > "$BUNDLE_DIR/README.md" << 'EOF'
# Anigma Binaries

This directory contains all the core Anigma executable binaries.

## Binaries

- **anigmad**: Background daemon for system services (gRPC server)
- **harmonia**: CLI for AI coding assistance
- **ml-worker**: ML inference worker process (MLX-based)

## Usage

Each binary has its own help:

```bash
./anigmad --help
./harmonia --help
./ml-worker --help
# etc.
```

## Integration with macOS App

These binaries are designed to be bundled into `Anigma.app/Contents/MacOS/`.
The SwiftUI app can launch them using `Process` or `NSTask`.

To find binaries from within the app bundle:

```swift
let bundlePath = Bundle.main.bundlePath
let binaryPath = bundlePath + "/Contents/MacOS/harmonia"
```
EOF

echo ""
echo "=========================================="
echo "✓ Binaries bundled successfully!"
echo "=========================================="
echo ""
echo "Location: $BUNDLE_DIR"
echo "Bundled: $COPIED_COUNT binaries"
echo ""
echo "Total size: $(du -sh "$BUNDLE_DIR" | awk '{print $1}')"
echo ""
