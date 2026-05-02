#!/bin/bash

# Build script for Anigma using xcodebuild with release configuration and 8 threads
# Usage: ./build-release.sh [scheme]

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/enable_sccache.sh"
enable_sccache


# Configuration
PROJECT_DIR="anigma"
SCHEME="${1:-AnigmaAppMacExecutable}"
CONFIGURATION="Release"
THREAD_COUNT=8
DERIVED_DATA_PATH="DerivedData"
LOG_FILE="build.log"

echo "🚀 Building $SCHEME with $CONFIGURATION configuration using $THREAD_COUNT threads..."

# Clean previous build artifacts
echo "🧹 Cleaning previous build artifacts..."
rm -rf "$DERIVED_DATA_PATH"
rm -f "$LOG_FILE"

# Build using xcodebuild
echo "🔨 Building with xcodebuild..."
xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination 'platform=macOS' \
    -parallelizeTargets \
    -jobs "$THREAD_COUNT" \
    -quiet \
    clean build 2>&1 | tee "$LOG_FILE"

# Check build result
BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the built executable
    EXECUTABLE_PATH=$(find "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION" -name "$SCHEME" -type f 2>/dev/null | head -1)
    
    if [ -n "$EXECUTABLE_PATH" ]; then
        echo "📦 Executable location: $EXECUTABLE_PATH"
        echo "📏 Size: $(du -h "$EXECUTABLE_PATH" | cut -f1)"
    else
        echo "⚠️  Could not find built executable"
    fi
    
    # Show build summary
    echo ""
    echo "📊 Build Summary:"
    echo "   Scheme: $SCHEME"
    echo "   Configuration: $CONFIGURATION"
    echo "   Threads: $THREAD_COUNT"
    echo "   Derived Data: $DERIVED_DATA_PATH"
    echo "   Log file: $LOG_FILE"
else
    echo "❌ Build failed with exit code $BUILD_RESULT"
    echo "📋 Check $LOG_FILE for details"
    
    # Show last 20 lines of log for quick debugging
    echo ""
    echo "🔍 Last 20 lines of build log:"
    tail -20 "$LOG_FILE"
    
    exit $BUILD_RESULT
fi