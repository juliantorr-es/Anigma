import Foundation
import PDFExporterKit
import BookAssemblerCapsule
import ChunkNormalizerCapsule

public struct ExportResult: Sendable, Codable {
    public let bookDocIR: BookDocIR
    public let layoutAnalysis: LayoutAnalysisResult?

    public init(bookDocIR: BookDocIR, layoutAnalysis: LayoutAnalysisResult? = nil) {
        self.bookDocIR = bookDocIR
        self.layoutAnalysis = layoutAnalysis
    }
}

public actor BookExportCapsule {
    private let bookAssembler: BookAssemblerCapsule

    public init(bookAssembler: BookAssemblerCapsule = try! BookAssemblerCapsule()) throws {
        self.bookAssembler = bookAssembler
    }

    public func export(
        manifest: BookProjectManifest,
        chunks: [NormalizedChunk],
        sourcePDF: Data? = nil
    ) async throws -> ExportResult {
        _ = sourcePDF
        let chunkSet = ChunkSet(chunks: chunks)
        let doc = try await bookAssembler.assemble(chunkSet: chunkSet, manifest: manifest)
        return ExportResult(bookDocIR: doc)
    }
}
