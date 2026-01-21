//
//  ErrorComponent.swift
//  ObservatoriumModule
//
//  Error tracking component for capturing and aggregating errors.
//  Errors are structured, classified, and can be promoted to Pragma issues.
//

import Foundation
import AnigmaCore

/// Component representing a tracked error.
/// Errors are captured with context for debugging and can be aggregated.
public struct ErrorRecordComponent: Component, Codable, Identifiable {
    // MARK: - Identity

    /// Unique error record ID.
    public let id: ErrorRecordId

    /// Error fingerprint for grouping similar errors.
    /// Based on error type + message + first stack frame.
    public let fingerprint: String

    // MARK: - Error Details

    /// Error type/class name.
    public var errorType: String

    /// Error message.
    public var message: String

    /// Severity level.
    public var severity: AlertSeverity

    /// Module where the error occurred.
    public var module: String

    /// Specific component or function.
    public var component: String?

    // MARK: - Context

    /// Stack trace (if available).
    public var stackTrace: [String]?

    /// Environment info (version, platform, etc.).
    public var environment: EnvironmentInfo

    /// Additional context for debugging.
    public var context: [String: String]

    /// Correlation ID for tracing across systems.
    public var correlationId: String?

    /// Principal who triggered the error (redacted if needed).
    public var principalId: String?

    // MARK: - State

    /// Current handling state.
    public var state: ErrorState

    /// Pragma issue ID if promoted.
    public var pragmaIssueId: String?

    /// Times this error has occurred (for aggregated records).
    public var occurrenceCount: Int

    /// First occurrence time.
    public let firstSeenAt: Date

    /// Most recent occurrence.
    public var lastSeenAt: Date

    // MARK: - Sensitivity

    /// Whether this error contains or may contain sensitive data.
    /// If true, extra care needed when logging/sharing.
    public var maySensitive: Bool

    // MARK: - Initialization

    public init(
        id: ErrorRecordId = ErrorRecordId(),
        fingerprint: String,
        errorType: String,
        message: String,
        severity: AlertSeverity = .error,
        module: String,
        component: String? = nil,
        stackTrace: [String]? = nil,
        environment: EnvironmentInfo = EnvironmentInfo.current,
        context: [String: String] = [:],
        correlationId: String? = nil,
        principalId: String? = nil,
        state: ErrorState = .new,
        pragmaIssueId: String? = nil,
        occurrenceCount: Int = 1,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        maySensitive: Bool = false
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.errorType = errorType
        self.message = message
        self.severity = severity
        self.module = module
        self.component = component
        self.stackTrace = stackTrace
        self.environment = environment
        self.context = context
        self.correlationId = correlationId
        self.principalId = principalId
        self.state = state
        self.pragmaIssueId = pragmaIssueId
        self.occurrenceCount = occurrenceCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.maySensitive = maySensitive
    }

    /// Creates a fingerprint from error components.
    public static func createFingerprint(
        errorType: String,
        message: String,
        module: String,
        component: String?
    ) -> String {
        // Normalize message by removing numbers and UUIDs for better grouping
        let normalizedMessage = message
            .replacingOccurrences(of: "[0-9a-fA-F-]{36}", with: "<UUID>", options: .regularExpression)
            .replacingOccurrences(of: "\\d+", with: "<N>", options: .regularExpression)

        let components = [errorType, normalizedMessage, module, component ?? ""]
        let combined = components.joined(separator: "|")

        // Simple hash for fingerprint
        var hash: UInt64 = 5381
        for char in combined.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        return String(format: "%016llx", hash)
    }

    /// Merges another occurrence into this record.
    public mutating func mergeOccurrence(at timestamp: Date, context: [String: String]? = nil) {
        occurrenceCount += 1
        lastSeenAt = max(lastSeenAt, timestamp)

        // Merge context if provided (keep last seen values)
        if let newContext = context {
            for (key, value) in newContext {
                self.context[key] = value
            }
        }
    }
}

/// State of an error in its lifecycle.
public enum ErrorState: String, Codable, Sendable {
    case new        // Just recorded
    case seen       // Reviewed but not actioned
    case triaged    // Assigned severity and owner
    case promoted   // Escalated to Pragma issue
    case resolved   // Fixed
    case ignored    // Marked as noise
}

/// Environment information captured with errors.
public struct EnvironmentInfo: Codable, Sendable {
    public var appVersion: String
    public var platform: String
    public var osVersion: String
    public var deviceModel: String?
    public var buildNumber: String?
    public var environment: String  // dev, staging, prod

    public init(
        appVersion: String = "0.1.0",
        platform: String = "macOS",
        osVersion: String = "",
        deviceModel: String? = nil,
        buildNumber: String? = nil,
        environment: String = "dev"
    ) {
        self.appVersion = appVersion
        self.platform = platform
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.buildNumber = buildNumber
        self.environment = environment
    }

    public static var current: EnvironmentInfo {
        EnvironmentInfo(
            appVersion: ObservatoriumModule.version,
            platform: {
                #if os(macOS)
                return "macOS"
                #elseif os(iOS)
                return "iOS"
                #elseif os(tvOS)
                return "tvOS"
                #elseif os(watchOS)
                return "watchOS"
                #else
                return "Unknown"
                #endif
            }(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            environment: {
                #if DEBUG
                return "dev"
                #else
                return "prod"
                #endif
            }()
        )
    }
}

// MARK: - Error Summary

/// Lightweight summary of an error for list views.
public struct ErrorSummary: Sendable, Identifiable {
    public let id: ErrorRecordId
    public let fingerprint: String
    public let errorType: String
    public let message: String
    public let severity: AlertSeverity
    public let module: String
    public let occurrenceCount: Int
    public let lastSeenAt: Date
    public let state: ErrorState
    public let hasPragmaIssue: Bool

    public init(from error: ErrorRecordComponent) {
        self.id = error.id
        self.fingerprint = error.fingerprint
        self.errorType = error.errorType
        self.message = error.message
        self.severity = error.severity
        self.module = error.module
        self.occurrenceCount = error.occurrenceCount
        self.lastSeenAt = error.lastSeenAt
        self.state = error.state
        self.hasPragmaIssue = error.pragmaIssueId != nil
    }
}

// MARK: - Error Cluster

/// A cluster of related errors for aggregated reporting.
public struct ErrorCluster: Codable, Sendable, Identifiable {
    public let id: String  // fingerprint
    public var fingerprint: String
    public var representativeError: ErrorRecordComponent
    public var totalOccurrences: Int
    public var affectedPrincipals: Set<String>
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var isPromoted: Bool
    public var pragmaIssueId: String?

    public init(
        fingerprint: String,
        representativeError: ErrorRecordComponent,
        totalOccurrences: Int = 1,
        affectedPrincipals: Set<String> = [],
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        isPromoted: Bool = false,
        pragmaIssueId: String? = nil
    ) {
        self.id = fingerprint
        self.fingerprint = fingerprint
        self.representativeError = representativeError
        self.totalOccurrences = totalOccurrences
        self.affectedPrincipals = affectedPrincipals
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.isPromoted = isPromoted
        self.pragmaIssueId = pragmaIssueId
    }

    /// Adds an occurrence to this cluster.
    public mutating func addOccurrence(_ error: ErrorRecordComponent) {
        totalOccurrences += error.occurrenceCount
        if let principal = error.principalId {
            affectedPrincipals.insert(principal)
        }
        if error.firstSeenAt < firstSeenAt {
            firstSeenAt = error.firstSeenAt
        }
        if error.lastSeenAt > lastSeenAt {
            lastSeenAt = error.lastSeenAt
            representativeError = error
        }
    }
}
