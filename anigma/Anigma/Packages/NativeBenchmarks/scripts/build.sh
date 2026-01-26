#!/bin/bash
# Build script for Anigma Native Benchmarks

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "Building Anigma Native Benchmarks"
echo "=========================================="

# Create build directory
BUILD_DIR="$PROJECT_ROOT/build"
if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
    echo "Created build directory: $BUILD_DIR"
fi

# Configure
cd "$BUILD_DIR"
echo "Configuring CMake..."
cmake -DCMAKE_BUILD_TYPE=Release ..

# Build
echo "Building..."
make -j$(nproc || sysctl -n hw.ncpu)

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "Executable: $BUILD_DIR/bin/anigma_benchmarks"
echo ""
echo "To run benchmarks:"
echo "  $BUILD_DIR/bin/anigma_benchmarks"
echo ""
echo "To save results:"
echo "  $BUILD_DIR/bin/anigma_benchmarks > results/benchmark_\$(date +%Y%m%d_%H%M%S).txt"
