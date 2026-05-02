//
//  ViewService.swift
//  PragmaModule
//
//  View generation for work items: lists, boards, timelines.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

/// Service for generating views of work items.
public actor ViewService {
    // MARK: - Dependencies

    private let workService: WorkService

    // MARK: - State

    private var savedViews: [String: SavedView] = [:]

    // MARK: - Initialization

    public init(workService: WorkService) {
        self.workService = workService
    }

    // MARK: - List View

    /// Generates a list view of tasks with filtering and sorting.
    public func listView(
        projectId: EntityId? = nil,
        filter: TaskFilter = TaskFilter(),
        sort: TaskSort = .createdDesc,
        limit: Int? = nil
    ) async -> ListView {
        var tasks: [TaskComponent]

        if let projectId = projectId {
            tasks = await workService.getProjectTasks(projectId: projectId)
        } else {
            // Get all tasks (would need a getAllTasks method in production)
            tasks = []
        }

        // Apply filters
        tasks = tasks.filter { filter.matches($0) }

        // Apply sort
        tasks = sortTasks(tasks, by: sort)

        // Apply limit
        if let limit = limit {
            tasks = Array(tasks.prefix(limit))
        }

        return ListView(
            tasks: tasks.map { TaskSummary(from: $0) },
            filter: filter,
            sort: sort,
            totalCount: tasks.count
        )
    }

    /// Generates a list view for a user's assigned tasks.
    public func myTasksView(userId: String, sort: TaskSort = .priorityDesc) async -> ListView {
        // TRACKED STUB: Full task filtering not implemented - workService query missing
        // Currently returns empty array; production requires workService.getTasksAssignedTo(userId)
        let tasks: [TaskComponent] = [] 
        let sorted = sortTasks(tasks, by: sort)

        return ListView(
            tasks: sorted.map { TaskSummary(from: $0) },
            filter: TaskFilter(assigneeId: userId),
            sort: sort,
            totalCount: tasks.count
        )
    }

    // MARK: - Board View (Kanban)

    /// Generates a Kanban board view grouped by status.
    public func boardView(
        projectId: EntityId,
        filter: TaskFilter = TaskFilter(),
        includeCompleted: Bool = false
    ) async -> BoardView {
        var tasks = await workService.getProjectTasks(projectId: projectId)

        // Apply filters
        tasks = tasks.filter { filter.matches($0) }

        // Filter completed if needed
        if !includeCompleted {
            // Pre-fetch workflow to avoid async in filter
            let workflowId = tasks.first?.workflowId ?? "simple"
            let workflow = await workService.getWorkflow(id: workflowId) ?? .simple
            tasks = tasks.filter { task in
                let status = workflow.statuses.first { $0.id == task.statusId }
                return status?.category != .done && status?.category != .cancelled
            }
        }

        // Get workflow for columns
        let workflowId = tasks.first?.workflowId ?? "simple"
        let workflow = await workService.getWorkflow(id: workflowId) ?? .simple

        // Group by status
        var columns: [BoardColumn] = []
        for status in workflow.statuses.sorted(by: { $0.order < $1.order }) {
            // Skip terminal statuses if not including completed
            if !includeCompleted && status.category.isTerminal {
                continue
            }

            let columnTasks = tasks
                .filter { $0.statusId == status.id }
                .sorted { $0.priority > $1.priority }
                .map { TaskSummary(from: $0) }

            columns.append(BoardColumn(
                status: status,
                tasks: columnTasks
            ))
        }

        return BoardView(
            columns: columns,
            filter: filter,
            totalCount: tasks.count
        )
    }

    // MARK: - Timeline View

    /// Generates a timeline/calendar view of tasks.
    public func timelineView(
        projectId: EntityId,
        startDate: Date,
        endDate: Date,
        filter: TaskFilter = TaskFilter()
    ) async -> TimelineView {
        var tasks = await workService.getProjectTasks(projectId: projectId)

        // Apply filters
        tasks = tasks.filter { filter.matches($0) }

        // Filter to tasks with dates in range
        tasks = tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due >= startDate && due <= endDate
        }

        // Group by date
        let calendar = Calendar.current
        var dateGroups: [Date: [TaskComponent]] = [:]

        for task in tasks {
            guard let due = task.dueDate else { continue }
            let dayStart = calendar.startOfDay(for: due)
            dateGroups[dayStart, default: []].append(task)
        }

        // Convert to timeline items
        let items = dateGroups.map { date, tasks in
            TimelineItem(
                date: date,
                tasks: tasks.map { TaskSummary(from: $0) }
            )
        }.sorted { $0.date < $1.date }

        // Calculate overdue
        let now = Date()
        let overdue = tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due < now && task.completedAt == nil
        }.map { TaskSummary(from: $0) }

        return TimelineView(
            startDate: startDate,
            endDate: endDate,
            items: items,
            overdueItems: overdue,
            filter: filter
        )
    }

    // MARK: - Dashboard View

    /// Generates a dashboard summary for a project.
    public func dashboardView(projectId: EntityId) async -> DashboardView {
        let tasks = await workService.getProjectTasks(projectId: projectId)
        let project = await workService.getProject(entityId: projectId)

        // Calculate metrics
        let total = tasks.count
        let completed = tasks.filter { $0.completedAt != nil }.count
        let inProgress = tasks.filter { task in
            task.completedAt == nil && task.statusId != "todo" && task.statusId != "backlog"
        }.count
        let overdue = tasks.filter { $0.isOverdue }.count

        // Group by priority
        let byPriority = Dictionary(grouping: tasks) { $0.priority }
            .mapValues { $0.count }

        // Group by status
        let byStatus = Dictionary(grouping: tasks) { $0.statusId }
            .mapValues { $0.count }

        // Recent activity (last 7 days)
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
            fatalError("Failed to unwrap weekAgo")
        }
        let recentlyUpdated = tasks
            .filter { $0.updatedAt >= weekAgo }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(10)
            .map { TaskSummary(from: $0) }

        // Due soon (next 7 days)
        guard let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) else {
            fatalError("Failed to unwrap nextWeek")
        }
        let dueSoon = tasks
            .filter { task in
                guard let due = task.dueDate, task.completedAt == nil else { return false }
                return due >= Date() && due <= nextWeek
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .prefix(10)
            .map { TaskSummary(from: $0) }

        return DashboardView(
            projectName: project?.name ?? "Unknown",
            totalTasks: total,
            completedTasks: completed,
            inProgressTasks: inProgress,
            overdueTasks: overdue,
            tasksByPriority: byPriority,
            tasksByStatus: byStatus,
            recentlyUpdated: Array(recentlyUpdated),
            dueSoon: Array(dueSoon),
            completionPercent: total > 0 ? Double(completed) / Double(total) * 100 : 0
        )
    }

    // MARK: - Saved Views

    /// Saves a view configuration.
    public func saveView(_ view: SavedView) {
        savedViews[view.id] = view
    }

    /// Gets a saved view.
    public func getSavedView(id: String) -> SavedView? {
        savedViews[id]
    }

    /// Lists saved views for a user.
    public func listSavedViews(userId: String) -> [SavedView] {
        savedViews.values.filter { $0.ownerId == userId || $0.isShared }
    }

    /// Deletes a saved view.
    public func deleteSavedView(id: String) {
        savedViews.removeValue(forKey: id)
    }

    // MARK: - Sorting

    private func sortTasks(_ tasks: [TaskComponent], by sort: TaskSort) -> [TaskComponent] {
        switch sort {
        case .createdAsc:
            return tasks.sorted { $0.createdAt < $1.createdAt }
        case .createdDesc:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case .updatedAsc:
            return tasks.sorted { $0.updatedAt < $1.updatedAt }
        case .updatedDesc:
            return tasks.sorted { $0.updatedAt > $1.updatedAt }
        case .priorityAsc:
            return tasks.sorted { $0.priority < $1.priority }
        case .priorityDesc:
            return tasks.sorted { $0.priority > $1.priority }
        case .dueDateAsc:
            return tasks.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .dueDateDesc:
            return tasks.sorted { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) }
        case .keyAsc:
            return tasks.sorted { $0.key < $1.key }
        case .keyDesc:
            return tasks.sorted { $0.key > $1.key }
        }
    }
}

// MARK: - View Types

/// List view of tasks.
public struct ListView: Sendable {
    public let tasks: [TaskSummary]
    public let filter: TaskFilter
    public let sort: TaskSort
    public let totalCount: Int

    public var isEmpty: Bool { tasks.isEmpty }
}

/// Kanban board view.
public struct BoardView: Sendable {
    public let columns: [BoardColumn]
    public let filter: TaskFilter
    public let totalCount: Int

    public var isEmpty: Bool { totalCount == 0 }
}

/// A column in the board view.
public struct BoardColumn: Sendable {
    public let status: WorkflowStatus
    public let tasks: [TaskSummary]

    public var count: Int { tasks.count }
    public var isEmpty: Bool { tasks.isEmpty }
}

/// Timeline/calendar view.
public struct TimelineView: Sendable {
    public let startDate: Date
    public let endDate: Date
    public let items: [TimelineItem]
    public let overdueItems: [TaskSummary]
    public let filter: TaskFilter

    public var totalDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}

/// A day in the timeline.
public struct TimelineItem: Sendable {
    public let date: Date
    public let tasks: [TaskSummary]

    public var count: Int { tasks.count }
}

/// Dashboard summary view.
public struct DashboardView: Sendable {
    public let projectName: String
    public let totalTasks: Int
    public let completedTasks: Int
    public let inProgressTasks: Int
    public let overdueTasks: Int
    public let tasksByPriority: [WorkPriority: Int]
    public let tasksByStatus: [String: Int]
    public let recentlyUpdated: [TaskSummary]
    public let dueSoon: [TaskSummary]
    public let completionPercent: Double
}

// MARK: - Filter & Sort

/// Filter criteria for tasks.
public struct TaskFilter: Sendable, Codable {
    public var assigneeId: String?
    public var reporterId: String?
    public var statusIds: [String]?
    public var priorities: [WorkPriority]?
    public var itemTypes: [WorkItemType]?
    public var tags: [String]?
    public var dueBefore: Date?
    public var dueAfter: Date?
    public var createdBefore: Date?
    public var createdAfter: Date?
    public var searchText: String?
    public var excludeCompleted: Bool

    public init(
        assigneeId: String? = nil,
        reporterId: String? = nil,
        statusIds: [String]? = nil,
        priorities: [WorkPriority]? = nil,
        itemTypes: [WorkItemType]? = nil,
        tags: [String]? = nil,
        dueBefore: Date? = nil,
        dueAfter: Date? = nil,
        createdBefore: Date? = nil,
        createdAfter: Date? = nil,
        searchText: String? = nil,
        excludeCompleted: Bool = false
    ) {
        self.assigneeId = assigneeId
        self.reporterId = reporterId
        self.statusIds = statusIds
        self.priorities = priorities
        self.itemTypes = itemTypes
        self.tags = tags
        self.dueBefore = dueBefore
        self.dueAfter = dueAfter
        self.createdBefore = createdBefore
        self.createdAfter = createdAfter
        self.searchText = searchText
        self.excludeCompleted = excludeCompleted
    }

    /// Checks if a task matches this filter.
    public func matches(_ task: TaskComponent) -> Bool {
        if let assignee = assigneeId, task.assigneeId != assignee {
            return false
        }

        if let reporter = reporterId, task.reporterId != reporter {
            return false
        }

        if let statuses = statusIds, !statuses.contains(task.statusId) {
            return false
        }

        if let priorities = priorities, !priorities.contains(task.priority) {
            return false
        }

        if let types = itemTypes, !types.contains(task.itemType) {
            return false
        }

        if let tags = tags, !tags.allSatisfy({ task.tags.contains($0) }) {
            return false
        }

        if let dueBefore = dueBefore, let due = task.dueDate, due > dueBefore {
            return false
        }

        if let dueAfter = dueAfter, let due = task.dueDate, due < dueAfter {
            return false
        }

        if let createdBefore = createdBefore, task.createdAt > createdBefore {
            return false
        }

        if let createdAfter = createdAfter, task.createdAt < createdAfter {
            return false
        }

        if let search = searchText?.lowercased(), !search.isEmpty {
            let matchesTitle = task.title.lowercased().contains(search)
            let matchesDesc = task.description?.lowercased().contains(search) ?? false
            let matchesKey = task.key.lowercased().contains(search)
            if !matchesTitle && !matchesDesc && !matchesKey {
                return false
            }
        }

        if excludeCompleted && task.completedAt != nil {
            return false
        }

        return true
    }
}

/// Sort options for tasks.
public enum TaskSort: String, Sendable, Codable, CaseIterable {
    case createdAsc
    case createdDesc
    case updatedAsc
    case updatedDesc
    case priorityAsc
    case priorityDesc
    case dueDateAsc
    case dueDateDesc
    case keyAsc
    case keyDesc

    public var label: String {
        switch self {
        case .createdAsc: return "Created (oldest first)"
        case .createdDesc: return "Created (newest first)"
        case .updatedAsc: return "Updated (oldest first)"
        case .updatedDesc: return "Updated (newest first)"
        case .priorityAsc: return "Priority (low to high)"
        case .priorityDesc: return "Priority (high to low)"
        case .dueDateAsc: return "Due date (earliest first)"
        case .dueDateDesc: return "Due date (latest first)"
        case .keyAsc: return "Key (A-Z)"
        case .keyDesc: return "Key (Z-A)"
        }
    }
}

// MARK: - Saved View

/// A saved view configuration.
public struct SavedView: Sendable, Codable, Identifiable {
    public let id: String
    public var name: String
    public var description: String?
    public let ownerId: String
    public var isShared: Bool
    public var viewType: SavedViewType
    public var filter: TaskFilter
    public var sort: TaskSort
    public var projectId: WorkItemId?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        ownerId: String,
        isShared: Bool = false,
        viewType: SavedViewType = .list,
        filter: TaskFilter = TaskFilter(),
        sort: TaskSort = .priorityDesc,
        projectId: WorkItemId? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ownerId = ownerId
        self.isShared = isShared
        self.viewType = viewType
        self.filter = filter
        self.sort = sort
        self.projectId = projectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum SavedViewType: String, Sendable, Codable, CaseIterable {
    case list
    case board
    case timeline
    case calendar
}
