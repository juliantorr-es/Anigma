import Foundation

public struct AgentPatch: Sendable {
    public let filePath: String
    public let diff: String

    public init(filePath: String, diff: String) {
        self.filePath = filePath
        self.diff = diff
    }
}

public struct AgentChangeSet: Sendable {
    public let id: UUID
    public let workspaceId: UUID
    public let title: String
    public let summary: String
    public let patches: [AgentPatch]
    public let generatedBy: String
    public let createdAt: Date

    public init(id: UUID, workspaceId: UUID, title: String, summary: String, patches: [AgentPatch], generatedBy: String, createdAt: Date) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.summary = summary
        self.patches = patches
        self.generatedBy = generatedBy
        self.createdAt = createdAt
    }
}

public struct ChangeSetManager {
    public init() {}

    public func createChangeSet(from patch: String, workspaceId: UUID, agentId: String) -> AgentChangeSet {
        // Placeholder for patch parsing logic
        return AgentChangeSet(
            id: UUID(),
            workspaceId: workspaceId,
            title: "Agent Proposal",
            summary: "Proposed by \(agentId)",
            patches: [AgentPatch(filePath: "unknown", diff: patch)],
            generatedBy: agentId,
            createdAt: Date()
        )
    }
}
