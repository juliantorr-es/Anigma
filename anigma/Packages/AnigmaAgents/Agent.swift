import Foundation
import AnigmaCore
import AnigmaSystemSpine
import DataCore
import DataEngine

public enum AgentCapability: String, Sendable, Codable {
    case dataAnalysis
    case codeModification
    case corporateIntegration
    case educationIntegration
}

public struct AgentContext: Sendable {
    public let workspaceId: UUID
    public let sessionId: String
    public let jobEngine: JobEngine
    public let dataEngine: DataEngine
    public let registry: AIRegistry?
    public let workingDirectory: URL?

    public init(workspaceId: UUID, sessionId: String, jobEngine: JobEngine, dataEngine: DataEngine, registry: AIRegistry? = nil, workingDirectory: URL? = nil) {
        self.workspaceId = workspaceId
        self.sessionId = sessionId
        self.jobEngine = jobEngine
        self.dataEngine = dataEngine
        self.registry = registry
        self.workingDirectory = workingDirectory
    }
}

public struct AgentResult: Sendable {
    public let output: String
    public let artifacts: [DataCore.Artifact]
    public let receipt: DataCore.CoreReceipt

    public init(output: String, artifacts: [DataCore.Artifact], receipt: DataCore.CoreReceipt) {
        self.output = output
        self.artifacts = artifacts
        self.receipt = receipt
    }
}

public protocol Agent: Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var capabilities: [AgentCapability] { get }

    func execute(instruction: String, context: AgentContext) async throws -> AgentResult
}
