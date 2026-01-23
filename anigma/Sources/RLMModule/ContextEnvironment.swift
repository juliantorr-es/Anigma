import Foundation
import AnigmaCore
import AnigmaPrimitives
import CapsuleCore
import ContextumModule
import ArtifactStoreModule
import InferenceCore
import CryptoKit

// Import capsule wrappers if available
#if canImport(TextChunkingCapsule)
import TextChunkingCapsule
#endif
#if canImport(TextPipelineCapsule)
import TextPipelineCapsule
#endif
#if canImport(VectorCapsule)
import VectorCapsule
#endif
#if canImport(CosineSimilarityCapsuleWrapper)
import CosineSimilarityCapsuleWrapper
#endif
#if canImport(RankFusionCapsuleWrapper)
import RankFusionCapsuleWrapper
#endif
#if canImport(VizAggregationCapsule)
import VizAggregationCapsule
#endif
#if canImport(LayoutEngineCapsule)
import LayoutEngineCapsule
#endif
#if canImport(MediaFingerprintCapsule)
import MediaFingerprintCapsule
#endif
#if canImport(MediaContainerCapsule)
import MediaContainerCapsule
#endif
#if canImport(CompressionCapsule)
import CompressionCapsule
#endif

/// The environment store for RLM operations, providing content-addressed span access
/// and integration with existing capsules for accelerated operations.
///
/// Environment operations follow the principle of "Swift governs, capsules compute":
/// - Swift enforces governance policies and resource budgets
/// - Capsules provide accelerated native operations (search, similarity, chunking, etc.)
/// - All operations are content-addressed and produce evidence records
public actor ContextEnvironment {
    
    // MARK: - Dependencies
    
    private let contextumDatabase: ContextumDatabase
    private let artifactAuthority: (any ArtifactAuthority)?
    private let evidenceAuthority: (any EvidenceAuthority)?
    private let embeddingComputing: (any EmbeddingComputing)?
    private let inferenceAuthority: (any InferenceAuthority)?
    
    // Capsule wrappers for accelerated operations
    private let textChunkingCapsule: Any?
    private let textPipelineCapsule: Any?
    private let vectorCapsule: Any?
    private let cosineSimilarityCapsule: Any?
    private let rankFusionCapsule: Any?
    private let vizAggregationCapsule: Any?
    private let layoutEngineCapsule: Any?
    private let mediaFingerprintCapsule: Any?
    private let mediaContainerCapsule: Any?
    private let compressionCapsule: Any?
    
    // MARK: - Capsule Accessors
    
    private var textPipelineCapsuleWrapper: TextPipelineCapsuleWrapper? {
        textPipelineCapsule as? TextPipelineCapsuleWrapper
    }
    
    private var textChunkingCapsuleWrapper: EnhancedTextChunkingCapsuleWrapper? {
        textChunkingCapsule as? EnhancedTextChunkingCapsuleWrapper
    }
    
    private var vectorCapsuleWrapper: VectorCapsuleWrapper? {
        vectorCapsule as? VectorCapsuleWrapper
    }
    
    private var cosineSimilarityCapsuleWrapper: CosineSimilarityCapsuleWrapper? {
        cosineSimilarityCapsule as? CosineSimilarityCapsuleWrapper
    }
    
    private var rankFusionCapsuleWrapper: RankFusionCapsuleWrapper? {
        rankFusionCapsule as? RankFusionCapsuleWrapper
    }
    
    private var layoutEngineCapsuleWrapper: LayoutEngineCapsuleWrapper? {
        layoutEngineCapsule as? LayoutEngineCapsuleWrapper
    }
    
    // In-memory cache for source metadata and span content
    private var sourceMetadataCache: [String: SourceMetadata] = [:]
    private var spanContentCache: [String: Data] = [:] // key: span reference ID
    private var sourceSpansCache: [String: [SpanRef]] = [:] // key: source hash
    
    // Active spans index for fast retrieval
    private var spanIndex: [String: SpanRef] = [:] // key: span reference ID
    
    // MARK: - Initialization
    
    public init(
        contextumDatabase: ContextumDatabase,
        artifactAuthority: (any ArtifactAuthority)? = nil,
        evidenceAuthority: (any EvidenceAuthority)? = nil,
        embeddingComputing: (any EmbeddingComputing)? = nil,
        inferenceAuthority: (any InferenceAuthority)? = nil,
        capsules: [String: Any] = [:]
    ) {
        self.contextumDatabase = contextumDatabase
        self.artifactAuthority = artifactAuthority
        self.evidenceAuthority = evidenceAuthority
        self.embeddingComputing = embeddingComputing
        self.inferenceAuthority = inferenceAuthority
        
        // Initialize capsule wrappers from provided capsules
        self.textChunkingCapsule = capsules["textChunking"] as? EnhancedTextChunkingCapsuleWrapper
        self.textPipelineCapsule = capsules["textPipeline"] as? TextPipelineCapsuleWrapper
        self.vectorCapsule = capsules["vector"] as? VectorCapsuleWrapper
        self.cosineSimilarityCapsule = capsules["cosineSimilarity"] as? CosineSimilarityCapsuleWrapper
        self.rankFusionCapsule = capsules["rankFusion"] as? RankFusionCapsuleWrapper
        self.vizAggregationCapsule = capsules["vizAggregation"] as? VizAggregationCapsuleWrapper
        self.layoutEngineCapsule = capsules["layoutEngine"] as? LayoutEngineCapsuleWrapper
        self.mediaFingerprintCapsule = capsules["mediaFingerprint"] as? MediaFingerprintCapsuleWrapper
        self.mediaContainerCapsule = capsules["mediaContainer"] as? MediaContainerCapsuleWrapper
        self.compressionCapsule = capsules["compression"] as? CompressionCapsuleWrapper
    }
    
    // MARK: - Environment Operations
    
    /// Get metadata about sources in the environment.
    /// - Parameter sourceHashes: Optional list of source hashes to peek at. If empty, returns all sources.
    /// - Returns: Array of source metadata with basic information (no content).
    public func peek(sourceHashes: [String] = []) async throws -> [SourceMetadata] {
        let startTime = Date()
        
        // Check cache first
        var results: [SourceMetadata] = []
        var missingHashes: [String] = []
        
        if sourceHashes.isEmpty {
            // Need to query all sources - for now return cached only
            // TODO: Query database for all sources
            return Array(sourceMetadataCache.values)
        } else {
            for hash in sourceHashes {
                if let cached = sourceMetadataCache[hash] {
                    results.append(cached)
                } else {
                    missingHashes.append(hash)
                }
            }
        }
        
        // Query database for missing sources
        if !missingHashes.isEmpty {
            // TODO: Batch query for multiple sources
            // For now, try to get each source individually
            for hash in missingHashes {
                if let source = try await contextumDatabase.getSource(artifactHash: hash) {
                    let metadata = SourceMetadata(
                        sourceId: source.sourceId,
                        contentHash: source.artifactHash,
                        mimeType: "unknown", // Not available in ContextSourceComponent
                        title: source.metadata["title"] ?? "Untitled",
                        size: 0, // Not available
                        addedAt: source.timestamp,
                        parentSourceId: nil,
                        metadata: source.metadata
                    )
                    sourceMetadataCache[hash] = metadata
                    results.append(metadata)
                }
            }
        }
        
        _ = startTime
        return results
    }
    
    /// Get a listing of all sources in the environment.
    /// - Returns: Array of source metadata.
    public func getDirectoryListing() async throws -> [SourceMetadata] {
        // In a real implementation, we would query the database for all sources
        // For now, return cached sources
        return Array(sourceMetadataCache.values)
    }
    
    /// Search for spans matching a query using hybrid search (vector + keyword).
    /// - Parameters:
    ///   - query: Search query text
    ///   - sourceHashes: Optional list of source hashes to search within. If empty, searches all sources.
    ///   - limit: Maximum number of results to return
    ///   - minScore: Minimum similarity score (0.0 to 1.0)
    /// - Returns: Array of span references with relevance scores.
    public func search(
        query: String,
        sourceHashes: [String] = [],
        limit: Int = 20,
        minScore: Double = 0.0
    ) async throws -> [(spanRef: SpanRef, score: Double)] {
        let startTime = Date()
        
        // Step 1: Full-text search via ContextumDatabase
        let chunkIds = try await contextumDatabase.searchFullText(query: query, limit: limit * 2)
        
        guard !chunkIds.isEmpty else { return [] }
        
        // Step 2: Get chunk content and metadata
        let chunks = try await contextumDatabase.getChunkContent(chunkIds: chunkIds)
        
        var results: [(spanRef: SpanRef, score: Double)] = []
        
        // Assign scores based on rank position (higher score for earlier ranks)
        for (index, chunk) in chunks.enumerated() {
            // Convert rank position to score (0.0 to 1.0)
            let rankScore = max(0.0, 1.0 - Double(index) / Double(chunks.count))
            
            if rankScore < minScore {
                continue
            }
            
            // Create span reference with chunk ID as stableId
            let spanRef = SpanRef(
                sourceHash: getHashForSourceId(chunk.sourceId),
                offset: 0,
                length: 0,
                stableId: chunk.chunkId
            )
            
            results.append((spanRef, rankScore))
            
            if results.count >= limit {
                break
            }
        }
        
        // Step 3: If vector capsule is available, augment with vector search
        // This would involve:
        // 1. Generating embedding for query using vectorCapsule (if available)
        // 2. Querying contextum_embeddings table for similar vectors
        // 3. Using cosineSimilarityCapsule for similarity computation
        // 4. Merging results using rankFusionCapsule
        
        // TODO: Implement vector search integration when embeddings are available
        
        _ = startTime
        return results
    }
    
    /// Retrieve content for specific spans.
    /// - Parameter spanRefs: Array of span references to retrieve.
    /// - Returns: Dictionary mapping span reference IDs to content strings.
    public func slice(spanRefs: [SpanRef]) async throws -> [String: String] {
        let startTime = Date()
        var results: [String: String] = [:]
        
        // Group by source hash for efficient retrieval
        var spansBySource: [String: [SpanRef]] = [:]
        for spanRef in spanRefs {
            spansBySource[spanRef.sourceHash, default: []].append(spanRef)
        }
        
        for (sourceHash, sourceSpans) in spansBySource {
            // Try to retrieve from chunks in database
            let chunkIds = sourceSpans.compactMap { $0.stableId }
            if !chunkIds.isEmpty {
                let chunks = try await contextumDatabase.getChunkContent(chunkIds: chunkIds)
                for chunk in chunks {
                    if let spanRef = sourceSpans.first(where: { $0.stableId == chunk.chunkId }) {
                        results[spanRef.referenceId] = chunk.content
                        // Cache the content
                        if let data = chunk.content.data(using: .utf8) {
                            spanContentCache[spanRef.referenceId] = data
                        }
                    }
                }
            }
            
            // For spans without stableId or not found in chunks, try artifact store
            let remainingSpans = sourceSpans.filter { results[$0.referenceId] == nil }
            if !remainingSpans.isEmpty, let artifactAuthority = artifactAuthority {
                do {
                    // Retrieve source artifact by hash
                    let artifactId = ArtifactID(hash: sourceHash)
                    let artifact = try await artifactAuthority.retrieve(artifactId, principal: .system)
                    
                    if let data = artifact.content {
                        for spanRef in remainingSpans {
                            // Extract byte range if offset/length are provided
                            if spanRef.length > 0 {
                                let start = Int(spanRef.offset)
                                let end = Int(spanRef.offset + spanRef.length)
                                if start < data.count {
                                    let subdata = data.subdata(in: start..<min(end, data.count))
                                    if let content = String(data: subdata, encoding: .utf8) {
                                        results[spanRef.referenceId] = content
                                        spanContentCache[spanRef.referenceId] = subdata
                                        continue
                                    }
                                }
                            }
                            
                            // Fallback: If no byte range or string conversion failed, return whole content if small
                            if data.count < 100_000, let content = String(data: data, encoding: .utf8) {
                                results[spanRef.referenceId] = content
                            } else {
                                results[spanRef.referenceId] = "[Binary data or too large to return in slice]"
                            }
                        }
                    }
                } catch {
                    print("[RLM] Artifact retrieval failed for \(sourceHash): \(error)")
                }
            }
            
            // Final fallback for anything still missing
            for spanRef in sourceSpans where results[spanRef.referenceId] == nil {
                results[spanRef.referenceId] = "[Content unavailable for span \(spanRef.referenceId)]"
            }
        }
        
        _ = startTime
        return results
    }
    
    /// Extract hierarchical headings/structure from a source.
    /// - Parameter sourceHash: Content hash of the source.
    /// - Returns: Array of headings with level and text.
    public func getHeadings(sourceHash: String) async throws -> [(level: Int, text: String, spanRef: SpanRef)] {
        let startTime = Date()
        
        // 1. Check if we have a layout engine capsule
        guard let layoutEngine = layoutEngineCapsuleWrapper else {
            // Fallback: Try to use text structure analysis if available
            return []
        }
        
        // 2. Retrieve artifact data
        guard let artifactAuthority = artifactAuthority else { return [] }
        
        do {
            let artifactId = ArtifactID(hash: sourceHash)
            let artifact = try await artifactAuthority.retrieve(artifactId, principal: .system)
            guard let data = artifact.content else { return [] }
            
            // 3. Analyze document structure using capsule
            // PDF analysis requires PDF data
            if artifact.mimeType == "application/pdf" {
                // Load and analyze PDF
                // NOTE: The current wrapper might need reset or state management
                // For simplicity, we'll assume analyzePDF is the entry point
                let layouts = try await layoutEngine.analyzePDF(data)
                
                var results: [(level: Int, text: String, spanRef: SpanRef)] = []
                
                for layout in layouts {
                    // Extract elements of type .header
                    // Note: This requires getLayoutElements if analyzePDF doesn't return them in PageLayout
                    let elements = try await layoutEngine.getLayoutElements(pageIndex: UInt32(layout.pageNumber - 1))
                    
                    for element in elements where element.type == .header {
                        let spanRef = SpanRef(
                            sourceHash: sourceHash,
                            offset: 0, // Element doesn't directly map to byte offset in PDF easily
                            length: UInt64(element.text.count),
                            stableId: "header_\(sourceHash)_\(element.elementId)"
                        )
                        results.append((level: Int(element.level), text: element.text, spanRef: spanRef))
                    }
                }
                
                return results
            } else {
                // Non-PDF structure analysis (e.g. Markdown)
                // For now, return empty as layout engine is PDF-centric
                return []
            }
        } catch {
            print("[RLM] getHeadings failed for \(sourceHash): \(error)")
            return []
        }
    }
    
    /// Generate a summary of a span using capsule acceleration.
    /// - Parameters:
    ///   - spanRef: Span to summarize.
    ///   - maxLength: Maximum summary length in tokens.
    ///   - style: Summary style (concise, detailed, bulleted, etc.).
    /// - Returns: Summary text.
    public func summarizeSpan(
        spanRef: SpanRef,
        maxLength: Int = 200,
        style: String = "concise"
    ) async throws -> String {
        let startTime = Date()
        
        // 1. Retrieve span content
        let contentMap = try await slice(spanRefs: [spanRef])
        guard let content = contentMap[spanRef.referenceId] else {
            return "[No content available for span \(spanRef.referenceId)]"
        }
        
        var text = content
        
        // 2. Use textPipelineCapsule for text normalization if available
        if let pipeline = textPipelineCapsuleWrapper {
            do {
                // Normalize text to NFC form and lowercase for consistency
                let normalized = try await pipeline.normalizeNFC(text)
                text = normalized
            } catch {
                // Continue with original text if normalization fails
                print("[RLM] Text pipeline normalization failed: \(error)")
            }
        }
        
        // 3. Simple extractive summarization heuristic
        let summary = extractSummary(from: text, maxLength: maxLength, style: style)
        
        _ = startTime
        return summary
    }
    
    /// Simple extractive summarization heuristic.
    /// - Parameters:
    ///   - text: Input text to summarize.
    ///   - maxLength: Maximum summary length in characters (approx).
    ///   - style: Summary style.
    /// - Returns: Extracted summary.
    private func extractSummary(from text: String, maxLength: Int, style: String) -> String {
        // Remove extra whitespace
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split into sentences (simple heuristic)
        let sentences = cleaned.split(separator: ".").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        guard !sentences.isEmpty else {
            return "[Empty content]"
        }
        
        // Select sentences based on style
        var selectedSentences: [String] = []
        var totalLength = 0
        
        switch style {
        case "concise":
            // Take first 1-2 sentences
            let maxSentences = min(2, sentences.count)
            for i in 0..<maxSentences {
                let sentence = sentences[i]
                if totalLength + sentence.count + 1 <= maxLength {
                    selectedSentences.append(sentence)
                    totalLength += sentence.count + 1
                } else {
                    break
                }
            }
            
        case "detailed":
            // Take up to 5 sentences or until maxLength
            let maxSentences = min(5, sentences.count)
            for i in 0..<maxSentences {
                let sentence = sentences[i]
                if totalLength + sentence.count + 1 <= maxLength {
                    selectedSentences.append(sentence)
                    totalLength += sentence.count + 1
                } else {
                    break
                }
            }
            
        case "bulleted":
            // Create bullet points from first few sentences
            let maxSentences = min(3, sentences.count)
            for i in 0..<maxSentences {
                let sentence = sentences[i]
                if totalLength + sentence.count + 3 <= maxLength { // +3 for "• " and newline
                    selectedSentences.append("• \(sentence)")
                    totalLength += sentence.count + 3
                } else {
                    break
                }
            }
            
        default:
            // Default: first sentence
            let firstSentence = sentences[0]
            if firstSentence.count > maxLength {
                return String(firstSentence.prefix(maxLength - 3)) + "..."
            }
            return firstSentence
        }
        
        // Join selected sentences
        if style == "bulleted" {
            return selectedSentences.joined(separator: "\n")
        } else {
            return selectedSentences.joined(separator: ". ") + (selectedSentences.isEmpty ? "" : ".")
        }
    }
    
    /// Rank candidate spans by relevance to a query.
    /// - Parameters:
    ///   - query: Query text or embedding.
    ///   - candidates: Candidate span references to rank.
    ///   - rankingMethod: Ranking method to use (similarity, hybrid, fusion).
    /// - Returns: Ranked candidates with scores.
    public func rankCandidates(
        query: String,
        candidates: [SpanRef],
        rankingMethod: String = "hybrid"
    ) async throws -> [(spanRef: SpanRef, score: Double)] {
        let startTime = Date()
        
        // 1. Try vector-based ranking if embeddings are available
        if let embeddingComputing = embeddingComputing, let cosineSimilarity = cosineSimilarityCapsuleWrapper {
            do {
                // Compute embedding for query
                let queryResult = try await embeddingComputing.computeEmbeddings(
                    modelID: "default-embedding-model",
                    modelVersion: nil,
                    inputs: [query],
                    normalize: true
                )
                
                guard let queryVector = queryResult.vectors.first else {
                    throw RLMError.toolExecutionFailed("Failed to compute query embedding", underlyingError: nil)
                }
                
                // Retrieve content for candidates and compute embeddings
                let contentMap = try await slice(spanRefs: candidates)
                let candidateTexts = candidates.compactMap { contentMap[$0.referenceId] }
                
                if !candidateTexts.isEmpty {
                    let candidateResults = try await embeddingComputing.computeEmbeddings(
                        modelID: "default-embedding-model",
                        modelVersion: nil,
                        inputs: candidateTexts,
                        normalize: true
                    )
                    
                    // Compute similarities
                    let queryVectorFloat = queryVector.map { Float($0) }
                    let candidateVectorsFloat = candidateResults.vectors.map { $0.map { Float($1) } }
                    
                    let similarities = try await cosineSimilarity.computeBatch(
                        query: queryVectorFloat,
                        candidates: candidateVectorsFloat
                    )
                    
                    var results: [(spanRef: SpanRef, score: Double)] = []
                    for (index, score) in similarities.enumerated() {
                        if index < candidates.count {
                            results.append((candidates[index], Double(score)))
                        }
                    }
                    
                    return results.sorted { $0.score > $1.score }
                }
            } catch {
                print("[RLM] Vector ranking failed: \(error)")
            }
        }
        
        // 2. Fallback: Keyword-based ranking (simple count of query words)
        let queryWords = Set(query.lowercased().split(separator: " ").map { String($0) })
        let contentMap = try await slice(spanRefs: candidates)
        
        var results: [(spanRef: SpanRef, score: Double)] = []
        for spanRef in candidates {
            let content = contentMap[spanRef.referenceId]?.lowercased() ?? ""
            var matchCount = 0
            for word in queryWords {
                if content.contains(word) {
                    matchCount += 1
                }
            }
            let score = Double(matchCount) / Double(max(1, queryWords.count))
            results.append((spanRef, score))
        }
        
        _ = startTime
        return results.sorted { $0.score > $1.score }
    }
    
    /// Compare two spans and highlight differences.
    /// - Parameters:
    ///   - spanRefA: First span.
    ///   - spanRefB: Second span.
    ///   - diffType: Type of diff (character, word, semantic).
    /// - Returns: Diff analysis with changes.
    public func diffSpans(
        spanRefA: SpanRef,
        spanRefB: SpanRef,
        diffType: String = "word"
    ) async throws -> [String: Any] {
        let startTime = Date()
        
        // In a real implementation:
        // 1. Retrieve both spans via slice()
        // 2. Use textPipelineCapsule for text normalization
        // 3. Compute diff using appropriate algorithm
        
        // For now, return empty diff
        _ = startTime
        return ["added": [], "removed": [], "changed": []]
    }
    
    /// Verify a claim against evidence in the environment.
    /// - Parameters:
    ///   - claim: Claim to verify.
    ///   - evidenceSpans: Optional specific spans to use as evidence.
    ///   - verificationMethod: Method to use for verification.
    /// - Returns: Verification result with confidence score.
    public func verifyClaim(
        claim: String,
        evidenceSpans: [SpanRef] = [],
        verificationMethod: String = "consistency"
    ) async throws -> [String: Any] {
        let startTime = Date()
        
        // In a real implementation:
        // 1. Search for relevant evidence via search()
        // 2. Use textPipelineCapsule for text analysis
        // 3. Use LLM via Harmonia for logical verification
        
        // For now, return placeholder result
        _ = startTime
        return [
            "verified": false,
            "confidence": 0.0,
            "evidenceUsed": [],
            "reasoning": "Verification not implemented"
        ]
    }
    
    /// Check consistency between multiple spans or claims.
    /// - Parameters:
    ///   - items: Spans or claims to check consistency between.
    ///   - consistencyType: Type of consistency check (factual, logical, temporal).
    /// - Returns: Consistency analysis.
    public func checkConsistency(
        items: [Any],
        consistencyType: String = "factual"
    ) async throws -> [String: Any] {
        let startTime = Date()
        
        // In a real implementation:
        // 1. Extract content from spans
        // 2. Use textPipelineCapsule for text analysis
        // 3. Use LLM via Harmonia for consistency checking
        
        // For now, return placeholder result
        _ = startTime
        return [
            "consistent": true,
            "inconsistencies": [],
            "confidence": 1.0
        ]
    }
    
    /// Spawn a subtask for decomposition via Harmonia workflow engine.
    /// - Parameters:
    ///   - taskDescription: Description of the subtask.
    ///   - parentSpanRefs: Spans from the parent task context.
    ///   - subtaskType: Type of subtask (analysis, synthesis, verification, etc.).
    /// - Returns: Subtask ID for tracking.
    public func spawnSubtask(
        taskDescription: String,
        parentSpanRefs: [SpanRef] = [],
        subtaskType: String = "analysis"
    ) async throws -> String {
        let startTime = Date()
        let subtaskId = UUID().uuidString
        
        // In a real implementation:
        // 1. Create Harmonia job with task description
        // 2. Include parent span refs as context
        
        // Record evidence of subtask spawn
        let result = ToolResult(
            success: true,
            output: ["subtask_id": AnyCodable(subtaskId)],
            evidenceHash: "", // Will be filled by recordEvidence
            duration: Date().timeIntervalSince(startTime),
            resourcesConsumed: ToolResources(toolCalls: 1)
        )
        
        _ = try await recordEvidence(
            operation: .spawnSubtask,
            inputs: [
                "description": AnyCodable(taskDescription),
                "type": AnyCodable(subtaskType)
            ],
            result: result,
            spanRefs: parentSpanRefs
        )
        
        return subtaskId
    }
    
    /// Get result of a spawned subtask.
    /// - Parameter subtaskId: ID returned by spawnSubtask.
    /// - Returns: Subtask result with status and output.
    public func getSubtaskResult(subtaskId: String) async throws -> [String: Any] {
        let startTime = Date()
        
        // In a real implementation:
        // 1. Query Harmonia for job status
        // 2. Retrieve job result if complete
        
        _ = startTime
        return [
            "status": "completed",
            "result": "Subtask \(subtaskId) result placeholder",
            "evidenceChain": []
        ]
    }
    
    /// Synthesize an artifact from multiple spans and analysis.
    /// - Parameters:
    ///   - spanRefs: Spans to synthesize from.
    ///   - synthesisType: Type of synthesis (summary, report, analysis, etc.).
    ///   - format: Output format (markdown, json, etc.).
    /// - Returns: Synthesized artifact.
    public func synthesizeArtifact(
        spanRefs: [SpanRef],
        synthesisType: String = "summary",
        format: String = "markdown"
    ) async throws -> String {
        let startTime = Date()
        
        // In a real implementation:
        // 1. Retrieve span contents via slice()
        // 2. Use textPipelineCapsule for text processing
        // 3. Use LLM via Harmonia for synthesis
        // 4. Format output according to requested format
        
        // For now, return placeholder artifact
        _ = startTime
        return "# Synthesized Artifact\n\nBased on \(spanRefs.count) spans."
    }
    
    /// Generate code based on instruction and retrieved context chunks.
    /// - Parameter inputs: Dictionary containing:
    ///   - "instruction": String describing what code to generate (required)
    ///   - "chunkIds": Array of chunk IDs to use as context (required)
    ///   - "language": Optional programming language hint
    /// - Returns: Tool result with generated code and metadata, plus span references for the chunks used.
    public func generateCode(inputs: [String: AnyCodable]) async throws -> (ToolResult, [SpanRef]) {
        let startTime = Date()
        
        // Parse inputs
        guard let instruction = inputs["instruction"]?.value as? String else {
            throw RLMError.toolExecutionFailed("Missing required parameter 'instruction'", underlyingError: nil)
        }
        guard let chunkIdsArray = inputs["chunkIds"]?.value as? [Any] else {
            throw RLMError.toolExecutionFailed("Missing required parameter 'chunkIds'", underlyingError: nil)
        }
        let chunkIds = chunkIdsArray.compactMap { $0 as? String }
        guard !chunkIds.isEmpty else {
            throw RLMError.toolExecutionFailed("'chunkIds' array is empty", underlyingError: nil)
        }
        let language = inputs["language"]?.value as? String
        
        // Check inference authority
        guard let inferenceAuthority = inferenceAuthority else {
            throw RLMError.toolExecutionFailed("No inference authority available for code generation", underlyingError: nil)
        }
        
        // Retrieve chunks from database
        let chunks = try await contextumDatabase.getChunkContent(chunkIds: chunkIds)
        
        // Construct context string
        var contextString = ""
        for (index, chunk) in chunks.enumerated() {
            contextString += """
            [CHUNK \(index + 1)]
            Source: \(chunk.sourceId)
            Content:
            \(chunk.content)
            
            """
        }
        
        let systemPrompt = """
        You are an expert coding assistant. Your task is to generate code based strictly on the provided context chunks and the user's instruction.
        
        Guidelines:
        - Use the provided context to understand existing patterns, variable names, and architectural style.
        - Do not invent new libraries or patterns unless explicitly asked.
        - Output ONLY the requested code, or a brief explanation if code cannot be generated.
        - If the language is specified as '\(language ?? "unknown")', ensure the code matches that language.
        """
        
        let userPrompt = """
        Context:
        \(contextString)
        
        Instruction:
        \(instruction)
        """
        
        let fullPrompt = "\(systemPrompt)\n\n\(userPrompt)"
        
        let request = InferenceRequest(
            task: .chat,
            input: fullPrompt,
            options: [
                "temperature": .number(0.2),
                "max_tokens": .integer(2048)
            ]
        )
        
        let response = try await inferenceAuthority.chatCompletion(
            request,
            priority: .ui,
            speculativeConfig: nil,
            context: ExecutionContext(principal: .system)
        )
        
        // Convert to span references for the chunks used
        let spanRefs = chunks.map { chunk in
            SpanRef(
                sourceHash: getHashForSourceId(chunk.sourceId),
                offset: 0,
                length: 0,
                stableId: chunk.chunkId
            )
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        let result = ToolResult(
            success: true,
            output: [
                "generated_code": AnyCodable(response.output),
                "instruction": AnyCodable(instruction),
                "chunk_ids": AnyCodable(chunkIds),
                "language": AnyCodable(language as Any)
            ],
            errorMessage: nil,
            evidenceHash: "", // Will be filled by recordEvidence
            duration: duration,
            resourcesConsumed: ToolResources(toolCalls: 1)
        )
        
        return (result, spanRefs)
    }
    
    /// Generate provenance chain for spans or artifacts.
    /// - Parameter itemRefs: Span references or artifact IDs to generate provenance for.
    /// - Returns: Provenance chain with evidence links.
    public func generateProvenance(itemRefs: [String]) async throws -> [String: Any] {
        let startTime = Date()
        
        // In a real implementation:
        // 1. Query EvidenceAuthority for evidence records
        // 2. Build provenance graph
        // 3. Include content hashes and timestamps
        
        // For now, return placeholder provenance
        _ = startTime
        return [
            "provenanceChain": [],
            "rootItems": itemRefs,
            "generatedAt": Date().iso8601String()
        ]
    }
    
    // MARK: - Source Management
    
    /// Add a source to the environment.
    /// - Parameter sourceMetadata: Metadata for the source.
    /// - Returns: Source hash.
    public func addSource(_ sourceMetadata: SourceMetadata) async throws -> String {
        // Store metadata in cache
        sourceMetadataCache[sourceMetadata.contentHash] = sourceMetadata
        
        // Convert to ContextSourceComponent and store in database
        let source = ContextSourceComponent(
            sourceId: sourceMetadata.sourceId,
            sourceType: .document, // Default
            artifactHash: sourceMetadata.contentHash,
            receiptId: UUID().uuidString, // Placeholder
            timestamp: sourceMetadata.addedAt,
            metadata: sourceMetadata.metadata
        )
        
        try await contextumDatabase.insertSource(source)
        
        // TODO: If content is available (via artifact store), index it
        // using textChunkingCapsule and generate embeddings
        
        return sourceMetadata.contentHash
    }
    
    /// Get spans for a source.
    /// - Parameter sourceHash: Content hash of the source.
    /// - Returns: Array of span references for the source.
    public func getSpansForSource(_ sourceHash: String) async throws -> [SpanRef] {
        // Check cache first
        if let cachedSpans = sourceSpansCache[sourceHash] {
            return cachedSpans
        }
        
        // Query database for chunks with this source hash
        // Note: We need to map sourceHash to sourceId first
        // For now, assume sourceHash is sourceId (they may differ)
        // TODO: Implement proper mapping
        
        // Get source metadata to get sourceId
        guard let sourceMetadata = sourceMetadataCache[sourceHash] else {
            // Source not found in cache, try to peek
            let sources = try await peek(sourceHashes: [sourceHash])
            guard let source = sources.first else {
                return []
            }
            // Continue with sourceMetadata now available
        }
        
        // Query chunks by sourceId
        // This requires a method to get chunks by sourceId that doesn't exist yet
        // For now, return empty array
        
        let spans: [SpanRef] = [] // TODO: Implement
        sourceSpansCache[sourceHash] = spans
        return spans
    }
    
    // MARK: - Evidence Recording
    
    private func recordEvidence(
        operation: ToolOperation,
        inputs: [String: AnyCodable],
        result: ToolResult,
        spanRefs: [SpanRef] = [],
        parentEvidenceIds: [String] = []
    ) async throws -> String {
        guard let evidenceAuthority = evidenceAuthority else {
            // If no evidence authority, return placeholder hash
            return "no-evidence-authority"
        }
        
        // Create evidence record
        let evidenceRecord = EvidenceRecord(
            operation: operation,
            inputs: inputs,
            result: result,
            parentEvidenceIds: parentEvidenceIds,
            spanRefs: spanRefs
        )
        
        // In a real implementation:
        // 1. Store evidence via EvidenceAuthority
        // 2. Return evidence hash
        
        // For now, return placeholder
        return evidenceRecord.contentHash
    }
    
    // MARK: - Helper Methods
    
    private func computeSHA256(_ data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: data)
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func getHashForSourceId(_ sourceId: String) -> String {
        // Search cache for sourceId
        if let metadata = sourceMetadataCache.values.first(where: { $0.sourceId == sourceId }) {
            return metadata.contentHash
        }
        // Fallback: assume they are the same (often they are in this system)
        return sourceId
    }
}

// MARK: - Date Extension for ISO 8601

private extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}