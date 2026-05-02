import Foundation
import CapsuleCore
import TelemetryCore
import PDFExporterKit
import DocumentIRKit
import ChunkNormalizerCapsule
import Collections

/// A capsule that assembles normalized chunks into a BookDocIR for print-ready export.
/// Generates deterministic node IDs and validates book structure.
public actor BookAssemblerCapsule: IdentifiableCapsule {
    /// Unique capsule identifier
    public nonisolated let id: CapsuleID
    
    /// Capsule configuration
    private let config: BookAssemblerConfig
    
    /// Diagnostics collector
    private let diagnostics: DiagnosticsCollector
    
    /// Telemetry service
    private let telemetry: TelemetryService
    
    /// Cache for assembled documents (manifest hash -> BookDocIR)
    private var cache: [String: BookDocIR]
    
    /// Node ID generator
    private let nodeIDGenerator: NodeIDGenerator
    
    /// Statistics
    private var stats: ProcessingStats
    
    /// Initializes the book assembler capsule
    public init(
        id: CapsuleID = CapsuleID(domain: "pdf.export", name: "book-assembler"),
        config: BookAssemblerConfig = .default,
        diagnostics: DiagnosticsCollector = .init(),
        telemetry: TelemetryService = .shared
    ) {
        self.id = id
        self.config = config
        self.diagnostics = diagnostics
        self.telemetry = telemetry
        self.cache = [:]
        self.nodeIDGenerator = NodeIDGenerator(strategy: config.nodeIDStrategy)
        self.stats = ProcessingStats()
    }
    
    /// Assembles normalized chunks into a BookDocIR
    ///
    /// - Parameters:
    ///   - chunkSet: Normalized chunks to assemble
    ///   - manifest: Book project manifest
    ///   - layoutAnalysis: Optional layout analysis from source PDF (enhances assembly)
    /// - Returns: Tuple containing assembled BookDocIR and capsule receipt
    public func assemble(
        chunkSet: ChunkSet,
        manifest: BookProjectManifest,
        layoutAnalysis: LayoutAnalysisResult? = nil
    ) async throws -> (BookDocIR, CapsuleReceipt) {
        let span = telemetry.startSpan(
            name: "book_assembler.assemble",
            attributes: [
                "chunk_count": chunkSet.chunks.count,
                "manifest_id": manifest.id.uuidString,
                "config_hash": configHash()
            ]
        )
        
        defer {
            span.end(attributes: [
                "processed_chunks": stats.processedChunks,
                "cached_documents": stats.cachedDocuments,
                "validation_errors": stats.validationErrors
            ])
        }
        
        do {
            // Check cache first
            let layoutHash = layoutAnalysis?.contentHash ?? "no-layout"
            let cacheKey = "\(manifest.id)-$chunkSet.contentHash)-$layoutHash)"
            if config.performance.cacheResults,
               let cached = cache[cacheKey] {
                stats.cachedDocuments += 1
                diagnostics.record(.info, message: "Using cached BookDocIR", metadata: ["cache_key": cacheKey])
                
                let receipt = try generateReceipt(
                    chunkSet: chunkSet,
                    manifest: manifest,
                    bookDocIR: cached,
                    errors: [],
                    fromCache: true,
                    layoutAnalysis: layoutAnalysis
                )
                
                return (cached, receipt)
            }
            
            // Validate inputs
            try validateInputs(chunkSet: chunkSet, manifest: manifest)
            
            // Process chunks in order
            var processingErrors: [AssemblyError] = []
            var assembledChunks: [AssembledChunk] = []
            
            for chunk in chunkSet.chunks.sorted(by: { $0.id < $1.id }) {
                do {
                    let assembled = try assembleChunk(chunk, manifest: manifest)
                    assembledChunks.append(assembled)
                    stats.processedChunks += 1
                } catch let error as AssemblyError {
                    processingErrors.append(error)
                    stats.validationErrors += 1
                } catch {
                    processingErrors.append(AssemblyError(
                        chunkID: chunk.id,
                        errorType: .internalError,
                        message: "Unexpected error: \(error)",
                        recoverable: config.errorHandling.maxAllowedErrors > processingErrors.count
                    ))
                    stats.validationErrors += 1
                }
            }
            
            // Check error threshold
            if processingErrors.count > config.errorHandling.maxAllowedErrors {
                throw CapsuleError.operationFailed(
                    "Exceeded maximum allowed errors: \(processingErrors.count)",
                    underlyingErrors: processingErrors.map { $0.asCapsuleError() }
                )
            }
            
            // Build document structure
            let bookDocIR = try buildDocumentStructure(
                assembledChunks: assembledChunks,
                manifest: manifest,
                errors: processingErrors
            )
            
            // Update cache
            if config.performance.cacheResults,
               cache.count < config.performance.maxCacheSize {
                cache[cacheKey] = bookDocIR
            }
            
            // Generate receipt
            let receipt = try generateReceipt(
                chunkSet: chunkSet,
                manifest: manifest,
                bookDocIR: bookDocIR,
                errors: processingErrors,
                fromCache: false,
                layoutAnalysis: layoutAnalysis
            )
            
            diagnostics.record(
                .info,
                message: "Assembled \(chunkSet.chunks.count) chunks into BookDocIR",
                metadata: [
                    "successful": assembledChunks.count,
                    "failed": processingErrors.count,
                    "total_nodes": bookDocIR.allNodeIDs.count
                ]
            )
            
            return (bookDocIR, receipt)
            
        } catch {
            span.recordError(error)
            diagnostics.record(.error, message: "Book assembly failed", error: error)
            throw error
        }
    }
    
    /// Validates input chunk set and manifest
    private func validateInputs(
        chunkSet: ChunkSet,
        manifest: BookProjectManifest
    ) throws {
        var validationErrors: [AssemblyError] = []
        
        // Check chunk references
        let manifestChunkIDs = Set(manifest.chunkRefs.map { $0.id })
        let chunkSetIDs = Set(chunkSet.chunks.map { $0.id })
        
        // Missing chunks in chunk set
        let missingChunks = manifestChunkIDs.subtracting(chunkSetIDs)
        if !missingChunks.isEmpty {
            let error = AssemblyError(
                chunkID: "manifest",
                errorType: .missingChunk,
                message: "Missing chunks referenced in manifest: \(missingChunks.joined(separator: ", "))",
                recoverable: !config.errorHandling.failOnMissingChunks
            )
            validationErrors.append(error)
        }
        
        // Extra chunks not in manifest
        let extraChunks = chunkSetIDs.subtracting(manifestChunkIDs)
        if !extraChunks.isEmpty {
            let error = AssemblyError(
                chunkID: "manifest",
                errorType: .extraChunk,
                message: "Extra chunks not in manifest: \(extraChunks.joined(separator: ", "))",
                recoverable: true  // Usually not critical
            )
            validationErrors.append(error)
        }
        
        // Validate manifest metadata
        if config.validation.validateMetadata {
            for requiredField in config.metadata.requiredMetadata {
                if manifest.bookIdentity.title.isEmpty && requiredField == "title" {
                    let error = AssemblyError(
                        chunkID: "manifest",
                        errorType: .invalidMetadata,
                        message: "Missing required metadata field: \(requiredField)",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                    validationErrors.append(error)
                }
            }
        }
        
        // Check error threshold
        if validationErrors.count > 0 {
            let criticalErrors = validationErrors.filter { !$0.recoverable }
            if !criticalErrors.isEmpty {
                throw CapsuleError.operationFailed(
                    "Input validation failed with \(criticalErrors.count) critical errors",
                    underlyingErrors: criticalErrors.map { $0.asCapsuleError() }
                )
            }
            
            if config.errorHandling.failOnValidationErrors {
                throw CapsuleError.operationFailed(
                    "Input validation failed with \(validationErrors.count) errors",
                    underlyingErrors: validationErrors.map { $0.asCapsuleError() }
                )
            }
        }
    }
    
    /// Assembles a single chunk into document nodes
    private func assembleChunk(
        _ chunk: NormalizedChunk,
        manifest: BookProjectManifest
    ) throws -> AssembledChunk {
        // Find chunk reference in manifest
        guard let chunkRef = manifest.chunkRefs.first(where: { $0.id == chunk.id }) else {
            throw AssemblyError(
                chunkID: chunk.id,
                errorType: .missingReference,
                message: "Chunk not found in manifest references",
                recoverable: !config.errorHandling.failOnMissingChunks
            )
        }
        
        // Parse chunk metadata
        let chunkMetadata = try parseChunkMetadata(chunk: chunk, chunkRef: chunkRef)
        
        // Determine node type based on metadata
        let nodeType = determineNodeType(chunkMetadata: chunkMetadata)
        
        // Generate deterministic node ID
        let nodeID = try nodeIDGenerator.generateID(
            for: chunk,
            type: nodeType,
            metadata: chunkMetadata
        )
        
        // Parse content into DocumentIR nodes
        let documentNodes = try parseContentIntoNodes(
            content: chunk.content,
            chunkID: chunk.id,
            nodeID: nodeID,
            metadata: chunkMetadata
        )
        
        return AssembledChunk(
            chunk: chunk,
            chunkRef: chunkRef,
            metadata: chunkMetadata,
            nodeType: nodeType,
            nodeID: nodeID,
            documentNodes: documentNodes,
            order: chunkRef.order
        )
    }
    
    /// Parses chunk metadata
    private func parseChunkMetadata(
        chunk: NormalizedChunk,
        chunkRef: ChunkReference
    ) throws -> ChunkMetadata {
        var metadata = chunk.metadata
        
        // Merge with chunk reference metadata
        if let refMetadata = chunkRef.metadata {
            if config.metadata.mergeMetadata {
                metadata.merge(refMetadata.properties) { current, _ in current }
            } else {
                metadata = refMetadata.properties
            }
        }
        
        // Apply default metadata
        for (key, value) in config.metadata.defaultMetadata {
            if metadata[key] == nil {
                metadata[key] = value
            }
        }
        
        // Validate metadata
        if config.validation.validateMetadata {
            try validateMetadata(metadata, forChunk: chunk.id)
        }
        
        return ChunkMetadata(
            properties: metadata,
            title: metadata["title"],
            chapterNumber: Int(metadata["chapter_number"] ?? ""),
            sectionNumber: Int(metadata["section_number"] ?? ""),
            tags: metadata["tags"]?.components(separatedBy: ",") ?? []
        )
    }
    
    /// Validates chunk metadata against rules
    private func validateMetadata(
        _ metadata: [String: String],
        forChunk chunkID: String
    ) throws {
        for (field, rule) in config.metadata.validationRules {
            guard let value = metadata[field] else {
                if rule.required {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Missing required metadata field: \(field)",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
                continue
            }
            
            switch rule.type {
            case .string:
                if let minLength = rule.minLength, value.count < minLength {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Field '\(field)' too short: \(value.count) characters (minimum: \(minLength))",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
                if let maxLength = rule.maxLength, value.count > maxLength {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Field '\(field)' too long: \(value.count) characters (maximum: \(maxLength))",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
                if let pattern = rule.pattern {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let range = NSRange(value.startIndex..<value.endIndex, in: value)
                    if regex.firstMatch(in: value, range: range) == nil {
                        throw AssemblyError(
                            chunkID: chunkID,
                            errorType: .invalidMetadata,
                            message: "Field '\(field)' doesn't match pattern: \(pattern)",
                            recoverable: !config.errorHandling.failOnInvalidMetadata
                        )
                    }
                }
                if let allowedValues = rule.allowedValues, !allowedValues.contains(value) {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Field '\(field)' has invalid value: \(value) (allowed: \(allowedValues.joined(separator: ", ")))",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
                
            case .integer:
                guard Int(value) != nil else {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Field '\(field)' must be an integer",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
                
            case .date:
                // Try ISO8601 format
                if ISO8601DateFormatter().date(from: value) == nil {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Field '\(field)' must be a valid ISO8601 date",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
                
            case .boolean:
                guard Bool(value) != nil else {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Field '\(field)' must be 'true' or 'false'",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
                
            case .url:
                guard URL(string: value) != nil else {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Field '\(field)' must be a valid URL",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
                
            case .email:
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                if !predicate.evaluate(with: value) {
                    throw AssemblyError(
                        chunkID: chunkID,
                        errorType: .invalidMetadata,
                        message: "Field '\(field)' must be a valid email address",
                        recoverable: !config.errorHandling.failOnInvalidMetadata
                    )
                }
            }
        }
    }
    
    /// Determines node type from chunk metadata
    private func determineNodeType(chunkMetadata: ChunkMetadata) -> NodeType {
        if chunkMetadata.chapterNumber != nil {
            return .chapter
        } else if chunkMetadata.sectionNumber != nil {
            return .section
        } else if let title = chunkMetadata.title {
            if title.lowercased().contains("appendix") {
                return .appendix
            } else if title.lowercased().contains("bibliography") {
                return .bibliography
            } else if title.lowercased().contains("index") {
                return .index
            } else if title.lowercased().contains("preface") ||
                      title.lowercased().contains("foreword") ||
                      title.lowercased().contains("introduction") {
                return .preface
            }
        }
        
        // Default to section
        return .section
    }
    
    /// Parses content into DocumentIR nodes
    private func parseContentIntoNodes(
        content: String,
        chunkID: String,
        nodeID: BookNodeID,
        metadata: ChunkMetadata
    ) throws -> [DocumentIRNode] {
        // For now, create a simple paragraph structure
        // In a full implementation, this would parse markdown or other formats
        
        var nodes: [DocumentIRNode] = []
        
        // Split into paragraphs
        let paragraphs = content.components(separatedBy: "\n\n")
        for (index, paragraph) in paragraphs.enumerated() {
            guard !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            let paragraphNode = DocumentIRNode.paragraph(
                DocumentIRNode.ParagraphNode(
                    content: [
                        .text(DocumentIRNode.InlineTextNode(text: paragraph))
                    ]
                )
            )
            
            nodes.append(paragraphNode)
        }
        
        // Add heading if we have a title
        if let title = metadata.title {
            let headingLevel = determineHeadingLevel(nodeType: determineNodeType(chunkMetadata: metadata))
            let headingNode = createHeadingNode(title: title, level: headingLevel)
            nodes.insert(headingNode, at: 0)
        }
        
        return nodes
    }
    
    /// Determines heading level based on node type
    private func determineHeadingLevel(nodeType: NodeType) -> Int {
        switch nodeType {
        case .chapter: return 1
        case .section: return 2
        case .appendix: return 1
        case .preface: return 1
        case .bibliography: return 1
        case .index: return 1
        }
    }
    
    /// Creates a heading node
    private func createHeadingNode(title: String, level: Int) -> DocumentIRNode {
        let inlineNodes: [DocumentIRNode.InlineNode] = [
            .text(DocumentIRNode.InlineTextNode(text: title))
        ]
        
        return DocumentIRNode.heading(
            DocumentIRNode.HeadingNode(
                level: level,
                content: inlineNodes
            )
        )
    }
    
    /// Builds complete document structure from assembled chunks
    private func buildDocumentStructure(
        assembledChunks: [AssembledChunk],
        manifest: BookProjectManifest,
        errors: [AssemblyError]
    ) throws -> BookDocIR {
        // Sort chunks by order
        let sortedChunks = assembledChunks.sorted { $0.order < $1.order }
        
        // Group by node type
        var chapters: [ChapterNode] = []
        var frontMatter: [BookDocIR.FrontMatterNode] = []
        var backMatter: [BookDocIR.BackMatterNode] = []
        
        for assembledChunk in sortedChunks {
            switch assembledChunk.nodeType {
            case .chapter:
                let chapter = try createChapterNode(from: assembledChunk, manifest: manifest)
                chapters.append(chapter)
                
            case .section:
                // Sections are handled within their parent chapters
                break
                
            case .preface:
                let preface = try createPrefaceNode(from: assembledChunk)
                frontMatter.append(.preface(preface))
                
            case .appendix:
                let appendix = try createAppendixNode(from: assembledChunk)
                backMatter.append(.appendix(appendix))
                
            case .bibliography:
                let bibliography = try createBibliographyNode(from: assembledChunk)
                backMatter.append(.bibliography(bibliography))
                
            case .index:
                let index = try createIndexNode(from: assembledChunk)
                backMatter.append(.index(index))
            }
        }
        
        // Add default front matter if needed
        if frontMatter.isEmpty {
            frontMatter.append(.titlePage(createTitlePageNode(manifest: manifest)))
            frontMatter.append(.tableOfContents(TableOfContentsNode(
                id: nodeIDGenerator.generateID(for: "toc", type: "tableOfContents"),
                depth: 3
            )))
        }
        
        // Create document metadata
        let documentMetadata = DocumentIRNode.DocumentMetadata(
            title: manifest.bookIdentity.title,
            author: manifest.bookIdentity.authors.joined(separator: ", "),
            date: Date(),
            language: manifest.language.code,
            properties: [:]
        )
        
        return BookDocIR(
            metadata: documentMetadata,
            frontMatter: frontMatter,
            chapters: chapters,
            backMatter: backMatter
        )
    }
    
    /// Creates a chapter node from assembled chunk
    private func createChapterNode(
        from assembledChunk: AssembledChunk,
        manifest: BookProjectManifest
    ) throws -> ChapterNode {
        ChapterNode(
            id: assembledChunk.nodeID,
            number: assembledChunk.metadata.chapterNumber,
            title: assembledChunk.metadata.title ?? "Chapter \(assembledChunk.metadata.chapterNumber ?? 0)",
            children: assembledChunk.documentNodes
        )
    }
    
    /// Creates a preface node from assembled chunk
    private func createPrefaceNode(from assembledChunk: AssembledChunk) throws -> PrefaceNode {
        PrefaceNode(
            id: assembledChunk.nodeID,
            title: assembledChunk.metadata.title ?? "Preface",
            children: assembledChunk.documentNodes
        )
    }
    
    /// Creates an appendix node from assembled chunk
    private func createAppendixNode(from assembledChunk: AssembledChunk) throws -> AppendixNode {
        let letter = assembledChunk.metadata.title?.first?.uppercased() ?? "A"
        return AppendixNode(
            id: assembledChunk.nodeID,
            letter: String(letter),
            title: assembledChunk.metadata.title ?? "Appendix \(letter)",
            children: assembledChunk.documentNodes
        )
    }
    
    /// Creates a bibliography node from assembled chunk
    private func createBibliographyNode(from assembledChunk: AssembledChunk) throws -> BibliographyNode {
        // Parse bibliography entries from content
        let entries = try parseBibliographyEntries(from: assembledChunk.chunk.content)
        
        return BibliographyNode(
            id: assembledChunk.nodeID,
            title: assembledChunk.metadata.title ?? "Bibliography",
            entries: entries
        )
    }
    
    /// Creates an index node from assembled chunk
    private func createIndexNode(from assembledChunk: AssembledChunk) throws -> IndexNode {
        // Parse index entries from content
        let entries = try parseIndexEntries(from: assembledChunk.chunk.content)
        
        return IndexNode(
            id: assembledChunk.nodeID,
            title: assembledChunk.metadata.title ?? "Index",
            entries: entries
        )
    }
    
    /// Creates a title page node from manifest
    private func createTitlePageNode(manifest: BookProjectManifest) -> TitlePageNode {
        TitlePageNode(
            id: nodeIDGenerator.generateID(for: "title", type: "titlePage"),
            title: manifest.bookIdentity.title,
            subtitle: manifest.bookIdentity.subtitle,
            authors: manifest.bookIdentity.authors,
            publisher: manifest.bookIdentity.publisher,
            date: Date()
        )
    }
    
    /// Parses bibliography entries from content
    private func parseBibliographyEntries(from content: String) throws -> [BibliographyNode.BibliographyEntry] {
        // Simplified implementation - in production, parse BibTeX or other formats
        return []
    }
    
    /// Parses index entries from content
    private func parseIndexEntries(from content: String) throws -> [IndexNode.IndexEntry] {
        // Simplified implementation - in production, parse index markup
        return []
    }
    
    /// Generates a capsule receipt
    private func generateReceipt(
        chunkSet: ChunkSet,
        manifest: BookProjectManifest,
        bookDocIR: BookDocIR,
        errors: [AssemblyError],
        fromCache: Bool,
        layoutAnalysis: LayoutAnalysisResult? = nil
    ) throws -> CapsuleReceipt {
        CapsuleReceipt(
            capsuleID: id,
            operation: "assemble",
            inputHashes: [chunkSet.contentHash, manifest.id.uuidString],
            outputHashes: [bookDocIR.allNodeIDs.map { $0.labelString }.joined(separator: "|")],
            metadata: [
                "chunk_count": chunkSet.chunks.count,
                "node_count": bookDocIR.allNodeIDs.count,
                "error_count": errors.count,
                "from_cache": fromCache,
                "config_hash": configHash(),
                "chapter_count": bookDocIR.chapters.count,
                "front_matter_count": bookDocIR.frontMatter.count,
                "back_matter_count": bookDocIR.backMatter.count,
                "layout_analyzed": layoutAnalysis != nil,
                "header_count": layoutAnalysis?.headers.count ?? 0,
                "table_count": layoutAnalysis?.tables.count ?? 0,
                "figure_count": layoutAnalysis?.figures.count ?? 0
            ],
            createdAt: Date()
        )
    }
    
    /// Computes a hash of the configuration
    private func configHash() -> String {
        let configData = try? JSONEncoder().encode(config)
        return configData?.base64EncodedString() ?? "unknown"
    }
}

// MARK: - Supporting Types

/// Node type enumeration
private enum NodeType: String, Sendable {
    case chapter = "chapter"
    case section = "section"
    case preface = "preface"
    case appendix = "appendix"
    case bibliography = "bibliography"
    case index = "index"
}

/// Assembled chunk with parsed structure
private struct AssembledChunk: Sendable {
    let chunk: NormalizedChunk
    let chunkRef: ChunkReference
    let metadata: ChunkMetadata
    let nodeType: NodeType
    let nodeID: BookNodeID
    let documentNodes: [DocumentIRNode]
    let order: Int
}

/// Chunk metadata
private struct ChunkMetadata: Sendable {
    let properties: [String: String]
    let title: String?
    let chapterNumber: Int?
    let sectionNumber: Int?
    let tags: [String]
}

/// Node ID generator
private struct NodeIDGenerator: Sendable {
    let strategy: NodeIDStrategy
    
    func generateID(
        for chunk: NormalizedChunk,
        type: NodeType,
        metadata: ChunkMetadata
    ) throws -> BookNodeID {
        var components: [String] = []
        
        if strategy.includeChunkID {
            components.append(chunk.id)
        }
        
        if strategy.includeLocalPath {
            // Use order from metadata if available
            if let chapterNumber = metadata.chapterNumber {
                components.append("ch\(chapterNumber)")
            }
            if let sectionNumber = metadata.sectionNumber {
                components.append("sec\(sectionNumber)")
            }
        }
        
        if strategy.includeNodeType {
            components.append(type.rawValue)
        }
        
        if strategy.includeContentHash {
            components.append(chunk.normalizedHash.prefix(8))
        }
        
        let idString = components.joined(separator: strategy.separator)
        
        return BookNodeID(
            sourceChunkID: chunk.id,
            localPath: [metadata.chapterNumber ?? 0, metadata.sectionNumber ?? 0],
            nodeType: type.rawValue
        )
    }
    
    func generateID(for identifier: String, type: String) -> BookNodeID {
        BookNodeID(
            sourceChunkID: identifier,
            localPath: [0],
            nodeType: type
        )
    }
}

/// Assembly error
private struct AssemblyError: Error, Sendable, CustomStringConvertible {
    enum ErrorType: String, Sendable, Codable {
        case missingChunk = "missing_chunk"
        case extraChunk = "extra_chunk"
        case missingReference = "missing_reference"
        case invalidMetadata = "invalid_metadata"
        case duplicateID = "duplicate_id"
        case validationError = "validation_error"
        case parsingError = "parsing_error"
        case internalError = "internal_error"
    }
    
    let chunkID: String
    let errorType: ErrorType
    let message: String
    let recoverable: Bool
    
    var description: String {
        return "Chunk \(chunkID): \(errorType.rawValue) - \(message)"
    }
    
    func asCapsuleError() -> CapsuleCore.Error {
        CapsuleCore.Error(
            code: "BOOK_ASSEMBLER_\(errorType.rawValue.uppercased())",
            message: message,
            metadata: ["chunk_id": chunkID, "recoverable": recoverable]
        )
    }
}

/// Processing statistics
private struct ProcessingStats: Sendable {
    var processedChunks: Int = 0
    var cachedDocuments: Int = 0
    var validationErrors: Int = 0
}