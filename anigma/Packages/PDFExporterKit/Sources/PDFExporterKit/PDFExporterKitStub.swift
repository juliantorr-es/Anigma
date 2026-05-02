import Foundation

public enum PDFExporterKit {
    public static let version = "stub-v1"
    public static let identifier = "com.anigma.pdfexporterkit.stub"
}

public struct BookProjectManifest: Codable, Sendable {
    public var id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

public struct BookDocIR: Codable, Sendable {
    public var allNodeIDs: [String]
    public var chapters: [String]
    public var frontMatter: [String]
    public var backMatter: [String]

    public init(
        allNodeIDs: [String] = [],
        chapters: [String] = [],
        frontMatter: [String] = [],
        backMatter: [String] = []
    ) {
        self.allNodeIDs = allNodeIDs
        self.chapters = chapters
        self.frontMatter = frontMatter
        self.backMatter = backMatter
    }
}

public struct LayoutAnalysisResult: Codable, Sendable {
    public struct DocumentStructureInfo: Codable, Sendable {
        public var sections: [String]

        public init(sections: [String] = []) {
            self.sections = sections
        }
    }

    public var headers: [String]
    public var tables: [String]
    public var figures: [String]
    public var documentStructure: DocumentStructureInfo

    public init(
        headers: [String] = [],
        tables: [String] = [],
        figures: [String] = [],
        documentStructure: DocumentStructureInfo = .init()
    ) {
        self.headers = headers
        self.tables = tables
        self.figures = figures
        self.documentStructure = documentStructure
    }
}

public actor LayoutAnalyzerCapsule {
    public init() throws {}

    public func analyzeSourcePDF(
        data: Data,
        manifest: BookProjectManifest
    ) async throws -> LayoutAnalysisResult {
        _ = data
        _ = manifest
        return LayoutAnalysisResult()
    }
}
