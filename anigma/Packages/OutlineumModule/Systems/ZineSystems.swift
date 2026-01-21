//
//  ZineSystems.swift
//  OutlineumModule
//
//  Systems for zine layout and export.
//  Combines multiple outline images into printable zine format.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Zine Layout Configuration

/// Configuration for zine layout generation.
public struct ZineLayoutConfig: Sendable {
    /// Page dimensions in points (72 points = 1 inch).
    public var pageWidth: CGFloat = 612   // 8.5 inches (letter)
    public var pageHeight: CGFloat = 792  // 11 inches

    /// Margins in points.
    public var marginTop: CGFloat = 36
    public var marginBottom: CGFloat = 36
    public var marginLeft: CGFloat = 36
    public var marginRight: CGFloat = 36

    /// Caption font size.
    public var captionFontSize: CGFloat = 12

    /// Space between image and caption.
    public var captionSpacing: CGFloat = 8

    public init() {}
}

// MARK: - Zine Layout System

/// System that arranges outline images into zine pages.
///
/// ## Pipeline Position
/// Runs after OutlineSystem. Creates ZinePageComponent entries for each page.
///
/// ## Process
/// 1. Find ZineComponent entities without layout
/// 2. For each page entity, determine layout based on image count
/// 3. Create or update ZinePageComponent with image positions
public struct ZineLayoutSystem: System {
    public var name: String { "ZineLayout" }

    private let config: ZineLayoutConfig

    public init(config: ZineLayoutConfig = ZineLayoutConfig()) {
        self.config = config
    }

    public func update(world: World) async {
        let zines = await world.query(ZineComponent.self)

        for (entityId, var zineComponent) in zines {
            // Skip if already processed
            if zineComponent.status != .draft { continue }

            zineComponent.status = .generating
            await world.addComponent(entityId, zineComponent)

            await layoutZine(entityId: entityId, zine: zineComponent, world: world)
        }
    }

    private func layoutZine(entityId: EntityId, zine: ZineComponent, world: World) async {
        logInfo("Laying out zine '\(zine.title)' with \(zine.pageCount) pages", category: "ZineLayout")

        var pageIndex = 0

        for pageEntityId in zine.pageEntityIds {
            // Check if this entity has outline content
            if let outline = await world.getComponent(pageEntityId, OutlineComponent.self) {
                // Create page layout based on available content
                let layoutType: PageLayoutType = determineLayout(for: outline)

                let pageComponent = ZinePageComponent(
                    pageIndex: pageIndex,
                    layoutType: layoutType,
                    imageEntityIds: [pageEntityId],
                    textContent: ""  // Could extract from metadata
                )

                await world.addComponent(pageEntityId, pageComponent)
                pageIndex += 1
            }
        }

        // Update zine status
        var updatedZine = zine
        updatedZine.status = .review
        updatedZine.modifiedAt = Date()
        await world.addComponent(entityId, updatedZine)

        logInfo("Zine '\(zine.title)' layout complete with \(pageIndex) pages", category: "ZineLayout")
    }

    private func determineLayout(for outline: OutlineComponent) -> PageLayoutType {
        // Simple heuristic: if we have both variants, use two-up; otherwise full bleed
        if outline.kidsOutlineRaster != nil && outline.adultOutlineRaster != nil {
            return .twoUp
        }
        return .fullBleed
    }
}

// MARK: - Zine Export System

/// System that exports zines to PDF format.
///
/// ## Pipeline Position
/// Runs after ZineLayoutSystem. Produces linear and booklet PDFs.
///
/// ## Process
/// 1. Find ZineComponent entities in review status
/// 2. Gather all page images in order
/// 3. Generate linear PDF (pages in reading order)
/// 4. Generate booklet PDF (pages arranged for folding)
public struct ZineExportSystem: System {
    public var name: String { "ZineExport" }

    private let workDirectory: URL
    private let config: ZineLayoutConfig
    private let generateBooklet: Bool

    public init(
        workDirectory: URL? = nil,
        config: ZineLayoutConfig = ZineLayoutConfig(),
        generateBooklet: Bool = true
    ) {
        self.workDirectory = workDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("outlineum/zines", isDirectory: true)
        self.config = config
        self.generateBooklet = generateBooklet
    }

    public func update(world: World) async {
        let zines = await world.query(ZineComponent.self)

        for (entityId, var zineComponent) in zines {
            // Only process zines ready for export
            guard zineComponent.status == .review else { continue }
            guard zineComponent.linearPdfPath == nil else { continue }

            await exportZine(entityId: entityId, zine: &zineComponent, world: world)
            await world.addComponent(entityId, zineComponent)
        }
    }

    private func exportZine(entityId: EntityId, zine: inout ZineComponent, world: World) async {
        logInfo("Exporting zine '\(zine.title)'", category: "ZineExport")

        // Create work directory
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        // Gather page images
        var pageImages: [(CGImage, PageLayoutType)] = []

        for pageEntityId in zine.pageEntityIds {
            if let outline = await world.getComponent(pageEntityId, OutlineComponent.self),
               let page = await world.getComponent(pageEntityId, ZinePageComponent.self) {
                // Prefer kids outline for zines (simpler lines)
                if let imagePath = outline.kidsOutlineRaster ?? outline.adultOutlineRaster,
                   let image = loadImage(from: imagePath) {
                    pageImages.append((image, page.layoutType))
                }
            }
        }

        guard !pageImages.isEmpty else {
            logWarning("No images found for zine '\(zine.title)'", category: "ZineExport")
            zine.status = .failed
            return
        }

        // Generate linear PDF
        let sanitizedTitle = zine.title.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let linearPdfUrl = workDirectory.appendingPathComponent("\(sanitizedTitle)_linear.pdf")

        if generateLinearPdf(pages: pageImages, to: linearPdfUrl) {
            zine.linearPdfPath = linearPdfUrl.path
            logInfo("Generated linear PDF: \(linearPdfUrl.path)", category: "ZineExport")
        }

        // Generate booklet PDF if requested and we have enough pages
        if generateBooklet && pageImages.count >= 4 {
            let bookletPdfUrl = workDirectory.appendingPathComponent("\(sanitizedTitle)_booklet.pdf")
            if generateBookletPdf(pages: pageImages, to: bookletPdfUrl) {
                zine.bookletPdfPath = bookletPdfUrl.path
                logInfo("Generated booklet PDF: \(bookletPdfUrl.path)", category: "ZineExport")
            }
        }

        zine.status = .published
        zine.modifiedAt = Date()
    }

    private func loadImage(from path: String) -> CGImage? {
        #if canImport(AppKit)
        guard let image = NSImage(contentsOfFile: path),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
        #else
        return nil
        #endif
    }

    private func generateLinearPdf(pages: [(CGImage, PageLayoutType)], to url: URL) -> Bool {
        #if canImport(CoreGraphics)
        var mediaBox = CGRect(x: 0, y: 0, width: config.pageWidth, height: config.pageHeight)

        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            logError("Failed to create PDF context", category: "ZineExport")
            return false
        }

        for (image, layoutType) in pages {
            context.beginPDFPage(nil)

            // Calculate image rect based on layout
            let imageRect = calculateImageRect(for: image, layoutType: layoutType)

            // Draw image
            context.draw(image, in: imageRect)

            context.endPDFPage()
        }

        context.closePDF()
        return true
        #else
        return false
        #endif
    }

    private func generateBookletPdf(pages: [(CGImage, PageLayoutType)], to url: URL) -> Bool {
        #if canImport(CoreGraphics)
        // Pad to multiple of 4 pages
        var paddedPages = pages
        while paddedPages.count % 4 != 0 {
            // Add blank placeholder
            paddedPages.append((createBlankImage(), .fullBleed))
        }

        // Calculate booklet page order (imposition)
        let bookletOrder = calculateBookletOrder(pageCount: paddedPages.count)

        // Create landscape pages for booklet (two pages per sheet)
        let sheetWidth = config.pageHeight * 2  // Two pages wide
        let sheetHeight = config.pageWidth
        var mediaBox = CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight)

        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            logError("Failed to create booklet PDF context", category: "ZineExport")
            return false
        }

        // Each sheet has two page positions
        for sheetIndex in stride(from: 0, to: bookletOrder.count, by: 2) {
            context.beginPDFPage(nil)

            // Left page
            let leftPageIndex = bookletOrder[sheetIndex]
            if leftPageIndex >= 0 && leftPageIndex < paddedPages.count {
                let (image, _) = paddedPages[leftPageIndex]
                let leftRect = CGRect(x: 0, y: 0, width: config.pageHeight, height: config.pageWidth)
                drawImageFittingRect(context: context, image: image, rect: leftRect)
            }

            // Right page
            if sheetIndex + 1 < bookletOrder.count {
                let rightPageIndex = bookletOrder[sheetIndex + 1]
                if rightPageIndex >= 0 && rightPageIndex < paddedPages.count {
                    let (image, _) = paddedPages[rightPageIndex]
                    let rightRect = CGRect(x: config.pageHeight, y: 0, width: config.pageHeight, height: config.pageWidth)
                    drawImageFittingRect(context: context, image: image, rect: rightRect)
                }
            }

            context.endPDFPage()
        }

        context.closePDF()
        return true
        #else
        return false
        #endif
    }

    #if canImport(CoreGraphics)
    private func calculateImageRect(for image: CGImage, layoutType: PageLayoutType) -> CGRect {
        let contentWidth = config.pageWidth - config.marginLeft - config.marginRight
        let contentHeight = config.pageHeight - config.marginTop - config.marginBottom

        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let contentAspect = contentWidth / contentHeight

        var imageWidth: CGFloat
        var imageHeight: CGFloat

        if imageAspect > contentAspect {
            // Image is wider than content area
            imageWidth = contentWidth
            imageHeight = contentWidth / imageAspect
        } else {
            // Image is taller than content area
            imageHeight = contentHeight
            imageWidth = contentHeight * imageAspect
        }

        // Center in content area
        let x = config.marginLeft + (contentWidth - imageWidth) / 2
        let y = config.marginBottom + (contentHeight - imageHeight) / 2

        return CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
    }

    private func drawImageFittingRect(context: CGContext, image: CGImage, rect: CGRect) {
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let rectAspect = rect.width / rect.height

        var drawRect: CGRect

        if imageAspect > rectAspect {
            let height = rect.width / imageAspect
            drawRect = CGRect(x: rect.minX, y: rect.minY + (rect.height - height) / 2,
                            width: rect.width, height: height)
        } else {
            let width = rect.height * imageAspect
            drawRect = CGRect(x: rect.minX + (rect.width - width) / 2, y: rect.minY,
                            width: width, height: rect.height)
        }

        context.draw(image, in: drawRect)
    }

    private func createBlankImage() -> CGImage {
        // Create a simple 1x1 white pixel image for blank pages
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel: [UInt8] = [255, 255, 255, 255]  // White
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
                               bytesPerRow: 4, space: colorSpace,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }
    #endif

    private func calculateBookletOrder(pageCount: Int) -> [Int] {
        // Standard booklet imposition for saddle-stitch binding
        // Each sheet has 4 page positions (front-left, front-right, back-left, back-right)
        var order: [Int] = []
        let sheetCount = pageCount / 4

        for sheet in 0..<sheetCount {
            // Front of sheet (when folded, becomes outer pages)
            // Back-right position = last unplaced page
            // Front-left position = first unplaced page
            let frontLeft = sheet * 2
            let frontRight = pageCount - 1 - (sheet * 2)

            // Back of sheet (becomes inner pages)
            let backLeft = pageCount - 2 - (sheet * 2)
            let backRight = 1 + (sheet * 2)

            // Add in print order (front side, then back side flipped)
            order.append(frontRight)
            order.append(frontLeft)
            order.append(backLeft)
            order.append(backRight)
        }

        return order
    }
}
