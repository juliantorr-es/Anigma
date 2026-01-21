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
if [ -d "$PROJECT_ROOT/.build/arm64-apple-macosx/release" ]; then
    BIN_PATH="$PROJECT_ROOT/.build/arm64-apple-macosx/release"
elif [ -d "$PROJECT_ROOT/.build/x86_64-apple-macosx/release" ]; then
    BIN_PATH="$PROJECT_ROOT/.build/x86_64-apple-macosx/release"
else
    BIN_PATH="$PROJECT_ROOT/.build/release"
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
    "anigma-cli"
    "ml-worker"
    "doctrine"
    "anigma-ast-services"
    "harmonia-surface"
    "outlineum-zine"
    "diaplasion-pipeline"
    "accessum-flow"
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
- **anigma-cli**: Modular monolith CLI with TUI entrypoint
- **ml-worker**: ML inference worker process (MLX-based)
- **doctrine**: Policy enforcement CLI
- **anigma-ast-services**: Swift AST analysis service
- **harmonia-surface**: Surface-level Harmonia operations
- **outlineum-zine**: Zine and print production tools
- **diaplasion-pipeline**: Document transformation pipeline
- **accessum-flow**: Accessibility workflow tools

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
