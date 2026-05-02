// Copyright (c) 2025 Anigma
// Licensed under the MIT License

#include <benchmark_utils.h>
#include <chrono>
#include <vector>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <numeric>
#include <cstdlib>

namespace anigma {
namespace benchmark {

// =============================================================================
// MARK: - Vector Operation Implementations
// =============================================================================

// Compute dot product of two vectors
float dot_product(const float* a, const float* b, size_t size) {
    float result = 0.0f;
    for (size_t i = 0; i < size; ++i) {
        result += a[i] * b[i];
    }
    return result;
}

// Compute magnitude (L2 norm) of a vector
float magnitude(const float* v, size_t size) {
    float sum = 0.0f;
    for (size_t i = 0; i < size; ++i) {
        sum += v[i] * v[i];
    }
    return std::sqrt(sum);
}

// Compute cosine similarity between two vectors
float cosine_similarity(const float* a, const float* b, size_t size) {
    float dot = dot_product(a, b, size);
    float mag_a = magnitude(a, size);
    float mag_b = magnitude(b, size);
    
    if (mag_a == 0.0f || mag_b == 0.0f) {
        return 0.0f;
    }
    
    return dot / (mag_a * mag_b);
}

// Normalize vector to unit length
void normalize_vector(float* v, size_t size) {
    float mag = magnitude(v, size);
    if (mag > 0.0f) {
        for (size_t i = 0; i < size; ++i) {
            v[i] /= mag;
        }
    }
}

// Batch dot products (computes dot product of multiple vector pairs)
void batch_dot_products(const float* a, const float* b, float* results, 
                       size_t vector_size, size_t pair_count) {
    for (size_t p = 0; p < pair_count; ++p) {
        results[p] = dot_product(&a[p * vector_size], &b[p * vector_size], vector_size);
    }
}

// Statistics helper
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
// MARK: - Vector Benchmarks
// =============================================================================

class VectorBenchmarks {
public:
    static void run() {
        std::cout << "\n" << std::string(80, '=') << "\n";
        std::cout << "VECTOR OPERATION BENCHMARKS\n";
        std::cout << std::string(80, '=') << "\n";

        run_dot_product_benchmarks();
        run_cosine_similarity_benchmarks();
        run_vector_normalization_benchmarks();
        run_batch_dot_product_benchmarks();
    }

private:
    static void run_dot_product_benchmarks() {
        const size_t vector_sizes[] = {128, 256, 768, 1024};

        for (size_t vec_size : vector_sizes) {
            run_dot_product_for_size(vec_size);
        }
    }

    static void run_dot_product_for_size(size_t vector_size) {
        // Allocate aligned vectors
        std::vector<float> a(vector_size, 1.0f);
        std::vector<float> b(vector_size, 2.0f);

        std::string name = "Dot Product (" + std::to_string(vector_size) + "-dim)";
        const BenchmarkMetadata metadata{
            "vector_dim=" + std::to_string(vector_size),
            "v1",
            {{"suite", "vector"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            name,
            "benchmarks.native.vector",
            metadata);
        
        const int iterations = 100000;
        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            volatile float result = dot_product(a.data(), b.data(), vector_size);
            (void)result;
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            volatile float result = dot_product(a.data(), b.data(), vector_size);
            auto t_end = std::chrono::high_resolution_clock::now();
            (void)result;

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        
        stats.print(name);

        double throughput = (iterations * vector_size) / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }

    static void run_cosine_similarity_benchmarks() {
        const size_t vector_sizes[] = {128, 256, 768, 1024};

        for (size_t vec_size : vector_sizes) {
            run_cosine_similarity_for_size(vec_size);
        }
    }

    static void run_cosine_similarity_for_size(size_t vector_size) {
        std::vector<float> a(vector_size, 1.0f);
        std::vector<float> b(vector_size, 2.0f);

        std::string name = "Cosine Similarity (" + std::to_string(vector_size) + "-dim)";
        const BenchmarkMetadata metadata{
            "vector_dim=" + std::to_string(vector_size),
            "v1",
            {{"suite", "vector"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            name,
            "benchmarks.native.vector",
            metadata);
        
        const int iterations = 50000;
        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            volatile float result = cosine_similarity(a.data(), b.data(), vector_size);
            (void)result;
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            volatile float result = cosine_similarity(a.data(), b.data(), vector_size);
            auto t_end = std::chrono::high_resolution_clock::now();
            (void)result;

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        
        stats.print(name);

        double throughput = iterations / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }

    static void run_vector_normalization_benchmarks() {
        const size_t vector_sizes[] = {128, 256, 768, 1024};

        for (size_t vec_size : vector_sizes) {
            run_normalization_for_size(vec_size);
        }
    }

    static void run_normalization_for_size(size_t vector_size) {
        // Use fresh vectors for each iteration to avoid cache effects
        const int iterations = 50000;
        std::vector<double> measurements;
        measurements.reserve(iterations);

        std::string name = "Vector Normalization (" + std::to_string(vector_size) + "-dim)";
        const BenchmarkMetadata metadata{
            "vector_dim=" + std::to_string(vector_size),
            "v1",
            {{"suite", "vector"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            name,
            "benchmarks.native.vector",
            metadata);

        // Warm-up
        for (int i = 0; i < 10; ++i) {
            std::vector<float> v(vector_size, 1.0f);
            normalize_vector(v.data(), vector_size);
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            std::vector<float> v(vector_size, 1.0f);
            
            auto t_start = std::chrono::high_resolution_clock::now();
            normalize_vector(v.data(), vector_size);
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        
        stats.print(name);

        double throughput = (iterations * vector_size) / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }

    static void run_batch_dot_product_benchmarks() {
        const size_t vector_size = 768;
        const size_t pair_counts[] = {100, 1000, 10000};

        for (size_t pair_count : pair_counts) {
            run_batch_for_size(vector_size, pair_count);
        }
    }

    static void run_batch_for_size(size_t vector_size, size_t pair_count) {
        std::vector<float> a(vector_size * pair_count, 1.0f);
        std::vector<float> b(vector_size * pair_count, 2.0f);
        std::vector<float> results(pair_count);

        std::string name = "Batch Dot Product (" + std::to_string(pair_count) + " pairs, " +
                          std::to_string(vector_size) + "-dim)";
        const BenchmarkMetadata metadata{
            "pair_count=" + std::to_string(pair_count) + ",vector_dim=" + std::to_string(vector_size),
            "v1",
            {{"suite", "vector"}}
        };
        auto span = begin_benchmark_span(
            DefaultCapsuleDiagnostics::shared(),
            name,
            "benchmarks.native.vector",
            metadata);
        
        const int iterations = 1000;
        std::vector<double> measurements;
        measurements.reserve(iterations);

        // Warm-up
        for (int i = 0; i < 5; ++i) {
            batch_dot_products(a.data(), b.data(), results.data(), vector_size, pair_count);
        }

        // Benchmarking
        auto start = std::chrono::high_resolution_clock::now();
        
        for (int i = 0; i < iterations; ++i) {
            auto t_start = std::chrono::high_resolution_clock::now();
            batch_dot_products(a.data(), b.data(), results.data(), vector_size, pair_count);
            auto t_end = std::chrono::high_resolution_clock::now();

            auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(t_end - t_start);
            measurements.push_back(static_cast<double>(elapsed.count()));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TimingStats stats;
        stats.compute(measurements);
        
        stats.print(name);

        double throughput = iterations / (total_time.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " batch/sec\n";
    }
};

} // namespace benchmark
} // namespace anigma

int main_vector_benchmarks() {
    anigma::benchmark::VectorBenchmarks::run();
    return 0;
}
