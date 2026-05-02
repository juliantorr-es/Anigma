// Copyright (c) 2025 Anigma
// Licensed under the MIT License

#include <iostream>
#include <chrono>
#include <string>
#include <vector>
#include <iomanip>

// Forward declarations
namespace anigma {
namespace benchmark {
    class TextBenchmarks;
    class HashingBenchmarks;
    class VectorBenchmarks;
    class CompressionBenchmarks;
    class MemoryBenchmarks;
    class ConcurrentBenchmarks;
}
}

// Forward declarations of entry points
extern int main_text_benchmarks();
extern int main_hashing_benchmarks();
extern int main_vector_benchmarks();
extern int main_compression_benchmarks();
extern int main_memory_benchmarks();
extern int main_concurrent_benchmarks();

void print_header() {
    std::cout << "\n";
    std::cout << "================================== BENCHMARK SUITE ==================================\n";
    std::cout << "                  ANIGMA NATIVE CAPSULE BENCHMARK SUITE\n";
    std::cout << "                       C++ Performance Benchmarks v1.0\n";
    std::cout << "================================================================================\n";
    std::cout << "\nBenchmarking native components across multiple performance dimensions:\n";
    std::cout << "  - Text Processing (normalization, encoding, regex)\n";
    std::cout << "  - Hashing (pHash, dHash, Hamming distance)\n";
    std::cout << "  - Vector Operations (dot product, cosine similarity)\n";
    std::cout << "  - Data Compression (RLE, LZ77)\n";
    std::cout << "  - Memory Performance (allocation, cache, buffers)\n";
    std::cout << "  - Concurrent Operations (threading, atomics, locks)\n";
}

void print_footer(double total_time) {
    std::cout << "\n";
    std::cout << "================================================================================\n";
    std::cout << "                         BENCHMARK SUITE COMPLETED\n";
    std::cout << "================================================================================\n";
    std::cout << std::fixed << std::setprecision(2);
    std::cout << "Total Execution Time: " << total_time << " seconds\n\n";
}

int main() {
    auto start_time = std::chrono::high_resolution_clock::now();
    
    print_header();
    
    std::vector<std::pair<std::string, int (*)()>> benchmarks = {
        {"Text Processing Benchmarks", main_text_benchmarks},
        {"Hashing Benchmarks", main_hashing_benchmarks},
        {"Vector Operation Benchmarks", main_vector_benchmarks},
        {"Compression Benchmarks", main_compression_benchmarks},
        {"Memory Performance Benchmarks", main_memory_benchmarks},
        {"Concurrent Operation Benchmarks", main_concurrent_benchmarks},
    };
    
    int failed_benchmarks = 0;
    for (const auto& benchmark : benchmarks) {
        std::cout << "\n" << std::string(80, '-') << "\n";
        std::cout << "Running: " << benchmark.first << "\n";
        std::cout << std::string(80, '-') << "\n";
        
        try {
            int result = benchmark.second();
            if (result != 0) {
                std::cerr << "WARNING: " << benchmark.first << " returned non-zero exit code\n";
                failed_benchmarks++;
            }
        } catch (const std::exception& e) {
            std::cerr << "ERROR in " << benchmark.first << ": " << e.what() << "\n";
            failed_benchmarks++;
        }
    }
    
    auto end_time = std::chrono::high_resolution_clock::now();
    auto total_duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        end_time - start_time
    );
    double total_seconds = static_cast<double>(total_duration.count()) / 1000.0;
    
    print_footer(total_seconds);
    
    if (failed_benchmarks > 0) {
        std::cerr << "WARNING: " << failed_benchmarks << " benchmark(s) had issues\n";
        return 1;
    }
    
    std::cout << "All benchmarks completed successfully!\n";
    return 0;
}
