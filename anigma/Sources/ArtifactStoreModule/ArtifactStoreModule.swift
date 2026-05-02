import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import DatabaseCore

/// Governed artifact storage with content-addressable semantics and full provenance
/// Implements court-safe artifact lifecycle: commit, retrieve, verify, retention
public actor ArtifactStoreModule {
    private let database: ArtifactStoreDatabase
    private let storageRoot: URL
    private let artifactAuthority: any ArtifactAuthority
    private let eventSink: ((ArtifactStoreEvent) -> Void)?
    private let systemContext: ExecutionContext

    public init(
        artifactAuthority: any ArtifactAuthority,
        storageRoot: URL,
        database: ArtifactStoreDatabase,
        eventSink: ((ArtifactStoreEvent) -> Void)? = nil
    ) {
        self.artifactAuthority = artifactAuthority
        self.storageRoot = storageRoot
        self.database = database
        self.eventSink = eventSink
        self.systemContext = ExecutionContext(principal: .system)
    }

    // MARK: - Artifact Commit

    /// Store artifact bytes with full provenance
    /// Returns commit receipt with artifact ID and content hash
    public func commit(
        content: Data,
        mediaType: String,
        source: ArtifactSource,
        metadata: [String: String] = [:],
        receiptID: String,
        evidenceHeadHash: String?
    ) async throws -> ArtifactCommitReceipt {
        let contentHash = computeSHA256(content)
        let artifactID = UUID().uuidString

        // Store artifact via ArtifactAuthority
        let artifact = Artifact(
            id: ArtifactID(hash: contentHash),
            mimeType: mediaType,
            size: Int64(content.count),
            createdAt: Date(),
            tags: [],
            metadata: metadata,
            content: content
        )
        
        _ = try await artifactAuthority.store(
            artifact,
            context: systemContext
        )
        
        // Store artifact metadata
        let storedArtifact = StoredArtifact(
            artifactID: artifactID,
            contentHash: contentHash,
            sourceHash: computeSourceHash(source),
            mediaType: mediaType,
            sizeBytes: Int64(content.count),
            source: source,
            metadata: metadata,
            receiptID: receiptID,
            evidenceHeadHash: evidenceHeadHash,
            committedAt: Date(),
            trustTier: .standard
        )

        try await database.insertArtifact(storedArtifact)

        // Emit commit event
        let event = ArtifactStoreEvent.committed(
            artifactID: artifactID,
            contentHash: contentHash,
            mediaType: mediaType,
            receiptID: receiptID
        )
        eventSink?(event)

        return ArtifactCommitReceipt(
            artifactID: artifactID,
            contentHash: contentHash,
            sizeBytes: Int64(content.count),
            committedAt: storedArtifact.committedAt
        )
    }

    // MARK: - Artifact Retrieval

    /// Retrieve artifact content by ID with integrity verification
    public func retrieve(artifactID: String) async throws -> RetrievedArtifact {
        guard let artifact = try await database.fetchArtifact(artifactID: artifactID) else {
            throw ArtifactStoreError.notFound(artifactID)
        }

        // Retrieve artifact via ArtifactAuthority
        let artifactIDObj = ArtifactID(hash: artifact.contentHash)
        let retrievedArtifact = try await artifactAuthority.retrieve(
            artifactIDObj,
            principal: .system
        )
        
        guard let content = retrievedArtifact.content else {
            throw ArtifactStoreError.storageCorruption(artifactID, artifact.contentHash)
        }
        
        // Verify integrity (authority should guarantee, but we double-check)
        let actualHash = computeSHA256(content)
        guard actualHash == artifact.contentHash else {
            throw ArtifactStoreError.integrityViolation(
                artifactID,
                expected: artifact.contentHash,
                actual: actualHash
            )
        }

        return RetrievedArtifact(
            artifact: artifact,
            content: content
        )
    }

    /// Retrieve artifact by content hash
    public func retrieveByHash(contentHash: String) async throws -> RetrievedArtifact {
        guard let artifact = try await database.fetchArtifactByHash(contentHash: contentHash) else {
            throw ArtifactStoreError.hashNotFound(contentHash)
        }

        return try await retrieve(artifactID: artifact.artifactID)
    }

    // MARK: - Artifact Verification

    /// Verify artifact integrity without retrieving full content
    public func verify(artifactID: String) async throws -> VerificationResult {
        guard let artifact = try await database.fetchArtifact(artifactID: artifactID) else {
            throw ArtifactStoreError.notFound(artifactID)
        }

        do {
            let artifactIDObj = ArtifactID(hash: artifact.contentHash)
            let retrievedArtifact = try await artifactAuthority.retrieve(
                artifactIDObj,
                principal: .system
            )
            
            guard let content = retrievedArtifact.content else {
                return VerificationResult(
                    artifactID: artifactID,
                    status: .unreadable,
                    expectedHash: artifact.contentHash,
                    actualHash: nil
                )
            }
            
            let actualHash = computeSHA256(content)
            let status: VerificationStatus = actualHash == artifact.contentHash ? .valid : .corrupted
            
            return VerificationResult(
                artifactID: artifactID,
                status: status,
                expectedHash: artifact.contentHash,
                actualHash: actualHash
            )
        } catch {
            // For now, treat any error as file being unreadable/missing
            // TODO: Distinguish between not found vs access denied when GenericCoreError visibility is fixed
            return VerificationResult(
                artifactID: artifactID,
                status: .missing,
                expectedHash: artifact.contentHash,
                actualHash: nil
            )
        }
    }

    // MARK: - Query

    /// List artifacts with optional filters
    public func listArtifacts(
        mediaType: String? = nil,
        trustTier: TrustTier? = nil,
        limit: Int = 100
    ) async throws -> [StoredArtifact] {
        return try await database.listArtifacts(
            mediaType: mediaType,
            trustTier: trustTier,
            limit: limit
        )
    }

    // MARK: - Helpers

    private func computeSHA256(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func computeSourceHash(_ source: ArtifactSource) -> String {
        let sourceDesc = "\(source.type):\(source.identifier)"
        return computeSHA256(sourceDesc.data(using: .utf8)!)
    }
}

extension ArtifactStoreModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        let databaseAuthority = await runtime.database
        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
        _ = try await ArtifactStoreDatabase(dbActor: databaseAdapter as! DatabaseCore.DatabaseExecutor)
    }
}

// MARK: - Event Types

public enum ArtifactStoreEvent: Codable, Sendable {
    case committed(artifactID: String, contentHash: String, mediaType: String, receiptID: String)
    case verified(artifactID: String, status: VerificationStatus)
    case retained(artifactID: String, retentionPolicyID: String)
    case redacted(artifactID: String, redactionPolicyID: String)
}

// MARK: - Data Types

public struct StoredArtifact: Codable, Sendable {
    public let artifactID: String
    public let contentHash: String
    public let sourceHash: String
    public let mediaType: String
    public let sizeBytes: Int64
    public let source: ArtifactSource
    public let metadata: [String: String]
    public let receiptID: String
    public let evidenceHeadHash: String?
    public let committedAt: Date
    public let trustTier: TrustTier
}

public struct ArtifactSource: Codable, Sendable {
    public let type: String // "user_upload", "ml_output", "conversion", "import"
    public let identifier: String // repo URL, model ID, etc.

    public init(type: String, identifier: String) {
        self.type = type
        self.identifier = identifier
    }
}

public struct ArtifactCommitReceipt: Codable, Sendable {
    public let artifactID: String
    public let contentHash: String
    public let sizeBytes: Int64
    public let committedAt: Date
}

public struct RetrievedArtifact: Sendable {
    public let artifact: StoredArtifact
    public let content: Data
}

public struct VerificationResult: Codable, Sendable {
    public let artifactID: String
    public let status: VerificationStatus
    public let expectedHash: String
    public let actualHash: String?
}

public enum VerificationStatus: String, Codable, Sendable {
    case valid
    case corrupted
    case missing
    case unreadable
}

public enum TrustTier: String, Codable, Sendable {
    case standard
    case sensitive
    case restricted
    case experimental
}

// MARK: - Errors

public enum ArtifactStoreError: Error, CustomStringConvertible {
    case notFound(String)
    case hashNotFound(String)
    case storageCorruption(String, String)
    case integrityViolation(String, expected: String, actual: String)
    case parseError(String)

    public var description: String {
        switch self {
        case .notFound(let id):
            return "Artifact not found: \(id)"
        case .hashNotFound(let hash):
            return "No artifact with hash: \(hash)"
        case .storageCorruption(let id, let hash):
            return "Storage file missing for artifact \(id) hash \(hash)"
        case .integrityViolation(let id, let expected, let actual):
            return "Integrity violation for \(id): expected \(expected), got \(actual)"
        case .parseError(let msg):
            return "Parse error: \(msg)"
        }
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
