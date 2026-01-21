//
//  IngestSystem.swift
//  OutlineumModule
//
//  Ported from: Outlineum/backend/outlineum/ecs/systems/ingest_system.py
//
//  Normalizes uploaded images: converts to PNG, strips metadata, auto-orients.
//  Uses CoreImage/CoreGraphics instead of shelling out to ImageMagick.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

#if canImport(CoreImage)
import CoreImage
import CoreGraphics
#endif

#if canImport(AppKit)
import AppKit
#endif

/// System that ingests and normalizes images for outline generation.
///
/// ## Pipeline Position
/// Runs first in the outline workflow. Prepares images for OutlineSystem.
///
/// ## Process
/// 1. Find entities with ImageComponent but no normalizedPath
/// 2. Load image, auto-orient, strip metadata
/// 3. Save as PNG to work directory
/// 4. Update ImageComponent with normalizedPath, dimensions
public struct IngestSystem: System {
    public var name: String { "Ingest" }

    /// Base directory for normalized images.
    private let workDirectory: URL

    public init(workDirectory: URL? = nil) {
        self.workDirectory = workDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("outlineum/normalized", isDirectory: true)
    }

    public func update(world: World) async {
        // Query entities with ImageComponent
        let entities = await world.query(ImageComponent.self)

        for (entityId, imageComponent) in entities {
            // Skip if already normalized
            guard imageComponent.normalizedPath == nil else { continue }

            await processImage(entityId: entityId, component: imageComponent, world: world)
        }
    }

    private func processImage(entityId: EntityId, component: ImageComponent, world: World) async {
        logInfo("Ingesting image for entity \(entityId): \(component.originalPath)", category: "IngestSystem")

        let originalURL = URL(fileURLWithPath: component.originalPath)

        #if canImport(AppKit)
        // macOS implementation using NSImage → CGImage → PNG
        guard let image = NSImage(contentsOf: originalURL) else {
            logError("Failed to load image: \(component.originalPath)", category: "IngestSystem")
            return
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            logError("Failed to get CGImage from: \(component.originalPath)", category: "IngestSystem")
            return
        }

        // Create work directory
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        // Generate normalized filename
        let normalizedFilename = "\(entityId.raw.uuidString)_norm.png"
        let normalizedURL = workDirectory.appendingPathComponent(normalizedFilename)

        // Create PNG representation
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            logError("Failed to create PNG data", category: "IngestSystem")
            return
        }

        do {
            try pngData.write(to: normalizedURL)
        } catch {
            logError("Failed to write normalized image: \(error)", category: "IngestSystem")
            return
        }

        // Update component
        var updated = component
        updated.normalizedPath = normalizedURL.path
        updated.width = cgImage.width
        updated.height = cgImage.height

        await world.addComponent(entityId, updated)

        logInfo("Normalized image saved to \(normalizedURL.path) (\(cgImage.width)x\(cgImage.height))",
                category: "IngestSystem")

        #else
        // Non-macOS: log that we can't process
        logWarning("IngestSystem requires macOS (AppKit) for image processing", category: "IngestSystem")
        #endif
    }
}
