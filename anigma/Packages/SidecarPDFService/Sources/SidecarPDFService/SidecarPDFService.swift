//
//  SidecarPDFService.swift
//  SidecarPDFService
//
//  Heavy PDF operations via PDFium. Designed to run in isolated process.
//

import Foundation
import AnigmaNativeShims

// MARK: - Error Types

public enum PDFServiceError: LocalizedError {
    case invalidInput(String)
    case documentOpenFailed(String)
    case documentCorrupted(String)
    case pageNotFound(Int)
    case renderingFailed(String)
    case outOfMemory
    case internalError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .documentOpenFailed(let msg): return "Failed to open document: \(msg)"
        case .documentCorrupted(let msg): return "Document corrupted: \(msg)"
        case .pageNotFound(let page): return "Page \(page) not found"
        case .renderingFailed(let msg): return "Rendering failed: \(msg)"
        case .outOfMemory: return "Out of memory"
        case .internalError(let msg): return "Internal error: \(msg)"
        }
    }
}

// MARK: - Protocol

public protocol PDFMutator {
    /// Merge multiple PDF documents into one
    func merge(pdfs: [Data]) throws -> Data
    
    /// Split PDF at given page index; returns (before, from)
    func split(pdf: Data, at page: Int) throws -> (Data, Data)
    
    /// Extract specific pages from PDF
    func extract(pdf: Data, pages: [Int]) throws -> Data
    
    /// Rasterize a single page to RGBA image data
    func rasterize(pdf: Data, page: Int, dpi: Int) throws -> RasterizedPage
}

public struct RasterizedPage {
    public let width: Int
    public let height: Int
    public let stride: Int
    public let pixelData: Data // RGBA8888 format
    
    public init(width: Int, height: Int, stride: Int, pixelData: Data) {
        self.width = width
        self.height = height
        self.stride = stride
        self.pixelData = pixelData
    }
}

// MARK: - Implementation

public class NativePDFService: PDFMutator {
    private static let initialized: Bool = {
        var err = anigma_capsule_error_t()
        let status = anigma_pdf_initialize(&err)
        guard status == ANIGMA_OK else {
            NSLog("Failed to initialize PDFium: \(status)")
            return false
        }
        return true
    }()
    
    public init() {
        _ = Self.initialized
    }
    
    deinit {
        var err = anigma_capsule_error_t()
        _ = anigma_pdf_destroy_library(&err)
    }
    
    public func merge(pdfs: [Data]) throws -> Data {
        guard !pdfs.isEmpty else {
            throw PDFServiceError.invalidInput("No PDFs provided")
        }
        
        if pdfs.count == 1 {
            return pdfs[0]
        }
        
        throw PDFServiceError.internalError("PDF merge not yet implemented in sidecar")
    }
    
    public func split(pdf: Data, at pageIndex: Int) throws -> (Data, Data) {
        let doc = try loadDocument(from: pdf)
        defer { anigma_pdf_document_destroy(doc, nil) }
        
        var pageCount: Int32 = 0
        let countStatus = anigma_pdf_document_get_page_count(doc, &pageCount, nil)
        guard countStatus == ANIGMA_OK else {
            throw PDFServiceError.internalError("Failed to get page count")
        }
        
        guard pageIndex > 0 && pageIndex < Int(pageCount) else {
            throw PDFServiceError.pageNotFound(pageIndex)
        }
        
        throw PDFServiceError.internalError("PDF split not yet implemented in sidecar")
    }
    
    public func extract(pdf: Data, pages: [Int]) throws -> Data {
        guard !pages.isEmpty else {
            throw PDFServiceError.invalidInput("No pages specified")
        }
        
        let doc = try loadDocument(from: pdf)
        defer { anigma_pdf_document_destroy(doc, nil) }
        
        var pageCount: Int32 = 0
        let countStatus = anigma_pdf_document_get_page_count(doc, &pageCount, nil)
        guard countStatus == ANIGMA_OK else {
            throw PDFServiceError.internalError("Failed to get page count")
        }
        
        for page in pages {
            guard page >= 0 && page < Int(pageCount) else {
                throw PDFServiceError.pageNotFound(page)
            }
        }
        
        throw PDFServiceError.internalError("PDF extraction not yet implemented in sidecar")
    }
    
    public func rasterize(pdf: Data, page: Int, dpi: Int) throws -> RasterizedPage {
        guard dpi > 0 && dpi <= 600 else {
            throw PDFServiceError.invalidInput("DPI must be between 1 and 600")
        }
        
        let doc = try loadDocument(from: pdf)
        defer { anigma_pdf_document_destroy(doc, nil) }
        
        var pageCount: Int32 = 0
        let countStatus = anigma_pdf_document_get_page_count(doc, &pageCount, nil)
        guard countStatus == ANIGMA_OK else {
            throw PDFServiceError.internalError("Failed to get page count")
        }
        
        guard page >= 0 && page < Int(pageCount) else {
            throw PDFServiceError.pageNotFound(page)
        }
        
        var pageHandle: anigma_pdf_page_t?
        let pageStatus = anigma_pdf_page_load(doc, Int32(page), &pageHandle, nil)
        guard pageStatus == ANIGMA_OK, let _ = pageHandle else {
            throw PDFServiceError.pageNotFound(page)
        }
        defer { anigma_pdf_page_destroy(pageHandle, nil) }
        
        var width: Double = 0
        var height: Double = 0
        let sizeStatus = anigma_pdf_page_get_size(pageHandle, &width, &height, nil)
        guard sizeStatus == ANIGMA_OK else {
            throw PDFServiceError.renderingFailed("Failed to get page size")
        }
        
        let dpiFloat = Float(dpi) / 72.0
        let pixelWidth = Int(ceil(width * Double(dpiFloat)))
        let pixelHeight = Int(ceil(height * Double(dpiFloat)))
        
        guard pixelWidth > 0 && pixelHeight > 0 else {
            throw PDFServiceError.invalidInput("Invalid page dimensions")
        }
        
        var bitmap: anigma_pdf_bitmap_t?
        let bitmapStatus = anigma_pdf_bitmap_create(Int32(pixelWidth), Int32(pixelHeight), true, &bitmap, nil)
        guard bitmapStatus == ANIGMA_OK, let _ = bitmap else {
            throw PDFServiceError.outOfMemory
        }
        defer { anigma_pdf_bitmap_destroy(bitmap, nil) }
        
        let renderStatus = anigma_pdf_page_render_to_bitmap(
            pageHandle, bitmap, 0, 0, Int32(pixelWidth), Int32(pixelHeight), 0, 0, nil
        )
        guard renderStatus == ANIGMA_OK else {
            throw PDFServiceError.renderingFailed("Failed to render page")
        }
        
        var buffer: UnsafeMutablePointer<UInt8>?
        var stride: Int32 = 0
        let bufferStatus = anigma_pdf_bitmap_get_buffer(bitmap, &buffer, &stride, nil)
        guard bufferStatus == ANIGMA_OK, let pixelBuffer = buffer else {
            throw PDFServiceError.renderingFailed("Failed to get bitmap buffer")
        }
        
        let totalBytes = Int(stride) * pixelHeight
        let pixelData = Data(bytes: pixelBuffer, count: totalBytes)
        
        return RasterizedPage(
            width: pixelWidth,
            height: pixelHeight,
            stride: Int(stride),
            pixelData: pixelData
        )
    }
    
    // MARK: - Helpers
    
    private func loadDocument(from data: Data) throws -> anigma_pdf_document_t {
        var doc: anigma_pdf_document_t?
        var err = anigma_capsule_error_t()
        
        let status = data.withUnsafeBytes { buffer in
            anigma_pdf_document_create_from_bytes(
                buffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                &doc,
                &err
            )
        }
        
        guard status == ANIGMA_OK, let document = doc else {
            if status == ANIGMA_ERR_CORRUPT_DATA {
                throw PDFServiceError.documentCorrupted("PDF file is corrupted")
            } else {
                throw PDFServiceError.documentOpenFailed("Status code: \(status)")
            }
        }
        
        return document
    }
}
