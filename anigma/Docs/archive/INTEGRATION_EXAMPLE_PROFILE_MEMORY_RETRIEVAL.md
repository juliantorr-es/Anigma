# Profile Memory + Freshness-Aware Retrieval Integration Example

This document demonstrates how the evidence-backed profile memory layer and freshness-aware retrieval system work together to provide a comprehensive personal context experience.

## Overview

The integration combines:
1. **Profile Memory Layer** - Durable facts about users, projects, preferences
2. **Freshness-Aware Retrieval** - Temporal reasoning and source trust in search
3. **Grounded Answer Validation** - Provenance gates with abstention

## Example Workflow

### 1. Profile Memory Consolidation

```swift
// During ingestion, repeated patterns are automatically consolidated into profile memory
let consolidationSystem = ProfileMemoryConsolidationSystem(
    database: contextumDatabase,
    profileMemorySystem: profileMemorySystem
)

try await consolidationSystem.consolidateEvidenceFromIngestion(
    entityId: "user-123",
    entityType: .user,
    timeWindow: 86400 * 7, // 7 days
    minEvidenceCount: 3,
    minConfidenceThreshold: 0.7
)

// This creates profile memories like:
// - "User prefers Swift over Python" (confidence: 0.85)
// - "User skilled in machine learning" (confidence: 0.90)
// - "User works with Acme Corp" (confidence: 0.75)
```

### 2. Freshness-Aware Retrieval with Profile Integration

```swift
// Create a search request with quality contract
let searchRequest = HybridSearchSystem.SearchRequest(
    query: "What programming languages does the user prefer?",
    mode: .hybrid,
    limit: 5,
    retrievalQualityContract: .init(
        freshnessPolicy: .init(
            maxAgeDays: 30,        // Only recent sources
            preferRecent: true,     // Boost recent evidence
            recentBoostFactor: 1.5 // 50% boost for fresh content
        ),
        sourceTrustPolicy: .init(
            trustedSourceTypes: ["document", "conversation"],
            trustBoostFactor: 2.0  // Double weight for trusted sources
        ),
        profileMemoryPolicy: .init(
            includeProfileMemory: true,  // Include profile facts
            profileMemoryBoostFactor: 1.8 // 80% boost for profile matches
        )
    )
)

// Execute the search
let searchSystem = HybridSearchSystem(database: contextumDatabase)
let result = try await searchSystem.search(searchRequest)

// Result includes:
// - EnhancedSearchResultChunk with source metadata and confidence scores
// - RetrievalQualityAssessment with overall quality metrics
// - Profile memory facts integrated into ranking
```

### 3. Grounded Answer Generation

```swift
// Use the retrieval results with AnswerProvenanceGate
let provenanceRecord = AnswerProvenanceRecord(
    id: UUID().uuidString,
    query: searchRequest.query,
    answer: "The user prefers Swift for programming tasks.",
    confidence: result.retrievalQuality.overallConfidence,
    sources: result.chunks.map { 
        AnswerProvenanceSource(
            sourceId: $0.sourceId,
            sourceType: $0.sourceMetadata.sourceType,
            similarity: $0.score ?? 0.0,
            chunkContent: $0.content,
            metadata: [
                "freshness": String($0.freshnessScore),
                "trust": String($0.sourceTrustScore),
                "isStale": String($0.isStale)
            ]
        )
    },
    receipts: [], // Would include ingestion receipts in production
    generatedAt: Date(),
    modelId: "contextum-retrieval"
)

// Apply provenance validation
let gate = AnswerProvenanceGate(thresholds: .default)
let validationResult = gate.validateAndFilter(answerRecord: provenanceRecord)

switch validationResult {
case .grounded(let groundedAnswer):
    // Safe to use - has sufficient evidence
    return groundedAnswer.originalAnswer.answer
case .abstention(let abstention):
    // Insufficient evidence - provide transparent response
    return "I don't have enough current information about the user's language preferences. " +
           "Missing context: \(abstention.missingContext.map { $0.message }.joined(separator: "; "))"
}
```

## Quality Assessment Example

```swift
// The retrieval quality assessment provides comprehensive metrics
let quality = result.retrievalQuality
print("""
Retrieval Quality Assessment:
- Overall Confidence: \(quality.overallConfidence)
- Freshness Score: \(quality.freshnessScore)
- Source Trust Score: \(quality.sourceTrustScore)
- Coverage Score: \(quality.coverageScore)
- Conflict Score: \(quality.conflictScore)
- Abstention Risk: \(quality.abstentionRisk)
""")

// Example output:
// Retrieval Quality Assessment:
// - Overall Confidence: 0.88
// - Freshness Score: 0.92 (all sources < 30 days old)
// - Source Trust Score: 0.95 (trusted document sources)
// - Coverage Score: 1.00 (no stale sources)
// - Conflict Score: 1.00 (no conflicts detected)
// - Abstention Risk: 0.05 (low risk)
```

## Conflict Resolution Example

```swift
// When conflicting profile memories are detected
detector.resolveProfileMemoryConflicts(
    conflicts: conflicts,
    resolutionStrategy: .keepHighestConfidence
)

// Example conflict resolution:
// - Conflict: "prefers Swift" (confidence: 0.85) vs "prefers Python" (confidence: 0.60)
// - Resolution: Keep "prefers Swift", deactivate "prefers Python"
// - Result: Single high-confidence profile memory remains active
```

## Abstention Example

```swift
// When evidence is stale or low confidence
if let abstentionReason = result.abstentionReason {
    print("Abstention triggered: \(abstentionReason)")
    
    // Example reasons:
    // - "All evidence is stale (older than freshness threshold)"
    // - "Average confidence (0.35) below threshold (0.40)"
    // - "No results found for query"
    
    return AssistantResponse(
        answer: "I can't provide an accurate answer right now.",
        confidence: result.retrievalQuality.overallConfidence,
        missingContext: [
            MissingContextWarning(
                type: .staleContext,
                message: abstentionReason,
                severity: .high,
                suggestedAction: "Update knowledge base with current information"
            )
        ]
    )
}
```

## Integration Benefits

1. **Temporal Awareness**: Retrieval automatically considers source freshness
2. **Trust Integration**: Source reputation affects ranking and confidence
3. **Profile Consistency**: Durable facts provide stable context across sessions
4. **Transparent Abstention**: Clear explanations when evidence is insufficient
5. **Quality Metrics**: Comprehensive assessment of retrieval quality

## Files Modified/Created

- `Sources/ContextumModule/Systems/ProfileMemorySystem.swift` - Profile memory CRUD
- `Sources/ContextumModule/Systems/ProfileMemoryConsolidationSystem.swift` - Automatic consolidation
- `Sources/ContextumModule/Systems/HybridSearchSystem.swift` - Freshness-aware retrieval
- `Sources/ContextumModule/Database/ContextumDatabase+ProfileMemory.swift` - Database schema
- `Sources/ContextumModule/Components/ProfileMemoryComponent.swift` - Data structures

## Next Steps

1. **Review and Approval**: Current implementations awaiting review
2. **Integration Testing**: Test end-to-end workflows with real data
3. **UI Integration**: Connect to assistant interfaces
4. **Performance Tuning**: Optimize ranking weights and thresholds
5. **Evaluation Expansion**: Add more scenarios to test matrix