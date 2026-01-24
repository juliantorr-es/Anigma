//
//  DocumentIngestSystem.swift
//  DiaplasionModule
//
//  Extracted from DiaplasionSystems.swift
//  System that ingests source documents and prepares them for OCR.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif
#if canImport(PDFKit)
import PDFKit
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

    public init(cacheDirectory: URL? = nil, renderDPI: CGFloat? = nil) {
        self.cacheDirectory = cacheDirectory ?? DiaplasionConfiguration.getEffectiveCacheDirectory()
        self.renderDPI = renderDPI ?? DiaplasionConfiguration.ocrRenderDPI
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

    // MARK: - Internal Implementation

    struct IngestResult {
        let source: DocumentSourceComponent
        let ingested: IngestedDocumentComponent
        let assets: DocumentAssetComponent?
    }

    func ingestDocument(at path: String) async throws -> IngestResult {
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
