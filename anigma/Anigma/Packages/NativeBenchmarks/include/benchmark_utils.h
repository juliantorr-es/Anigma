// Copyright (c) 2025 Anigma
// Licensed under the MIT License

#ifndef ANIGMA_BENCHMARK_UTILS_H
#define ANIGMA_BENCHMARK_UTILS_H

#include <chrono>
#include <vector>
#include <algorithm>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <numeric>
#include <string>
#include <sstream>
#include <map>
#include <limits>
#include <functional>

#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/task_info.h>
#endif

namespace anigma {
namespace benchmark {

// =============================================================================
// MARK: - Timer Utilities
// =============================================================================

class Timer {
public:
    using Clock = std::chrono::high_resolution_clock;
    using Duration = std::chrono::nanoseconds;
    using TimePoint = std::chrono::time_point<Clock, Duration>;

    Timer() : start_(Clock::now()) {}

    void reset() {
        start_ = Clock::now();
    }

    // Get elapsed time in nanoseconds
    Duration elapsed_ns() const {
        return std::chrono::duration_cast<Duration>(Clock::now() - start_);
    }

    // Get elapsed time in microseconds
    double elapsed_us() const {
        auto count = std::chrono::duration_cast<std::chrono::microseconds>(
            Clock::now() - start_).count();
        return static_cast<double>(count);
    }

    // Get elapsed time in milliseconds
    double elapsed_ms() const {
        auto count = std::chrono::duration_cast<std::chrono::microseconds>(
            Clock::now() - start_).count();
        return static_cast<double>(count) / 1000.0;
    }

    // Get elapsed time in seconds
    double elapsed_s() const {
        return elapsed_ms() / 1000.0;
    }

private:
    TimePoint start_;
};

// =============================================================================
// MARK: - Statistics
// =============================================================================

struct Statistics {
    double count = 0;
    double sum = 0;
    double min = std::numeric_limits<double>::max();
    double max = std::numeric_limits<double>::lowest();
    double mean = 0;
    double stddev = 0;
    double p50 = 0;  // median
    double p95 = 0;
    double p99 = 0;
    double p999 = 0; // 99.9th percentile

    // Throughput metrics
    double throughput_ops_sec = 0;
    double throughput_mb_sec = 0;

    static Statistics compute(const std::vector<double>& measurements,
                             size_t operations = 1,
                             size_t bytes = 0) {
        Statistics stats;
        
        if (measurements.empty()) {
            return stats;
        }

        stats.count = measurements.size();
        stats.sum = std::accumulate(measurements.begin(), measurements.end(), 0.0);
        stats.mean = stats.sum / stats.count;
        stats.min = *std::min_element(measurements.begin(), measurements.end());
        stats.max = *std::max_element(measurements.begin(), measurements.end());

        // Calculate standard deviation
        double variance = 0;
        for (double val : measurements) {
            variance += (val - stats.mean) * (val - stats.mean);
        }
        stats.stddev = std::sqrt(variance / stats.count);

        // Calculate percentiles
        std::vector<double> sorted = measurements;
        std::sort(sorted.begin(), sorted.end());

        auto percentile = [&sorted](double p) -> double {
            size_t idx = static_cast<size_t>(sorted.size() * p);
            idx = std::min(idx, sorted.size() - 1);
            return sorted[idx];
        };

        stats.p50 = percentile(0.50);
        stats.p95 = percentile(0.95);
        stats.p99 = percentile(0.99);
        stats.p999 = percentile(0.999);

        // Throughput
        double total_time_s = stats.sum / 1000000.0; // assuming microseconds
        stats.throughput_ops_sec = (static_cast<double>(operations) * stats.count) / total_time_s;
        
        if (bytes > 0) {
            stats.throughput_mb_sec = (static_cast<double>(bytes) * stats.count) / 
                                     (total_time_s * 1000000.0);
        }

        return stats;
    }

    void print(const std::string& name) const {
        std::cout << "\n" << name << " Results:\n";
        std::cout << "  Count:         " << static_cast<int>(count) << "\n";
        std::cout << "  Mean:          " << std::fixed << std::setprecision(4) 
                  << mean << " µs\n";
        std::cout << "  Std Dev:       " << stddev << " µs\n";
        std::cout << "  Min:           " << min << " µs\n";
        std::cout << "  Max:           " << max << " µs\n";
        std::cout << "  p50:           " << p50 << " µs\n";
        std::cout << "  p95:           " << p95 << " µs\n";
        std::cout << "  p99:           " << p99 << " µs\n";
        std::cout << "  p999:          " << p999 << " µs\n";
        
        if (throughput_ops_sec > 0) {
            std::cout << "  Throughput:    " << std::fixed << std::setprecision(0)
                      << throughput_ops_sec << " ops/sec\n";
        }
        if (throughput_mb_sec > 0) {
            std::cout << "  Throughput:    " << std::fixed << std::setprecision(2)
                      << throughput_mb_sec << " MB/s\n";
        }
    }

    std::string to_json() const {
        std::ostringstream os;
        os << std::fixed << std::setprecision(4);
        os << "{\n";
        os << "  \"count\": " << static_cast<int>(count) << ",\n";
        os << "  \"mean_us\": " << mean << ",\n";
        os << "  \"stddev_us\": " << stddev << ",\n";
        os << "  \"min_us\": " << min << ",\n";
        os << "  \"max_us\": " << max << ",\n";
        os << "  \"p50_us\": " << p50 << ",\n";
        os << "  \"p95_us\": " << p95 << ",\n";
        os << "  \"p99_us\": " << p99 << ",\n";
        os << "  \"p999_us\": " << p999 << ",\n";
        os << "  \"throughput_ops_sec\": " << throughput_ops_sec;
        if (throughput_mb_sec > 0) {
            os << ",\n  \"throughput_mb_sec\": " << throughput_mb_sec;
        }
        os << "\n}";
        return os.str();
    }

    std::string to_csv() const {
        std::ostringstream os;
        os << std::fixed << std::setprecision(4);
        os << static_cast<int>(count) << ","
           << mean << ","
           << stddev << ","
           << min << ","
           << max << ","
           << p50 << ","
           << p95 << ","
           << p99 << ","
           << p999 << ","
           << throughput_ops_sec;
        if (throughput_mb_sec > 0) {
            os << "," << throughput_mb_sec;
        }
        return os.str();
    }
};

// =============================================================================
// MARK: - Benchmark Runner
// =============================================================================

class BenchmarkRunner {
public:
    using Benchmark = std::function<void(size_t iterations)>;

    struct Result {
        std::string name;
        Statistics stats;
        std::string description;
    };

    BenchmarkRunner() = default;

    void run(const std::string& name,
             const std::string& description,
             Benchmark benchmark,
             size_t min_iterations = 1,
             size_t max_iterations = 10000,
             size_t min_time_ms = 100) {
        
        std::cout << "\n[BENCHMARK] " << name << "\n";
        std::cout << "  Description: " << description << "\n";
        
        std::vector<double> measurements;
        size_t iterations = min_iterations;
        auto total_start = Timer();

        // Warm-up run
        benchmark(1);

        // Adaptive iteration count
        while (total_start.elapsed_ms() < min_time_ms && iterations <= max_iterations) {
            Timer timer;
            benchmark(iterations);
            double elapsed_us = timer.elapsed_us();
            measurements.push_back(elapsed_us);

            // Adapt iteration count
            double target_us = 10000.0; // Target 10ms per measurement
            iterations = static_cast<size_t>(
                iterations * target_us / std::max(1.0, elapsed_us)
            );
            iterations = std::min(iterations, max_iterations);
            iterations = std::max(iterations, min_iterations);
        }

        Statistics stats = Statistics::compute(measurements, iterations);
        stats.print(name);

        results_.push_back(Result{name, stats, description});
    }

    const std::vector<Result>& results() const {
        return results_;
    }

    void print_summary() const {
        std::cout << "\n" << std::string(80, '=') << "\n";
        std::cout << "BENCHMARK SUMMARY\n";
        std::cout << std::string(80, '=') << "\n";

        for (const auto& result : results_) {
            std::cout << std::left << std::setw(40) << result.name
                      << " mean: " << std::fixed << std::setprecision(2)
                      << result.stats.mean << " µs"
                      << " (p99: " << result.stats.p99 << " µs)\n";
        }
    }

private:
    std::vector<Result> results_;
};

// =============================================================================
// MARK: - Memory Utilities
// =============================================================================

class MemoryTracker {
public:
    struct Usage {
        size_t rss = 0;  // Resident Set Size
        size_t vms = 0;  // Virtual Memory Size
    };

    static Usage current_usage() {
        Usage usage;
        #ifdef __APPLE__
            // macOS implementation
            struct task_basic_info info = {};
            mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
            
            if (task_info(mach_task_self_, TASK_BASIC_INFO,
                         reinterpret_cast<task_info_t>(&info), &count) == KERN_SUCCESS) {
                usage.rss = info.resident_size;
                usage.vms = info.virtual_size;
            }
        #endif
        return usage;
    }

    static double get_rss_mb() {
        return static_cast<double>(current_usage().rss) / (1024.0 * 1024.0);
    }
};

// =============================================================================
// MARK: - Data Generation
// =============================================================================

class DataGenerator {
public:
    // Generate random bytes
    static std::vector<uint8_t> random_bytes(size_t size) {
        std::vector<uint8_t> data(size);
        for (size_t i = 0; i < size; ++i) {
            data[i] = rand() % 256;
        }
        return data;
    }

    // Generate repetitive pattern (highly compressible)
    static std::vector<uint8_t> repetitive_pattern(size_t size) {
        std::vector<uint8_t> data;
        std::string pattern = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        while (data.size() < size) {
            for (char c : pattern) {
                if (data.size() >= size) break;
                data.push_back(static_cast<uint8_t>(c));
            }
        }
        return data;
    }

    // Generate text-like data
    static std::vector<uint8_t> text_like_data(size_t size) {
        std::vector<uint8_t> data;
        std::string text = "The quick brown fox jumps over the lazy dog. ";
        while (data.size() < size) {
            for (char c : text) {
                if (data.size() >= size) break;
                data.push_back(static_cast<uint8_t>(c));
            }
        }
        return data;
    }

    // Generate random float vectors
    static std::vector<std::vector<float>> random_vectors(size_t count, size_t dimensions) {
        std::vector<std::vector<float>> vectors;
        for (size_t i = 0; i < count; ++i) {
            std::vector<float> vec;
            for (size_t j = 0; j < dimensions; ++j) {
                vec.push_back((static_cast<float>(rand()) / RAND_MAX) * 2.0f - 1.0f);
            }
            vectors.push_back(vec);
        }
        return vectors;
    }

    // Generate random strings
    static std::vector<std::string> random_strings(size_t count, size_t length) {
        std::vector<std::string> strings;
        const char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";
        
        for (size_t i = 0; i < count; ++i) {
            std::string str;
            for (size_t j = 0; j < length; ++j) {
                str += charset[rand() % (sizeof(charset) - 1)];
            }
            strings.push_back(str);
        }
        return strings;
    }
};

// =============================================================================
// MARK: - Utility Inline Literal
// =============================================================================

constexpr size_t operator"" _MB(unsigned long long bytes) {
    return bytes * 1024 * 1024;
}

constexpr size_t operator"" _KB(unsigned long long bytes) {
    return bytes * 1024;
}

} // namespace benchmark
} // namespace anigma

#endif // ANIGMA_BENCHMARK_UTILS_H
