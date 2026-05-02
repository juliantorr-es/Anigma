import Foundation
import AnigmaSystemSpine
import DataCore

public protocol PipelineStage: Sendable {
    var id: String { get }
    func execute(input: Artifact, context: PipelineContext) async throws -> Artifact
}

public struct PipelineContext: Sendable {
    public let jobId: String
    public let policy: PolicyPosture
    public let budget: ResourceBudget

    public init(jobId: String, policy: PolicyPosture, budget: ResourceBudget) {
        self.jobId = jobId
        self.policy = policy
        self.budget = budget
    }
}

public struct PolicyPosture: Sendable {
    public let allowExternalTools: Bool
    public let allowNetwork: Bool

    public init(allowExternalTools: Bool, allowNetwork: Bool) {
        self.allowExternalTools = allowExternalTools
        self.allowNetwork = allowNetwork
    }
}

public struct ResourceBudget: Sendable {
    public let maxMemory: Int
    public let timeout: TimeInterval

    public init(maxMemory: Int, timeout: TimeInterval) {
        self.maxMemory = maxMemory
        self.timeout = timeout
    }
}
