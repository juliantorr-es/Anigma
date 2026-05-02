import Foundation
import DatabaseCore
import AnigmaCore
import AnigmaPrimitives
import CryptoKit
import OSLog

private let contextumDatabaseLogger = Logger(
    subsystem: "com.anigma.ContextumModule",
    category: "ContextumDatabase"
)

/// Bounding box for spatial queries
public struct BoundingBox: Sendable {
    let left: Double
    let top: Double
    let right: Double
    let bottom: Double

    init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.init(left: minX, top: minY, right: maxX, bottom: maxY)
    }

    var minX: Double { left }
    var minY: Double { top }
    var maxX: Double { right }
    var maxY: Double { bottom }
    var width: Double { right - left }
    var height: Double { bottom - top }
}

/// Configuration for inserting embeddings
public struct InsertEmbeddingConfiguration: Sendable {
    let embeddingId: String
    let chunkHash: String
    let modelHash: String
    let modelId: String
    let vectorDimensions: Int
    let vector: [Float]
    let receiptId: String
    let evidenceHeadHash: String
}

/// Configuration for inserting analytics rollups
public struct InsertAnalyticsRollupConfiguration: Sendable {
    let windowStart: Int64
    let windowEnd: Int64
    let groupKeyHash: String
    let rollupSpecHash: String
    let eventRangeStart: Int64
    let eventRangeEnd: Int64
    let eventCount: Int
    let reportArtifactHash: String
    let receiptID: String
}

/// Configuration for inserting anomalies
public struct InsertAnomalyConfiguration: Sendable {
    let detectorID: String
    let windowStart: Date
    let windowEnd: Date
    let groupKeyHash: String
    let anomalySpecHash: String
    let subjectKey: String
    let severity: Int
    let evidenceRollupIDs: [String]
    let reportArtifactHash: String
    let receiptID: String
}

/// Chunk content retrieved by hash
public struct ChunkContentByHash: Sendable {
    public let chunkId: String
    public let chunkHash: String
    public let content: String
    public let sourceId: String
}

public struct ChunkReplayContext: Sendable {
    public let chunkId: String
    public let sourceId: String
    public let sourceHash: String
    public let contentHash: String
    public let content: String
    public let tokenizerPolicyHash: String?
    public let sanitizerPolicyHash: String?
    public let sourcePageIndex: Int?
    public let sourceSectionPath: [String]
    public let sourceSectionTitle: String?
    public let documentLineage: DocumentTruthLineage?
    public let documentAdapterID: String?
    public let documentReplayHash: String?
}

public struct SourceSelectionPolicy: Sendable {
    public let includeStale: Bool
    public let includeSuperseded: Bool
    public let includeConflicted: Bool

    public init(
        includeStale: Bool = false,
        includeSuperseded: Bool = false,
        includeConflicted: Bool = true
    ) {
        self.includeStale = includeStale
        self.includeSuperseded = includeSuperseded
        self.includeConflicted = includeConflicted
    }

    public static let freshOnly = SourceSelectionPolicy()
}

public enum ContextumDatabaseError: Error {
    case missingEmbeddingParameters
    case invalidChunkData
    case embeddingDimensionMismatch
}

public actor ContextumDatabase {
    internal let database: any DatabaseExecutor
    internal var dbActor: any DatabaseExecutor { database }
    private let migrationVersion = 1
    internal var databasePath: String?  // Store path for size calculations (internal for CompactionSystem)

    internal let artifactAuthority: (any ArtifactAuthority)?

    public init(databaseExecutor: any DatabaseExecutor, artifactAuthority: (any ArtifactAuthority)? = nil) {
        self.database = databaseExecutor
        self.artifactAuthority = artifactAuthority
    }

    public init(dbActor: DatabaseAuthorityAdapter, artifactAuthority: (any ArtifactAuthority)? = nil) {
        self.init(databaseExecutor: dbActor, artifactAuthority: artifactAuthority)
    }

    public init(databaseAuthority: any AnigmaFoundation.DatabaseAuthority, artifactAuthority: (any ArtifactAuthority)? = nil) {
        self.init(databaseExecutor: DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority), artifactAuthority: artifactAuthority)
    }

    public func isVectorAvailable() async -> Bool {
        await database.isVectorAvailable()
    }

    /// Set the database path for size calculations

    public func setDatabasePath(_ path: String) {
        self.databasePath = path
    }

    func storeContentAsArtifact(_ data: Data, mimeType: String = "text/plain", tags: [String] = [], metadata: [String: String] = [:]) async throws -> String {
        guard let authority = artifactAuthority else {
            // No artifact authority configured, skip artifact storage
            return ""
        }
        let hash = BLAKE3Digest.hex(of: data)
        let artifactId = ArtifactID(hash: hash)
        // Check if artifact already exists (optional optimization)
        // Create artifact object
        let artifact = Artifact(
            id: artifactId,
            mimeType: mimeType,
            size: Int64(data.count),
            createdAt: Date(),
            tags: tags,
            metadata: metadata,
            content: data
        )
        let systemContext = ExecutionContext(principal: .system)
        let (_, receipt) = try await authority.store(artifact, context: systemContext)
        // We can log receipt if needed
        return hash
    }

    func stableHash(_ parts: [String]) -> String {
        let data = Data(parts.joined(separator: "|").utf8)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    func addColumnIfMissing(table: String, column: String, type: String) async throws {
        let rows = try await database.query(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = current_schema()
              AND table_name = ?
              AND column_name = ?
            """,
            parameters: [.text(table), .text(column)]
        )
        guard rows.isEmpty else { return }
        _ = try await database.executeAsync("ALTER TABLE \(table) ADD COLUMN \(column) \(type);")
    }

    public func insertEvent(_ event: TelemetryEventComponent) async throws {
        let diagnosticJSON = try JSONEncoder().encode(event.diagnosticPayload)
        let diagnosticString = String(data: diagnosticJSON, encoding: .utf8) ?? "{}"

        let agentParam: DatabaseParameter = event.agentId.map { .text($0) } ?? .null
        let jobParam: DatabaseParameter = event.jobId.map { .text($0) } ?? .null
        let runParam: DatabaseParameter = event.runId.map { .text($0) } ?? .null
        let receiptParam: DatabaseParameter = event.receiptId.map { .text($0) } ?? .null
        let durationParam: DatabaseParameter = event.durationMs.map { .int(Int($0)) } ?? .null
        let errorParam: DatabaseParameter = event.errorCode.map { .text($0) } ?? .null

        _ = try await database.executeAsync(
            """
            INSERT INTO contextum_events (
                event_id, event_type, agent_id, job_id, run_id, receipt_id,
                timestamp, duration_ms, outcome, error_code, diagnostic_payload
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(event.eventId),
                .text(event.eventType.rawValue),
                agentParam,
                jobParam,
                runParam,
                receiptParam,
                .int(Int(event.timestamp.timeIntervalSince1970)),
                durationParam,
                .text(event.outcome.rawValue),
                errorParam,
                .text(diagnosticString)
            ]
        )
    }

    public func insertChunk(
        _ chunk: ChunkComponent,
        content: String,
        layoutMetadata: ChunkLayoutMetadata? = nil,
        provenance: ChunkIngestProvenance? = nil,
        documentLineage: DocumentTruthLineage? = nil
    ) async throws {
        let tokenParam: DatabaseParameter = chunk.tokenCount.map { .int(Int($0)) } ?? .null
        let sourceRows = try await database.query(
            "SELECT source_hash, artifact_hash, receipt_id, evidence_head_hash FROM contextum_sources WHERE source_id = ? LIMIT 1;",
            parameters: [.text(chunk.sourceId)]
        )
        let sourceRow = sourceRows.first
        let sourceHash = sourceRow?.string(for: "source_hash") ?? stableHash([chunk.sourceId, chunk.contentHash])
        let rawArtifactHash = provenance?.rawArtifactHash ?? sourceRow?.string(for: "artifact_hash")
        let normalizationHash = provenance?.normalizationHash
        let chunkerConfigHash = provenance?.chunkerConfigHash
        let tokenizerPolicyHash = provenance?.tokenizerPolicyHash
        let sanitizerPolicyHash = provenance?.sanitizerPolicyHash
        let boundaryMetadataJSON = provenance.flatMap { try? JSONEncoder().encode($0.boundaryMetadata) }
            .flatMap { String(data: $0, encoding: .utf8) }
        let receiptId = sourceRow?.string(for: "receipt_id")
        let sourceEvidenceHash = sourceRow?.string(for: "evidence_head_hash") ?? sourceHash
        let chunkHash = chunk.contentHash
        let evidenceHeadHash = stableHash([sourceEvidenceHash, chunkHash, String(chunk.chunkIndex), String(chunk.totalChunks)])
        let chunkerParamsJSON = layoutMetadata.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        let confidenceScore = layoutMetadata?.confidence ?? 1.0
        let createdAt = Int(chunk.timestamp.timeIntervalSince1970)
        var parentChunkId = provenance?.parentChunkId
        if parentChunkId == nil, chunk.chunkIndex > 0 {
            let previousRows = try await database.query(
                """
                SELECT chunk_id
                FROM contextum_chunks
                WHERE source_id = ? AND chunk_index = ?
                LIMIT 1;
                """,
                parameters: [.text(chunk.sourceId), .int(Int(chunk.chunkIndex - 1))]
            )
            parentChunkId = previousRows.first?.string(for: "chunk_id")
        }
        let childChunkId = provenance?.childChunkId
        let resolvedLineage = documentLineage ?? provenance?.documentLineage
        let lineageJSON = resolvedLineage.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        let sourceSectionPathJSON = resolvedLineage.flatMap { try? JSONEncoder().encode($0.sectionPath) }.flatMap { String(data: $0, encoding: .utf8) }
        let sourceSectionTitle = resolvedLineage?.sectionTitle
        let sourcePageIndex = resolvedLineage?.pageIndex
        let documentAdapterID = resolvedLineage?.adapterID
        let documentReplayHash = resolvedLineage.map { stableHash([$0.replayKey, $0.structuralHash, $0.sourceHash]) }
        let chunkInsertParameters: [DatabaseParameter] = [
            .text(chunk.chunkId),
            .text(chunk.sourceId),
            .text(sourceHash),
            .text(chunk.contentHash),
            .text(chunkHash),
            .int(Int(chunk.chunkIndex)),
            .int(Int(chunk.totalChunks)),
            .int(Int(chunk.byteRange.lowerBound)),
            .int(Int(chunk.byteRange.upperBound)),
            tokenParam,
            receiptId.map { .text($0) } ?? .null,
            receiptId.map { .text($0) } ?? .null,
            .text(evidenceHeadHash),
            .int(createdAt),
            .int(1),
            chunkerParamsJSON.map { .text($0) } ?? .null,
            .double(confidenceScore),
            rawArtifactHash.map { .text($0) } ?? .null,
            normalizationHash.map { .text($0) } ?? .null,
            chunkerConfigHash.map { .text($0) } ?? .null,
            tokenizerPolicyHash.map { .text($0) } ?? .null,
            sanitizerPolicyHash.map { .text($0) } ?? .null,
            boundaryMetadataJSON.map { .text($0) } ?? .null,
            parentChunkId.map { .text($0) } ?? .null,
            childChunkId.map { .text($0) } ?? .null,
            layoutMetadata.map { .int($0.pageIndex) } ?? .null,
            layoutMetadata.map { .double($0.boundingBox[0]) } ?? .null,
            layoutMetadata.map { .double($0.boundingBox[1]) } ?? .null,
            layoutMetadata.map { .double($0.boundingBox[2]) } ?? .null,
            layoutMetadata.map { .double($0.boundingBox[3]) } ?? .null,
            layoutMetadata.map { .text($0.segmentType) } ?? .null,
            layoutMetadata.map { .double($0.confidence) } ?? .null,
            lineageJSON.map { .text($0) } ?? .null,
            sourceSectionPathJSON.map { .text($0) } ?? .null,
            sourceSectionTitle.map { .text($0) } ?? .null,
            documentAdapterID.map { .text($0) } ?? .null,
            documentReplayHash.map { .text($0) } ?? .null,
            sourcePageIndex.map { .int($0) } ?? .null
        ]
        let chunkInsertSQL = """
            INSERT INTO contextum_chunks (
                chunk_id, source_id, source_hash, content_hash, chunk_hash,
                chunk_index, total_chunks, byte_range_start, byte_range_end,
                token_count, receipt_id, created_receipt_id, evidence_head_hash, timestamp,
                chunker_version, chunker_params, confidence_score,
                raw_artifact_hash, normalization_hash, chunker_config_hash, tokenizer_policy_hash, sanitizer_policy_hash, boundary_metadata,
                parent_chunk_id, child_chunk_id,
                page_index, page_left, page_top, page_right, page_bottom,
                segment_type, layout_confidence,
                document_lineage, source_section_path, source_section_title,
                document_adapter_id, document_replay_hash, source_page_index
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

        _ = try await database.executeAsync(
            chunkInsertSQL,
            parameters: chunkInsertParameters
        )

        if let parentChunkId {
            _ = try await database.executeAsync(
                "UPDATE contextum_chunks SET child_chunk_id = ? WHERE chunk_id = ?;",
                parameters: [.text(chunk.chunkId), .text(parentChunkId)]
            )
        }

        // Store chunk content as artifact via ArtifactAuthority if configured
        let contentData = Data(content.utf8)
        _ = try? await storeContentAsArtifact(contentData, mimeType: "text/plain", tags: ["chunk"], metadata: ["chunkId": chunk.chunkId, "sourceId": chunk.sourceId])

        _ = try await database.executeAsync(
            "INSERT INTO fts_chunks (chunk_id, content) VALUES (?, ?);",
            parameters: [
                .text(chunk.chunkId),
                .text(content)
            ]
        )
    }

    public func insertEmbedding(config: InsertEmbeddingConfiguration) async throws {
        let vectorData = Data(bytes: config.vector, count: config.vector.count * MemoryLayout<Float>.size)
        let vectorHash = BLAKE3Digest.hex(of: vectorData)
        let embeddedAt = Int(Date().timeIntervalSince1970)
        
        // Convert to pgvector string format: [1.2, 3.4, ...]
        let vectorString = "[\(config.vector.map { String($0) }.joined(separator: ","))]"

        _ = try await database.executeAsync(
            """
            INSERT INTO contextum_embeddings (
                embedding_id, chunk_hash, model_hash, model_id,
                vector_dimensions, vector_blob, vector, vector_hash, receipt_id,
                created_receipt_id, evidence_head_hash, timestamp, embedded_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?::vector, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (embedding_id) DO UPDATE SET
                chunk_hash = EXCLUDED.chunk_hash,
                model_hash = EXCLUDED.model_hash,
                model_id = EXCLUDED.model_id,
                vector_dimensions = EXCLUDED.vector_dimensions,
                vector_blob = EXCLUDED.vector_blob,
                vector = EXCLUDED.vector,
                vector_hash = EXCLUDED.vector_hash,
                receipt_id = EXCLUDED.receipt_id,
                created_receipt_id = EXCLUDED.created_receipt_id,
                evidence_head_hash = EXCLUDED.evidence_head_hash,
                timestamp = EXCLUDED.timestamp,
                embedded_at = EXCLUDED.embedded_at;
            """,
            parameters: [
                .text(config.embeddingId),
                .text(config.chunkHash),
                .text(config.modelHash),
                .text(config.modelId),
                .int(config.vector.count),
                .blob(vectorData),
                .text(vectorString),
                .text(vectorHash),
                .text(config.receiptId),
                .text(config.receiptId),
                .text(config.evidenceHeadHash),
                .int(embeddedAt),
                .int(embeddedAt)
            ]
        )
    }

    public func searchFullText(
        query: String,
        limit: Int = 20,
        sourceSelection: SourceSelectionPolicy = .freshOnly
    ) async throws -> [String] {
        var sql = """
            SELECT f.chunk_id
            FROM fts_chunks f
            JOIN contextum_chunks c ON c.chunk_id = f.chunk_id
            JOIN contextum_sources s ON s.source_id = c.source_id
            WHERE f.search_vector @@ plainto_tsquery('english', ?)
            """
        var parameters: [DatabaseParameter] = [.text(query)]
        let now = Int(Date().timeIntervalSince1970)
        if !sourceSelection.includeStale {
            sql += " AND (s.stale_at IS NULL OR s.stale_at > ?)"
            parameters.append(.int(now))
        }
        if !sourceSelection.includeSuperseded {
            sql += " AND s.superseded_by_source_id IS NULL"
        }
        if !sourceSelection.includeConflicted {
            sql += " AND s.conflict_status != 'unresolved'"
        }
        sql += " LIMIT ?;"
        parameters.append(.int(Int(limit)))
        let rows = try await database.query(sql, parameters: parameters)

        return rows.compactMap { $0.string(for: "chunk_id") }
    }

    public func getChunkContent(
        chunkIds: [String],
        sourceSelection: SourceSelectionPolicy = .freshOnly
    ) async throws -> [HybridSearchSystem.SearchResultChunk] {
        guard !chunkIds.isEmpty else { return [] }

        let placeholders = chunkIds.map { _ in "?" }.joined(separator: ", ")
        var query = """
            SELECT c.chunk_id, c.source_id, f.content
            FROM contextum_chunks c
            JOIN fts_chunks f ON c.chunk_id = f.chunk_id
            JOIN contextum_sources s ON c.source_id = s.source_id
            WHERE c.chunk_id IN (\(placeholders))
            """
        var parameters = chunkIds.map { DatabaseParameter.text($0) }
        let now = Int(Date().timeIntervalSince1970)
        if !sourceSelection.includeStale {
            query += " AND (s.stale_at IS NULL OR s.stale_at > ?)"
            parameters.append(.int(now))
        }
        if !sourceSelection.includeSuperseded {
            query += " AND s.superseded_by_source_id IS NULL"
        }
        if !sourceSelection.includeConflicted {
            query += " AND s.conflict_status != 'unresolved'"
        }
        query += ";"

        let rows = try await database.query(
            query,
            parameters: parameters
        )

        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id"),
                  let sourceId = row.string(for: "source_id"),
                  let content = row.string(for: "content") else {
                return nil
            }
            return HybridSearchSystem.SearchResultChunk(
                chunkId: chunkId,
                content: content,
                sourceId: sourceId,
                score: nil
            )
        }
    }

    public func getAgentStats(agentId: String, taskTaxonomy: String) async throws -> AgentStatsComponent? {
        let rows = try await database.query(
            """
            SELECT total_executions, success_count, failure_count,
                   avg_duration_ms, p50_duration_ms, p95_duration_ms,
                   last_executed, failure_codes
            FROM contextum_agent_stats
            WHERE agent_id = ? AND task_taxonomy = ?;
            """,
            parameters: [
                .text(agentId),
                .text(taskTaxonomy)
            ]
        )

        guard let row = rows.first else { return nil }

        let totalExec = row.int(for: "total_executions") ?? 0
        let successCount = row.int(for: "success_count") ?? 0
        let failureCount = row.int(for: "failure_count") ?? 0
        let avgDur = row.double(for: "avg_duration_ms") ?? 0
        let p50 = row.double(for: "p50_duration_ms") ?? 0
        let p95 = row.double(for: "p95_duration_ms") ?? 0
        let lastExec = row.int64(for: "last_executed") ?? 0
        let codesJSON = row.string(for: "failure_codes") ?? "{}"

        // Decode failure codes with error logging
        let codes: [String: Int]
        do {
            codes = try JSONDecoder().decode([String: Int].self, from: Data(codesJSON.utf8))
        } catch {
            contextumDatabaseLogger.warning(
                "Failed to decode failure codes for agent '\(agentId, privacy: .public)': \(String(describing: error), privacy: .public)"
            )
            codes = [:]
        }

        return AgentStatsComponent(
            agentId: agentId,
            taskTaxonomy: taskTaxonomy,
            totalExecutions: totalExec,
            successCount: successCount,
            failureCount: failureCount,
            avgDurationMs: avgDur,
            p50DurationMs: p50,
            p95DurationMs: p95,
            lastExecuted: Date(timeIntervalSince1970: TimeInterval(lastExec)),
            failureCodes: codes
        )
    }

    public func getChunkContentByHash(
        chunkHashes: [String],
        sourceSelection: SourceSelectionPolicy = .freshOnly
    ) async throws -> [ChunkContentByHash] {
        guard !chunkHashes.isEmpty else { return [] }

        let placeholders = chunkHashes.map { _ in "?" }.joined(separator: ", ")
        var query = """
            SELECT c.chunk_id, c.content_hash, c.source_id, f.content
            FROM contextum_chunks c
            JOIN fts_chunks f ON c.chunk_id = f.chunk_id
            JOIN contextum_sources s ON c.source_id = s.source_id
            WHERE c.content_hash IN (\(placeholders))
            """
        var parameters = chunkHashes.map { DatabaseParameter.text($0) }
        let now = Int(Date().timeIntervalSince1970)
        if !sourceSelection.includeStale {
            query += " AND (s.stale_at IS NULL OR s.stale_at > ?)"
            parameters.append(.int(now))
        }
        if !sourceSelection.includeSuperseded {
            query += " AND s.superseded_by_source_id IS NULL"
        }
        if !sourceSelection.includeConflicted {
            query += " AND s.conflict_status != 'unresolved'"
        }
        query += ";"

        let rows = try await database.query(
            query,
            parameters: parameters
        )

        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id"),
                  let chunkHash = row.string(for: "content_hash"),
                  let sourceId = row.string(for: "source_id"),
                  let content = row.string(for: "content") else {
                return nil
            }
            return ChunkContentByHash(chunkId: chunkId, chunkHash: chunkHash, content: content, sourceId: sourceId)
        }
    }

    public func getChunkReplayContext(chunkId: String) async throws -> ChunkReplayContext? {
        let rows = try await database.query(
            """
            SELECT c.chunk_id, c.source_id, c.source_hash, c.content_hash, f.content,
                   c.tokenizer_policy_hash, c.sanitizer_policy_hash,
                   c.page_index, c.source_section_path, c.source_section_title,
                   c.document_lineage, c.document_adapter_id, c.document_replay_hash
            FROM contextum_chunks c
            JOIN fts_chunks f ON c.chunk_id = f.chunk_id
            WHERE c.chunk_id = ? LIMIT 1;
            """,
            parameters: [.text(chunkId)]
        )

        guard let row = rows.first,
              let content = row.string(for: "content"),
              let sourceId = row.string(for: "source_id"),
              let sourceHash = row.string(for: "source_hash") ?? row.string(for: "source_id"),
              let contentHash = row.string(for: "content_hash") else {
            return nil
        }

        let sectionPathJSON = row.string(for: "source_section_path") ?? "[]"
        let sectionPath = (try? JSONDecoder().decode([String].self, from: Data(sectionPathJSON.utf8))) ?? []
        let lineage = row.string(for: "document_lineage").flatMap { Data($0.utf8) }.flatMap {
            try? JSONDecoder().decode(DocumentTruthLineage.self, from: $0)
        }

        return ChunkReplayContext(
            chunkId: chunkId,
            sourceId: sourceId,
            sourceHash: sourceHash,
            contentHash: contentHash,
            content: content,
            tokenizerPolicyHash: row.string(for: "tokenizer_policy_hash"),
            sanitizerPolicyHash: row.string(for: "sanitizer_policy_hash"),
            sourcePageIndex: row.int(for: "page_index"),
            sourceSectionPath: sectionPath,
            sourceSectionTitle: row.string(for: "source_section_title"),
            documentLineage: lineage,
            documentAdapterID: row.string(for: "document_adapter_id"),
            documentReplayHash: row.string(for: "document_replay_hash")
        )
    }

    public func getChunkHashToIdMap(
        chunkHashes: [String],
        sourceSelection: SourceSelectionPolicy = .freshOnly
    ) async throws -> [String: String] {
        guard !chunkHashes.isEmpty else { return [:] }

        let placeholders = chunkHashes.map { _ in "?" }.joined(separator: ", ")
        var query = """
            SELECT chunk_id, content_hash
            FROM contextum_chunks c
            JOIN contextum_sources s ON c.source_id = s.source_id
            WHERE content_hash IN (\(placeholders))
            """
        var parameters = chunkHashes.map { DatabaseParameter.text($0) }
        let now = Int(Date().timeIntervalSince1970)
        if !sourceSelection.includeStale {
            query += " AND (s.stale_at IS NULL OR s.stale_at > ?)"
            parameters.append(.int(now))
        }
        if !sourceSelection.includeSuperseded {
            query += " AND s.superseded_by_source_id IS NULL"
        }
        if !sourceSelection.includeConflicted {
            query += " AND s.conflict_status != 'unresolved'"
        }
        query += ";"

        let rows = try await database.query(
            query,
            parameters: parameters
        )

        var mapping: [String: String] = [:]
        for row in rows {
            if let chunkId = row.string(for: "chunk_id"),
               let chunkHash = row.string(for: "content_hash") {
                mapping[chunkHash] = chunkId
            }
        }
        return mapping
    }

    public func searchSpatialWithScore(
        pageIndex: Int?,
        boundingBox: BoundingBox?,
        limit: Int,
        sourceSelection: SourceSelectionPolicy = .freshOnly
    ) async throws -> [(chunkId: String, score: Double)] {
        var query = """
            SELECT c.chunk_id, 1.0 as score
            FROM contextum_chunks c
            JOIN contextum_sources s ON c.source_id = s.source_id
            WHERE 1=1
            """
        var parameters: [DatabaseParameter] = []

        if let pageIndex = pageIndex {
            query += " AND c.page_index = ?"
            parameters.append(.int(pageIndex))
        }

        if let bbox = boundingBox {
            query += " AND c.page_left >= ? AND c.page_top >= ? AND c.page_right <= ? AND c.page_bottom <= ?"
            parameters.append(.double(bbox.left))
            parameters.append(.double(bbox.top))
            parameters.append(.double(bbox.right))
            parameters.append(.double(bbox.bottom))
        }

        let now = Int(Date().timeIntervalSince1970)
        if !sourceSelection.includeStale {
            query += " AND (s.stale_at IS NULL OR s.stale_at > ?)"
            parameters.append(.int(now))
        }
        if !sourceSelection.includeSuperseded {
            query += " AND s.superseded_by_source_id IS NULL"
        }
        if !sourceSelection.includeConflicted {
            query += " AND s.conflict_status != 'unresolved'"
        }

        query += " ORDER BY score DESC LIMIT ?"
        parameters.append(.int(limit))

        let rows = try await database.query(query, parameters: parameters)

        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id"),
                  let score = row.double(for: "score") else {
                return nil
            }
            return (chunkId: chunkId, score: score)
        }
    }

    public func clearAll() async throws {
        let statements = [
            "DELETE FROM contextum_embeddings;",
            "DELETE FROM fts_chunks;",
            "DELETE FROM contextum_chunks;",
            "DELETE FROM contextum_sources;",
            "DELETE FROM contextum_events;",
            "DELETE FROM contextum_agent_stats;",
            "DELETE FROM contextum_index_status;",
            "DELETE FROM contextum_artifact_commits;",
            "DELETE FROM contextum_index_states;",
            "DELETE FROM contextum_jobs;",
            "DELETE FROM contextum_analytics_rollups;",
            "DELETE FROM contextum_anomalies;",
            "DELETE FROM forensics_reports;",
            "DELETE FROM forensic_evidence;",
            "DELETE FROM failure_reports;",
            "DELETE FROM root_cause_hypotheses;",
            "DELETE FROM replay_chunk_lineage_links;",
            "DELETE FROM replay_linkage;",
            "DELETE FROM feedback_votes;",
            "DELETE FROM agent_recommendations;",
            "DELETE FROM embedding_drift_events;",
            "DELETE FROM media_fingerprints;"
        ]

        for statement in statements {
            _ = try? await database.executeAsync(statement)
        }
    }

    // MARK: - Missing Methods for Workflows and Ingestion

    public func getChunksByContentHash(contentHash: String) async throws -> [ChunkComponent] {
        let rows = try await database.query(
            "SELECT * FROM contextum_chunks WHERE content_hash = ?;",
            parameters: [.text(contentHash)]
        )
        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id") else { return nil }
            return ChunkComponent(
                chunkId: chunkId,
                sourceId: row.string(for: "source_id") ?? "",
                contentHash: row.string(for: "content_hash") ?? "",
                chunkIndex: row.int(for: "chunk_index") ?? 0,
                totalChunks: row.int(for: "total_chunks") ?? 0,
                byteRange: (row.int(for: "byte_range_start") ?? 0)..<(row.int(for: "byte_range_end") ?? 0),
                tokenCount: row.int(for: "token_count"),
                timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0))
            )
        }
    }

    public func searchFullTextWithSpatial(
        query: String,
        pageIndex: Int?,
        boundingBox: BoundingBox?,
        limit: Int,
        sourceSelection: SourceSelectionPolicy = .freshOnly
    ) async throws -> [String] {
        // Simple implementation merging FTS and spatial if possible
        // Real implementation would use more complex joins or vector-spatial extensions
        let ftsIds = try await searchFullText(
            query: query,
            limit: limit * 2,
            sourceSelection: sourceSelection
        )
        if ftsIds.isEmpty { return [] }

        let placeholders = ftsIds.map { _ in "?" }.joined(separator: ", ")
        var sql = """
            SELECT c.chunk_id
            FROM contextum_chunks c
            JOIN contextum_sources s ON c.source_id = s.source_id
            WHERE c.chunk_id IN (\(placeholders))
            """
        var params = ftsIds.map { DatabaseParameter.text($0) }

        if let pageIndex = pageIndex {
            sql += " AND c.page_index = ?"
            params.append(.int(pageIndex))
        }

        if let bbox = boundingBox {
            sql += " AND c.page_left >= ? AND c.page_top >= ? AND c.page_right <= ? AND c.page_bottom <= ?"
            params.append(.double(bbox.left))
            params.append(.double(bbox.top))
            params.append(.double(bbox.right))
            params.append(.double(bbox.bottom))
        }

        let now = Int(Date().timeIntervalSince1970)
        if !sourceSelection.includeStale {
            sql += " AND (s.stale_at IS NULL OR s.stale_at > ?)"
            params.append(.int(now))
        }
        if !sourceSelection.includeSuperseded {
            sql += " AND s.superseded_by_source_id IS NULL"
        }
        if !sourceSelection.includeConflicted {
            sql += " AND s.conflict_status != 'unresolved'"
        }

        sql += " LIMIT ?;"
        params.append(.int(limit))

        let rows = try await database.query(sql, parameters: params)
        return rows.compactMap { row in row.string(for: "chunk_id") }
    }

    public func filterChunksBySpatial(
        chunkIds: [String],
        pageIndex: Int?,
        boundingBox: BoundingBox?,
        limit: Int? = nil,
        sourceSelection: SourceSelectionPolicy = .freshOnly
    ) async throws -> [String] {
        if chunkIds.isEmpty { return [] }

        let placeholders = chunkIds.map { _ in "?" }.joined(separator: ", ")
        var sql = """
            SELECT c.chunk_id
            FROM contextum_chunks c
            JOIN contextum_sources s ON c.source_id = s.source_id
            WHERE c.chunk_id IN (\(placeholders))
            """
        var params = chunkIds.map { DatabaseParameter.text($0) }

        if let pageIndex = pageIndex {
            sql += " AND c.page_index = ?"
            params.append(.int(pageIndex))
        }

        if let bbox = boundingBox {
            sql += " AND c.page_left >= ? AND c.page_top >= ? AND c.page_right <= ? AND c.page_bottom <= ?"
            params.append(.double(bbox.left))
            params.append(.double(bbox.top))
            params.append(.double(bbox.right))
            params.append(.double(bbox.bottom))
        }

        let now = Int(Date().timeIntervalSince1970)
        if !sourceSelection.includeStale {
            sql += " AND (s.stale_at IS NULL OR s.stale_at > ?)"
            params.append(.int(now))
        }
        if !sourceSelection.includeSuperseded {
            sql += " AND s.superseded_by_source_id IS NULL"
        }
        if !sourceSelection.includeConflicted {
            sql += " AND s.conflict_status != 'unresolved'"
        }

        if let limit = limit {
            sql += " LIMIT ?;"
            params.append(.int(limit))
        }

        let rows = try await database.query(sql, parameters: params)
        return rows.compactMap { row in row.string(for: "chunk_id") }
    }

    public func getChunksByHash(chunkHashes: [String]) async throws -> [ChunkComponent] {
        if chunkHashes.isEmpty { return [] }
        let placeholders = chunkHashes.map { _ in "?" }.joined(separator: ", ")
        let rows = try await database.query(
            "SELECT * FROM contextum_chunks WHERE content_hash IN (\(placeholders));",
            parameters: chunkHashes.map { .text($0) }
        )
        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id") else { return nil }
            return ChunkComponent(
                chunkId: chunkId,
                sourceId: row.string(for: "source_id") ?? "",
                contentHash: row.string(for: "content_hash") ?? "",
                chunkIndex: row.int(for: "chunk_index") ?? 0,
                totalChunks: row.int(for: "total_chunks") ?? 0,
                byteRange: (row.int(for: "byte_range_start") ?? 0)..<(row.int(for: "byte_range_end") ?? 0),
                tokenCount: row.int(for: "token_count"),
                timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0))
            )
        }
    }
}
