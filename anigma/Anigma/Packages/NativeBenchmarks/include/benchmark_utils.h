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
#include <fstream>
#include <memory>
#include <mutex>
#include <random>
#include <cstdlib>
#include <ctime>

#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/task_info.h>
#endif

namespace anigma {
namespace benchmark {

// =============================================================================
// MARK: - Capsule Diagnostics (C++ Adapter)
// =============================================================================

enum class SpanStatus {
    ok,
    error,
    cancelled,
    unknown
};

class DiagnosticSpan {
public:
    virtual ~DiagnosticSpan() = default;
    virtual void end(SpanStatus status) = 0;
    virtual void add_tag(const std::string& key, const std::string& value) = 0;
};

class CapsuleDiagnostics {
public:
    virtual ~CapsuleDiagnostics() = default;
    virtual std::unique_ptr<DiagnosticSpan> begin_span(
        const std::string& name,
        const std::string& category,
        const std::string& correlation_id,
        const std::map<std::string, std::string>& tags) = 0;
};

struct BenchmarkMetadata {
    std::string input_size;
    std::string algorithm_version;
    std::map<std::string, std::string> tags;

    std::map<std::string, std::string> to_tags() const {
        std::map<std::string, std::string> merged = tags;
        if (!input_size.empty()) {
            merged["input_size"] = input_size;
        }
        if (!algorithm_version.empty()) {
            merged["algorithm_version"] = algorithm_version;
        }
        return merged;
    }
};

class DefaultCapsuleDiagnostics;

class DefaultDiagnosticSpan final : public DiagnosticSpan {
public:
    DefaultDiagnosticSpan(
        DefaultCapsuleDiagnostics& diagnostics,
        std::string name,
        std::string category,
        std::string correlation_id,
        std::map<std::string, std::string> tags);

    void end(SpanStatus status) override;
    void add_tag(const std::string& key, const std::string& value) override;

private:
    DefaultCapsuleDiagnostics& diagnostics_;
    std::string name_;
    std::string category_;
    std::string correlation_id_;
    std::chrono::system_clock::time_point start_time_;
    std::map<std::string, std::string> tags_;
    bool ended_ = false;
};

class DefaultCapsuleDiagnostics final : public CapsuleDiagnostics {
public:
    explicit DefaultCapsuleDiagnostics(std::string output_path = default_output_path())
        : output_path_(std::move(output_path)),
          output_(output_path_, std::ios::app),
          correlation_id_(generate_correlation_id()) {}

    std::unique_ptr<DiagnosticSpan> begin_span(
        const std::string& name,
        const std::string& category,
        const std::string& correlation_id,
        const std::map<std::string, std::string>& tags) override {
        return std::make_unique<DefaultDiagnosticSpan>(
            *this,
            name,
            category,
            correlation_id.empty() ? correlation_id_ : correlation_id,
            tags);
    }

    static std::shared_ptr<DefaultCapsuleDiagnostics> shared() {
        static std::shared_ptr<DefaultCapsuleDiagnostics> instance =
            std::make_shared<DefaultCapsuleDiagnostics>();
        return instance;
    }

    void record_span(
        const std::string& span_id,
        const std::string& name,
        const std::string& category,
        const std::string& correlation_id,
        const std::chrono::system_clock::time_point& start_time,
        const std::chrono::system_clock::time_point& end_time,
        SpanStatus status,
        const std::map<std::string, std::string>& tags) {
        std::lock_guard<std::mutex> lock(output_mutex_);
        if (!output_.is_open()) {
            return;
        }

        const auto duration_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            end_time - start_time).count();

        output_ << "{\n"
                << "  \"type\": \"span\",\n"
                << "  \"span_id\": \"" << span_id << "\",\n"
                << "  \"name\": \"" << escape_json(name) << "\",\n"
                << "  \"category\": \"" << escape_json(category) << "\",\n"
                << "  \"correlation_id\": \"" << escape_json(correlation_id) << "\",\n"
                << "  \"start_time\": \"" << format_timestamp(start_time) << "\",\n"
                << "  \"end_time\": \"" << format_timestamp(end_time) << "\",\n"
                << "  \"duration_ms\": " << duration_ms << ",\n"
                << "  \"status\": \"" << status_to_string(status) << "\",\n"
                << "  \"tags\": " << format_tags(tags) << "\n"
                << "}\n";
        output_.flush();
    }

    std::string generate_span_id() {
        std::uniform_int_distribution<uint64_t> dist(0, std::numeric_limits<uint64_t>::max());
        std::ostringstream os;
        os << std::hex << std::setw(16) << std::setfill('0') << dist(rng_)
           << std::setw(16) << std::setfill('0') << dist(rng_);
        return os.str();
    }

private:
    static std::string default_output_path() {
        const char* env_path = std::getenv("ANIGMA_BENCHMARK_TELEMETRY_OUTPUT");
        if (env_path && env_path[0] != '\0') {
            return std::string(env_path);
        }
        return "benchmark_telemetry.jsonl";
    }

    static std::string format_timestamp(const std::chrono::system_clock::time_point& time_point) {
        std::time_t time_value = std::chrono::system_clock::to_time_t(time_point);
        std::tm tm_value = *std::gmtime(&time_value);
        std::ostringstream os;
        os << std::put_time(&tm_value, "%Y-%m-%dT%H:%M:%SZ");
        return os.str();
    }

    static std::string escape_json(const std::string& value) {
        std::ostringstream os;
        for (char c : value) {
            switch (c) {
            case '"': os << "\\\""; break;
            case '\\': os << "\\\\"; break;
            case '\n': os << "\\n"; break;
            case '\r': os << "\\r"; break;
            case '\t': os << "\\t"; break;
            default:
                if (static_cast<unsigned char>(c) < 0x20) {
                    os << "\\u" << std::hex << std::setw(4) << std::setfill('0')
                       << static_cast<int>(static_cast<unsigned char>(c));
                } else {
                    os << c;
                }
                break;
            }
        }
        return os.str();
    }

    static std::string format_tags(const std::map<std::string, std::string>& tags) {
        std::ostringstream os;
        os << "{";
        bool first = true;
        for (const auto& kv : tags) {
            if (!first) {
                os << ", ";
            }
            first = false;
            os << "\"" << escape_json(kv.first) << "\": \"" << escape_json(kv.second) << "\"";
        }
        os << "}";
        return os.str();
    }

    static std::string status_to_string(SpanStatus status) {
        switch (status) {
        case SpanStatus::ok:
            return "ok";
        case SpanStatus::error:
            return "error";
        case SpanStatus::cancelled:
            return "cancelled";
        case SpanStatus::unknown:
        default:
            return "unknown";
        }
    }

    static std::string generate_correlation_id() {
        std::ostringstream os;
        os << "benchmark-run-" << std::time(nullptr);
        return os.str();
    }

    std::string output_path_;
    std::ofstream output_;
    std::string correlation_id_;
    std::mutex output_mutex_;
    std::mt19937_64 rng_{std::random_device{}()};
};

inline DefaultDiagnosticSpan::DefaultDiagnosticSpan(
    DefaultCapsuleDiagnostics& diagnostics,
    std::string name,
    std::string category,
    std::string correlation_id,
    std::map<std::string, std::string> tags)
    : diagnostics_(diagnostics),
      name_(std::move(name)),
      category_(std::move(category)),
      correlation_id_(std::move(correlation_id)),
      start_time_(std::chrono::system_clock::now()),
      tags_(std::move(tags)) {}

inline void DefaultDiagnosticSpan::end(SpanStatus status) {
    if (ended_) {
        return;
    }
    ended_ = true;
    diagnostics_.record_span(
        diagnostics_.generate_span_id(),
        name_,
        category_,
        correlation_id_,
        start_time_,
        std::chrono::system_clock::now(),
        status,
        tags_);
}

inline void DefaultDiagnosticSpan::add_tag(const std::string& key, const std::string& value) {
    tags_[key] = value;
}

class ScopedDiagnosticSpan {
public:
    explicit ScopedDiagnosticSpan(std::unique_ptr<DiagnosticSpan> span)
        : span_(std::move(span)) {}

    ScopedDiagnosticSpan(ScopedDiagnosticSpan&& other) noexcept = default;
    ScopedDiagnosticSpan& operator=(ScopedDiagnosticSpan&& other) noexcept = default;

    ScopedDiagnosticSpan(const ScopedDiagnosticSpan&) = delete;
    ScopedDiagnosticSpan& operator=(const ScopedDiagnosticSpan&) = delete;

    ~ScopedDiagnosticSpan() {
        if (span_ && !ended_) {
            span_->end(status_);
        }
    }

    void mark_error() {
        status_ = SpanStatus::error;
    }

    void end(SpanStatus status) {
        if (span_ && !ended_) {
            ended_ = true;
            span_->end(status);
        }
    }

private:
    std::unique_ptr<DiagnosticSpan> span_;
    SpanStatus status_ = SpanStatus::ok;
    bool ended_ = false;
};

inline ScopedDiagnosticSpan begin_benchmark_span(
    const std::shared_ptr<CapsuleDiagnostics>& diagnostics,
    const std::string& name,
    const std::string& category,
    const BenchmarkMetadata& metadata) {
    if (!diagnostics) {
        return ScopedDiagnosticSpan(nullptr);
    }
    return ScopedDiagnosticSpan(diagnostics->begin_span(
        name,
        category,
        "",
        metadata.to_tags()));
}

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

    explicit BenchmarkRunner(
        std::string category = "benchmarks.native",
        std::shared_ptr<CapsuleDiagnostics> diagnostics = DefaultCapsuleDiagnostics::shared())
        : category_(std::move(category)), diagnostics_(std::move(diagnostics)) {}

    void run(const std::string& name,
             const std::string& description,
             const Benchmark& benchmark,
             const BenchmarkMetadata& metadata = {},
             size_t min_iterations = 1,
             size_t max_iterations = 10000,
             size_t min_time_ms = 100) {
        
        std::cout << "\n[BENCHMARK] " << name << "\n";
        std::cout << "  Description: " << description << "\n";
        
        ScopedDiagnosticSpan span = begin_benchmark_span(diagnostics_, name, category_, metadata);

        std::vector<double> measurements;
        size_t iterations = min_iterations;
        auto total_start = Timer();

        try {
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
        } catch (...) {
            span.mark_error();
            throw;
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
    std::string category_;
    std::shared_ptr<CapsuleDiagnostics> diagnostics_;
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
