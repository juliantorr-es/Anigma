#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="$ROOT_DIR/Benchmarks/BenchmarkHarness/results/benchmark_results.json"

swift run --package-path "$ROOT_DIR/Benchmarks/BenchmarkHarness" anigma-bench \
  --pretty \
  --output "$OUTPUT_PATH"
