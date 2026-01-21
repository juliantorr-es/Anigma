import Foundation

/// P4: Forensics as first-class artifacts
/// Implements failure report generation and replay workflows with full provenance
/// NOTE: Simplified stub implementation - full implementation requires telemetry system

public struct FailureReportWorkflow {
    public static func execute(
        database: ContextumDatabase,
        receiptID: String,
        runID: String,
        comparisonCriteria: ComparisonCriteria?
    ) async throws -> FailureReportArtifact {

        // Step 1: Query events for this run to build timeline
        let events = try await database.queryEventsByRunID(runID: runID)

        let timeline = events.map { event in
            let diagnosticJSON = (try? JSONSerialization.data(withJSONObject: event.diagnosticPayload)) ?? Data()
            let diagnosticString = String(data: diagnosticJSON, encoding: .utf8) ?? "{}"

            return TimelineEntry(
                eventID: event.eventId,
                eventType: event.eventType.rawValue,
                timestamp: event.timestamp,
                outcome: event.outcome.rawValue,
                diagnosticPayload: diagnosticString
            )
        }

        // Step 2: Extract preflight search events and returned chunks
        let preflightEvents = events.filter { event in
            let type = event.eventType.rawValue
            return type.contains("search") || type.contains("retrieval")
        }
        let preflightSearchEventIDs = preflightEvents.map { $0.eventId }

        // Parse returned chunk hashes from diagnostic payload.
        var returnedChunkHashes: [String] = []
        for event in preflightEvents {
            returnedChunkHashes.append(contentsOf: parseChunkHashes(from: event.diagnosticPayload))
        }

        // Step 3: Extract execution receipts
        let executionEvents = events.filter { event in
            let type = event.eventType.rawValue
            return type.contains("execution") || type.contains("invoke")
        }
        let executionReceiptIDs = executionEvents.compactMap { $0.receiptId }

        // Step 4: Find postflight outcome event (usually the last failure event)
        let failureEvents = events.filter { $0.outcome == .failure }
        let postflightOutcomeEventID = failureEvents.last?.eventId

        // Step 5: Generate root cause hypotheses based on error patterns
        var rootCauseHypotheses: [RootCauseHypothesis] = []

        // Hypothesis 1: Context quality issues
        if returnedChunkHashes.isEmpty {
            var supportingFacts: [String: AnyCodable] = [:]
            supportingFacts["chunk_count"] = AnyCodable(valueInternal: 0)

            rootCauseHypotheses.append(RootCauseHypothesis(
                hypothesis: "No context chunks retrieved - search may have failed or query was too specific",
                rule: "empty_context_detection",
                evidenceReferences: preflightSearchEventIDs,
                supportingFacts: supportingFacts
            ))
        }

        // Hypothesis 2: Model failure pattern
        if let lastFailure = failureEvents.last,
           let errorCode = lastFailure.errorCode,
           errorCode.contains("model") || errorCode.contains("timeout") {
            var supportingFacts: [String: AnyCodable] = [:]
            supportingFacts["error_code"] = AnyCodable(valueInternal: errorCode)
            supportingFacts["duration_ms"] = AnyCodable(valueInternal: lastFailure.durationMs ?? 0.0)

            rootCauseHypotheses.append(RootCauseHypothesis(
                hypothesis: "Model execution failure detected - potential timeout or model degradation",
                rule: "model_failure_detection",
                evidenceReferences: [lastFailure.eventId],
                supportingFacts: supportingFacts
            ))
        }

        // Step 6: Fetch comparison runs if criteria provided
        var comparisonRuns: [ComparisonRunSummary] = []
        if let criteria = comparisonCriteria {
            let rollups = try await database.queryRollups(
                taxonomy: criteria.taxonomy,
                repoSizeBand: criteria.repoSizeBand,
                since: Date().addingTimeInterval(-7 * 24 * 3600)  // Last 7 days
            )

            comparisonRuns = rollups.prefix(criteria.limit).map { rollup in
                ComparisonRunSummary(
                    runID: rollup.receiptID,
                    outcome: rollup.successfulRuns > rollup.totalRuns / 2 ? "success" : "failure",
                    duration: Int(rollup.latencyP95),
                    timestamp: rollup.windowStart
                )
            }
        }

        return FailureReportArtifact(
            receiptID: receiptID,
            runID: runID,
            timeline: timeline,
            preflightSearchEventIDs: preflightSearchEventIDs,
            returnedChunkHashes: Array(Set(returnedChunkHashes)),  // Deduplicate
            planArtifactHash: nil,  // Would require artifact store integration
            executionReceiptIDs: executionReceiptIDs,
            postflightOutcomeEventID: postflightOutcomeEventID,
            environmentCorrelation: nil,  // Would require workflow metadata
            rootCauseHypotheses: rootCauseHypotheses,
            comparisonRuns: comparisonRuns,
            generatedAt: Date()
        )
    }
}

public struct ReplayWorkflow {
    public static func execute(
        database: ContextumDatabase,
        originalRunID: String,
        overrideAgentID: String?,
        artifactStore: ArtifactStoreProtocol,
        policyEngine: PolicyEngineProtocol
    ) async throws -> ReplayResult {

        // Step 1: Policy gate - verify replay is allowed
        let replayAllowed = try await policyEngine.evaluateReplayPermission(runID: originalRunID)
        guard replayAllowed else {
            throw ContextumError.replayNotAllowed(runID: originalRunID)
        }

        // Step 2: Query original run events to reconstruct context
        let originalEvents = try await database.queryEventsByRunID(runID: originalRunID)

        // Step 3: Extract chunk hashes from search events
        var contextChunkHashes: [String] = []
        for event in originalEvents {
            let type = event.eventType.rawValue
            guard type.contains("search") || type.contains("retrieval") else { continue }
            contextChunkHashes.append(contentsOf: parseChunkHashes(from: event.diagnosticPayload))
        }

        // Deduplicate chunk hashes
        let uniqueChunkHashes = Array(Set(contextChunkHashes))

        // Step 4: Verify chunks still exist in database
        let existingChunks = try await database.getChunksByHash(chunkHashes: uniqueChunkHashes)
        let verifiedChunkHashes = existingChunks.map { $0.contentHash }

        // Step 5: Generate replay IDs
        let replayRunID = UUID()
        let replayReceiptID = "receipt_replay_\(replayRunID.uuidString)"

        // Step 6: Record replay linkage for audit trail
        // Convert originalRunID string to UUID (or generate if invalid)
        let originalRunUUID = UUID(uuidString: originalRunID) ?? UUID()

        let linkage = ReplayLinkageComponent(
            originalRunID: originalRunUUID,
            replayRunID: replayRunID,
            replayReceiptID: replayReceiptID,
            reconstructionMethod: "chunk_hash_lookup",
            corpusSnapshotHash: Optional<String>.none,  // Could hash the set of chunks for forensics
            contextSetHash: hashChunkSet(verifiedChunkHashes),
            created: Date()
        )

        try await database.insertReplayLinkage(linkage)

        print("✅ [ForensicsWorkflow] Replay prepared for run \(originalRunID)")
        print("   → Reconstructed \(verifiedChunkHashes.count)/\(uniqueChunkHashes.count) context chunks")
        if uniqueChunkHashes.count != verifiedChunkHashes.count {
            print("   ⚠️  Warning: \(uniqueChunkHashes.count - verifiedChunkHashes.count) chunks missing from corpus")
        }

        return ReplayResult(
            replayRunID: replayRunID.uuidString,
            originalRunID: originalRunID,
            replayReceiptID: replayReceiptID,
            contextChunksUsed: verifiedChunkHashes,
            overrideAgentID: overrideAgentID
        )
    }

    // Helper: Generate deterministic hash of chunk set for corpus snapshot tracking
    private static func hashChunkSet(_ chunkHashes: [String]) -> String {
        let sorted = chunkHashes.sorted()
        let combined = sorted.joined(separator: "|")
        return "chunkset_\(combined.prefix(64))"  // Simplified hash
    }
}

// MARK: - Supporting Types

private func parseChunkHashes(from payload: [String: String]) -> [String] {
    guard let raw = payload["chunk_hashes"], !raw.isEmpty else { return [] }
    if let data = raw.data(using: .utf8),
       let decoded = try? JSONDecoder().decode([String].self, from: data) {
        return decoded
    }
    return raw
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

public struct ComparisonCriteria {
    public let taxonomy: String
    public let repoSizeBand: String?
    public let limit: Int

    public init(taxonomy: String, repoSizeBand: String?, limit: Int) {
        self.taxonomy = taxonomy
        self.repoSizeBand = repoSizeBand
        self.limit = limit
    }
}

public struct FailureReportArtifact: Codable {
    public let receiptID: String
    public let runID: String
    public let timeline: [TimelineEntry]
    public let preflightSearchEventIDs: [String]
    public let returnedChunkHashes: [String]
    public let planArtifactHash: String?
    public let executionReceiptIDs: [String]
    public let postflightOutcomeEventID: String?
    public let environmentCorrelation: EnvironmentCorrelation?
    public let rootCauseHypotheses: [RootCauseHypothesis]
    public let comparisonRuns: [ComparisonRunSummary]
    public let generatedAt: Date
}

public struct TimelineEntry: Codable {
    public let eventID: String
    public let eventType: String
    public let timestamp: Date
    public let outcome: String
    public let diagnosticPayload: String
}

public struct RootCauseHypothesis: Codable {
    public let hypothesis: String
    public let rule: String
    public let evidenceReferences: [String]
    public let supportingFacts: [String: AnyCodable]
}

public struct ComparisonRunSummary: Codable {
    public let runID: String
    public let outcome: String
    public let duration: Int?
    public let timestamp: Date
}

public struct EnvironmentCorrelation: Codable {
    public let workflowID: String?
    public let runID: String?
    public let jobID: String?
}

public struct ReplayResult {
    public let replayRunID: String
    public let originalRunID: String
    public let replayReceiptID: String
    public let contextChunksUsed: [String]
    public let overrideAgentID: String?
}

public struct AnyCodable: Codable {
    public let value: Any

    public var stringValue: String? { value as? String }
    public var intValue: Int? { value as? Int }
    public var doubleValue: Double? { value as? Double }
    public var arrayValue: [AnyCodable]? { value as? [AnyCodable] }

    // Internal initializer for creating instances with Any value
    init(valueInternal: Any) {
        self.value = valueInternal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else {
            value = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let array = value as? [AnyCodable] {
            try container.encode(array)
        }
    }
}

// MARK: - Protocol Requirements

public protocol ArtifactStoreProtocol {
    func fetchArtifact(hash: String) async throws -> Data
}

public protocol PolicyEngineProtocol {
    func evaluateReplayPermission(runID: String) async throws -> Bool
}
