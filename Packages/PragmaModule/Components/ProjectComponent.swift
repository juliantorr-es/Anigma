//
//  ProjectComponent.swift
//  PragmaModule
//
//  Project container component for organizing work items.
//

import Foundation
import AnigmaCore

/// Component representing a project or initiative.
/// Projects are containers for tasks and have their own lifecycle.
public struct ProjectComponent: Component, Codable, Identifiable, Sendable {
    // MARK: - Identity

    /// Unique project ID.
    public let id: WorkItemId

    /// Project key prefix (e.g., "PROJ" for "PROJ-123").
    public var keyPrefix: String

    /// Next task number for key generation.
    public var nextTaskNumber: Int

    /// Project name.
    public var name: String

    /// Project description (Markdown).
    public var description: String?

    // MARK: - Classification

    /// Type of project container.
    public var itemType: WorkItemType

    /// Current status.
    public var status: ProjectStatus

    /// Project category.
    public var category: String?

    // MARK: - Ownership

    /// Project lead/owner user ID.
    public var leadId: String

    /// Team member user IDs.
    public var memberIds: [String]

    /// Parent project/initiative ID (for nested projects).
    public var parentId: WorkItemId?

    // MARK: - Scheduling

    /// Planned start date.
    public var startDate: Date?

    /// Target end date.
    public var targetDate: Date?

    /// Actual completion date.
    public var completedAt: Date?

    // MARK: - Configuration

    /// Default workflow ID for new tasks.
    public var defaultWorkflowId: String

    /// Enabled work item types for this project.
    public var enabledItemTypes: [WorkItemType]

    /// Project settings.
    public var settings: ProjectSettings

    // MARK: - Metadata

    /// Tags for project categorization.
    public var tags: [String]

    /// Custom fields.
    public var customFields: [String: String]

    // MARK: - Timestamps

    public let createdAt: Date
    public var updatedAt: Date
    public var archivedAt: Date?

    /// Version for optimistic locking.
    public var version: Int

    // MARK: - Initialization

    public init(
        id: WorkItemId = WorkItemId(),
        keyPrefix: String,
        nextTaskNumber: Int = 1,
        name: String,
        description: String? = nil,
        itemType: WorkItemType = .project,
        status: ProjectStatus = .active,
        category: String? = nil,
        leadId: String,
        memberIds: [String] = [],
        parentId: WorkItemId? = nil,
        startDate: Date? = nil,
        targetDate: Date? = nil,
        completedAt: Date? = nil,
        defaultWorkflowId: String = "simple",
        enabledItemTypes: [WorkItemType] = [.task, .bug, .feature, .subtask],
        settings: ProjectSettings = ProjectSettings(),
        tags: [String] = [],
        customFields: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archivedAt: Date? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.keyPrefix = keyPrefix
        self.nextTaskNumber = nextTaskNumber
        self.name = name
        self.description = description
        self.itemType = itemType
        self.status = status
        self.category = category
        self.leadId = leadId
        self.memberIds = memberIds
        self.parentId = parentId
        self.startDate = startDate
        self.targetDate = targetDate
        self.completedAt = completedAt
        self.defaultWorkflowId = defaultWorkflowId
        self.enabledItemTypes = enabledItemTypes
        self.settings = settings
        self.tags = tags
        self.customFields = customFields
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.version = version
    }

    // MARK: - Key Generation

    /// Generates the next task key and increments counter.
    public mutating func generateNextKey() -> String {
        let key = "\(keyPrefix)-\(nextTaskNumber)"
        nextTaskNumber += 1
        return key
    }

    /// Generates a preview of the next key without incrementing.
    public func previewNextKey() -> String {
        "\(keyPrefix)-\(nextTaskNumber)"
    }
}

// MARK: - Project Status

/// Status of a project.
public enum ProjectStatus: String, Codable, Sendable, CaseIterable {
    case planning
    case active
    case onHold
    case completed
    case archived
    case cancelled

    public var isActive: Bool {
        self == .planning || self == .active
    }

    public var isTerminal: Bool {
        self == .completed || self == .archived || self == .cancelled
    }

    public var label: String {
        switch self {
        case .planning: return "Planning"
        case .active: return "Active"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .archived: return "Archived"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Project Settings

/// Configuration settings for a project.
public struct ProjectSettings: Codable, Sendable, Equatable {
    /// Whether to auto-assign tasks to the creator.
    public var autoAssignToCreator: Bool

    /// Whether due dates are required for tasks.
    public var requireDueDate: Bool

    /// Whether estimates are required.
    public var requireEstimate: Bool

    /// Default estimate unit (hours, points, days).
    public var estimateUnit: EstimateUnit

    /// Whether to show completed tasks in board view.
    public var showCompletedInBoard: Bool

    /// Maximum number of items in progress per user.
    public var wipLimit: Int?

    /// Whether this project uses sprints.
    public var sprintsEnabled: Bool

    /// Sprint duration in weeks.
    public var sprintDurationWeeks: Int

    public init(
        autoAssignToCreator: Bool = false,
        requireDueDate: Bool = false,
        requireEstimate: Bool = false,
        estimateUnit: EstimateUnit = .hours,
        showCompletedInBoard: Bool = false,
        wipLimit: Int? = nil,
        sprintsEnabled: Bool = false,
        sprintDurationWeeks: Int = 2
    ) {
        self.autoAssignToCreator = autoAssignToCreator
        self.requireDueDate = requireDueDate
        self.requireEstimate = requireEstimate
        self.estimateUnit = estimateUnit
        self.showCompletedInBoard = showCompletedInBoard
        self.wipLimit = wipLimit
        self.sprintsEnabled = sprintsEnabled
        self.sprintDurationWeeks = sprintDurationWeeks
    }
}

/// Units for work estimation.
public enum EstimateUnit: String, Codable, Sendable, CaseIterable {
    case hours
    case points
    case days

    public var label: String {
        switch self {
        case .hours: return "Hours"
        case .points: return "Story Points"
        case .days: return "Days"
        }
    }

    public var abbreviation: String {
        switch self {
        case .hours: return "h"
        case .points: return "pts"
        case .days: return "d"
        }
    }
}

// MARK: - Project Summary

/// Lightweight project summary for portfolio views.
public struct ProjectSummary: Sendable, Identifiable {
    public let id: WorkItemId
    public let keyPrefix: String
    public let name: String
    public let status: ProjectStatus
    public let leadId: String
    public let targetDate: Date?
    public let taskCount: Int
    public let completedTaskCount: Int
    public let tags: [String]

    public var progressPercent: Double {
        guard taskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(taskCount) * 100
    }

    public init(
        from project: ProjectComponent,
        taskCount: Int = 0,
        completedTaskCount: Int = 0
    ) {
        self.id = project.id
        self.keyPrefix = project.keyPrefix
        self.name = project.name
        self.status = project.status
        self.leadId = project.leadId
        self.targetDate = project.targetDate
        self.taskCount = taskCount
        self.completedTaskCount = completedTaskCount
        self.tags = project.tags
    }
}
