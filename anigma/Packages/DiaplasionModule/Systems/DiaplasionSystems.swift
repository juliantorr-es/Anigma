//
//  DiaplasionSystems.swift
//  DiaplasionModule
//
//  Systems for Diaplasion alt-media transformation pipelines.
//
//  These systems use Apple frameworks (Vision, CoreGraphics, PDFKit)
//  to implement document processing without external dependencies.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
import TextChunkingCapsule
import AnigmaNativeShims
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Document Ingest System

/// System that ingests source documents and prepares them for OCR.
///
/// This system:
/// 1. Reads files from disk (PDF or image)
/// 2. Detects format using magic bytes
/// 3. Extracts page images for OCR processing
/// 4. Caches extracted images to a temp directory
///
/// **Input**: Entity with `FileComponent` pointing to a document file
/// **Output**: Adds `DocumentSourceComponent` and `IngestedDocumentComponent`
public struct DocumentIngestSystem: System {
    public var name: String { "DocumentIngest" }

    /// Directory for caching extracted page images.
    /// If nil, uses system temp directory.
    public let cacheDirectory: URL?

    /// DPI for rendering PDF pages to images. Default 150 is good for OCR.
    public let renderDPI: CGFloat

    public init(cacheDirectory: URL? = nil, renderDPI: CGFloat = 150) {
        self.cacheDirectory = cacheDirectory
        self.renderDPI = renderDPI
    }

    public func update(world: World) async {
        // Query for entities with FileComponent but no DocumentSourceComponent yet
        let files = await world.query(FileComponent.self)

        for (entity, fileComp) in files {
            // Skip if already ingested
            if await world.hasComponent(entity, DocumentSourceComponent.self) {
                continue
            }

            guard let path = fileComp.path else {
                await Logger.shared.warning("FileComponent has no path", category: "Diaplasion")
                continue
            }

            do {
                let result = try await ingestDocument(at: path)
                await world.addComponent(entity, result.source)
                await world.addComponent(entity, result.ingested)
                if let assets = result.assets {
                    await world.addComponent(entity, assets)
                }
                await Logger.shared.info("Ingested document: \(path)", category: "Diaplasion")
            } catch {
                await Logger.shared.error("Ingest failed for \(path): \(error)", category: "Diaplasion")
                // Add error state
                let errorComponent = IngestedDocumentComponent(
                    isComplete: false,
                    errors: [error.localizedDescription]
                )
                await world.addComponent(entity, errorComponent)

                let metadata = ingestErrorMetadata(for: error)
                await appendProcessingError(config: AppendProcessingErrorConfiguration(
                    world: world,
                    entity: entity,
                    stage: .ingest,
                    code: metadata.code,
                    message: error.localizedDescription,
                    retryPolicy: metadata.retryPolicy,
                    context: ["path": path]
                ))
            }
        }
    }

    // MARK: - Private Implementation

    private struct IngestResult {
        let source: DocumentSourceComponent
        let ingested: IngestedDocumentComponent
        let assets: DocumentAssetComponent?
    }

    private func ingestDocument(at path: String) async throws -> IngestResult {
        let url = URL(fileURLWithPath: path)

        // Check file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw DiaplasionError.fileNotFound(path: path)
        }

        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let fileSize = attributes[.size] as? Int64
        let contentHash = fileHash(at: url)

        // Detect format
        let format = try detectFormat(at: url)

        // Process based on format
        switch format {
        case .pdf:
            let result = try await ingestPDF(at: url, fileSize: fileSize, contentHash: contentHash)
            return IngestResult(source: result.source, ingested: result.ingested, assets: nil)
        case .jpeg, .png, .tiff, .gif, .bmp, .heic:
            let result = try await ingestImage(at: url, format: format, fileSize: fileSize, contentHash: contentHash)
            return IngestResult(source: result.source, ingested: result.ingested, assets: nil)
        case .docx, .html, .rtf, .plainText:
            return try ingestTextDocument(at: url, format: format, fileSize: fileSize, contentHash: contentHash)
        default:
            throw DiaplasionError.unsupportedFormat(format: format.rawValue)
        }
    }

    private func ingestTextDocument(
        at url: URL,
        format: DocumentFormat,
        fileSize: Int64?,
        contentHash: String?
    ) throws -> IngestResult {
        var assets: [DocumentAsset] = []
        let text: String

        switch format {
        case .plainText:
            text = try extractPlainText(at: url)
        case .html:
            text = try extractHTMLText(from: url)
        case .rtf:
            text = try extractRTFText(from: url)
        case .docx:
            let extracted = try extractDocx(from: url)
            text = extracted.text
            assets = extracted.assets
        default:
            throw DiaplasionError.unsupportedFormat(format: format.rawValue)
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var errors: [String] = []
        let isComplete = !trimmed.isEmpty
        if !isComplete {
            errors.append("Extracted text is empty")
        }

        let source = DocumentSourceComponent(
            sourceURI: url.path,
            format: format,
            pageCount: nil,
            fileSize: fileSize,
            contentHash: contentHash
        )

        let ingested = IngestedDocumentComponent(
            pageImagePaths: [],
            pageDimensions: [],
            textContent: text,
            isComplete: isComplete,
            errors: errors
        )

        let assetComponent = assets.isEmpty ? nil : DocumentAssetComponent(assets: assets)
        return IngestResult(source: source, ingested: ingested, assets: assetComponent)
    }

    private func ingestErrorMetadata(for error: Error) -> (code: String, retryPolicy: RetryPolicy) {
        if let diaplasionError = error as? DiaplasionError {
            switch diaplasionError {
            case .fileNotFound:
                return ("ingest.file_not_found", .noRetry)
            case .unsupportedFormat:
                return ("ingest.unsupported_format", .noRetry)
            case .docxExtractionFailed:
                return ("ingest.docx_extract_failed", .default)
            case .textExtractionFailed:
                return ("ingest.text_extract_failed", .default)
            default:
                return ("ingest.failed", .default)
            }
        }
        return ("ingest.failed", .default)
    }

    private func extractPlainText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let text = decodeText(data: data) {
            return text
        }
        throw DiaplasionError.textExtractionFailed(reason: "Unsupported text encoding")
    }

    private func extractHTMLText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        #if canImport(AppKit) || canImport(UIKit)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return try NSAttributedString(data: data, options: options, documentAttributes: nil).string
        #else
        let raw = decodeText(data: data) ?? ""
        return stripHTMLTags(raw)
        #endif
    }

    private func extractRTFText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        #if canImport(AppKit) || canImport(UIKit)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        return try NSAttributedString(data: data, options: options, documentAttributes: nil).string
        #else
        let raw = decodeText(data: data) ?? ""
        return stripRTFControls(raw)
        #endif
    }

    private struct DocxExtractionResult {
        let text: String
        let assets: [DocumentAsset]
    }

    private func extractDocx(from url: URL) throws -> DocxExtractionResult {
        let cacheDir = try getOrCreateCacheDirectory()
        let extractDir = cacheDir.appendingPathComponent("docx_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let unzipURL = URL(fileURLWithPath: "/usr/bin/unzip")
        guard FileManager.default.isExecutableFile(atPath: unzipURL.path) else {
            throw DiaplasionError.docxExtractionFailed(reason: "unzip tool not available")
        }

        let process = Process()
        process.executableURL = unzipURL
        process.arguments = ["-qq", url.path, "-d", extractDir.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DiaplasionError.docxExtractionFailed(reason: "unzip failed with status \(process.terminationStatus)")
        }

        let documentXML = extractDir.appendingPathComponent("word/document.xml")
        guard FileManager.default.fileExists(atPath: documentXML.path) else {
            throw DiaplasionError.docxExtractionFailed(reason: "word/document.xml missing")
        }

        let data = try Data(contentsOf: documentXML)
        let parserDelegate = DocxTextParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            let message = parser.parserError?.localizedDescription ?? "XML parse failed"
            throw DiaplasionError.docxExtractionFailed(reason: message)
        }

        let assets = try extractDocxAssets(from: extractDir)
        let text = parserDelegate.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return DocxExtractionResult(text: text, assets: assets)
    }

    private func extractDocxAssets(from directory: URL) throws -> [DocumentAsset] {
        let mediaDir = directory.appendingPathComponent("word/media")
        guard FileManager.default.fileExists(atPath: mediaDir.path) else {
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(at: mediaDir, includingPropertiesForKeys: [.isDirectoryKey])
        var assets: [DocumentAsset] = []

        for fileURL in fileURLs {
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                continue
            }
            let sourcePath = "word/media/\(fileURL.lastPathComponent)"
            let type = assetType(for: fileURL)
            let hash = fileHash(at: fileURL)
            let asset = DocumentAsset(
                sourcePath: sourcePath,
                assetPath: fileURL.path,
                mediaType: type,
                role: .embedded,
                contentHash: hash
            )
            assets.append(asset)
        }

        return assets
    }

    private final class DocxTextParser: NSObject, XMLParserDelegate {
        private(set) var text: String = ""
        private var inText = false

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes: [String: String] = [:]
        ) {
            if elementName.hasSuffix(":t") || elementName == "w:t" {
                inText = true
            } else if elementName.hasSuffix(":tab") || elementName == "w:tab" {
                text.append("\t")
            } else if elementName.hasSuffix(":br") || elementName == "w:br" {
                text.append("\n")
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inText {
                text.append(string)
            }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            if elementName.hasSuffix(":t") || elementName == "w:t" {
                inText = false
            } else if elementName.hasSuffix(":p") || elementName == "w:p" {
                if !text.hasSuffix("\n\n") {
                    text.append("\n\n")
                }
            }
        }
    }

    private func assetType(for url: URL) -> DocumentAssetType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic":
            return .image
        default:
            return .attachment
        }
    }

    private func decodeText(data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf16) {
            return text
        }
        if let text = String(data: data, encoding: .utf16LittleEndian) {
            return text
        }
        if let text = String(data: data, encoding: .utf16BigEndian) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        return String(data: data, encoding: .ascii)
    }

    private func stripHTMLTags(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        let stripped = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ")
        return stripped.replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private func stripRTFControls(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "{", with: "")
        result = result.replacingOccurrences(of: "}", with: "")
        guard let regex = try? NSRegularExpression(pattern: "\\\\[a-zA-Z]+-?\\d*\\s?", options: []) else {
            return result
        }
        let range = NSRange(result.startIndex..., in: result)
        return regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
    }

    /// Detects document format using magic bytes.
    private func detectFormat(at url: URL) throws -> DocumentFormat {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 8 else {
            // Fall back to extension
            return formatFromExtension(url.pathExtension)
        }

        let bytes = [UInt8](data.prefix(8))

        // PDF: %PDF
        if bytes.count >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46 {
            return .pdf
        }

        // JPEG: FF D8 FF
        if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return .jpeg
        }

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes.count >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return .png
        }

        // TIFF: 49 49 2A 00 (little endian) or 4D 4D 00 2A (big endian)
        if bytes.count >= 4 {
            if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
               (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {
                return .tiff
            }
        }

        // GIF: GIF87a or GIF89a
        if bytes.count >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return .gif
        }

        // BMP: BM
        if bytes.count >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D {
            return .bmp
        }

        // Fall back to extension
        return formatFromExtension(url.pathExtension)
    }

    private func formatFromExtension(_ ext: String) -> DocumentFormat {
        switch ext.lowercased() {
        case "pdf": return .pdf
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "tiff", "tif": return .tiff
        case "gif": return .gif
        case "bmp": return .bmp
        case "heic", "heif": return .heic
        case "docx": return .docx
        case "epub": return .epub
        case "html", "htm": return .html
        case "txt": return .plainText
        case "rtf": return .rtf
        default: return .unknown
        }
    }

    #if canImport(PDFKit)
    private func ingestPDF(
        at url: URL,
        fileSize: Int64?,
        contentHash: String?
    ) async throws -> (source: DocumentSourceComponent, ingested: IngestedDocumentComponent) {
        guard let document = PDFDocument(url: url) else {
            throw DiaplasionError.pdfLoadFailed(path: url.path)
        }

        let pageCount = document.pageCount
        let cacheDir = try getOrCreateCacheDirectory()

        var pageImagePaths: [String] = []
        var pageDimensions: [(width: Int, height: Int)] = []
        var errors: [String] = []

        // Scale factor for rendering (72 points per inch is PDF standard)
        let scale = renderDPI / 72.0

        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else {
                errors.append("Could not get page \(pageIndex + 1)")
                continue
            }

            let mediaBox = page.bounds(for: .mediaBox)
            let width = Int(mediaBox.width * scale)
            let height = Int(mediaBox.height * scale)

            // Render page to image using NSImage -> CGImage conversion on macOS
            #if canImport(AppKit)
            let thumbnail = page.thumbnail(of: CGSize(width: width, height: height), for: .mediaBox)
            // NSImage.cgImage is a method that takes parameters, we need to call it properly
            var imageRect = CGRect(x: 0, y: 0, width: thumbnail.size.width, height: thumbnail.size.height)
            if let cgImage = thumbnail.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) {
                let imagePath = cacheDir.appendingPathComponent("page_\(pageIndex + 1).png").path

                if saveCGImageAsPNG(cgImage, to: imagePath) {
                    pageImagePaths.append(imagePath)
                    pageDimensions.append((width: width, height: height))
                } else {
                    errors.append("Failed to save page \(pageIndex + 1) image")
                }
            } else {
                errors.append("Failed to render page \(pageIndex + 1)")
            }
            #elseif canImport(UIKit)
            let thumbnail = page.thumbnail(of: CGSize(width: width, height: height), for: .mediaBox)
            if let cgImage = thumbnail.cgImage {
                let imagePath = cacheDir.appendingPathComponent("page_\(pageIndex + 1).png").path

                if saveCGImageAsPNG(cgImage, to: imagePath) {
                    pageImagePaths.append(imagePath)
                    pageDimensions.append((width: width, height: height))
                } else {
                    errors.append("Failed to save page \(pageIndex + 1) image")
                }
            } else {
                errors.append("Failed to render page \(pageIndex + 1)")
            }
            #else
            errors.append("PDF rendering not supported on this platform")
            #endif
        }

        let source = DocumentSourceComponent(
            sourceURI: url.path,
            format: .pdf,
            pageCount: pageCount,
            fileSize: fileSize,
            contentHash: contentHash
        )

        let ingested = IngestedDocumentComponent(
            pageImagePaths: pageImagePaths,
            pageDimensions: pageDimensions,
            isComplete: errors.isEmpty,
            errors: errors
        )

        return (source, ingested)
    }
    #else
    private func ingestPDF(
        at url: URL,
        fileSize: Int64?,
        contentHash: String?
    ) async throws -> (source: DocumentSourceComponent, ingested: IngestedDocumentComponent) {
        throw DiaplasionError.unsupportedFormat(format: "PDF (PDFKit not available)")
    }
    #endif

    private func ingestImage(
        at url: URL,
        format: DocumentFormat,
        fileSize: Int64?,
        contentHash: String?
    ) async throws -> (source: DocumentSourceComponent, ingested: IngestedDocumentComponent) {
        #if canImport(CoreGraphics)
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DiaplasionError.imageLoadFailed(path: url.path)
        }

        let width = cgImage.width
        let height = cgImage.height

        let cacheDir = try getOrCreateCacheDirectory()
        let imagePath = cacheDir.appendingPathComponent("page_1.png").path

        guard saveCGImageAsPNG(cgImage, to: imagePath) else {
            throw DiaplasionError.imageLoadFailed(path: url.path)
        }

        let source = DocumentSourceComponent(
            sourceURI: url.path,
            format: format,
            pageCount: 1,
            fileSize: fileSize,
            contentHash: contentHash
        )

        let ingested = IngestedDocumentComponent(
            pageImagePaths: [imagePath],
            pageDimensions: [(width: width, height: height)],
            isComplete: true,
            errors: []
        )

        return (source, ingested)
        #else
        throw DiaplasionError.unsupportedFormat(format: "Image (CoreGraphics not available)")
        #endif
    }

    private func getOrCreateCacheDirectory() throws -> URL {
        let baseDir = cacheDirectory ?? FileManager.default.temporaryDirectory
        let sessionDir = baseDir.appendingPathComponent("diaplasion_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        return sessionDir
    }

    #if canImport(CoreGraphics)
    private func saveCGImageAsPNG(_ image: CGImage, to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
    #endif
}

// MARK: - OCR Extraction System

/// System that performs OCR on document images using Apple Vision framework.
///
/// This system:
/// 1. Reads cached page images from IngestedDocumentComponent
/// 2. Runs VNRecognizeTextRequest on each page
/// 3. Collects text with confidence scores and bounding boxes
/// 4. Produces OCRResultComponent with aggregated results
///
/// **Input**: Entity with `IngestedDocumentComponent` (completed)
/// **Output**: Adds `OCRResultComponent`
public struct OCRExtractionSystem: System {
    public var name: String { "OCRExtraction" }

    /// Recognition level: .fast for speed, .accurate for quality.
    public let recognitionLevel: RecognitionLevel

    /// Minimum confidence threshold (0.0-1.0). Text below this is excluded.
    public let confidenceThreshold: Float

    /// Languages to recognize (e.g., ["en-US"]). Empty = automatic.
    public let languages: [String]

    /// Whether to attempt language detection on extracted text.
    public let detectLanguage: Bool

    public enum RecognitionLevel: Sendable {
        case fast
        case accurate
    }

    public init(
        recognitionLevel: RecognitionLevel = .accurate,
        confidenceThreshold: Float = 0.0,
        languages: [String] = [],
        detectLanguage: Bool = true
    ) {
        self.recognitionLevel = recognitionLevel
        self.confidenceThreshold = confidenceThreshold
        self.languages = languages
        self.detectLanguage = detectLanguage
    }

    public func update(world: World) async {
        // Query for entities with IngestedDocumentComponent but no OCRResultComponent
        let documents = await world.query(IngestedDocumentComponent.self)

        for (entity, ingested) in documents {
            // Skip if already OCR'd
            if await world.hasComponent(entity, OCRResultComponent.self) {
                continue
            }

            // Skip if ingestion failed
            guard ingested.isComplete else {
                await Logger.shared.warning("Skipping OCR for incomplete document", category: "Diaplasion")
                await appendProcessingError(
                    world: world,
                    entity: entity,
                    stage: .ocr,
                    code: "ocr.ingest_incomplete",
                    message: "Ingested document is incomplete",
                    retryPolicy: .noRetry
                )
                continue
            }

            if let textContent = ingested.textContent {
                let startTime = Date()
                let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.isEmpty {
                    await Logger.shared.warning("Skipping OCR for empty extracted text", category: "Diaplasion")
                    await appendProcessingError(
                        world: world,
                        entity: entity,
                        stage: .textExtraction,
                        code: "text.empty",
                        message: "Extracted text is empty",
                        retryPolicy: .noRetry
                    )
                    let errorResult = OCRResultComponent(
                        text: "",
                        confidence: 0.0,
                        pageResults: [],
                        engine: "TextExtract",
                        processingTime: Date().timeIntervalSince(startTime)
                    )
                    await world.addComponent(entity, errorResult)
                    continue
                }

                var result = OCRResultComponent(
                    text: trimmed,
                    confidence: 1.0,
                    language: nil,
                    pageResults: [
                        PageOCRResult(
                            pageNumber: 1,
                            text: trimmed,
                            confidence: 1.0,
                            boundingBoxes: nil
                        )
                    ],
                    engine: "TextExtract",
                    processingTime: Date().timeIntervalSince(startTime)
                )

                if let language = detectLanguageCode(for: trimmed) {
                    result.language = language
                } else if detectLanguage {
                    await appendProcessingError(
                        world: world,
                        entity: entity,
                        stage: .languageDetection,
                        code: "language.detect.failed",
                        message: "Could not determine dominant language",
                        retryPolicy: .noRetry,
                        context: ["textLength": "\(trimmed.count)"]
                    )
                }

                await world.addComponent(entity, result)
                await Logger.shared.info(
                    "Text extraction completed: \(trimmed.count) characters",
                    category: "Diaplasion"
                )
                continue
            }

            guard !ingested.pageImagePaths.isEmpty else {
                await Logger.shared.warning("Skipping OCR for missing page images", category: "Diaplasion")
                await appendProcessingError(
                    world: world,
                    entity: entity,
                    stage: .ocr,
                    code: "ocr.no_pages",
                    message: "No page images available for OCR",
                    retryPolicy: .noRetry
                )
                continue
            }

            let startTime = Date()

            do {
                var result = try await performOCR(on: ingested)
                let processingTime = Date().timeIntervalSince(startTime)

                result.processingTime = processingTime
                result.engine = "Apple Vision"

                if let language = detectLanguageCode(for: result.text) {
                    result.language = language
                } else if detectLanguage {
                    await appendProcessingError(
                        world: world,
                        entity: entity,
                        stage: .languageDetection,
                        code: "language.detect.failed",
                        message: "Could not determine dominant language",
                        retryPolicy: .noRetry,
                        context: ["textLength": "\(result.text.count)"]
                    )
                }

                await world.addComponent(entity, result)
                await Logger.shared.info(
                    "OCR completed: \(ingested.pageImagePaths.count) pages in \(String(format: "%.2f", processingTime))s",
                    category: "Diaplasion"
                )
            } catch {
                await Logger.shared.error("OCR failed: \(error)", category: "Diaplasion")
                await appendProcessingError(
                    world: world,
                    entity: entity,
                    stage: .ocr,
                    code: "ocr.failed",
                    message: error.localizedDescription,
                    retryPolicy: .default,
                    context: ["pageCount": "\(ingested.pageImagePaths.count)"]
                )
                let errorResult = OCRResultComponent(
                    text: "",
                    confidence: 0.0,
                    pageResults: [],
                    engine: "Apple Vision",
                    processingTime: Date().timeIntervalSince(startTime)
                )
                await world.addComponent(entity, errorResult)
            }
        }
    }

    // MARK: - Private Implementation

    private func detectLanguageCode(for text: String) -> String? {
        guard detectLanguage else { return nil }
        #if canImport(NaturalLanguage)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else {
            return nil
        }
        return language.rawValue
        #else
        return nil
        #endif
    }

    #if canImport(Vision) && canImport(CoreGraphics)
    private func performOCR(on ingested: IngestedDocumentComponent) async throws -> OCRResultComponent {
        var pageResults: [PageOCRResult] = []
        var allText = ""
        var totalConfidence: Double = 0.0
        var wordCount = 0

        for (index, imagePath) in ingested.pageImagePaths.enumerated() {
            let pageNumber = index + 1
            let pageResult = try await ocrPage(at: imagePath, pageNumber: pageNumber)
            pageResults.append(pageResult)

            if !allText.isEmpty && !pageResult.text.isEmpty {
                allText += "\n\n"
            }
            allText += pageResult.text

            if let conf = pageResult.confidence {
                totalConfidence += conf
                wordCount += 1
            }
        }

        let avgConfidence = wordCount > 0 ? totalConfidence / Double(wordCount) : nil

        return OCRResultComponent(
            text: allText,
            confidence: avgConfidence,
            language: nil,
            pageResults: pageResults
        )
    }

    private func ocrPage(at imagePath: String, pageNumber: Int) async throws -> PageOCRResult {
        let url = URL(fileURLWithPath: imagePath)

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DiaplasionError.imageLoadFailed(path: imagePath)
        }

        // Create Vision request handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Configure text recognition request
        let request = VNRecognizeTextRequest()

        // Set recognition level
        switch recognitionLevel {
        case .fast:
            request.recognitionLevel = .fast
        case .accurate:
            request.recognitionLevel = .accurate
        }

        // Set languages if specified
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        }

        // Use revision 3 for best results on macOS 13+ / iOS 16+
        request.revision = VNRecognizeTextRequestRevision3

        // Run synchronously (Vision doesn't have async API)
        try handler.perform([request])

        guard let observations = request.results else {
            return PageOCRResult(pageNumber: pageNumber, text: "", confidence: nil, boundingBoxes: nil)
        }

        // Collect text and bounding boxes
        var textLines: [String] = []
        var boundingBoxes: [TextBoundingBox] = []
        var confidenceSum: Float = 0.0
        var confidenceCount = 0

        let imageWidth = Double(cgImage.width)
        let imageHeight = Double(cgImage.height)

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            // Filter by confidence threshold
            if candidate.confidence < confidenceThreshold {
                continue
            }

            textLines.append(candidate.string)
            confidenceSum += candidate.confidence
            confidenceCount += 1

            // Convert normalized bounding box to pixel coordinates
            // Vision uses bottom-left origin, we convert to top-left
            let box = observation.boundingBox
            let bbox = TextBoundingBox(
                x: box.origin.x * imageWidth,
                y: (1.0 - box.origin.y - box.height) * imageHeight,
                width: box.width * imageWidth,
                height: box.height * imageHeight,
                text: candidate.string,
                confidence: Double(candidate.confidence)
            )
            boundingBoxes.append(bbox)
        }

        let pageText = textLines.joined(separator: "\n")
        let avgConfidence = confidenceCount > 0 ? Double(confidenceSum / Float(confidenceCount)) : nil

        return PageOCRResult(
            pageNumber: pageNumber,
            text: pageText,
            confidence: avgConfidence,
            boundingBoxes: boundingBoxes
        )
    }
    #else
    private func performOCR(on ingested: IngestedDocumentComponent) async throws -> OCRResultComponent {
        throw DiaplasionError.ocrFailed(reason: "Vision framework not available")
    }
    #endif
}

// MARK: - Text Chunking System

/// System that chunks extracted text into semantic units.
///
/// This system:
/// 1. Reads OCRResultComponent text
/// 2. Normalizes whitespace and removes obvious OCR artifacts
/// 3. Detects headings (ALL CAPS, short lines after blank lines)
/// 4. Splits into paragraphs
/// 5. Produces ChunkedTextComponent with typed chunks
///
/// **Input**: Entity with `OCRResultComponent`
/// **Output**: Adds `ChunkedTextComponent`
public struct TextChunkingSystem: System {
    public var name: String { "TextChunking" }

    /// Chunking strategy to use.
    public let strategy: ChunkingStrategy

    /// Maximum characters per chunk (for .fixedToken strategy).
    public let maxChunkSize: Int

    /// Minimum characters for a line to be considered a heading candidate.
    public let minHeadingLength: Int

    /// Maximum characters for a line to be considered a heading candidate.
    public let maxHeadingLength: Int

    public init(
        strategy: ChunkingStrategy = .paragraph,
        maxChunkSize: Int = 2000,
        minHeadingLength: Int = 3,
        maxHeadingLength: Int = 100
    ) {
        self.strategy = strategy
        self.maxChunkSize = maxChunkSize
        self.minHeadingLength = minHeadingLength
        self.maxHeadingLength = maxHeadingLength
    }

    public func update(world: World) async {
        // Query for entities with OCRResultComponent but no ChunkedTextComponent
        let documents = await world.query(OCRResultComponent.self)

        for (entity, ocrResult) in documents {
            // Skip if already chunked
            if await world.hasComponent(entity, ChunkedTextComponent.self) {
                continue
            }

            // Skip empty results
            guard !ocrResult.text.isEmpty else {
                await Logger.shared.warning("Skipping chunking for empty OCR result", category: "Diaplasion")
                continue
            }

            let chunks = await chunkText(ocrResult.text)

            let result = ChunkedTextComponent(
                chunks: chunks,
                strategy: strategy,
                totalTokens: nil // Could estimate: chunks.reduce(0) { $0 + ($1.tokenCount ?? 0) }
            )

            await world.addComponent(entity, result)
            await Logger.shared.info("Chunked text into \(chunks.count) chunks", category: "Diaplasion")
        }
    }

    // MARK: - Private Implementation

    private func chunkText(_ text: String) async -> [TextChunk] {
        // Normalize text first
        let normalized = normalizeText(text)

        switch strategy {
        case .paragraph:
            return chunkByParagraph(normalized)
        case .sentence:
            return chunkBySentence(normalized)
        case .fixedToken:
            return await chunkUsingCapsule(normalized)
        case .page:
            // For page-based, we'd need page markers - fall back to paragraph
            return chunkByParagraph(normalized)
        case .semantic:
            // Semantic requires more advanced NLP - fall back to paragraph with heading detection
            return chunkByParagraph(normalized)
        }
    }

    /// Normalizes OCR text by cleaning up common artifacts.
    private func normalizeText(_ text: String) -> String {
        var result = text

        // Normalize line endings
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")

        // Remove excessive whitespace within lines (but preserve paragraph breaks)
        let lines = result.components(separatedBy: "\n")
        let cleanedLines = lines.map { line -> String in
            // Collapse multiple spaces to single space
            let collapsed = line.replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            return collapsed.trimmingCharacters(in: .whitespaces)
        }
        result = cleanedLines.joined(separator: "\n")

        // Collapse more than 2 consecutive newlines to 2
        result = result.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Chunks text by paragraphs, detecting headings.
    private func chunkByParagraph(_ text: String) -> [TextChunk] {
        // Split on double newlines (paragraph boundaries)
        let paragraphs = text.components(separatedBy: "\n\n")

        var chunks: [TextChunk] = []

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let chunkType = classifyParagraph(trimmed)
            let chunk = TextChunk(
                text: trimmed,
                chunkType: chunkType,
                pageNumber: nil,
                tokenCount: estimateTokenCount(trimmed)
            )
            chunks.append(chunk)
        }

        return chunks
    }

    /// Chunks text by sentences.
    private func chunkBySentence(_ text: String) -> [TextChunk] {
        // Simple sentence boundary detection
        // Split on sentence-ending punctuation followed by whitespace
        var chunks: [TextChunk] = []
        var currentSentence = ""
        var previousChar: Character = " "

        for char in text {
            currentSentence.append(char)

            // Check for sentence boundary: period/exclamation/question followed by space
            if (previousChar == "." || previousChar == "!" || previousChar == "?") && char.isWhitespace {
                let trimmed = currentSentence.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let chunk = TextChunk(
                        text: trimmed,
                        chunkType: .paragraph,
                        pageNumber: nil,
                        tokenCount: estimateTokenCount(trimmed)
                    )
                    chunks.append(chunk)
                }
                currentSentence = ""
            }
            previousChar = char
        }

        // Don't forget the last sentence
        let trimmed = currentSentence.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let chunk = TextChunk(
                text: trimmed,
                chunkType: .paragraph,
                pageNumber: nil,
                tokenCount: estimateTokenCount(trimmed)
            )
            chunks.append(chunk)
        }

        return chunks
    }

    /// Chunks text using TextChunkingCapsule with content-defined boundaries.
    private func chunkUsingCapsule(_ text: String) async -> [TextChunk] {
        guard !text.isEmpty else { return [] }
        
        // Convert to UTF-8 data for byte-level chunking
        let data = Data(text.utf8)
        
        // Compute average bytes per character for this specific text
        // This gives us a better estimate than assuming 4 bytes per character
        let avgBytesPerChar = max(1, data.count / text.count)
        
        // Convert character-based maxChunkSize to byte-based target size
        let targetBytes = maxChunkSize * avgBytesPerChar
        
        // Ensure reasonable bounds for chunk sizes
        // Minimum chunk size: at least 64 bytes, but no larger than target/2
        let minBytes = max(64, targetBytes / 4)
        // Maximum chunk size: cap at 16KB to avoid overly large chunks
        let maxBytes = min(targetBytes * 2, 16384)
        
        let config = TextChunkingConfig(
            targetChunkSize: targetBytes,
            minChunkSize: minBytes,
            maxChunkSize: maxBytes,
            windowSize: 48,
            determinismTier: 1
        )
        
        do {
            // Use one-shot chunking
            let wrapper = try TextChunkingCapsuleWrapper(config: config)
            try await wrapper.processBytes(data)
            try await wrapper.finalize()
            
            // Extract chunks as Data slices
            let chunkData = try await wrapper.extractChunks(from: data)
            
            // Convert Data back to String chunks
            var chunks: [TextChunk] = []
            for chunk in chunkData {
                if let chunkString = String(data: chunk, encoding: .utf8) {
                    let trimmed = chunkString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let chunkType = classifyParagraph(trimmed)
                        let chunk = TextChunk(
                            text: trimmed,
                            chunkType: chunkType,
                            pageNumber: nil,
                            tokenCount: estimateTokenCount(trimmed)
                        )
                        chunks.append(chunk)
                    }
                } else {
                    // UTF-8 conversion failed, fall back to original method
                    return fallbackChunkByFixedSize(text)
                }
            }
            
            return chunks.isEmpty ? [TextChunk(
                text: text,
                chunkType: .paragraph,
                pageNumber: nil,
                tokenCount: estimateTokenCount(text)
            )] : chunks
            
        } catch {
            // Capsule failed, fall back to original method
            return fallbackChunkByFixedSize(text)
        }
    }
    
    /// Original fixed-size chunking method kept as fallback
    private func fallbackChunkByFixedSize(_ text: String) -> [TextChunk] {
        var chunks: [TextChunk] = []
        var remaining = text

        while !remaining.isEmpty {
            let endIndex: String.Index
            if remaining.count <= maxChunkSize {
                endIndex = remaining.endIndex
            } else {
                // Try to break at a paragraph or sentence boundary
                let searchEnd = remaining.index(remaining.startIndex, offsetBy: maxChunkSize)
                let searchRange = remaining.startIndex..<searchEnd

                if let paragraphBreak = remaining.range(of: "\n\n", options: .backwards, range: searchRange)?.lowerBound {
                    endIndex = paragraphBreak
                } else if let sentenceBreak = remaining.range(of: ". ", options: .backwards, range: searchRange)?.upperBound {
                    endIndex = sentenceBreak
                } else {
                    endIndex = searchEnd
                }
            }

            let chunkText = String(remaining[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunkText.isEmpty {
                let chunk = TextChunk(
                    text: chunkText,
                    chunkType: .paragraph,
                    pageNumber: nil,
                    tokenCount: estimateTokenCount(chunkText)
                )
                chunks.append(chunk)
            }

            remaining = String(remaining[endIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return chunks
    }



    /// Classifies a paragraph as heading, body, etc.
    private func classifyParagraph(_ text: String) -> ChunkType {
        let lineCount = text.components(separatedBy: "\n").count
        let length = text.count

        // Heading heuristics:
        // 1. Single line
        // 2. Reasonable length (not too long)
        // 3. ALL CAPS or Title Case
        // 4. Doesn't end with typical sentence punctuation

        guard lineCount == 1 else { return .paragraph }
        guard length >= minHeadingLength && length <= maxHeadingLength else { return .paragraph }

        // Check for ALL CAPS
        let uppercased = text.uppercased()
        if text == uppercased && text.range(of: "[a-zA-Z]", options: .regularExpression) != nil {
            return .heading
        }

        // Check for Title Case (most words start with uppercase)
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count >= 2 && words.count <= 10 {
            let capitalizedCount = words.filter { word in
                guard let first = word.first else { return false }
                return first.isUppercase
            }.count

            if Double(capitalizedCount) / Double(words.count) >= 0.7 {
                // Check it doesn't end with sentence punctuation
                if !text.hasSuffix(".") && !text.hasSuffix(",") {
                    return .heading
                }
            }
        }

        // Check for numbered headings (e.g., "1. Introduction", "Chapter 1")
        if text.range(of: "^(Chapter|Section|Part|\\d+\\.?)\\s", options: .regularExpression) != nil {
            return .heading
        }

        return .paragraph
    }

    /// Estimates token count (rough approximation: ~4 chars per token).
    private func estimateTokenCount(_ text: String) -> Int {
        // This is a rough estimate. GPT-style tokenizers average ~4 chars/token for English.
        max(1, text.count / 4)
    }
}

// MARK: - EPUB Export System

/// System that generates accessible EPUB 3 output.
///
/// This system:
/// 1. Queries entities with ChunkedTextComponent and TransformRequestComponent
/// 2. Generates EPUB 3 structure (mimetype, container.xml, content.opf)
/// 3. Converts chunks to semantic XHTML
/// 4. Creates navigation documents (nav.xhtml, toc.ncx for compatibility)
/// 5. Packages as .epub file (ZIP with specific structure)
///
/// **Input**: Entity with `ChunkedTextComponent` and `TransformRequestComponent` targeting .epub
/// **Output**: Updates `AccessibleOutputComponent` with EPUB file reference
public struct EPUBExportSystem: System {
    public var name: String { "EPUBExport" }

    /// Output directory for generated EPUB files.
    /// If nil, uses system temp directory.
    public let outputDirectory: URL?

    /// EPUB metadata defaults
    public let defaultLanguage: String
    public let defaultPublisher: String

    public init(
        outputDirectory: URL? = nil,
        defaultLanguage: String = "en",
        defaultPublisher: String = "Diaplasion"
    ) {
        self.outputDirectory = outputDirectory
        self.defaultLanguage = defaultLanguage
        self.defaultPublisher = defaultPublisher
    }

    public func update(world: World) async {
        // Query for entities with ChunkedTextComponent and TransformRequestComponent
        let candidates = await world.query(ChunkedTextComponent.self, TransformRequestComponent.self)

        for (entity, chunked, request) in candidates {
            // Only process if EPUB is a target format
            guard request.targetFormats.contains(.epub) else { continue }

            // Skip if already has EPUB output
            if let existing = await world.getComponent(entity, AccessibleOutputComponent.self),
               existing.outputs[.epub] != nil {
                continue
            }

            // Get document source for metadata
            let source = await world.getComponent(entity, DocumentSourceComponent.self)

            do {
                let epubPath = try generateEPUB(
                    chunks: chunked.chunks,
                    sourceURI: source?.sourceURI,
                    requestId: request.requestId
                )

                // Update or create AccessibleOutputComponent
                var output = await world.getComponent(entity, AccessibleOutputComponent.self)
                    ?? AccessibleOutputComponent()

                let fileSize = try? FileManager.default.attributesOfItem(atPath: epubPath)[.size] as? Int64

                output.outputs[.epub] = OutputReference(
                    format: .epub,
                    uri: epubPath,
                    fileSize: fileSize,
                    createdAt: Date()
                )
                output.qaStatus = .pending

                await world.addComponent(entity, output)
                await Logger.shared.info("Generated EPUB: \(epubPath)", category: "Diaplasion")

            } catch {
                await Logger.shared.error("EPUB generation failed: \(error)", category: "Diaplasion")
            }
        }
    }

    // MARK: - EPUB Generation

    private func generateEPUB(chunks: [TextChunk], sourceURI: String?, requestId: String) throws -> String {
        // Create output directory
        let baseDir = outputDirectory ?? FileManager.default.temporaryDirectory
        let epubDir = baseDir.appendingPathComponent("epub_\(requestId)")
        let metaInfDir = epubDir.appendingPathComponent("META-INF")
        let oebpsDir = epubDir.appendingPathComponent("OEBPS")

        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)

        // Extract title from first heading or use filename
        let title = extractTitle(from: chunks, sourceURI: sourceURI)
        let identifier = "urn:uuid:\(UUID().uuidString)"
        let date = ISO8601DateFormatter().string(from: Date())

        // 1. Write mimetype (must be first, uncompressed)
        let mimetypePath = epubDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypePath, atomically: true, encoding: .utf8)

        // 2. Write container.xml
        let containerXML = generateContainerXML()
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        // 3. Generate content files and collect manifest entries
        var manifestItems: [(id: String, href: String, mediaType: String)] = []
        var spineItems: [String] = []
        var navPoints: [(id: String, label: String, src: String)] = []

        // Split chunks into chapters (each heading starts a new chapter)
        let chapters = splitIntoChapters(chunks)

        for (index, chapter) in chapters.enumerated() {
            let chapterId = "chapter\(index + 1)"
            let chapterFile = "\(chapterId).xhtml"
            let chapterPath = oebpsDir.appendingPathComponent(chapterFile)

            let xhtml = generateChapterXHTML(chapter: chapter, chapterNumber: index + 1, title: title)
            try xhtml.write(to: chapterPath, atomically: true, encoding: .utf8)

            manifestItems.append((id: chapterId, href: chapterFile, mediaType: "application/xhtml+xml"))
            spineItems.append(chapterId)

            // Navigation point
            let chapterTitle = chapter.first { $0.chunkType == .heading }?.text ?? "Chapter \(index + 1)"
            navPoints.append((id: chapterId, label: chapterTitle, src: chapterFile))
        }

        // 4. Generate nav.xhtml (EPUB 3 navigation)
        let navXHTML = generateNavXHTML(navPoints: navPoints, title: title)
        try navXHTML.write(to: oebpsDir.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)
        manifestItems.append((id: "nav", href: "nav.xhtml", mediaType: "application/xhtml+xml"))

        // 5. Generate toc.ncx (EPUB 2 compatibility)
        let tocNCX = generateTocNCX(navPoints: navPoints, title: title, identifier: identifier)
        try tocNCX.write(to: oebpsDir.appendingPathComponent("toc.ncx"), atomically: true, encoding: .utf8)
        manifestItems.append((id: "ncx", href: "toc.ncx", mediaType: "application/x-dtbncx+xml"))

        // 6. Generate content.opf (package document)
        let contentOPF = generateContentOPF(
            title: title,
            identifier: identifier,
            date: date,
            manifestItems: manifestItems,
            spineItems: spineItems
        )
        try contentOPF.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        // 7. Package as ZIP with .epub extension
        let epubPath = baseDir.appendingPathComponent("\(requestId).epub").path
        try packageAsEPUB(directory: epubDir, outputPath: epubPath)

        // Cleanup temp directory
        try? FileManager.default.removeItem(at: epubDir)

        return epubPath
    }

    private func extractTitle(from chunks: [TextChunk], sourceURI: String?) -> String {
        // Try to find first heading
        if let heading = chunks.first(where: { $0.chunkType == .heading }) {
            return heading.text
        }

        // Fall back to filename
        if let uri = sourceURI {
            let filename = (uri as NSString).lastPathComponent
            let name = (filename as NSString).deletingPathExtension
            return name
        }

        return "Untitled Document"
    }

    private func splitIntoChapters(_ chunks: [TextChunk]) -> [[TextChunk]] {
        var chapters: [[TextChunk]] = []
        var currentChapter: [TextChunk] = []

        for chunk in chunks {
            if chunk.chunkType == .heading && !currentChapter.isEmpty {
                chapters.append(currentChapter)
                currentChapter = [chunk]
            } else {
                currentChapter.append(chunk)
            }
        }

        if !currentChapter.isEmpty {
            chapters.append(currentChapter)
        }

        // If no chapters were created, make one from all chunks
        if chapters.isEmpty && !chunks.isEmpty {
            chapters.append(chunks)
        }

        return chapters
    }

    // MARK: - XML Generation

    private func generateContainerXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
    }

    private func generateContentOPF(
        title: String,
        identifier: String,
        date: String,
        manifestItems: [(id: String, href: String, mediaType: String)],
        spineItems: [String]
    ) -> String {
        let escapedTitle = escapeXML(title)

        let manifestEntries = manifestItems.map { item in
            let properties = item.id == "nav" ? " properties=\"nav\"" : ""
            return "        <item id=\"\(item.id)\" href=\"\(item.href)\" media-type=\"\(item.mediaType)\"\(properties)/>"
        }.joined(separator: "\n")

        let spineEntries = spineItems.map { id in
            "        <itemref idref=\"\(id)\"/>"
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="uid">\(identifier)</dc:identifier>
                <dc:title>\(escapedTitle)</dc:title>
                <dc:language>\(defaultLanguage)</dc:language>
                <dc:publisher>\(escapeXML(defaultPublisher))</dc:publisher>
                <dc:date>\(date)</dc:date>
                <meta property="dcterms:modified">\(date)</meta>
            </metadata>
            <manifest>
        \(manifestEntries)
            </manifest>
            <spine toc="ncx">
        \(spineEntries)
            </spine>
        </package>
        """
    }

    private func generateNavXHTML(navPoints: [(id: String, label: String, src: String)], title: String) -> String {
        let escapedTitle = escapeXML(title)

        let navItems = navPoints.map { point in
            "                <li><a href=\"\(point.src)\">\(escapeXML(point.label))</a></li>"
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="\(defaultLanguage)">
        <head>
            <meta charset="UTF-8"/>
            <title>\(escapedTitle) - Table of Contents</title>
        </head>
        <body>
            <nav epub:type="toc" id="toc">
                <h1>Table of Contents</h1>
                <ol>
        \(navItems)
                </ol>
            </nav>
        </body>
        </html>
        """
    }

    private func generateTocNCX(navPoints: [(id: String, label: String, src: String)], title: String, identifier: String) -> String {
        let escapedTitle = escapeXML(title)

        let navPointsXML = navPoints.enumerated().map { index, point in
            """
                    <navPoint id="navpoint-\(index + 1)" playOrder="\(index + 1)">
                        <navLabel><text>\(escapeXML(point.label))</text></navLabel>
                        <content src="\(point.src)"/>
                    </navPoint>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
            <head>
                <meta name="dtb:uid" content="\(identifier)"/>
                <meta name="dtb:depth" content="1"/>
                <meta name="dtb:totalPageCount" content="0"/>
                <meta name="dtb:maxPageNumber" content="0"/>
            </head>
            <docTitle><text>\(escapedTitle)</text></docTitle>
            <navMap>
        \(navPointsXML)
            </navMap>
        </ncx>
        """
    }

    private func generateChapterXHTML(chapter: [TextChunk], chapterNumber: Int, title: String) -> String {
        let escapedTitle = escapeXML(title)

        var bodyContent = ""

        for chunk in chapter {
            let escapedText = escapeXML(chunk.text)

            switch chunk.chunkType {
            case .heading:
                bodyContent += "    <h1>\(escapedText)</h1>\n"
            case .paragraph:
                bodyContent += "    <p>\(escapedText)</p>\n"
            case .listItem:
                bodyContent += "    <p class=\"list-item\">• \(escapedText)</p>\n"
            case .quote:
                bodyContent += "    <blockquote>\(escapedText)</blockquote>\n"
            case .caption:
                bodyContent += "    <p class=\"caption\">\(escapedText)</p>\n"
            case .footnote:
                bodyContent += "    <aside epub:type=\"footnote\">\(escapedText)</aside>\n"
            case .code:
                bodyContent += "    <pre><code>\(escapedText)</code></pre>\n"
            case .table, .figure:
                bodyContent += "    <div class=\"\(chunk.chunkType.rawValue)\">\(escapedText)</div>\n"
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="\(defaultLanguage)">
        <head>
            <meta charset="UTF-8"/>
            <title>\(escapedTitle) - Chapter \(chapterNumber)</title>
            <style type="text/css">
                body { font-family: serif; line-height: 1.6; margin: 1em; }
                h1 { font-size: 1.5em; margin-top: 1em; }
                p { margin: 0.5em 0; text-indent: 1em; }
                p.list-item { text-indent: 0; margin-left: 2em; }
                blockquote { margin: 1em 2em; font-style: italic; }
                .caption { font-size: 0.9em; text-align: center; }
                pre { background: #f4f4f4; padding: 1em; overflow-x: auto; }
            </style>
        </head>
        <body>
        \(bodyContent)
        </body>
        </html>
        """
    }

    private func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - ZIP Packaging

    private func packageAsEPUB(directory: URL, outputPath: String) throws {
        // Use /usr/bin/zip for packaging (available on macOS)
        // The mimetype must be stored uncompressed as the first file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory

        // First add mimetype uncompressed
        process.arguments = ["-X0", outputPath, "mimetype"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DiaplasionError.epubPackagingFailed(reason: "Failed to add mimetype")
        }

        // Then add everything else compressed
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        addProcess.currentDirectoryURL = directory
        addProcess.arguments = ["-Xr9", outputPath, "META-INF", "OEBPS"]
        try addProcess.run()
        addProcess.waitUntilExit()

        guard addProcess.terminationStatus == 0 else {
            throw DiaplasionError.epubPackagingFailed(reason: "Failed to add content")
        }
    }
}

// MARK: - Braille Export System

/// System that generates braille-ready output using Unified English Braille (UEB).
public struct BrailleExportSystem: System {
    public var name: String { "BrailleExport" }

    /// Braille grade for translation
    public enum BrailleGrade: String, Codable, Sendable {
        case grade1  // Uncontracted - letter by letter
        case grade2  // Contracted - uses standard contractions
    }

    /// Output format for braille files
    public enum BrailleOutputFormat: String, Codable, Sendable {
        case brf  // Braille Ready Format (ASCII)
        case pef  // Portable Embosser Format (XML)
    }

    /// Configuration for braille export
    public struct Configuration: Sendable {
        public let grade: BrailleGrade
        public let outputFormats: Set<BrailleOutputFormat>
        public let cellsPerLine: Int
        public let linesPerPage: Int
        public let outputDirectory: String?

        public init(
            grade: BrailleGrade = .grade2,
            outputFormats: Set<BrailleOutputFormat> = [.brf],
            cellsPerLine: Int = 40,
            linesPerPage: Int = 25,
            outputDirectory: String? = nil
        ) {
            self.grade = grade
            self.outputFormats = outputFormats
            self.cellsPerLine = cellsPerLine
            self.linesPerPage = linesPerPage
            self.outputDirectory = outputDirectory
        }
    }

    private let configuration: Configuration
    private let translator: UEBTranslator

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.translator = UEBTranslator(grade: configuration.grade)
    }

    public func update(world: World) async {
        // Query all entities - we'll filter for braille targets
        let entities = await world.allEntities()

        for entityId in entities {
            guard let chunked = await world.getComponent(entityId, ChunkedTextComponent.self),
                  let request = await world.getComponent(entityId, TransformRequestComponent.self),
                  request.targetFormats.contains(.brailleReady),
                  request.status == .processing else {
                continue
            }

            await Logger.shared.debug("BrailleExportSystem processing entity \(entityId)", category: "Diaplasion")

            do {
                // Translate chunks to braille
                var brailleChunks: [BrailleChunk] = []
                for chunk in chunked.chunks {
                    let brailleText = translator.translate(chunk.text)
                    brailleChunks.append(BrailleChunk(
                        original: chunk,
                        brailleText: brailleText,
                        grade: configuration.grade
                    ))
                }

                // Determine output directory
                let outputDir = configuration.outputDirectory ?? FileManager.default.temporaryDirectory
                    .appendingPathComponent("braille_\(UUID().uuidString)")
                    .path
                try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

                var outputs: [OutputFormat: OutputReference] = [:]

                // Generate BRF if requested
                if configuration.outputFormats.contains(.brf) {
                    let brfPath = (outputDir as NSString).appendingPathComponent("\(request.requestId).brf")
                    try generateBRF(chunks: brailleChunks, to: brfPath)

                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: brfPath)[.size] as? Int64) ?? 0
                    outputs[.brailleReady] = OutputReference(
                        format: .brailleReady,
                        uri: brfPath,
                        fileSize: fileSize
                    )

                    await Logger.shared.info("Generated BRF: \(brfPath)", category: "Diaplasion")
                }

                // Generate PEF if requested
                if configuration.outputFormats.contains(.pef) {
                    let pefPath = (outputDir as NSString).appendingPathComponent("\(request.requestId).pef")
                    try generatePEF(chunks: brailleChunks, to: pefPath, requestId: request.requestId)

                    await Logger.shared.info("Generated PEF: \(pefPath)", category: "Diaplasion")
                }

                // Update or create AccessibleOutputComponent
                var accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
                    ?? AccessibleOutputComponent()
                for (format, ref) in outputs {
                    accessible.outputs[format] = ref
                }
                accessible.qaStatus = .pending
                await world.addComponent(entityId, accessible)

            } catch {
                await Logger.shared.error("BrailleExportSystem failed: \(error)", category: "Diaplasion")
            }
        }
    }

    /// Generate BRF (Braille Ready Format) file.
    /// BRF uses ASCII characters to represent braille cells for embossers.
    private func generateBRF(chunks: [BrailleChunk], to path: String) throws {
        var output = ""
        var currentLine = ""
        var lineCount = 0

        for chunk in chunks {
            // Add heading marker if needed
            if chunk.original.chunkType == .heading {
                // Flush current line
                if !currentLine.isEmpty {
                    output += currentLine + "\r\n"
                    currentLine = ""
                    lineCount += 1
                }
                // Add blank line before heading
                if lineCount > 0 {
                    output += "\r\n"
                    lineCount += 1
                }
            }

            // Word-wrap braille text to cells per line
            let words = chunk.brailleText.split(separator: " ")
            for word in words {
                let wordStr = String(word)

                if currentLine.isEmpty {
                    currentLine = wordStr
                } else if currentLine.count + 1 + wordStr.count <= configuration.cellsPerLine {
                    currentLine += " " + wordStr
                } else {
                    // Line is full, emit it
                    output += currentLine + "\r\n"
                    lineCount += 1
                    currentLine = wordStr

                    // Page break if needed
                    if lineCount >= configuration.linesPerPage {
                        output += "\u{0C}"  // Form feed for page break
                        lineCount = 0
                    }
                }
            }

            // Paragraph break
            if chunk.original.chunkType == .paragraph {
                if !currentLine.isEmpty {
                    output += currentLine + "\r\n"
                    currentLine = ""
                    lineCount += 1
                }
                output += "\r\n"  // Blank line between paragraphs
                lineCount += 1
            }
        }

        // Flush remaining content
        if !currentLine.isEmpty {
            output += currentLine + "\r\n"
        }

        try output.write(toFile: path, atomically: true, encoding: .ascii)
    }

    /// Generate PEF (Portable Embosser Format) file.
    /// PEF is an XML format for digital braille documents.
    private func generatePEF(chunks: [BrailleChunk], to path: String, requestId: String) throws {
        var pef = """
        <?xml version="1.0" encoding="UTF-8"?>
        <pef version="2008-1" xmlns="http://www.daisy.org/ns/2008/pef">
          <head>
            <meta xmlns:dc="http://purl.org/dc/elements/1.1/">
              <dc:identifier>\(requestId)</dc:identifier>
              <dc:format>application/x-pef+xml</dc:format>
              <dc:date>\(ISO8601DateFormatter().string(from: Date()))</dc:date>
            </meta>
          </head>
          <body>
            <volume cols="\(configuration.cellsPerLine)" rows="\(configuration.linesPerPage)" rowgap="0" duplex="true">
              <section>

        """

        var currentPage: [String] = []
        var currentRow = ""

        func emitPage() {
            if !currentRow.isEmpty {
                currentPage.append(currentRow)
                currentRow = ""
            }
            if !currentPage.isEmpty {
                pef += "        <page>\n"
                for row in currentPage {
                    // Convert braille ASCII to Unicode braille
                    let unicodeBraille = brailleASCIIToUnicode(row)
                    pef += "          <row>\(unicodeBraille)</row>\n"
                }
                pef += "        </page>\n"
                currentPage = []
            }
        }

        for chunk in chunks {
            let words = chunk.brailleText.split(separator: " ")
            for word in words {
                let wordStr = String(word)

                if currentRow.isEmpty {
                    currentRow = wordStr
                } else if currentRow.count + 1 + wordStr.count <= configuration.cellsPerLine {
                    currentRow += " " + wordStr
                } else {
                    currentPage.append(currentRow)
                    currentRow = wordStr

                    if currentPage.count >= configuration.linesPerPage {
                        emitPage()
                    }
                }
            }

            // Paragraph break
            if !currentRow.isEmpty {
                currentPage.append(currentRow)
                currentRow = ""
            }
            currentPage.append("")  // Blank line
        }

        emitPage()

        pef += """
              </section>
            </volume>
          </body>
        </pef>
        """

        try pef.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Convert North American Braille ASCII to Unicode braille characters.
    private func brailleASCIIToUnicode(_ ascii: String) -> String {
        // North American Braille ASCII to Unicode mapping
        let asciiToBraille: [Character: Character] = [
            " ": "\u{2800}", // Blank
            "A": "\u{2801}", "B": "\u{2803}", "C": "\u{2809}", "D": "\u{2819}",
            "E": "\u{2811}", "F": "\u{280B}", "G": "\u{281B}", "H": "\u{2813}",
            "I": "\u{280A}", "J": "\u{281A}", "K": "\u{2805}", "L": "\u{2807}",
            "M": "\u{280D}", "N": "\u{281D}", "O": "\u{2815}", "P": "\u{280F}",
            "Q": "\u{281F}", "R": "\u{2817}", "S": "\u{280E}", "T": "\u{281E}",
            "U": "\u{2825}", "V": "\u{2827}", "W": "\u{283A}", "X": "\u{282D}",
            "Y": "\u{283D}", "Z": "\u{2835}",
            "1": "\u{2801}", "2": "\u{2803}", "3": "\u{2809}", "4": "\u{2819}",
            "5": "\u{2811}", "6": "\u{280B}", "7": "\u{281B}", "8": "\u{2813}",
            "9": "\u{280A}", "0": "\u{281A}",
            ",": "\u{2802}", ";": "\u{2806}", ":": "\u{2812}", ".": "\u{2832}",
            "!": "\u{2816}", "?": "\u{2826}", "'": "\u{2804}", "-": "\u{2824}"
        ]

        return String(ascii.uppercased().map { asciiToBraille[$0] ?? $0 })
    }
}

/// Represents a chunk of text translated to braille.
private struct BrailleChunk {
    let original: TextChunk
    let brailleText: String
    let grade: BrailleExportSystem.BrailleGrade
}

/// Pure-Swift UEB (Unified English Braille) translator.
///
/// This implements a subset of UEB rules for basic text translation.
/// For full UEB compliance, consider liblouis integration.
///
/// ## Grade 1 (Uncontracted)
/// Direct letter-to-braille mapping with number and capital indicators.
///
/// ## Grade 2 (Contracted)
/// Includes 180+ contractions for common words and letter combinations.
/// This implementation covers the most common contractions.
private struct UEBTranslator {
    let grade: BrailleExportSystem.BrailleGrade

    // UEB letter representations in North American Braille ASCII
    private let letterMap: [Character: String] = [
        "a": "A", "b": "B", "c": "C", "d": "D", "e": "E",
        "f": "F", "g": "G", "h": "H", "i": "I", "j": "J",
        "k": "K", "l": "L", "m": "M", "n": "N", "o": "O",
        "p": "P", "q": "Q", "r": "R", "s": "S", "t": "T",
        "u": "U", "v": "V", "w": "W", "x": "X", "y": "Y", "z": "Z"
    ]

    // Number indicator (dots 3456)
    private let numberIndicator = "#"

    // Capital indicator (dot 6)
    private let capitalIndicator = ","

    // Numbers use same patterns as letters a-j
    private let numberMap: [Character: String] = [
        "1": "A", "2": "B", "3": "C", "4": "D", "5": "E",
        "6": "F", "7": "G", "8": "H", "9": "I", "0": "J"
    ]

    // Grade 2 whole-word contractions (most common)
    private let wholeWordContractions: [String: String] = [
        "but": "B", "can": "C", "do": "D", "every": "E",
        "from": "F", "go": "G", "have": "H", "just": "J",
        "knowledge": "K", "like": "L", "more": "M", "not": "N",
        "people": "P", "quite": "Q", "rather": "R", "so": "S",
        "that": "T", "us": "U", "very": "V", "will": "W",
        "it": "X", "you": "Y", "as": "Z",
        "and": "&", "for": "=", "of": "(", "the": "!",
        "with": ")", "child": "*", "shall": "%", "this": "?",
        "which": "<", "out": ">", "still": "/"
    ]

    // Grade 2 part-word contractions (letter combinations)
    private let partWordContractions: [String: String] = [
        "ing": "+", "tion": ";", "ness": ":", "ment": "!",
        "ound": "$", "ance": "@", "ence": "`", "ong": "\\",
        "ful": "]", "ity": "~", "ble": "}", "ght": "["
    ]

    func translate(_ text: String) -> String {
        var result = ""
        let words = text.components(separatedBy: .whitespaces)

        for (index, word) in words.enumerated() {
            if index > 0 { result += " " }
            result += translateWord(word)
        }

        return result
    }

    private func translateWord(_ word: String) -> String {
        // Skip empty words
        guard !word.isEmpty else { return "" }

        // Preserve punctuation at start and end
        var prefix = ""
        var suffix = ""
        var core = word

        while let first = core.first, !first.isLetter && !first.isNumber {
            prefix += translatePunctuation(first)
            core.removeFirst()
        }

        while let last = core.last, !last.isLetter && !last.isNumber {
            suffix = translatePunctuation(last) + suffix
            core.removeLast()
        }

        guard !core.isEmpty else { return prefix + suffix }

        // Check for whole-word contraction (Grade 2 only)
        if grade == .grade2 {
            if let contraction = wholeWordContractions[core.lowercased()] {
                let needsCap = core.first?.isUppercase ?? false
                return prefix + (needsCap ? capitalIndicator : "") + contraction + suffix
            }
        }

        // Translate character by character with contractions
        return prefix + translateCharacters(core) + suffix
    }

    private func translateCharacters(_ text: String) -> String {
        var result = ""
        var remaining = text.lowercased()
        var originalIndex = text.startIndex
        var inNumber = false

        while !remaining.isEmpty {
            var matched = false

            // Check for part-word contractions (Grade 2 only)
            if grade == .grade2 {
                for (pattern, contraction) in partWordContractions.sorted(by: { $0.key.count > $1.key.count }) {
                    if remaining.hasPrefix(pattern) {
                        result += contraction
                        remaining.removeFirst(pattern.count)
                        originalIndex = text.index(originalIndex, offsetBy: pattern.count)
                        matched = true
                        inNumber = false
                        break
                    }
                }
            }

            if !matched {
                let char = remaining.removeFirst()
                let originalChar = text[originalIndex]
                originalIndex = text.index(after: originalIndex)

                if char.isNumber {
                    if !inNumber {
                        result += numberIndicator
                        inNumber = true
                    }
                    result += numberMap[char] ?? String(char)
                } else if char.isLetter {
                    inNumber = false
                    if originalChar.isUppercase {
                        result += capitalIndicator
                    }
                    result += letterMap[char] ?? String(char)
                } else {
                    inNumber = false
                    result += translatePunctuation(char)
                }
            }
        }

        return result
    }

    private func translatePunctuation(_ char: Character) -> String {
        switch char {
        case ".": return "4"
        case ",": return "1"
        case ";": return "2"
        case ":": return "3"
        case "!": return "6"
        case "?": return "8"
        case "'", "\u{2018}", "\u{2019}": return "'"  // straight and curly apostrophes
        case "\"", "\u{201C}", "\u{201D}": return "7"  // straight and curly quotes
        case "(": return "9"
        case ")": return "0"
        case "-", "\u{2013}", "\u{2014}": return "-"  // hyphen, en-dash, em-dash
        case "/": return "_"
        case "@": return ".A"
        case "#": return ".N"
        case "$": return ".S"
        case "%": return ".P"
        case "&": return ".&"
        case "*": return ".*"
        default: return String(char)
        }
    }
}

// MARK: - Audio Prep System

/// System that prepares text for audio/TTS output with SSML markup.
public struct AudioPrepSystem: System {
    public var name: String { "AudioPrep" }

    /// Configuration for audio preparation
    public struct Configuration: Sendable {
        /// Pause duration after paragraphs (in seconds)
        public let paragraphPause: Double
        /// Pause duration after headings (in seconds)
        public let headingPause: Double
        /// Pause duration after sentences (in seconds)
        public let sentencePause: Double
        /// Speaking rate adjustment for headings (1.0 = normal)
        public let headingRate: Double
        /// Output directory for SSML files
        public let outputDirectory: String?
        /// Whether to generate plain text alongside SSML
        public let generatePlainText: Bool

        public init(
            paragraphPause: Double = 0.8,
            headingPause: Double = 1.2,
            sentencePause: Double = 0.3,
            headingRate: Double = 0.9,
            outputDirectory: String? = nil,
            generatePlainText: Bool = true
        ) {
            self.paragraphPause = paragraphPause
            self.headingPause = headingPause
            self.sentencePause = sentencePause
            self.headingRate = headingRate
            self.outputDirectory = outputDirectory
            self.generatePlainText = generatePlainText
        }
    }

    private let configuration: Configuration
    private let normalizer: TextNormalizer

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.normalizer = TextNormalizer()
    }

    public func update(world: World) async {
        let entities = await world.allEntities()

        for entityId in entities {
            guard let chunked = await world.getComponent(entityId, ChunkedTextComponent.self),
                  let request = await world.getComponent(entityId, TransformRequestComponent.self),
                  request.targetFormats.contains(.audioReady),
                  request.status == .processing else {
                continue
            }

            await Logger.shared.debug("AudioPrepSystem processing entity \(entityId)", category: "Diaplasion")

            do {
                // Determine output directory
                let outputDir = configuration.outputDirectory ?? FileManager.default.temporaryDirectory
                    .appendingPathComponent("audio_\(UUID().uuidString)")
                    .path
                try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

                // Generate SSML
                let ssmlPath = (outputDir as NSString).appendingPathComponent("\(request.requestId).ssml")
                let ssml = generateSSML(chunks: chunked.chunks, requestId: request.requestId)
                try ssml.write(toFile: ssmlPath, atomically: true, encoding: .utf8)

                var outputs: [OutputFormat: OutputReference] = [:]

                let fileSize = (try? FileManager.default.attributesOfItem(atPath: ssmlPath)[.size] as? Int64) ?? 0
                outputs[.audioReady] = OutputReference(
                    format: .audioReady,
                    uri: ssmlPath,
                    fileSize: fileSize
                )

                await Logger.shared.info("Generated SSML: \(ssmlPath)", category: "Diaplasion")

                // Generate plain text if requested
                if configuration.generatePlainText {
                    let textPath = (outputDir as NSString).appendingPathComponent("\(request.requestId)_audio.txt")
                    let plainText = generatePlainText(chunks: chunked.chunks)
                    try plainText.write(toFile: textPath, atomically: true, encoding: .utf8)

                    await Logger.shared.debug("Generated plain text: \(textPath)", category: "Diaplasion")
                }

                // Generate chapter manifest for audiobook tools
                let manifestPath = (outputDir as NSString).appendingPathComponent("\(request.requestId)_chapters.json")
                let manifest = generateChapterManifest(chunks: chunked.chunks, requestId: request.requestId)
                try manifest.write(toFile: manifestPath, atomically: true, encoding: .utf8)

                // Update or create AccessibleOutputComponent
                var accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
                    ?? AccessibleOutputComponent()
                for (format, ref) in outputs {
                    accessible.outputs[format] = ref
                }
                accessible.qaStatus = .pending
                await world.addComponent(entityId, accessible)

            } catch {
                await Logger.shared.error("AudioPrepSystem failed: \(error)", category: "Diaplasion")
            }
        }
    }

    /// Generate SSML with prosody hints for natural TTS output.
    private func generateSSML(chunks: [TextChunk], requestId: String) -> String {
        var ssml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <speak version="1.1" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">

        """

        var chapterNumber = 0

        for chunk in chunks {
            let normalizedText = normalizer.normalize(chunk.text)
            let escapedText = escapeXML(normalizedText)

            switch chunk.chunkType {
            case .heading:
                chapterNumber += 1
                // Heading: slower rate, higher emphasis, longer pause after
                ssml += """
                  <mark name="chapter\(chapterNumber)"/>
                  <prosody rate="\(Int(configuration.headingRate * 100))%" pitch="+5%">
                    <emphasis level="strong">\(escapedText)</emphasis>
                  </prosody>
                  <break time="\(Int(configuration.headingPause * 1000))ms"/>

                """

            case .paragraph:
                // Normal paragraph with sentence-level structure
                let sentences = splitIntoSentences(escapedText)
                ssml += "  <p>\n"
                for sentence in sentences {
                    ssml += "    <s>\(sentence)</s>\n"
                }
                ssml += "  </p>\n"
                ssml += "  <break time=\"\(Int(configuration.paragraphPause * 1000))ms\"/>\n"

            case .listItem:
                // List items with slight pause before
                ssml += "  <break time=\"200ms\"/>\n"
                ssml += "  <s>\(escapedText)</s>\n"

            case .quote:
                // Quotes with slight pitch change to indicate quotation
                ssml += """
                  <prosody pitch="-2%">
                    <p>\(escapedText)</p>
                  </prosody>
                  <break time="\(Int(configuration.paragraphPause * 1000))ms"/>

                """

            case .caption, .footnote:
                // Captions and footnotes: slightly faster, lower volume
                ssml += """
                  <prosody rate="105%" volume="-2dB">
                    <s>\(escapedText)</s>
                  </prosody>
                  <break time="300ms"/>

                """

            default:
                // Default handling
                ssml += "  <s>\(escapedText)</s>\n"
                ssml += "  <break time=\"\(Int(configuration.sentencePause * 1000))ms\"/>\n"
            }
        }

        ssml += "</speak>\n"
        return ssml
    }

    /// Generate plain text suitable for TTS engines that don't support SSML.
    private func generatePlainText(chunks: [TextChunk]) -> String {
        var text = ""

        for chunk in chunks {
            let normalized = normalizer.normalize(chunk.text)

            switch chunk.chunkType {
            case .heading:
                // Double newline before headings
                if !text.isEmpty { text += "\n\n" }
                text += normalized + "\n\n"

            case .paragraph:
                text += normalized + "\n\n"

            case .listItem:
                text += "• " + normalized + "\n"

            default:
                text += normalized + "\n"
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate a JSON chapter manifest for audiobook generation tools.
    private func generateChapterManifest(chunks: [TextChunk], requestId: String) -> String {
        var chapters: [[String: Any]] = []
        var currentChapter: [String: Any]?
        var chunkIndex = 0

        for chunk in chunks {
            if chunk.chunkType == .heading {
                // Save previous chapter if exists
                if let chapter = currentChapter {
                    chapters.append(chapter)
                }
                // Start new chapter
                currentChapter = [
                    "title": chunk.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    "startChunkIndex": chunkIndex
                ]
            }
            chunkIndex += 1
        }

        // Save final chapter
        if let chapter = currentChapter {
            chapters.append(chapter)
        }

        // If no chapters found, create a single chapter
        if chapters.isEmpty {
            chapters.append([
                "title": "Content",
                "startChunkIndex": 0
            ])
        }

        let manifest: [String: Any] = [
            "requestId": requestId,
            "chapterCount": chapters.count,
            "totalChunks": chunks.count,
            "chapters": chapters
        ]

        // Manual JSON serialization to avoid JSONSerialization issues with Any
        return serializeManifest(manifest)
    }

    private func serializeManifest(_ manifest: [String: Any]) -> String {
        var json = "{\n"
        json += "  \"requestId\": \"\(manifest["requestId"] as? String ?? "")\",\n"
        json += "  \"chapterCount\": \(manifest["chapterCount"] as? Int ?? 0),\n"
        json += "  \"totalChunks\": \(manifest["totalChunks"] as? Int ?? 0),\n"
        json += "  \"chapters\": [\n"

        if let chapters = manifest["chapters"] as? [[String: Any]] {
            for (index, chapter) in chapters.enumerated() {
                let title = (chapter["title"] as? String ?? "").replacingOccurrences(of: "\"", with: "\\\"")
                let startIndex = chapter["startChunkIndex"] as? Int ?? 0
                json += "    {\"title\": \"\(title)\", \"startChunkIndex\": \(startIndex)}"
                if index < chapters.count - 1 { json += "," }
                json += "\n"
            }
        }

        json += "  ]\n"
        json += "}\n"
        return json
    }

    /// Split text into sentences for SSML <s> elements.
    private func splitIntoSentences(_ text: String) -> [String] {
        // Simple sentence splitting on . ! ? followed by space or end
        let pattern = #"[.!?]+[\s]+|[.!?]+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [text]
        }

        var sentences: [String] = []
        var lastEnd = text.startIndex

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        for match in matches {
            if let range = Range(match.range, in: text) {
                let sentenceEnd = range.upperBound
                let sentence = String(text[lastEnd..<sentenceEnd]).trimmingCharacters(in: .whitespaces)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                lastEnd = sentenceEnd
            }
        }

        // Add remaining text
        if lastEnd < text.endIndex {
            let remaining = String(text[lastEnd...]).trimmingCharacters(in: .whitespaces)
            if !remaining.isEmpty {
                sentences.append(remaining)
            }
        }

        return sentences.isEmpty ? [text] : sentences
    }

    /// Escape XML special characters.
    private func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

/// Text normalizer for TTS preparation.
///
/// Converts numbers, abbreviations, and symbols to spoken forms
/// for more natural text-to-speech output.
private struct TextNormalizer {

    // Common abbreviations
    private let abbreviations: [String: String] = [
        "Dr.": "Doctor",
        "Mr.": "Mister",
        "Mrs.": "Missus",
        "Ms.": "Miss",
        "Jr.": "Junior",
        "Sr.": "Senior",
        "St.": "Saint",
        "Ave.": "Avenue",
        "Blvd.": "Boulevard",
        "Rd.": "Road",
        "etc.": "etcetera",
        "e.g.": "for example",
        "i.e.": "that is",
        "vs.": "versus",
        "Prof.": "Professor",
        "Inc.": "Incorporated",
        "Ltd.": "Limited",
        "Corp.": "Corporation",
        "Dept.": "Department",
        "approx.": "approximately",
        "govt.": "government"
    ]

    // Symbols to spoken form
    private let symbols: [String: String] = [
        "@": " at ",
        "&": " and ",
        "%": " percent",
        "$": " dollars",
        "€": " euros",
        "£": " pounds",
        "¥": " yen",
        "+": " plus ",
        "=": " equals ",
        "#": " number ",
        "©": " copyright ",
        "®": " registered ",
        "™": " trademark "
    ]

    func normalize(_ text: String) -> String {
        var result = text

        // Expand abbreviations
        for (abbrev, expansion) in abbreviations {
            result = result.replacingOccurrences(of: abbrev, with: expansion)
        }

        // Replace symbols
        for (symbol, spoken) in symbols {
            result = result.replacingOccurrences(of: symbol, with: spoken)
        }

        // Normalize numbers in text
        result = normalizeNumbers(result)

        // Clean up multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Convert numbers to spoken form.
    private func normalizeNumbers(_ text: String) -> String {
        // Match standalone numbers (not part of words)
        let pattern = #"\b(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        var result = text
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange).reversed()

        for match in matches {
            if let range = Range(match.range, in: result) {
                let numberStr = String(result[range]).replacingOccurrences(of: ",", with: "")
                if let number = Double(numberStr) {
                    let spoken = numberToWords(number)
                    result.replaceSubrange(range, with: spoken)
                }
            }
        }

        return result
    }

    /// Convert a number to spoken words.
    private func numberToWords(_ number: Double) -> String {
        // Handle decimals
        if number != floor(number) {
            let intPart = Int(number)
            let decimalPart = String(format: "%.2f", number).split(separator: ".").last ?? ""
            return "\(numberToWords(Double(intPart))) point \(String(decimalPart).map { String($0) }.joined(separator: " "))"
        }

        let n = Int(number)

        if n == 0 { return "zero" }
        if n < 0 { return "negative \(numberToWords(Double(-n)))" }

        let ones = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                   "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
                   "seventeen", "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

        if n < 20 {
            return ones[n]
        } else if n < 100 {
            let remainder = n % 10
            return tens[n / 10] + (remainder > 0 ? "-\(ones[remainder])" : "")
        } else if n < 1000 {
            let remainder = n % 100
            return "\(ones[n / 100]) hundred" + (remainder > 0 ? " \(numberToWords(Double(remainder)))" : "")
        } else if n < 1_000_000 {
            let thousands = n / 1000
            let remainder = n % 1000
            return "\(numberToWords(Double(thousands))) thousand" + (remainder > 0 ? " \(numberToWords(Double(remainder)))" : "")
        } else if n < 1_000_000_000 {
            let millions = n / 1_000_000
            let remainder = n % 1_000_000
            return "\(numberToWords(Double(millions))) million" + (remainder > 0 ? " \(numberToWords(Double(remainder)))" : "")
        } else {
            // For very large numbers, just read digits
            return String(n).map { String($0) }.joined(separator: " ")
        }
    }
}

// MARK: - QA Validation System

/// System that validates transformation outputs for accessibility compliance.
///
/// This system:
/// 1. Queries entities with AccessibleOutputComponent where qaStatus == .pending
/// 2. Performs format-specific validation checks
/// 3. Validates structure and accessibility compliance
/// 4. Updates qaStatus and validationResults
///
/// **Input**: Entity with `AccessibleOutputComponent` (qaStatus == .pending)
/// **Output**: Updates qaStatus and adds validationResults
public struct DiaplasionQASystem: System {
    public var name: String { "DiaplasionQA" }

    /// Confidence threshold below which manual review is required.
    public let reviewThreshold: Double

    /// Whether to perform structural validation on EPUBs.
    public let validateEPUBStructure: Bool

    public init(
        reviewThreshold: Double = 0.8,
        validateEPUBStructure: Bool = true
    ) {
        self.reviewThreshold = reviewThreshold
        self.validateEPUBStructure = validateEPUBStructure
    }

    public func update(world: World) async {
        // Query for entities with AccessibleOutputComponent
        let outputs = await world.query(AccessibleOutputComponent.self)

        for (entity, var output) in outputs {
            // Skip if not pending QA
            guard output.qaStatus == .pending else { continue }

            // Get OCR result for confidence check
            let ocrResult = await world.getComponent(entity, OCRResultComponent.self)

            var validationResults: [ValidationResult] = []
            var overallPassed = true

            // Check OCR confidence
            if let confidence = ocrResult?.confidence {
                let confidenceCheck = ValidationResult(
                    check: "OCR Confidence",
                    passed: confidence >= reviewThreshold,
                    message: confidence >= reviewThreshold
                        ? "Confidence \(String(format: "%.1f%%", confidence * 100)) meets threshold"
                        : "Confidence \(String(format: "%.1f%%", confidence * 100)) below threshold \(String(format: "%.1f%%", reviewThreshold * 100))"
                )
                validationResults.append(confidenceCheck)

                if !confidenceCheck.passed {
                    overallPassed = false
                }
            }

            // Validate EPUB if present
            if let epubRef = output.outputs[.epub], validateEPUBStructure {
                let epubResults = validateEPUB(at: epubRef.uri)
                validationResults.append(contentsOf: epubResults)

                if epubResults.contains(where: { !$0.passed }) {
                    overallPassed = false
                }
            }

            // Check chunking quality
            if let chunked = await world.getComponent(entity, ChunkedTextComponent.self) {
                let chunkResults = validateChunking(chunked)
                validationResults.append(contentsOf: chunkResults)

                if chunkResults.contains(where: { !$0.passed }) {
                    overallPassed = false
                }
            }

            // Update QA status
            output.validationResults = validationResults
            output.qaStatus = overallPassed ? .passed : .needsReview

            await world.addComponent(entity, output)
            await Logger.shared.info(
                "QA completed: \(overallPassed ? "passed" : "needs review") with \(validationResults.count) checks",
                category: "Diaplasion"
            )
        }
    }

    // MARK: - Validation Helpers

    private func validateEPUB(at path: String) -> [ValidationResult] {
        var results: [ValidationResult] = []

        // Check file exists
        let fileExists = FileManager.default.fileExists(atPath: path)
        results.append(ValidationResult(
            check: "EPUB File Exists",
            passed: fileExists,
            message: fileExists ? nil : "EPUB file not found at \(path)"
        ))

        guard fileExists else { return results }

        // Check file is a valid ZIP (EPUB is a ZIP file)
        if let data = FileManager.default.contents(atPath: path), data.count >= 4 {
            let isZip = data[0] == 0x50 && data[1] == 0x4B // "PK" magic bytes
            results.append(ValidationResult(
                check: "EPUB ZIP Format",
                passed: isZip,
                message: isZip ? nil : "File is not a valid ZIP archive"
            ))
        }

        // Check file size is reasonable (not empty, not suspiciously small)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attributes[.size] as? Int64 {
            let minSize: Int64 = 500 // Minimum reasonable EPUB size
            let sizeOK = size >= minSize
            results.append(ValidationResult(
                check: "EPUB File Size",
                passed: sizeOK,
                message: sizeOK ? "File size: \(size) bytes" : "File too small (\(size) bytes)"
            ))
        }

        return results
    }

    private func validateChunking(_ chunked: ChunkedTextComponent) -> [ValidationResult] {
        var results: [ValidationResult] = []

        // Check that we have content
        let hasContent = !chunked.chunks.isEmpty
        results.append(ValidationResult(
            check: "Has Content",
            passed: hasContent,
            message: hasContent ? "\(chunked.chunks.count) chunks" : "No content chunks found"
        ))

        guard hasContent else { return results }

        // Check for heading structure
        let headingCount = chunked.chunks.filter { $0.chunkType == .heading }.count
        let hasHeadings = headingCount > 0
        results.append(ValidationResult(
            check: "Document Structure",
            passed: hasHeadings,
            message: hasHeadings ? "\(headingCount) headings detected" : "No headings detected - may lack structure"
        ))

        // Check for suspiciously short chunks that might indicate OCR errors
        let shortChunks = chunked.chunks.filter { $0.text.count < 10 && $0.chunkType != .heading }
        let fewShortChunks = shortChunks.count <= chunked.chunks.count / 4
        results.append(ValidationResult(
            check: "Chunk Quality",
            passed: fewShortChunks,
            message: fewShortChunks
                ? "Chunk lengths appear reasonable"
                : "\(shortChunks.count) suspiciously short chunks detected"
        ))

        // Check for very long chunks that might indicate missed paragraph breaks
        let longChunks = chunked.chunks.filter { $0.text.count > 5000 }
        let fewLongChunks = longChunks.isEmpty
        results.append(ValidationResult(
            check: "Paragraph Breaks",
            passed: fewLongChunks,
            message: fewLongChunks
                ? "No excessively long paragraphs"
                : "\(longChunks.count) very long paragraphs may need manual review"
        ))

        return results
    }
}
