//
//  PageVersionComponent.swift
//  CodexModule
//
//  Component representing a version of a page (for version history).
//

import Foundation
import AnigmaCore

/// Component representing a specific version of a page.
public struct PageVersionComponent: Component, Sendable, Codable {
    public let versionId: VersionId
    public let pageId: PageId
    public let versionNumber: Int

    // Content snapshot
    public let title: String
    public let body: String
    public let contentFormat: ContentFormat
    public let excerpt: String?

    // Metadata
    public let author: String           // Who created this version
    public let changeMessage: String?   // Commit-style message
    public let changedFields: [String]  // What fields changed

    // Diff info
    public let addedLines: Int
    public let removedLines: Int
    public let previousVersionId: VersionId?

    // Timestamps
    public let createdAt: Date

    public init(
        versionId: VersionId = VersionId(),
        pageId: PageId,
        versionNumber: Int,
        title: String,
        body: String,
        contentFormat: ContentFormat = .markdown,
        excerpt: String? = nil,
        author: String,
        changeMessage: String? = nil,
        changedFields: [String] = [],
        addedLines: Int = 0,
        removedLines: Int = 0,
        previousVersionId: VersionId? = nil
    ) {
        self.versionId = versionId
        self.pageId = pageId
        self.versionNumber = versionNumber
        self.title = title
        self.body = body
        self.contentFormat = contentFormat
        self.excerpt = excerpt
        self.author = author
        self.changeMessage = changeMessage
        self.changedFields = changedFields
        self.addedLines = addedLines
        self.removedLines = removedLines
        self.previousVersionId = previousVersionId
        self.createdAt = Date()
    }

    /// Creates a version from a page component.
    public static func from(
        page: PageComponent,
        previousVersion: PageVersionComponent?,
        changeMessage: String?,
        changedFields: [String]
    ) -> PageVersionComponent {
        // Calculate diff stats (simplified)
        let previousLines = previousVersion?.body.components(separatedBy: .newlines).count ?? 0
        let currentLines = page.body.components(separatedBy: .newlines).count

        return PageVersionComponent(
            versionId: page.currentVersionId,
            pageId: page.pageId,
            versionNumber: page.versionNumber,
            title: page.title,
            body: page.body,
            contentFormat: page.contentFormat,
            excerpt: page.excerpt,
            author: page.contributors.last ?? page.author,
            changeMessage: changeMessage,
            changedFields: changedFields,
            addedLines: max(0, currentLines - previousLines),
            removedLines: max(0, previousLines - currentLines),
            previousVersionId: previousVersion?.versionId
        )
    }

    /// Summary of changes.
    public var changeSummary: String {
        if addedLines > 0 && removedLines > 0 {
            return "+\(addedLines) / -\(removedLines) lines"
        } else if addedLines > 0 {
            return "+\(addedLines) lines"
        } else if removedLines > 0 {
            return "-\(removedLines) lines"
        } else {
            return "No content changes"
        }
    }
}
