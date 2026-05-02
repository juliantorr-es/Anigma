import AnigmaPrimitives

import AnigmaPrimitives

//
//  SharedComponents.swift
//  AnigmaCore
//
//  Generic, reusable components shared across all domain modules.
//  These components are domain-agnostic and can be used by any module.
//
//  Domain-specific components (DocumentComponent, ZineComponent, etc.)
//  should be defined in their respective modules, not here.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation

// MARK: - File Component

/// References a file or resource by path, URL, or logical identifier.
/// Used by any entity that needs to track associated files.
///
/// ## Usage
/// ```swift
/// let file = FileComponent(path: "/path/to/document.pdf")
/// world.addComponent(entity, file)
/// ```
public struct FileComponent: Component, Codable {
    /// Local file path (if applicable).
    public var path: String?

    /// URL (local file:// or remote http://).
    public var url: URL?

    /// Logical resource identifier (for abstract resources).
    public var resourceId: String?

    /// MIME type of the file.
    public var mimeType: String?

    /// File size in bytes (if known).
    public var sizeBytes: Int64?

    /// SHA-256 hash of file contents (for integrity checking).
    public var contentHash: String?

    /// When the file was last modified.
    public var modifiedAt: Date?

    public init(
        path: String? = nil,
        url: URL? = nil,
        resourceId: String? = nil,
        mimeType: String? = nil,
        sizeBytes: Int64? = nil,
        contentHash: String? = nil,
        modifiedAt: Date? = nil
    ) {
        self.path = path
        self.url = url
        self.resourceId = resourceId
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.contentHash = contentHash
        self.modifiedAt = modifiedAt
    }

    /// Convenience initializer for local files.
    public init(path: String) {
        self.path = path
        self.url = URL(fileURLWithPath: path)
    }

    /// Convenience initializer for URLs.
    public init(url: URL) {
        self.url = url
        if url.isFileURL {
            self.path = url.path
        }
    }

    /// The display name (filename) of the file.
    public var displayName: String? {
        if let path = path {
            return (path as NSString).lastPathComponent
        }
        return url?.lastPathComponent
    }

    /// The file extension.
    public var fileExtension: String? {
        if let path = path {
            let ext = (path as NSString).pathExtension
            return ext.isEmpty ? nil : ext
        }
        return url?.pathExtension
    }
}

// MARK: - QA Component

/// Quality assurance scores and flags.
/// Used to track quality metrics for any entity that undergoes QA checks.
///
/// ## Usage
/// ```swift
/// var qa = QAComponent()
/// qa.overallScore = 0.95
/// qa.flags["needs_review"] = true
/// qa.scores["accuracy"] = 0.98
/// ```
public struct QAComponent: Component, Codable {
    /// Overall quality score (0.0 to 1.0).
    public var overallScore: Double?

    /// Individual quality scores by category.
    public var scores: [String: Double]

    /// Quality flags (e.g., "needs_review", "auto_approved").
    public var flags: [String: Bool]

    /// Human-readable notes about quality issues.
    public var notes: [String]

    /// When QA was last performed.
    public var checkedAt: Date?

    /// Who/what performed the QA check.
    public var checkedBy: String?

    public init(
        overallScore: Double? = nil,
        scores: [String: Double] = [:],
        flags: [String: Bool] = [:],
        notes: [String] = [],
        checkedAt: Date? = nil,
        checkedBy: String? = nil
    ) {
        self.overallScore = overallScore
        self.scores = scores
        self.flags = flags
        self.notes = notes
        self.checkedAt = checkedAt
        self.checkedBy = checkedBy
    }

    /// Whether the entity passes QA (score above threshold).
    public func passes(threshold: Double = 0.8) -> Bool {
        guard let score = overallScore else { return false }
        return score >= threshold
    }

    /// Whether the entity needs manual review.
    public var needsReview: Bool {
        flags["needs_review"] ?? false
    }
}

// MARK: - Metadata Component

/// Generic key-value metadata for any entity.
/// Use for flexible, schema-less metadata that doesn't fit other components.
///
/// ## Usage
/// ```swift
/// var meta = MetadataComponent()
/// meta.values["author"] = "Jane Doe"
/// meta.values["version"] = "1.0"
/// meta.tags = ["important", "reviewed"]
/// ```
public struct MetadataComponent: Component, Codable {
    /// Key-value pairs for arbitrary metadata.
    public var values: [String: String]

    /// Tags for categorization and filtering.
    public var tags: Set<String>

    /// Optional human-readable label.
    public var label: String?

    /// Optional description.
    public var description: String?

    /// When this metadata was last updated.
    public var updatedAt: Date

    public init(
        values: [String: String] = [:],
        tags: Set<String> = [],
        label: String? = nil,
        description: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.values = values
        self.tags = tags
        self.label = label
        self.description = description
        self.updatedAt = updatedAt
    }

    /// Gets a metadata value, with optional type conversion.
    public func get(_ key: String) -> String? {
        values[key]
    }

    /// Gets a metadata value as Int.
    public func getInt(_ key: String) -> Int? {
        values[key].flatMap { Int($0) }
    }

    /// Gets a metadata value as Double.
    public func getDouble(_ key: String) -> Double? {
        values[key].flatMap { Double($0) }
    }

    /// Gets a metadata value as Bool.
    public func getBool(_ key: String) -> Bool? {
        guard let value = values[key]?.lowercased() else { return nil }
        switch value {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }

    /// Checks if a tag is present.
    public func hasTag(_ tag: String) -> Bool {
        tags.contains(tag)
    }
}

// MARK: - Job Component

/// Attaches a job reference to an entity.
/// Used to track which entities are involved in which jobs.
///
/// ## Usage
/// ```swift
/// let jobComp = JobComponent(jobId: job.id, role: .input)
/// world.addComponent(documentEntity, jobComp)
/// ```
public struct JobComponent: Component, Codable {
    /// The job ID this entity is associated with.
    public let jobId: JobId

    /// The role this entity plays in the job.
    public var role: JobRole

    /// Current status (mirrors job status for quick access).
    public var status: AnigmaFoundation.JobStatus

    /// When this association was created.
    public let associatedAt: Date

    /// Optional notes about this entity's role.
    public var notes: String?

    public init(
        jobId: JobId,
        role: JobRole = .input,
        status: AnigmaFoundation.JobStatus = .pending,
        associatedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.jobId = jobId
        self.role = role
        self.status = status
        self.associatedAt = associatedAt
        self.notes = notes
    }
}

/// The role an entity plays in a job.
public enum JobRole: String, Codable, Sendable {
    /// Entity is an input to the job.
    case input

    /// Entity is an output produced by the job.
    case output

    /// Entity is both input and output (modified in place).
    case inOut

    /// Entity is referenced but not modified.
    case reference
}

// MARK: - Name Component

/// Human-readable name for an entity.
/// Use for entities that need display names or identifiers.
public struct NameComponent: Component, Codable {
    /// Internal/technical name.
    public let name: String

    /// User-facing display name.
    public var displayName: String?

    public init(name: String, displayName: String? = nil) {
        self.name = name
        self.displayName = displayName
    }

    /// Returns displayName if set, otherwise name.
    public var label: String {
        displayName ?? name
    }
}

// MARK: - Timestamp Component

/// Tracks creation and modification times.
public struct TimestampComponent: Component, Codable {
    /// When the entity was created.
    public let createdAt: Date

    /// When the entity was last modified.
    public var modifiedAt: Date

    public init(createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Age since creation.
    public var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }

    /// Time since last modification.
    public var timeSinceModification: TimeInterval {
        Date().timeIntervalSince(modifiedAt)
    }

    /// Returns a copy with updated modifiedAt timestamp.
    public func touch() -> TimestampComponent {
        TimestampComponent(createdAt: createdAt, modifiedAt: Date())
    }
}

// MARK: - Tag Component

/// Simple tags for filtering and categorization.
/// Lighter-weight than MetadataComponent when you only need tags.
public struct TagComponent: Component, Codable {
    /// The set of tags.
    public var tags: Set<String>

    public init(_ tags: String...) {
        self.tags = Set(tags)
    }

    public init(_ tags: Set<String>) {
        self.tags = tags
    }

    public init(_ tags: [String]) {
        self.tags = Set(tags)
    }

    public func hasTag(_ tag: String) -> Bool {
        tags.contains(tag)
    }

    public func hasAnyTag(_ checkTags: [String]) -> Bool {
        !tags.isDisjoint(with: checkTags)
    }

    public func hasAllTags(_ checkTags: [String]) -> Bool {
        Set(checkTags).isSubset(of: tags)
    }
}

// MARK: - Status Component

/// Generic status tracking for entities.
/// Use for entities with simple state machines.
public struct StatusComponent: Component, Codable {
    /// Current status string.
    public var status: String

    /// Previous status (for history/rollback).
    public var previousStatus: String?

    /// When the status was last changed.
    public var changedAt: Date

    /// Reason for the current status.
    public var reason: String?

    public init(
        status: String,
        previousStatus: String? = nil,
        changedAt: Date = Date(),
        reason: String? = nil
    ) {
        self.status = status
        self.previousStatus = previousStatus
        self.changedAt = changedAt
        self.reason = reason
    }

    /// Transitions to a new status.
    public mutating func transition(to newStatus: String, reason: String? = nil) {
        self.previousStatus = self.status
        self.status = newStatus
        self.changedAt = Date()
        self.reason = reason
    }
}
