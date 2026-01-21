//
//  CommentComponent.swift
//  PragmaModule
//
//  Comments and discussion threads for work items.
//

import Foundation
import AnigmaCore

/// Component representing a comment on a work item.
public struct CommentComponent: Component, Codable, Identifiable, Sendable {
    /// Unique comment ID.
    public let id: UUID

    /// Work item this comment belongs to.
    public let workItemId: WorkItemId

    /// Author user ID.
    public let authorId: String

    /// Comment body (Markdown supported).
    public var body: String

    /// Mentioned user IDs (extracted from @mentions).
    public var mentionedUserIds: [String]

    /// Parent comment ID (for threaded replies).
    public var parentCommentId: UUID?

    /// Whether this is a system-generated comment.
    public var isSystemComment: Bool

    /// Comment type for special rendering.
    public var commentType: CommentType

    /// Reactions on this comment.
    public var reactions: [CommentReaction]

    // MARK: - Timestamps

    public let createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    /// Version for edit tracking.
    public var version: Int

    public init(
        id: UUID = UUID(),
        workItemId: WorkItemId,
        authorId: String,
        body: String,
        mentionedUserIds: [String] = [],
        parentCommentId: UUID? = nil,
        isSystemComment: Bool = false,
        commentType: CommentType = .comment,
        reactions: [CommentReaction] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.workItemId = workItemId
        self.authorId = authorId
        self.body = body
        self.mentionedUserIds = mentionedUserIds
        self.parentCommentId = parentCommentId
        self.isSystemComment = isSystemComment
        self.commentType = commentType
        self.reactions = reactions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.version = version
    }

    /// Whether this comment has been edited.
    public var isEdited: Bool {
        version > 1 && updatedAt > createdAt
    }

    /// Whether this comment is deleted (soft delete).
    public var isDeleted: Bool {
        deletedAt != nil
    }

    /// Whether this is a reply to another comment.
    public var isReply: Bool {
        parentCommentId != nil
    }
}

// MARK: - Comment Types

/// Types of comments for special rendering.
public enum CommentType: String, Codable, Sendable, CaseIterable {
    /// Regular user comment.
    case comment

    /// Review comment on an attempt.
    case review

    /// Status change notification.
    case statusChange

    /// Assignment change.
    case assignmentChange

    /// Field update.
    case fieldChange

    /// Workflow transition.
    case transition

    /// Link added/removed.
    case linkChange

    /// Time logged.
    case workLog

    /// Attachment added.
    case attachment

    /// AI-generated comment/summary.
    case aiGenerated

    /// Resolution comment.
    case resolution

    public var isUserGenerated: Bool {
        self == .comment || self == .review || self == .resolution
    }

    public var icon: String {
        switch self {
        case .comment: return "💬"
        case .review: return "📝"
        case .statusChange: return "🔄"
        case .assignmentChange: return "👤"
        case .fieldChange: return "✏️"
        case .transition: return "➡️"
        case .linkChange: return "🔗"
        case .workLog: return "⏱️"
        case .attachment: return "📎"
        case .aiGenerated: return "🤖"
        case .resolution: return "✅"
        }
    }
}

// MARK: - Comment Reactions

/// A reaction on a comment.
public struct CommentReaction: Codable, Sendable, Equatable {
    public let emoji: String
    public let userId: String
    public let createdAt: Date

    public init(emoji: String, userId: String, createdAt: Date = Date()) {
        self.emoji = emoji
        self.userId = userId
        self.createdAt = createdAt
    }
}

// MARK: - System Comment Builders

extension CommentComponent {
    /// Creates a status change system comment.
    public static func statusChange(
        workItemId: WorkItemId,
        userId: String,
        from: String,
        to: String
    ) -> CommentComponent {
        CommentComponent(
            workItemId: workItemId,
            authorId: userId,
            body: "Changed status from **\(from)** to **\(to)**",
            isSystemComment: true,
            commentType: .statusChange
        )
    }

    /// Creates an assignment change system comment.
    public static func assignmentChange(
        workItemId: WorkItemId,
        userId: String,
        oldAssignee: String?,
        newAssignee: String?
    ) -> CommentComponent {
        let body: String
        if let old = oldAssignee, let new = newAssignee {
            body = "Reassigned from **\(old)** to **\(new)**"
        } else if let new = newAssignee {
            body = "Assigned to **\(new)**"
        } else if let old = oldAssignee {
            body = "Unassigned from **\(old)**"
        } else {
            body = "Assignment changed"
        }

        return CommentComponent(
            workItemId: workItemId,
            authorId: userId,
            body: body,
            isSystemComment: true,
            commentType: .assignmentChange
        )
    }

    /// Creates a work log system comment.
    public static func workLog(
        workItemId: WorkItemId,
        userId: String,
        hours: Double,
        description: String?
    ) -> CommentComponent {
        var body = "Logged **\(hours)h** of work"
        if let desc = description {
            body += ": \(desc)"
        }

        return CommentComponent(
            workItemId: workItemId,
            authorId: userId,
            body: body,
            isSystemComment: true,
            commentType: .workLog
        )
    }
}

// MARK: - Discussion Thread

/// Aggregated discussion thread for a work item.
public struct DiscussionThread: Sendable {
    public let workItemId: WorkItemId
    public let comments: [CommentComponent]
    public let totalCount: Int
    public let participantIds: [String]

    public init(workItemId: WorkItemId, comments: [CommentComponent]) {
        self.workItemId = workItemId
        self.comments = comments.filter { !$0.isDeleted }
        self.totalCount = self.comments.count
        self.participantIds = Array(Set(self.comments.map { $0.authorId }))
    }

    /// Root comments (not replies).
    public var rootComments: [CommentComponent] {
        comments.filter { !$0.isReply }
    }

    /// Replies to a specific comment.
    public func replies(to commentId: UUID) -> [CommentComponent] {
        comments.filter { $0.parentCommentId == commentId }
    }

    /// User-generated comments only.
    public var userComments: [CommentComponent] {
        comments.filter { $0.commentType.isUserGenerated }
    }

    /// Activity feed (system comments).
    public var activityFeed: [CommentComponent] {
        comments.filter { $0.isSystemComment }
    }
}
