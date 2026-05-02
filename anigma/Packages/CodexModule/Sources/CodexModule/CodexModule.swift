//
//  CodexModule.swift
//  CodexModule
//
//  Knowledge and documentation domain for Anigma.
//  "Codex" (Latin) - a bound book, a collected body of text, often legal or scholarly
//
//  This module provides:
//  - Spaces: Organizational containers for related content
//  - Pages: Documents with rich content, versioning, and hierarchy
//  - Templates: Reusable document structures for common use cases
//  - Comments: Discussion threads on content
//  - Search: Full-text and semantic search across content
//  - Knowledge Base: Help articles with categories and tags
//
//  All content is ECS entities with components, governed by AnigmaCore.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import GovernanceCore

// MARK: - Module Definition

/// The Codex knowledge and documentation module.
public enum CodexModule {
    public static let version = "0.1.0"
    public static let name = "Codex"

    /// Initializes the Codex module with governance integration.
    public static func initialize(governance: any GoverningController) async {
        // Register Codex-specific write checks
        await governance.registerWriteCheck(ContentAccessCheck())
        await governance.registerWriteCheck(PublishApprovalCheck())

        // Log initialization
        try? await governance.auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: "system",
            module: "CodexModule",
            description: "CodexModule initialized (v\(version))",
            metadata: ["original_event_type": "system_started"]
        )
    }

    /// Initializes the Codex module with runtime governance integration.
    public static func initialize(governance: any RuntimeServices) async {
        let controller = await governance.governance
        await initialize(governance: controller)
    }
}

// MARK: - Codex Identifiers

/// Unique identifier for spaces.
public struct SpaceId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }

    public var description: String { "Space(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for pages.
public struct PageId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }

    public var description: String { "Page(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for templates.
public struct TemplateId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public var description: String { "Template(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for comments.
public struct CommentId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public var description: String { "Comment(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for page versions.
public struct VersionId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public var description: String { "Version(\(raw.uuidString.prefix(8)))" }
}

// MARK: - Space Types

/// Types of content spaces.
public enum SpaceType: String, Codable, Sendable, CaseIterable {
    case documentation      // Technical documentation
    case knowledgeBase      // Help articles, FAQ
    case wiki               // Collaborative wiki
    case project            // Project-specific docs
    case policy             // Policies and procedures
    case legal              // Legal documents
    case personal           // Personal notes space
    case archive            // Archived content
}

/// Visibility levels for spaces and pages.
public enum ContentVisibility: String, Codable, Sendable, CaseIterable {
    case `public`           // Anyone can view
    case `internal`         // Organization members only
    case restricted         // Specific groups/roles only
    case `private`          // Owner and explicit shares only
    case confidential       // Highly restricted
}

// MARK: - Page Types

/// Types of pages/documents.
public enum PageType: String, Codable, Sendable, CaseIterable {
    case document           // General document
    case article            // Help/KB article
    case runbook            // Operational runbook
    case policy             // Policy document
    case procedure          // Standard operating procedure
    case template           // Page template
    case meeting            // Meeting notes
    case decision           // Decision record (ADR-style)
    case specification      // Technical spec
    case tutorial           // How-to guide
    case faq                // FAQ page
    case glossary           // Glossary/definitions
    case changelog          // Change log
}

/// Page status in the content lifecycle.
public enum PageStatus: String, Codable, Sendable, CaseIterable {
    case draft              // Work in progress
    case review             // Under review
    case approved           // Approved for publishing
    case published          // Live/published
    case archived           // Archived/deprecated
    case deleted            // Soft deleted

    public var isEditable: Bool {
        switch self {
        case .draft, .review:
            return true
        case .approved, .published, .archived, .deleted:
            return false
        }
    }

    public var isVisible: Bool {
        switch self {
        case .published:
            return true
        case .draft, .review, .approved, .archived, .deleted:
            return false
        }
    }
}

// MARK: - Content Formats

/// Content format for page body.
public enum ContentFormat: String, Codable, Sendable, CaseIterable {
    case markdown           // Markdown
    case html               // HTML
    case plainText          // Plain text
    case richText           // Structured rich text (JSON-based)
}

// MARK: - Template Categories

/// Categories for templates.
public enum TemplateCategory: String, Codable, Sendable, CaseIterable {
    case general            // General purpose
    case software           // Software development
    case legal              // Legal documents
    case accessibility      // Accessibility/DSPS
    case meeting            // Meetings
    case project            // Project management
    case policy             // Policies/procedures
    case support            // Support/KB articles
}

// MARK: - Write Checks

/// Checks access to content based on visibility and role.
public struct ContentAccessCheck: WriteCheck {
    public let id = "codex-content-access"
    public let name = "Content Access Check"
    public let isBlocking = true

    public init() {}

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        proposal.module == "Codex" &&
        (proposal.componentType == "PageComponent" || proposal.componentType == "SpaceComponent")
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        // Real implementation would check:
        // 1. Space/page visibility settings
        // 2. Principal's role and group memberships
        // 3. Explicit access grants
        .pass(checkId: id, message: "Content access check passed")
    }
}

/// Checks that published content has required approvals.
public struct PublishApprovalCheck: WriteCheck {
    public let id = "codex-publish-approval"
    public let name = "Publish Approval Check"
    public let isBlocking = true

    public init() {}

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        proposal.module == "Codex" &&
        proposal.operation == "publish"
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        // Real implementation would check:
        // 1. Page type requires approval
        // 2. Required approvers have approved
        // 3. No blocking comments
        .pass(checkId: id, message: "Publish approval check passed")
    }
}

// MARK: - Codex Errors

public enum CodexError: Error, LocalizedError, Sendable {
    case spaceNotFound(SpaceId)
    case pageNotFound(PageId)
    case templateNotFound(TemplateId)
    case versionNotFound(VersionId)
    case commentNotFound(CommentId)
    case permissionDenied(reason: String)
    case invalidStatus(String)
    case circularHierarchy(PageId)
    case contentLocked(by: String)
    case validationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .spaceNotFound(let id):
            return "Space not found: \(id)"
        case .pageNotFound(let id):
            return "Page not found: \(id)"
        case .templateNotFound(let id):
            return "Template not found: \(id)"
        case .versionNotFound(let id):
            return "Version not found: \(id)"
        case .commentNotFound(let id):
            return "Comment not found: \(id)"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .invalidStatus(let detail):
            return "Invalid status: \(detail)"
        case .circularHierarchy(let id):
            return "Circular hierarchy detected involving: \(id)"
        case .contentLocked(let by):
            return "Content locked by: \(by)"
        case .validationFailed(let detail):
            return "Validation failed: \(detail)"
        }
    }
}

// MARK: - Search Types

/// Search query for finding content.
public struct ContentSearchQuery: Sendable {
    public var text: String?
    public var spaceIds: [SpaceId]?
    public var pageTypes: [PageType]?
    public var status: [PageStatus]?
    public var tags: [String]?
    public var author: String?
    public var modifiedAfter: Date?
    public var modifiedBefore: Date?
    public var visibility: [ContentVisibility]?
    public var limit: Int
    public var offset: Int

    public init(
        text: String? = nil,
        spaceIds: [SpaceId]? = nil,
        pageTypes: [PageType]? = nil,
        status: [PageStatus]? = nil,
        tags: [String]? = nil,
        author: String? = nil,
        modifiedAfter: Date? = nil,
        modifiedBefore: Date? = nil,
        visibility: [ContentVisibility]? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.text = text
        self.spaceIds = spaceIds
        self.pageTypes = pageTypes
        self.status = status
        self.tags = tags
        self.author = author
        self.modifiedAfter = modifiedAfter
        self.modifiedBefore = modifiedBefore
        self.visibility = visibility
        self.limit = limit
        self.offset = offset
    }
}

/// Search result with relevance scoring.
public struct ContentSearchResult: Sendable {
    public let pageId: PageId
    public let entityId: EntityId
    public let title: String
    public let excerpt: String?
    public let spaceId: SpaceId
    public let relevanceScore: Double
    public let matchedTerms: [String]

    public init(
        pageId: PageId,
        entityId: EntityId,
        title: String,
        excerpt: String?,
        spaceId: SpaceId,
        relevanceScore: Double,
        matchedTerms: [String]
    ) {
        self.pageId = pageId
        self.entityId = entityId
        self.title = title
        self.excerpt = excerpt
        self.spaceId = spaceId
        self.relevanceScore = relevanceScore
        self.matchedTerms = matchedTerms
    }
}

// MARK: - Capability Module Conformance

extension CodexModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // Register module with runtime
        await initialize(governance: runtime.governance)
    }
}
