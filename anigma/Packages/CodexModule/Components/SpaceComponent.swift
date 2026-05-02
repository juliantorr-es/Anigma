import AnigmaPrimitives

import AnigmaPrimitives

//
//  SpaceComponent.swift
//  CodexModule
//
//  Component representing a content space (organizational container).
//

import Foundation
import AnigmaCore

/// Component representing a content space.
public struct SpaceComponent: Component, Sendable, Codable {
    public let spaceId: SpaceId
    public var spaceType: SpaceType

    // Basic information
    public var key: String              // Short unique key (e.g., "DOC", "KB", "PROJ-123")
    public var name: String
    public var description: String?
    public var iconEmoji: String?

    // Visibility and access
    public var visibility: ContentVisibility
    public var ownerId: String
    public var adminIds: [String]

    // Organization
    public var parentSpaceId: SpaceId?
    public var childSpaceIds: [SpaceId]
    public var defaultPageType: PageType
    public var allowedPageTypes: [PageType]

    // Settings
    public var defaultVisibility: ContentVisibility
    public var requireApproval: Bool
    public var approverIds: [String]
    public var allowComments: Bool
    public var allowPublicComments: Bool

    // Classification
    public var tags: Set<String>
    public var customFields: [String: String]

    // Stats
    public var pageCount: Int
    public var memberCount: Int

    // Lifecycle
    public var createdAt: Date
    public var updatedAt: Date
    public var archivedAt: Date?

    public init(
        spaceId: SpaceId = SpaceId(),
        spaceType: SpaceType = .wiki,
        key: String,
        name: String,
        description: String? = nil,
        iconEmoji: String? = nil,
        visibility: ContentVisibility = .internal,
        ownerId: String,
        adminIds: [String] = [],
        parentSpaceId: SpaceId? = nil,
        childSpaceIds: [SpaceId] = [],
        defaultPageType: PageType = .document,
        allowedPageTypes: [PageType] = PageType.allCases,
        defaultVisibility: ContentVisibility = .internal,
        requireApproval: Bool = false,
        approverIds: [String] = [],
        allowComments: Bool = true,
        allowPublicComments: Bool = false,
        tags: Set<String> = [],
        customFields: [String: String] = [:]
    ) {
        self.spaceId = spaceId
        self.spaceType = spaceType
        self.key = key.uppercased()
        self.name = name
        self.description = description
        self.iconEmoji = iconEmoji
        self.visibility = visibility
        self.ownerId = ownerId
        self.adminIds = adminIds
        self.parentSpaceId = parentSpaceId
        self.childSpaceIds = childSpaceIds
        self.defaultPageType = defaultPageType
        self.allowedPageTypes = allowedPageTypes
        self.defaultVisibility = defaultVisibility
        self.requireApproval = requireApproval
        self.approverIds = approverIds
        self.allowComments = allowComments
        self.allowPublicComments = allowPublicComments
        self.tags = tags
        self.customFields = customFields
        self.pageCount = 0
        self.memberCount = 1
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Whether the space is archived.
    public var isArchived: Bool {
        archivedAt != nil
    }

    /// Archives the space.
    public mutating func archive() {
        archivedAt = Date()
        updatedAt = Date()
    }

    /// Unarchives the space.
    public mutating func unarchive() {
        archivedAt = nil
        updatedAt = Date()
    }
}
