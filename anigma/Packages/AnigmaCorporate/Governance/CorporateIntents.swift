//
//  CorporateIntents.swift
//  AnigmaCorporate
//
//  Defines concrete intents for corporate actions.
//

import Foundation
import AnigmaCore
import AnigmaSystemSpine

public struct PostMessageIntent: GovernanceIntent, Codable {
    public let id: UUID
    public let channelId: String
    public let message: String
    public let attachments: [String] // URLs or IDs

    public var description: String {
        return "Post message to channel \(channelId)"
    }

    public init(channelId: String, message: String, attachments: [String] = []) {
        self.id = UUID()
        self.channelId = channelId
        self.message = message
        self.attachments = attachments
    }
}

public struct CreateIssueIntent: GovernanceIntent, Codable {
    public let id: UUID
    public let projectKey: String
    public let summary: String
    public let issueDescription: String
    public let issueType: String

    public var description: String {
        return "Create \(issueType) in \(projectKey): \(summary)"
    }

    public init(projectKey: String, summary: String, description: String, issueType: String = "Task") {
        self.id = UUID()
        self.projectKey = projectKey
        self.summary = summary
        self.issueDescription = description
        self.issueType = issueType
    }
}

public struct UpdateRecordIntent: GovernanceIntent, Codable {
    public let id: UUID
    public let recordId: String
    public let fields: [String: String]

    public var description: String {
        return "Update record \(recordId) with \(fields.keys.joined(separator: ", "))"
    }

    public init(recordId: String, fields: [String: String]) {
        self.id = UUID()
        self.recordId = recordId
        self.fields = fields
    }
}

public struct SendEnvelopeIntent: GovernanceIntent, Codable {
    public let id: UUID
    public let templateId: String
    public let recipients: [String] // Email addresses
    public let subject: String

    public var description: String {
        return "Send envelope '\(subject)' to \(recipients.joined(separator: ", "))"
    }

    public init(templateId: String, recipients: [String], subject: String) {
        self.id = UUID()
        self.templateId = templateId
        self.recipients = recipients
        self.subject = subject
    }
}

public struct PublishPageIntent: GovernanceIntent, Codable {
    public let id: UUID
    public let spaceKey: String
    public let title: String
    public let content: String
    public let parentId: String?

    public var description: String {
        return "Publish page '\(title)' to space \(spaceKey)"
    }

    public init(spaceKey: String, title: String, content: String, parentId: String? = nil) {
        self.id = UUID()
        self.spaceKey = spaceKey
        self.title = title
        self.content = content
        self.parentId = parentId
    }
}
