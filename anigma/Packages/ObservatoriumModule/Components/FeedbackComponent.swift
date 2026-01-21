//
//  FeedbackComponent.swift
//  ObservatoriumModule
//
//  User feedback component for capturing bug reports, feature requests,
//  and general feedback from institutional users.
//

import Foundation
import AnigmaCore

/// Component representing user feedback.
/// Feedback flows: captured → triaged → promoted (to Pragma) → resolved.
public struct FeedbackComponent: Component, Codable, Identifiable {
    // MARK: - Identity

    /// Unique feedback ID.
    public let id: FeedbackId

    /// Type of feedback.
    public var feedbackType: FeedbackType

    // MARK: - Content

    /// Title/summary of the feedback.
    public var title: String

    /// Detailed description.
    public var description: String

    /// Severity from user's perspective.
    public var userSeverity: UserSeverity

    // MARK: - Context

    /// Module the feedback is about.
    public var module: String?

    /// Specific view or screen.
    public var view: String?

    /// Tags for categorization.
    public var tags: [String]

    /// Department or team (for CCSF context).
    public var department: String?

    // MARK: - Reporter

    /// User who submitted the feedback.
    public var reporterId: String

    /// Reporter's contact preference.
    public var contactPreference: ContactPreference

    /// Reporter's email (optional, for follow-up).
    public var contactEmail: String?

    // MARK: - Environment

    /// Captured environment info.
    public var environment: EnvironmentInfo

    /// Current URL or view path when feedback was submitted.
    public var currentPath: String?

    /// Session ID for correlation.
    public var sessionId: String?

    // MARK: - Attachments

    /// Screenshot data (base64 encoded, if captured).
    public var screenshotData: String?

    /// System-generated diagnostic info.
    public var diagnosticInfo: [String: String]

    // MARK: - State

    /// Current state in the feedback lifecycle.
    public var state: FeedbackState

    /// Triage notes from reviewer.
    public var triageNotes: String?

    /// Assigned internal severity after triage.
    public var triagedSeverity: AlertSeverity?

    /// Pragma issue ID if promoted.
    public var pragmaIssueId: String?

    /// Assignee for handling.
    public var assigneeId: String?

    // MARK: - Timestamps

    public let submittedAt: Date
    public var triagedAt: Date?
    public var resolvedAt: Date?
    public var lastUpdatedAt: Date

    // MARK: - Initialization

    public init(
        id: FeedbackId = FeedbackId(),
        feedbackType: FeedbackType,
        title: String,
        description: String,
        userSeverity: UserSeverity = .medium,
        module: String? = nil,
        view: String? = nil,
        tags: [String] = [],
        department: String? = nil,
        reporterId: String,
        contactPreference: ContactPreference = .inApp,
        contactEmail: String? = nil,
        environment: EnvironmentInfo = EnvironmentInfo.current,
        currentPath: String? = nil,
        sessionId: String? = nil,
        screenshotData: String? = nil,
        diagnosticInfo: [String: String] = [:],
        state: FeedbackState = .submitted,
        triageNotes: String? = nil,
        triagedSeverity: AlertSeverity? = nil,
        pragmaIssueId: String? = nil,
        assigneeId: String? = nil,
        submittedAt: Date = Date(),
        triagedAt: Date? = nil,
        resolvedAt: Date? = nil,
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.feedbackType = feedbackType
        self.title = title
        self.description = description
        self.userSeverity = userSeverity
        self.module = module
        self.view = view
        self.tags = tags
        self.department = department
        self.reporterId = reporterId
        self.contactPreference = contactPreference
        self.contactEmail = contactEmail
        self.environment = environment
        self.currentPath = currentPath
        self.sessionId = sessionId
        self.screenshotData = screenshotData
        self.diagnosticInfo = diagnosticInfo
        self.state = state
        self.triageNotes = triageNotes
        self.triagedSeverity = triagedSeverity
        self.pragmaIssueId = pragmaIssueId
        self.assigneeId = assigneeId
        self.submittedAt = submittedAt
        self.triagedAt = triagedAt
        self.resolvedAt = resolvedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

/// Types of feedback.
public enum FeedbackType: String, Codable, Sendable {
    case bug = "bug"                 // Something is broken
    case performance = "performance" // Something is slow
    case usability = "usability"     // Hard to use / confusing
    case feature = "feature"         // Feature request
    case question = "question"       // How do I...?
    case praise = "praise"           // This is great!
    case other = "other"             // Doesn't fit above
}

/// User's perception of severity.
public enum UserSeverity: String, Codable, Sendable {
    case low = "low"           // Minor annoyance
    case medium = "medium"     // Noticeable problem
    case high = "high"         // Significant impact
    case blocker = "blocker"   // Cannot continue work
}

/// How user wants to be contacted.
public enum ContactPreference: String, Codable, Sendable {
    case inApp = "in_app"     // Notify in application
    case email = "email"      // Send email
    case none = "none"        // Don't contact me
}

/// State of feedback in its lifecycle.
public enum FeedbackState: String, Codable, Sendable {
    case submitted      // Just received
    case acknowledged   // Auto-acknowledged to user
    case triaged        // Reviewed and categorized
    case promoted       // Escalated to Pragma issue
    case inProgress     // Being worked on
    case resolved       // Fixed or answered
    case declined       // Won't fix / out of scope
    case duplicate      // Duplicate of another
}

// MARK: - Feedback Summary

/// Lightweight summary for list views.
public struct FeedbackSummary: Sendable, Identifiable {
    public let id: FeedbackId
    public let feedbackType: FeedbackType
    public let title: String
    public let userSeverity: UserSeverity
    public let state: FeedbackState
    public let submittedAt: Date
    public let department: String?
    public let hasPragmaIssue: Bool

    public init(from feedback: FeedbackComponent) {
        self.id = feedback.id
        self.feedbackType = feedback.feedbackType
        self.title = feedback.title
        self.userSeverity = feedback.userSeverity
        self.state = feedback.state
        self.submittedAt = feedback.submittedAt
        self.department = feedback.department
        self.hasPragmaIssue = feedback.pragmaIssueId != nil
    }
}
public struct BugReportConfiguration: Sendable {
    public let title: String
    public let description: String
    public let severity: UserSeverity
    public let module: String
    public let reporterId: String
    public let currentPath: String?
    public let sessionId: String?
}

extension FeedbackComponent {
    /// Creates a bug report.
    public static func bugReport(config: BugReportConfiguration) -> FeedbackComponent {
        FeedbackComponent(
            feedbackType: .bug,
            title: config.title,
            description: config.description,
            userSeverity: config.severity,
            module: config.module,
            reporterId: config.reporterId,
            currentPath: config.currentPath,
            sessionId: config.sessionId
        )
    }

    /// Creates a feature request.
    public static func featureRequest(
        title: String,
        description: String,
        module: String?,
        reporterId: String,
        tags: [String] = []
    ) -> FeedbackComponent {
        FeedbackComponent(
            feedbackType: .feature,
            title: title,
            description: description,
            userSeverity: .medium,
            module: module,
            tags: tags,
            reporterId: reporterId
        )
    }

    /// Gathers system diagnostic info.
    private static func gatherDiagnostics() -> [String: String] {
        var info: [String: String] = [:]

        let processInfo = ProcessInfo.processInfo
        info["memory_mb"] = String(format: "%.0f", Double(processInfo.physicalMemory) / 1_000_000)
        info["processor_count"] = String(processInfo.processorCount)
        info["thermal_state"] = {
            switch processInfo.thermalState {
            case .nominal: return "nominal"
            case .fair: return "fair"
            case .serious: return "serious"
            case .critical: return "critical"
            @unknown default: return "unknown"
            }
        }()
        info["uptime_seconds"] = String(Int(processInfo.systemUptime))

        return info
    }
}

