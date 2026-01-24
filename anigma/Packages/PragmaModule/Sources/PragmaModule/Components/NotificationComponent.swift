//
//  NotificationComponent.swift
//  PragmaModule
//
//  Notifications and inbox for user alerts.
//

import Foundation
import AnigmaCore

/// Component representing a notification for a user.
public struct NotificationComponent: Component, Codable, Identifiable, Sendable {
    /// Unique notification ID.
    public let id: UUID

    /// User who receives this notification.
    public let recipientId: String

    /// Type of notification.
    public let notificationType: NotificationType

    /// Title/headline.
    public let title: String

    /// Notification body.
    public let body: String

    /// Related work item (if any).
    public let workItemId: WorkItemId?

    /// Related project (if any).
    public let projectId: WorkItemId?

    /// User who triggered this notification.
    public let actorId: String?

    /// Priority/urgency.
    public let priority: NotificationPriority

    /// Category for grouping.
    public let category: NotificationCategory

    /// Deep link URL.
    public let actionUrl: String?

    // MARK: - State

    /// Whether the notification has been read.
    public var isRead: Bool

    /// Whether the notification has been dismissed.
    public var isDismissed: Bool

    /// When the notification was read.
    public var readAt: Date?

    // MARK: - Timestamps

    public let createdAt: Date
    public var expiresAt: Date?

    public init(
        id: UUID = UUID(),
        recipientId: String,
        notificationType: NotificationType,
        title: String,
        body: String,
        workItemId: WorkItemId? = nil,
        projectId: WorkItemId? = nil,
        actorId: String? = nil,
        priority: NotificationPriority = .normal,
        category: NotificationCategory = .activity,
        actionUrl: String? = nil,
        isRead: Bool = false,
        isDismissed: Bool = false,
        readAt: Date? = nil,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.recipientId = recipientId
        self.notificationType = notificationType
        self.title = title
        self.body = body
        self.workItemId = workItemId
        self.projectId = projectId
        self.actorId = actorId
        self.priority = priority
        self.category = category
        self.actionUrl = actionUrl
        self.isRead = isRead
        self.isDismissed = isDismissed
        self.readAt = readAt
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    /// Whether this notification is still active (not expired, not dismissed).
    public var isActive: Bool {
        if isDismissed { return false }
        if let expires = expiresAt, Date() > expires { return false }
        return true
    }

    /// Age of the notification.
    public var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }

    /// Human-readable age string.
    public var ageString: String {
        let seconds = Int(age)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Notification Types

public enum NotificationType: String, Codable, Sendable, CaseIterable {
    // Assignment
    case assigned
    case unassigned
    case reassigned

    // Mentions
    case mentioned

    // Updates
    case statusChanged
    case priorityChanged
    case dueDateChanged
    case commentAdded
    case fieldChanged

    // Watching
    case watchedItemUpdated

    // Due dates
    case dueSoon
    case overdue

    // Workflow
    case transitionRequired
    case approvalRequired
    case blocked
    case unblocked

    // System
    case automationTriggered
    case aiSuggestion
    case systemAlert

    public var icon: String {
        switch self {
        case .assigned, .unassigned, .reassigned: return "👤"
        case .mentioned: return "@"
        case .statusChanged: return "🔄"
        case .priorityChanged: return "⚡"
        case .dueDateChanged: return "📅"
        case .commentAdded: return "💬"
        case .fieldChanged: return "✏️"
        case .watchedItemUpdated: return "👁️"
        case .dueSoon: return "⏰"
        case .overdue: return "🔴"
        case .transitionRequired: return "➡️"
        case .approvalRequired: return "✋"
        case .blocked: return "🚫"
        case .unblocked: return "✅"
        case .automationTriggered: return "⚙️"
        case .aiSuggestion: return "🤖"
        case .systemAlert: return "⚠️"
        }
    }
}

// MARK: - Notification Priority

public enum NotificationPriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3

    public static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Notification Category

public enum NotificationCategory: String, Codable, Sendable, CaseIterable {
    /// Activity on items you're involved with.
    case activity

    /// Direct mentions and assignments.
    case direct

    /// Due date reminders.
    case reminders

    /// Workflow and approvals.
    case workflow

    /// System and automation.
    case system

    public var label: String {
        switch self {
        case .activity: return "Activity"
        case .direct: return "Direct"
        case .reminders: return "Reminders"
        case .workflow: return "Workflow"
        case .system: return "System"
        }
    }
}

// MARK: - Notification Preferences

/// User preferences for notifications.
public struct NotificationPreferences: Codable, Sendable, Equatable {
    public var enabledTypes: Set<NotificationType>
    public var mutedProjectIds: Set<String>
    public var mutedWorkItemIds: Set<String>
    public var emailDigestFrequency: DigestFrequency
    public var quietHoursStart: Int?  // Hour of day (0-23)
    public var quietHoursEnd: Int?

    public init(
        enabledTypes: Set<NotificationType> = Set(NotificationType.allCases),
        mutedProjectIds: Set<String> = [],
        mutedWorkItemIds: Set<String> = [],
        emailDigestFrequency: DigestFrequency = .daily,
        quietHoursStart: Int? = nil,
        quietHoursEnd: Int? = nil
    ) {
        self.enabledTypes = enabledTypes
        self.mutedProjectIds = mutedProjectIds
        self.mutedWorkItemIds = mutedWorkItemIds
        self.emailDigestFrequency = emailDigestFrequency
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
    }

    /// Default preferences with all notifications enabled.
    public static let `default` = NotificationPreferences()

    /// Checks if a notification should be delivered based on preferences.
    public func shouldDeliver(_ notification: NotificationComponent) -> Bool {
        // Check if type is enabled
        guard enabledTypes.contains(notification.notificationType) else {
            return false
        }

        // Check muted projects
        if let projectId = notification.projectId,
           mutedProjectIds.contains(projectId.raw.uuidString) {
            return false
        }

        // Check muted work items
        if let workItemId = notification.workItemId,
           mutedWorkItemIds.contains(workItemId.raw.uuidString) {
            return false
        }

        return true
    }
}

/// Email digest frequency.
public enum DigestFrequency: String, Codable, Sendable, CaseIterable {
    case realtime
    case hourly
    case daily
    case weekly
    case never
}

// MARK: - Inbox

/// User's notification inbox.
public struct NotificationInbox: Sendable {
    public let userId: String
    public let notifications: [NotificationComponent]

    public init(userId: String, notifications: [NotificationComponent]) {
        self.userId = userId
        self.notifications = notifications.filter { $0.isActive }
    }

    /// Unread count.
    public var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    /// Notifications grouped by category.
    public var byCategory: [NotificationCategory: [NotificationComponent]] {
        Dictionary(grouping: notifications) { $0.category }
    }

    /// High priority notifications.
    public var highPriority: [NotificationComponent] {
        notifications.filter { $0.priority >= .high }
    }

    /// Today's notifications.
    public var today: [NotificationComponent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return notifications.filter { $0.createdAt >= today }
    }
}

// MARK: - Notification Builders

extension NotificationComponent {
    /// Creates an assignment notification.
    public static func assigned(
        to userId: String,
        workItemId: WorkItemId,
        workItemTitle: String,
        by actorId: String
    ) -> NotificationComponent {
        NotificationComponent(
            recipientId: userId,
            notificationType: .assigned,
            title: "You've been assigned",
            body: "You've been assigned to: \(workItemTitle)",
            workItemId: workItemId,
            actorId: actorId,
            priority: .high,
            category: .direct
        )
    }

    /// Creates a mention notification.
    public static func mentioned(
        userId: String,
        in workItemId: WorkItemId,
        workItemTitle: String,
        by actorId: String
    ) -> NotificationComponent {
        NotificationComponent(
            recipientId: userId,
            notificationType: .mentioned,
            title: "You were mentioned",
            body: "You were mentioned in: \(workItemTitle)",
            workItemId: workItemId,
            actorId: actorId,
            priority: .high,
            category: .direct
        )
    }

    /// Creates a due soon reminder.
    public static func dueSoon(
        userId: String,
        workItemId: WorkItemId,
        workItemTitle: String,
        dueDate: Date
    ) -> NotificationComponent {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let dueString = formatter.localizedString(for: dueDate, relativeTo: Date())

        return NotificationComponent(
            recipientId: userId,
            notificationType: .dueSoon,
            title: "Due soon",
            body: "\(workItemTitle) is due \(dueString)",
            workItemId: workItemId,
            priority: .high,
            category: .reminders
        )
    }

    /// Creates an overdue notification.
    public static func overdue(
        userId: String,
        workItemId: WorkItemId,
        workItemTitle: String
    ) -> NotificationComponent {
        NotificationComponent(
            recipientId: userId,
            notificationType: .overdue,
            title: "Overdue",
            body: "\(workItemTitle) is overdue",
            workItemId: workItemId,
            priority: .urgent,
            category: .reminders
        )
    }
}
