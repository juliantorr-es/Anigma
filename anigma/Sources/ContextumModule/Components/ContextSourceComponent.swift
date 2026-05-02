import Foundation

public struct ContextSourceComponent: Codable, Hashable, Sendable {
    public let sourceId: String
    public let sourceType: SourceType
    public let artifactHash: String
    public let receiptId: String
    public let timestamp: Date
    public let metadata: [String: String]
    public let uri: String?
    public let canonicalRef: String?
    public let canonicalEntityId: String?
    public let currentHash: String
    public let revision: Int
    public let mimeType: String?
    public let discoveredAt: Date
    public let lastSeenAt: Date
    public let staleAt: Date?
    public let supersedesSourceId: String?
    public let supersededBySourceId: String?
    public let supersessionRootSourceId: String?
    public let supersessionDepth: Int
    public let conflictStatus: ConflictStatus
    public let reingestionPolicy: ReingestionPolicy
    public let confidenceScore: Double
    public let ingestReceiptId: String?
    public let content: String?

    public enum SourceType: String, Codable, Sendable {
        case document
        case conversation
        case toolOutput
        case codebase
        case userInput
    }

    public enum ConflictStatus: String, Codable, Sendable {
        case none
        case unresolved
        case resolved
    }

    public enum ReingestionPolicy: String, Codable, Sendable {
        case onHashChange
        case periodic
        case manual
        case always
    }

    public init(
        sourceId: String,
        sourceType: SourceType,
        artifactHash: String,
        receiptId: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:],
        uri: String? = nil,
        canonicalRef: String? = nil,
        canonicalEntityId: String? = nil,
        currentHash: String? = nil,
        revision: Int = 1,
        mimeType: String? = nil,
        discoveredAt: Date? = nil,
        lastSeenAt: Date? = nil,
        staleAt: Date? = nil,
        supersedesSourceId: String? = nil,
        supersededBySourceId: String? = nil,
        supersessionRootSourceId: String? = nil,
        supersessionDepth: Int = 0,
        conflictStatus: ConflictStatus? = nil,
        reingestionPolicy: ReingestionPolicy? = nil,
        confidenceScore: Double = 1.0,
        ingestReceiptId: String? = nil,
        content: String? = nil
    ) {
        let resolvedUri = uri ?? metadata["uri"]
        let resolvedCanonicalRef = canonicalRef ?? metadata["canonicalRef"] ?? resolvedUri ?? artifactHash
        let resolvedCanonicalEntityId = canonicalEntityId ?? metadata["canonicalEntityId"]
        let resolvedCurrentHash = currentHash ?? metadata["currentHash"] ?? artifactHash
        let resolvedMimeType = mimeType ?? metadata["mimeType"]
        let resolvedDiscoveredAt = discoveredAt ?? timestamp
        let resolvedLastSeenAt = max(lastSeenAt ?? timestamp, resolvedDiscoveredAt)
        let resolvedStaleAt = staleAt.map { max($0, resolvedLastSeenAt) }
        let resolvedIngestReceiptId = ingestReceiptId ?? metadata["ingestReceiptId"] ?? receiptId
        let resolvedRevision = max(revision, 1)
        let resolvedSupersedesSourceId = supersedesSourceId ?? metadata["supersedesSourceId"]
        let resolvedSupersededBySourceId = supersededBySourceId ?? metadata["supersededBySourceId"]
        let resolvedSupersessionRootSourceId = supersessionRootSourceId ?? metadata["supersessionRootSourceId"]
        let resolvedSupersessionDepth = max(
            supersessionDepth,
            Int(metadata["supersessionDepth"] ?? "") ?? 0
        )
        let resolvedConflictStatus = conflictStatus
            ?? metadata["conflictStatus"].flatMap(ConflictStatus.init(rawValue:))
            ?? .none
        let resolvedReingestionPolicy = reingestionPolicy
            ?? metadata["reingestionPolicy"].flatMap(ReingestionPolicy.init(rawValue:))
            ?? .onHashChange

        self.sourceId = sourceId
        self.sourceType = sourceType
        self.artifactHash = artifactHash
        self.receiptId = receiptId
        self.timestamp = timestamp
        self.metadata = metadata
        self.uri = resolvedUri
        self.canonicalRef = resolvedCanonicalRef
        self.canonicalEntityId = resolvedCanonicalEntityId
        self.currentHash = resolvedCurrentHash
        self.revision = resolvedRevision
        self.mimeType = resolvedMimeType
        self.discoveredAt = resolvedDiscoveredAt
        self.lastSeenAt = resolvedLastSeenAt
        self.staleAt = resolvedStaleAt
        self.supersedesSourceId = resolvedSupersedesSourceId
        self.supersededBySourceId = resolvedSupersededBySourceId
        self.supersessionRootSourceId = resolvedSupersessionRootSourceId
        self.supersessionDepth = resolvedSupersessionDepth
        self.conflictStatus = resolvedConflictStatus
        self.reingestionPolicy = resolvedReingestionPolicy
        self.confidenceScore = confidenceScore
        self.ingestReceiptId = resolvedIngestReceiptId
        self.content = content
    }
}
