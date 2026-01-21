import Foundation
import AnigmaSystemSpine
import DataCore

public actor AIRegistry {
    private let storageURL: URL

    public init(storageURL: URL) {
        self.storageURL = storageURL
        Task {
            try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        }
    }

    // Models
    public func listModels() async throws -> [AIModel] {
        return try load(type: AIModel.self, directory: "models")
    }

    public func save(model: AIModel) async throws {
        try save(item: model, id: model.id, directory: "models")
    }

    // Providers
    public func listProviders() async throws -> [AIProvider] {
        return try load(type: AIProvider.self, directory: "providers")
    }

    public func save(provider: AIProvider) async throws {
        try save(item: provider, id: provider.id, directory: "providers")
    }

    // Tools
    public func listTools() async throws -> [AITool] {
        return try load(type: AITool.self, directory: "tools")
    }

    public func save(tool: AITool) async throws {
        try save(item: tool, id: tool.id, directory: "tools")
    }

    // Benchmarks
    public func listBenchmarks() async throws -> [AIBenchmark] {
        return try load(type: AIBenchmark.self, directory: "benchmarks")
    }

    public func save(benchmark: AIBenchmark) async throws {
        try save(item: benchmark, id: benchmark.id, directory: "benchmarks")
    }

    // Helpers
    private func load<T: Codable>(type: T.Type, directory: String) throws -> [T] {
        let dirURL = storageURL.appendingPathComponent(directory)
        guard FileManager.default.fileExists(atPath: dirURL.path) else { return [] }

        let fileURLs = try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
        return try fileURLs.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    private func save<T: Codable>(item: T, id: String, directory: String) throws {
        let dirURL = storageURL.appendingPathComponent(directory)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let fileURL = dirURL.appendingPathComponent("\(id).json")
        let data = try JSONEncoder().encode(item)
        try data.write(to: fileURL)
    }
}
