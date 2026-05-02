import Foundation

public struct ChunkBoundaryMetadata: Codable, Sendable {
    public let normalizationForm: UnicodeForm
    public let sanitized: Bool
    public let originalLength: Int
    public let normalizedLength: Int
    public let chunkIndex: Int
    public let totalChunks: Int
    public let chunkByteRangeStart: Int
    public let chunkByteRangeEnd: Int
    public let overlapSize: Int
    public let boundaries: [TextBoundary]

    public init(
        normalizationForm: UnicodeForm,
        sanitized: Bool,
        originalLength: Int,
        normalizedLength: Int,
        chunkIndex: Int,
        totalChunks: Int,
        chunkByteRangeStart: Int,
        chunkByteRangeEnd: Int,
        overlapSize: Int,
        boundaries: [TextBoundary]
    ) {
        self.normalizationForm = normalizationForm
        self.sanitized = sanitized
        self.originalLength = originalLength
        self.normalizedLength = normalizedLength
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
        self.chunkByteRangeStart = chunkByteRangeStart
        self.chunkByteRangeEnd = chunkByteRangeEnd
        self.overlapSize = overlapSize
        self.boundaries = boundaries
    }
}

public struct ChunkIngestProvenance: Codable, Sendable {
    public let rawArtifactHash: String
    public let normalizationHash: String
    public let chunkerConfigHash: String
    public let tokenizerPolicyHash: String
    public let sanitizerPolicyHash: String
    public let boundaryMetadata: ChunkBoundaryMetadata
    public let parentChunkId: String?
    public let childChunkId: String?
    public let documentLineage: DocumentTruthLineage?

    public init(
        rawArtifactHash: String,
        normalizationHash: String,
        chunkerConfigHash: String,
        tokenizerPolicyHash: String,
        sanitizerPolicyHash: String,
        boundaryMetadata: ChunkBoundaryMetadata,
        parentChunkId: String? = nil,
        childChunkId: String? = nil,
        documentLineage: DocumentTruthLineage? = nil
    ) {
        self.rawArtifactHash = rawArtifactHash
        self.normalizationHash = normalizationHash
        self.chunkerConfigHash = chunkerConfigHash
        self.tokenizerPolicyHash = tokenizerPolicyHash
        self.sanitizerPolicyHash = sanitizerPolicyHash
        self.boundaryMetadata = boundaryMetadata
        self.parentChunkId = parentChunkId
        self.childChunkId = childChunkId
        self.documentLineage = documentLineage
    }
}
