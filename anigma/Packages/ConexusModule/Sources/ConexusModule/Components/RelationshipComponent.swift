import AnigmaPrimitives

import AnigmaPrimitives

//
//  RelationshipComponent.swift
//  ConexusModule
//
//  Component representing a relationship between CRM entities.
//

import Foundation
import AnigmaCore

/// Unique identifier for relationships.
public struct RelationshipId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public var description: String { "Rel(\(raw.uuidString.prefix(8)))" }
}

/// Component representing a relationship between contacts and/or organizations.
public struct RelationshipComponent: Component, Sendable {
    public let relationshipId: RelationshipId
    public var relationshipType: RelationshipType

    // The two ends of the relationship
    // Each end can be either a contact or an organization
    public var fromType: RelationshipEndType
    public var fromId: UUID             // ContactId.raw or OrganizationId.raw
    public var toType: RelationshipEndType
    public var toId: UUID

    // Metadata
    public var role: String?            // Specific role (e.g., "CEO", "Primary Contact")
    public var isPrimary: Bool          // Is this the primary relationship of its type
    public var startDate: Date?
    public var endDate: Date?
    public var notes: String?

    // Lifecycle
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        relationshipId: RelationshipId = RelationshipId(),
        relationshipType: RelationshipType,
        fromType: RelationshipEndType,
        fromId: UUID,
        toType: RelationshipEndType,
        toId: UUID,
        role: String? = nil,
        isPrimary: Bool = false,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String? = nil
    ) {
        self.relationshipId = relationshipId
        self.relationshipType = relationshipType
        self.fromType = fromType
        self.fromId = fromId
        self.toType = toType
        self.toId = toId
        self.role = role
        self.isPrimary = isPrimary
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Whether the relationship is currently active.
    public var isActive: Bool {
        if let endDate = endDate, endDate < Date() {
            return false
        }
        if let startDate = startDate, startDate > Date() {
            return false
        }
        return true
    }
}

// MARK: - Relationship End Type

public enum RelationshipEndType: String, Codable, Sendable, CaseIterable {
    case contact
    case organization
}

// MARK: - Relationship Builders

extension RelationshipComponent {
    /// Creates an "employed by" relationship (Contact works at Organization).
    public static func employedBy(
        contact: ContactId,
        organization: OrganizationId,
        role: String? = nil,
        isPrimary: Bool = true,
        startDate: Date? = nil
    ) -> RelationshipComponent {
        RelationshipComponent(
            relationshipType: .employedBy,
            fromType: .contact,
            fromId: contact.raw,
            toType: .organization,
            toId: organization.raw,
            role: role,
            isPrimary: isPrimary,
            startDate: startDate
        )
    }

    /// Creates a "manages" relationship (Contact manages Contact).
    public static func manages(
        manager: ContactId,
        report: ContactId
    ) -> RelationshipComponent {
        RelationshipComponent(
            relationshipType: .manages,
            fromType: .contact,
            fromId: manager.raw,
            toType: .contact,
            toId: report.raw
        )
    }

    /// Creates a "member of" relationship (Contact is member of Organization).
    public static func memberOf(
        contact: ContactId,
        organization: OrganizationId,
        role: String? = nil
    ) -> RelationshipComponent {
        RelationshipComponent(
            relationshipType: .memberOf,
            fromType: .contact,
            fromId: contact.raw,
            toType: .organization,
            toId: organization.raw,
            role: role
        )
    }

    /// Creates a "referred by" relationship for tracking referrals.
    public static func referredBy(
        contact: ContactId,
        referrer: ContactId
    ) -> RelationshipComponent {
        RelationshipComponent(
            relationshipType: .referredBy,
            fromType: .contact,
            fromId: contact.raw,
            toType: .contact,
            toId: referrer.raw
        )
    }
}
