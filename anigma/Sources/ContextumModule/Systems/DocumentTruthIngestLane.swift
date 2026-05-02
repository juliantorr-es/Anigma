import Foundation
import CryptoKit

public struct DocumentTruthIngestReceipt: Sendable, Codable, Hashable {
    public let sourceId: String
    public let documentFormat: DocumentTruthSourceFormat
    public let adapterID: String
    public let manifestHash: String
    public let replayHash: String
    public let chunkCount: Int
    public let pageCount: Int
    public let sectionCount: Int
}

public actor DocumentTruthIngestLane {
    private let database: ContextumDatabase
    private let maxChunkSize: Int
    private let overlapSize: Int
    private let textPreprocessor: TextPreprocessingSystem
    private let preprocessingConfiguration: TextPreprocessingConfiguration

    public init(
        database: ContextumDatabase,
        maxChunkSize: Int = 512,
        overlapSize: Int = 50,
        preprocessingConfiguration: TextPreprocessingConfiguration = .ingestDefault
    ) {
        self.database = database
        self.maxChunkSize = maxChunkSize
        self.overlapSize = overlapSize
        self.textPreprocessor = TextPreprocessingSystem(useCapsuleFallback: true)
        self.preprocessingConfiguration = preprocessingConfiguration
    }

    public func ingest(
        source: ContextSourceComponent,
        input: DocumentTruthIngestInput
    ) async throws -> DocumentTruthIngestReceipt {
        let adapter = DocumentTruthIngestAdapterFactory.makeAdapter(for: input.format)
        let document = try adapter.buildDocument(from: input)
        let chunks = document.makeChunkDrafts(maxChunkSize: maxChunkSize, overlapSize: overlapSize)
        let replayHash = digest([
            document.manifestHash,
            document.sourceHash,
            chunks.map(\.lineage.replayKey).joined(separator: ",")
        ].joined(separator: "|"))

        var metadata = source.metadata
        metadata["documentTruthFormat"] = document.format.rawValue
        metadata["documentTruthAdapter"] = document.adapterID
        metadata["documentTruthManifestHash"] = document.manifestHash
        metadata["documentTruthReplayHash"] = replayHash
        metadata["documentTruthSectionCount"] = String(document.sections.count)
        metadata["documentTruthPageCount"] = String(document.sections.filter { $0.kind == .page }.count)
        metadata["documentTruthCanonicalRef"] = document.canonicalRef

        let sourceRecord = ContextSourceComponent(
            sourceId: source.sourceId,
            sourceType: source.sourceType,
            artifactHash: source.artifactHash,
            receiptId: source.receiptId,
            timestamp: source.timestamp,
            metadata: metadata,
            uri: document.uri ?? source.uri,
            canonicalRef: document.canonicalRef,
            canonicalEntityId: source.canonicalEntityId,
            currentHash: source.currentHash,
            revision: source.revision,
            mimeType: document.mimeType,
            discoveredAt: source.discoveredAt,
            lastSeenAt: source.lastSeenAt,
            staleAt: source.staleAt,
            supersedesSourceId: source.supersedesSourceId,
            supersededBySourceId: source.supersededBySourceId,
            supersessionRootSourceId: source.supersessionRootSourceId,
            supersessionDepth: source.supersessionDepth,
            conflictStatus: source.conflictStatus,
            reingestionPolicy: source.reingestionPolicy,
            confidenceScore: source.confidenceScore,
            ingestReceiptId: source.ingestReceiptId,
            content: source.content
        )
        let persistedSource = try await database.upsertResolvedSource(sourceRecord)
        let tokenizerPolicyHash = preprocessingConfiguration
            .tokenizerPolicyFingerprint(sourceType: persistedSource.sourceType)
        let sanitizerPolicyHash = preprocessingConfiguration
            .sanitizerPolicyFingerprint(sourceType: persistedSource.sourceType)
        let preprocessingPolicyHash = preprocessingConfiguration
            .preprocessingPolicyFingerprint(sourceType: persistedSource.sourceType)

        for (index, draft) in chunks.enumerated() {
            let preprocessed = await textPreprocessor.preprocessForStorage(
                draft.content,
                configuration: preprocessingConfiguration
            )
            let chunkID = digest([
                persistedSource.sourceId,
                draft.lineage.replayKey,
                draft.contentHash,
                String(index)
            ].joined(separator: "|"))
            let chunk = ChunkComponent(
                chunkId: chunkID,
                sourceId: persistedSource.sourceId,
                contentHash: draft.contentHash,
                chunkIndex: index,
                totalChunks: chunks.count,
                byteRange: 0..<draft.content.utf8.count,
                tokenCount: preprocessed.tokenCount
            )
            let boundaryMetadata = ChunkBoundaryMetadata(
                normalizationForm: preprocessingConfiguration.normalizationForm,
                sanitized: preprocessed.sanitized,
                originalLength: preprocessed.originalLength,
                normalizedLength: preprocessed.processedLength,
                chunkIndex: index,
                totalChunks: chunks.count,
                chunkByteRangeStart: 0,
                chunkByteRangeEnd: draft.content.utf8.count,
                overlapSize: overlapSize,
                boundaries: preprocessed.boundaries
            )
            let provenance = ChunkIngestProvenance(
                rawArtifactHash: sourceRecord.artifactHash,
                normalizationHash: digest([
                    persistedSource.sourceType.rawValue,
                    draft.contentHash,
                    preprocessed.normalizedText,
                    tokenizerPolicyHash,
                    sanitizerPolicyHash
                ].joined(separator: "|")),
                chunkerConfigHash: digest([
                    persistedSource.sourceType.rawValue,
                    input.format.rawValue,
                    input.mimeType,
                    String(maxChunkSize),
                    String(overlapSize),
                    document.adapterID,
                    preprocessingPolicyHash
                ].joined(separator: "|")),
                tokenizerPolicyHash: tokenizerPolicyHash,
                sanitizerPolicyHash: sanitizerPolicyHash,
                boundaryMetadata: boundaryMetadata,
                documentLineage: draft.lineage
            )
            try await database.insertChunk(
                chunk,
                content: draft.content,
                provenance: provenance,
                documentLineage: draft.lineage
            )
        }

        return DocumentTruthIngestReceipt(
            sourceId: persistedSource.sourceId,
            documentFormat: document.format,
            adapterID: document.adapterID,
            manifestHash: document.manifestHash,
            replayHash: replayHash,
            chunkCount: chunks.count,
            pageCount: document.sections.filter { $0.kind == .page }.count,
            sectionCount: document.sections.count
        )
    }

    private func digest(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
}
