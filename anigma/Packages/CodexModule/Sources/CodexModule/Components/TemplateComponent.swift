import AnigmaPrimitives

import AnigmaPrimitives

//
//  TemplateComponent.swift
//  CodexModule
//
//  Component representing a page template.
//

import Foundation
import AnigmaCore

/// Component representing a reusable page template.
public struct TemplateComponent: Component, Sendable {
    public let templateId: TemplateId
    public var category: TemplateCategory

    // Basic information
    public var name: String
    public var description: String?
    public var iconEmoji: String?

    // Template content
    public var titleTemplate: String    // Template for title (can include placeholders)
    public var bodyTemplate: String     // Template body content
    public var contentFormat: ContentFormat
    public var defaultPageType: PageType

    // Placeholders
    public var placeholders: [TemplatePlaceholder]

    // Scope
    public var isGlobal: Bool           // Available across all spaces
    public var spaceIds: [SpaceId]      // Specific spaces where available
    public var allowedPageTypes: [PageType]

    // Metadata
    public var tags: Set<String>
    public var author: String
    public var useCount: Int

    // Lifecycle
    public var createdAt: Date
    public var updatedAt: Date
    public var isActive: Bool

    public init(
        templateId: TemplateId = TemplateId(),
        category: TemplateCategory = .general,
        name: String,
        description: String? = nil,
        iconEmoji: String? = nil,
        titleTemplate: String = "",
        bodyTemplate: String,
        contentFormat: ContentFormat = .markdown,
        defaultPageType: PageType = .document,
        placeholders: [TemplatePlaceholder] = [],
        isGlobal: Bool = true,
        spaceIds: [SpaceId] = [],
        allowedPageTypes: [PageType] = PageType.allCases,
        tags: Set<String> = [],
        author: String
    ) {
        self.templateId = templateId
        self.category = category
        self.name = name
        self.description = description
        self.iconEmoji = iconEmoji
        self.titleTemplate = titleTemplate
        self.bodyTemplate = bodyTemplate
        self.contentFormat = contentFormat
        self.defaultPageType = defaultPageType
        self.placeholders = placeholders
        self.isGlobal = isGlobal
        self.spaceIds = spaceIds
        self.allowedPageTypes = allowedPageTypes
        self.tags = tags
        self.author = author
        self.useCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
    }

    /// Applies placeholder values to generate content.
    public func apply(values: [String: String]) -> (title: String, body: String) {
        var title = titleTemplate
        var body = bodyTemplate

        for placeholder in placeholders {
            let key = "{{\(placeholder.key)}}"
            let value = values[placeholder.key] ?? placeholder.defaultValue ?? ""
            title = title.replacingOccurrences(of: key, with: value)
            body = body.replacingOccurrences(of: key, with: value)
        }

        return (title, body)
    }

    /// Validates that required placeholders have values.
    public func validate(values: [String: String]) -> [String] {
        var missing: [String] = []
        for placeholder in placeholders where placeholder.isRequired {
            if values[placeholder.key]?.isEmpty ?? true {
                missing.append(placeholder.key)
            }
        }
        return missing
    }
}

// MARK: - Template Placeholder

/// A placeholder within a template.
public struct TemplatePlaceholder: Codable, Sendable, Equatable {
    public let key: String              // e.g., "project_name", "date", "author"
    public let label: String            // Human-readable label
    public let description: String?
    public let type: PlaceholderType
    public let isRequired: Bool
    public let defaultValue: String?
    public let options: [String]?       // For select type

    public init(
        key: String,
        label: String,
        description: String? = nil,
        type: PlaceholderType = .text,
        isRequired: Bool = false,
        defaultValue: String? = nil,
        options: [String]? = nil
    ) {
        self.key = key
        self.label = label
        self.description = description
        self.type = type
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.options = options
    }
}

public enum PlaceholderType: String, Codable, Sendable, CaseIterable {
    case text               // Single line text
    case multiline          // Multi-line text
    case date               // Date picker
    case select             // Dropdown select
    case user               // User picker
    case number             // Numeric input
    case boolean            // Yes/no toggle
}

// MARK: - Built-in Templates

extension TemplateComponent {
    /// Meeting notes template.
    public static func meetingNotes(author: String) -> TemplateComponent {
        TemplateComponent(
            category: .meeting,
            name: "Meeting Notes",
            description: "Template for recording meeting notes and action items",
            iconEmoji: "📝",
            titleTemplate: "Meeting Notes: {{meeting_title}} - {{date}}",
            bodyTemplate: """
            # {{meeting_title}}

            **Date:** {{date}}
            **Attendees:** {{attendees}}
            **Facilitator:** {{facilitator}}

            ## Agenda

            1.
            2.
            3.

            ## Discussion Notes



            ## Decisions Made

            -

            ## Action Items

            | Action | Owner | Due Date |
            |--------|-------|----------|
            |        |       |          |

            ## Next Meeting

            **Date:**
            **Topics to Cover:**
            """,
            defaultPageType: .meeting,
            placeholders: [
                TemplatePlaceholder(key: "meeting_title", label: "Meeting Title", isRequired: true),
                TemplatePlaceholder(key: "date", label: "Date", type: .date, isRequired: true),
                TemplatePlaceholder(key: "attendees", label: "Attendees"),
                TemplatePlaceholder(key: "facilitator", label: "Facilitator")
            ],
            author: author
        )
    }

    /// Decision record (ADR) template.
    public static func decisionRecord(author: String) -> TemplateComponent {
        TemplateComponent(
            category: .software,
            name: "Decision Record (ADR)",
            description: "Architecture Decision Record for documenting technical decisions",
            iconEmoji: "⚖️",
            titleTemplate: "ADR-{{number}}: {{title}}",
            bodyTemplate: """
            # ADR-{{number}}: {{title}}

            **Status:** {{status}}
            **Date:** {{date}}
            **Author:** {{author}}

            ## Context

            What is the issue that we're seeing that is motivating this decision or change?

            ## Decision

            What is the change that we're proposing and/or doing?

            ## Consequences

            What becomes easier or more difficult to do because of this change?

            ### Positive

            -

            ### Negative

            -

            ### Neutral

            -

            ## Alternatives Considered

            ### Option 1:

            **Pros:**
            -

            **Cons:**
            -

            ## Related Decisions

            -
            """,
            defaultPageType: .decision,
            placeholders: [
                TemplatePlaceholder(key: "number", label: "ADR Number", type: .number, isRequired: true),
                TemplatePlaceholder(key: "title", label: "Decision Title", isRequired: true),
                TemplatePlaceholder(key: "status", label: "Status", type: .select, defaultValue: "Proposed",
                                   options: ["Proposed", "Accepted", "Deprecated", "Superseded"]),
                TemplatePlaceholder(key: "date", label: "Date", type: .date, isRequired: true),
                TemplatePlaceholder(key: "author", label: "Author", type: .user)
            ],
            author: author
        )
    }

    /// Runbook template.
    public static func runbook(author: String) -> TemplateComponent {
        TemplateComponent(
            category: .software,
            name: "Operational Runbook",
            description: "Template for operational procedures and incident response",
            iconEmoji: "📋",
            titleTemplate: "Runbook: {{procedure_name}}",
            bodyTemplate: """
            # {{procedure_name}}

            **Last Updated:** {{date}}
            **Owner:** {{owner}}
            **Review Frequency:** {{review_frequency}}

            ## Overview

            Brief description of what this runbook covers.

            ## Prerequisites

            - [ ] Access to ...
            - [ ] Tools required: ...
            - [ ] Knowledge of: ...

            ## Procedure

            ### Step 1:

            ```bash
            # Commands here
            ```

            ### Step 2:

            ### Step 3:

            ## Verification

            How to verify the procedure was successful.

            ## Rollback

            Steps to rollback if something goes wrong.

            ## Troubleshooting

            | Symptom | Possible Cause | Resolution |
            |---------|----------------|------------|
            |         |                |            |

            ## Related Documents

            -

            ## Change History

            | Date | Author | Changes |
            |------|--------|---------|
            |      |        |         |
            """,
            defaultPageType: .runbook,
            placeholders: [
                TemplatePlaceholder(key: "procedure_name", label: "Procedure Name", isRequired: true),
                TemplatePlaceholder(key: "date", label: "Date", type: .date, isRequired: true),
                TemplatePlaceholder(key: "owner", label: "Owner", type: .user),
                TemplatePlaceholder(key: "review_frequency", label: "Review Frequency", type: .select,
                                   defaultValue: "Quarterly",
                                   options: ["Monthly", "Quarterly", "Annually"])
            ],
            author: author
        )
    }

    /// Alt-media request template (DSPS specific).
    public static func altMediaRequest(author: String) -> TemplateComponent {
        TemplateComponent(
            category: .accessibility,
            name: "Alt-Media Request",
            description: "Template for documenting alternative media conversion requests",
            iconEmoji: "♿",
            titleTemplate: "Alt-Media Request: {{document_title}}",
            bodyTemplate: """
            # Alt-Media Request

            ## Request Information

            **Student ID:** {{student_id}}
            **Course:** {{course}}
            **Instructor:** {{instructor}}
            **Request Date:** {{date}}
            **Due Date:** {{due_date}}

            ## Source Document

            **Title:** {{document_title}}
            **Type:** {{document_type}}
            **Page Count:** {{page_count}}
            **Source Location:**

            ## Requested Formats

            - [ ] Electronic Text
            - [ ] Large Print (Size: ___)
            - [ ] Braille
            - [ ] Audio
            - [ ] EPUB
            - [ ] Other: ___

            ## Special Requirements

            {{special_requirements}}

            ## Processing Notes



            ## Quality Assurance

            - [ ] OCR accuracy verified
            - [ ] Formatting preserved
            - [ ] Images described
            - [ ] Tables accessible
            - [ ] Student notified

            ## Delivery

            **Delivered Date:**
            **Delivered By:**
            **Delivery Method:**
            """,
            defaultPageType: .document,
            placeholders: [
                TemplatePlaceholder(key: "student_id", label: "Student ID", isRequired: true),
                TemplatePlaceholder(key: "course", label: "Course", isRequired: true),
                TemplatePlaceholder(key: "instructor", label: "Instructor"),
                TemplatePlaceholder(key: "date", label: "Request Date", type: .date, isRequired: true),
                TemplatePlaceholder(key: "due_date", label: "Due Date", type: .date),
                TemplatePlaceholder(key: "document_title", label: "Document Title", isRequired: true),
                TemplatePlaceholder(key: "document_type", label: "Document Type", type: .select,
                                   options: ["Textbook", "Handout", "Exam", "Syllabus", "Article", "Other"]),
                TemplatePlaceholder(key: "page_count", label: "Page Count", type: .number),
                TemplatePlaceholder(key: "special_requirements", label: "Special Requirements", type: .multiline)
            ],
            author: author
        )
    }
}
