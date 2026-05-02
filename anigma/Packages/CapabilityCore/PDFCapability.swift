//
//  PDFCapability.swift
//  CapabilityCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Capability for rendering PDF documents and extracting metadata.
public protocol PDFRenderingCapability: Capability {
    /// The URL of the PDF document being handled (if applicable).
    var documentURL: URL? { get }

    /// The total number of pages in the document (if loaded).
    var pageCount: Int? { get }

    /// Renders specified pages of a PDF to bitmap images.
    /// - Parameters:
    ///   - pdfData: The raw PDF file data.
    ///   - pages: The page indices to render (0-indexed). If nil, renders all pages.
    ///   - dpi: Dots per inch for the output bitmap.
    /// - Returns: An array of bitmap data (e.g., PNG or JPEG).
    func renderPagesToBitmap(pdfData: Data, pages: [Int]?, dpi: Int) async throws -> [Data]

    /// Renders a specific page to a bitmap image.
    /// - Parameters:
    ///   - pdfData: The raw PDF file data.
    ///   - pageNumber: The 1-based page number.
    ///   - resolution: The resolution in dots per inch (DPI).
    /// - Returns: Image data (e.g., PNG or TIFF format), or nil on failure.
    func renderPage(pdfData: Data, pageNumber: Int, resolution: CGFloat) async throws -> Data?

    /// Returns the dimensions of a specific page.
    /// - Parameters:
    ///   - pdfData: The raw PDF file data.
    ///   - pageNumber: The 1-based page number.
    /// - Returns: The size of the page in points, or nil if the page number is invalid.
    func dimensions(pdfData: Data, forPage pageNumber: Int) async throws -> CGSize?

    /// Extracts text content from a PDF.
    /// - Parameter pdfData: The raw PDF file data.
    /// - Returns: The extracted text.
    func extractText(pdfData: Data) async throws -> String

    /// Extracts text content from a specific page.
    /// - Parameters:
    ///   - pdfData: The raw PDF file data.
    ///   - pageNumber: The 1-based page number.
    /// - Returns: A string containing all text from the page, or nil on failure.
    func extractText(pdfData: Data, pageNumber: Int) async throws -> String?

    /// Gets metadata from a PDF document.
    /// - Parameter pdfData: The raw PDF file data.
    /// - Returns: A dictionary of metadata keys and values.
    func getMetadata(pdfData: Data) async throws -> [String: String]
}

extension PDFRenderingCapability {
    public static var capabilityId: String { CapabilityIds.pdfRender }
}

/// Capability for structural PDF operations (merge, split, etc.).
public protocol PDFSurgeryCapability: Capability {
    /// Merges multiple PDF documents into one.
    /// - Parameter pdfs: Array of PDF data to merge.
    /// - Returns: Merged PDF data.
    func merge(pdfs: [Data]) async throws -> Data

    /// Splits a PDF into multiple documents based on page ranges.
    /// - Parameters:
    ///   - pdfData: The raw PDF data to split.
    ///   - pageRanges: Array of page index arrays. Each inner array defines a new document.
    /// - Returns: Array of split PDF data.
    func split(pdfData: Data, pageRanges: [[Int]]) async throws -> [Data]

    /// Rotates pages in a PDF document.
    /// - Parameters:
    ///   - pdfData: The raw PDF data.
    ///   - pageNumbers: The 1-based page numbers to rotate.
    ///   - rotationAngle: The angle of rotation in degrees (e.g., 90, 180, 270).
    /// - Returns: Modified PDF data.
    func rotatePages(pdfData: Data, pageNumbers: [Int], by rotationAngle: Int) async throws -> Data

    /// Removes pages from a PDF document.
    /// - Parameters:
    ///   - pdfData: The raw PDF data.
    ///   - pageNumbers: The 1-based page numbers to remove.
    /// - Returns: Modified PDF data.
    func removePages(pdfData: Data, pageNumbers: [Int]) async throws -> Data
}

extension PDFSurgeryCapability {
    public static var capabilityId: String { CapabilityIds.pdfSurgery }
}
