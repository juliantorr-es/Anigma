import BenchmarkHarness
import Foundation
import LayoutEngineCapsuleBenchmarks
import PDFCapsuleBenchmarks
import RankFusionCapsuleBenchmarks
import TextChunkingCapsuleBenchmarks
import VectorIndexCapsuleBenchmarks

struct BenchCLIOptions {
    var outputPath: String?
    var prettyPrinted = false
    var iterations: Int?
    var suite: BenchmarkSuite = .all
}

enum BenchmarkSuite: String {
    case all = "all"
    case hotPath = "hot-path"
    case vectorIndex = "vector-index"
    case rankFusion = "rank-fusion"
    case textChunking = "text-chunking"
    case pdf = "pdf"
    case layoutEngine = "layout-engine"
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
        case "--suite":
            if let value = iterator.next(), let suite = BenchmarkSuite(rawValue: value) {
                options.suite = suite
            }
        default:
            continue
        }
    }

    return options
}

func makeVectorIndexBenchmarks(iterations: Int?) throws -> [BenchmarkCase] {
    if let iterations {
        return [
            VectorIndexBuildBenchmark(iterations: iterations),
            try VectorIndexQueryBenchmark(iterations: iterations)
        ]
    }
    return [
        VectorIndexBuildBenchmark(),
        try VectorIndexQueryBenchmark()
    ]
}

func makeRankFusionBenchmarks(iterations: Int?) throws -> [BenchmarkCase] {
    if let iterations {
        return [try RankFusionMergeBenchmark(iterations: iterations)]
    }
    return [try RankFusionMergeBenchmark()]
}

func makeTextChunkingBenchmarks(iterations: Int?) throws -> [BenchmarkCase] {
    if let iterations {
        return [
            try TextChunkingLargeInputBenchmark(iterations: iterations),
            try TextIngestNormalizeChunkHotPathBenchmark(iterations: iterations)
        ]
    }
    return [
        try TextChunkingLargeInputBenchmark(),
        try TextIngestNormalizeChunkHotPathBenchmark()
    ]
}

func makePDFBenchmarks(iterations: Int?) throws -> [BenchmarkCase] {
    if let iterations {
        return [try PDFTextExtractionBenchmark(iterations: iterations)]
    }
    return [try PDFTextExtractionBenchmark()]
}

func makeLayoutEngineBenchmarks(iterations: Int?) throws -> [BenchmarkCase] {
    if let iterations {
        return [try LayoutEngineAnalysisBenchmark(iterations: iterations)]
    }
    return [try LayoutEngineAnalysisBenchmark()]
}

func makeBenchmarks(suite: BenchmarkSuite, iterations: Int?) throws -> [BenchmarkCase] {
    var benchmarks: [BenchmarkCase] = []

    switch suite {
    case .all:
        benchmarks.append(contentsOf: try makeVectorIndexBenchmarks(iterations: iterations))
        benchmarks.append(contentsOf: try makeRankFusionBenchmarks(iterations: iterations))
        benchmarks.append(contentsOf: try makeTextChunkingBenchmarks(iterations: iterations))
        benchmarks.append(contentsOf: try makePDFBenchmarks(iterations: iterations))
        benchmarks.append(contentsOf: try makeLayoutEngineBenchmarks(iterations: iterations))
    case .hotPath:
        if let iterations {
            benchmarks.append(try TextIngestNormalizeChunkHotPathBenchmark(iterations: iterations))
        } else {
            benchmarks.append(try TextIngestNormalizeChunkHotPathBenchmark())
        }
    case .vectorIndex:
        benchmarks.append(contentsOf: try makeVectorIndexBenchmarks(iterations: iterations))
    case .rankFusion:
        benchmarks.append(contentsOf: try makeRankFusionBenchmarks(iterations: iterations))
    case .textChunking:
        benchmarks.append(contentsOf: try makeTextChunkingBenchmarks(iterations: iterations))
    case .pdf:
        benchmarks.append(contentsOf: try makePDFBenchmarks(iterations: iterations))
    case .layoutEngine:
        benchmarks.append(contentsOf: try makeLayoutEngineBenchmarks(iterations: iterations))
    }

    return benchmarks
}

@main
struct BenchmarkCLI {
    static func main() async {
        do {
            let options = parseOptions()
            let benchmarks = try makeBenchmarks(suite: options.suite, iterations: options.iterations)
            let runner = BenchmarkRunner()
            let report = try await runner.run(benchmarks: benchmarks)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
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
