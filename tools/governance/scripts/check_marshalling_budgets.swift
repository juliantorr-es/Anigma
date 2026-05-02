#!/usr/bin/env swift
// swift-tools-version: 6.0
// Validate capsule benchmark reports and budget guardrails.

import Foundation

struct BenchmarkReport: Codable {
    struct BenchmarkResult: Codable {
        let name: String
        let wallTimeSeconds: Double?
        let durationSeconds: Double
        let operations: Int
        let opsPerSecond: Double
        let memoryBytes: Int64?
        let rssBytes: Int64?
        let allocationCount: Int64?
        let crossLanguageCallCount: Int64?
        let bytesCopied: Int64?
    }

    let generatedAt: Date
    let results: [BenchmarkResult]
}

func fail(_ message: String) -> Never {
    fputs("❌ \(message)\n", stderr)
    exit(1)
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let packageRoot = projectRoot
let suite = ProcessInfo.processInfo.environment["CAPSULE_BENCH_SUITE"] ?? "all"
let iterations = ProcessInfo.processInfo.environment["CAPSULE_BENCH_ITERATIONS"] ?? "3"
let reportURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("capsule-benchmark-report.json")

print("📊 Running capsule benchmarks (\(suite), \(iterations) iterations)...")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = [
    "swift",
    "run",
    "--package-path",
    packageRoot.path,
    "anigma-capsule-bench",
    "--suite",
    suite,
    "--iterations",
    iterations,
    "--output",
    reportURL.path,
    "--pretty"
]
let vendorLibURL = projectRoot.appendingPathComponent("Vendor/lib")
process.currentDirectoryURL = vendorLibURL
process.environment = {
    var environment = ProcessInfo.processInfo.environment
    let dyldPath = vendorLibURL.path
    if let existing = environment["DYLD_LIBRARY_PATH"], !existing.isEmpty {
        environment["DYLD_LIBRARY_PATH"] = "\(dyldPath):\(existing)"
    } else {
        environment["DYLD_LIBRARY_PATH"] = dyldPath
    }
    if let existing = environment["LD_LIBRARY_PATH"], !existing.isEmpty {
        environment["LD_LIBRARY_PATH"] = "\(dyldPath):\(existing)"
    } else {
        environment["LD_LIBRARY_PATH"] = dyldPath
    }
    return environment
}()

let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe

do {
    try process.run()
    process.waitUntilExit()
} catch {
    fail("Unable to start benchmark harness: \(error)")
}

let harnessOutput = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
if !harnessOutput.isEmpty {
    print(harnessOutput, terminator: "")
}

guard process.terminationStatus == 0 else {
    fail("Benchmark harness failed with exit code \(process.terminationStatus)")
}

guard FileManager.default.fileExists(atPath: reportURL.path) else {
    fail("Benchmark harness did not write a report at \(reportURL.path)")
}

do {
    let data = try Data(contentsOf: reportURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(BenchmarkReport.self, from: data)

    guard !report.results.isEmpty else {
        fail("Benchmark report did not include any results")
    }

    for result in report.results {
        guard !result.name.isEmpty else {
            fail("Benchmark report included an unnamed result")
        }
        guard result.durationSeconds >= 0 else {
            fail("Benchmark \(result.name) reported a negative duration")
        }
        if let wallTimeSeconds = result.wallTimeSeconds {
            guard wallTimeSeconds >= 0 else {
                fail("Benchmark \(result.name) reported a negative wall time")
            }
        }
        guard result.opsPerSecond > 0 else {
            fail("Benchmark \(result.name) did not report a positive throughput")
        }
        guard result.memoryBytes != nil else {
            fail("Benchmark \(result.name) did not report memory usage")
        }
        guard result.rssBytes != nil else {
            fail("Benchmark \(result.name) did not report RSS usage")
        }
        guard result.allocationCount != nil else {
            fail("Benchmark \(result.name) did not report allocation count")
        }
        guard result.crossLanguageCallCount != nil else {
            fail("Benchmark \(result.name) did not report cross-language call count")
        }
        guard result.bytesCopied != nil else {
            fail("Benchmark \(result.name) did not report bytes copied")
        }
    }

    print("✅ Benchmark report validated (\(report.results.count) results)")
} catch {
    fail("Failed to decode benchmark report: \(error)")
}

exit(0)
