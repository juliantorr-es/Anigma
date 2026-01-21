import Foundation
import AnigmaSystemSpine
import AnigmaAgents

public actor AIConsoleClient {
    private let jobEngine: JobEngine
    private let registry: AIRegistry

    public init(jobEngine: JobEngine, registry: AIRegistry) {
        self.jobEngine = jobEngine
        self.registry = registry
    }

    public func listModels() async throws -> [AIModel] {
        return try await registry.listModels()
    }

    public func listProviders() async throws -> [AIProvider] {
        return try await registry.listProviders()
    }

    public func listTools() async throws -> [AITool] {
        return try await registry.listTools()
    }

    public func listBenchmarks() async throws -> [AIBenchmark] {
        return try await registry.listBenchmarks()
    }

    public func installModel(url: URL) async throws -> String {
        let jobId = UUID()
        try await jobEngine.enqueue(
            SharedJob(
                id: jobId,
                type: .ingest,
                payload: url.absoluteString.data(using: .utf8) ?? Data(),
                idempotencyKey: url.absoluteString,
                sourceSurface: "ai.console"
            )
        )

        // In a real implementation, the job worker would update the registry upon completion.
        // For this spine, we'll optimistically add a "downloading" model entry or rely on the job receipt.
        // Let's add a placeholder model entry to the registry so the UI sees something.
        let model = AIModel(
            id: UUID().uuidString,
            name: url.lastPathComponent,
            family: "Unknown",
            format: "Unknown",
            quantization: nil,
            sizeBytes: 0,
            lastUsed: nil,
            isValidated: false
        )
        try await registry.save(model: model)

        return jobId.uuidString
    }

    public func verifyProvider(id: String) async throws -> String {
        let jobId = UUID()
        try await jobEngine.enqueue(
            SharedJob(
                id: jobId,
                type: .agentExecution,
                payload: "verify-provider:\(id)".data(using: .utf8) ?? Data(),
                idempotencyKey: "verify-\(id)-\(Date().timeIntervalSince1970)",
                sourceSurface: "ai.console"
            )
        )
        return jobId.uuidString
    }

    public func approveTool(id: String) async throws {
        // Update registry
        if let tools = try? await registry.listTools(), let tool = tools.first(where: { $0.id == id }) {
            let updatedTool = AITool(
                id: tool.id,
                name: tool.name,
                path: tool.path,
                fingerprint: tool.fingerprint,
                isApproved: true
            )
            try await registry.save(tool: updatedTool)
        }

        let jobId = UUID()
        try await jobEngine.enqueue(
            SharedJob(
                id: jobId,
                type: .governance,
                payload: "approve-tool:\(id)".data(using: .utf8) ?? Data(),
                idempotencyKey: "approve-\(id)-\(Date().timeIntervalSince1970)",
                sourceSurface: "ai.console"
            )
        )
    }

    public func runBenchmark(id: String) async throws -> String {
        let jobId = UUID()
        try await jobEngine.enqueue(
            SharedJob(
                id: jobId,
                type: .agentExecution,
                payload: "benchmark:\(id)".data(using: .utf8) ?? Data(),
                idempotencyKey: "benchmark-\(id)-\(Date().timeIntervalSince1970)",
                sourceSurface: "ai.console"
            )
        )
        return jobId.uuidString
    }
}
