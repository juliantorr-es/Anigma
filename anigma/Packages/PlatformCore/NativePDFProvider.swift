//
//  NativePDFProvider.swift
//  PlatformCore
//
//  [Brief description of file purpose]
//

import CapabilityCore
import Foundation

#if canImport(PDFKit)
    import PDFKit

    public final class NativePDFProvider: CapabilityProvider, PDFRenderingCapability,
        PDFSurgeryCapability {
        public let providerId: String = "anigma.provider.pdf.native.mac"

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
            guard let document = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }

            var results: [Data] = []
            let pageCount = document.pageCount
            let indices = pages ?? Array(0..<pageCount)

            for index in indices {
                guard index >= 0 && index < pageCount else { continue }
                guard let page = document.page(at: index) else { continue }

                let bounds = page.bounds(for: .mediaBox)
                let scale = CGFloat(dpi) / 72.0
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

                #if os(macOS)
                    let image = NSImage(size: size)
                    image.lockFocus()
                    if let context = NSGraphicsContext.current?.cgContext {
                        context.setFillColor(NSColor.white.cgColor)
                        context.fill(CGRect(origin: .zero, size: size))
                        context.scaleBy(x: scale, y: scale)
                        page.draw(with: .mediaBox, to: context)
                    }
                    image.unlockFocus()

                    if let tiffData = image.tiffRepresentation,
                        let bitmapImage = NSBitmapImageRep(data: tiffData),
                        let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                        results.append(pngData)
                    }
                #else
                    // iOS implementation would use UIGraphicsImageRenderer
                    let renderer = UIGraphicsImageRenderer(size: size)
                    let pngData = renderer.pngData { context in
                        UIColor.white.setFill()
                        context.fill(CGRect(origin: .zero, size: size))
                        context.cgContext.saveGState()
                        context.cgContext.translateBy(x: 0, y: size.height)
                        context.cgContext.scaleBy(x: scale, y: -scale)
                        page.draw(with: .mediaBox, to: context.cgContext)
                        context.cgContext.restoreGState()
                    }
                    results.append(pngData)
                #endif
            }

            return results
        }

        public func renderPage(pdfData: Data, pageNumber: Int, resolution: CGFloat) async throws
            -> Data? {
            guard let document = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }

            let index = pageNumber - 1  // Convert 1-based to 0-based
            guard index >= 0 && index < document.pageCount else {
                return nil
            }

            guard let page = document.page(at: index) else {
                return nil
            }

            let bounds = page.bounds(for: .mediaBox)
            let scale = resolution / 72.0
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

            #if os(macOS)
                let image = NSImage(size: size)
                image.lockFocus()
                if let context = NSGraphicsContext.current?.cgContext {
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(CGRect(origin: .zero, size: size))
                    context.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: context)
                }
                image.unlockFocus()

                if let tiffData = image.tiffRepresentation,
                    let bitmapImage = NSBitmapImageRep(data: tiffData),
                    let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    return pngData
                }
                return nil
            #else
                let renderer = UIGraphicsImageRenderer(size: size)
                return renderer.pngData { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    context.cgContext.saveGState()
                    context.cgContext.translateBy(x: 0, y: size.height)
                    context.cgContext.scaleBy(x: scale, y: -scale)
                    page.draw(with: .mediaBox, to: context.cgContext)
                    context.cgContext.restoreGState()
                }
            #endif
        }

        public func dimensions(pdfData: Data, forPage pageNumber: Int) async throws -> CGSize? {
            guard let document = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }

            let index = pageNumber - 1  // Convert 1-based to 0-based
            guard index >= 0 && index < document.pageCount else {
                return nil
            }

            guard let page = document.page(at: index) else {
                return nil
            }

            return page.bounds(for: .mediaBox).size
        }

        public func extractText(pdfData: Data) async throws -> String {
            guard let document = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }
            return document.string ?? ""
        }

        public func extractText(pdfData: Data, pageNumber: Int) async throws -> String? {
            guard let document = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }

            let index = pageNumber - 1  // Convert 1-based to 0-based
            guard index >= 0 && index < document.pageCount else {
                return nil
            }

            guard let page = document.page(at: index) else {
                return nil
            }

            return page.string
        }

        public func getMetadata(pdfData: Data) async throws -> [String: String] {
            guard let document = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }

            var metadata: [String: String] = [:]
            if let attributes = document.documentAttributes {
                for (key, value) in attributes {
                    metadata[key.description] = "\(value)"
                }
            }
            return metadata
        }

        // MARK: - PDFSurgeryCapability

        public func merge(pdfs: [Data]) async throws -> Data {
            let resultDocument = PDFDocument()

            for pdfData in pdfs {
                guard let document = PDFDocument(data: pdfData) else {
                    throw CapabilityError.invalidInput("Invalid PDF data in merge list")
                }

                for i in 0..<document.pageCount {
                    if let page = document.page(at: i) {
                        resultDocument.insert(page, at: resultDocument.pageCount)
                    }
                }
            }

            guard let data = resultDocument.dataRepresentation() else {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "NativePDFProvider", code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to generate PDF data representation"
                        ]))
            }

            return data
        }

        public func split(pdfData: Data, pageRanges: [[Int]]) async throws -> [Data] {
            guard let sourceDocument = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }

            var results: [Data] = []

            for range in pageRanges {
                let newDocument = PDFDocument()
                for index in range {
                    if index >= 0 && index < sourceDocument.pageCount,
                        let page = sourceDocument.page(at: index) {
                        newDocument.insert(page, at: newDocument.pageCount)
                    }
                }
                if let data = newDocument.dataRepresentation() {
                    results.append(data)
                }
            }

            return results
        }

        public func rotatePages(pdfData: Data, pageNumbers: [Int], by rotationAngle: Int)
            async throws -> Data {
            guard let document = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }

            for pageNumber in pageNumbers {
                let index = pageNumber - 1  // Convert 1-based to 0-based
                guard index >= 0 && index < document.pageCount else { continue }
                guard let page = document.page(at: index) else { continue }

                page.rotation = (page.rotation + rotationAngle) % 360
            }

            guard let data = document.dataRepresentation() else {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "NativePDFProvider", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to generate rotated PDF"]))
            }

            return data
        }

        public func removePages(pdfData: Data, pageNumbers: [Int]) async throws -> Data {
            guard let document = PDFDocument(data: pdfData) else {
                throw CapabilityError.invalidInput("Invalid PDF data")
            }

            // Sort in descending order to remove from end to beginning
            let sortedIndices = pageNumbers.map { $0 - 1 }.sorted(by: >)

            for index in sortedIndices {
                guard index >= 0 && index < document.pageCount else { continue }
                document.removePage(at: index)
            }

            guard let data = document.dataRepresentation() else {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "NativePDFProvider", code: 3,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to generate PDF after page removal"
                        ]))
            }

            return data
        }
    }
#endif
