import BenchmarkHarness
import BenchmarkSamples
import Foundation

struct BenchCLIOptions {
    var outputPath: String?
    var prettyPrinted = false
    var iterations: Int?
}

func parseOptions() -> BenchCLIOptions {
    var options = BenchCLIOptions()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()

    while let argument = iterator.next() {
        switch argument {
        case "--output":
            options.outputPath = iterator.next()
        case "--pretty":
            options.prettyPrinted = true
        case "--iterations":
            if let value = iterator.next(), let iterations = Int(value) {
                options.iterations = iterations
            }
        default:
            continue
        }
    }

    return options
}

@main
struct BenchmarkCLI {
    static func main() async {
        do {
            let options = parseOptions()
            let iterations = options.iterations ?? 2_000
            let benchmarks: [BenchmarkCase] = [
                StringJoinBenchmark(iterations: iterations)
            ]
            let runner = BenchmarkRunner()
            let report = try await runner.run(benchmarks: benchmarks)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.keyEncodingStrategy = .convertToSnakeCase
            if options.prettyPrinted {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }

            let data = try encoder.encode(report)

            if let outputPath = options.outputPath {
                let outputURL = URL(fileURLWithPath: outputPath)
                let folderURL = outputURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                try data.write(to: outputURL, options: [.atomic])
            }

            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([0x0A]))
        } catch {
            fputs("Benchmark run failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
