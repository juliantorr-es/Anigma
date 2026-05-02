import Foundation
import TelemetryCore

public enum CapsuleGateStatus: String, Codable, Sendable {
    case gated
    case ungated
}

public struct CapsuleDescriptor: Codable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let gateStatus: CapsuleGateStatus

    public init(id: String, name: String, version: String, gateStatus: CapsuleGateStatus) {
        self.id = id
        self.name = name
        self.version = version
        self.gateStatus = gateStatus
    }
}

public protocol GatedCapsule: Sendable {
    var descriptor: CapsuleDescriptor { get }
}

public enum CapsuleRegistrationError: LocalizedError, Sendable {
    case notAllowlisted(String)

    public var errorDescription: String? {
        switch self {
        case .notAllowlisted(let id):
            return "Capsule is not allowlisted for execution: \(id)"
        }
    }
}

public final class CapsuleRegistry: @unchecked Sendable {
    private let allowlist: Set<String>
    private let lock = NSLock()
    private var registered: [String: CapsuleDescriptor] = [:]

    public init(allowlist: Set<String>) {
        self.allowlist = allowlist
    }

    @discardableResult
    public func register(_ capsule: GatedCapsule) throws -> CapsuleDescriptor {
        let id = capsule.descriptor.id
        guard allowlist.contains(id) else {
            throw CapsuleRegistrationError.notAllowlisted(id)
        }

        lock.lock()
        defer { lock.unlock() }
        registered[id] = capsule.descriptor
        return capsule.descriptor
    }

    public func registeredCapsuleIDs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return registered.keys.sorted()
    }

    public func isRegistered(_ capsuleID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return registered[capsuleID] != nil
    }
}

public struct VerticalSliceRequest: Sendable {
    public let jobID: String
    public let sourcePath: String
    public let instruction: String
    public let text: String?
    public let pdfData: Data?

    public init(jobID: String, sourcePath: String, instruction: String, text: String?, pdfData: Data?) {
        self.jobID = jobID
        self.sourcePath = sourcePath
        self.instruction = instruction
        self.text = text
        self.pdfData = pdfData
    }
}

public struct IngestSummary: Codable, Sendable {
    public let documentID: String
    public let sourcePath: String
    public let contentType: String
    public let characterCount: Int
    public let digest: String
}

public struct ChunkSummary: Codable, Sendable {
    public let chunkID: String
    public let offset: Int
    public let length: Int
    public let digest: String
}

public struct EmbeddingSummary: Codable, Sendable {
    public let chunkID: String
    public let dimensions: Int
    public let digest: String
}

public struct RankSummary: Codable, Sendable {
    public let chunkID: String
    public let fusedScore: Double
    public let lexicalScore: Double
    public let embeddingScore: Double
}

public struct RenderPlanSection: Codable, Sendable {
    public let chunkID: String
    public let title: String
    public let highlight: String
    public let score: Double
}

public struct RenderPlan: Codable, Sendable {
    public let planID: String
    public let instruction: String
    public let summary: String
    public let sections: [RenderPlanSection]
}

public struct VerticalSlicePipelineOutput: Codable, Sendable {
    public let ingest: IngestSummary
    public let chunks: [ChunkSummary]
    public let embeddings: [EmbeddingSummary]
    public let ranks: [RankSummary]
    public let renderPlan: RenderPlan
    public let outputDigest: String
}

public final class VerticalSlicePipeline: @unchecked Sendable {
    public static let defaultAllowlist: Set<String> = [
        "capsule.ingest.pdf",
        "capsule.ingest.text",
        "capsule.chunker.standard",
        "capsule.embedding.index",
        "capsule.rank.fusion",
        "capsule.render.plan"
    ]

    private let registry: CapsuleRegistry
    private let pdfIngest = PDFIngestCapsule()
    private let textIngest = TextIngestCapsule()
    private let chunker = ChunkingCapsule()
    private let embedder = EmbeddingIndexCapsule()
    private let ranker = RankFusionCapsule()
    private let renderer = RenderPlanCapsule()

    public init(allowlist: Set<String> = VerticalSlicePipeline.defaultAllowlist) {
        registry = CapsuleRegistry(allowlist: allowlist)
        _ = try? registry.register(pdfIngest)
        _ = try? registry.register(textIngest)
        _ = try? registry.register(chunker)
        _ = try? registry.register(embedder)
        _ = try? registry.register(ranker)
        _ = try? registry.register(renderer)
    }

    public func execute(request: VerticalSliceRequest, diagnostics: CapsuleDiagnostics) async throws -> VerticalSlicePipelineOutput {
        try ensureRegistered()

        let ingestSpan = diagnostics.beginSpan(
            name: "capsule.ingest",
            category: "capsule",
            correlationID: nil,
            tags: ["job_id": request.jobID, "source": request.sourcePath]
        )

        let ingested: IngestedDocument
        if let pdfData = request.pdfData {
            ingested = pdfIngest.ingest(sourcePath: request.sourcePath, data: pdfData)
        } else {
            ingested = textIngest.ingest(sourcePath: request.sourcePath, text: request.text ?? "")
        }
        ingestSpan.end(status: .ok)

        let chunkSpan = diagnostics.beginSpan(
            name: "capsule.chunking",
            category: "capsule",
            correlationID: nil,
            tags: ["document_id": ingested.documentID]
        )
        let chunks = chunker.chunk(document: ingested)
        chunkSpan.end(status: .ok)

        let embeddingSpan = diagnostics.beginSpan(
            name: "capsule.embedding",
            category: "capsule",
            correlationID: nil,
            tags: ["chunk_count": "\(chunks.count)"]
        )
        let embeddings = embedder.embed(chunks: chunks)
        embeddingSpan.end(status: .ok)

        let rankSpan = diagnostics.beginSpan(
            name: "capsule.rank_fusion",
            category: "capsule",
            correlationID: nil,
            tags: ["instruction": request.instruction]
        )
        let rankings = ranker.rank(chunks: chunks, embeddings: embeddings, instruction: request.instruction)
        rankSpan.end(status: .ok)

        let renderSpan = diagnostics.beginSpan(
            name: "capsule.render_plan",
            category: "capsule",
            correlationID: nil,
            tags: ["ranked_count": "\(rankings.count)"]
        )
        let renderPlan = renderer.render(document: ingested, rankings: rankings, instruction: request.instruction)
        renderSpan.end(status: .ok)

        let digestSeed = "\(renderPlan.planID)|\(renderPlan.summary)|\(rankings.map { $0.chunkID }.joined(separator: ","))"
        let output = VerticalSlicePipelineOutput(
            ingest: ingested.summary,
            chunks: chunks.map { $0.summary },
            embeddings: embeddings.map { $0.summary },
            ranks: rankings.map { $0.summary },
            renderPlan: renderPlan,
            outputDigest: DeterministicHasher.hexDigest(digestSeed)
        )

        diagnostics.event(
            level: .info,
            category: "daemon.pipeline",
            message: "Render plan emitted",
            correlationID: nil,
            metadata: ["plan_id": renderPlan.planID, "output_digest": output.outputDigest]
        )

        return output
    }

    private func ensureRegistered() throws {
        let required = [
            pdfIngest.descriptor.id,
            textIngest.descriptor.id,
            chunker.descriptor.id,
            embedder.descriptor.id,
            ranker.descriptor.id,
            renderer.descriptor.id
        ]
        let missing = required.filter { !registry.isRegistered($0) }
        if let missingID = missing.first {
            throw CapsuleRegistrationError.notAllowlisted(missingID)
        }
    }
}

private struct IngestedDocument: Sendable {
    let documentID: String
    let sourcePath: String
    let contentType: String
    let text: String
    let digest: String

    var summary: IngestSummary {
        IngestSummary(
            documentID: documentID,
            sourcePath: sourcePath,
            contentType: contentType,
            characterCount: text.count,
            digest: digest
        )
    }
}

private struct Chunk: Sendable {
    let chunkID: String
    let offset: Int
    let length: Int
    let text: String
    let digest: String

    var summary: ChunkSummary {
        ChunkSummary(chunkID: chunkID, offset: offset, length: length, digest: digest)
    }
}

private struct EmbeddingRecord: Sendable {
    let chunkID: String
    let vector: [Double]
    let digest: String

    var summary: EmbeddingSummary {
        EmbeddingSummary(chunkID: chunkID, dimensions: vector.count, digest: digest)
    }
}

private struct RankedChunk: Sendable {
    let chunkID: String
    let fusedScore: Double
    let lexicalScore: Double
    let embeddingScore: Double

    var summary: RankSummary {
        RankSummary(
            chunkID: chunkID,
            fusedScore: fusedScore,
            lexicalScore: lexicalScore,
            embeddingScore: embeddingScore
        )
    }
}

private struct PDFIngestCapsule: GatedCapsule {
    let descriptor = CapsuleDescriptor(
        id: "capsule.ingest.pdf",
        name: "PDFIngestCapsule",
        version: "1.0.0",
        gateStatus: .gated
    )

    func ingest(sourcePath: String, data: Data) -> IngestedDocument {
        let digest = DeterministicHasher.hexDigest(data)
        let text = "PDF ingest \(digest)"
        return IngestedDocument(
            documentID: "doc-\(digest)",
            sourcePath: sourcePath,
            contentType: "application/pdf",
            text: text,
            digest: digest
        )
    }
}

private struct TextIngestCapsule: GatedCapsule {
    let descriptor = CapsuleDescriptor(
        id: "capsule.ingest.text",
        name: "TextIngestCapsule",
        version: "1.0.0",
        gateStatus: .gated
    )

    func ingest(sourcePath: String, text: String) -> IngestedDocument {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = DeterministicHasher.hexDigest(normalized)
        return IngestedDocument(
            documentID: "doc-\(digest)",
            sourcePath: sourcePath,
            contentType: "text/plain",
            text: normalized,
            digest: digest
        )
    }
}

private struct ChunkingCapsule: GatedCapsule {
    let descriptor = CapsuleDescriptor(
        id: "capsule.chunker.standard",
        name: "ChunkingCapsule",
        version: "1.0.0",
        gateStatus: .gated
    )

    func chunk(document: IngestedDocument, chunkSize: Int = 240) -> [Chunk] {
        guard !document.text.isEmpty else { return [] }
        var chunks: [Chunk] = []
        var start = document.text.startIndex
        var offset = 0

        while start < document.text.endIndex {
            let end = document.text.index(start, offsetBy: chunkSize, limitedBy: document.text.endIndex) ?? document.text.endIndex
            let chunkText = String(document.text[start..<end])
            let digest = DeterministicHasher.hexDigest(chunkText)
            let chunkID = "chunk-\(chunks.count)-\(digest)"
            let length = chunkText.count
            chunks.append(Chunk(chunkID: chunkID, offset: offset, length: length, text: chunkText, digest: digest))
            start = end
            offset += length
        }
        return chunks
    }
}

private struct EmbeddingIndexCapsule: GatedCapsule {
    let descriptor = CapsuleDescriptor(
        id: "capsule.embedding.index",
        name: "EmbeddingIndexCapsule",
        version: "1.0.0",
        gateStatus: .gated
    )

    func embed(chunks: [Chunk]) -> [EmbeddingRecord] {
        chunks.map { chunk in
            let vector = DeterministicHasher.embeddingVector(for: chunk.text, dimensions: 6)
            let digest = DeterministicHasher.hexDigest("\(chunk.chunkID)|\(vector.map { String(format: "%.4f", $0) }.joined(separator: ","))")
            return EmbeddingRecord(chunkID: chunk.chunkID, vector: vector, digest: digest)
        }
    }
}

private struct RankFusionCapsule: GatedCapsule {
    let descriptor = CapsuleDescriptor(
        id: "capsule.rank.fusion",
        name: "RankFusionCapsule",
        version: "1.0.0",
        gateStatus: .gated
    )

    func rank(chunks: [Chunk], embeddings: [EmbeddingRecord], instruction: String) -> [RankedChunk] {
        let queryVector = DeterministicHasher.embeddingVector(for: instruction, dimensions: 6)
        let queryTokens = Tokenizer.tokens(from: instruction)
        let embeddingLookup = Dictionary(uniqueKeysWithValues: embeddings.map { ($0.chunkID, $0.vector) })

        let ranked = chunks.map { chunk -> RankedChunk in
            let chunkTokens = Tokenizer.tokens(from: chunk.text)
            let lexicalMatches = queryTokens.filter { chunkTokens.contains($0) }.count
            let lexicalScore = queryTokens.isEmpty ? 0.0 : Double(lexicalMatches) / Double(queryTokens.count)
            let embeddingScore = VectorMath.cosineSimilarity(queryVector, embeddingLookup[chunk.chunkID] ?? [])
            let fused = (0.7 * embeddingScore) + (0.3 * lexicalScore)
            return RankedChunk(chunkID: chunk.chunkID, fusedScore: fused, lexicalScore: lexicalScore, embeddingScore: embeddingScore)
        }

        return ranked.sorted { $0.fusedScore > $1.fusedScore }
    }
}

private struct RenderPlanCapsule: GatedCapsule {
    let descriptor = CapsuleDescriptor(
        id: "capsule.render.plan",
        name: "RenderPlanCapsule",
        version: "1.0.0",
        gateStatus: .gated
    )

    func render(document: IngestedDocument, rankings: [RankedChunk], instruction: String) -> RenderPlan {
        let topRanked = rankings.prefix(3)
        let sections = topRanked.enumerated().map { index, ranked in
            let title = "Section \(index + 1)"
            let highlight = "Chunk \(ranked.chunkID) aligned to instruction"
            return RenderPlanSection(
                chunkID: ranked.chunkID,
                title: title,
                highlight: highlight,
                score: ranked.fusedScore
            )
        }
        let digestSeed = "\(document.documentID)|\(instruction)|\(sections.map { $0.chunkID }.joined(separator: ","))"
        let planID = "plan-\(DeterministicHasher.hexDigest(digestSeed))"
        let summary = "Render plan for \(document.sourcePath) with \(sections.count) sections"
        return RenderPlan(planID: planID, instruction: instruction, summary: summary, sections: sections)
    }
}

private enum Tokenizer {
    static func tokens(from text: String) -> [String] {
        let allowed = CharacterSet.alphanumerics
        return text
            .lowercased()
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
    }
}

private enum VectorMath {
    static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard !lhs.isEmpty, lhs.count == rhs.count else { return 0.0 }
        let dot = zip(lhs, rhs).reduce(0.0) { $0 + ($1.0 * $1.1) }
        let lhsNorm = sqrt(lhs.reduce(0.0) { $0 + ($1 * $1) })
        let rhsNorm = sqrt(rhs.reduce(0.0) { $0 + ($1 * $1) })
        guard lhsNorm > 0, rhsNorm > 0 else { return 0.0 }
        return dot / (lhsNorm * rhsNorm)
    }
}

private enum DeterministicHasher {
    static func hexDigest(_ text: String) -> String {
        hexDigest(Data(text.utf8))
    }

    static func hexDigest(_ data: Data) -> String {
        let hash = fnv1a64(data)
        return String(format: "%016llx", hash)
    }

    static func embeddingVector(for text: String, dimensions: Int) -> [Double] {
        let seed = fnv1a64(Data(text.utf8))
        var values: [Double] = []
        values.reserveCapacity(dimensions)
        for index in 0..<dimensions {
            let shift = UInt64(index * 8)
            let byte = Double((seed >> shift) & 0xFF) / 255.0
            values.append(byte)
        }
        let norm = sqrt(values.reduce(0.0) { $0 + ($1 * $1) })
        guard norm > 0 else { return values }
        return values.map { $0 / norm }
    }

    private static func fnv1a64(_ data: Data) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }
}
