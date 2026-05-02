//
//  OutlineSystem.swift
//  OutlineumModule
//
//  Ported from: Outlineum/backend/outlineum/ecs/systems/outline_system.py
//
//  Generates outline variants (kids/adult) from normalized images.
//  Uses CoreImage for edge detection instead of ImageMagick.
//
//  Note: Potrace vectorization requires the potrace binary.
//  For a pure-Swift solution, we'd need to implement tracing ourselves.
//  For now, we generate raster outlines and optionally call potrace.
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

/// Configuration for outline generation.
public struct OutlineConfig: Sendable {
    // Kids outline: thick, simplified
    public var kidsBlurRadius: Double = 3.0
    public var kidsEdgeIntensity: Double = 1.0
    public var kidsThreshold: Double = 0.5

    // Adult outline: detailed
    public var adultBlurRadius: Double = 1.0
    public var adultEdgeIntensity: Double = 2.0
    public var adultThreshold: Double = 0.3

    public init() {}
}

/// System that generates outline variants from normalized images.
///
/// ## Pipeline Position
/// Runs after IngestSystem. Produces OutlineComponent with paths to outputs.
///
/// ## Process
/// 1. Find entities with ImageComponent.normalizedPath but no OutlineComponent
/// 2. Apply edge detection filters (CoreImage)
/// 3. Save raster outlines (BMP for potrace compatibility)
/// 4. Optionally run potrace for SVG vectorization
/// 5. Create OutlineComponent with output paths
public struct OutlineSystem: System {
    public var name: String { "Outline" }

    private let workDirectory: URL
    private let config: OutlineConfig
    private let enableVectorization: Bool

    public init(
        workDirectory: URL? = nil,
        config: OutlineConfig = OutlineConfig(),
        enableVectorization: Bool = true
    ) {
        self.workDirectory = workDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("outlineum/outlines", isDirectory: true)
        self.config = config
        self.enableVectorization = enableVectorization
    }

    public func update(world: World) async {
        // Query entities with normalized images
        let entities = await world.query(ImageComponent.self)

        for (entityId, imageComponent) in entities {
            // Skip if no normalized path
            guard let normalizedPath = imageComponent.normalizedPath else { continue }

            // Skip if already has outline
            if await world.hasComponent(entityId, OutlineComponent.self) { continue }

            await generateOutlines(
                entityId: entityId,
                normalizedPath: normalizedPath,
                world: world
            )
        }
    }

    private func generateOutlines(entityId: EntityId, normalizedPath: String, world: World) async {
        logInfo("Generating outlines for entity \(entityId)", category: "OutlineSystem")

        let startTime = Date()
        var outlineComponent = OutlineComponent()

        // Create work directory
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        #if canImport(CoreImage) && canImport(AppKit)
        let inputURL = URL(fileURLWithPath: normalizedPath)

        // Generate kids outline (simplified, thick lines)
        if let kidsRaster = generateKidsOutline(entityId: entityId, inputURL: inputURL) {
            outlineComponent.kidsOutlineRaster = kidsRaster.path

            if enableVectorization {
                if let kidsVector = vectorize(rasterPath: kidsRaster, entityId: entityId, variant: "kids") {
                    outlineComponent.kidsOutlineVector = kidsVector.path
                }
            }
        }

        // Generate adult outline (detailed)
        if let adultRaster = generateAdultOutline(entityId: entityId, inputURL: inputURL) {
            outlineComponent.adultOutlineRaster = adultRaster.path

            if enableVectorization {
                if let adultVector = vectorize(rasterPath: adultRaster, entityId: entityId, variant: "adult") {
                    outlineComponent.adultOutlineVector = adultVector.path
                }
            }
        }

        #else
        outlineComponent.errors.append("OutlineSystem requires macOS (CoreImage) for processing")
        #endif

        outlineComponent.generatedAt = Date()
        outlineComponent.processingDurationMs = Int64(Date().timeIntervalSince(startTime) * 1000)

        await world.addComponent(entityId, outlineComponent)

        logInfo("Outlines generated for \(entityId) in \(outlineComponent.processingDurationMs ?? 0)ms",
                category: "OutlineSystem")
    }

    #if canImport(CoreImage) && canImport(AppKit)
    private func generateKidsOutline(entityId: EntityId, inputURL: URL) -> URL? {
        guard let ciImage = CIImage(contentsOf: inputURL) else {
            logError("Failed to load image for kids outline", category: "OutlineSystem")
            return nil
        }

        // Apply filters: grayscale → blur → edge detection → threshold
        let context = CIContext()

        var processed = ciImage

        // Convert to grayscale
        if let grayscale = CIFilter(name: "CIColorMonochrome") {
            grayscale.setValue(processed, forKey: kCIInputImageKey)
            grayscale.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")
            grayscale.setValue(1.0, forKey: "inputIntensity")
            if let output = grayscale.outputImage {
                processed = output
            }
        }

        // Apply Gaussian blur (simplifies details)
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(processed, forKey: kCIInputImageKey)
            blur.setValue(config.kidsBlurRadius, forKey: kCIInputRadiusKey)
            if let output = blur.outputImage {
                processed = output
            }
        }

        // Edge detection
        if let edges = CIFilter(name: "CIEdges") {
            edges.setValue(processed, forKey: kCIInputImageKey)
            edges.setValue(config.kidsEdgeIntensity, forKey: kCIInputIntensityKey)
            if let output = edges.outputImage {
                processed = output
            }
        }

        // Invert (black lines on white background)
        if let invert = CIFilter(name: "CIColorInvert") {
            invert.setValue(processed, forKey: kCIInputImageKey)
            if let output = invert.outputImage {
                processed = output
            }
        }

        // Render to BMP
        let outputURL = workDirectory.appendingPathComponent("\(entityId.raw.uuidString)_kids.png")

        guard let cgImage = context.createCGImage(processed, from: ciImage.extent) else {
            logError("Failed to render kids outline", category: "OutlineSystem")
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: outputURL)
            return outputURL
        } catch {
            logError("Failed to write kids outline: \(error)", category: "OutlineSystem")
            return nil
        }
    }

    private func generateAdultOutline(entityId: EntityId, inputURL: URL) -> URL? {
        guard let ciImage = CIImage(contentsOf: inputURL) else {
            logError("Failed to load image for adult outline", category: "OutlineSystem")
            return nil
        }

        let context = CIContext()
        var processed = ciImage

        // Convert to grayscale
        if let grayscale = CIFilter(name: "CIColorMonochrome") {
            grayscale.setValue(processed, forKey: kCIInputImageKey)
            grayscale.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")
            grayscale.setValue(1.0, forKey: "inputIntensity")
            if let output = grayscale.outputImage {
                processed = output
            }
        }

        // Light blur (preserves more detail than kids)
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(processed, forKey: kCIInputImageKey)
            blur.setValue(config.adultBlurRadius, forKey: kCIInputRadiusKey)
            if let output = blur.outputImage {
                processed = output
            }
        }

        // Edge detection with higher intensity
        if let edges = CIFilter(name: "CIEdges") {
            edges.setValue(processed, forKey: kCIInputImageKey)
            edges.setValue(config.adultEdgeIntensity, forKey: kCIInputIntensityKey)
            if let output = edges.outputImage {
                processed = output
            }
        }

        // Invert
        if let invert = CIFilter(name: "CIColorInvert") {
            invert.setValue(processed, forKey: kCIInputImageKey)
            if let output = invert.outputImage {
                processed = output
            }
        }

        let outputURL = workDirectory.appendingPathComponent("\(entityId.raw.uuidString)_adult.png")

        guard let cgImage = context.createCGImage(processed, from: ciImage.extent) else {
            logError("Failed to render adult outline", category: "OutlineSystem")
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: outputURL)
            return outputURL
        } catch {
            logError("Failed to write adult outline: \(error)", category: "OutlineSystem")
            return nil
        }
    }
    #endif

    private func vectorize(rasterPath: URL, entityId: EntityId, variant: String) -> URL? {
        // Check if potrace is available
        let potraceURL = URL(fileURLWithPath: "/opt/homebrew/bin/potrace")
        guard FileManager.default.fileExists(atPath: potraceURL.path) else {
            // Try /usr/local/bin
            let altPath = "/usr/local/bin/potrace"
            guard FileManager.default.fileExists(atPath: altPath) else {
                logWarning("potrace not found, skipping vectorization", category: "OutlineSystem")
                return nil
            }
            return runPotrace(executablePath: altPath, rasterPath: rasterPath, entityId: entityId, variant: variant)
        }
        return runPotrace(executablePath: potraceURL.path, rasterPath: rasterPath, entityId: entityId, variant: variant)
    }

    private func runPotrace(executablePath: String, rasterPath: URL, entityId: EntityId, variant: String) -> URL? {
        let outputURL = workDirectory.appendingPathComponent("\(entityId.raw.uuidString)_\(variant).svg")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [
            rasterPath.path,
            "-s",  // SVG output
            "-o", outputURL.path,
            "--turdsize", "2"
        ]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputURL.path) {
                return outputURL
            }
        } catch {
            logError("potrace failed: \(error)", category: "OutlineSystem")
        }

        return nil
    }
}
