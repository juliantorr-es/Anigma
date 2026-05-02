// BookExportCapsule - Main export capsule for PDF exporter pipeline
//
// This capsule orchestrates the entire PDF export process, from layout analysis
// through to final PDF generation. It integrates with the LayoutEngineCapsule
// to provide enhanced document structure understanding and content placement.

import Foundation
import CapsuleCore
import TelemetryCore
import PDFExporterKit
import BookAssemblerCapsule
import ChunkNormalizerCapsule
import LayoutEngineCapsule
import AnigmaPrimitives

/// Main export capsule for PDF exporter pipeline
public actor BookExportCapsule: IdentifiableCapsule {
    private let layoutAnalyzer: LayoutAnalyzerCapsule?
    private let chunkNormalizer: ChunkNormalizerCapsule
    private let bookAssembler: BookAssemblerCapsule
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "book-export-v1"
    
    /// Initialize the book export capsule
    ///
    /// - Parameters:
    ///   - layoutAnalyzer: Optional layout analyzer for source PDF analysis
    ///   - chunkNormalizer: Chunk normalizer capsule
    ///   - bookAssembler: Book assembler capsule
    ///   - diagnostics: Optional diagnostics provider
    /// - Throws: If initialization fails
    public init(
        layoutAnalyzer: LayoutAnalyzerCapsule? = nil,
        chunkNormalizer: ChunkNormalizerCapsule = try! ChunkNormalizerCapsule(),
        bookAssembler: BookAssemblerCapsule = try! BookAssemblerCapsule(),
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "BookExportCapsule.init",
            category: "pdfexporter.export.init",
            correlationID: nil,
            tags: [
                "algorithm_version": Self.algorithmVersion,
                "has_layout_analyzer": "\(layoutAnalyzer != nil)"
            ]
        )
        
        do {
            self.layoutAnalyzer = layoutAnalyzer
            self.chunkNormalizer = chunkNormalizer
            self.bookAssembler = bookAssembler
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "pdfexporter.export.init",
                message: "Failed to initialize book export capsule: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Export a book project to PDF
    ///
    /// - Parameters:
    ///   - manifest: Book project manifest
    ///   - chunks: Source chunks
    ///   - sourcePDF: Optional source PDF for layout analysis
    /// - Returns: Tuple containing export result and capsule receipt
    /// - Throws: If export fails
    public func export(
        manifest: BookProjectManifest,
        chunks: [NormalizedChunk],
        sourcePDF: Data? = nil
    ) async throws -> (ExportResult, CapsuleReceipt) {
        let span = diagnostics.beginSpan(
            name: "BookExportCapsule.export",
            category: "pdfexporter.export.export",
            correlationID: nil,
            tags: [
                "manifest_id": manifest.id.uuidString,
                "chunk_count": chunks.count,
                "has_source_pdf": "\(sourcePDF != nil)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            // Step 1: Perform layout analysis if source PDF provided
            var layoutAnalysis: LayoutAnalysisResult?
            if let sourcePDF = sourcePDF, let analyzer = layoutAnalyzer {
                (layoutAnalysis, _) = try await analyzer.analyzeSourcePDF(
                    data: sourcePDF,
                    manifest: manifest
                )
                
                diagnostics.event(
                    level: .info,
                    category: "pdfexporter.export.export",
                    message: "Layout analysis completed",
                    correlationID: nil,
                    tags: [
                        "page_count": "\(layoutAnalysis.pageCount)",
                        "header_count": "\(layoutAnalysis.headers.count)",
                        "table_count": "\(layoutAnalysis.tables.count)"
                    ]
                )
            }
            
            // Step 2: Normalize chunks
            let chunkSet = try chunkNormalizer.normalize(chunks: chunks)
            
            // Step 3: Assemble book with layout information
            let (docIR, assemblyReceipt) = try await bookAssembler.assemble(
                chunkSet: chunkSet,
                manifest: manifest,
                layoutAnalysis: layoutAnalysis
            )
            
            // Step 4: Create export result
            let result = ExportResult(
                bookDocIR: docIR,
                layoutAnalysis: layoutAnalysis,
                assemblyReceipt: assemblyReceipt
            )
            
            // Step 5: Generate final receipt
            let receipt = try await generateReceipt(
                manifest: manifest,
                chunks: chunks,
                sourcePDF: sourcePDF,
                layoutAnalysis: layoutAnalysis,
                assemblyReceipt: assemblyReceipt,
                result: result
            )
            
            diagnostics.event(
                level: .info,
                category: "pdfexporter.export.export",
                message: "Export completed successfully",
                correlationID: nil,
                tags: [
                    "node_count": "\(result.bookDocIR.allNodeIDs.count)",
                    "chapter_count": "\(result.bookDocIR.chapters.count)"
                ]
            )
            
            span.end(status: .ok)
            return (result, receipt)
        } catch {
            diagnostics.event(
                level: .error,
                category: "pdfexporter.export.export",
                message: "Export failed: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Generate export receipt
    ///
    /// - Parameters:
    ///   - manifest: Book project manifest
    ///   - chunks: Source chunks
    ///   - sourcePDF: Optional source PDF
    ///   - layoutAnalysis: Optional layout analysis
    ///   - assemblyReceipt: Assembly receipt
    ///   - result: Export result
    /// - Returns: Capsule receipt
    /// - Throws: If receipt generation fails
    private func generateReceipt(
        manifest: BookProjectManifest,
        chunks: [NormalizedChunk],
        sourcePDF: Data?,
        layoutAnalysis: LayoutAnalysisResult?,
        assemblyReceipt: CapsuleReceipt,
        result: ExportResult
    ) throws -> CapsuleReceipt {
        CapsuleReceipt(
            capsuleID: id,
            operation: "export",
            inputHashes: [
                manifest.id.uuidString,
                chunks.map { $0.id }.joined(separator: "|"),
                sourcePDF != nil ? BLAKE3Digest.hex(of: sourcePDF!) : "no-source-pdf"
            ],
            outputHashes: [
                result.bookDocIR.allNodeIDs.map { $0.labelString }.joined(separator: "|")
            ],
            metadata: [
                "manifest_id": manifest.id.uuidString,
                "chunk_count": chunks.count,
                "node_count": result.bookDocIR.allNodeIDs.count,
                "chapter_count": result.bookDocIR.chapters.count,
                "front_matter_count": result.bookDocIR.frontMatter.count,
                "back_matter_count": result.bookDocIR.backMatter.count,
                "has_source_pdf": "\(sourcePDF != nil)",
                "layout_analyzed": "\(layoutAnalysis != nil)",
                "header_count": "\(layoutAnalysis?.headers.count ?? 0)",
                "table_count": "\(layoutAnalysis?.tables.count ?? 0)",
                "figure_count": "\(layoutAnalysis?.figures.count ?? 0)",
                "section_count": "\(layoutAnalysis?.documentStructure.sections.count ?? 0)",
                "algorithm_version": Self.algorithmVersion
            ],
            createdAt: Date()
        )
    }
}

// MARK: - Supporting Types

/// Export result containing assembled document and metadata
public struct ExportResult: Sendable {
    /// Assembled book document
    public let bookDocIR: BookDocIR
    
    /// Optional layout analysis from source PDF
    public let layoutAnalysis: LayoutAnalysisResult?
    
    /// Assembly receipt
    public let assemblyReceipt: CapsuleReceipt
    
    /// Initialize new export result
    ///
    /// - Parameters:
    ///   - bookDocIR: Assembled book document
    ///   - layoutAnalysis: Optional layout analysis
    ///   - assemblyReceipt: Assembly receipt
    public init(
        bookDocIR: BookDocIR,
        layoutAnalysis: LayoutAnalysisResult? = nil,
        assemblyReceipt: CapsuleReceipt
    ) {
        self.bookDocIR = bookDocIR
        self.layoutAnalysis = layoutAnalysis
        self.assemblyReceipt = assemblyReceipt
    }
}

// MARK: - Extension for PDFExporterKit

extension PDFExporterKit {
    /// Export types
    public typealias ExportResult = BookExportCapsule.ExportResult
}
