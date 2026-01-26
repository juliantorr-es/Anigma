// Copyright (c) 2025 Anigma
// Licensed under the MIT License

#include <chrono>
#include <vector>
#include <cstdint>
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <cmath>
#include <memory>
#include <cstdlib>
#include <cstring>

namespace anigma {
namespace benchmark {

// =============================================================================
// MARK: - Memory Utilities
// =============================================================================

class MemoryStats {
    double mean_us = 0;
    double min_us = 1e9;
    double max_us = 0;
    double p95_us = 0;
    double p99_us = 0;
    size_t total_allocated = 0;

public:
    void compute(std::vector<double>& measurements, size_t allocated) {
        if (measurements.empty()) return;
        
        total_allocated = allocated;
        mean_us = 0;
        for (double m : measurements) {
            mean_us += m;
            min_us = std::min(min_us, m);
            max_us = std::max(max_us, m);
        }
        mean_us /= measurements.size();

        std::sort(measurements.begin(), measurements.end());
        size_t idx95 = static_cast<size_t>(measurements.size() * 0.95);
        size_t idx99 = static_cast<size_t>(measurements.size() * 0.99);
        p95_us = measurements[idx95];
        p99_us = measurements[idx99];
    }

    void print(const std::string& name) const {
        std::cout << "\n" << name << " Results:\n";
        std::cout << "  Mean:          " << std::fixed << std::setprecision(4) 
                  << mean_us << " µs\n";
        std::cout << "  Min:           " << min_us << " µs\n";
        std::cout << "  Max:           " << max_us << " µs\n";
        std::cout << "  p95:           " << p95_us << " µs\n";
        std::cout << "  p99:           " << p99_us << " µs\n";
        std::cout << "  Total Allocated: " << std::fixed << std::setprecision(2)
                  << (static_cast<double>(total_allocated) / (1024.0 * 1024.0))
                  << " MB\n";
    }
};

// =============================================================================
// MARK: - Memory Benchmarks
// =============================================================================

class MemoryBenchmarks {
public:
    static void run() {
        std::cout << "\n" << std::string(80, '=') << "\n";
        std::cout << "MEMORY PERFORMANCE BENCHMARKS\n";
        std::cout << std::string(80, '=') << "\n";

        run_allocation_patterns();
        run_cache_efficiency();
        run_large_buffer_handling();
        run_fragmentation_test();
    }

private:
    static void run_allocation_patterns() {
        std::cout << "\n--- Allocation Patterns ---\n";

        benchmark_small_allocations();
        benchmark_medium_allocations();
        benchmark_large_allocations();
    }

    static void benchmark_small_allocations() {
        const int iterations = 100000;
        const size_t alloc_size = 64; // 64 bytes
        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 100; ++i) {
            void* ptr = malloc(alloc_size);
            free(ptr);
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            void* ptr = malloc(alloc_size);
            auto t_mid = std::chrono::high_resolution_clock::now();
            free(ptr);
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        MemoryStats stats;
        stats.compute(measurements, iterations * alloc_size);
        stats.print("Small Allocations (64 bytes)");

        double throughput = iterations / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " alloc/sec\n";
    }

    static void benchmark_medium_allocations() {
        const int iterations = 10000;
        const size_t alloc_size = 4096; // 4 KB
        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            void* ptr = malloc(alloc_size);
            free(ptr);
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            void* ptr = malloc(alloc_size);
            auto t_end = std::chrono::high_resolution_clock::now();
            free(ptr);

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        MemoryStats stats;
        stats.compute(measurements, iterations * alloc_size);
        stats.print("Medium Allocations (4 KB)");

        double throughput = iterations / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " alloc/sec\n";
    }

    static void benchmark_large_allocations() {
        const int iterations = 100;
        const size_t alloc_size = 1024 * 1024; // 1 MB
        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 2; ++i) {
            void* ptr = malloc(alloc_size);
            free(ptr);
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            void* ptr = malloc(alloc_size);
            auto t_end = std::chrono::high_resolution_clock::now();
            free(ptr);

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        MemoryStats stats;
        stats.compute(measurements, iterations * alloc_size);
        stats.print("Large Allocations (1 MB)");

        double throughput = iterations / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " alloc/sec\n";
    }

    static void run_cache_efficiency() {
        std::cout << "\n--- Cache Efficiency ---\n";

        benchmark_sequential_access();
        benchmark_random_access();
        benchmark_strided_access();
    }

    static void benchmark_sequential_access() {
        const size_t array_size = 1024 * 1024;
        const int iterations = 1000;
        std::vector<int> data(array_size);
        
        // Initialize
        for (size_t i = 0; i < array_size; ++i) {
            data[i] = i;
        }

        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            volatile int sum = 0;
            for (size_t j = 0; j < array_size; ++j) {
                sum += data[j];
            }
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            volatile int sum = 0;
            for (size_t j = 0; j < array_size; ++j) {
                sum += data[j];
            }
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        MemoryStats stats;
        stats.compute(measurements, array_size * sizeof(int));
        stats.print("Sequential Access (1 MB array)");

        double throughput = (iterations * array_size * sizeof(int)) / (total_time.count() / 1000.0) / 1e9;
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(2) 
                  << throughput << " GB/s\n";
    }

    static void benchmark_random_access() {
        const size_t array_size = 64 * 1024;
        const int iterations = 10000;
        std::vector<int> data(array_size);
        
        // Initialize with indices
        for (size_t i = 0; i < array_size; ++i) {
            data[i] = i;
        }

        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            volatile int sum = 0;
            for (size_t j = 0; j < 1000; ++j) {
                sum += data[(j * 7919) % array_size];
            }
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            volatile int sum = 0;
            for (size_t j = 0; j < 100; ++j) {
                sum += data[(j * 7919) % array_size];
            }
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        MemoryStats stats;
        stats.compute(measurements, array_size * sizeof(int));
        stats.print("Random Access (256 KB array)");

        double throughput = (iterations * 100) / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }

    static void benchmark_strided_access() {
        const size_t array_size = 1024 * 1024;
        const int stride = 16;
        const int iterations = 100;
        std::vector<int> data(array_size);
        
        // Initialize
        for (size_t i = 0; i < array_size; ++i) {
            data[i] = i;
        }

        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 5; ++i) {
            volatile int sum = 0;
            for (size_t j = 0; j < array_size; j += stride) {
                sum += data[j];
            }
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            volatile int sum = 0;
            for (size_t j = 0; j < array_size; j += stride) {
                sum += data[j];
            }
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        MemoryStats stats;
        stats.compute(measurements, array_size * sizeof(int));
        stats.print("Strided Access (1 MB array, stride=16)");

        double throughput = (iterations * array_size * sizeof(int)) / (total_time.count() / 1000.0) / 1e9;
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(2) 
                  << throughput << " GB/s\n";
    }

    static void run_large_buffer_handling() {
        std::cout << "\n--- Large Buffer Handling ---\n";

        benchmark_buffer_copy();
        benchmark_buffer_fill();
    }

    static void benchmark_buffer_copy() {
        const size_t buffer_size = 64 * 1024 * 1024; // 64 MB
        const int iterations = 10;
        
        std::vector<uint8_t> src(buffer_size);
        std::vector<uint8_t> dst(buffer_size);
        
        // Initialize
        for (size_t i = 0; i < buffer_size; ++i) {
            src[i] = static_cast<uint8_t>(i % 256);
        }

        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            std::memcpy(dst.data(), src.data(), buffer_size);
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        MemoryStats stats;
        stats.compute(measurements, buffer_size);
        stats.print("Buffer Copy (64 MB)");

        double throughput = (iterations * buffer_size) / (total_time.count() / 1000.0) / 1e9;
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(2) 
                  << throughput << " GB/s\n";
    }

    static void benchmark_buffer_fill() {
        const size_t buffer_size = 64 * 1024 * 1024; // 64 MB
        const int iterations = 10;
        
        std::vector<uint8_t> dst(buffer_size);

        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            std::memset(dst.data(), 42, buffer_size);
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        MemoryStats stats;
        stats.compute(measurements, buffer_size);
        stats.print("Buffer Fill (64 MB)");

        double throughput = (iterations * buffer_size) / (total_time.count() / 1000.0) / 1e9;
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(2) 
                  << throughput << " GB/s\n";
    }

    static void run_fragmentation_test() {
        std::cout << "\n--- Memory Fragmentation ---\n";

        // Allocate and free in specific patterns to measure fragmentation
        const int block_count = 1000;
        const size_t block_size = 1024; // 1 KB
        std::vector<void*> blocks;

        auto start = std::chrono::high_resolution_clock::now();
        
        // Allocate
        for (int i = 0; i < block_count; ++i) {
            blocks.push_back(malloc(block_size));
        }

        auto mid = std::chrono::high_resolution_clock::now();
        auto alloc_time = std::chrono::duration_cast<std::chrono::milliseconds>(mid - start);

        // Free every other block
        for (int i = 1; i < block_count; i += 2) {
            free(blocks[i]);
        }

        auto post_free = std::chrono::high_resolution_clock::now();
        auto free_time = std::chrono::duration_cast<std::chrono::milliseconds>(post_free - mid);

        // Try to allocate again (should be fragmented)
        std::vector<void*> new_blocks;
        for (int i = 0; i < block_count / 2; ++i) {
            new_blocks.push_back(malloc(block_size));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto realloc_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - post_free);

        std::cout << "\nFragmentation Test Results:\n";
        std::cout << "  Initial Allocation (" << block_count << " x " << block_size 
                  << " bytes): " << alloc_time.count() << " ms\n";
        std::cout << "  Free Every Other Block: " << free_time.count() << " ms\n";
        std::cout << "  Re-allocation (fragmented): " << realloc_time.count() << " ms\n";

        double fragmentation_ratio = static_cast<double>(realloc_time.count()) / 
                                     static_cast<double>(alloc_time.count());
        std::cout << "  Fragmentation Ratio: " << std::fixed << std::setprecision(2) 
                  << fragmentation_ratio << "x\n";

        // Cleanup
        for (void* ptr : blocks) {
            free(ptr);
        }
        for (void* ptr : new_blocks) {
            free(ptr);
        }
    }
};

} // namespace benchmark
} // namespace anigma

int main_memory_benchmarks() {
    anigma::benchmark::MemoryBenchmarks::run();
    return 0;
}
