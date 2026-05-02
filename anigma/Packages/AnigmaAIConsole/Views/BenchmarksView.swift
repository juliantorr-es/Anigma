import AnigmaAgents
import SwiftUI

struct BenchmarksView: View {
    let client: AIConsoleClient
    @State private var benchmarks: [AIBenchmark] = []

    var body: some View {
        List(benchmarks) { benchmark in
            VStack(alignment: .leading) {
                Text(benchmark.name).font(.headline)
                if let result = benchmark.result {
                    Text("Result: \(result)").font(.caption)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Benchmark: \(benchmark.name), Result: \(benchmark.result ?? "None")")
        }
        .accessibilityLabel("AI Benchmarks List")
        .overlay {
            if benchmarks.isEmpty {
                ContentUnavailableView("No Benchmarks Run", systemImage: "chart.bar", description: Text("Run benchmarks to evaluate model performance."))
            }
        }
        .task {
            benchmarks = (try? await client.listBenchmarks()) ?? []
        }
    }
}
