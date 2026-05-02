import Foundation
import CryptoKit

public enum SourceGraphOriginKind: String, Codable, Sendable, CaseIterable {
    case document
    case note
}

public struct SourceGraphFreshness: Codable, Hashable, Sendable {
    public let discoveredAt: Date
    public let lastSeenAt: Date
    public let staleAt: Date?
    public let score: Double

    public init(discoveredAt: Date, lastSeenAt: Date, staleAt: Date?, score: Double) {
        self.discoveredAt = discoveredAt
        self.lastSeenAt = lastSeenAt
        self.staleAt = staleAt
        self.score = score
    }
}

public struct SourceGraphConfidence: Codable, Hashable, Sendable {
    public let sourceScore: Double
    public let structureScore: Double
    public let tokenScore: Double

    public init(sourceScore: Double, structureScore: Double, tokenScore: Double) {
        self.sourceScore = sourceScore
        self.structureScore = structureScore
        self.tokenScore = tokenScore
    }

    public var score: Double {
        (sourceScore + structureScore + tokenScore) / 3.0
    }
}

public struct SourceGraphSourceRecord: Codable, Hashable, Sendable {
    public let sourceId: String
    public let sourceType: ContextSourceComponent.SourceType
    public let artifactHash: String
    public let receiptID: String
    public let ingestReceiptID: String?
    public let timestamp: Date
    public let uri: String?
    public let canonicalRef: String?
    public let canonicalEntityId: String?
    public let currentHash: String
    public let revision: Int
    public let mimeType: String?
    public let discoveredAt: Date
    public let lastSeenAt: Date
    public let staleAt: Date?
    public let supersedesSourceId: String?
    public let supersededBySourceId: String?
    public let supersessionRootSourceId: String?
    public let supersessionDepth: Int
    public let conflictStatus: ContextSourceComponent.ConflictStatus
    public let reingestionPolicy: ContextSourceComponent.ReingestionPolicy
    public let confidenceScore: Double
    public let metadata: [String: String]

    public init(source: ContextSourceComponent, metadata: [String: String]? = nil) {
        self.sourceId = source.sourceId
        self.sourceType = source.sourceType
        self.artifactHash = source.artifactHash
        self.receiptID = source.receiptId
        self.ingestReceiptID = source.ingestReceiptId
        self.timestamp = source.timestamp
        self.uri = source.uri
        self.canonicalRef = source.canonicalRef
        self.canonicalEntityId = source.canonicalEntityId
        self.currentHash = source.currentHash
        self.revision = source.revision
        self.mimeType = source.mimeType
        self.discoveredAt = source.discoveredAt
        self.lastSeenAt = source.lastSeenAt
        self.staleAt = source.staleAt
        self.supersedesSourceId = source.supersedesSourceId
        self.supersededBySourceId = source.supersededBySourceId
        self.supersessionRootSourceId = source.supersessionRootSourceId
        self.supersessionDepth = source.supersessionDepth
        self.conflictStatus = source.conflictStatus
        self.reingestionPolicy = source.reingestionPolicy
        self.confidenceScore = source.confidenceScore
        self.metadata = metadata ?? source.metadata
    }
}

public struct SourceGraphReplayMetadata: Codable, Hashable, Sendable {
    public let sourceHash: String
    public let manifestHash: String
    public let replayHash: String
    public let documentReplayHash: String
    public let nodeReplayHashes: [String]

    public init(
        sourceHash: String,
        manifestHash: String,
        replayHash: String,
        documentReplayHash: String,
        nodeReplayHashes: [String]
    ) {
        self.sourceHash = sourceHash
        self.manifestHash = manifestHash
        self.replayHash = replayHash
        self.documentReplayHash = documentReplayHash
        self.nodeReplayHashes = nodeReplayHashes
    }
}

public struct SourceGraphProvenance: Codable, Hashable, Sendable {
    public let adapterID: String
    public let sourceHash: String
    public let manifestHash: String
    public let replayHash: String
    public let receiptID: String
    public let sourceRecord: SourceGraphSourceRecord?
    public let ingestReceipt: SourceGraphIngestReceipt?
    public let replayMetadata: SourceGraphReplayMetadata?
    public let documentLineage: DocumentTruthLineage?

    public init(
        adapterID: String,
        sourceHash: String,
        manifestHash: String,
        replayHash: String,
        receiptID: String,
        sourceRecord: SourceGraphSourceRecord? = nil,
        ingestReceipt: SourceGraphIngestReceipt? = nil,
        replayMetadata: SourceGraphReplayMetadata? = nil,
        documentLineage: DocumentTruthLineage? = nil
    ) {
        self.adapterID = adapterID
        self.sourceHash = sourceHash
        self.manifestHash = manifestHash
        self.replayHash = replayHash
        self.receiptID = receiptID
        self.sourceRecord = sourceRecord
        self.ingestReceipt = ingestReceipt
        self.replayMetadata = replayMetadata
        self.documentLineage = documentLineage
    }
}

public struct SourceGraphNode: Codable, Hashable, Sendable {
    public let nodeID: String
    public let kind: DocumentTruthNodeKind
    public let section: DocumentTruthSectionNode
    public let tokenCount: Int
    public let freshness: SourceGraphFreshness
    public let confidence: SourceGraphConfidence
    public let provenance: SourceGraphProvenance
    public let children: [SourceGraphNode]

    public init(
        nodeID: String,
        kind: DocumentTruthNodeKind,
        section: DocumentTruthSectionNode,
        tokenCount: Int,
        freshness: SourceGraphFreshness,
        confidence: SourceGraphConfidence,
        provenance: SourceGraphProvenance,
        children: [SourceGraphNode] = []
    ) {
        self.nodeID = nodeID
        self.kind = kind
        self.section = section
        self.tokenCount = tokenCount
        self.freshness = freshness
        self.confidence = confidence
        self.provenance = provenance
        self.children = children
    }
}

public struct SourceGraphDocument: Codable, Hashable, Sendable {
    public let sourceId: String
    public let origin: SourceGraphOriginKind
    public let adapterID: String
    public let format: DocumentTruthSourceFormat
    public let mimeType: String
    public let canonicalRef: String
    public let uri: String?
    public let title: String?
    public let sourceHash: String
    public let manifestHash: String
    public let freshness: SourceGraphFreshness
    public let confidence: SourceGraphConfidence
    public let provenance: SourceGraphProvenance
    public let nodes: [SourceGraphNode]
    public let sourceRecord: SourceGraphSourceRecord?
    public let ingestReceipt: SourceGraphIngestReceipt?
    public let replayMetadata: SourceGraphReplayMetadata?

    public init(
        sourceId: String,
        origin: SourceGraphOriginKind,
        adapterID: String,
        format: DocumentTruthSourceFormat,
        mimeType: String,
        canonicalRef: String,
        uri: String?,
        title: String?,
        sourceHash: String,
        manifestHash: String,
        freshness: SourceGraphFreshness,
        confidence: SourceGraphConfidence,
        provenance: SourceGraphProvenance,
        nodes: [SourceGraphNode],
        sourceRecord: SourceGraphSourceRecord? = nil,
        ingestReceipt: SourceGraphIngestReceipt? = nil,
        replayMetadata: SourceGraphReplayMetadata? = nil
    ) {
        self.sourceId = sourceId
        self.origin = origin
        self.adapterID = adapterID
        self.format = format
        self.mimeType = mimeType
        self.canonicalRef = canonicalRef
        self.uri = uri
        self.title = title
        self.sourceHash = sourceHash
        self.manifestHash = manifestHash
        self.freshness = freshness
        self.confidence = confidence
        self.provenance = provenance
        self.nodes = nodes
        self.sourceRecord = sourceRecord
        self.ingestReceipt = ingestReceipt
        self.replayMetadata = replayMetadata
    }

    public var nodeCount: Int {
        nodes.reduce(0) { $0 + $1.nodeCount }
    }
}

public extension SourceGraphNode {
    public var nodeCount: Int {
        1 + children.reduce(0) { $0 + $1.nodeCount }
    }
}

public struct LocalNoteIngestInput: Sendable, Hashable {
    public let title: String
    public let content: String
    public let canonicalRef: String
    public let uri: String?
    public let notebook: String?
    public let tags: [String]
    public let createdAt: Date?
    public let updatedAt: Date?
    public let metadata: [String: String]

    public init(
        title: String,
        content: String,
        canonicalRef: String,
        uri: String? = nil,
        notebook: String? = nil,
        tags: [String] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.title = title
        self.content = content
        self.canonicalRef = canonicalRef
        self.uri = uri
        self.notebook = notebook
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

public struct SourceGraphIngestReceipt: Codable, Hashable, Sendable {
    public let sourceId: String
    public let origin: SourceGraphOriginKind
    public let adapterID: String
    public let nodeCount: Int
    public let manifestHash: String
    public let replayHash: String
    public let freshnessScore: Double
    public let confidenceScore: Double
}

public struct LocalDocumentSourceGraphAdapter: Sendable {
    public let adapterID = "source-graph/local-document"
    private let textPreprocessor: TextPreprocessingSystem
    private let preprocessingConfiguration: TextPreprocessingConfiguration

    public init(
        textPreprocessor: TextPreprocessingSystem = TextPreprocessingSystem(useCapsuleFallback: true),
        preprocessingConfiguration: TextPreprocessingConfiguration = .ingestDefault
    ) {
        self.textPreprocessor = textPreprocessor
        self.preprocessingConfiguration = preprocessingConfiguration
    }

    public func buildGraph(
        from input: DocumentTruthIngestInput,
        source: ContextSourceComponent? = nil
    ) async throws -> SourceGraphDocument {
        let adapter = DocumentTruthIngestAdapterFactory.makeAdapter(for: input.format)
        let document = try adapter.buildDocument(from: input)
        return try await buildGraph(from: document, source: source, origin: .document)
    }

    public func buildGraph(
        from document: DocumentTruthDocument,
        source: ContextSourceComponent? = nil,
        origin: SourceGraphOriginKind = .document
    ) async throws -> SourceGraphDocument {
        let sourceId = source?.sourceId ?? document.sourceHash
        let freshness = freshnessMetadata(from: source)
        let confidence = confidenceMetadata(from: source, document: document, nodeCount: document.sections.count)
        let sourceRecord = source.map { SourceGraphSourceRecord(source: $0) }
        var nodes: [SourceGraphNode] = []
        nodes.reserveCapacity(document.sections.count)
        for section in document.sections {
            nodes.append(try await buildNode(section: section, document: document, source: source))
        }
        let replayHash = replayHash(for: document)
        let ingestReceipt = SourceGraphIngestReceipt(
            sourceId: sourceId,
            origin: origin,
            adapterID: adapterID,
            nodeCount: nodes.count,
            manifestHash: document.manifestHash,
            replayHash: replayHash,
            freshnessScore: freshness.score,
            confidenceScore: confidence.score
        )
        let replayMetadata = SourceGraphReplayMetadata(
            sourceHash: document.sourceHash,
            manifestHash: document.manifestHash,
            replayHash: replayHash,
            documentReplayHash: replayHash,
            nodeReplayHashes: nodes.map(\.provenance.replayHash)
        )
        let provenance = SourceGraphProvenance(
            adapterID: adapterID,
            sourceHash: document.sourceHash,
            manifestHash: document.manifestHash,
            replayHash: replayHash,
            receiptID: source?.receiptId ?? document.manifestHash,
            sourceRecord: sourceRecord,
            ingestReceipt: ingestReceipt,
            replayMetadata: replayMetadata,
            documentLineage: nodes.first?.provenance.documentLineage
        )

        return SourceGraphDocument(
            sourceId: sourceId,
            origin: origin,
            adapterID: adapterID,
            format: document.format,
            mimeType: document.mimeType,
            canonicalRef: document.canonicalRef,
            uri: document.uri,
            title: document.title,
            sourceHash: document.sourceHash,
            manifestHash: document.manifestHash,
            freshness: freshness,
            confidence: confidence,
            provenance: provenance,
            nodes: nodes,
            sourceRecord: sourceRecord,
            ingestReceipt: ingestReceipt,
            replayMetadata: replayMetadata
        )
    }

    private func buildNode(
        section: DocumentTruthSectionNode,
        document: DocumentTruthDocument,
        source: ContextSourceComponent?
    ) async throws -> SourceGraphNode {
        let tokenCount = await textPreprocessor.tokenCount(
            for: section.text ?? "",
            policy: preprocessingConfiguration.tokenizerPolicyConfiguration.tokenizationPolicy
        )
        let freshness = freshnessMetadata(from: source)
        let confidence = nodeConfidence(from: source, section: section, tokenCount: tokenCount)
        let lineage = makeLineage(for: section, document: document)
        let provenance = SourceGraphProvenance(
            adapterID: document.adapterID,
            sourceHash: document.sourceHash,
            manifestHash: document.manifestHash,
            replayHash: replayKey(for: lineage),
            receiptID: source?.receiptId ?? document.manifestHash,
            sourceRecord: source.map { SourceGraphSourceRecord(source: $0) },
            ingestReceipt: nil,
            replayMetadata: nil,
            documentLineage: lineage
        )
        var children: [SourceGraphNode] = []
        children.reserveCapacity(section.children.count)
        for child in section.children {
            children.append(try await buildNode(section: child, document: document, source: source))
        }

        return SourceGraphNode(
            nodeID: section.nodeID,
            kind: section.kind,
            section: section,
            tokenCount: tokenCount,
            freshness: freshness,
            confidence: confidence,
            provenance: provenance,
            children: children
        )
    }

    private func freshnessMetadata(from source: ContextSourceComponent?) -> SourceGraphFreshness {
        guard let source else {
            let now = Date()
            return SourceGraphFreshness(discoveredAt: now, lastSeenAt: now, staleAt: nil, score: 1.0)
        }

        let discoveredAt = source.discoveredAt
        let lastSeenAt = source.lastSeenAt
        let staleAt = source.staleAt
        let score: Double

        if let staleAt, staleAt > discoveredAt {
            let denominator = max(staleAt.timeIntervalSince(discoveredAt), 1)
            let elapsed = min(max(lastSeenAt.timeIntervalSince(discoveredAt), 0), denominator)
            score = max(0, min(1, 1 - (elapsed / denominator)))
        } else {
            score = max(0, min(1, source.confidenceScore))
        }

        return SourceGraphFreshness(
            discoveredAt: discoveredAt,
            lastSeenAt: lastSeenAt,
            staleAt: staleAt,
            score: score
        )
    }

    private func confidenceMetadata(
        from source: ContextSourceComponent?,
        document: DocumentTruthDocument,
        nodeCount: Int
    ) -> SourceGraphConfidence {
        let sourceScore = max(0, min(1, source?.confidenceScore ?? 1.0))
        let structureScore = nodeCount == 0 ? 0.4 : min(1.0, 0.6 + (Double(nodeCount) / 10.0))
        let tokenScore = tokenScore(for: document)
        return SourceGraphConfidence(
            sourceScore: sourceScore,
            structureScore: structureScore,
            tokenScore: tokenScore
        )
    }

    private func nodeConfidence(from source: ContextSourceComponent?, section: DocumentTruthSectionNode, tokenCount: Int) -> SourceGraphConfidence {
        let sourceScore = max(0, min(1, source?.confidenceScore ?? 1.0))
        let structureScore: Double
        switch section.kind {
        case .document, .page:
            structureScore = 1.0
        case .heading:
            structureScore = 0.99
        case .paragraph, .blockquote:
            structureScore = 0.96
        case .listItem:
            structureScore = 0.94
        case .codeBlock:
            structureScore = 0.97
        case .table, .figure, .image, .caption:
            structureScore = 0.9
        case .text:
            structureScore = 0.92
        }
        let tokenScore = tokenCount > 0 ? 1.0 : 0.5
        return SourceGraphConfidence(sourceScore: sourceScore, structureScore: structureScore, tokenScore: tokenScore)
    }

    private func tokenScore(for document: DocumentTruthDocument) -> Double {
        let textNodeCount = document.sections.reduce(0) { total, section in
            total + countTextNodes(in: section)
        }
        return document.sections.isEmpty ? 0.4 : min(1.0, 0.6 + (Double(textNodeCount) / Double(max(document.sections.count, 1)) / 10.0))
    }

    private func countTextNodes(in section: DocumentTruthSectionNode) -> Int {
        let selfCount = (section.text?.isEmpty == false) ? 1 : 0
        return selfCount + section.children.reduce(0) { $0 + countTextNodes(in: $1) }
    }

    private func makeLineage(for section: DocumentTruthSectionNode, document: DocumentTruthDocument) -> DocumentTruthLineage {
        DocumentTruthLineage(
            adapterID: document.adapterID,
            sourceFormat: document.format,
            sourceMimeType: document.mimeType,
            sourceHash: document.sourceHash,
            sectionPath: section.path,
            sectionTitle: section.title,
            nodeKind: section.kind,
            pageIndex: section.pageIndex,
            sourceRangeStart: section.sourceRangeStart,
            sourceRangeEnd: section.sourceRangeEnd,
            partIndex: 0,
            partCount: 1,
            replayKey: replayKey(for: section, document: document),
            structuralHash: structuralHash(for: section)
        )
    }

    private func replayKey(for lineage: DocumentTruthLineage) -> String {
        digest([
            lineage.adapterID,
            lineage.sourceHash,
            lineage.sectionPath.joined(separator: "/"),
            lineage.nodeKind.rawValue,
            String(lineage.pageIndex ?? -1),
            String(lineage.sourceRangeStart ?? -1),
            String(lineage.sourceRangeEnd ?? -1),
            String(lineage.partIndex),
            String(lineage.partCount)
        ].joined(separator: "|"))
    }

    private func replayHash(for document: DocumentTruthDocument) -> String {
        digest([
            document.sourceHash,
            document.manifestHash,
            document.canonicalRef,
            document.sections.map(\.nodeID).joined(separator: ",")
        ].joined(separator: "|"))
    }

    private func replayKey(for section: DocumentTruthSectionNode, document: DocumentTruthDocument) -> String {
        digest([
            document.sourceHash,
            document.canonicalRef,
            section.path.joined(separator: "/"),
            section.kind.rawValue,
            String(section.pageIndex ?? -1),
            String(section.sourceRangeStart ?? -1),
            String(section.sourceRangeEnd ?? -1),
            section.nodeID
        ].joined(separator: "|"))
    }

    private func structuralHash(for section: DocumentTruthSectionNode) -> String {
        digest([
            section.nodeID,
            section.kind.rawValue,
            section.title ?? "",
            section.path.joined(separator: "/"),
            String(section.pageIndex ?? -1),
            String(section.sourceRangeStart ?? -1),
            String(section.sourceRangeEnd ?? -1)
        ].joined(separator: "|"))
    }
}

public struct LocalNoteSourceGraphAdapter: Sendable {
    public let adapterID = "source-graph/local-note"
    private let documentAdapter: LocalDocumentSourceGraphAdapter

    public init(documentAdapter: LocalDocumentSourceGraphAdapter = LocalDocumentSourceGraphAdapter()) {
        self.documentAdapter = documentAdapter
    }

    public func buildGraph(
        from note: LocalNoteIngestInput,
        source: ContextSourceComponent? = nil
    ) async throws -> SourceGraphDocument {
        var metadata = note.metadata
        metadata["sourceKind"] = "note"
        metadata["notebook"] = note.notebook ?? metadata["notebook"] ?? ""
        if !note.tags.isEmpty {
            metadata["tags"] = note.tags.joined(separator: ",")
        }
        if let createdAt = note.createdAt {
            metadata["createdAt"] = ISO8601DateFormatter().string(from: createdAt)
        }
        if let updatedAt = note.updatedAt {
            metadata["updatedAt"] = ISO8601DateFormatter().string(from: updatedAt)
        }
        let sourceRecord = source.map { SourceGraphSourceRecord(source: $0, metadata: metadata) }

        let documentInput = DocumentTruthIngestInput(
            format: .markdown,
            content: note.content,
            mimeType: "text/markdown",
            canonicalRef: note.canonicalRef,
            uri: note.uri,
            title: note.title,
            metadata: metadata
        )

        let document = try DocumentTruthIngestAdapterFactory
            .makeAdapter(for: documentInput.format)
            .buildDocument(from: documentInput)
        let graph = try await documentAdapter.buildGraph(from: document, source: source, origin: .note)
        let replayHash = graph.provenance.replayHash
        let ingestReceipt = SourceGraphIngestReceipt(
            sourceId: graph.sourceId,
            origin: .note,
            adapterID: adapterID,
            nodeCount: graph.nodes.count,
            manifestHash: graph.manifestHash,
            replayHash: replayHash,
            freshnessScore: graph.freshness.score,
            confidenceScore: graph.confidence.score
        )
        let replayMetadata = SourceGraphReplayMetadata(
            sourceHash: graph.sourceHash,
            manifestHash: graph.manifestHash,
            replayHash: replayHash,
            documentReplayHash: graph.replayMetadata?.documentReplayHash ?? replayHash,
            nodeReplayHashes: graph.nodes.map { $0.provenance.replayHash }
        )
        return SourceGraphDocument(
            sourceId: graph.sourceId,
            origin: .note,
            adapterID: adapterID,
            format: graph.format,
            mimeType: graph.mimeType,
            canonicalRef: graph.canonicalRef,
            uri: graph.uri,
            title: graph.title,
            sourceHash: graph.sourceHash,
            manifestHash: graph.manifestHash,
            freshness: graph.freshness,
            confidence: graph.confidence,
            provenance: SourceGraphProvenance(
                adapterID: adapterID,
                sourceHash: graph.sourceHash,
                manifestHash: graph.manifestHash,
                replayHash: replayHash,
                receiptID: graph.provenance.receiptID,
                sourceRecord: sourceRecord,
                ingestReceipt: ingestReceipt,
                replayMetadata: replayMetadata,
                documentLineage: graph.provenance.documentLineage
            ),
            nodes: graph.nodes,
            sourceRecord: sourceRecord,
            ingestReceipt: ingestReceipt,
            replayMetadata: replayMetadata
        )
    }
}

private func digest(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
}
