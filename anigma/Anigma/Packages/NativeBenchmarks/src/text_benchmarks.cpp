// Copyright (c) 2025 Anigma
// Licensed under the MIT License

#include <benchmark_utils.h>
#include <string>
#include <cctype>
#include <locale>
#include <regex>
#include <iostream>

namespace anigma {
namespace benchmark {

// =============================================================================
// MARK: - Text Processing Benchmarks
// =============================================================================

class TextBenchmarks {
public:
    static void run() {
        std::cout << "\n" << std::string(80, '=') << "\n";
        std::cout << "TEXT PROCESSING BENCHMARKS\n";
        std::cout << std::string(80, '=') << "\n";

        BenchmarkRunner runner("benchmarks.native.text");

        // String trimming benchmark
        run_string_trimming(runner);

        // Lowercase conversion benchmark
        run_lowercase_conversion(runner);

        // Regular expression matching
        run_regex_matching(runner);

        // UTF-8 validation
        run_utf8_validation(runner);

        // Character encoding/decoding
        run_character_encoding(runner);

        // String concatenation
        run_string_concatenation(runner);

        // Print summary
        runner.print_summary();
    }

private:
    static void run_string_trimming(BenchmarkRunner& runner) {
        const auto test_strings = DataGenerator::random_strings(1000, 100);
        
        const BenchmarkMetadata metadata{
            "1000x100 chars",
            "v1",
            {{"suite", "text"}}
        };

        runner.run(
            "String Trimming",
            "Trim whitespace from strings",
            [&test_strings](size_t iterations) {
                volatile size_t total = 0;
                for (size_t i = 0; i < iterations; ++i) {
                    for (const auto& str : test_strings) {
                        // Trim leading whitespace
                        size_t start = str.find_first_not_of(" \t\n\r");
                        // Trim trailing whitespace
                        size_t end = str.find_last_not_of(" \t\n\r");
                        if (start != std::string::npos && end != std::string::npos) {
                            auto trimmed = str.substr(start, end - start + 1);
                            total += trimmed.length();
                        }
                    }
                }
                return total;
            },
            metadata,
            1, 100, 100
        );
    }

    static void run_lowercase_conversion(BenchmarkRunner& runner) {
        const auto test_strings = DataGenerator::random_strings(1000, 100);
        
        const BenchmarkMetadata metadata{
            "1000x100 chars",
            "v1",
            {{"suite", "text"}}
        };

        runner.run(
            "Lowercase Conversion",
            "Convert strings to lowercase",
            [&test_strings](size_t iterations) {
                volatile size_t total = 0;
                for (size_t i = 0; i < iterations; ++i) {
                    for (const auto& str : test_strings) {
                        std::string lower;
                        for (char c : str) {
                            lower += std::tolower(static_cast<unsigned char>(c));
                        }
                        total += lower.length();
                    }
                }
                return total;
            },
            metadata,
            1, 100, 100
        );
    }

    static void run_regex_matching(BenchmarkRunner& runner) {
        const auto test_strings = DataGenerator::random_strings(100, 50);
        const std::regex email_pattern(R"([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})");
        
        const BenchmarkMetadata metadata{
            "100x50 chars",
            "v1",
            {{"suite", "text"}}
        };

        runner.run(
            "Regex Matching (email pattern)",
            "Match email patterns in strings",
            [&test_strings, &email_pattern](size_t iterations) {
                volatile size_t matches = 0;
                for (size_t i = 0; i < iterations; ++i) {
                    for (const auto& str : test_strings) {
                        if (std::regex_search(str, email_pattern)) {
                            matches++;
                        }
                    }
                }
                return matches;
            },
            metadata,
            1, 100, 100
        );
    }

    static void run_utf8_validation(BenchmarkRunner& runner) {
        // Create test UTF-8 strings
        std::vector<std::string> utf8_strings;
        utf8_strings.push_back("Hello World");
        utf8_strings.push_back("Héllo Wørld");
        utf8_strings.push_back("你好世界");
        utf8_strings.push_back("مرحبا بالعالم");
        utf8_strings.push_back("Привет мир");
        
        const BenchmarkMetadata metadata{
            "5 samples",
            "v1",
            {{"suite", "text"}}
        };

        runner.run(
            "UTF-8 Validation",
            "Validate UTF-8 encoded strings",
            [&utf8_strings](size_t iterations) {
                volatile size_t valid = 0;
                for (size_t i = 0; i < iterations; ++i) {
                    for (const auto& str : utf8_strings) {
                        // Simple UTF-8 validation
                        bool is_valid = true;
                        for (size_t j = 0; j < str.length(); ) {
                            unsigned char c = static_cast<unsigned char>(str[j]);
                            int bytes = 0;
                            
                            if ((c & 0x80) == 0) {
                                bytes = 1;
                            } else if ((c & 0xE0) == 0xC0) {
                                bytes = 2;
                            } else if ((c & 0xF0) == 0xE0) {
                                bytes = 3;
                            } else if ((c & 0xF8) == 0xF0) {
                                bytes = 4;
                            } else {
                                is_valid = false;
                                break;
                            }
                            
                            j += bytes;
                        }
                        if (is_valid) valid++;
                    }
                }
                return valid;
            },
            metadata,
            1, 1000, 100
        );
    }

    static void run_character_encoding(BenchmarkRunner& runner) {
        const std::string text = "The quick brown fox jumps over the lazy dog";
        
        const BenchmarkMetadata metadata{
            "43 chars",
            "v1",
            {{"suite", "text"}}
        };

        runner.run(
            "Character Encoding/Decoding",
            "Encode/decode string to UTF-8",
            [&text](size_t iterations) {
                volatile size_t total = 0;
                for (size_t i = 0; i < iterations; ++i) {
                    // Simulate encoding
                    std::string encoded;
                    for (char c : text) {
                        encoded += c;
                    }
                    // Simulate decoding
                    for (char c : encoded) {
                        total += static_cast<unsigned char>(c);
                    }
                }
                return total;
            },
            metadata,
            1, 10000, 100
        );
    }

    static void run_string_concatenation(BenchmarkRunner& runner) {
        const auto strings = DataGenerator::random_strings(100, 20);
        
        const BenchmarkMetadata metadata{
            "100x20 chars",
            "v1",
            {{"suite", "text"}}
        };

        runner.run(
            "String Concatenation",
            "Concatenate multiple strings",
            [&strings](size_t iterations) {
                volatile size_t total = 0;
                for (size_t i = 0; i < iterations; ++i) {
                    std::string result;
                    for (const auto& s : strings) {
                        result += s;
                    }
                    total += result.length();
                }
                return total;
            },
            metadata,
            1, 1000, 100
        );
    }
};

} // namespace benchmark
} // namespace anigma

int main_text_benchmarks() {
    anigma::benchmark::TextBenchmarks::run();
    return 0;
}
