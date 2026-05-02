import Foundation
import AnigmaPrimitives

public enum ScoutFindingSeverity: String, Sendable, Codable, CaseIterable, Hashable {
    case critical
    case error
    case warning
    case info
}

public struct ScoutFinding: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public let projectId: UUID
    public var taskId: String?
    public let filePath: String
    public let problemKind: String
    public let severity: ScoutFindingSeverity
    public let description: String
    public let suggestedFix: String?
    public let lineStart: Int?
    public let lineEnd: Int?
    public let createdAt: Date
    public let astAnchorJSON: String?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        taskId: String? = nil,
        filePath: String,
        problemKind: String,
        severity: ScoutFindingSeverity,
        description: String,
        suggestedFix: String? = nil,
        lineStart: Int? = nil,
        lineEnd: Int? = nil,
        createdAt: Date = Date(),
        astAnchorJSON: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.taskId = taskId
        self.filePath = filePath
        self.problemKind = problemKind
        self.severity = severity
        self.description = description
        self.suggestedFix = suggestedFix
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.createdAt = createdAt
        self.astAnchorJSON = astAnchorJSON
    }
}
