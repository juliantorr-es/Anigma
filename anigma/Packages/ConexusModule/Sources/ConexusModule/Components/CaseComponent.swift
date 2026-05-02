import AnigmaPrimitives

import AnigmaPrimitives

//
//  CaseComponent.swift
//  ConexusModule
//
//  Component representing a case/request (support ticket, legal matter, etc.).
//

import Foundation
import AnigmaCore

/// Component representing a case or service request.
public struct CaseComponent: Component, Sendable {
    public let caseId: CaseId
    public var caseType: CaseType
    public var status: CaseStatus
    public var priority: CasePriority

    // Basic information
    public var subject: String
    public var description: String?
    public var caseNumber: String       // Human-readable case number

    // Relationships
    public var contactId: ContactId?
    public var organizationId: OrganizationId?
    public var relatedDealId: DealId?

    // Assignment
    public var ownerId: String?
    public var queueId: String?
    public var escalatedTo: String?

    // Timing
    public var createdAt: Date
    public var updatedAt: Date
    public var dueDate: Date?
    public var resolvedAt: Date?
    public var closedAt: Date?
    public var firstResponseAt: Date?

    // SLA tracking
    public var slaName: String?
    public var slaDeadline: Date?
    public var slaBreached: Bool

    // Classification
    public var category: String?
    public var subcategory: String?
    public var tags: Set<String>
    public var customFields: [String: String]

    // Resolution
    public var resolution: String?
    public var resolutionType: ResolutionType?
    public var satisfactionRating: Int?  // 1-5 scale
    public var satisfactionComment: String?

    // Alt-media specific (for DSPS cases)
    public var requestedFormats: [AccessibleFormat]
    public var sourceDocumentIds: [String]
    public var deliveredDocumentIds: [String]

    public init(
        caseId: CaseId = CaseId(),
        caseType: CaseType = .supportTicket,
        status: CaseStatus = .new,
        priority: CasePriority = .medium,
        subject: String,
        description: String? = nil,
        caseNumber: String? = nil,
        contactId: ContactId? = nil,
        organizationId: OrganizationId? = nil,
        relatedDealId: DealId? = nil,
        ownerId: String? = nil,
        queueId: String? = nil,
        dueDate: Date? = nil,
        slaName: String? = nil,
        slaDeadline: Date? = nil,
        category: String? = nil,
        subcategory: String? = nil,
        tags: Set<String> = [],
        customFields: [String: String] = [:],
        requestedFormats: [AccessibleFormat] = [],
        sourceDocumentIds: [String] = []
    ) {
        self.caseId = caseId
        self.caseType = caseType
        self.status = status
        self.priority = priority
        self.subject = subject
        self.description = description
        self.caseNumber = caseNumber ?? Self.generateCaseNumber()
        self.contactId = contactId
        self.organizationId = organizationId
        self.relatedDealId = relatedDealId
        self.ownerId = ownerId
        self.queueId = queueId
        self.dueDate = dueDate
        self.slaName = slaName
        self.slaDeadline = slaDeadline
        self.slaBreached = false
        self.category = category
        self.subcategory = subcategory
        self.tags = tags
        self.customFields = customFields
        self.requestedFormats = requestedFormats
        self.sourceDocumentIds = sourceDocumentIds
        self.deliveredDocumentIds = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Generate a human-readable case number.
    private static func generateCaseNumber() -> String {
        let timestamp = Int(Date().timeIntervalSince1970) % 1000000
        let random = Int.random(in: 100...999)
        return "CASE-\(timestamp)-\(random)"
    }

    /// Whether the case is still open.
    public var isOpen: Bool { status.isOpen }

    /// Time to first response (if responded).
    public var timeToFirstResponse: TimeInterval? {
        guard let firstResponseAt = firstResponseAt else { return nil }
        return firstResponseAt.timeIntervalSince(createdAt)
    }

    /// Time to resolution (if resolved).
    public var timeToResolution: TimeInterval? {
        guard let resolvedAt = resolvedAt else { return nil }
        return resolvedAt.timeIntervalSince(createdAt)
    }

    /// Age of the case in days.
    public var age: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }

    /// Updates status and records timestamps.
    public mutating func updateStatus(_ newStatus: CaseStatus) {
        status = newStatus
        updatedAt = Date()

        switch newStatus {
        case .resolved:
            resolvedAt = Date()
        case .closed:
            closedAt = Date()
            if resolvedAt == nil { resolvedAt = Date() }
        default:
            break
        }
    }

    /// Records first response.
    public mutating func recordFirstResponse() {
        if firstResponseAt == nil {
            firstResponseAt = Date()
        }
    }

    /// Escalates the case.
    public mutating func escalate(to: String) {
        escalatedTo = to
        priority = min(CasePriority.critical, CasePriority(rawValue: priority.rawValue + 1) ?? .critical)
        updatedAt = Date()
    }
}

// MARK: - Resolution Types

public enum ResolutionType: String, Codable, Sendable, CaseIterable {
    case solved             // Issue resolved
    case workaround         // Workaround provided
    case duplicate          // Duplicate of another case
    case cannotReproduce    // Cannot reproduce issue
    case noActionRequired   // No action needed
    case declined           // Request declined
    case escalated          // Escalated to another team
    case selfResolved       // Customer resolved themselves
}
