import Foundation
import DatabaseCore
import AnigmaCore

extension ContextumDatabase {
    public func getSource(artifactHash: String) async throws -> ContextSourceComponent? {
        let rows = try await database.query(
            "SELECT * FROM contextum_sources WHERE artifact_hash = ? LIMIT 1;",
            parameters: [.text(artifactHash)]
        )
        guard let row = rows.first else { return nil }
        return source(from: row, fallbackArtifactHash: artifactHash)
    }

    public func getCurrentSource(
        canonicalRef: String,
        sourceType: ContextSourceComponent.SourceType
    ) async throws -> ContextSourceComponent? {
        let canonicalLaneRef = canonicalLaneReference(for: canonicalRef)
        let legacyNormalizedCanonicalRef = legacyNormalizedCanonicalRef(for: canonicalRef)
        let rows = try await database.query(
            """
            SELECT * FROM contextum_sources
            WHERE source_type = ? AND superseded_by_source_id IS NULL
              AND (
                canonical_lane_ref = ?
                OR canonical_ref = ?
                OR (? IS NOT NULL AND canonical_lane_ref IS NULL AND LOWER(TRIM(canonical_ref)) = ?)
              )
            ORDER BY last_seen_at DESC
            LIMIT 1;
            """,
            parameters: [
                .text(sourceType.rawValue),
                .text(canonicalLaneRef),
                .text(canonicalRef),
                legacyNormalizedCanonicalRef.map { .text($0) } ?? .null,
                legacyNormalizedCanonicalRef.map { .text($0) } ?? .null
            ]
        )
        guard let row = rows.first else { return nil }
        return source(from: row, fallbackArtifactHash: canonicalRef)
    }

    public func getContextSources(ids: [String]) async throws -> [ContextSourceComponent] {
        guard !ids.isEmpty else { return [] }

        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let rows = try await database.query(
            """
            SELECT * FROM contextum_sources
            WHERE source_id IN (\(placeholders))
            ORDER BY source_id;
            """,
            parameters: ids.map { DatabaseParameter.text($0) }
        )

        return rows.compactMap { row in
            guard let sourceId = row.string(for: "source_id") else { return nil }
            return source(from: row, fallbackArtifactHash: row.string(for: "artifact_hash") ?? sourceId)
        }
    }

    @discardableResult
    public func upsertResolvedSource(_ source: ContextSourceComponent) async throws -> ContextSourceComponent {
        let canonicalRef = source.canonicalRef ?? source.artifactHash
        let canonicalLaneRef = canonicalLaneReference(for: canonicalRef)
        let priorCurrentSource = try await getCurrentSource(
            canonicalRef: canonicalRef,
            sourceType: source.sourceType
        )
        let sameHashAsCurrent = priorCurrentSource?.currentHash == source.currentHash
        let resolvedSourceId: String = {
            guard let priorCurrentSource else { return source.sourceId }
            if sameHashAsCurrent { return priorCurrentSource.sourceId }
            if priorCurrentSource.sourceId == source.sourceId {
                return stableHash([
                    source.sourceId,
                    source.currentHash,
                    source.receiptId,
                    String(max(source.revision, priorCurrentSource.revision + 1))
                ])
            }
            return source.sourceId
        }()
        let canonicalEntityId = source.canonicalEntityId
            ?? priorCurrentSource?.canonicalEntityId
            ?? stableHash([
                "canonical-entity",
                source.sourceType.rawValue,
                canonicalLaneRef
            ])
        let supersessionRootSourceId = source.supersessionRootSourceId
            ?? priorCurrentSource?.supersessionRootSourceId
            ?? priorCurrentSource?.sourceId
            ?? resolvedSourceId
        let resolvedRevision = max(
            source.revision,
            priorCurrentSource.map { sameHashAsCurrent ? $0.revision : $0.revision + 1 } ?? source.revision
        )
        let resolvedSupersessionDepth = max(
            source.supersessionDepth,
            priorCurrentSource.map { sameHashAsCurrent ? $0.supersessionDepth : $0.supersessionDepth + 1 } ?? 0
        )
        let resolvedSupersedesSourceId = sameHashAsCurrent
            ? (source.supersedesSourceId ?? priorCurrentSource?.supersedesSourceId)
            : (source.supersedesSourceId ?? priorCurrentSource?.sourceId)
        let resolvedSupersededBySourceId = sameHashAsCurrent
            ? (source.supersededBySourceId ?? priorCurrentSource?.supersededBySourceId)
            : source.supersededBySourceId
        var mergedMetadata = source.metadata
        mergedMetadata["canonicalEntityId"] = canonicalEntityId
        mergedMetadata["canonicalLaneRef"] = canonicalLaneRef
        mergedMetadata["supersessionRootSourceId"] = supersessionRootSourceId
        mergedMetadata["supersessionDepth"] = String(resolvedSupersessionDepth)
        if let resolvedSupersedesSourceId {
            mergedMetadata["supersedesSourceId"] = resolvedSupersedesSourceId
        }
        if let resolvedSupersededBySourceId {
            mergedMetadata["supersededBySourceId"] = resolvedSupersededBySourceId
        }

        let resolvedSource = ContextSourceComponent(
            sourceId: resolvedSourceId,
            sourceType: source.sourceType,
            artifactHash: source.artifactHash,
            receiptId: source.receiptId,
            timestamp: source.timestamp,
            metadata: mergedMetadata,
            uri: source.uri,
            canonicalRef: canonicalRef,
            canonicalEntityId: canonicalEntityId,
            currentHash: source.currentHash,
            revision: resolvedRevision,
            mimeType: source.mimeType,
            discoveredAt: priorCurrentSource.map { min($0.discoveredAt, source.discoveredAt) } ?? source.discoveredAt,
            lastSeenAt: priorCurrentSource.map { max($0.lastSeenAt, source.lastSeenAt) } ?? source.lastSeenAt,
            staleAt: source.staleAt,
            supersedesSourceId: resolvedSupersedesSourceId,
            supersededBySourceId: resolvedSupersededBySourceId,
            supersessionRootSourceId: supersessionRootSourceId,
            supersessionDepth: resolvedSupersessionDepth,
            conflictStatus: source.conflictStatus,
            reingestionPolicy: source.reingestionPolicy,
            confidenceScore: source.confidenceScore,
            ingestReceiptId: source.ingestReceiptId,
            content: source.content
        )

        try await persistSource(resolvedSource)

        if let priorCurrentSource,
           !sameHashAsCurrent,
           priorCurrentSource.sourceId != resolvedSource.sourceId {
            _ = try await database.executeAsync(
                """
                UPDATE contextum_sources
                SET superseded_by_source_id = ?, last_seen_at = ?
                WHERE source_id = ?;
                """,
                parameters: [
                    .text(resolvedSource.sourceId),
                    .int(Int(resolvedSource.lastSeenAt.timeIntervalSince1970)),
                    .text(priorCurrentSource.sourceId)
                ]
            )
        }

        return resolvedSource
    }

    public func getChunks(ids: [String]) async throws -> [ChunkComponent] {
        guard !ids.isEmpty else { return [] }

        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let rows = try await database.query(
            """
            SELECT chunk_id, source_id, content_hash, chunk_index, total_chunks,
                   byte_range_start, byte_range_end, token_count, timestamp
            FROM contextum_chunks
            WHERE chunk_id IN (\(placeholders))
            ORDER BY chunk_id;
            """,
            parameters: ids.map { DatabaseParameter.text($0) }
        )

        return rows.compactMap { row in
            guard
                let chunkId = row.string(for: "chunk_id"),
                let sourceId = row.string(for: "source_id"),
                let contentHash = row.string(for: "content_hash"),
                let chunkIndex = row.int(for: "chunk_index"),
                let totalChunks = row.int(for: "total_chunks"),
                let byteRangeStart = row.int(for: "byte_range_start"),
                let byteRangeEnd = row.int(for: "byte_range_end")
            else {
                return nil
            }

            let timestamp = Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0))
            return ChunkComponent(
                chunkId: chunkId,
                sourceId: sourceId,
                contentHash: contentHash,
                chunkIndex: chunkIndex,
                totalChunks: totalChunks,
                byteRange: byteRangeStart..<byteRangeEnd,
                tokenCount: row.int(for: "token_count"),
                timestamp: timestamp
            )
        }
    }

    public func insertSource(_ source: ContextSourceComponent) async throws {
        _ = try await upsertResolvedSource(source)
    }

    private func source(from row: DatabaseRow, fallbackArtifactHash: String) -> ContextSourceComponent {
        let metadataJSON = row.string(for: "metadata") ?? "{}"
        let metadata = (try? JSONDecoder().decode([String: String].self, from: Data(metadataJSON.utf8))) ?? [:]
        let sourceType = ContextSourceComponent.SourceType(rawValue: row.string(for: "source_type") ?? "") ?? .document
        let canonicalRef = row.string(for: "canonical_ref")
        let canonicalLaneRef = row.string(for: "canonical_lane_ref")
            ?? canonicalRef.map { canonicalLaneReference(for: $0) }
        let discoveredAt = Date(timeIntervalSince1970: TimeInterval(row.int64(for: "discovered_at") ?? 0))
        let lastSeenAt = Date(timeIntervalSince1970: TimeInterval(row.int64(for: "last_seen_at") ?? 0))
        let staleAt = row.int64(for: "stale_at").map { Date(timeIntervalSince1970: TimeInterval($0)) }
        var mergedMetadata = metadata
        mergedMetadata["documentTruthFormat"] = row.string(for: "document_truth_format") ?? metadata["documentTruthFormat"] ?? ""
        mergedMetadata["documentTruthAdapter"] = row.string(for: "document_truth_adapter") ?? metadata["documentTruthAdapter"] ?? ""
        mergedMetadata["documentTruthManifestHash"] = row.string(for: "document_truth_manifest_hash") ?? metadata["documentTruthManifestHash"] ?? ""
        mergedMetadata["documentTruthReplayHash"] = row.string(for: "document_truth_replay_hash") ?? metadata["documentTruthReplayHash"] ?? ""
        if let sectionCount = row.int(for: "document_truth_section_count") {
            mergedMetadata["documentTruthSectionCount"] = String(sectionCount)
        }
        if let pageCount = row.int(for: "document_truth_page_count") {
            mergedMetadata["documentTruthPageCount"] = String(pageCount)
        }
        if let supersedesSourceId = row.string(for: "supersedes_source_id") {
            mergedMetadata["supersedesSourceId"] = supersedesSourceId
        }
        if let supersededBySourceId = row.string(for: "superseded_by_source_id") {
            mergedMetadata["supersededBySourceId"] = supersededBySourceId
        }
        if let conflictStatus = row.string(for: "conflict_status") {
            mergedMetadata["conflictStatus"] = conflictStatus
        }
        if let reingestionPolicy = row.string(for: "reingestion_policy") {
            mergedMetadata["reingestionPolicy"] = reingestionPolicy
        }
        if let canonicalEntityId = row.string(for: "canonical_entity_id") {
            mergedMetadata["canonicalEntityId"] = canonicalEntityId
        }
        if let supersessionRootSourceId = row.string(for: "supersession_root_source_id") {
            mergedMetadata["supersessionRootSourceId"] = supersessionRootSourceId
        }
        if let supersessionDepth = row.int(for: "supersession_depth") {
            mergedMetadata["supersessionDepth"] = String(supersessionDepth)
        }
        if let canonicalLaneRef {
            mergedMetadata["canonicalLaneRef"] = canonicalLaneRef
        }

        return ContextSourceComponent(
            sourceId: row.string(for: "source_id") ?? "",
            sourceType: sourceType,
            artifactHash: row.string(for: "artifact_hash") ?? "",
            receiptId: row.string(for: "receipt_id") ?? "",
            timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0)),
            metadata: mergedMetadata,
            uri: row.string(for: "uri"),
            canonicalRef: canonicalRef,
            canonicalEntityId: row.string(for: "canonical_entity_id"),
            currentHash: row.string(for: "current_hash") ?? row.string(for: "artifact_hash") ?? fallbackArtifactHash,
            revision: row.int(for: "revision") ?? 1,
            mimeType: row.string(for: "mime_type"),
            discoveredAt: discoveredAt,
            lastSeenAt: lastSeenAt,
            staleAt: staleAt,
            supersedesSourceId: row.string(for: "supersedes_source_id"),
            supersededBySourceId: row.string(for: "superseded_by_source_id"),
            supersessionRootSourceId: row.string(for: "supersession_root_source_id"),
            supersessionDepth: row.int(for: "supersession_depth") ?? 0,
            conflictStatus: row.string(for: "conflict_status").flatMap(ContextSourceComponent.ConflictStatus.init(rawValue:)),
            reingestionPolicy: row.string(for: "reingestion_policy").flatMap(ContextSourceComponent.ReingestionPolicy.init(rawValue:)),
            confidenceScore: row.double(for: "confidence_score") ?? 1.0,
            ingestReceiptId: row.string(for: "ingest_receipt_id"),
            content: row.string(for: "content")
        )
    }

    private func persistSource(_ source: ContextSourceComponent) async throws {
        let metadataJSON = (try? JSONEncoder().encode(source.metadata)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let canonicalLaneRef = canonicalLaneReference(for: source.canonicalRef ?? source.artifactHash)
        let sourceHash = stableHash([
            source.sourceId,
            source.sourceType.rawValue,
            source.artifactHash,
            source.receiptId,
            source.uri ?? "",
            source.canonicalRef ?? "",
            canonicalLaneRef,
            source.canonicalEntityId ?? "",
            source.currentHash,
            String(source.revision),
            source.mimeType ?? "",
            String(Int(source.discoveredAt.timeIntervalSince1970)),
            String(Int(source.lastSeenAt.timeIntervalSince1970)),
            source.staleAt.map { String(Int($0.timeIntervalSince1970)) } ?? "",
            source.supersedesSourceId ?? "",
            source.supersededBySourceId ?? "",
            source.supersessionRootSourceId ?? "",
            String(source.supersessionDepth),
            source.conflictStatus.rawValue,
            source.reingestionPolicy.rawValue,
            String(source.confidenceScore),
            source.ingestReceiptId ?? "",
            source.metadata["documentTruthFormat"] ?? "",
            source.metadata["documentTruthAdapter"] ?? "",
            source.metadata["documentTruthManifestHash"] ?? "",
            source.metadata["documentTruthReplayHash"] ?? "",
            source.metadata["documentTruthSectionCount"] ?? "",
            source.metadata["documentTruthPageCount"] ?? ""
        ])
        let evidenceHeadHash = stableHash([sourceHash, source.currentHash, source.receiptId])
        let sectionCount = Int(source.metadata["documentTruthSectionCount"] ?? "")
        let pageCount = Int(source.metadata["documentTruthPageCount"] ?? "")

        _ = try await database.executeAsync(
            """
            INSERT INTO contextum_sources (
                source_id, source_type, source_hash, artifact_hash,
                uri, canonical_ref, canonical_lane_ref, canonical_entity_id, current_hash, revision, mime_type,
                document_truth_format, document_truth_adapter,
                document_truth_manifest_hash, document_truth_replay_hash,
                document_truth_section_count, document_truth_page_count,
                discovered_at, last_seen_at, stale_at,
                supersedes_source_id, superseded_by_source_id, supersession_root_source_id, supersession_depth,
                conflict_status, reingestion_policy, confidence_score,
                ingest_receipt_id, receipt_id, evidence_head_hash,
                timestamp, metadata
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (source_id) DO UPDATE SET
                source_type = EXCLUDED.source_type,
                source_hash = EXCLUDED.source_hash,
                artifact_hash = EXCLUDED.artifact_hash,
                uri = EXCLUDED.uri,
                canonical_ref = EXCLUDED.canonical_ref,
                canonical_lane_ref = EXCLUDED.canonical_lane_ref,
                canonical_entity_id = EXCLUDED.canonical_entity_id,
                current_hash = EXCLUDED.current_hash,
                revision = EXCLUDED.revision,
                mime_type = EXCLUDED.mime_type,
                document_truth_format = EXCLUDED.document_truth_format,
                document_truth_adapter = EXCLUDED.document_truth_adapter,
                document_truth_manifest_hash = EXCLUDED.document_truth_manifest_hash,
                document_truth_replay_hash = EXCLUDED.document_truth_replay_hash,
                document_truth_section_count = EXCLUDED.document_truth_section_count,
                document_truth_page_count = EXCLUDED.document_truth_page_count,
                discovered_at = EXCLUDED.discovered_at,
                last_seen_at = EXCLUDED.last_seen_at,
                stale_at = EXCLUDED.stale_at,
                supersedes_source_id = EXCLUDED.supersedes_source_id,
                superseded_by_source_id = EXCLUDED.superseded_by_source_id,
                supersession_root_source_id = EXCLUDED.supersession_root_source_id,
                supersession_depth = EXCLUDED.supersession_depth,
                conflict_status = EXCLUDED.conflict_status,
                reingestion_policy = EXCLUDED.reingestion_policy,
                confidence_score = EXCLUDED.confidence_score,
                ingest_receipt_id = EXCLUDED.ingest_receipt_id,
                receipt_id = EXCLUDED.receipt_id,
                evidence_head_hash = EXCLUDED.evidence_head_hash,
                timestamp = EXCLUDED.timestamp,
                metadata = EXCLUDED.metadata;
            """,
            parameters: [
                .text(source.sourceId),
                .text(source.sourceType.rawValue),
                .text(sourceHash),
                .text(source.artifactHash),
                source.uri.map { .text($0) } ?? .null,
                source.canonicalRef.map { .text($0) } ?? .null,
                .text(canonicalLaneRef),
                source.canonicalEntityId.map { .text($0) } ?? .null,
                .text(source.currentHash),
                .int(source.revision),
                source.mimeType.map { .text($0) } ?? .null,
                source.metadata["documentTruthFormat"].map { .text($0) } ?? .null,
                source.metadata["documentTruthAdapter"].map { .text($0) } ?? .null,
                source.metadata["documentTruthManifestHash"].map { .text($0) } ?? .null,
                source.metadata["documentTruthReplayHash"].map { .text($0) } ?? .null,
                sectionCount.map { .int($0) } ?? .null,
                pageCount.map { .int($0) } ?? .null,
                .int(Int(source.discoveredAt.timeIntervalSince1970)),
                .int(Int(source.lastSeenAt.timeIntervalSince1970)),
                source.staleAt.map { .int(Int($0.timeIntervalSince1970)) } ?? .null,
                source.supersedesSourceId.map { .text($0) } ?? .null,
                source.supersededBySourceId.map { .text($0) } ?? .null,
                source.supersessionRootSourceId.map { .text($0) } ?? .null,
                .int(source.supersessionDepth),
                .text(source.conflictStatus.rawValue),
                .text(source.reingestionPolicy.rawValue),
                .double(source.confidenceScore),
                source.ingestReceiptId.map { .text($0) } ?? .null,
                .text(source.receiptId),
                .text(evidenceHeadHash),
                .int(Int(source.lastSeenAt.timeIntervalSince1970)),
                .text(metadataJSON)
            ]
        )
    }

    private func canonicalLaneReference(for canonicalRef: String) -> String {
        let trimmed = canonicalRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isCanonicalPersonLane(trimmed) else { return trimmed }
        let suffix = String(trimmed.dropFirst("person://".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "person://\(suffix.lowercased())"
    }

    private func legacyNormalizedCanonicalRef(for canonicalRef: String) -> String? {
        let trimmed = canonicalRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isCanonicalPersonLane(trimmed) else { return nil }
        return trimmed.lowercased()
    }

    private func isCanonicalPersonLane(_ canonicalRef: String) -> Bool {
        canonicalRef.lowercased().hasPrefix("person://")
    }
}
