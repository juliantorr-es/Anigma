//
//  PDFiumProvider.swift
//  PlatformCore
//
//  Linux PDF provider using PDFium library.
//

import CapabilityCore
import Foundation
import os

#if os(Linux)
    import CPDFium

    /// PDF provider for Linux using PDFium library.
    /// Note: This requires PDFium to be installed on the system.
    public final class PDFiumProvider: CapabilityProvider, PDFRenderingCapability,
        PDFSurgeryCapability {
        public let providerId: String = "anigma.provider.pdf.pdfium.linux"

        public var supportedCapabilities: [String] {
            [
                CapabilityIds.pdfRender,
                CapabilityIds.pdfSurgery
            ]
        }

        public var documentURL: URL? { nil }
        public var pageCount: Int? { nil }

        public init() {}

        // MARK: - PDFRenderingCapability

        public func renderPagesToBitmap(pdfData: Data, pages: [Int]?, dpi: Int) async throws
            -> [Data] {
            let indices = try withDocument(pdfData: pdfData) { document -> [Int] in
                let count = Int(FPDF_GetPageCount(document))
                if let pages {
                    return pages.filter { $0 >= 0 && $0 < count }
                }
                return Array(0..<count)
            }

            return try indices.map { index in
                guard
                    let data = try renderPagePNG(
                        pdfData: pdfData,
                        pageIndex: index,
                        dpi: dpi
                    )
                else {
                    throw pdfiumError("Failed to render page \(index)")
                }
                return data
            }
        }

        public func renderPage(pdfData: Data, pageNumber: Int, resolution: CGFloat) async throws
            -> Data? {
            let index = pageNumber - 1
            return try renderPagePNG(
                pdfData: pdfData,
                pageIndex: index,
                dpi: Int(resolution)
            )
        }

        public func dimensions(pdfData: Data, forPage pageNumber: Int) async throws -> CGSize? {
            let index = pageNumber - 1
            return try withDocument(pdfData: pdfData) { document in
                guard let page = FPDF_LoadPage(document, Int32(index)) else { return nil }
                defer { FPDF_ClosePage(page) }
                let width = Double(FPDF_GetPageWidthF(page))
                let height = Double(FPDF_GetPageHeightF(page))
                return CGSize(width: width, height: height)
            }
        }

        public func extractText(pdfData: Data) async throws -> String {
            return try withDocument(pdfData: pdfData) { document in
                let pageCount = Int(FPDF_GetPageCount(document))
                var result = ""
                for index in 0..<pageCount {
                    guard let page = FPDF_LoadPage(document, Int32(index)) else { continue }
                    defer { FPDF_ClosePage(page) }
                    result += try extractText(page: page)
                    if index < pageCount - 1 {
                        result += "\n"
                    }
                }
                return result
            }
        }

        public func extractText(pdfData: Data, pageNumber: Int) async throws -> String? {
            let index = pageNumber - 1
            return try withDocument(pdfData: pdfData) { document in
                guard let page = FPDF_LoadPage(document, Int32(index)) else { return nil }
                defer { FPDF_ClosePage(page) }
                return try extractText(page: page)
            }
        }

        public func getMetadata(pdfData: Data) async throws -> [String: String] {
            return try withDocument(pdfData: pdfData) { document in
                var metadata: [String: String] = [:]
                let keys = ["Title", "Author", "Subject", "Keywords", "Creator", "Producer"]
                for key in keys {
                    if let value = readMetadata(document: document, key: key) {
                        metadata[key.lowercased()] = value
                    }
                }
                return metadata
            }
        }

        // MARK: - PDFSurgeryCapability

        public func merge(pdfs: [Data]) async throws -> Data {
            try ensureInitialized()
            guard let outputDoc = FPDF_CreateNewDocument() else {
                throw pdfiumError("Failed to create output document")
            }
            defer { FPDF_CloseDocument(outputDoc) }

            for pdf in pdfs {
                try withDocument(pdfData: pdf) { document in
                    let count = Int(FPDF_GetPageCount(document))
                    let range = pageRangeString(for: Array(0..<count))
                    let result = range.withCString { ptr in
                        FPDF_ImportPages(outputDoc, document, ptr, 0)
                    }
                    if result == 0 {
                        throw pdfiumError("Failed to import pages")
                    }
                }
            }

            return try save(document: outputDoc)
        }

        public func split(pdfData: Data, pageRanges: [[Int]]) async throws -> [Data] {
            try ensureInitialized()
            return try withDocument(pdfData: pdfData) { document in
                var outputs: [Data] = []
                let pageCount = Int(FPDF_GetPageCount(document))
                for range in pageRanges {
                    let filtered = range.filter { $0 >= 0 && $0 < pageCount }
                    guard !filtered.isEmpty else {
                        throw CapabilityError.invalidInput("Split range is empty")
                    }
                    guard let outputDoc = FPDF_CreateNewDocument() else {
                        throw pdfiumError("Failed to create output document")
                    }
                    defer { FPDF_CloseDocument(outputDoc) }
                    let rangeString = pageRangeString(for: filtered)
                    let result = rangeString.withCString { ptr in
                        FPDF_ImportPages(outputDoc, document, ptr, 0)
                    }
                    if result == 0 {
                        throw pdfiumError("Failed to import pages")
                    }
                    outputs.append(try save(document: outputDoc))
                }
                return outputs
            }
        }

        public func rotatePages(pdfData: Data, pageNumbers: [Int], by rotationAngle: Int)
            async throws -> Data {
            try ensureInitialized()
            return try withDocument(pdfData: pdfData) { document in
                let rotation = ((rotationAngle / 90) % 4 + 4) % 4
                for pageNumber in pageNumbers {
                    let index = pageNumber - 1
                    guard let page = FPDF_LoadPage(document, Int32(index)) else { continue }
                    defer { FPDF_ClosePage(page) }
                    FPDFPage_SetRotation(page, Int32(rotation))
                }
                return try save(document: document)
            }
        }

        public func removePages(pdfData: Data, pageNumbers: [Int]) async throws -> Data {
            try ensureInitialized()
            return try withDocument(pdfData: pdfData) { document in
                let count = Int(FPDF_GetPageCount(document))
                let removeSet = Set(pageNumbers.map { $0 - 1 })
                let remaining = (0..<count).filter { !removeSet.contains($0) }
                guard !remaining.isEmpty else {
                    throw CapabilityError.invalidInput("No pages remain after removal")
                }
                guard let outputDoc = FPDF_CreateNewDocument() else {
                    throw pdfiumError("Failed to create output document")
                }
                defer { FPDF_CloseDocument(outputDoc) }
                let range = pageRangeString(for: remaining)
                let result = range.withCString { ptr in
                    FPDF_ImportPages(outputDoc, document, ptr, 0)
                }
                if result == 0 {
                    throw pdfiumError("Failed to import pages")
                }
                return try save(document: outputDoc)
            }
        }

        private func ensureInitialized() throws {
            try PDFiumLibrary.ensureInitialized()
        }

        private func withDocument<T>(
            pdfData: Data,
            _ work: (FPDF_DOCUMENT) throws -> T
        ) throws -> T {
            try ensureInitialized()
            var data = pdfData
            return try data.withUnsafeMutableBytes { buffer in
                guard let base = buffer.baseAddress else {
                    throw CapabilityError.invalidInput("Empty PDF data")
                }
                guard let document = FPDF_LoadMemDocument(base, Int32(buffer.count), nil) else {
                    throw pdfiumError("Failed to open document")
                }
                defer { FPDF_CloseDocument(document) }
                return try work(document)
            }
        }

        private func renderPagePNG(pdfData: Data, pageIndex: Int, dpi: Int) throws -> Data? {
            try withDocument(pdfData: pdfData) { document in
                guard let page = FPDF_LoadPage(document, Int32(pageIndex)) else { return nil }
                defer { FPDF_ClosePage(page) }

                let pageWidth = Double(FPDF_GetPageWidthF(page))
                let pageHeight = Double(FPDF_GetPageHeightF(page))
                let scale = Double(dpi) / 72.0
                let width = Int(pageWidth * scale)
                let height = Int(pageHeight * scale)
                guard width > 0, height > 0 else { return nil }

                guard
                    let bitmap = FPDFBitmap_CreateEx(
                        Int32(width),
                        Int32(height),
                        FPDFBitmap_BGRA,
                        nil,
                        0
                    )
                else {
                    throw pdfiumError("Failed to create bitmap")
                }
                defer { FPDFBitmap_Destroy(bitmap) }

                FPDFBitmap_FillRect(bitmap, 0, 0, Int32(width), Int32(height), 0xFFFF_FFFF)
                FPDF_RenderPageBitmap(
                    bitmap,
                    page,
                    0,
                    0,
                    Int32(width),
                    Int32(height),
                    0,
                    Int32(FPDF_ANNOT)
                )

                guard let buffer = FPDFBitmap_GetBuffer(bitmap) else { return nil }
                let stride = Int(FPDFBitmap_GetStride(bitmap))
                let byteCount = stride * height
                let src = buffer.bindMemory(to: UInt8.self, capacity: byteCount)
                var rgba = [UInt8](repeating: 0, count: height * width * 4)
                for row in 0..<height {
                    let rowStart = row * stride
                    let destStart = row * width * 4
                    for col in 0..<width {
                        let idx = rowStart + col * 4
                        let dest = destStart + col * 4
                        let b = src[idx]
                        let g = src[idx + 1]
                        let r = src[idx + 2]
                        let a = src[idx + 3]
                        rgba[dest] = r
                        rgba[dest + 1] = g
                        rgba[dest + 2] = b
                        rgba[dest + 3] = a
                    }
                }

                return try PNGEncoder.encodeRGBA(
                    width: width,
                    height: height,
                    rgba: rgba,
                    bytesPerRow: width * 4
                )
            }
        }

        private func extractText(page: FPDF_PAGE) throws -> String {
            guard let textPage = FPDFText_LoadPage(page) else {
                return ""
            }
            defer { FPDFText_ClosePage(textPage) }
            let charCount = Int(FPDFText_CountChars(textPage))
            guard charCount > 0 else { return "" }
            var buffer = [UInt16](repeating: 0, count: charCount + 1)
            let readCount = FPDFText_GetText(
                textPage,
                0,
                Int32(charCount),
                &buffer
            )
            if readCount <= 0 {
                return ""
            }
            return String(decoding: buffer, as: UTF16.self).trimmingCharacters(
                in: .whitespacesAndNewlines)
        }

        private func readMetadata(document: FPDF_DOCUMENT, key: String) -> String? {
            let keyData = key.data(using: .ascii) ?? Data()
            return keyData.withUnsafeBytes { keyBuffer in
                guard let keyPtr = keyBuffer.baseAddress?.assumingMemoryBound(to: Int8.self) else {
                    return nil
                }
                let len = FPDF_GetMetaText(document, keyPtr, nil, 0)
                guard len > 2 else { return nil }
                var buffer = [UInt16](repeating: 0, count: Int(len / 2))
                _ = buffer.withUnsafeMutableBytes { buf in
                    FPDF_GetMetaText(document, keyPtr, buf.baseAddress, len)
                }
                return String(decoding: buffer, as: UTF16.self).trimmingCharacters(
                    in: .whitespacesAndNewlines)
            }
        }

        private func pageRangeString(for indices: [Int]) -> String {
            indices.map { String($0 + 1) }.joined(separator: ",")
        }

        private func save(document: FPDF_DOCUMENT) throws -> Data {
            let writer = PDFiumFileWriter()
            var context = PDFiumFileWriteContext(
                fileWrite: FPDF_FILEWRITE(version: 1, WriteBlock: pdfiumWriteBlock),
                writer: Unmanaged.passRetained(writer)
            )
            defer { context.writer.release() }
            let result = withUnsafeMutablePointer(to: &context) { contextPtr -> Int32 in
                let fileWritePtr = UnsafeMutableRawPointer(contextPtr)
                    .assumingMemoryBound(to: FPDF_FILEWRITE.self)
                return FPDF_SaveAsCopy(document, fileWritePtr, 0)
            }
            guard result == 1 else {
                throw pdfiumError("Failed to save document")
            }
            return writer.data
        }

        private func pdfiumError(_ message: String) -> Error {
            let errorCode = FPDF_GetLastError()
            return CapabilityError.providerFailed(
                providerId,
                NSError(
                    domain: "PDFiumProvider",
                    code: Int(errorCode),
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            )
        }
    }

    private final class PDFiumFileWriter {
        var data = Data()
    }

    private struct PDFiumFileWriteContext {
        var fileWrite: FPDF_FILEWRITE
        var writer: Unmanaged<PDFiumFileWriter>
    }

    private enum PDFiumLibrary {
        private static let initialized = OSAllocatedUnfairLock(initialState: false)

        static func ensureInitialized() throws {
            initialized.withLock { isInit in
                if isInit { return }
                FPDF_InitLibrary()
                isInit = true
            }
        }
    }

    private func pdfiumWriteBlock(
        _ fileWrite: UnsafeMutablePointer<FPDF_FILEWRITE>?,
        _ data: UnsafePointer<UInt8>?,
        _ size: UInt32
    ) -> Int32 {
        guard let fileWrite, let data else { return 0 }
        let context = fileWrite.withMemoryRebound(
            to: PDFiumFileWriteContext.self,
            capacity: 1
        ) { $0 }
        let writer = context.pointee.writer.takeUnretainedValue()
        writer.data.append(data, count: Int(size))
        return 1
    }
#endif
