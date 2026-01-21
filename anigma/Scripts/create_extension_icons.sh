#!/bin/bash
set -e

# Script to generate icon assets for the anigma-mcp Claude Desktop extension
# Requires: ImageMagick (convert command) or Inkscape + png2icns (for macOS .icns conversion)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
EXTENSION_DIR="$REPO_ROOT/extension"
ASSETS_DIR="$EXTENSION_DIR/assets"
SVG_SOURCE="$ASSETS_DIR/icon.svg"

echo "═══════════════════════════════════════════════════════════════"
echo "Anigma MCP Extension Icon Generation"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if SVG source exists
if [ ! -f "$SVG_SOURCE" ]; then
    echo "✗ SVG source not found: $SVG_SOURCE"
    exit 1
fi

# Try to use ImageMagick if available
if command -v convert &> /dev/null; then
    echo "Using ImageMagick to generate PNG icons..."
    echo ""

    # Generate each size
    for size in 32 64 128 256; do
        output="$ASSETS_DIR/icon-${size}.png"
        echo "Generating ${size}x${size} icon..."
        convert -background none -size "${size}x${size}" "$SVG_SOURCE" "$output"
        if [ -f "$output" ]; then
            echo "  ✓ Created $output"
        else
            echo "  ✗ Failed to create $output"
        fi
    done

    echo ""
    echo "✓ Icon generation complete!"

# Try to use Inkscape if ImageMagick not available
elif command -v inkscape &> /dev/null; then
    echo "Using Inkscape to generate PNG icons..."
    echo ""

    for size in 32 64 128 256; do
        output="$ASSETS_DIR/icon-${size}.png"
        echo "Generating ${size}x${size} icon..."
        inkscape --export-type=png --export-filename="$output" \
            -w "$size" -h "$size" "$SVG_SOURCE" 2>/dev/null
        if [ -f "$output" ]; then
            echo "  ✓ Created $output"
        else
            echo "  ✗ Failed to create $output"
        fi
    done

    echo ""
    echo "✓ Icon generation complete!"

else
    echo "⚠ ImageMagick (convert) or Inkscape not found."
    echo ""
    echo "Install ImageMagick:"
    echo "  brew install imagemagick"
    echo ""
    echo "Or install Inkscape:"
    echo "  brew install inkscape"
    echo ""
    echo "After installation, run this script again."
    echo ""
    echo "Alternative: Use an online converter to convert $SVG_SOURCE to PNG"
    echo "  → https://cloudconvert.com/svg-to-png"
    echo ""
    exit 1
fi

echo ""
echo "Icons are ready for packaging!"
