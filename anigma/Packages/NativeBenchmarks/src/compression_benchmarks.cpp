// Copyright (c) 2025 Anigma
// Licensed under the MIT License

#include <benchmark_utils.h>
#include <chrono>
#include <vector>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <cstdlib>

namespace anigma {
namespace benchmark {

// =============================================================================
// MARK: - Simple Compression Implementations
// =============================================================================

// Simple RLE (Run-Length Encoding) - for highly repetitive data
std::vector<uint8_t> rle_compress(const uint8_t* data, size_t size) {
    std::vector<uint8_t> compressed;
    
    if (size == 0) return compressed;
    
    size_t i = 0;
    while (i < size) {
        uint8_t byte = data[i];
        size_t run_length = 1;
        
        while (i + run_length < size && data[i + run_length] == byte && run_length < 255) {
            run_length++;
        }
        
        if (run_length >= 4) {
            // Encode as RLE: marker (255) + byte + count
            compressed.push_back(255);
            compressed.push_back(byte);
            compressed.push_back(static_cast<uint8_t>(run_length));
            i += run_length;
        } else {
            // Encode literally
            for (size_t j = 0; j < run_length; ++j) {
                compressed.push_back(byte);
            }
            i += run_length;
        }
    }
    
    return compressed;
}

// Simple LZ77-inspired compression for text-like data
std::vector<uint8_t> lz77_compress(const uint8_t* data, size_t size) {
    std::vector<uint8_t> compressed;
    
    size_t i = 0;
    while (i < size) {
        // Try to find a match in previous data
        int best_match_len = 0;
        int best_match_dist = 0;
        
        // Search window of 256 bytes
        size_t search_start = (i > 256) ? i - 256 : 0;
        
        for (size_t j = search_start; j < i; ++j) {
            size_t match_len = 0;
            while (j + match_len < i && i + match_len < size &&
                   data[j + match_len] == data[i + match_len] && match_len < 255) {
                match_len++;
            }
            
            if (match_len > best_match_len && match_len >= 4) {
                best_match_len = match_len;
                best_match_dist = i - j;
            }
        }
        
        if (best_match_len >= 4) {
            // Encode as match: marker (254) + distance + length
            compressed.push_back(254);
            compressed.push_back(static_cast<uint8_t>(best_match_dist));
            compressed.push_back(static_cast<uint8_t>(best_match_len));
            i += best_match_len;
        } else {
            // Encode as literal
            compressed.push_back(data[i]);
            i++;
        }
    }
    
    return compressed;
}

// Simple statistics helper
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
        size_t idx95 = static_cast<size_t>(measurements.size() * 0.95);
        size_t idx99 = static_cast<size_t>(measurements.size() * 0.99);
        p95 = measurements[idx95];
        p99 = measurements[idx99];
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
// MARK: - Compression Benchmarks
// =============================================================================

class CompressionBenchmarks {
public:
    static void run() {
        std::cout << "\n" << std::string(80, '=') << "\n";
        std::cout << "COMPRESSION BENCHMARKS\n";
        std::cout << std::string(80, '=') << "\n";

        // Test with different data patterns
        benchmark_random_data();
        benchmark_repetitive_data();
        benchmark_text_data();
    }

private:
    static std::vector<uint8_t> generate_random_data(size_t size) {
        std::vector<uint8_t> data(size);
        for (size_t i = 0; i < size; ++i) {
            data[i] = static_cast<uint8_t>(rand() % 256);
        }
        return data;
    }

    static std::vector<uint8_t> generate_repetitive_data(size_t size) {
        std::vector<uint8_t> data;
        const uint8_t pattern[] = {65, 66, 67, 68, 69};
        
        while (data.size() < size) {
            for (uint8_t p : pattern) {
                if (data.size() >= size) break;
                data.push_back(p);
            }
        }
        return data;
    }

    static std::vector<uint8_t> generate_text_data(size_t size) {
        std::vector<uint8_t> data;
        const char* text = "The quick brown fox jumps over the lazy dog. ";
        
        while (data.size() < size) {
            for (char c : std::string(text)) {
                if (data.size() >= size) break;
                data.push_back(static_cast<uint8_t>(c));
            }
        }
        return data;
    }

    static void benchmark_random_data() {
        const size_t data_size = 1024 * 1024; // 1 MB
        const auto data = generate_random_data(data_size);
        
        std::cout << "\n--- Random Data (1 MB) ---\n";
        benchmark_compression_rle(data, "Random Data (RLE)");
        benchmark_compression_lz77(data, "Random Data (LZ77)");
    }

    static void benchmark_repetitive_data() {
        const size_t data_size = 1024 * 1024; // 1 MB
        const auto data = generate_repetitive_data(data_size);
        
        std::cout << "\n--- Repetitive Data (1 MB) ---\n";
        benchmark_compression_rle(data, "Repetitive Data (RLE)");
        benchmark_compression_lz77(data, "Repetitive Data (LZ77)");
    }

    static void benchmark_text_data() {
        const size_t data_size = 1024 * 1024; // 1 MB
        const auto data = generate_text_data(data_size);
        
        std::cout << "\n--- Text Data (1 MB) ---\n";
        benchmark_compression_rle(data, "Text Data (RLE)");
        benchmark_compression_lz77(data, "Text Data (LZ77)");
    }

    static void benchmark_compression_rle(const std::vector<uint8_t>& data, const std::string& name) {
        const BenchmarkMetadata metadata{
            std::to_string(data.size()) + " bytes",
            "rle_v1",
            {{"suite", "compression"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            name,
            "benchmarks.native.compression",
            metadata);

        const int iterations = 10;
        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 2; ++i) {
            auto compressed = rle_compress(data.data(), data.size());
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        std::vector<uint8_t> last_result;
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            last_result = rle_compress(data.data(), data.size());
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        stats.print(name);

        double ratio = static_cast<double>(last_result.size()) / static_cast<double>(data.size());
        double throughput = (iterations * data.size()) / (total_time.count() / 1000.0) / 1e6;
        
        std::cout << "  Compression Ratio: " << std::fixed << std::setprecision(2) 
                  << (ratio * 100.0) << "%\n";
        std::cout << "  Throughput:    " << throughput << " MB/s\n";
    }

    static void benchmark_compression_lz77(const std::vector<uint8_t>& data, const std::string& name) {
        const BenchmarkMetadata metadata{
            std::to_string(data.size()) + " bytes",
            "lz77_v1",
            {{"suite", "compression"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            name,
            "benchmarks.native.compression",
            metadata);

        const int iterations = 5;
        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 2; ++i) {
            auto compressed = lz77_compress(data.data(), data.size());
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        std::vector<uint8_t> last_result;
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            last_result = lz77_compress(data.data(), data.size());
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        stats.print(name);

        double ratio = static_cast<double>(last_result.size()) / static_cast<double>(data.size());
        double throughput = (iterations * data.size()) / (total_time.count() / 1000.0) / 1e6;
        
        std::cout << "  Compression Ratio: " << std::fixed << std::setprecision(2) 
                  << (ratio * 100.0) << "%\n";
        std::cout << "  Throughput:    " << throughput << " MB/s\n";
    }
};

} // namespace benchmark
} // namespace anigma

int main_compression_benchmarks() {
    anigma::benchmark::CompressionBenchmarks::run();
    return 0;
}
