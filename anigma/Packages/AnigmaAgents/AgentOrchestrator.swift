import Foundation
import AnigmaSystemSpine
import DataEngine

public enum AgentError: Error {
    case agentNotFound(String)
}

public actor AgentOrchestrator {
    private var agents: [String: Agent] = [:]
    private let jobEngine: JobEngine
    private let dataEngine: DataEngine
    private let registry: AIRegistry?

    public init(jobEngine: JobEngine, dataEngine: DataEngine, registry: AIRegistry? = nil) {
        self.jobEngine = jobEngine
        self.dataEngine = dataEngine
        self.registry = registry
    }

    public func register(agent: Agent) {
        agents[agent.id] = agent
    }

    public func execute(agentId: String, instruction: String, workspaceId: UUID, workingDirectory: URL? = nil) async throws -> String {
        guard agents[agentId] != nil else {
            throw AgentError.agentNotFound(agentId)
        }

        let jobId = UUID()

        // Enqueue job for background processing by the sidecar daemon
        try await jobEngine.enqueue(
            SharedJob(
                id: jobId,
                type: .agentExecution,
                payload: instruction.data(using: .utf8) ?? Data(),
                idempotencyKey: jobId.uuidString,
                sourceSurface: "agent.orchestrator"
            )
        )

        // return jobId.uuidString
        return "Job \(jobId.uuidString.prefix(8)) enqueued for background execution."
    }
}
