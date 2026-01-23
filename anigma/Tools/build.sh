#!/bin/bash
# Tools/build.sh
# Incremental build script for Anigma Engine components.

set -e

# Configuration
BUILD_DIR=".build"
SCHEME="Anigma"
CONFIG="debug" # Default to debug for faster incremental builds

# Function to build a specific target
build_target() {
    local target=$1
    echo "🚀 Building target: $target..."
    swift build --target "$target" -c "$CONFIG" --build-path "$BUILD_DIR"
}

# Function to build the core engine "Hot Path"
build_engine() {
    echo "⚡️ Building Anigma Engine Hot Path..."
    build_target "NativeKernel"
    build_target "RuntimeOrchestrator"
    build_target "PlatformAdapters"
}

# Main routing
case "$1" in
    "engine")
        build_engine
        ;;
    "kernel")
        build_target "NativeKernel"
        ;;
    "ui")
        build_target "AnigmaUI"
        ;;
    "app")
        build_target "AnigmaAppMacExecutable"
        ;;
    "clean")
        echo "🧹 Cleaning build artifacts..."
        rm -rf "$BUILD_DIR"
        ;;
    *)
        echo "Usage: ./build.sh {engine|kernel|ui|app|clean}"
        exit 1
        ;;
esac

echo "✅ Build successful!"
