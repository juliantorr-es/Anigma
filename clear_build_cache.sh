#!/bin/bash
# Script to clear SwiftPM build cache and rebuild Anigma
# This resolves the _NumericsShims module issue caused by stale module cache

set -euo pipefail

echo "=== Anigma Build Cache Clear Script ==="
echo "This script removes SwiftPM build artifacts and rebuilds the project."
echo ""

# Navigate to the anigma directory
cd /Users/user/Developer/GitHub/Anigma_clean/anigma

echo "Current directory: $(pwd)"
echo ""

# Step 1: Remove local build directory
echo "Step 1/4: Removing local .build directory..."
if [ -d ".build" ]; then
    rm -rf .build
    echo "  ✓ Removed .build directory"
else
    echo "  - .build directory not found"
fi

# Step 2: Remove global SwiftPM cache
echo ""
echo "Step 2/4: Removing global SwiftPM cache..."
if [ -d "~/.build" ]; then
    rm -rf ~/.build
    echo "  ✓ Removed ~/.build"
else
    echo "  - ~/.build not found"
fi

# Step 3: Remove Xcode DerivedData
echo ""
echo "Step 3/4: Removing Xcode DerivedData..."
if [ -d "~/Library/Developer/Xcode/DerivedData" ]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData
    echo "  ✓ Removed Xcode DerivedData"
else
    echo "  - Xcode DerivedData not found"
fi

# Step 4: Clean local package files
echo ""
echo "Step 4/4: Cleaning package resolution files..."
[ -f "Package.resolved" ] && rm -f Package.resolved && echo "  ✓ Removed Package.resolved"
[ -d "Package.resolved.lock" ] && rm -rf Package.resolved.lock && echo "  ✓ Removed Package.resolved.lock"

echo ""
echo "=== Cache clearing complete ==="
echo ""
echo "Now resolving and building... This may take several minutes."
echo ""

# Resolve dependencies
echo "Resolving dependencies..."
swift package resolve

# Build the project
echo ""
echo "Building..."
swift build

echo ""
echo "=== Build complete ==="
