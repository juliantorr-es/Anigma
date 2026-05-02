#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="$ROOT_DIR/Anigma/Benchmarks/BenchmarkHarness/results/benchmark_results.json"

DYLD_LIBRARY_PATH="$ROOT_DIR/Vendor/lib${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}" \
LD_LIBRARY_PATH="$ROOT_DIR/Vendor/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
swift run --package-path "$ROOT_DIR" anigma-capsule-bench \
  --pretty \
  --output "$OUTPUT_PATH"
