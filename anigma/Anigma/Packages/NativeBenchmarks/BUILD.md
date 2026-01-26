# Anigma Native Benchmarks - Build Instructions

Comprehensive C++ performance benchmark suite for Anigma's native capsules.

## Prerequisites

### macOS
```bash
# Install Xcode command line tools
xcode-select --install

# Install CMake (if not already installed)
brew install cmake
```

### Linux
```bash
# Ubuntu/Debian
sudo apt-get install cmake g++ build-essential

# Fedora
sudo dnf install cmake gcc-c++ make
```

## Building

### Quick Build
```bash
cd Packages/NativeBenchmarks
mkdir -p build
cd build
cmake ..
make -j$(nproc)
```

### Optimized Release Build
```bash
cd Packages/NativeBenchmarks
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```

### Debug Build (with debugging symbols)
```bash
cd Packages/NativeBenchmarks
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Debug ..
make
```

## Running Benchmarks

### Execute All Benchmarks
```bash
./build/bin/anigma_benchmarks
```

### Save Results to File
```bash
./build/bin/anigma_benchmarks > results/benchmark_results_$(date +%Y%m%d_%H%M%S).txt
```

### Run with Profiling (macOS)
```bash
instruments -t 'System Trace' ./build/bin/anigma_benchmarks
```

## Benchmark Categories

### 1. Text Processing Benchmarks
- String trimming and whitespace removal
- Lowercase conversion
- Regular expression matching
- UTF-8 validation
- Character encoding/decoding
- String concatenation

**Key Metrics:**
- Throughput: strings/sec
- Latency: microseconds
- Memory usage

### 2. Hashing Benchmarks
- pHash computation (DCT-based image hashing)
- dHash computation (gradient-based image hashing)
- 64-bit and 256-bit hash generation
- Hamming distance calculation
- Batch hash search operations

**Key Metrics:**
- Hash generation: hashes/sec
- Distance calculations: ops/sec
- Throughput: MB/s for data processing

### 3. Vector Operation Benchmarks
- Dot product computation for vectors of sizes 128, 256, 768, 1024 dimensions
- Cosine similarity calculations
- Vector normalization
- Batch dot product operations

**Key Metrics:**
- Operations/sec for different vector dimensions
- Throughput: scalar operations/sec

### 4. Data Compression Benchmarks
- RLE (Run-Length Encoding) compression
- LZ77-inspired dictionary compression
- Compression ratio measurement
- Performance on different data patterns:
  - Random data (worst case)
  - Repetitive data (best case for RLE)
  - Text-like data (moderate compression)

**Key Metrics:**
- Compression ratio: %
- Throughput: MB/s
- Mean latency: milliseconds

### 5. Memory Performance Benchmarks
- Small allocations (64 bytes)
- Medium allocations (4 KB)
- Large allocations (1 MB)
- Sequential memory access patterns
- Random access patterns
- Strided access patterns
- Large buffer operations (copy, fill)
- Memory fragmentation analysis

**Key Metrics:**
- Allocation throughput: allocs/sec
- Access throughput: GB/s
- Fragmentation ratio

### 6. Concurrent Operation Benchmarks
- Thread pool performance with varying thread counts
- Atomic operations (increment, compare-and-swap)
- Mutex lock contention measurement
- Thread scaling efficiency

**Key Metrics:**
- Tasks/sec for thread pool
- Operations/sec for atomics
- Lock operations/sec
- Scaling efficiency across cores

## Performance Baseline Results

Expected baseline performance on modern hardware (Apple Silicon M1/M2 or Intel Core i7/i9):

### Text Processing
- String trimming: ~1-5 µs per string
- Lowercase conversion: ~2-8 µs per string
- Regex matching: ~5-20 µs per pattern match
- UTF-8 validation: ~0.5-2 µs per character

### Hashing
- pHash (64x64): ~10-50 µs per hash
- dHash (64x64): ~5-25 µs per hash
- Hamming distance: ~0.1-0.5 µs per operation
- Hash batch search (10K): ~5-15 ms per search

### Vector Operations
- Dot product (768-dim): ~5-15 µs per operation
- Cosine similarity (768-dim): ~10-30 µs per operation
- Vector normalization (768-dim): ~10-30 µs per operation
- Batch operations: ~1-5 ms per batch (1000 pairs)

### Compression
- RLE compression (1 MB): ~5-50 ms depending on data pattern
- LZ77 compression (1 MB): ~50-200 ms depending on data pattern
- Compression ratios:
  - Random data: ~95-100%
  - Repetitive data: ~10-40%
  - Text data: ~40-70%

### Memory
- Small allocations: ~0.1-1 µs
- Medium allocations: ~0.5-5 µs
- Large allocations: ~10-100 µs
- Sequential access: ~50-100 GB/s
- Random access: ~5-20 GB/s
- Strided access: ~30-80 GB/s
- Buffer copy (64 MB): ~10-30 GB/s
- Buffer fill (64 MB): ~50-150 GB/s

### Concurrent Operations
- Thread pool throughput: ~10K-100K tasks/sec
- Atomic increment: ~100M-1B ops/sec (varies by thread count)
- Atomic CAS: ~10M-100M ops/sec
- Mutex ops: ~100K-1M ops/sec (high contention)
- Thread scaling: Near-linear up to 4 cores, diminishing returns beyond

## Analysis and Comparison

### Compare Against Swift Benchmarks
```bash
python3 scripts/compare_benchmarks.py \
  --cpp results/benchmark_cpp.txt \
  --swift results/benchmark_swift.txt \
  --output results/comparison.html
```

### Generate Trend Report
```bash
python3 scripts/analyze_trends.py \
  --baseline results/baseline.json \
  --current results/latest.json \
  --output results/trend_report.json
```

### Detect Regressions
```bash
python3 scripts/regression_detection.py \
  --baseline results/baseline.json \
  --current results/current.json \
  --threshold 10  # Alert if performance degrades > 10%
```

## Interpreting Results

### Statistical Measures
- **Mean**: Average time per operation
- **Min/Max**: Best and worst case performance
- **p95/p99**: 95th and 99th percentile latencies
- **Throughput**: Operations per second or MB/s

### Performance Considerations
1. **Compilation Flags**: Results use -O3 optimization
2. **Warm-up**: Benchmarks include warm-up iterations
3. **Variability**: Some measurements may show variance due to:
   - OS scheduling
   - CPU frequency scaling
   - Cache state
   - System load

### Regression Thresholds
- **Critical**: >20% degradation
- **Warning**: 10-20% degradation
- **Acceptable**: <10% variance

## Profiling and Optimization

### Profile with Instruments (macOS)
```bash
# CPU profiling
instruments -t 'CPU Samples' ./build/bin/anigma_benchmarks

# Memory allocation
instruments -t 'Allocations' ./build/bin/anigma_benchmarks

# System trace
instruments -t 'System Trace' ./build/bin/anigma_benchmarks
```

### Profile with perf (Linux)
```bash
perf record -g ./build/bin/anigma_benchmarks
perf report
```

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Build Benchmarks
  run: |
    cd Packages/NativeBenchmarks
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j$(nproc)

- name: Run Benchmarks
  run: |
    ./Packages/NativeBenchmarks/build/bin/anigma_benchmarks > benchmark_results.txt

- name: Compare Against Baseline
  run: |
    python3 scripts/regression_detection.py \
      --baseline baseline.json \
      --current benchmark_results.txt
```

## Troubleshooting

### Build Errors

**Error: CMake not found**
```bash
# Install CMake
brew install cmake  # macOS
apt-get install cmake  # Linux
```

**Error: C++17 features not available**
- Ensure compiler is recent (GCC 7+, Clang 5+, MSVC 2017+)
- Update compiler: `brew upgrade gcc` or `apt-get upgrade g++`

### Runtime Issues

**Benchmark takes too long**
- Results may vary based on system load
- Run in isolation: `sudo nice -n -20 ./build/bin/anigma_benchmarks`
- Close other applications

**High variance in results**
- Disable dynamic CPU frequency scaling (Linux):
  ```bash
  echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  ```
- Run multiple times and average results

## Performance Optimization Tips

1. **Vectorization**: Enable SIMD instructions in compilation
2. **Cache Locality**: Access memory sequentially when possible
3. **Memory Alignment**: Align data structures to cache line boundaries
4. **Threading**: Use thread pool for work distribution
5. **Profiling**: Use Instruments/perf to identify bottlenecks

## Further Reading

- [CMake Documentation](https://cmake.org/documentation/)
- [C++17 Standard](https://en.cppreference.com/)
- [Google Benchmark](https://github.com/google/benchmark)
- [Performance Analysis Guide](https://easyperf.net/)
