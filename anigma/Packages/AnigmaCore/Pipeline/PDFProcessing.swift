//
//  PDFProcessing.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import ContractsCore
import CoreGraphics
import Foundation

#if canImport(PDFKit)
import PDFKit
#endif

/// Errors that can occur while parsing PDFs.
enum PDFProcessingError: Error {
    case invalidDocument
    case invalidPage(index: Int)
}

/// Parses PDF byte streams and exposes metadata needed by the pipeline contracts.
struct PDFProcessing {
    private let data: Data
    #if canImport(PDFKit)
    private let document: PDFDocument
    #else
    private let document: CGPDFDocument
    #endif

    init(data: Data) throws {
        self.data = data
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else {
            throw PDFProcessingError.invalidDocument
        }
        self.document = document
        #else
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else {
            throw PDFProcessingError.invalidDocument
        }
        self.document = document
        #endif
    }

    var pageCount: Int {
        #if canImport(PDFKit)
        document.pageCount
        #else
        document.numberOfPages
        #endif
    }

    func boundingBox(forPage index: Int) throws -> BoundingBoxRef {
        let rect: CGRect
        #if canImport(PDFKit)
        guard let page = document.page(at: index) else {
            throw PDFProcessingError.invalidPage(index: index)
        }
        rect = page.bounds(for: .mediaBox)
        #else
        guard let page = document.page(at: index + 1) else {
            throw PDFProcessingError.invalidPage(index: index)
        }
        rect = page.getBoxRect(.mediaBox)
        #endif
        return BoundingBoxRef(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.width),
            height: Double(rect.height)
        )
    }

    func text(forPage index: Int) throws -> String {
        #if canImport(PDFKit)
        guard let page = document.page(at: index) else {
            throw PDFProcessingError.invalidPage(index: index)
        }
        return page.string ?? ""
        #else
        return ""
        #endif
    }
}
