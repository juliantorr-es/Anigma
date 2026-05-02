import Foundation
import AnigmaPrimitives
import CapabilityCore

/// Implementation of RLMCapability that wraps ContextEnvironment.
public actor RLMCapabilityImpl: RLMCapability {
    
    private let environment: ContextEnvironment
    
    public init(environment: ContextEnvironment) {
        self.environment = environment
    }
    
    // MARK: - Environment Exploration
    
    public func peek(sourceHashes: [String]) async throws -> [SourceMetadata] {
        try await environment.peek(sourceHashes: sourceHashes)
    }
    
    public func search(
        query: String,
        sourceHashes: [String],
        limit: Int,
        minScore: Double
    ) async throws -> [(spanRef: SpanRef, score: Double)] {
        try await environment.search(
            query: query,
            sourceHashes: sourceHashes,
            limit: limit,
            minScore: minScore
        )
    }
    
    public func slice(spanRefs: [SpanRef]) async throws -> [String: String] {
        try await environment.slice(spanRefs: spanRefs)
    }
    
    public func getHeadings(sourceHash: String) async throws -> [(level: Int, text: String, spanRef: SpanRef)] {
        try await environment.getHeadings(sourceHash: sourceHash)
    }
    
    // MARK: - Analysis Operations
    
    public func summarizeSpan(
        spanRef: SpanRef,
        maxLength: Int,
        style: String
    ) async throws -> String {
        try await environment.summarizeSpan(
            spanRef: spanRef,
            maxLength: maxLength,
            style: style
        )
    }
    
    public func rankCandidates(
        query: String,
        candidates: [SpanRef],
        rankingMethod: String
    ) async throws -> [(spanRef: SpanRef, score: Double)] {
        try await environment.rankCandidates(
            query: query,
            candidates: candidates,
            rankingMethod: rankingMethod
        )
    }
    
    public func diffSpans(
        spanRefA: SpanRef,
        spanRefB: SpanRef,
        diffType: String
    ) async throws -> [String: Any] {
        try await environment.diffSpans(
            spanRefA: spanRefA,
            spanRefB: spanRefB,
            diffType: diffType
        )
    }
    
    // MARK: - Verification Operations
    
    public func verifyClaim(
        claim: String,
        evidenceSpans: [SpanRef],
        verificationMethod: String
    ) async throws -> [String: Any] {
        try await environment.verifyClaim(
            claim: claim,
            evidenceSpans: evidenceSpans,
            verificationMethod: verificationMethod
        )
    }
    
    public func checkConsistency(
        items: [Any],
        consistencyType: String
    ) async throws -> [String: Any] {
        try await environment.checkConsistency(
            items: items,
            consistencyType: consistencyType
        )
    }
    
    // MARK: - Task Decomposition
    
    public func spawnSubtask(
        taskDescription: String,
        parentSpanRefs: [SpanRef],
        subtaskType: String
    ) async throws -> String {
        try await environment.spawnSubtask(
            taskDescription: taskDescription,
            parentSpanRefs: parentSpanRefs,
            subtaskType: subtaskType
        )
    }
    
    public func getSubtaskResult(subtaskId: String) async throws -> [String: Any] {
        try await environment.getSubtaskResult(subtaskId: subtaskId)
    }
    
    // MARK: - Synthesis Operations
    
    public func synthesizeArtifact(
        spanRefs: [SpanRef],
        synthesisType: String,
        format: String
    ) async throws -> String {
        try await environment.synthesizeArtifact(
            spanRefs: spanRefs,
            synthesisType: synthesisType,
            format: format
        )
    }
    
    public func generateProvenance(itemRefs: [String]) async throws -> [String: Any] {
        try await environment.generateProvenance(itemRefs: itemRefs)
    }
}

// MARK: - Capability Provider

/// Provider for RLMCapability.
public actor RLMCapabilityProvider: CapabilityProvider {
    
    private let environment: ContextEnvironment
    private var capabilityImpl: RLMCapabilityImpl?
    
    public let providerId: String
    public let supportedCapabilities: [String] = [CapabilityIds.rlm]
    
    public init(
        providerId: String = "anigma.rlm.capability-provider",
        environment: ContextEnvironment
    ) {
        self.providerId = providerId
        self.environment = environment
    }
    
    /// Get the RLMCapability implementation.
    public func getCapability() async throws -> any RLMCapability {
        if let existing = capabilityImpl {
            return existing
        }
        let impl = RLMCapabilityImpl(environment: environment)
        capabilityImpl = impl
        return impl
    }
}