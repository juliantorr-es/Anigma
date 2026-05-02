import Foundation
import Testing
@testable import AnigmaCLIDatabase
import AnigmaCLICore

private struct StubEmbeddingProvider: EmbeddingProvider {
    nonisolated let dimension: Int = 4
    nonisolated let name: String = "stub"

    func embed(text: String) async throws -> [Float] {
        [0.1, 0.2, 0.3, 0.4]
    }
}

struct RAGPipelinePromptAssemblyTests {
    @Test
    func shortContextKeepsLegacyAssembly() async throws {
        let pipeline = try await makePipeline()
        let context = [
            SearchResult(
                chunkId: "doc-1",
                content: "Short evidence chunk with grounding facts.",
                metadata: #"{"source_id":"README.md"}"#,
                similarity: 0.92,
                createdAt: Date()
            )
        ]

        let prompt = await pipeline.buildPrompt(query: "What changed?", context: context)

        #expect(prompt.contains("[1] Short evidence chunk with grounding facts."))
        #expect(!prompt.contains("[Context compression applied:"))
        #expect(!prompt.contains("source=README.md chunk_id=doc-1"))
    }

    @Test
    func longContextCompressesAndKeepsProvenance() async throws {
        let pipeline = try await makePipeline()
        let longBody = String(repeating: "retrieval-grounding-signal ", count: 700)
        let context = (0..<6).map { idx in
            SearchResult(
                chunkId: "doc-\(idx)",
                content: "Document \(idx)\n\(longBody)\nTail \(idx)",
                metadata: #"{"source_id":"file\#(idx).swift","path":"Sources/file\#(idx).swift"}"#,
                similarity: 0.9 - Float(idx) * 0.05,
                createdAt: Date()
            )
        }

        let prompt = await pipeline.buildPrompt(query: "Summarize all findings", context: context)

        #expect(prompt.contains("[Context compression applied:"))
        #expect(prompt.contains("source=file0.swift chunk_id=doc-0"))
        #expect(prompt.contains("source=file1.swift chunk_id=doc-1"))
        #expect(prompt.contains("...[compacted]..."))
    }

    @Test
    func longContextCompressionIsDeterministicForTiedScores() async throws {
        let pipeline = try await makePipeline()
        let longBody = String(repeating: "deterministic-grounding ", count: 900)
        let doc0 = SearchResult(
            chunkId: "doc-0",
            content: "Document 0\n\(longBody)\nTail 0",
            metadata: #"{"path":"Sources/file0.swift"}"#,
            similarity: 0.8,
            createdAt: Date()
        )
        let doc1 = SearchResult(
            chunkId: "doc-1",
            content: "Document 1\n\(longBody)\nTail 1",
            metadata: #"{"path":"Sources/file1.swift"}"#,
            similarity: 0.8,
            createdAt: Date()
        )
        let doc2 = SearchResult(
            chunkId: "doc-2",
            content: "Document 2\n\(longBody)\nTail 2",
            metadata: #"{"path":"Sources/file2.swift"}"#,
            similarity: 0.8,
            createdAt: Date()
        )

        let promptA = await pipeline.buildPrompt(query: "Summarize", context: [doc2, doc0, doc1])
        let promptB = await pipeline.buildPrompt(query: "Summarize", context: [doc1, doc2, doc0])

        #expect(promptA == promptB)
        #expect(promptA.contains("source=Sources/file0.swift chunk_id=doc-0"))
    }

    private func makePipeline() async throws -> RAGPipeline {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-rag-tests-\(UUID().uuidString).postgres")
        let vectorStore = try await CLIVectorStore(dbPath: dbURL.path, dimension: 4)
        return RAGPipeline(vectorStore: vectorStore, embeddingProvider: StubEmbeddingProvider())
    }
}
