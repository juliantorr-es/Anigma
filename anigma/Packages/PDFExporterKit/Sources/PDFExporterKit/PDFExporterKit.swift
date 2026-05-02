// PDFExporterKit - Canonical artifacts and models for print-ready book export
//
// This module provides the canonical artifact definitions and data models
// for the PDF exporter pipeline. It extends DocumentIRKit with book-specific
// nodes and provides deterministic artifact schemas for the entire export
// pipeline.

@_exported import Foundation
@_exported import DocumentIRKit

/// Main module export
public enum PDFExporterKit {
    /// Module version
    public static let version = "1.0.0"
    
    /// Module identifier
    public static let identifier = "com.anigma.pdfexporterkit"
}

// MARK: - Re-export Artifacts

// Book project and document artifacts
public typealias BookProjectManifest = PDFExporterKit.BookProjectManifest
public typealias BookDocIR = PDFExporterKit.BookDocIR
public typealias BookNodeID = PDFExporterKit.BookNodeID

// Style and configuration artifacts
public typealias StyleBundle = PDFExporterKit.StyleBundle
public typealias LaTeXSourcePackage = PDFExporterKit.LaTeXSourcePackage

// Build and toolchain artifacts
public typealias BuildReport = PDFExporterKit.BuildReport
public typealias ToolchainReceipt = PDFExporterKit.ToolchainReceipt

// Supporting types
public typealias BookIdentity = PDFExporterKit.BookIdentity
public typealias PaperSize = PDFExporterKit.PaperSize
public typealias TrimSize = PDFExporterKit.TrimSize
public typealias PageMargins = PDFExporterKit.PageMargins
public typealias BindingType = PDFExporterKit.BindingType
public typealias PrintMode = PDFExporterKit.PrintMode
public typealias OutputIntent = PDFExporterKit.OutputIntent

// Node types
public typealias TitlePageNode = PDFExporterKit.TitlePageNode
public typealias CopyrightPageNode = PDFExporterKit.CopyrightPageNode
public typealias DedicationNode = PDFExporterKit.DedicationNode
public typealias EpigraphNode = PDFExporterKit.EpigraphNode
public typealias PrefaceNode = PDFExporterKit.PrefaceNode
public typealias TableOfContentsNode = PDFExporterKit.TableOfContentsNode
public typealias ChapterNode = PDFExporterKit.ChapterNode
public typealias AppendixNode = PDFExporterKit.AppendixNode
public typealias BibliographyNode = PDFExporterKit.BibliographyNode
public typealias IndexNode = PDFExporterKit.IndexNode
public typealias ColophonNode = PDFExporterKit.ColophonNode
public typealias FloatNode = PDFExporterKit.FloatNode
public typealias CrossReferenceNode = PDFExporterKit.CrossReferenceNode
public typealias IndexTermNode = PDFExporterKit.IndexTermNode

// Build report types
public typealias ExportWarning = PDFExporterKit.ExportWarning
public typealias ExportError = PDFExporterKit.ExportError
public typealias PrintReadinessStatus = PDFExporterKit.PrintReadinessStatus
public typealias ExportMetrics = PDFExporterKit.ExportMetrics

// Toolchain types
public typealias ToolchainType = PDFExporterKit.ToolchainType
public typealias ToolchainConfig = PDFExporterKit.ToolchainConfig
public typealias Platform = PDFExporterKit.Platform
public typealias Dependency = PDFExporterKit.Dependency

// MARK: - AnyCodable (canonicalized to AnigmaPrimitives)

// Use the canonical AnyCodable from AnigmaPrimitives
// See: Packages/AnigmaPrimitives/Sources/AnigmaPrimitives/AnyCodable.swift
import AnigmaPrimitives

public typealias AnyCodable = AnigmaPrimitives.AnyCodable
}

// MARK: - Convenience Extensions

extension BookProjectManifest {
    /// Create a simple manifest for testing
    public static func testManifest(
        title: String = "Test Book",
        authors: [String] = ["Test Author"],
        chunkCount: Int = 1
    ) -> BookProjectManifest {
        let chunkRefs = (0..<chunkCount).map { index in
            ChunkReference(
                id: "chunk-\(index)",
                contentHash: "hash-\(index)",
                order: index
            )
        }
        
        return BookProjectManifest(
            bookIdentity: BookIdentity(
                title: title,
                authors: authors
            ),
            revision: "test-\(UUID().uuidString)",
            locale: LocaleIdentifier("en_US"),
            language: LanguageCode("en"),
            paperSize: PaperSize(standard: .letter),
            trimSize: TrimSize(
                width: Measurement(value: 6, unit: .inches),
                height: Measurement(value: 9, unit: .inches)
            ),
            margins: PageMargins(
                top: Measurement(value: 1, unit: .inches),
                bottom: Measurement(value: 1, unit: .inches),
                inner: Measurement(value: 1.25, unit: .inches),
                outer: Measurement(value: 0.75, unit: .inches)
            ),
            bindingType: .perfectBound,
            printMode: .duplexLongEdge,
            outputIntent: .homePrint,
            styleProfileId: "default",
            chunkRefs: chunkRefs,
            assetRefs: []
        )
    }
}

extension BookDocIR {
    /// Create a simple book document for testing
    public static func testDocument(
        chapterCount: Int = 1,
        includeFrontMatter: Bool = true,
        includeBackMatter: Bool = false
    ) -> BookDocIR {
        let metadata = DocumentIRNode.DocumentMetadata(
            title: "Test Book",
            author: "Test Author",
            date: Date(),
            language: "en",
            properties: [:]
        )
        
        var frontMatter: [FrontMatterNode] = []
        if includeFrontMatter {
            frontMatter.append(.titlePage(TitlePageNode(
                id: BookNodeID(sourceChunkID: "front", localPath: [0], nodeType: "titlePage"),
                title: "Test Book",
                authors: ["Test Author"]
            )))
        }
        
        let chapters = (0..<chapterCount).map { index in
            ChapterNode(
                id: BookNodeID(sourceChunkID: "chapter-\(index)", localPath: [index], nodeType: "chapter"),
                number: index + 1,
                title: "Chapter \(index + 1)",
                children: [
                    .paragraph(DocumentIRNode.ParagraphNode(
                        content: [
                            .text(DocumentIRNode.InlineTextNode(text: "This is chapter \(index + 1). "))
                        ]
                    ))
                ]
            )
        }
        
        var backMatter: [BackMatterNode] = []
        if includeBackMatter {
            backMatter.append(.bibliography(BibliographyNode(
                id: BookNodeID(sourceChunkID: "back", localPath: [0], nodeType: "bibliography"),
                entries: []
            )))
        }
        
        return BookDocIR(
            metadata: metadata,
            frontMatter: frontMatter,
            chapters: chapters,
            backMatter: backMatter
        )
    }
}

extension StyleBundle {
    /// Create a default style bundle for testing
    public static var defaultBundle: StyleBundle {
        StyleBundle(
            id: "default",
            latexClass: "scrbook",
            packages: [
                LaTeXPackage(name: "fontspec"),
                LaTeXPackage(name: "microtype"),
                LaTeXPackage(name: "hyperref"),
                LaTeXPackage(name: "graphicx"),
                LaTeXPackage(name: "booktabs"),
                LaTeXPackage(name: "listings")
            ],
            fontSet: FontSet(
                bodyFont: FontSet.FontSpecification(
                    family: "Latin Modern Roman",
                    size: Measurement(value: 11, unit: .points)
                ),
                headingFont: FontSet.FontSpecification(
                    family: "Latin Modern Sans",
                    weight: .bold
                ),
                monospaceFont: FontSet.FontSpecification(
                    family: "Latin Modern Mono"
                ),
                loadingStrategy: .embedded
            )
        )
    }
}

extension BuildReport {
    /// Create a successful build report for testing
    public static func successfulReport(pageCount: Int = 100) -> BuildReport {
        BuildReport(
            compilationPasses: [
                CompilationPass(
                    number: 1,
                    engine: .tectonic,
                    arguments: ["--keep-intermediates", "--outdir=build"],
                    exitCode: 0,
                    stabilized: true,
                    duration: 2.5
                )
            ],
            printReadiness: .ready,
            metrics: ExportMetrics(
                pageCount: pageCount,
                totalCompilationTime: 2.5,
                passCount: 1,
                pdfFileSize: 1024 * 1024, // 1MB
                embeddedFonts: 3,
                embeddedImages: 5
            ),
            source: .texCompiler
        )
    }
    
    /// Create a report with warnings for testing
    public static func warningReport() -> BuildReport {
        BuildReport(
            warnings: [
                ExportWarning(
                    type: .overfullBox,
                    severity: .medium,
                    message: "Overfull \\hbox (1.2pt too wide) in paragraph at lines 42--45",
                    sourceLocation: ExportWarning.SourceLocation(
                        file: "chapter1.tex",
                        line: 42,
                        chunkID: "chunk-1",
                        nodeID: "paragraph-42"
                    ),
                    blockingInStrictMode: true,
                    suggestion: "Consider rephrasing or adding a hyphenation point."
                )
            ],
            printReadiness: .needsAttention,
            metrics: ExportMetrics(
                pageCount: 100,
                overfullBoxCount: 1,
                totalCompilationTime: 3.0,
                passCount: 2
            ),
            source: .texCompiler
        )
    }
}

// MARK: - Unit Conversion Helpers

extension UnitLength {
    /// Points (1/72 inch)
    public static let points = UnitLength(symbol: "pt", converter: UnitConverterLinear(coefficient: 1/72.0))
    
    /// Inches
    public static let inches = UnitLength(symbol: "in", converter: UnitConverterLinear(coefficient: 1.0))
    
    /// Centimeters
    public static let centimeters = UnitLength(symbol: "cm", converter: UnitConverterLinear(coefficient: 2.54))
    
    /// Millimeters
    public static let millimeters = UnitLength(symbol: "mm", converter: UnitConverterLinear(coefficient: 25.4))
    
    /// Picas (1/6 inch)
    public static let picas = UnitLength(symbol: "pc", converter: UnitConverterLinear(coefficient: 1/6.0))
}

// MARK: - Error Extensions

extension ExportError {
    /// Create a missing asset error
    public static func missingAsset(
        path: String,
        sourceLocation: ExportWarning.SourceLocation? = nil
    ) -> ExportError {
        ExportError(
            type: .missingAsset,
            message: "Missing asset: \(path)",
            sourceLocation: sourceLocation,
            suggestion: "Ensure the asset exists in the vault or provide a valid path."
        )
    }
    
    /// Create an unresolved reference error
    public static func unresolvedReference(
        label: String,
        sourceLocation: ExportWarning.SourceLocation? = nil
    ) -> ExportError {
        ExportError(
            type: .undefinedControlSequence,
            message: "Unresolved reference: \(label)",
            sourceLocation: sourceLocation,
            suggestion: "Check that the referenced label exists and is spelled correctly."
        )
    }
}

extension ExportWarning {
    /// Create an overfull box warning
    public static func overfullBox(
        width: Double,
        sourceLocation: SourceLocation? = nil,
        line: Int? = nil
    ) -> ExportWarning {
        ExportWarning(
            type: .overfullBox,
            severity: .medium,
            message: String(format: "Overfull \\hbox (%.1fpt too wide)", width),
            sourceLocation: sourceLocation,
            logLine: line,
            blockingInStrictMode: true,
            suggestion: "Consider rephrasing, adding hyphenation, or adjusting margins."
        )
    }
    
    /// Create a font substitution warning
    public static func fontSubstitution(
        requested: String,
        substituted: String,
        sourceLocation: SourceLocation? = nil
    ) -> ExportWarning {
        ExportWarning(
            type: .fontSubstitution,
            severity: .high,
            message: "Font substitution: '\(requested)' -> '\(substituted)'",
            sourceLocation: sourceLocation,
            blockingInStrictMode: true,
            suggestion: "Embed the requested font or use a different font that is available."
        )
    }
}
