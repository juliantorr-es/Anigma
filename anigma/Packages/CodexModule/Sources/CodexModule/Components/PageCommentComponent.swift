//
//  PageCommentComponent.swift
//  CodexModule
//
//  Component representing a comment on a page.
//

import Foundation
import AnigmaCore

/// Component representing a comment on a page.
public struct PageCommentComponent: Component, Sendable {
    public let commentId: CommentId
    public let pageId: PageId
    public var parentCommentId: CommentId?  // For threaded replies

    // Content
    public var body: String
    public var contentFormat: ContentFormat

    // Inline comment (for specific locations in content)
    public var isInline: Bool
    public var anchorText: String?          // Text being commented on
    public var anchorPosition: Int?         // Character position in body

    // Author
    public let author: String

    // Status
    public var isResolved: Bool
    public var resolvedBy: String?
    public var resolvedAt: Date?

    // Reactions
    public var reactions: [CommentReaction]

    // Mentions
    public var mentions: [String]           // @mentioned users

    // Lifecycle
    public let createdAt: Date
    public var updatedAt: Date
    public var isEdited: Bool
    public var isDeleted: Bool

    public init(
        commentId: CommentId = CommentId(),
        pageId: PageId,
        parentCommentId: CommentId? = nil,
        body: String,
        contentFormat: ContentFormat = .markdown,
        isInline: Bool = false,
        anchorText: String? = nil,
        anchorPosition: Int? = nil,
        author: String
    ) {
        self.commentId = commentId
        self.pageId = pageId
        self.parentCommentId = parentCommentId
        self.body = body
        self.contentFormat = contentFormat
        self.isInline = isInline
        self.anchorText = anchorText
        self.anchorPosition = anchorPosition
        self.author = author
        self.isResolved = false
        self.reactions = []
        self.mentions = Self.extractMentions(from: body)
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isEdited = false
        self.isDeleted = false
    }

    /// Extracts @mentions from comment body.
    private static func extractMentions(from body: String) -> [String] {
        let pattern = "@([a-zA-Z0-9_-]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(body.startIndex..., in: body)
        let matches = regex.matches(in: body, range: range)

        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: body) else { return nil }
            return String(body[range])
        }
    }

    /// Whether this is a top-level comment.
    public var isTopLevel: Bool {
        parentCommentId == nil
    }

    /// Updates the comment body.
    public mutating func update(body: String) {
        self.body = body
        self.mentions = Self.extractMentions(from: body)
        self.updatedAt = Date()
        self.isEdited = true
    }

    /// Marks the comment as resolved.
    public mutating func resolve(by principal: String) {
        isResolved = true
        resolvedBy = principal
        resolvedAt = Date()
    }

    /// Reopens a resolved comment.
    public mutating func reopen() {
        isResolved = false
        resolvedBy = nil
        resolvedAt = nil
    }

    /// Adds a reaction.
    public mutating func addReaction(_ emoji: String, by user: String) {
        if let index = reactions.firstIndex(where: { $0.emoji == emoji }) {
            if !reactions[index].users.contains(user) {
                reactions[index].users.append(user)
            }
        } else {
            reactions.append(CommentReaction(emoji: emoji, users: [user]))
        }
    }

    /// Removes a reaction.
    public mutating func removeReaction(_ emoji: String, by user: String) {
        guard let index = reactions.firstIndex(where: { $0.emoji == emoji }) else { return }
        reactions[index].users.removeAll { $0 == user }
        if reactions[index].users.isEmpty {
            reactions.remove(at: index)
        }
    }

    /// Soft deletes the comment.
    public mutating func delete() {
        isDeleted = true
        body = "[deleted]"
        updatedAt = Date()
    }
}

// MARK: - Comment Reaction

/// A reaction on a comment.
public struct CommentReaction: Codable, Sendable, Equatable {
    public let emoji: String
    public var users: [String]

    public init(emoji: String, users: [String]) {
        self.emoji = emoji
        self.users = users
    }

    public var count: Int { users.count }
}
