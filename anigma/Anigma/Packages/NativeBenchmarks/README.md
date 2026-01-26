# Anigma Native Benchmark Suite

Comprehensive C++ performance benchmark suite for Anigma's native capsules, providing parallel benchmarking coverage with the Swift benchmark suite.

## Overview

This benchmark suite measures performance across 6 critical dimensions:

1. **Text Processing** - String operations, UTF-8 validation, regex matching
2. **Hashing** - Image fingerprinting (pHash, dHash), similarity computation
3. **Vector Operations** - Linear algebra operations for embeddings
4. **Data Compression** - Compression ratio and throughput measurement
5. **Memory Performance** - Allocation patterns, cache efficiency, buffer operations
6. **Concurrent Operations** - Thread pool, atomics, lock contention

## Quick Start

### Build
```bash
cd Packages/NativeBenchmarks
chmod +x scripts/build.sh
./scripts/build.sh
```

### Run
```bash
./build/bin/anigma_benchmarks
```

### Analyze Results
```bash
python3 scripts/analyze_results.py \
  --results benchmark_output.txt \
  --baseline results/baseline.json \
  --output results/analysis.json
```

## Directory Structure

```
NativeBenchmarks/
├── CMakeLists.txt              # Build configuration
├── BUILD.md                     # Detailed build instructions
├── README.md                    # This file
├── include/
│   └── benchmark_utils.h       # Benchmark framework utilities
├── src/
│   ├── main.cpp                # Main entry point (500+ lines)
│   ├── text_benchmarks.cpp     # Text processing (400+ lines)
│   ├── hashing_benchmarks.cpp  # Hashing operations (450+ lines)
│   ├── vector_benchmarks.cpp   # Vector math (500+ lines)
│   ├── compression_benchmarks.cpp  # Data compression (450+ lines)
│   ├── memory_benchmarks.cpp   # Memory performance (550+ lines)
│   └── concurrent_benchmarks.cpp   # Threading (450+ lines)
├── scripts/
│   ├── build.sh                # Automated build script
│   └── analyze_results.py      # Results analysis tool
├── results/                    # Benchmark results
└── cmake/                      # CMake helpers

Total: 3,700+ lines of benchmark code
```

## Benchmark Details

### 1. Text Processing Benchmarks
Tests fundamental string operations at various scales.

**Tests:**
- String trimming (whitespace removal)
- Lowercase conversion
- Regular expression matching (email patterns)
- UTF-8 validation (multiple scripts)
- Character encoding/decoding
- String concatenation

**Metrics:**
- Mean/p95/p99 latency (microseconds)
- Throughput (operations/sec)

**Example Output:**
```
String Trimming Results:
  Mean:          2.5432 µs
  Min:           0.0123 µs
  Max:           45.6789 µs
  p95:           3.2345 µs
  p99:           5.6789 µs
  Throughput:    392150 ops/sec
```

### 2. Hashing Benchmarks
Measures performance of perceptual hashing algorithms for media fingerprinting.

**Tests:**
- pHash computation (DCT-based, 32x32 and 64x64)
- dHash computation (gradient-based, 8x8)
- 64-bit Hamming distance calculation
- 256-bit Hamming distance calculation
- Batch hash search (brute-force, 10K candidates)
- 256-bit hash generation

**Metrics:**
- Hash generation rate (hashes/sec)
- Distance calculations (ops/sec)
- Throughput (MB/s)

**Example Output:**
```
pHash Computation (64x64) Results:
  Mean:          42.5678 µs
  Throughput:    96.35 MB/s

Hamming Distance (64-bit) Results:
  Mean:          0.1234 µs
  Throughput:    8100000 ops/sec
```

### 3. Vector Operation Benchmarks
Benchmarks mathematical operations on high-dimensional vectors.

**Tests:**
- Dot product (128, 256, 768, 1024 dimensions)
- Cosine similarity (multiple dimensions)
- Vector normalization (L2 norm)
- Batch dot products (100-10K pairs)

**Metrics:**
- Operations per second
- Throughput (scalar ops/sec)
- Latency distribution

**Example Output:**
```
Dot Product (768-dim) Results:
  Mean:          8.9234 µs
  Throughput:    112300 ops/sec

Cosine Similarity (768-dim) Results:
  Mean:          15.4567 µs
  Throughput:    64800 ops/sec
```

### 4. Compression Benchmarks
Measures compression algorithms on various data patterns.

**Tests:**
- RLE compression (Run-Length Encoding)
- LZ77 compression (dictionary-based)
- On random data (worst case)
- On repetitive data (best case)
- On text-like data (typical case)

**Metrics:**
- Compression ratio (%)
- Throughput (MB/s)
- Latency (milliseconds)

**Example Output:**
```
Repetitive Data (RLE) Results:
  Mean:          45.6789 ms
  Compression Ratio: 25.30%
  Throughput:    21.87 MB/s
```

### 5. Memory Performance Benchmarks
Tests allocation patterns, access patterns, and buffer operations.

**Tests:**
- Small allocations (64 bytes)
- Medium allocations (4 KB)
- Large allocations (1 MB)
- Sequential memory access (cache-friendly)
- Random memory access (cache-unfriendly)
- Strided access patterns
- Large buffer copy (64 MB)
- Large buffer fill (64 MB)
- Memory fragmentation analysis

**Metrics:**
- Allocation throughput (allocs/sec)
- Access throughput (GB/s)
- Fragmentation ratio

**Example Output:**
```
Small Allocations (64 bytes) Results:
  Mean:          0.2345 µs
  Throughput:    4261896 alloc/sec

Sequential Access (1 MB array) Results:
  Mean:          1234.5678 µs
  Throughput:    80.50 GB/s

Memory Fragmentation Results:
  Initial Allocation: 12 ms
  Free Every Other Block: 3 ms
  Re-allocation (fragmented): 18 ms
  Fragmentation Ratio: 1.50x
```

### 6. Concurrent Operation Benchmarks
Tests multi-threaded performance and synchronization primitives.

**Tests:**
- Thread pool performance (1, 2, 4, 8 threads)
- Atomic increment operations
- Atomic compare-and-swap operations
- Mutex lock contention
- Thread scaling (1, 2, 4, 8, 16 threads)

**Metrics:**
- Tasks/sec throughput
- Operations/sec
- Lock operations/sec
- Scaling efficiency

**Example Output:**
```
Thread Pool (8 threads, 10000 tasks):
  Total Time:    45 ms
  Throughput:    222222 tasks/sec

Atomic Increment (8 threads):
  Operations:    800000
  Total Time:    12 ms
  Throughput:    66666667 ops/sec

Thread Scaling (8 threads):
  Total Work:    800000
  Total Time:    125 ms
  Throughput:    6400000 ops/sec
```

## Performance Baselines

Expected results on modern hardware (Apple Silicon M1/M2 or Intel Core i7/i9):

### Text Processing
```
String Trimming:       1-5 µs
Lowercase:             2-8 µs
Regex Matching:        5-20 µs
UTF-8 Validation:      0.5-2 µs/char
String Concat:         5-15 µs
```

### Hashing
```
pHash (64x64):         10-50 µs
dHash (64x64):         5-25 µs
Hamming Distance (64): 0.1-0.5 µs
Hamming Distance (256): 0.3-1.5 µs
Batch Search (10K):    5-15 ms
```

### Vector Operations
```
Dot Product (768D):    5-15 µs
Cosine Similarity:     10-30 µs
Normalization:         10-30 µs
Batch (1000 pairs):    1-5 ms
```

### Compression
```
RLE (1 MB random):     10-30 ms (95-100% ratio)
RLE (1 MB repetitive): 5-15 ms (10-40% ratio)
LZ77 (1 MB text):      50-150 ms (40-70% ratio)
```

### Memory
```
Small Alloc:           0.1-1 µs
Medium Alloc:          0.5-5 µs
Large Alloc:           10-100 µs
Sequential Access:     50-100 GB/s
Random Access:         5-20 GB/s
Buffer Copy:           10-30 GB/s
```

### Concurrent
```
Thread Pool:           10K-100K tasks/sec
Atomic Inc:            100M-1B ops/sec
Atomic CAS:            10M-100M ops/sec
Mutex Lock:            100K-1M ops/sec
```

## Integration with CI/CD

### GitHub Actions

```yaml
name: Benchmark Suite

on: [push, pull_request]

jobs:
  benchmark:
    runs-on: [ubuntu-latest, macos-latest]
    steps:
      - uses: actions/checkout@v2
      
      - name: Install dependencies
        run: |
          if [[ "$RUNNER_OS" == "Linux" ]]; then
            sudo apt-get install cmake
          else
            brew install cmake
          fi
      
      - name: Build
        run: |
          cd Packages/NativeBenchmarks
          ./scripts/build.sh
      
      - name: Run Benchmarks
        run: |
          ./Packages/NativeBenchmarks/build/bin/anigma_benchmarks \
            > benchmark_results.txt
      
      - name: Detect Regressions
        run: |
          python3 Packages/NativeBenchmarks/scripts/analyze_results.py \
            --results benchmark_results.txt \
            --baseline Packages/NativeBenchmarks/results/baseline.json \
            --threshold 0.10
      
      - name: Upload Results
        uses: actions/upload-artifact@v2
        with:
          name: benchmark-results
          path: benchmark_results.txt
```

## Comparison with Swift Benchmarks

The C++ benchmarks parallel the Swift benchmark suite structure:

| Category | Swift Test | C++ Benchmark |
|----------|-----------|---------------|
| Text Processing | textNormalization | String Trimming, Lowercase |
| Text | textChunking | String Concat |
| Hashing | hashThroughput | pHash, dHash, Hamming |
| Vector | vectorSimilarity | Dot Product, Cosine Similarity |
| JSON | jsonDecoding | (Compression tests cover serialization) |
| Memory | memoryAllocation | Allocation Patterns, Cache Tests |
| Concurrency | concurrentThroughput | Thread Pool, Atomics |

## Compilation Flags

- **Optimization**: `-O3` (Release mode)
- **Standard**: C++17
- **Platform-specific**: `-march=native` for native instruction set
- **LTO**: Enabled in Release builds (Linux)

## Requirements

- **CMake**: 3.15+
- **C++17 Compiler**: GCC 7+, Clang 5+, MSVC 2017+, Apple Clang 10+
- **macOS**: 10.14+ (for Mach APIs)
- **Linux**: Any modern distribution

## Building with Different Flags

### Debug Build with Symbols
```bash
mkdir build_debug
cd build_debug
cmake -DCMAKE_BUILD_TYPE=Debug ..
make
```

### Static Build
```bash
cmake -DBUILD_SHARED_LIBS=OFF ..
```

## Profiling

### macOS with Instruments
```bash
# CPU profiling
instruments -t 'CPU Samples' ./build/bin/anigma_benchmarks

# Memory profiling
instruments -t 'Allocations' ./build/bin/anigma_benchmarks

# System trace
instruments -t 'System Trace' ./build/bin/anigma_benchmarks
```

### Linux with perf
```bash
perf record -g ./build/bin/anigma_benchmarks
perf report
```

## Performance Optimization Tips

1. **Disable CPU frequency scaling** (Linux):
   ```bash
   echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   ```

2. **Run with high priority**:
   ```bash
   sudo nice -n -20 ./build/bin/anigma_benchmarks
   ```

3. **Close other applications** for stable results

4. **Run multiple times** and average for variance analysis

5. **Check for thermal throttling**:
   ```bash
   # macOS
   powermetrics --samplers smc
   ```

## Future Enhancements

- [ ] SIMD optimization tests
- [ ] GPU acceleration benchmarks
- [ ] Network I/O performance
- [ ] File system operations
- [ ] Database query performance
- [ ] Web framework benchmarks
- [ ] ML inference performance

## References

- [CMake Documentation](https://cmake.org/)
- [C++17 Standard](https://en.cppreference.com/)
- [Google Benchmark Framework](https://github.com/google/benchmark)
- [Performance Analysis with perf](https://easyperf.net/)
- [macOS Performance Tools](https://developer.apple.com/xcode/performance/)

## License

Copyright (c) 2025 Anigma. Licensed under the MIT License.

## Support

For issues or questions:
1. Check BUILD.md for detailed build instructions
2. Review benchmark output for specific metric explanations
3. Use analyze_results.py for regression detection
4. Profile with Instruments/perf for bottleneck identification
