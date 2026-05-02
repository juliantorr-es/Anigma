import Foundation

/// Component tracking retention policy rules
public struct RetentionPolicyComponent: Codable, Sendable, Hashable {
    public let policyID: String
    public let cutoffDays: Int
    public let targetTypes: Set<String>
    public let trustTierRequired: String?
    public let createdAt: Date

    public init(
        policyID: String,
        cutoffDays: Int,
        targetTypes: Set<String>,
        trustTierRequired: String? = nil,
        createdAt: Date = Date()
    ) {
        self.policyID = policyID
        self.cutoffDays = cutoffDays
        self.targetTypes = targetTypes
        self.trustTierRequired = trustTierRequired
        self.createdAt = createdAt
    }
}

/// Component tracking redaction rules
public struct RedactionRuleComponent: Codable, Sendable, Hashable {
    public let ruleID: String
    public let pattern: String
    public let replacement: String
    public let targetFields: Set<String>
    public let isReversible: Bool
    public let encryptionKeyID: String?
    public let createdAt: Date

    public init(
        ruleID: String,
        pattern: String,
        replacement: String,
        targetFields: Set<String>,
        isReversible: Bool = false,
        encryptionKeyID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.ruleID = ruleID
        self.pattern = pattern
        self.replacement = replacement
        self.targetFields = targetFields
        self.isReversible = isReversible
        self.encryptionKeyID = encryptionKeyID
        self.createdAt = createdAt
    }
}

/// Component tracking deletion manifest entries
public struct DeletionManifestComponent: Codable, Sendable, Hashable {
    public let manifestID: String
    public let policyID: String
    public let targetHash: String
    public let targetType: String
    public let deletedAt: Date
    public let receiptID: String

    public init(
        manifestID: String,
        policyID: String,
        targetHash: String,
        targetType: String,
        deletedAt: Date,
        receiptID: String
    ) {
        self.manifestID = manifestID
        self.policyID = policyID
        self.targetHash = targetHash
        self.targetType = targetType
        self.deletedAt = deletedAt
        self.receiptID = receiptID
    }
}

/// Component tracking redaction manifest entries
public struct RedactionManifestComponent: Codable, Sendable, Hashable {
    public let manifestID: String
    public let rulesetHash: String
    public let targetHash: String
    public let originalContentHash: String
    public let redactedContentHash: String
    public let redactedAt: Date
    public let receiptID: String
    public let isReversible: Bool

    public init(
        manifestID: String,
        rulesetHash: String,
        targetHash: String,
        originalContentHash: String,
        redactedContentHash: String,
        redactedAt: Date,
        receiptID: String,
        isReversible: Bool
    ) {
        self.manifestID = manifestID
        self.rulesetHash = rulesetHash
        self.targetHash = targetHash
        self.originalContentHash = originalContentHash
        self.redactedContentHash = redactedContentHash
        self.redactedAt = redactedAt
        self.receiptID = receiptID
        self.isReversible = isReversible
    }
}

/// Component tracking compaction runs
public struct CompactionRunComponent: Codable, Sendable, Hashable {
    public let runID: String
    public let startedAt: Date
    public let completedAt: Date?
    public let segmentsProcessed: Int
    public let bytesReclaimed: Int64
    public let receiptID: String?

    public init(
        runID: String,
        startedAt: Date,
        completedAt: Date? = nil,
        segmentsProcessed: Int = 0,
        bytesReclaimed: Int64 = 0,
        receiptID: String? = nil
    ) {
        self.runID = runID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.segmentsProcessed = segmentsProcessed
        self.bytesReclaimed = bytesReclaimed
        self.receiptID = receiptID
    }
}
