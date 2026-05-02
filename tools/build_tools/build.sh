#!/bin/bash

# Main build script for Anigma
# Supports both xcodebuild and Swift Package Manager builds
# Usage: ./build.sh [method] [target/scheme]
#   method: xcodebuild (default) or swift
#   target/scheme: target name for build method

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/enable_sccache.sh"
enable_sccache

# Default configuration
METHOD="${1:-xcodebuild}"
TARGET="${2:-AnigmaAppMacExecutable}"
CONFIGURATION="Release"
THREAD_COUNT=8
PROJECT_DIR="anigma"

echo "🔧 Anigma Build Script"
echo "======================"

case "$METHOD" in
    xcodebuild|xcode|xc)
        echo "📱 Using xcodebuild method"
        
        # Check if we have an Xcode project
        if [ ! -f "$PROJECT_DIR/Anigma.xcodeproj/project.pbxproj" ]; then
            echo "⚠️  No Xcode project found. Generating one..."
            cd "$PROJECT_DIR"
            swift package generate-xcodeproj || {
                echo "❌ Failed to generate Xcode project"
                echo "   Falling back to Swift Package Manager..."
                METHOD="swift"
                cd ..
            }
            cd ..
        fi
        
        if [ "$METHOD" = "xcodebuild" ]; then
            DERIVED_DATA_PATH="DerivedData"
            LOG_FILE="xcodebuild.log"
            
            echo "🧹 Cleaning previous build artifacts..."
            rm -rf "$DERIVED_DATA_PATH"
            rm -f "$LOG_FILE"
            
            echo "🔨 Building with xcodebuild using $THREAD_COUNT threads..."
            xcodebuild \
                -project "$PROJECT_DIR/Anigma.xcodeproj" \
                -scheme "$TARGET" \
                -configuration "$CONFIGURATION" \
                -derivedDataPath "$DERIVED_DATA_PATH" \
                -destination 'platform=macOS' \
                -parallelizeTargets \
                -jobs "$THREAD_COUNT" \
                clean build 2>&1 | tee "$LOG_FILE"
            
            BUILD_RESULT=$?
            
            if [ $BUILD_RESULT -eq 0 ]; then
                echo "✅ xcodebuild build successful!"
                EXECUTABLE_PATH=$(find "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION" -name "$TARGET" -type f 2>/dev/null | head -1)
            fi
        fi
        ;;
    
    swift|spm|package)
        echo "⚡ Using Swift Package Manager method"
        
        BUILD_DIR=".build"
        LOG_FILE="swift-build.log"
        SWIFT_CONFIG="release"
        
        echo "🧹 Cleaning previous build artifacts..."
        cd "$PROJECT_DIR"
        rm -rf "$BUILD_DIR"
        rm -f "../$LOG_FILE"
        
        echo "🔨 Building with Swift Package Manager using $THREAD_COUNT threads..."
        swift build \
            --configuration "$SWIFT_CONFIG" \
            --product "$TARGET" \
            --jobs "$THREAD_COUNT" \
            --verbose 2>&1 | tee "../$LOG_FILE"
        
        BUILD_RESULT=$?
        cd ..
        
        if [ $BUILD_RESULT -eq 0 ]; then
            echo "✅ Swift Package Manager build successful!"
            EXECUTABLE_PATH="$PROJECT_DIR/$BUILD_DIR/$SWIFT_CONFIG/$TARGET"
        fi
        ;;
    
    *)
        echo "❌ Unknown build method: $METHOD"
        echo "   Available methods: xcodebuild, swift"
        exit 1
        ;;
esac

# Final output
if [ $BUILD_RESULT -eq 0 ]; then
    echo ""
    echo "🎉 Build completed successfully!"
    echo "================================"
    
    if [ -n "$EXECUTABLE_PATH" ] && [ -f "$EXECUTABLE_PATH" ]; then
        echo "📦 Executable: $EXECUTABLE_PATH"
        echo "📏 Size: $(du -h "$EXECUTABLE_PATH" | cut -f1)"
        
        # Show architecture info
        echo "🏗️  Architecture:"
        if command -v lipo >/dev/null 2>&1; then
            lipo -info "$EXECUTABLE_PATH" 2>/dev/null || echo "   Not a universal binary"
        fi
        
        # Show Swift version info if available
        if command -v dwarfdump >/dev/null 2>&1; then
            echo "⚡ Swift Version:"
            dwarfdump --uuid "$EXECUTABLE_PATH" 2>/dev/null | grep -i swift || echo "   Could not determine Swift version"
        fi
    else
        echo "⚠️  Built executable not found at expected location"
        echo "   Searching for executable..."
        find . -name "$TARGET" -type f ! -path "*/.*" 2>/dev/null | head -5 | while read -r found_path; do
            echo "   • $found_path ($(du -h "$found_path" | cut -f1))"
        done
    fi
    
    echo ""
    echo "📊 Build Configuration:"
    echo "   Method: $METHOD"
    echo "   Target: $TARGET"
    echo "   Configuration: $CONFIGURATION"
    echo "   Threads: $THREAD_COUNT"
    echo "   Project: $PROJECT_DIR"
    
    # Offer to run the executable
    echo ""
    read -p "🚀 Run the executable? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] && [ -f "$EXECUTABLE_PATH" ]; then
        echo "➡️  Running $EXECUTABLE_PATH..."
        "$EXECUTABLE_PATH" --help || echo "Executable ran (exit code: $?)"
    fi
else
    echo "❌ Build failed with exit code $BUILD_RESULT"
    
    # Show error summary
    case "$METHOD" in
        xcodebuild)
            echo "📋 Check xcodebuild.log for details"
            echo "🔍 Last 20 lines of log:"
            tail -20 "xcodebuild.log" 2>/dev/null || echo "   Log file not found"
            ;;
        swift)
            echo "📋 Check swift-build.log for details"
            echo "🔍 Last 20 lines of log:"
            tail -20 "swift-build.log" 2>/dev/null || echo "   Log file not found"
            ;;
    esac
    
    exit $BUILD_RESULT
fi
