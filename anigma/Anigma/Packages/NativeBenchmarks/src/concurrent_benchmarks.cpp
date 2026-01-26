// Copyright (c) 2025 Anigma
// Licensed under the MIT License

#include <chrono>
#include <vector>
#include <thread>
#include <mutex>
#include <atomic>
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <condition_variable>
#include <queue>
#include <cstdlib>

namespace anigma {
namespace benchmark {

// =============================================================================
// MARK: - Thread Pool Implementation
// =============================================================================

class SimpleThreadPool {
private:
    std::vector<std::thread> workers;
    std::queue<std::function<void()>> tasks;
    std::mutex queue_mutex;
    std::condition_variable condition;
    std::atomic<bool> stop{false};
    std::atomic<int> active_tasks{0};

public:
    explicit SimpleThreadPool(size_t num_threads) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers.emplace_back([this] { work(); });
        }
    }

    ~SimpleThreadPool() {
        stop = true;
        condition.notify_all();
        for (auto& w : workers) {
            w.join();
        }
    }

    void enqueue(std::function<void()> task) {
        {
            std::unique_lock<std::mutex> lock(queue_mutex);
            tasks.push(task);
            active_tasks++;
        }
        condition.notify_one();
    }

    void wait_all() {
        while (active_tasks > 0) {
            std::this_thread::yield();
        }
    }

private:
    void work() {
        while (true) {
            std::function<void()> task;
            {
                std::unique_lock<std::mutex> lock(queue_mutex);
                condition.wait(lock, [this] { return !tasks.empty() || stop; });
                if (stop && tasks.empty()) break;
                if (!tasks.empty()) {
                    task = tasks.front();
                    tasks.pop();
                }
            }
            if (task) {
                task();
                active_tasks--;
            }
        }
    }
};

// =============================================================================
// MARK: - Concurrent Benchmarks
// =============================================================================

class ConcurrentBenchmarks {
public:
    static void run() {
        std::cout << "\n" << std::string(80, '=') << "\n";
        std::cout << "CONCURRENT OPERATION BENCHMARKS\n";
        std::cout << std::string(80, '=') << "\n";

        run_thread_pool_performance();
        run_atomic_operations();
        run_lock_contention();
        run_thread_scaling();
    }

private:
    static void run_thread_pool_performance() {
        std::cout << "\n--- Thread Pool Performance ---\n";

        const int num_threads_options[] = {1, 2, 4, 8};
        const int num_tasks = 10000;

        for (int num_threads : num_threads_options) {
            benchmark_thread_pool(num_threads, num_tasks);
        }
    }

    static void benchmark_thread_pool(int num_threads, int num_tasks) {
        SimpleThreadPool pool(num_threads);
        std::atomic<int> completed{0};

        auto start = std::chrono::high_resolution_clock::now();

        // Enqueue all tasks
        for (int i = 0; i < num_tasks; ++i) {
            pool.enqueue([&completed]() {
                // Simulate light work
                for (int j = 0; j < 100; ++j) {
                    volatile int x = j * 2;
                    (void)x;
                }
                completed++;
            });
        }

        pool.wait_all();
        auto end = std::chrono::high_resolution_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        std::cout << "\nThread Pool (" << num_threads << " threads, " << num_tasks << " tasks):\n";
        std::cout << "  Total Time:    " << elapsed.count() << " ms\n";

        double throughput = static_cast<double>(num_tasks) / (elapsed.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " tasks/sec\n";
    }

    static void run_atomic_operations() {
        std::cout << "\n--- Atomic Operations ---\n";

        benchmark_atomic_increment();
        benchmark_atomic_compare_swap();
    }

    static void benchmark_atomic_increment() {
        const int num_threads = 8;
        const int increments_per_thread = 100000;
        std::vector<double> measurements;

        std::atomic<long long> counter{0};

        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (int t = 0; t < num_threads; ++t) {
            threads.emplace_back([&counter, increments_per_thread]() {
                for (int i = 0; i < increments_per_thread; ++i) {
                    counter.fetch_add(1, std::memory_order_relaxed);
                }
            });
        }

        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        int total_operations = num_threads * increments_per_thread;
        double throughput = static_cast<double>(total_operations) / (elapsed.count() / 1000.0);

        std::cout << "\nAtomic Increment (" << num_threads << " threads):\n";
        std::cout << "  Operations:    " << total_operations << "\n";
        std::cout << "  Total Time:    " << elapsed.count() << " ms\n";
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }

    static void benchmark_atomic_compare_swap() {
        const int num_threads = 4;
        const int attempts = 10000;
        std::vector<double> measurements;

        std::atomic<int> value{0};

        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (int t = 0; t < num_threads; ++t) {
            threads.emplace_back([&value, attempts]() {
                int successes = 0;
                for (int i = 0; i < attempts; ++i) {
                    int expected = value.load();
                    if (value.compare_exchange_strong(expected, expected + 1,
                                                     std::memory_order_relaxed)) {
                        successes++;
                    }
                }
            });
        }

        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        int total_attempts = num_threads * attempts;
        double throughput = static_cast<double>(total_attempts) / (elapsed.count() / 1000.0);

        std::cout << "\nAtomic Compare-Swap (" << num_threads << " threads):\n";
        std::cout << "  Attempts:      " << total_attempts << "\n";
        std::cout << "  Total Time:    " << elapsed.count() << " ms\n";
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }

    static void run_lock_contention() {
        std::cout << "\n--- Lock Contention ---\n";

        benchmark_mutex_contention();
    }

    static void benchmark_mutex_contention() {
        const int num_threads = 8;
        const int iterations = 10000;
        std::mutex mtx;
        long long counter = 0;

        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (int t = 0; t < num_threads; ++t) {
            threads.emplace_back([&mtx, &counter, iterations]() {
                for (int i = 0; i < iterations; ++i) {
                    {
                        std::lock_guard<std::mutex> lock(mtx);
                        counter++;
                    }
                }
            });
        }

        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        int total_operations = num_threads * iterations;
        double throughput = static_cast<double>(total_operations) / (elapsed.count() / 1000.0);

        std::cout << "\nMutex Lock Contention (" << num_threads << " threads):\n";
        std::cout << "  Operations:    " << total_operations << "\n";
        std::cout << "  Total Time:    " << elapsed.count() << " ms\n";
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
        std::cout << "  Final Counter: " << counter << "\n";
    }

    static void run_thread_scaling() {
        std::cout << "\n--- Thread Scaling ---\n";

        const int thread_counts[] = {1, 2, 4, 8, 16};
        const int work_per_thread = 100000;

        for (int num_threads : thread_counts) {
            benchmark_thread_scaling(num_threads, work_per_thread);
        }
    }

    static void benchmark_thread_scaling(int num_threads, int work_per_thread) {
        std::atomic<long long> total_work{0};

        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (int t = 0; t < num_threads; ++t) {
            threads.emplace_back([&total_work, work_per_thread]() {
                for (int i = 0; i < work_per_thread; ++i) {
                    // Simulate some computation
                    volatile int x = i * 2;
                    volatile int y = x + 1;
                    total_work++;
                    (void)y;
                }
            });
        }

        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        std::cout << "\nThread Scaling (" << num_threads << " threads):\n";
        std::cout << "  Total Work:    " << total_work.load() << "\n";
        std::cout << "  Total Time:    " << elapsed.count() << " ms\n";

        double throughput = static_cast<double>(total_work.load()) / (elapsed.count() / 1000.0);
        std::cout << "  Throughput:    " << std::fixed << std::setprecision(0) 
                  << throughput << " ops/sec\n";
    }
};

} // namespace benchmark
} // namespace anigma

int main_concurrent_benchmarks() {
    anigma::benchmark::ConcurrentBenchmarks::run();
    return 0;
}
