#!/bin/bash
set -e

# Install script for the canonical harmonia binary.
# Compatibility wrapper retained at the legacy script path.
# Usage: bash Scripts/install_anigma_cli.sh [install_path]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_PATH="${1:-/usr/local/bin}"
BIN_NAME="harmonia"

echo "==============================================================="
echo "Harmonia Installer"
echo "==============================================================="
echo ""

if command -v xcrun > /dev/null 2>&1; then
    SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
    export SDKROOT
fi

echo "Step 1/2: Building harmonia (release mode)..."
cd "$REPO_ROOT"
if swift build -c release --product "$BIN_NAME" > /dev/null 2>&1; then
    echo "  Build successful"
else
    echo "  Build failed. Run: swift build -c release --product $BIN_NAME"
    exit 1
fi

echo ""
echo "Step 2/2: Installing $BIN_NAME to $INSTALL_PATH..."

if [ -f "$REPO_ROOT/.build/arm64-apple-macosx/release/$BIN_NAME" ]; then
    BIN_PATH="$REPO_ROOT/.build/arm64-apple-macosx/release/$BIN_NAME"
elif [ -f "$REPO_ROOT/.build/x86_64-apple-macosx/release/$BIN_NAME" ]; then
    BIN_PATH="$REPO_ROOT/.build/x86_64-apple-macosx/release/$BIN_NAME"
elif [ -f "$REPO_ROOT/.build/release/$BIN_NAME" ]; then
    BIN_PATH="$REPO_ROOT/.build/release/$BIN_NAME"
else
    echo "  Binary not found in .build release folders."
    exit 1
fi

if [ "$INSTALL_PATH" = "/usr/local/bin" ] || [ "$INSTALL_PATH" = "/opt/homebrew/bin" ]; then
    sudo cp "$BIN_PATH" "$INSTALL_PATH/$BIN_NAME"
    sudo chmod +x "$INSTALL_PATH/$BIN_NAME"
    echo "  Installed to $INSTALL_PATH/$BIN_NAME"
else
    mkdir -p "$INSTALL_PATH"
    cp "$BIN_PATH" "$INSTALL_PATH/$BIN_NAME"
    chmod +x "$INSTALL_PATH/$BIN_NAME"
    echo "  Installed to $INSTALL_PATH/$BIN_NAME"
fi

if command -v "$BIN_NAME" > /dev/null 2>&1 || [ -x "$INSTALL_PATH/$BIN_NAME" ]; then
    echo "  Verified: $BIN_NAME is executable"
else
    echo "  Installation verification failed"
    exit 1
fi

echo ""
echo "Install complete."
echo "Run: $BIN_NAME"
echo ""
