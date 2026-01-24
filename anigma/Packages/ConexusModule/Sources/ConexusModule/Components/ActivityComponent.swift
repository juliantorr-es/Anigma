//
//  ActivityComponent.swift
//  ConexusModule
//
//  Component representing an activity (call, email, meeting, note) in the CRM.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

/// Component representing an activity attached to a CRM record.
public struct ActivityComponent: Component, Sendable {
    public let activityId: ActivityId
    public var activityType: ActivityType

    // Basic information
    public var subject: String
    public var body: String?
    public var direction: ActivityDirection?

    // Timing
    public var occurredAt: Date
    public var duration: TimeInterval?
    public var createdAt: Date

    // Relationships
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

    public mutating func complete() {
        isCompleted = true
        completedAt = Date()
    }
}

public enum ActivityDirection: String, Codable, Sendable, CaseIterable {
    case inbound, outbound
}

extension ActivityComponent {
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
            createdBy: createdBy
        )
    }
}
