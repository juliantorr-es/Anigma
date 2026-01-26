# Anigma Profiling & Benchmarking Setup Guide

**Purpose**: Step-by-step guide to set up comprehensive profiling and benchmarking for Anigma native capsules.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Environment Setup](#environment-setup)
3. [Running Benchmarks](#running-benchmarks)
4. [macOS Profiling with Instruments](#macos-profiling-with-instruments)
5. [Linux Profiling](#linux-profiling)
6. [Analyzing Results](#analyzing-results)
7. [CI/CD Integration](#cicd-integration)

---

## Quick Start

### macOS (Recommended for Development)

```bash
# Navigate to project
cd /Users/user/Developer/GitHub/Anigma_clean/anigma/Anigma

# Build benchmarks
cd Packages/NativeBenchmarks
./scripts/build.sh

# Run benchmarks
./build/bin/anigma_benchmarks > results/latest.json

# Profile with Instruments
instruments -t 'CPU Samples' -D results/latest.trace ./build/bin/anigma_benchmarks

# Profile memory
instruments -t 'Allocations' -D results/memory.trace ./build/bin/anigma_benchmarks

# Analyze results
python3 scripts/analyze_results.py \
    --results results/latest.json \
    --baseline results/baseline.json \
    --output results/comparison.json
```

### Linux

```bash
# Install dependencies
sudo apt-get install cmake gcc g++ build-essential

# Build
cd Packages/NativeBenchmarks
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)

# Run benchmarks
./bin/anigma_benchmarks > ../results/latest.json

# Profile with perf
perf record -g -F 99 ./bin/anigma_benchmarks
perf report --hierarchy
perf script | stackcollapse-perf.pl | flamegraph.pl > /tmp/flamegraph.svg
```

---

## Environment Setup

### macOS Prerequisites

```bash
# Install Xcode Command Line Tools (if not already installed)
xcode-select --install

# Verify installation
xcode-select -p  # Should output: /Applications/Xcode.app/Contents/Developer

# Install Homebrew (if needed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install CMake
brew install cmake

# Verify CMake
cmake --version  # Should be 3.15+
```

### Linux Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    cmake \
    gcc \
    g++ \
    build-essential \
    linux-tools-generic \
    python3 \
    python3-pip

# Fedora/RHEL
sudo dnf install -y \
    cmake \
    gcc \
    g++ \
    make \
    perf \
    python3

# Verify installations
cmake --version
gcc --version
g++ --version
```

### Python Dependencies

```bash
# Install Python analysis tools
pip3 install --upgrade pip
pip3 install numpy pandas matplotlib seaborn
```

---

## Running Benchmarks

### Full Benchmark Suite

```bash
cd Packages/NativeBenchmarks

# Build with optimization flags
chmod +x scripts/build.sh
./scripts/build.sh

# Expected output:
# ✓ Configuring build...
# ✓ Building project...
# ✓ Build complete: ./build/bin/anigma_benchmarks
```

### Run Benchmarks with Output

```bash
# Run with default settings
./build/bin/anigma_benchmarks

# Expected output format:
# ============================================================
# Anigma Native Benchmark Suite
# ============================================================
# 
# Text Processing Benchmarks:
#   String Trimming:       2.5432 µs (avg), 3.2345 µs (p95)
#   Lowercase:             3.8234 µs (avg), 4.5678 µs (p95)
#   ...
#
# Hashing Benchmarks:
#   pHash (64x64):        42.5678 µs (avg)
#   ...
```

### Benchmark Variations

```bash
# Run specific benchmark category
./build/bin/anigma_benchmarks --category hash

# Run with custom iterations
./build/bin/anigma_benchmarks --iterations 10000

# Save results to JSON
./build/bin/anigma_benchmarks --output results/custom.json

# Save results to CSV
./build/bin/anigma_benchmarks --format csv --output results/custom.csv

# Verbose output
./build/bin/anigma_benchmarks --verbose

# Run with memory profiling
./build/bin/anigma_benchmarks --profile-memory
```

### Batch Running for Statistical Stability

```bash
#!/bin/bash
# scripts/run_benchmarks_multiple.sh

set -e

RUNS=5
OUTPUT_DIR="results/runs"

mkdir -p "$OUTPUT_DIR"

for i in $(seq 1 $RUNS); do
    echo "Run $i / $RUNS..."
    ./build/bin/anigma_benchmarks \
        --output "$OUTPUT_DIR/run_$i.json"
    sleep 2  # Cool down between runs
done

# Average results
python3 scripts/average_results.py \
    --input-dir "$OUTPUT_DIR" \
    --output results/averaged.json

echo "Results saved to results/averaged.json"
```

---

## macOS Profiling with Instruments

### CPU Profiling

```bash
cd Packages/NativeBenchmarks

# Method 1: System CPU profiling
instruments -t 'CPU Samples' \
    -D results/cpu_profile.trace \
    ./build/bin/anigma_benchmarks

# Method 2: Time Profiler
instruments -t 'Time Profiler' \
    -D results/time_profile.trace \
    ./build/bin/anigma_benchmarks

# View results
# Open results/cpu_profile.trace in Instruments.app
open results/cpu_profile.trace
```

### Memory Profiling

```bash
# Allocations profiling (shows memory leaks and allocation patterns)
instruments -t 'Allocations' \
    -D results/allocations.trace \
    ./build/bin/anigma_benchmarks

# System Memory profiling
instruments -t 'System Memory' \
    -D results/system_memory.trace \
    ./build/bin/anigma_benchmarks

# Heap Allocations profiling
instruments -t 'Heap Allocations' \
    -D results/heap.trace \
    ./build/bin/anigma_benchmarks
```

### Cache & Performance Profiling

```bash
# System Trace (includes cache analysis)
instruments -t 'System Trace' \
    -D results/system_trace.trace \
    ./build/bin/anigma_benchmarks

# Counters profiling (CPU cycles, cache misses)
instruments -t 'Counters' \
    -D results/counters.trace \
    ./build/bin/anigma_benchmarks
```

### Interpreting Instruments Output

**Key Metrics to Look For:**

1. **CPU Samples**
   - Top functions consuming most CPU time
   - Call stacks showing function call paths
   - Look for hot paths > 10% of total time

2. **Allocations**
   - Total allocations count
   - Peak memory usage
   - Allocation frequency (allocs/sec)
   - Look for excessive allocations > 1M/sec

3. **System Trace**
   - Thread context switches
   - Lock contention
   - I/O operations
   - Look for lock wait time > 5%

4. **Counters**
   - CPU cycles per instruction (CPI)
   - Cache miss rates
   - Branch misses
   - Look for CPI > 4 (suboptimal), Cache miss > 20% (problematic)

### Exporting Instruments Data

```bash
# Export to XML
instruments -t 'CPU Samples' \
    -D results/cpu_profile.trace \
    -e xml \
    ./build/bin/anigma_benchmarks

# View trace file (programmatic access)
xcrun xctrace import results/cpu_profile.trace --terse

# Convert to text report
instruments -l /Profiles \
    results/cpu_profile.trace > results/cpu_profile_report.txt
```

---

## Linux Profiling

### perf Recording & Analysis

```bash
# Record with call stack
perf record -g -F 99 \
    -o results/perf.data \
    ./build/bin/anigma_benchmarks

# Generate report
perf report -i results/perf.data

# Print call stacks
perf script -i results/perf.data > results/perf_stack.txt

# Top functions by CPU time
perf report -i results/perf.data --sort=comm,dso,symbol

# Generate flamegraph
perf script -i results/perf.data | \
    stackcollapse-perf.pl | \
    flamegraph.pl > results/flamegraph.svg
```

### Installing Flamegraph Tools

```bash
# Clone flamegraph repository
git clone https://github.com/brendangregg/FlameGraph.git
cd FlameGraph

# Add to PATH
export PATH="$PATH:$(pwd)"

# Test
flamegraph.pl --help
```

### Valgrind Profiling (Memory Detailed Analysis)

```bash
# Massif - heap memory profiler
valgrind --tool=massif \
    --massif-out-file=results/massif.out \
    ./build/bin/anigma_benchmarks

# Generate report
ms_print results/massif.out > results/memory_report.txt

# Callgrind - CPU + memory profiler
valgrind --tool=callgrind \
    --callgrind-out-file=results/callgrind.out \
    ./build/bin/anigma_benchmarks

# View callgrind results
# Install kcachegrind: sudo apt-get install kcachegrind
kcachegrind results/callgrind.out &
```

### Cache Performance Analysis

```bash
# Cache miss analysis with perf
perf stat -e L1-dcache-load-misses,LLC-load-misses,cycles \
    ./build/bin/anigma_benchmarks

# Detailed cache analysis
perf record -e cache-references,cache-misses \
    ./build/bin/anigma_benchmarks
    
perf report
```

---

## Analyzing Results

### Python Analysis Script

Create `scripts/analyze_benchmarks.py`:

```python
#!/usr/bin/env python3

import json
import sys
import argparse
from pathlib import Path
import numpy as np
import pandas as pd

def load_results(filename):
    """Load benchmark results from JSON file"""
    with open(filename, 'r') as f:
        return json.load(f)

def compare_results(current, baseline, threshold=0.05):
    """Compare current results with baseline, detect regressions"""
    report = {
        'timestamp': pd.Timestamp.now().isoformat(),
        'results': {},
        'regressions': [],
        'improvements': []
    }
    
    for test_name, current_metrics in current.get('benchmarks', {}).items():
        baseline_metrics = baseline.get('benchmarks', {}).get(test_name, {})
        
        if not baseline_metrics:
            continue
        
        current_mean = current_metrics.get('mean')
        baseline_mean = baseline_metrics.get('mean')
        
        if current_mean is None or baseline_mean is None:
            continue
        
        regression_pct = (current_mean - baseline_mean) / baseline_mean
        
        report['results'][test_name] = {
            'baseline': baseline_mean,
            'current': current_mean,
            'change_pct': regression_pct * 100,
            'status': 'OK'
        }
        
        if regression_pct > threshold:
            report['results'][test_name]['status'] = 'REGRESSION'
            report['regressions'].append({
                'test': test_name,
                'regression': regression_pct * 100,
                'before': baseline_mean,
                'after': current_mean
            })
        elif regression_pct < -threshold:
            report['results'][test_name]['status'] = 'IMPROVED'
            report['improvements'].append({
                'test': test_name,
                'improvement': -regression_pct * 100,
                'before': baseline_mean,
                'after': current_mean
            })
    
    return report

def print_report(report):
    """Print analysis report"""
    print("\n" + "="*70)
    print("BENCHMARK ANALYSIS REPORT")
    print("="*70)
    
    # Regressions
    if report['regressions']:
        print("\n❌ REGRESSIONS DETECTED:")
        for reg in report['regressions']:
            print(f"  {reg['test']}: +{reg['regression']:.2f}% "
                  f"({reg['before']:.2f} → {reg['after']:.2f})")
    
    # Improvements
    if report['improvements']:
        print("\n✅ IMPROVEMENTS:")
        for imp in report['improvements']:
            print(f"  {imp['test']}: -{imp['improvement']:.2f}% "
                  f"({imp['before']:.2f} → {imp['after']:.2f})")
    
    # Summary
    print("\n📊 SUMMARY:")
    print(f"  Total tests: {len(report['results'])}")
    print(f"  Regressions: {len(report['regressions'])}")
    print(f"  Improvements: {len(report['improvements'])}")
    
    if not report['regressions'] and not report['improvements']:
        print("  Status: ✓ No significant changes")

def main():
    parser = argparse.ArgumentParser(description='Analyze benchmark results')
    parser.add_argument('--current', required=True, help='Current results JSON')
    parser.add_argument('--baseline', required=True, help='Baseline results JSON')
    parser.add_argument('--threshold', type=float, default=0.05, 
                       help='Regression threshold (default: 5%)')
    parser.add_argument('--output', help='Output JSON file')
    parser.add_argument('--verbose', action='store_true')
    
    args = parser.parse_args()
    
    # Load data
    current = load_results(args.current)
    baseline = load_results(args.baseline)
    
    # Compare
    report = compare_results(current, baseline, args.threshold)
    
    # Print
    print_report(report)
    
    # Save
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\n✓ Report saved to {args.output}")
    
    # Exit with error if regressions found
    if report['regressions']:
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### Running Analysis

```bash
# Compare current with baseline
python3 scripts/analyze_benchmarks.py \
    --current results/latest.json \
    --baseline results/baseline.json \
    --output results/comparison.json \
    --threshold 0.05

# With verbose output
python3 scripts/analyze_benchmarks.py \
    --current results/latest.json \
    --baseline results/baseline.json \
    --verbose
```

### Visualization

```python
#!/usr/bin/env python3
# scripts/visualize_results.py

import json
import matplotlib.pyplot as plt
import numpy as np

def plot_benchmark_comparison(current_file, baseline_file, output_file):
    """Create comparison chart"""
    
    with open(current_file) as f:
        current = json.load(f)
    with open(baseline_file) as f:
        baseline = json.load(f)
    
    tests = []
    current_times = []
    baseline_times = []
    
    for test_name, metrics in current.get('benchmarks', {}).items():
        baseline_metrics = baseline.get('benchmarks', {}).get(test_name, {})
        if baseline_metrics:
            tests.append(test_name)
            current_times.append(metrics.get('mean', 0))
            baseline_times.append(baseline_metrics.get('mean', 0))
    
    # Create figure
    fig, ax = plt.subplots(figsize=(12, 6))
    
    x = np.arange(len(tests))
    width = 0.35
    
    ax.bar(x - width/2, baseline_times, width, label='Baseline')
    ax.bar(x + width/2, current_times, width, label='Current')
    
    ax.set_ylabel('Time (µs)')
    ax.set_title('Benchmark Comparison: Baseline vs Current')
    ax.set_xticks(x)
    ax.set_xticklabels(tests, rotation=45, ha='right')
    ax.legend()
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=150)
    print(f"Chart saved to {output_file}")

if __name__ == '__main__':
    plot_benchmark_comparison(
        'results/latest.json',
        'results/baseline.json',
        'results/comparison.png'
    )
```

---

## CI/CD Integration

### GitHub Actions Integration

Create `.github/workflows/benchmark.yml`:

```yaml
name: Performance Benchmarks

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  benchmark:
    runs-on: [macos-latest, ubuntu-latest]
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies (macOS)
        if: runner.os == 'macOS'
        run: |
          brew install cmake
      
      - name: Install dependencies (Linux)
        if: runner.os == 'Linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y cmake gcc g++ build-essential python3
      
      - name: Build benchmarks
        working-directory: ./Packages/NativeBenchmarks
        run: |
          ./scripts/build.sh
      
      - name: Run benchmarks
        working-directory: ./Packages/NativeBenchmarks
        run: |
          ./build/bin/anigma_benchmarks --output results/current.json
      
      - name: Compare with baseline
        working-directory: ./Packages/NativeBenchmarks
        run: |
          python3 scripts/analyze_benchmarks.py \
            --current results/current.json \
            --baseline results/baseline.json \
            --threshold 0.10 \
            --output results/comparison.json
      
      - name: Upload results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: benchmark-results-${{ matrix.os }}
          path: Packages/NativeBenchmarks/results/
      
      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const comparison = JSON.parse(fs.readFileSync(
              'Packages/NativeBenchmarks/results/comparison.json', 'utf8'
            ));
            
            let comment = '## Benchmark Results\n\n';
            if (comparison.regressions.length > 0) {
              comment += '❌ **Regressions detected:**\n';
              comparison.regressions.forEach(reg => {
                comment += `- ${reg.test}: +${reg.regression.toFixed(2)}%\n`;
              });
            }
            if (comparison.improvements.length > 0) {
              comment += '✅ **Improvements:**\n';
              comparison.improvements.forEach(imp => {
                comment += `- ${imp.test}: -${imp.improvement.toFixed(2)}%\n`;
              });
            }
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

### Baseline Establishment

```bash
#!/bin/bash
# scripts/establish_baseline.sh

set -e

echo "Establishing benchmark baseline..."

cd Packages/NativeBenchmarks

# Build with optimization
./scripts/build.sh

# Run multiple times for stability
for i in {1..5}; do
    echo "Run $i/5..."
    ./build/bin/anigma_benchmarks --output results/baseline_run_$i.json
    sleep 2
done

# Average results
python3 scripts/average_results.py \
    --input results/baseline_run_*.json \
    --output results/baseline.json

echo "✓ Baseline established: results/baseline.json"
```

---

## Profiling Best Practices

### Before Profiling

1. **Close Other Applications**
   ```bash
   # macOS
   killall -9 Finder Dock Safari Chrome Firefox
   
   # Linux
   pkill firefox chrome chromium
   ```

2. **Disable Thermal Throttling** (Linux)
   ```bash
   sudo cpupower frequency-set -g performance
   ```

3. **Set High Priority**
   ```bash
   # macOS
   sudo nice -n -20 ./build/bin/anigma_benchmarks
   
   # Linux
   sudo chrt -f 99 ./build/bin/anigma_benchmarks
   ```

### Collection Tips

1. **Use Long Profiling Runs**
   - Minimum 30-60 seconds for stable results
   - Avoids JIT warm-up effects
   - Captures behavior variation

2. **Record Call Stacks**
   - perf: `-g` flag for call graphs
   - Instruments: Check "Record call stacks"
   - Enables flamegraph generation

3. **Multiple Runs**
   - Run 5-10 times for variance analysis
   - Average results
   - Check for consistency

### Analysis Tips

1. **Focus on Hot Paths**
   - Look for functions > 5% of total time
   - Trace call stacks
   - Find optimization opportunities

2. **Check Memory Patterns**
   - Peak memory usage
   - Allocation frequency
   - Cache efficiency

3. **Validate Profiling Artifacts**
   - Ensure representative workload
   - Check for anomalies
   - Cross-check with multiple tools

---

## Troubleshooting

### Build Issues

```bash
# Clean build
cd Packages/NativeBenchmarks
rm -rf build
./scripts/build.sh

# Verbose build
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=ON ..
make VERBOSE=1
```

### Profiling Issues

```bash
# Instruments crashes
# → Try without verbose flags
# → Reduce benchmark iterations
# → Update Xcode

# perf not available (Linux)
sudo apt-get install linux-tools-generic

# Permission denied (Linux)
echo 1 | sudo tee /proc/sys/kernel/perf_event_paranoid
```

### Performance Anomalies

- Run multiple times to check consistency
- Check for background processes
- Verify CPU frequency scaling is disabled
- Check thermal status (powermetrics on macOS)

---

## Next Steps

1. Establish baseline metrics
2. Profile before optimizations
3. Implement Phase 1 optimizations
4. Compare results
5. Document improvements
6. Iterate with Phase 2-3

