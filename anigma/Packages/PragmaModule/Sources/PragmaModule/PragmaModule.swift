//
//  PragmaModule.swift
//  PragmaModule
//
//  Work management domain for Anigma.
//  "Pragma" (πρᾶγμα) - Greek for "thing done, deed, matter, business"
//
//  This module provides:
//  - Tasks/Issues with statuses, assignees, due dates, dependencies
//  - Projects/Initiatives as containers with goals and timelines
//  - Hierarchy: Goal → Initiative → Project → Task/Subtask
//  - Workflows with configurable state machines
//  - Views: List, Board, Timeline, Calendar
//  - Collaboration: Comments, @mentions, notifications
//  - Automation: Rules engine with triggers and actions
//
//  All work items are ECS entities with components, governed by AnigmaCore.
//

import Foundation
import AnigmaCore
import ContractsCore
import GovernanceCore

// MARK: - Module Definition

/// The Pragma work management module.
public enum PragmaModule {
    public static let version = "0.1.0"
    public static let name = "Pragma"

    /// Initializes the Pragma module with governance integration.
    public static func initialize(governance: GovernanceController) async {
        // Register Pragma-specific write checks
        await governance.writeGate.registerCheck(WorkItemOwnershipCheck())
        await governance.writeGate.registerCheck(WorkflowTransitionCheck())

        // Log initialization
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: "system",
            module: "PragmaModule",
            description: "PragmaModule initialized (v\(version))",
            metadata: ["original_event_type": "systemStarted", "version": version]
        )
    }
}

// MARK: - Work Item Identifiers

/// Unique identifier for any work item (task, project, etc.)
public struct WorkItemId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }

    public var description: String {
        "Work(\(raw.uuidString.prefix(8)))"
    }
}

extension WorkItemId: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        if let uuid = UUID(uuidString: value) {
            self.raw = uuid
        } else {
            // Deterministic UUID from string for testing
            let data = Data(value.utf8)
            var bytes = [UInt8](repeating: 0, count: 16)
            for (i, byte) in data.prefix(16).enumerated() {
                bytes[i] = byte
            }
            self.raw = UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    }
}

// MARK: - Work Item Types

/// Classification of work items.
public enum WorkItemType: String, Codable, Sendable, CaseIterable {
    case task
    case subtask
    case bug
    case feature
    case story
    case epic
    case project
    case initiative
    case goal
    case milestone

    /// Whether this type can contain other work items.
    public var isContainer: Bool {
        switch self {
        case .project, .initiative, .goal, .epic:
            return true
        case .task, .subtask, .bug, .feature, .story, .milestone:
            return false
        }
    }

    /// Valid child types for container items.
    public var validChildTypes: [WorkItemType] {
        switch self {
        case .goal:
            return [.initiative, .project]
        case .initiative:
            return [.project, .epic]
        case .project:
            return [.epic, .story, .task, .bug, .feature, .milestone]
        case .epic:
            return [.story, .task, .bug, .feature]
        case .story:
            return [.subtask]
        case .task, .bug, .feature:
            return [.subtask]
        case .subtask, .milestone:
            return []
        }
    }
}

// MARK: - Priority

/// Priority levels for work items.
public enum WorkPriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case lowest = 0
    case low = 1
    case medium = 2
    case high = 3
    case highest = 4
    case critical = 5

    public static func < (lhs: WorkPriority, rhs: WorkPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .lowest: return "Lowest"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .highest: return "Highest"
        case .critical: return "Critical"
        }
    }

    public var emoji: String {
        switch self {
        case .lowest: return "⬇️"
        case .low: return "🔽"
        case .medium: return "➡️"
        case .high: return "🔼"
        case .highest: return "⬆️"
        case .critical: return "🔴"
        }
    }
}

// MARK: - Status Categories

/// High-level status categories for workflow states.
public enum StatusCategory: String, Codable, Sendable, CaseIterable {
    case todo
    case inProgress
    case done
    case cancelled

    public var isTerminal: Bool {
        self == .done || self == .cancelled
    }

    public var isActive: Bool {
        self == .inProgress
    }
}

// MARK: - Workflow Status

/// A status within a workflow.
public struct WorkflowStatus: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let category: StatusCategory
    public let color: String
    public let order: Int

    public init(id: String, name: String, category: StatusCategory, color: String = "#808080", order: Int = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.color = color
        self.order = order
    }

    // Built-in statuses
    public static let backlog = WorkflowStatus(id: "backlog", name: "Backlog", category: .todo, color: "#808080", order: 0)
    public static let todo = WorkflowStatus(id: "todo", name: "To Do", category: .todo, color: "#0052CC", order: 1)
    public static let inProgress = WorkflowStatus(id: "in_progress", name: "In Progress", category: .inProgress, color: "#FFAB00", order: 2)
    public static let inReview = WorkflowStatus(id: "in_review", name: "In Review", category: .inProgress, color: "#6554C0", order: 3)
    public static let done = WorkflowStatus(id: "done", name: "Done", category: .done, color: "#36B37E", order: 4)
    public static let cancelled = WorkflowStatus(id: "cancelled", name: "Cancelled", category: .cancelled, color: "#FF5630", order: 5)
}

// MARK: - Workflow Definition

/// Defines the state machine for a work item type.
public struct WorkflowDefinition: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let statuses: [WorkflowStatus]
    public let transitions: [WorkflowTransition]
    public let initialStatusId: String

    public init(
        id: String,
        name: String,
        description: String? = nil,
        statuses: [WorkflowStatus],
        transitions: [WorkflowTransition],
        initialStatusId: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.statuses = statuses
        self.transitions = transitions
        self.initialStatusId = initialStatusId
    }

    /// Gets valid next statuses from a given status.
    public func validTransitions(from statusId: String) -> [WorkflowStatus] {
        let validIds = transitions
            .filter { $0.fromStatusId == statusId }
            .map { $0.toStatusId }
        return statuses.filter { validIds.contains($0.id) }
    }

    /// Checks if a transition is valid.
    public func isValidTransition(from: String, to: String) -> Bool {
        transitions.contains { $0.fromStatusId == from && $0.toStatusId == to }
    }

    /// Default simple workflow.
    public static let simple = WorkflowDefinition(
        id: "simple",
        name: "Simple Workflow",
        description: "Basic To Do → In Progress → Done workflow",
        statuses: [.todo, .inProgress, .done, .cancelled],
        transitions: [
            WorkflowTransition(fromStatusId: "todo", toStatusId: "in_progress"),
            WorkflowTransition(fromStatusId: "in_progress", toStatusId: "done"),
            WorkflowTransition(fromStatusId: "in_progress", toStatusId: "todo"),
            WorkflowTransition(fromStatusId: "todo", toStatusId: "cancelled"),
            WorkflowTransition(fromStatusId: "in_progress", toStatusId: "cancelled")
        ],
        initialStatusId: "todo"
    )

    /// Software development workflow.
    public static let software = WorkflowDefinition(
        id: "software",
        name: "Software Development",
        description: "Backlog → To Do → In Progress → In Review → Done",
        statuses: [.backlog, .todo, .inProgress, .inReview, .done, .cancelled],
        transitions: [
            WorkflowTransition(fromStatusId: "backlog", toStatusId: "todo"),
            WorkflowTransition(fromStatusId: "todo", toStatusId: "in_progress"),
            WorkflowTransition(fromStatusId: "in_progress", toStatusId: "in_review"),
            WorkflowTransition(fromStatusId: "in_review", toStatusId: "done"),
            WorkflowTransition(fromStatusId: "in_review", toStatusId: "in_progress"),
            WorkflowTransition(fromStatusId: "todo", toStatusId: "backlog"),
            WorkflowTransition(fromStatusId: "backlog", toStatusId: "cancelled"),
            WorkflowTransition(fromStatusId: "todo", toStatusId: "cancelled"),
            WorkflowTransition(fromStatusId: "in_progress", toStatusId: "cancelled")
        ],
        initialStatusId: "backlog"
    )
}

/// A transition between workflow statuses.
public struct WorkflowTransition: Codable, Sendable, Equatable {
    public let fromStatusId: String
    public let toStatusId: String
    public let name: String?
    public let requiresComment: Bool
    public let automationTrigger: String?

    public init(
        fromStatusId: String,
        toStatusId: String,
        name: String? = nil,
        requiresComment: Bool = false,
        automationTrigger: String? = nil
    ) {
        self.fromStatusId = fromStatusId
        self.toStatusId = toStatusId
        self.name = name
        self.requiresComment = requiresComment
        self.automationTrigger = automationTrigger
    }
}

// MARK: - Write Checks

/// Checks that the principal has permission to modify work items they don't own.
public struct WorkItemOwnershipCheck: WriteCheck {
    public let id = "pragma-ownership"
    public let name = "Work Item Ownership Check"
    public let isBlocking = false  // Non-blocking, just advisory

    public init() {}

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        proposal.module == "Pragma" && proposal.componentType == "TaskComponent"
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        // For now, always pass - real implementation would check ownership
        .pass(checkId: id, message: "Ownership check passed")
    }
}

/// Checks that workflow transitions are valid.
public struct WorkflowTransitionCheck: WriteCheck {
    public let id = "pragma-workflow-transition"
    public let name = "Workflow Transition Check"
    public let isBlocking = true

    public init() {}

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        proposal.module == "Pragma" && proposal.operation == "status_change"
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        // Real implementation would validate against workflow definition
        guard let fromStatus = proposal.context["from_status"],
              let toStatus = proposal.context["to_status"] else {
            return .fail(checkId: id, message: "Missing status information")
        }

        // For now, always pass - real implementation would check workflow
        return .pass(checkId: id, message: "Transition from \(fromStatus) to \(toStatus) is valid")
    }
}

// MARK: - Pragma Errors

public enum PragmaError: Error, LocalizedError, Sendable {
    case workItemNotFound(WorkItemId)
    case invalidTransition(from: String, to: String)
    case invalidParentType(child: WorkItemType, parent: WorkItemType)
    case circularDependency(WorkItemId)
    case permissionDenied(reason: String)
    case workflowNotFound(String)
    case duplicateKey(String)

    public var errorDescription: String? {
        switch self {
        case .workItemNotFound(let id):
            return "Work item not found: \(id)"
        case .invalidTransition(let from, let to):
            return "Invalid workflow transition from '\(from)' to '\(to)'"
        case .invalidParentType(let child, let parent):
            return "Cannot add \(child.rawValue) to \(parent.rawValue)"
        case .circularDependency(let id):
            return "Circular dependency detected involving: \(id)"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .workflowNotFound(let id):
            return "Workflow not found: \(id)"
        case .duplicateKey(let key):
            return "Duplicate key: \(key)"
        }
    }
}

// MARK: - Database Integration

private actor PragmaDatabase {
    internal let dbActor: DatabaseAuthorityAdapter
    
    public init(dbActor: DatabaseAuthorityAdapter) {
        self.dbActor = dbActor
    }
    
    public func migrate() async throws {
        // Open the database connection
        try await dbActor.open()
        // No schema migrations yet
        // Future migrations will be added here
    }
}

// MARK: - CapabilityModule Conformance

extension PragmaModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // Get database adapter for migration compatibility
        let databaseAuthority = await runtime.database
        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
        let database = PragmaDatabase(dbActor: databaseAdapter)
        try await database.migrate()
        
        // TODO: Set up other authorities (evidence, artifact) if used
        
        await Logger.shared.info("PragmaModule registered with database adapter", category: "Runtime")
    }
}
