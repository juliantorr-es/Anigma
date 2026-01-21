//
//  PageComponent.swift
//  CodexModule
//
//  Component representing a page/document in the knowledge base.
//

import Foundation
import AnigmaCore

/// Component representing a page or document.
public struct PageComponent: Component, Sendable, Codable {
    public let pageId: PageId
    public var spaceId: SpaceId
    public var pageType: PageType
    public var status: PageStatus

    // Content
    public var title: String
    public var slug: String             // URL-friendly identifier
    public var body: String
    public var contentFormat: ContentFormat
    public var excerpt: String?         // Summary/preview text

    // Hierarchy
    public var parentPageId: PageId?
    public var childPageIds: [PageId]
    public var order: Int               // Order among siblings

    // Versioning
    public var currentVersionId: VersionId
    public var versionNumber: Int

    // Metadata
    public var author: String
    public var contributors: [String]
    public var visibility: ContentVisibility

    // Classification
    public var tags: Set<String>
    public var labels: [String]         // KB article labels
    public var category: String?        // KB category
    public var customFields: [String: String]

    // Attachments
    public var attachmentIds: [String]

    // Related content
    public var relatedPageIds: [PageId]
    public var linkedFromPageIds: [PageId]  // Backlinks

    // Stats
    public var viewCount: Int
    public var helpfulCount: Int        // For KB articles
    public var notHelpfulCount: Int
    public var commentCount: Int

    // Lifecycle
    public var createdAt: Date
    public var updatedAt: Date
    public var publishedAt: Date?
    public var archivedAt: Date?
    public var lastViewedAt: Date?

    // Review/Approval
    public var reviewedBy: String?
    public var reviewedAt: Date?
    public var approvedBy: String?
    public var approvedAt: Date?

    // Locking
    public var lockedBy: String?
    public var lockedAt: Date?
    public var lockExpires: Date?

    public init(
        pageId: PageId = PageId(),
        spaceId: SpaceId,
        pageType: PageType = .document,
        status: PageStatus = .draft,
        title: String,
        slug: String? = nil,
        body: String = "",
        contentFormat: ContentFormat = .markdown,
        excerpt: String? = nil,
        parentPageId: PageId? = nil,
        childPageIds: [PageId] = [],
        order: Int = 0,
        author: String,
        visibility: ContentVisibility = .internal,
        tags: Set<String> = [],
        labels: [String] = [],
        category: String? = nil,
        customFields: [String: String] = [:]
    ) {
        self.pageId = pageId
        self.spaceId = spaceId
        self.pageType = pageType
        self.status = status
        self.title = title
        self.slug = slug ?? Self.generateSlug(from: title)
        self.body = body
        self.contentFormat = contentFormat
        self.excerpt = excerpt
        self.parentPageId = parentPageId
        self.childPageIds = childPageIds
        self.order = order
        self.currentVersionId = VersionId()
        self.versionNumber = 1
        self.author = author
        self.contributors = [author]
        self.visibility = visibility
        self.tags = tags
        self.labels = labels
        self.category = category
        self.customFields = customFields
        self.attachmentIds = []
        self.relatedPageIds = []
        self.linkedFromPageIds = []
        self.viewCount = 0
        self.helpfulCount = 0
        self.notHelpfulCount = 0
        self.commentCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Generates a URL-friendly slug from a title.
    public static func generateSlug(from title: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        var slug = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: allowed.inverted)
            .joined()
        // Collapse multiple dashes into single dash
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Whether the page can be edited.
    public var isEditable: Bool {
        status.isEditable && !isLocked
    }

    /// Whether the page is currently locked.
    public var isLocked: Bool {
        guard lockedBy != nil, let expires = lockExpires else { return false }
        return expires > Date()
    }

    /// Whether the page is published.
    public var isPublished: Bool {
        status == .published
    }

    /// Full path combining space key and slug.
    public func path(spaceKey: String) -> String {
        "/\(spaceKey)/\(slug)"
    }

    /// Updates content and increments version.
    public mutating func updateContent(
        title: String? = nil,
        body: String? = nil,
        excerpt: String? = nil,
        editor: String
    ) {
        if let title = title, title != self.title {
            self.title = title
            self.slug = Self.generateSlug(from: title)
        }
        if let body = body {
            self.body = body
        }
        if let excerpt = excerpt {
            self.excerpt = excerpt
        }

        // Increment version
        self.currentVersionId = VersionId()
        self.versionNumber += 1

        // Track contributor
        if !contributors.contains(editor) {
            contributors.append(editor)
        }

        self.updatedAt = Date()
    }

    /// Publishes the page.
    public mutating func publish(by principal: String) {
        status = .published
        publishedAt = Date()
        approvedBy = principal
        approvedAt = Date()
        updatedAt = Date()
    }

    /// Archives the page.
    public mutating func archive() {
        status = .archived
        archivedAt = Date()
        updatedAt = Date()
    }

    /// Acquires a lock on the page.
    public mutating func acquireLock(by principal: String, duration: TimeInterval = 3600) -> Bool {
        if isLocked && lockedBy != principal {
            return false
        }
        lockedBy = principal
        lockedAt = Date()
        lockExpires = Date().addingTimeInterval(duration)
        return true
    }

    /// Releases the lock on the page.
    public mutating func releaseLock(by principal: String) -> Bool {
        guard lockedBy == principal else { return false }
        lockedBy = nil
        lockedAt = nil
        lockExpires = nil
        return true
    }

    /// Records a view.
    public mutating func recordView() {
        viewCount += 1
        lastViewedAt = Date()
    }

    /// Records feedback on a KB article.
    public mutating func recordFeedback(helpful: Bool) {
        if helpful {
            helpfulCount += 1
        } else {
            notHelpfulCount += 1
        }
    }

    /// Helpfulness score (0.0 to 1.0).
    public var helpfulnessScore: Double? {
        let total = helpfulCount + notHelpfulCount
        guard total > 0 else { return nil }
        return Double(helpfulCount) / Double(total)
    }
}
