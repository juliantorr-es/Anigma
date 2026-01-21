//
//  ActivityComponent.swift
//  ConexusModule
//
//  Component representing an activity (call, email, meeting, note) in the CRM.
//

import Foundation
import AnigmaCore

/// Component representing an activity attached to a CRM record.
public struct ActivityComponent: Component, Sendable {
    public let activityId: ActivityId
    public var activityType: ActivityType

    // Basic information
    public var subject: String
    public var body: String?
    public var direction: ActivityDirection?  // Inbound/outbound for calls/emails

    // Timing
    public var occurredAt: Date
    public var duration: TimeInterval?        // For calls/meetings
    public var createdAt: Date

    // Relationships - can be attached to multiple record types
    public var contactIds: [ContactId]
    public var organizationId: OrganizationId?
    public var dealId: DealId?
    public var caseId: CaseId?

    // Creator/owner
    public var createdBy: String
    public var assignedTo: String?

    // For tasks
    public var isCompleted: Bool
    public var completedAt: Date?
    public var dueDate: Date?
    public var priority: CasePriority?

    // For meetings
    public var location: String?
    public var attendees: [String]
    public var meetingUrl: URL?

    // Attachments
    public var attachmentIds: [String]

    // Classification
    public var tags: Set<String>
    public var customFields: [String: String]

    public init(
        activityId: ActivityId = ActivityId(),
        activityType: ActivityType,
        subject: String,
        body: String? = nil,
        direction: ActivityDirection? = nil,
        occurredAt: Date = Date(),
        duration: TimeInterval? = nil,
        contactIds: [ContactId] = [],
        organizationId: OrganizationId? = nil,
        dealId: DealId? = nil,
        caseId: CaseId? = nil,
        createdBy: String,
        assignedTo: String? = nil,
        dueDate: Date? = nil,
        priority: CasePriority? = nil,
        location: String? = nil,
        attendees: [String] = [],
        meetingUrl: URL? = nil,
        attachmentIds: [String] = [],
        tags: Set<String> = [],
        customFields: [String: String] = [:]
    ) {
        self.activityId = activityId
        self.activityType = activityType
        self.subject = subject
        self.body = body
        self.direction = direction
        self.occurredAt = occurredAt
        self.duration = duration
        self.contactIds = contactIds
        self.organizationId = organizationId
        self.dealId = dealId
        self.caseId = caseId
        self.createdBy = createdBy
        self.assignedTo = assignedTo
        self.isCompleted = false
        self.dueDate = dueDate
        self.priority = priority
        self.location = location
        self.attendees = attendees
        self.meetingUrl = meetingUrl
        self.attachmentIds = attachmentIds
        self.tags = tags
        self.customFields = customFields
        self.createdAt = Date()
    }

    /// Marks a task activity as completed.
    public mutating func complete() {
        isCompleted = true
        completedAt = Date()
    }

    /// Duration formatted as string (e.g., "1h 30m").
    public var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Activity Direction

public enum ActivityDirection: String, Codable, Sendable, CaseIterable {
    case inbound    // Customer contacted us
    case outbound   // We contacted customer
}

// MARK: - Activity Builders

extension ActivityComponent {
    /// Creates a call activity.
    public static func call(
        subject: String,
        direction: ActivityDirection,
        duration: TimeInterval? = nil,
        notes: String? = nil,
        contactIds: [ContactId] = [],
        createdBy: String
    ) -> ActivityComponent {
        ActivityComponent(
            activityType: .call,
            subject: subject,
            body: notes,
            direction: direction,
            duration: duration,
            contactIds: contactIds,
            createdBy: createdBy
        )
    }

    /// Creates an email activity.
    public static func email(
        subject: String,
        body: String?,
        direction: ActivityDirection,
        contactIds: [ContactId] = [],
        createdBy: String
    ) -> ActivityComponent {
        ActivityComponent(
            activityType: .email,
            subject: subject,
            body: body,
            direction: direction,
            contactIds: contactIds,
struct MeetingConfiguration: Sendable {
    let subject: String
    let notes: String
    let duration: TimeInterval
    let location: String?
    let attendees: [String]
    let contactIds: [ContactId]
    let createdBy: String
    
    init(
        subject: String,
        notes: String,
        duration: TimeInterval,
        location: String? = nil,
        attendees: [String],
        contactIds: [ContactId],
        createdBy: String
    ) {
        self.subject = subject
        self.notes = notes
        self.duration = duration
        self.location = location
        self.attendees = attendees
        self.contactIds = contactIds
        self.createdBy = createdBy
    }
}
        notes: String,
        duration: TimeInterval,
        location: String? = nil,
        attendees: [String] = [],
        contactIds: [ContactId] = [],
        createdBy: String
    ) {
        self.subject = subject
        self.notes = notes
        self.duration = duration
        self.location = location
        self.attendees = attendees
        self.contactIds = contactIds
        self.createdBy = createdBy
    }
}

// Updated meeting function
func meeting(config: MeetingConfiguration) -> ActivityComponent {
    ActivityComponent(
        activityType: .meeting,
        subject: config.subject,
        body: config.notes,
        duration: config.duration,
        contactIds: config.contactIds,
        createdBy: config.createdBy
        // Note: location and attendees parameters need to be handled in ActivityComponent
    )
}
            location: location,
            attendees: attendees
        )
/// Configuration for creating a task activity.
public struct TaskConfiguration: Sendable {
    public let subject: String
    public let description: String
    public let dueDate: Date
    public let priority: TaskPriority
    public let assignedTo: String
    public let contactIds: [ContactId]
    public let createdBy: String
    
    public init(
        subject: String,
        description: String,
        dueDate: Date,
        priority: TaskPriority,
        assignedTo: String,
        contactIds: [ContactId],
        createdBy: String
    ) {
        self.subject = subject
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.assignedTo = assignedTo
        self.contactIds = contactIds
        self.createdBy = createdBy
    }
}

/// Creates a task activity.
public static func task(config: TaskConfiguration) -> ActivityComponent {
    // Implementation using config properties
    // Note: Original implementation should be migrated to use the config object
}
        ActivityComponent(
            activityType: .note,
            subject: "Note",
            body: content,
            contactIds: contactIds,
            organizationId: organizationId,
            dealId: dealId,
            caseId: caseId,

        contactIds: [ContactId] = [],
        createdBy: String
    ) -> ActivityComponent {
        ActivityComponent(
            activityType: .task,
            subject: subject,
            body: description,
            contactIds: contactIds,
            createdBy: createdBy,
struct TaskConfiguration: Sendable {
    let subject: String
    let description: String?
    let dueDate: Date?
    let priority: TaskPriority
    let assignedTo: User?
    let contactIds: [UUID]
    let createdBy: User
    
    init(
        subject: String,
        description: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        assignedTo: User? = nil,
        contactIds: [UUID] = [],
        createdBy: User
    ) {
        self.subject = subject
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.assignedTo = assignedTo
        self.contactIds = contactIds
        self.createdBy = createdBy
    }
}

// Updated function signature:
// func task(config: TaskConfiguration) {
//     // Implementation using config properties
// }
