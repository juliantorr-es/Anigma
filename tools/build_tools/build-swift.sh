#!/bin/bash

# Build script for Anigma using Swift Package Manager with release configuration
# Usage: ./build-swift.sh [target]

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/enable_sccache.sh"
enable_sccache


# Configuration
PROJECT_DIR="anigma"
TARGET="${1:-AnigmaAppMacExecutable}"
CONFIGURATION="release"
THREAD_COUNT=8
BUILD_DIR=".build"
LOG_FILE="swift-build.log"

echo "🚀 Building $TARGET with $CONFIGURATION configuration using $THREAD_COUNT threads..."

# Clean previous build artifacts
echo "🧹 Cleaning previous build artifacts..."
cd "$PROJECT_DIR"
rm -rf "$BUILD_DIR"
rm -f "../$LOG_FILE"

# Build using Swift Package Manager
echo "🔨 Building with Swift Package Manager..."
swift build \
    --configuration "$CONFIGURATION" \
    --product "$TARGET" \
    --jobs "$THREAD_COUNT" \
    --verbose 2>&1 | tee "../$LOG_FILE"

# Check build result
BUILD_RESULT=$?

cd ..

if [ $BUILD_RESULT -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the built executable
    EXECUTABLE_PATH="$PROJECT_DIR/$BUILD_DIR/$CONFIGURATION/$TARGET"
    
    if [ -f "$EXECUTABLE_PATH" ]; then
        echo "📦 Executable location: $EXECUTABLE_PATH"
        echo "📏 Size: $(du -h "$EXECUTABLE_PATH" | cut -f1)"
        
        # Show some info about the binary
        echo ""
        echo "🔍 Binary Information:"
        file "$EXECUTABLE_PATH"
        echo "   Architecture: $(lipo -info "$EXECUTABLE_PATH" 2>/dev/null || echo "Not a universal binary")"
    else
        echo "⚠️  Could not find built executable at $EXECUTABLE_PATH"
        
        # Try to find it elsewhere
        echo "🔍 Searching for executable..."
        find "$PROJECT_DIR/$BUILD_DIR" -name "$TARGET" -type f 2>/dev/null | while read -r found_path; do
            echo "   Found: $found_path"
            echo "   Size: $(du -h "$found_path" | cut -f1)"
        done
    fi
    
    # Show build summary
    echo ""
    echo "📊 Build Summary:"
    echo "   Target: $TARGET"
    echo "   Configuration: $CONFIGURATION"
    echo "   Threads: $THREAD_COUNT"
    echo "   Build directory: $PROJECT_DIR/$BUILD_DIR"
    echo "   Log file: $LOG_FILE"
else
    echo "❌ Build failed with exit code $BUILD_RESULT"
    echo "📋 Check $LOG_FILE for details"
    
    # Show last 30 lines of log for quick debugging
    echo ""
    echo "🔍 Last 30 lines of build log:"
    tail -30 "$LOG_FILE"
    
    exit $BUILD_RESULT
fi