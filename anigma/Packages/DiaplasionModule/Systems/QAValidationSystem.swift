//
//  QAValidationSystem.swift
//  DiaplasionModule
//
//  Extracted from DiaplasionSystems.swift
//  System that validates transformation outputs for accessibility compliance.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - QA Validation System

/// System that validates transformation outputs for accessibility compliance.
///
/// This system:
/// 1. Queries entities with AccessibleOutputComponent where qaStatus == .pending
/// 2. Performs format-specific validation checks
/// 3. Validates structure and accessibility compliance
/// 4. Updates qaStatus and validationResults
///
/// **Input**: Entity with `AccessibleOutputComponent` (qaStatus == .pending)
/// **Output**: Updates qaStatus and adds validationResults
public struct DiaplasionQASystem: System {
    public var name: String { "DiaplasionQA" }

    /// Confidence threshold below which manual review is required.
    public let reviewThreshold: Double

    /// Whether to perform structural validation on EPUBs.
    public let validateEPUBStructure: Bool

    public init(
        reviewThreshold: Double = 0.8,
        validateEPUBStructure: Bool = true
    ) {
        self.reviewThreshold = reviewThreshold
        self.validateEPUBStructure = validateEPUBStructure
    }

    public func update(world: World) async {
        // Query for entities with AccessibleOutputComponent
        let outputs = await world.query(AccessibleOutputComponent.self)

        for (entity, var output) in outputs {
            // Skip if not pending QA
            guard output.qaStatus == .pending else { continue }

            // Get OCR result for confidence check
            let ocrResult = await world.getComponent(entity, OCRResultComponent.self)

            var validationResults: [ValidationResult] = []
            var overallPassed = true

            // Check OCR confidence
            if let confidence = ocrResult?.confidence {
                let confidenceCheck = ValidationResult(
                    check: "OCR Confidence",
                    passed: confidence >= reviewThreshold,
                    message: confidence >= reviewThreshold
                        ? "Confidence \(String(format: "%.1f%%", confidence * 100)) meets threshold"
                        : "Confidence \(String(format: "%.1f%%", confidence * 100)) below threshold \(String(format: "%.1f%%", reviewThreshold * 100))"
                )
                validationResults.append(confidenceCheck)

                if !confidenceCheck.passed {
                    overallPassed = false
                }
            }

            // Validate EPUB if present
            if let epubRef = output.outputs[.epub], validateEPUBStructure {
                let epubResults = validateEPUB(at: epubRef.uri)
                validationResults.append(contentsOf: epubResults)

                if epubResults.contains(where: { !$0.passed }) {
                    overallPassed = false
                }
            }

            // Check chunking quality
            if let chunked = await world.getComponent(entity, ChunkedTextComponent.self) {
                let chunkResults = validateChunking(chunked)
                validationResults.append(contentsOf: chunkResults)

                if chunkResults.contains(where: { !$0.passed }) {
                    overallPassed = false
                }
            }

            // Update QA status
            output.validationResults = validationResults
            output.qaStatus = overallPassed ? .passed : .needsReview

            await world.addComponent(entity, output)
            await Logger.shared.info(
                "QA completed: \(overallPassed ? "passed" : "needs review") with \(validationResults.count) checks",
                category: "Diaplasion"
            )
        }
    }

    // MARK: - Validation Helpers

    private func validateEPUB(at path: String) -> [ValidationResult] {
        var results: [ValidationResult] = []

        // Check file exists
        let fileExists = FileManager.default.fileExists(atPath: path)
        results.append(ValidationResult(
            check: "EPUB File Exists",
            passed: fileExists,
            message: fileExists ? nil : "EPUB file not found at \(path)"
        ))

        guard fileExists else { return results }

        // Check file is a valid ZIP (EPUB is a ZIP file)
        if let data = FileManager.default.contents(atPath: path), data.count >= 4 {
            let isZip = data[0] == 0x50 && data[1] == 0x4B // "PK" magic bytes
            results.append(ValidationResult(
                check: "EPUB ZIP Format",
                passed: isZip,
                message: isZip ? nil : "File is not a valid ZIP archive"
            ))
        }

        // Check file size is reasonable (not empty, not suspiciously small)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attributes[.size] as? Int64 {
            let minSize: Int64 = 500 // Minimum reasonable EPUB size
            let sizeOK = size >= minSize
            results.append(ValidationResult(
                check: "EPUB File Size",
                passed: sizeOK,
                message: sizeOK ? "File size: \(size) bytes" : "File too small (\(size) bytes)"
            ))
        }

        return results
    }

    private func validateChunking(_ chunked: ChunkedTextComponent) -> [ValidationResult] {
        var results: [ValidationResult] = []

        // Check that we have content
        let hasContent = !chunked.chunks.isEmpty
        results.append(ValidationResult(
            check: "Has Content",
            passed: hasContent,
            message: hasContent ? "\(chunked.chunks.count) chunks" : "No content chunks found"
        ))

        guard hasContent else { return results }

        // Check for heading structure
        let headingCount = chunked.chunks.filter { $0.chunkType == .heading }.count
        let hasHeadings = headingCount > 0
        results.append(ValidationResult(
            check: "Document Structure",
            passed: hasHeadings,
            message: hasHeadings ? "\(headingCount) headings detected" : "No headings detected - may lack structure"
        ))

        // Check for suspiciously short chunks that might indicate OCR errors
        let shortChunks = chunked.chunks.filter { $0.text.count < 10 && $0.chunkType != .heading }
        let fewShortChunks = shortChunks.count <= chunked.chunks.count / 4
        results.append(ValidationResult(
            check: "Chunk Quality",
            passed: fewShortChunks,
            message: fewShortChunks
                ? "Chunk lengths appear reasonable"
                : "\(shortChunks.count) suspiciously short chunks detected"
        ))

        // Check for very long chunks that might indicate missed paragraph breaks
        let longChunks = chunked.chunks.filter { $0.text.count > 5000 }
        let fewLongChunks = longChunks.isEmpty
        results.append(ValidationResult(
            check: "Paragraph Breaks",
            passed: fewLongChunks,
            message: fewLongChunks
                ? "No excessively long paragraphs"
                : "\(longChunks.count) very long paragraphs may need manual review"
        ))

        return results
    }
}
