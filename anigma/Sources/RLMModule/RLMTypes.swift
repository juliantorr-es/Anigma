import CryptoKit
import Foundation
import AnigmaCore

// MARK: - Span References

/// Reference to a content-addressed span within a source document.
///
/// Spans are the fundamental unit of context in the RLM environment.
/// Each span is content-addressed by hash and can be referenced
/// deterministically across operations.
public struct SpanRef: Sendable, Codable, Hashable {
    /// Content hash of the source document (SHA256)
    public let sourceHash: String
    
    /// Byte offset of the span within the source
    public let offset: UInt64
    
    /// Length of the span in bytes
    public let length: UInt64
    
    /// Optional stable ID for the span (e.g., chunk ID)
    public let stableId: String?
    
    /// Create a span reference.
    public init(
        sourceHash: String,
        offset: UInt64,
        length: UInt64,
        stableId: String? = nil
    ) {
        self.sourceHash = sourceHash
        self.offset = offset
        self.length = length
        self.stableId = stableId
    }
    
    /// Compute a stable reference ID for this span.
    public var referenceId: String {
        if let stableId = stableId {
            return stableId
        }
        return "\(sourceHash):\(offset):\(length)"
    }
}

/// Metadata for a source document in the context environment.
public struct SourceMetadata: Sendable, Codable {
    /// Unique identifier for the source
    public let sourceId: String
    
    /// Content hash (SHA256)
    public var contentHash: String
    
    /// MIME type or format
    public let mimeType: String
    
    /// Original filename or title
    public let title: String
    
    /// Size in bytes
    public let size: Int64
    
    /// When the source was added to the environment
    public let addedAt: Date
    
    /// Optional parent source ID for derived sources
    public let parentSourceId: String?
    
    /// Source-specific metadata as key-value pairs
    public let metadata: [String: String]
    
    public init(
        sourceId: String,
        contentHash: String,
        mimeType: String,
        title: String,
        size: Int64,
        addedAt: Date = Date(),
        parentSourceId: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.sourceId = sourceId
        self.contentHash = contentHash
        self.mimeType = mimeType
        self.title = title
        self.size = size
        self.addedAt = addedAt
        self.parentSourceId = parentSourceId
        self.metadata = metadata
    }
}

// MARK: - Governance Policy

/// Governance policy for RLM runtime loops.
public struct RLMGovernancePolicy: Sendable, Codable {
    /// Allowed tool operations
    public let allowedTools: Set<String>
    
    /// Maximum recursion depth for subtask decomposition
    public let maxRecursionDepth: Int
    
    /// Whether to require verification passes
    public let requireVerification: Bool
    
    /// Whether to allow parallel subtask execution
    public let allowParallelSubtasks: Bool
    
    /// Maximum number of subtasks that can be spawned in one decomposition
    public let maxSubtasksPerDecomposition: Int
    
    /// Tools considered "environment checks" that reset analysis timers
    public let environmentCheckTools: Set<String>
    
    /// High-impact operations requiring extra confirmation
    public let highImpactOperations: Set<String>
    
    /// Whether to enforce deterministic execution
    public let enforceDeterminism: Bool
    
    public init(
        allowedTools: Set<String> = Set(ToolOperation.allCases.map { $0.rawValue }),
        maxRecursionDepth: Int = 3,
        requireVerification: Bool = true,
        allowParallelSubtasks: Bool = true,
        maxSubtasksPerDecomposition: Int = 10,
        environmentCheckTools: Set<String> = ["peek", "search", "slice", "get_headings"],
        highImpactOperations: Set<String> = ["summarize", "spawn_subtask", "verify_claim"],
        enforceDeterminism: Bool = true
    ) {
        self.allowedTools = allowedTools
        self.maxRecursionDepth = maxRecursionDepth
        self.requireVerification = requireVerification
        self.allowParallelSubtasks = allowParallelSubtasks
        self.maxSubtasksPerDecomposition = maxSubtasksPerDecomposition
        self.environmentCheckTools = environmentCheckTools
        self.highImpactOperations = highImpactOperations
        self.enforceDeterminism = enforceDeterminism
    }
    
    /// Default policy for general use.
    public static let `default` = RLMGovernancePolicy()
    
    /// Strict policy for high-security or DSPS domains.
    public static let strict = RLMGovernancePolicy(
        maxRecursionDepth: 2,
        requireVerification: true,
        allowParallelSubtasks: false,
        maxSubtasksPerDecomposition: 5,
        enforceDeterminism: true
    )
    
    /// Relaxed policy for exploratory use.
    public static let relaxed = RLMGovernancePolicy(
        maxRecursionDepth: 5,
        requireVerification: false,
        allowParallelSubtasks: true,
        maxSubtasksPerDecomposition: 20,
        enforceDeterminism: false
    )
}

// MARK: - Resource Budgets

/// Resource budgets for RLM runtime loops.
public struct RLMResourceBudgets: Sendable, Codable {
    /// Maximum total tool calls allowed
    public let maxToolCalls: Int
    
    /// Maximum tokens for planner model
    public let plannerTokenBudget: Int
    
    /// Maximum tokens per worker model invocation
    public let workerTokenBudget: Int
    
    /// Maximum total execution time in seconds
    public let maxExecutionTime: TimeInterval
    
    /// Maximum bytes that can be retrieved in a single operation
    public let maxRetrievalBytes: Int
    
    /// Maximum number of spans that can be referenced
    public let maxSpanReferences: Int
    
    /// Maximum size of intermediate artifacts
    public let maxArtifactSize: Int
    
    public init(
        maxToolCalls: Int = 50,
        plannerTokenBudget: Int = 8000,
        workerTokenBudget: Int = 4000,
        maxExecutionTime: TimeInterval = 300, // 5 minutes
        maxRetrievalBytes: Int = 1_000_000, // 1 MB
        maxSpanReferences: Int = 100,
        maxArtifactSize: Int = 100_000 // 100 KB
    ) {
        self.maxToolCalls = maxToolCalls
        self.plannerTokenBudget = plannerTokenBudget
        self.workerTokenBudget = workerTokenBudget
        self.maxExecutionTime = maxExecutionTime
        self.maxRetrievalBytes = maxRetrievalBytes
        self.maxSpanReferences = maxSpanReferences
        self.maxArtifactSize = maxArtifactSize
    }
    
    /// Default budgets for general use.
    public static let `default` = RLMResourceBudgets()
    
    /// Conservative budgets for resource-constrained environments.
    public static let conservative = RLMResourceBudgets(
        maxToolCalls: 20,
        plannerTokenBudget: 4000,
        workerTokenBudget: 2000,
        maxExecutionTime: 120, // 2 minutes
        maxRetrievalBytes: 100_000, // 100 KB
        maxSpanReferences: 50,
        maxArtifactSize: 10_000 // 10 KB
    )
    
    /// Generous budgets for complex tasks.
    public static let generous = RLMResourceBudgets(
        maxToolCalls: 100,
        plannerTokenBudget: 16000,
        workerTokenBudget: 8000,
        maxExecutionTime: 600, // 10 minutes
        maxRetrievalBytes: 10_000_000, // 10 MB
        maxSpanReferences: 500,
        maxArtifactSize: 1_000_000 // 1 MB
    )
}

// MARK: - Tool Operations

/// Available tool operations in the RLM environment.
public enum ToolOperation: String, CaseIterable, Sendable, Codable {
    // Exploration operations
    case peek = "peek"
    case search = "search"
    case slice = "slice"
    case getHeadings = "get_headings"
    case listEntities = "list_entities"
    
    // Analysis operations
    case summarizeSpan = "summarize_span"
    case rankCandidates = "rank_candidates"
    case diffSpans = "diff_spans"
    
    // Verification operations
    case verifyClaim = "verify_claim"
    case checkConsistency = "check_consistency"
    
    // Task decomposition
    case spawnSubtask = "spawn_subtask"
    case getSubtaskResult = "get_subtask_result"
    
    // Synthesis operations
    case synthesizeArtifact = "synthesize_artifact"
    case generateProvenance = "generate_provenance"
    case generateCode = "generate_code"
}

/// Result of a tool operation.
public struct ToolResult: Sendable, Codable {
    /// Whether the operation succeeded
    public let success: Bool
    
    /// Operation output (JSON-serializable)
    public let output: [String: AnyCodable]
    
    /// Error message if operation failed
    public let errorMessage: String?
    
    /// Evidence hash for the operation
    public let evidenceHash: String
    
    /// Operation duration in seconds
    public let duration: TimeInterval
    
    /// Resources consumed by the operation
    public let resourcesConsumed: ToolResources
    
    public init(
        success: Bool,
        output: [String: AnyCodable] = [:],
        errorMessage: String? = nil,
        evidenceHash: String,
        duration: TimeInterval,
        resourcesConsumed: ToolResources
    ) {
        self.success = success
        self.output = output
        self.errorMessage = errorMessage
        self.evidenceHash = evidenceHash
        self.duration = duration
        self.resourcesConsumed = resourcesConsumed
    }
}

/// Resources consumed by a tool operation.
public struct ToolResources: Sendable, Codable {
    /// Tokens used
    public let tokensUsed: Int
    
    /// Tool calls made
    public let toolCalls: Int
    
    /// Bytes retrieved
    public let bytesRetrieved: Int
    
    /// Spans referenced
    public let spansReferenced: Int
    
    public init(
        tokensUsed: Int = 0,
        toolCalls: Int = 0,
        bytesRetrieved: Int = 0,
        spansReferenced: Int = 0
    ) {
        self.tokensUsed = tokensUsed
        self.toolCalls = toolCalls
        self.bytesRetrieved = bytesRetrieved
        self.spansReferenced = spansReferenced
    }
    
    /// Add resources together.
    public static func + (lhs: ToolResources, rhs: ToolResources) -> ToolResources {
        ToolResources(
            tokensUsed: lhs.tokensUsed + rhs.tokensUsed,
            toolCalls: lhs.toolCalls + rhs.toolCalls,
            bytesRetrieved: lhs.bytesRetrieved + rhs.bytesRetrieved,
            spansReferenced: lhs.spansReferenced + rhs.spansReferenced
        )
    }
}

// MARK: - Evidence and Artifacts

/// Evidence record for an RLM operation.
public struct EvidenceRecord: Sendable, Codable {
    /// Unique evidence ID
    public let evidenceId: String
    
    /// Operation that was performed
    public let operation: ToolOperation
    
    /// Input parameters (JSON-serializable)
    public let inputs: [String: AnyCodable]
    
    /// Output result
    public let result: ToolResult
    
    /// Timestamp of the operation
    public let timestamp: Date
    
    /// Parent evidence IDs (for chained operations)
    public let parentEvidenceIds: [String]
    
    /// Span references used in this operation
    public let spanRefs: [SpanRef]
    
    /// Content hash of the full evidence record
    public var contentHash: String
    
    public init(
        evidenceId: String = UUID().uuidString,
        operation: ToolOperation,
        inputs: [String: AnyCodable],
        result: ToolResult,
        timestamp: Date = Date(),
        parentEvidenceIds: [String] = [],
        spanRefs: [SpanRef] = []
    ) {
        self.evidenceId = evidenceId
        self.operation = operation
        self.inputs = inputs
        self.result = result
        self.timestamp = timestamp
        self.parentEvidenceIds = parentEvidenceIds
        self.spanRefs = spanRefs
        self.contentHash = "" // Temporary for encoding
        
        // Compute content hash
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(self)
        self.contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Artifact produced by an RLM runtime loop.
public struct RLMArtifact: Sendable, Codable {
    /// Unique artifact ID
    public let artifactId: String
    
    /// Type of artifact (summary, analysis, synthesis, etc.)
    public let artifactType: String
    
    /// Content of the artifact
    public let content: String
    
    /// Format of the content (markdown, json, etc.)
    public let format: String
    
    /// Evidence records that contributed to this artifact
    public let evidenceChain: [EvidenceRecord]
    
    /// Span references used in creating this artifact
    public let sourceSpans: [SpanRef]
    
    /// Content hash of the artifact
    public var contentHash: String
    
    /// When the artifact was created
    public let createdAt: Date
    
    public init(
        artifactId: String = UUID().uuidString,
        artifactType: String,
        content: String,
        format: String = "markdown",
        evidenceChain: [EvidenceRecord],
        sourceSpans: [SpanRef],
        createdAt: Date = Date()
    ) {
        self.artifactId = artifactId
        self.artifactType = artifactType
        self.content = content
        self.format = format
        self.evidenceChain = evidenceChain
        self.sourceSpans = sourceSpans
        self.createdAt = createdAt
        self.contentHash = "" // Temporary for encoding
        
        // Compute content hash
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(self)
        self.contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Helper Types

/// Type-erased codable value for JSON serialization.
/// See: Packages/AnigmaPrimitives/Sources/AnigmaPrimitives/AnyCodable.swift
import AnigmaPrimitives

public typealias AnyCodable = AnigmaPrimitives.AnyCodable

// MARK: - SHA256 Helper

private extension SHA256 {
    static func hash(data: Data) -> [UInt8] {
        var hasher = SHA256()
        hasher.update(data: data)
        let digest = hasher.finalize()
        return Array(digest)
    }
}
