import Foundation
import PDFExporterKit
import ChunkNormalizerCapsule

public struct BookAssemblerConfig: Sendable, Codable {
    public static let `default` = BookAssemblerConfig()
    public init() {}
}

public actor BookAssemblerCapsule {
    public init(config: BookAssemblerConfig = .default) throws {
        _ = config
    }

    public func assemble(
        chunkSet: ChunkSet,
        manifest: BookProjectManifest,
        layoutAnalysis: LayoutAnalysisResult? = nil
    ) async throws -> BookDocIR {
        _ = manifest
        _ = layoutAnalysis
        return BookDocIR(allNodeIDs: chunkSet.chunks.map(\.id), chapters: chunkSet.chunks.map(\.normalizedContent))
    }
}
