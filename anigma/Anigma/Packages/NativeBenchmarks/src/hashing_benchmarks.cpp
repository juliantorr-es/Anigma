// Copyright (c) 2025 Anigma
// Licensed under the MIT License

#include <benchmark_utils.h>
#include <chrono>
#include <array>
#include <vector>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <cmath>
#include <numeric>

namespace anigma {
namespace benchmark {

// =============================================================================
// MARK: - Hash Function Implementations
// =============================================================================

// Compute Hamming distance between two 64-bit hashes
uint32_t hamming_distance_64(uint64_t hash1, uint64_t hash2) {
    uint64_t xor_result = hash1 ^ hash2;
    uint32_t count = 0;
    while (xor_result) {
        count += xor_result & 1;
        xor_result >>= 1;
    }
    return count;
}

// Compute Hamming distance between two 256-bit hashes
uint32_t hamming_distance_256(const uint64_t* hash1, const uint64_t* hash2) {
    uint32_t distance = 0;
    for (int i = 0; i < 4; ++i) {
        distance += hamming_distance_64(hash1[i], hash2[i]);
    }
    return distance;
}

// Simple pHash simulation (DCT-based)
uint64_t compute_phash_simple(const uint8_t* data, size_t size) {
    // Simplified hash computation for benchmarking
    uint64_t hash = 5381;
    for (size_t i = 0; i < size; ++i) {
        hash = ((hash << 5) + hash) ^ data[i];
    }
    return hash;
}

// Simple dHash simulation (gradient-based)
uint64_t compute_dhash_simple(const uint8_t* data, size_t size) {
    // Simplified hash computation for benchmarking
    uint64_t hash = 0;
    for (size_t i = 1; i < size; ++i) {
        if (data[i] > data[i - 1]) {
            hash = (hash << 1) | 1;
        } else {
            hash = hash << 1;
        }
    }
    return hash;
}

// Generate random hash
uint64_t random_hash() {
    return static_cast<uint64_t>(rand()) << 32 | rand();
}

// =============================================================================
// MARK: - Statistics Helper
// =============================================================================

struct TimingStats {
    double mean = 0;
    double min = 1e9;
    double max = 0;
    double p95 = 0;
    double p99 = 0;

    void compute(std::vector<double>& measurements) {
        if (measurements.empty()) return;
        
        mean = 0;
        for (double m : measurements) {
            mean += m;
            min = std::min(min, m);
            max = std::max(max, m);
        }
        mean /= measurements.size();

        std::sort(measurements.begin(), measurements.end());
        p95 = measurements[static_cast<size_t>(measurements.size() * 0.95)];
        p99 = measurements[static_cast<size_t>(measurements.size() * 0.99)];
    }

    void print(const std::string& name) const {
        std::cout << "\n" << name << " Results:\n";
        std::cout << "  Mean:          " << std::fixed << std::setprecision(4) 
                  << mean << " µs\n";
        std::cout << "  Min:           " << min << " µs\n";
        std::cout << "  Max:           " << max << " µs\n";
        std::cout << "  p95:           " << p95 << " µs\n";
        std::cout << "  p99:           " << p99 << " µs\n";
    }
};

// =============================================================================
// MARK: - Hashing Benchmarks
// =============================================================================

class HashingBenchmarks {
public:
    static void run() {
        std::cout << "\n" << std::string(80, '=') << "\n";
        std::cout << "HASHING BENCHMARKS\n";
        std::cout << std::string(80, '=') << "\n";

        run_phash_benchmark();
        run_dhash_benchmark();
        run_hamming_distance_64();
        run_hamming_distance_256();
        run_hash_batch_search();
        run_256bit_hash_generation();
    }

private:
    static void run_phash_benchmark() {
        const size_t data_size = 4096; // 64x64 image
        const std::vector<uint8_t> test_data(data_size, 42);
        const int iterations = 10000;

        const BenchmarkMetadata metadata{
            "4096 bytes",
            "v1",
            {{"suite", "hashing"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            "pHash Computation (64x64)",
            "benchmarks.native.hashing",
            metadata);

        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            volatile auto hash = compute_phash_simple(test_data.data(), test_data.size());
            (void)hash;
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            volatile auto hash = compute_phash_simple(test_data.data(), test_data.size());
            auto t_end = std::chrono::high_resolution_clock::now();
            (void)hash;

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(elapsed.count());
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        stats.print("pHash Computation (64x64)");

        double throughput = (iterations * data_size) / (total_time.count() / 1000.0) / 1e6;
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(2) 
                  << throughput << " MB/s\n";
    }

    static void run_dhash_benchmark() {
        const size_t data_size = 4096; // 64x64 image
        const std::vector<uint8_t> test_data(data_size, 42);
        const int iterations = 10000;

        const BenchmarkMetadata metadata{
            "4096 bytes",
            "v1",
            {{"suite", "hashing"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            "dHash Computation (64x64)",
            "benchmarks.native.hashing",
            metadata);

        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            volatile auto hash = compute_dhash_simple(test_data.data(), test_data.size());
            (void)hash;
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            volatile auto hash = compute_dhash_simple(test_data.data(), test_data.size());
            auto t_end = std::chrono::high_resolution_clock::now();
            (void)hash;

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(elapsed.count());
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        stats.print("dHash Computation (64x64)");

        double throughput = (iterations * data_size) / (total_time.count() / 1000.0) / 1e6;
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(2) 
                  << throughput << " MB/s\n";
    }

    static void run_hamming_distance_64() {
        const int iterations = 100000;
        std::vector<double> measurements;
        measurements.reserve(iterations);

        const BenchmarkMetadata metadata{
            "1000 hashes",
            "v1",
            {{"suite", "hashing"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            "Hamming Distance (64-bit)",
            "benchmarks.native.hashing",
            metadata);

        std::vector<uint64_t> hashes;
        for (int i = 0; i < 1000; ++i) {
            hashes.push_back(random_hash());
        }

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            volatile auto dist = hamming_distance_64(hashes[0], hashes[1]);
            (void)dist;
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            
            volatile auto dist = hamming_distance_64(
                hashes[i % hashes.size()],
                hashes[(i + 1) % hashes.size()]
            );
            (void)dist;
            
            auto t_end = std::chrono::high_resolution_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(elapsed.count());
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        stats.print("Hamming Distance (64-bit)");

        double throughput = iterations / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }

    static void run_hamming_distance_256() {
        const int iterations = 10000;
        std::vector<double> measurements;
        measurements.reserve(iterations);

        const BenchmarkMetadata metadata{
            "1000 hashes",
            "v1",
            {{"suite", "hashing"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            "Hamming Distance (256-bit)",
            "benchmarks.native.hashing",
            metadata);

        std::vector<std::array<uint64_t, 4>> hashes;
        for (int i = 0; i < 1000; ++i) {
            std::array<uint64_t, 4> hash = {{random_hash(), random_hash(), random_hash(), random_hash()}};
            hashes.push_back(hash);
        }

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            volatile auto dist = hamming_distance_256(hashes[0].data(), hashes[1].data());
            (void)dist;
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            
            volatile auto dist = hamming_distance_256(
                hashes[i % hashes.size()].data(),
                hashes[(i + 1) % hashes.size()].data()
            );
            (void)dist;
            
            auto t_end = std::chrono::high_resolution_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(elapsed.count());
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        stats.print("Hamming Distance (256-bit)");

        double throughput = iterations / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }

    static void run_hash_batch_search() {
        const int candidate_count = 10000;
        const int iterations = 100;
        std::vector<double> measurements;

        const BenchmarkMetadata metadata{
            "10000 candidates",
            "v1",
            {{"suite", "hashing"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            "Hash Batch Search (10K candidates)",
            "benchmarks.native.hashing",
            metadata);

        std::vector<uint64_t> candidates(candidate_count);
        for (int i = 0; i < candidate_count; ++i) {
            candidates[i] = random_hash();
        }
        uint64_t query = candidates[0];

        // Warm-up
        for (int i = 0; i < 5; ++i) {
            int matches = 0;
            for (int j = 0; j < candidate_count; ++j) {
                if (hamming_distance_64(query, candidates[j]) <= 10) {
                    matches++;
                }
            }
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            
            volatile int matches = 0;
            for (int j = 0; j < candidate_count; ++j) {
                if (hamming_distance_64(query, candidates[j]) <= 10) {
                    matches++;
                }
            }
            
            auto t_end = std::chrono::high_resolution_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(t_end - t_start);
            measurements.push_back(elapsed.count());
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        stats.print("Hash Batch Search (10K candidates)");

        double throughput = (iterations * candidate_count) / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " comparisons/sec\n";
    }

    static void run_256bit_hash_generation() {
        const size_t data_size = 256; // 16x16 image for 256-bit hash
        const std::vector<uint8_t> test_data(data_size, 42);
        const int iterations = 10000;

        const BenchmarkMetadata metadata{
            "256 bytes",
            "v1",
            {{"suite", "hashing"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            "256-bit Hash Generation (16x16)",
            "benchmarks.native.hashing",
            metadata);

        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            std::array<uint64_t, 4> hash;
            for (int j = 0; j < 4; ++j) {
                hash[j] = compute_phash_simple(&test_data[j * 64], 64);
            }
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            
            std::array<uint64_t, 4> hash;
            for (int j = 0; j < 4; ++j) {
                hash[j] = compute_phash_simple(&test_data[j * 64], 64);
            }
            
            auto t_end = std::chrono::high_resolution_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(elapsed.count());
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        stats.print("256-bit Hash Generation (16x16)");

        double throughput = iterations / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " hashes/sec\n";
    }
};

} // namespace benchmark
} // namespace anigma

int main_hashing_benchmarks() {
    anigma::benchmark::HashingBenchmarks::run();
    return 0;
}
