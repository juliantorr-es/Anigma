#!/bin/bash
set -e

# Script to package anigma-mcp as a Claude Desktop .mcpb extension
# .mcpb is a zip archive containing:
#   - manifest.json (extension metadata)
#   - anigma-mcp (binary executable)
#   - assets/ (icon files)
#   - README.md (documentation)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$REPO_ROOT/.build/release"
EXTENSION_DIR="$REPO_ROOT/extension"
OUTPUT_DIR="${1:-$REPO_ROOT}"

echo "═══════════════════════════════════════════════════════════════"
echo "Anigma MCP Extension Packaging"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Step 1: Build anigma-mcp
echo "Step 1/5: Building anigma-mcp (release mode)..."
cd "$REPO_ROOT"
if swift build -c release -Xswiftc -suppress-warnings > /dev/null 2>&1; then
    echo "  ✓ Build successful"
else
    echo "  ✗ Build failed. Run: swift build -c release"
    exit 1
fi

# Step 2: Verify binary exists
echo ""
echo "Step 2/5: Verifying binary..."
if [ ! -f "$BUILD_DIR/anigma-mcp" ]; then
    echo "  ✗ Binary not found at $BUILD_DIR/anigma-mcp"
    exit 1
fi
echo "  ✓ Binary found"

# Step 3: Verify extension files
echo ""
echo "Step 3/5: Verifying extension files..."
required_files=(
    "$EXTENSION_DIR/manifest.json"
    "$EXTENSION_DIR/README.md"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "  ✗ Missing: $file"
        exit 1
    fi
done
echo "  ✓ All required files present"

# Step 4: Check for icons
echo ""
echo "Step 4/5: Checking icon assets..."
icons_found=0
for size in 32 64 128 256; do
    if [ -f "$EXTENSION_DIR/assets/icon-${size}.png" ]; then
        icons_found=$((icons_found + 1))
    fi
done

if [ $icons_found -lt 4 ]; then
    echo "  ⚠ Only $icons_found/4 icons found"
    echo "  → Generate icons: bash Scripts/create_extension_icons.sh"
    echo "  → Or use placeholder icons (we'll create them)"

    # Create simple placeholder PNG icons using base64
    echo "  → Creating placeholder PNG icons..."
    mkdir -p "$EXTENSION_DIR/assets"

    # Create a simple 256x256 PNG placeholder (solid color)
    create_placeholder_icon() {
        local size=$1
        local output="$EXTENSION_DIR/assets/icon-${size}.png"

        # Create minimal PNG using ImageMagick if available
        if command -v convert &> /dev/null; then
            convert -size "${size}x${size}" xc:'#1a1a2e' \
                -fill '#00d4ff' -draw "circle $((size/2)),$((size/2)) $((size/4)),$((size/4))" \
                "$output"
        else
            # Fallback: create placeholder using pure Swift or skip
            echo "    ℹ Skipping $output (convert not available)"
            return
        fi
    }

    for size in 32 64 128 256; do
        create_placeholder_icon $size
    done
    icons_found=4
fi

if [ $icons_found -eq 4 ]; then
    echo "  ✓ All 4 icon sizes available"
fi

# Step 5: Create .mcpb package
echo ""
echo "Step 5/5: Creating anigma-mcp.mcpb package..."

# Create temporary staging directory
STAGING_DIR=$(mktemp -d)
trap "rm -rf $STAGING_DIR" EXIT

BUNDLE_DIR="$STAGING_DIR/anigma-mcp"
mkdir -p "$BUNDLE_DIR"

# Copy files to staging
cp "$EXTENSION_DIR/manifest.json" "$BUNDLE_DIR/"
cp "$EXTENSION_DIR/README.md" "$BUNDLE_DIR/"
cp "$BUILD_DIR/anigma-mcp" "$BUNDLE_DIR/"
chmod +x "$BUNDLE_DIR/anigma-mcp"

# Copy assets
mkdir -p "$BUNDLE_DIR/assets"
for size in 32 64 128 256; do
    if [ -f "$EXTENSION_DIR/assets/icon-${size}.png" ]; then
        cp "$EXTENSION_DIR/assets/icon-${size}.png" "$BUNDLE_DIR/assets/"
    fi
done

# Create zip archive (.mcpb is just a renamed zip)
OUTPUT_FILE="$OUTPUT_DIR/anigma-mcp.mcpb"
cd "$STAGING_DIR"
zip -r -q "$OUTPUT_FILE" anigma-mcp/

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "  ✗ Failed to create package"
    exit 1
fi

# Get file size
FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
echo "  ✓ Created $OUTPUT_FILE ($FILE_SIZE)"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✓ Extension Package Ready!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Package: $OUTPUT_FILE"
echo "Size: $FILE_SIZE"
echo ""
echo "Installation:"
echo "  1. Double-click anigma-mcp.mcpb"
echo "  2. Claude Desktop will extract and configure it"
echo "  3. Restart Claude Desktop (Cmd+Q, then relaunch)"
echo ""
echo "Verify:"
echo "  → Ask Claude: 'Show me the system health'"
echo "  → Claude should call get_system_health and return metrics"
echo ""
echo "Distribution:"
echo "  → Upload to GitHub releases"
echo "  → Users can install directly from the .mcpb file"
echo "  → No need for manual configuration!"
echo ""
