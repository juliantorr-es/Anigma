import Foundation
import AnigmaPrimitives
import CapabilityCore

/// Capability for Runtime Loop Manager (RLM) operations.
///
/// Provides governed access to context environment operations with
/// evidence recording and capsule acceleration.
public protocol RLMCapability: Capability {
    
    // MARK: - Environment Exploration
    
    /// Get metadata about sources in the environment.
    /// - Parameter sourceHashes: Optional list of source hashes to peek at.
    /// - Returns: Array of source metadata.
    func peek(sourceHashes: [String]) async throws -> [SourceMetadata]
    
    /// Search for spans matching a query using hybrid search.
    /// - Parameters:
    ///   - query: Search query text.
    ///   - sourceHashes: Optional list of source hashes to search within.
    ///   - limit: Maximum number of results.
    ///   - minScore: Minimum similarity score.
    /// - Returns: Array of span references with relevance scores.
    func search(
        query: String,
        sourceHashes: [String],
        limit: Int,
        minScore: Double
    ) async throws -> [(spanRef: SpanRef, score: Double)]
    
    /// Retrieve content for specific spans.
    /// - Parameter spanRefs: Array of span references to retrieve.
    /// - Returns: Dictionary mapping span reference IDs to content strings.
    func slice(spanRefs: [SpanRef]) async throws -> [String: String]
    
    /// Extract hierarchical headings/structure from a source.
    /// - Parameter sourceHash: Content hash of the source.
    /// - Returns: Array of headings with level, text, and span reference.
    func getHeadings(sourceHash: String) async throws -> [(level: Int, text: String, spanRef: SpanRef)]
    
    // MARK: - Analysis Operations
    
    /// Generate a summary of a span.
    /// - Parameters:
    ///   - spanRef: Span to summarize.
    ///   - maxLength: Maximum summary length in tokens.
    ///   - style: Summary style.
    /// - Returns: Summary text.
    func summarizeSpan(
        spanRef: SpanRef,
        maxLength: Int,
        style: String
    ) async throws -> String
    
    /// Rank candidate spans by relevance to a query.
    /// - Parameters:
    ///   - query: Query text.
    ///   - candidates: Candidate span references.
    ///   - rankingMethod: Ranking method.
    /// - Returns: Ranked candidates with scores.
    func rankCandidates(
        query: String,
        candidates: [SpanRef],
        rankingMethod: String
    ) async throws -> [(spanRef: SpanRef, score: Double)]
    
    /// Compare two spans and highlight differences.
    /// - Parameters:
    ///   - spanRefA: First span.
    ///   - spanRefB: Second span.
    ///   - diffType: Type of diff.
    /// - Returns: Diff analysis.
    func diffSpans(
        spanRefA: SpanRef,
        spanRefB: SpanRef,
        diffType: String
    ) async throws -> [String: Any]
    
    // MARK: - Verification Operations
    
    /// Verify a claim against evidence in the environment.
    /// - Parameters:
    ///   - claim: Claim to verify.
    ///   - evidenceSpans: Optional specific spans to use as evidence.
    ///   - verificationMethod: Verification method.
    /// - Returns: Verification result.
    func verifyClaim(
        claim: String,
        evidenceSpans: [SpanRef],
        verificationMethod: String
    ) async throws -> [String: Any]
    
    /// Check consistency between multiple items.
    /// - Parameters:
    ///   - items: Spans or claims to check.
    ///   - consistencyType: Type of consistency check.
    /// - Returns: Consistency analysis.
    func checkConsistency(
        items: [Any],
        consistencyType: String
    ) async throws -> [String: Any]
    
    // MARK: - Task Decomposition
    
    /// Spawn a subtask for decomposition via Harmonia workflow engine.
    /// - Parameters:
    ///   - taskDescription: Description of the subtask.
    ///   - parentSpanRefs: Spans from parent task context.
    ///   - subtaskType: Type of subtask.
    /// - Returns: Subtask ID.
    func spawnSubtask(
        taskDescription: String,
        parentSpanRefs: [SpanRef],
        subtaskType: String
    ) async throws -> String
    
    /// Get result of a spawned subtask.
    /// - Parameter subtaskId: ID returned by spawnSubtask.
    /// - Returns: Subtask result.
    func getSubtaskResult(subtaskId: String) async throws -> [String: Any]
    
    // MARK: - Synthesis Operations
    
    /// Synthesize an artifact from multiple spans.
    /// - Parameters:
    ///   - spanRefs: Spans to synthesize from.
    ///   - synthesisType: Type of synthesis.
    ///   - format: Output format.
    /// - Returns: Synthesized artifact.
    func synthesizeArtifact(
        spanRefs: [SpanRef],
        synthesisType: String,
        format: String
    ) async throws -> String
    
    /// Generate provenance chain for items.
    /// - Parameter itemRefs: Span references or artifact IDs.
    /// - Returns: Provenance chain.
    func generateProvenance(itemRefs: [String]) async throws -> [String: Any]
}

extension RLMCapability {
    public static var capabilityId: String { CapabilityIds.rlm }
}

// MARK: - Capability ID Extension

public extension CapabilityIds {
    static let rlm = "anigma.capability.rlm"
}

// MARK: - Default Parameter Values

extension RLMCapability {
    
    public func peek(sourceHashes: [String] = []) async throws -> [SourceMetadata] {
        try await peek(sourceHashes: sourceHashes)
    }
    
    public func search(
        query: String,
        sourceHashes: [String] = [],
        limit: Int = 20,
        minScore: Double = 0.0
    ) async throws -> [(spanRef: SpanRef, score: Double)] {
        try await search(
            query: query,
            sourceHashes: sourceHashes,
            limit: limit,
            minScore: minScore
        )
    }
    
    public func slice(spanRefs: [SpanRef]) async throws -> [String: String] {
        try await slice(spanRefs: spanRefs)
    }
    
    public func getHeadings(sourceHash: String) async throws -> [(level: Int, text: String, spanRef: SpanRef)] {
        try await getHeadings(sourceHash: sourceHash)
    }
    
    public func summarizeSpan(
        spanRef: SpanRef,
        maxLength: Int = 200,
        style: String = "concise"
    ) async throws -> String {
        try await summarizeSpan(
            spanRef: spanRef,
            maxLength: maxLength,
            style: style
        )
    }
    
    public func rankCandidates(
        query: String,
        candidates: [SpanRef],
        rankingMethod: String = "hybrid"
    ) async throws -> [(spanRef: SpanRef, score: Double)] {
        try await rankCandidates(
            query: query,
            candidates: candidates,
            rankingMethod: rankingMethod
        )
    }
    
    public func diffSpans(
        spanRefA: SpanRef,
        spanRefB: SpanRef,
        diffType: String = "word"
    ) async throws -> [String: Any] {
        try await diffSpans(
            spanRefA: spanRefA,
            spanRefB: spanRefB,
            diffType: diffType
        )
    }
    
    public func verifyClaim(
        claim: String,
        evidenceSpans: [SpanRef] = [],
        verificationMethod: String = "consistency"
    ) async throws -> [String: Any] {
        try await verifyClaim(
            claim: claim,
            evidenceSpans: evidenceSpans,
            verificationMethod: verificationMethod
        )
    }
    
    public func checkConsistency(
        items: [Any],
        consistencyType: String = "factual"
    ) async throws -> [String: Any] {
        try await checkConsistency(
            items: items,
            consistencyType: consistencyType
        )
    }
    
    public func spawnSubtask(
        taskDescription: String,
        parentSpanRefs: [SpanRef] = [],
        subtaskType: String = "analysis"
    ) async throws -> String {
        try await spawnSubtask(
            taskDescription: taskDescription,
            parentSpanRefs: parentSpanRefs,
            subtaskType: subtaskType
        )
    }
    
    public func synthesizeArtifact(
        spanRefs: [SpanRef],
        synthesisType: String = "summary",
        format: String = "markdown"
    ) async throws -> String {
        try await synthesizeArtifact(
            spanRefs: spanRefs,
            synthesisType: synthesisType,
            format: format
        )
    }
    
    public func generateProvenance(itemRefs: [String]) async throws -> [String: Any] {
        try await generateProvenance(itemRefs: itemRefs)
    }
}