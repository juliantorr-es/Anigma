import AnigmaPrimitives

import AnigmaPrimitives

//
//  ImageExtractor.swift
//  DiaplasionModule
//
//  Extracts and optimizes images from documents for EPUB inclusion.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
import AnigmaNativeShims
import UniformTypeIdentifiers

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

/// Extracts and optimizes images from documents for EPUB inclusion.
public struct ImageExtractor: Sendable {
    
    // MARK: - Configuration
    
    /// Maximum image size in pixels
    public let maxImageSize: Int
    
    /// JPEG quality for compressed images
    public let jpegQuality: Double
    
    /// Include images in EPUB output
    public let includeImages: Bool
    
    /// Generate alt text for images
    public let generateAltText: Bool
    
    /// Extract images from PDFs
    public let extractFromPDFs: Bool
    
    // MARK: - Initialization
    
    public init(
        maxImageSize: Int? = nil,
        jpegQuality: Double = 0.85,
        includeImages: Bool? = nil,
        generateAltText: Bool = true,
        extractFromPDFs: Bool? = nil
    ) {
        self.maxImageSize = maxImageSize ?? DiaplasionConfiguration.epubMaxImageSize
        self.jpegQuality = jpegQuality
        self.includeImages = includeImages ?? DiaplasionConfiguration.epubIncludeImages
        self.generateAltText = generateAltText
        self.extractFromPDFs = extractFromPDFs ?? DiaplasionConfiguration.enableImageExtraction
    }
    
    // MARK: - Public Interface
    
    /// Extract images from a document.
    public func extractImages(from document: DocumentSourceComponent) async throws -> [ExtractedImage] {
        guard includeImages else { return [] }
        
        var images: [ExtractedImage] = []
        
        switch document.format {
        case .pdf:
            if extractFromPDFs {
                images = try await extractImagesFromPDF(document)
            }
        case .jpeg, .png, .tiff, .gif:
            images = try await extractSingleImage(document)
        default:
            // For other formats, check if document references external images
            images = try await extractReferencedImages(document)
        }
        
        // Optimize all extracted images
        let optimizedImages = try await optimizeImages(images)
        
        logInfo(
            "Extracted and optimized \(optimizedImages.count) images from document",
            category: "Diaplasion"
        )
        
        return optimizedImages
    }
    
    // MARK: - Private Implementation
    
    private func extractImagesFromPDF(_ document: DocumentSourceComponent) async throws -> [ExtractedImage] {
        guard let pdfURL = URL(string: document.sourceURI) else {
            throw ImageExtractionError.invalidDocumentPath
        }
        
        #if canImport(PDFKit)
        let pdfDocument = PDFDocument(url: pdfURL)
        guard let pdfDocument = pdfDocument else {
            throw ImageExtractionError.pdfLoadFailed
        }
        
        var images: [ExtractedImage] = []
        let pageCount = pdfDocument.pageCount
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // Extract images from this page
            let pageImages = try await extractImagesFromPDFPage(page, pageIndex: pageIndex)
            images.append(contentsOf: pageImages)
        }
        
        return images
        #else
        throw ImageExtractionError.platformUnsupported
        #endif
    }
    
    #if canImport(PDFKit)
    private func extractImagesFromPDFPage(_ page: PDFPage, pageIndex: Int) async throws -> [ExtractedImage] {
        var images: [ExtractedImage] = []
        
        // Get page bounds
        let pageRect = page.bounds(for: .mediaBox)
        
        // Render page as image to extract content
        #if canImport(AppKit)
        let thumbnail = page.thumbnail(of: CGSize(width: pageRect.width, height: pageRect.height), for: .mediaBox)
        var imageRect = CGRect(x: 0, y: 0, width: thumbnail.size.width, height: thumbnail.size.height)
        if let cgImage = thumbnail.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) {
            // Try to detect individual images in the rendered page
            let detectedImages = try await detectImagesInCGImage(cgImage, pageIndex: pageIndex)
            images.append(contentsOf: detectedImages)
        }
        #elseif canImport(UIKit)
        let thumbnail = page.thumbnail(of: CGSize(width: pageRect.width, height: pageRect.height), for: .mediaBox)
        if let cgImage = thumbnail.cgImage {
            let detectedImages = try await detectImagesInCGImage(cgImage, pageIndex: pageIndex)
            images.append(contentsOf: detectedImages)
        }
        #endif
        
        return images
    }
    #endif
    
    private func extractSingleImage(_ document: DocumentSourceComponent) async throws -> [ExtractedImage] {
        guard let imageURL = URL(string: document.sourceURI) else {
            throw ImageExtractionError.invalidDocumentPath
        }
        
        let imageData = try Data(contentsOf: imageURL)
        let imageFormat = detectImageFormat(from: imageData)
        
        // Generate alt text if enabled
        let altText = generateAltText ? await generateAltTextForImage(imageData) : nil
        
        return [
            ExtractedImage(
                id: "cover",
                imageData: imageData,
                format: imageFormat,
                width: nil, // Will be determined during optimization
                height: nil,
                altText: altText,
                caption: nil,
                position: .cover,
                sourcePath: document.sourceURI
            )
        ]
    }
    
    private func extractReferencedImages(_ document: DocumentSourceComponent) async throws -> [ExtractedImage] {
        // For text-based documents, extract any referenced image files
        // This is a simplified implementation
        return []
    }
    
    private func detectImagesInCGImage(_ cgImage: CGImage, pageIndex: Int) async throws -> [ExtractedImage] {
        var images: [ExtractedImage] = []
        
        // Simple approach: treat the entire page as one image
        // In practice, you'd want to detect individual image regions
        guard let imageData = cgImageToImageData(cgImage) else {
            throw ImageExtractionError.imageConversionFailed
        }
        
        let altText = generateAltText ? await generateAltTextForImage(imageData) : nil
        
        images.append(
            ExtractedImage(
                id: "page_\(pageIndex)",
                imageData: imageData,
                format: .png,
                width: cgImage.width,
                height: cgImage.height,
                altText: altText,
                caption: nil,
                position: .inline,
                sourcePath: nil
            )
        )
        
        return images
    }
    
    private func optimizeImages(_ images: [ExtractedImage]) async throws -> [ExtractedImage] {
        return try await withThrowingTaskGroup(of: ExtractedImage.self) { group in
            var optimizedImages: [ExtractedImage] = []
            
            for image in images {
                group.addTask {
                    return try await self.optimizeImage(image)
                }
            }
            
            for try await optimizedImage in group {
                optimizedImages.append(optimizedImage)
            }
            
            return optimizedImages
        }
    }
    
    private func optimizeImage(_ image: ExtractedImage) async throws -> ExtractedImage {
        guard let cgImage = createCGImage(from: image.imageData, format: image.format) else {
            return image // Return original if optimization fails
        }
        
        // Resize if necessary
        let targetSize = calculateTargetSize(
            currentWidth: cgImage.width,
            currentHeight: cgImage.height
        )
        
        guard let resizedImage = resizeImage(cgImage, targetSize: targetSize) else {
            return image
        }
        
        // Convert to optimized data
        guard let optimizedData = cgImageToImageData(resizedImage, format: .jpeg, quality: jpegQuality) else {
            return image
        }
        
        return ExtractedImage(
            id: image.id,
            imageData: optimizedData,
            format: .jpeg,
            width: resizedImage.width,
            height: resizedImage.height,
            altText: image.altText,
            caption: image.caption,
            position: image.position,
            sourcePath: image.sourcePath
        )
    }
    
    private func calculateTargetSize(currentWidth: Int, currentHeight: Int) -> CGSize {
        let maxDimension = CGFloat(maxImageSize)
        
        if currentWidth <= maxImageSize && currentHeight <= maxImageSize {
            return CGSize(width: currentWidth, height: currentHeight)
        }
        
        let aspectRatio = CGFloat(currentWidth) / CGFloat(currentHeight)
        
        if currentWidth > currentHeight {
            return CGSize(
                width: maxDimension,
                height: maxDimension / aspectRatio
            )
        } else {
            return CGSize(
                width: maxDimension * aspectRatio,
                height: maxDimension
            )
        }
    }
    
    private func resizeImage(_ image: CGImage, targetSize: CGSize) -> CGImage? {
        #if canImport(CoreGraphics)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        
        return context.makeImage()
        #else
        return image
        #endif
    }
    
    private func createCGImage(from data: Data, format: ImageFormat) -> CGImage? {
        #if canImport(CoreGraphics)
        guard let dataProvider = CGDataProvider(data: data as CFData) else {
            return nil
        }
        
        switch format {
        case .png:
            return CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        case .jpeg:
            return CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        case .tiff, .gif:
            // For TIFF and GIF, use CGImageSource
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        #else
        return nil
        #endif
    }
    
    private func cgImageToImageData(_ cgImage: CGImage, format: ImageFormat = .png, quality: Double = 0.85) -> Data? {
        #if canImport(CoreGraphics)
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, format.utType, 1, nil) else {
            return nil
        }
        
        let options: [NSString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        return mutableData as Data
        #else
        return nil
        #endif
    }
    
    private func detectImageFormat(from data: Data) -> ImageFormat {
        let headers = data.prefix(8)
        
        if headers.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        } else if headers.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        } else if headers.starts(with: [0x49, 0x49, 0x2A, 0x00]) ||
                  headers.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return .tiff
        } else if headers.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return .gif
        } else {
            return .png // Default assumption
        }
    }
    
    private func generateAltTextForImage(_ imageData: Data) async -> String? {
        // Simplified alt text generation
        // In practice, this would use OCR or machine learning to describe the image
        
        #if canImport(Vision)
        guard let image = createCGImage(from: imageData, format: .png) else {
            return nil
        }
        
        let request = VNGenerateImageFeaturePrintRequest()
        
        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            
            if let result = request.results?.first {
                // Use feature print to generate a basic description
                return generateDescriptionFromFeaturePrint(result)
            }
        } catch {
            logWarning(
                "Failed to generate image description: \(error)",
                category: "Diaplasion"
            )
        }
        #endif
        
        return "Image extracted from document"
    }
    
    private func generateDescriptionFromFeaturePrint(_ featurePrint: VNFeaturePrintObservation) -> String {
        // Very simplified description generation
        return "Visual content from document"
    }
}

// MARK: - Supporting Types

/// Extracted image from a document.
public struct ExtractedImage: Sendable {
    public let id: String
    public let imageData: Data
    public let format: ImageFormat
    public let width: Int?
    public let height: Int?
    public let altText: String?
    public let caption: String?
    public let position: ImagePosition
    public let sourcePath: String?
    
    public init(
        id: String,
        imageData: Data,
        format: ImageFormat,
        width: Int?,
        height: Int?,
        altText: String?,
        caption: String?,
        position: ImagePosition,
        sourcePath: String?
    ) {
        self.id = id
        self.imageData = imageData
        self.format = format
        self.width = width
        self.height = height
        self.altText = altText
        self.caption = caption
        self.position = position
        self.sourcePath = sourcePath
    }
    
    /// File extension for this image format.
    public var fileExtension: String {
        return format.fileExtension
    }
    
    /// MIME type for this image format.
    public var mimeType: String {
        return format.mimeType
    }
    
    /// Estimated file size in KB.
    public var sizeKB: Double {
        return Double(imageData.count) / 1024.0
    }
}

/// Supported image formats.
public enum ImageFormat: String, CaseIterable, Sendable {
    case png = "png"
    case jpeg = "jpeg"
    case tiff = "tiff"
    case gif = "gif"
    
    /// Uniform Type Identifier for the format.
    public var utType: CFString {
        switch self {
        case .png: return UTType.png.identifier as CFString
        case .jpeg: return UTType.jpeg.identifier as CFString
        case .tiff: return UTType.tiff.identifier as CFString
        case .gif: return UTType.gif.identifier as CFString
        }
    }
    
    /// File extension.
    public var fileExtension: String {
        return rawValue
    }
    
    /// MIME type.
    public var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        case .tiff: return "image/tiff"
        case .gif: return "image/gif"
        }
    }
}

/// Position of image in document.
public enum ImagePosition: String, CaseIterable, Sendable {
    case cover = "cover"
    case inline = "inline"
    case figure = "figure"
    case banner = "banner"
    case background = "background"
}

/// Image extraction errors.
public enum ImageExtractionError: LocalizedError {
    case invalidDocumentPath
    case pdfLoadFailed
    case imageConversionFailed
    case platformUnsupported
    case unsupportedFormat
    
    public var errorDescription: String? {
        switch self {
        case .invalidDocumentPath:
            return "Invalid document path provided"
        case .pdfLoadFailed:
            return "Failed to load PDF document"
        case .imageConversionFailed:
            return "Failed to convert image data"
        case .platformUnsupported:
            return "Image extraction not supported on this platform"
        case .unsupportedFormat:
            return "Unsupported document format for image extraction"
        }
    }
}

/// System that manages image extraction for EPUB generation.
public struct ImageExtractionSystem: System {
    public var name: String { "ImageExtraction" }
    
    private let extractor: ImageExtractor
    
    public init(extractor: ImageExtractor = ImageExtractor()) {
        self.extractor = extractor
    }
    
    public func update(world: World) async {
        let entities = await world.query(
            DocumentSourceComponent.self,
            TransformRequestComponent.self
        )
        
        for (entity, document, transform) in entities {
            // Skip if not processing EPUB
            if !transform.targetFormats.contains(.epub) {
                continue
            }
            
            // Skip if already processed
            if await world.hasComponent(entity, ExtractedImagesComponent.self) {
                continue
            }
            
            do {
                let images = try await extractor.extractImages(from: document)
                let component = ExtractedImagesComponent(
                    images: images,
                    extractionDate: Date(),
                    totalSizeKB: images.reduce(0) { $0 + $1.sizeKB }
                )
                
                await world.addComponent(entity, component)
                
                logInfo(
                    "Extracted \(images.count) images for entity \(entity)",
                    category: "Diaplasion"
                )
                
            } catch {
                logError(
                    "Image extraction failed: \(error)",
                    category: "Diaplasion"
                )
                
                // Add error component
                await world.addComponent(entity, ImageExtractionErrorComponent(
                    error: error.localizedDescription,
                    timestamp: Date()
                ))
            }
        }
    }
}

/// Component containing extracted images.
public struct ExtractedImagesComponent: Component {
    public let images: [ExtractedImage]
    public let extractionDate: Date
    public let totalSizeKB: Double
    
    public init(
        images: [ExtractedImage],
        extractionDate: Date,
        totalSizeKB: Double
    ) {
        self.images = images
        self.extractionDate = extractionDate
        self.totalSizeKB = totalSizeKB
    }
}

/// Component for image extraction errors.
public struct ImageExtractionErrorComponent: Component {
    public let error: String
    public let timestamp: Date
    
    public init(error: String, timestamp: Date) {
        self.error = error
        self.timestamp = timestamp
    }
}