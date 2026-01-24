//
//  TaskComponent.swift
//  PragmaModule
//
//  Core task/issue component for work items.
//  This is the fundamental unit of trackable work in Pragma.
//

import Foundation
import AnigmaCore

/// Component representing a task or issue.
/// Attached to entities in the ECS World for work tracking.
public struct TaskComponent: Component, Codable, Identifiable, Sendable {
    // MARK: - Identity

    /// Unique work item ID (separate from EntityId for cross-referencing).
    public let id: WorkItemId

    /// Human-readable key (e.g., "PROJ-123").
    public var key: String

    /// Type of work item.
    public var itemType: WorkItemType

    // MARK: - Core Fields

    /// Task title/summary.
    public var title: String

    /// Detailed description (Markdown supported).
    public var description: String?

    /// Current status ID (references WorkflowStatus).
    public var statusId: String

    /// Priority level.
    public var priority: WorkPriority

    // MARK: - Assignment

    /// User ID of the assignee.
    public var assigneeId: String?

    /// User ID of the reporter/creator.
    public var reporterId: String

    /// User IDs of watchers.
    public var watcherIds: [String]

    // MARK: - Hierarchy

    /// Parent work item ID (for subtasks, tasks in epics, etc.).
    public var parentId: WorkItemId?

    /// Project this task belongs to.
    public var projectId: WorkItemId?

    // MARK: - Scheduling

    /// Due date for completion.
    public var dueDate: Date?

    /// Start date for planned work.
    public var startDate: Date?

    /// Estimated effort (in hours, points, or custom unit).
    public var estimate: Double?

    /// Time logged (in hours).
    public var timeLogged: Double

    // MARK: - Metadata

    /// Tags/labels for categorization.
    public var tags: [String]

    /// Custom fields (key-value).
    public var customFields: [String: String]

    /// Workflow definition ID this task uses.
    public var workflowId: String

    // MARK: - Timestamps

    /// When the task was created.
    public let createdAt: Date

    /// When the task was last updated.
    public var updatedAt: Date

    /// When the task was completed (if done).
    public var completedAt: Date?

    // MARK: - Version

    /// Optimistic locking version.
    public var version: Int

    // MARK: - Initialization

    public init(
        id: WorkItemId = WorkItemId(),
        key: String,
        itemType: WorkItemType = .task,
        title: String,
        description: String? = nil,
        statusId: String = "todo",
        priority: WorkPriority = .medium,
        assigneeId: String? = nil,
        reporterId: String,
        watcherIds: [String] = [],
        parentId: WorkItemId? = nil,
        projectId: WorkItemId? = nil,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        estimate: Double? = nil,
        timeLogged: Double = 0,
        tags: [String] = [],
        customFields: [String: String] = [:],
        workflowId: String = "simple",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.key = key
        self.itemType = itemType
        self.title = title
        self.description = description
        self.statusId = statusId
        self.priority = priority
        self.assigneeId = assigneeId
        self.reporterId = reporterId
        self.watcherIds = watcherIds
        self.parentId = parentId
        self.projectId = projectId
        self.dueDate = dueDate
        self.startDate = startDate
        self.estimate = estimate
        self.timeLogged = timeLogged
        self.tags = tags
        self.customFields = customFields
        self.workflowId = workflowId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.version = version
    }

    // MARK: - Computed Properties

    /// Whether the task is overdue.
    public var isOverdue: Bool {
        guard let due = dueDate, completedAt == nil else { return false }
        return Date() > due
    }

    /// Remaining estimate after time logged.
    public var remainingEstimate: Double? {
        guard let est = estimate else { return nil }
        return max(0, est - timeLogged)
    }

    /// Age of the task in days.
    public var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
}

// MARK: - Task Mutation Helpers

extension TaskComponent {
    /// Returns a copy with updated status and timestamp.
    public func withStatus(_ newStatusId: String, completedAt: Date? = nil) -> TaskComponent {
        var copy = self
        copy.statusId = newStatusId
        copy.updatedAt = Date()
        copy.version += 1
        if let completed = completedAt {
            copy.completedAt = completed
        }
        return copy
    }

    /// Returns a copy with updated assignee.
    public func withAssignee(_ assigneeId: String?) -> TaskComponent {
        var copy = self
        copy.assigneeId = assigneeId
        copy.updatedAt = Date()
        copy.version += 1
        return copy
    }

    /// Returns a copy with logged time added.
    public func withTimeLogged(_ hours: Double) -> TaskComponent {
        var copy = self
        copy.timeLogged += hours
        copy.updatedAt = Date()
        copy.version += 1
        return copy
    }

    /// Returns a copy with updated priority.
    public func withPriority(_ priority: WorkPriority) -> TaskComponent {
        var copy = self
        copy.priority = priority
        copy.updatedAt = Date()
        copy.version += 1
        return copy
    }

    /// Returns a copy with a tag added.
    public func withTag(_ tag: String) -> TaskComponent {
        var copy = self
        if !copy.tags.contains(tag) {
            copy.tags.append(tag)
        }
        copy.updatedAt = Date()
        copy.version += 1
        return copy
    }

    /// Returns a copy with a watcher added.
    public func withWatcher(_ userId: String) -> TaskComponent {
        var copy = self
        if !copy.watcherIds.contains(userId) {
            copy.watcherIds.append(userId)
        }
        copy.updatedAt = Date()
        copy.version += 1
        return copy
    }
}

// MARK: - Task Summary

/// Lightweight summary of a task for list views.
public struct TaskSummary: Sendable, Identifiable {
    public let id: WorkItemId
    public let key: String
    public let title: String
    public let statusId: String
    public let priority: WorkPriority
    public let assigneeId: String?
    public let dueDate: Date?
    public let isOverdue: Bool
    public let tags: [String]

    public init(from task: TaskComponent) {
        self.id = task.id
        self.key = task.key
        self.title = task.title
        self.statusId = task.statusId
        self.priority = task.priority
        self.assigneeId = task.assigneeId
        self.dueDate = task.dueDate
        self.isOverdue = task.isOverdue
        self.tags = task.tags
    }
}
