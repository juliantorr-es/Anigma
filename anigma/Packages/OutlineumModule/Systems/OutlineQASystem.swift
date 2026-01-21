//
//  OutlineQASystem.swift
//  OutlineumModule
//
//  Ported from: Outlineum/backend/outlineum/ecs/systems/qa_system.py
//
//  Performs quality assessment on generated outlines.
//  Determines if outlines are suitable for kids/adult use.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

#if canImport(CoreImage)
    import CoreImage
#endif

#if canImport(AppKit)
    import AppKit
#endif

/// System that performs QA on generated outlines.
///
/// ## Pipeline Position
/// Runs after OutlineSystem. Adds OutlineQAComponent with scores.
///
/// ## QA Metrics
/// - **Clarity**: How clean/distinct are the lines?
/// - **Noise**: How much visual noise/artifacts?
/// - **Coverage**: What percentage of the page has content?
/// - **Complexity**: Line detail level (affects age-appropriateness)
public struct OutlineQASystem: System {
    public var name: String { "OutlineQA" }

    /// Thresholds for approval.
    public struct Thresholds: Sendable {
        public var minClarityForKids: Double = 0.6
        public var maxNoiseForKids: Double = 0.3
        public var minClarityForAdults: Double = 0.4
        public var maxNoiseForAdults: Double = 0.5
        public var minCoverage: Double = 0.1
        public var maxCoverage: Double = 0.9

        public init() {}
    }

    private let thresholds: Thresholds

    public init(thresholds: Thresholds = Thresholds()) {
        self.thresholds = thresholds
    }

    public func update(world: World) async {
        // Find entities with OutlineComponent but no OutlineQAComponent
        let entities = await world.query(OutlineComponent.self)

        for (entityId, outlineComponent) in entities {
            // Skip if already has QA
            if await world.hasComponent(entityId, OutlineQAComponent.self) { continue }

            // Skip if no outlines generated
            guard outlineComponent.hasAnyOutline else { continue }

            await performQA(entityId: entityId, outline: outlineComponent, world: world)
        }
    }

    private func performQA(entityId: EntityId, outline: OutlineComponent, world: World) async {
        logInfo("Performing QA for entity \(entityId)", category: "OutlineQASystem")

        var qa = OutlineQAComponent()
        qa.checkedAt = Date()
        qa.checkedBy = "OutlineQASystem/heuristic"

        #if canImport(AppKit)
            // Analyze kids outline
            if let kidsPath = outline.kidsOutlineRaster ?? outline.kidsOutlineVector {
                let metrics = analyzeImage(path: kidsPath)
                qa.outlineScores["kids_clarity"] = metrics.clarity
                qa.outlineScores["kids_noise"] = metrics.noise
                qa.outlineScores["kids_coverage"] = metrics.coverage
            }

            // Analyze adult outline
            if let adultPath = outline.adultOutlineRaster ?? outline.adultOutlineVector {
                let metrics = analyzeImage(path: adultPath)
                qa.outlineScores["adult_clarity"] = metrics.clarity
                qa.outlineScores["adult_noise"] = metrics.noise
                qa.outlineScores["adult_coverage"] = metrics.coverage
            }
        #endif

        // Apply thresholds for decisions
        let kidsClarity = qa.outlineScores["kids_clarity"] ?? 0
        let kidsNoise = qa.outlineScores["kids_noise"] ?? 1
        let adultClarity = qa.outlineScores["adult_clarity"] ?? 0
        let adultNoise = qa.outlineScores["adult_noise"] ?? 1

        qa.decisionFlags["approved_for_kids"] =
            kidsClarity >= thresholds.minClarityForKids && kidsNoise <= thresholds.maxNoiseForKids

        qa.decisionFlags["approved_for_adults"] =
            adultClarity >= thresholds.minClarityForAdults
            && adultNoise <= thresholds.maxNoiseForAdults

        // Need manual review if borderline
        let isKidsBorderline = kidsClarity > 0.4 && kidsClarity < 0.7
        let isAdultBorderline = adultClarity > 0.3 && adultClarity < 0.5
        qa.decisionFlags["needs_manual_review"] = isKidsBorderline || isAdultBorderline

        // Overall pass if at least one variant is approved
        qa.overallPass = qa.approvedForKids || qa.approvedForAdults

        if !qa.overallPass {
            qa.notes.append("No variants passed automatic approval")
        }

        await world.addComponent(entityId, qa)

        logInfo(
            "QA complete for \(entityId): pass=\(qa.overallPass), kids=\(qa.approvedForKids), adults=\(qa.approvedForAdults)",
            category: "OutlineQASystem")
    }

    #if canImport(AppKit)
        private struct ImageMetrics {
            var clarity: Double = 0.5
            var noise: Double = 0.5
            var coverage: Double = 0.5
        }

        private func analyzeImage(path: String) -> ImageMetrics {
            var metrics = ImageMetrics()

            guard let image = NSImage(contentsOfFile: path),
                let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else {
                return metrics
            }

            // Simple heuristic analysis based on pixel statistics
            let width = cgImage.width
            let height = cgImage.height

            guard let dataProvider = cgImage.dataProvider,
                let data = dataProvider.data,
                let bytes = CFDataGetBytePtr(data)
            else {
                return metrics
            }

            let bytesPerPixel = cgImage.bitsPerPixel / 8
            let bytesPerRow = cgImage.bytesPerRow

            var darkPixels = 0
            var edgeTransitions = 0
            var previousBrightness: UInt8 = 0

            // Sample every 10th pixel for performance
            let step = 10
            for y in stride(from: 0, to: height, by: step) {
                for x in stride(from: 0, to: width, by: step) {
                    let offset = y * bytesPerRow + x * bytesPerPixel

                    // Get grayscale value (assuming RGB/RGBA)
                    let r = bytes[offset]
                    let g = bytesPerPixel > 1 ? bytes[offset + 1] : r
                    let b = bytesPerPixel > 2 ? bytes[offset + 2] : r
                    let brightness = UInt8((Int(r) + Int(g) + Int(b)) / 3)

                    if brightness < 128 {
                        darkPixels += 1
                    }

                    // Count edge transitions (brightness changes)
                    if abs(Int(brightness) - Int(previousBrightness)) > 50 {
                        edgeTransitions += 1
                    }
                    previousBrightness = brightness
                }
            }

            let sampledPixels = (width / step) * (height / step)

            // Coverage: ratio of dark (ink) pixels
            metrics.coverage = Double(darkPixels) / Double(max(sampledPixels, 1))

            // Clarity: based on edge transitions (more = cleaner lines)
            let expectedTransitions = Double(sampledPixels) * 0.1
            metrics.clarity = min(1.0, Double(edgeTransitions) / expectedTransitions)

            // Noise: inverse of clarity for simple heuristic
            metrics.noise = 1.0 - metrics.clarity

            return metrics
        }
    #endif
}
