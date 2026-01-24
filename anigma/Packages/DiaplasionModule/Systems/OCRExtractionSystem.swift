//
//  OCRExtractionSystem.swift
//  DiaplasionModule
//
//  Extracted from DiaplasionSystems.swift
//  System that performs OCR on document images using Apple Vision framework.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

// MARK: - OCR Extraction System

/// System that performs OCR on document images using Apple Vision framework.
///
/// This system:
/// 1. Reads cached page images from IngestedDocumentComponent
/// 2. Runs VNRecognizeTextRequest on each page
/// 3. Collects text with confidence scores and bounding boxes
/// 4. Produces OCRResultComponent with aggregated results
///
/// **Input**: Entity with `IngestedDocumentComponent` (completed)
/// **Output**: Adds `OCRResultComponent`
public struct OCRExtractionSystem: System {
    public var name: String { "OCRExtraction" }

    /// Recognition level: .fast for speed, .accurate for quality.
    public let recognitionLevel: RecognitionLevel

    /// Minimum confidence threshold (0.0-1.0). Text below this is excluded.
    public let confidenceThreshold: Float

    /// Languages to recognize (e.g., ["en-US"]). Empty = automatic.
    public let languages: [String]

    /// Whether to attempt language detection on extracted text.
    public let detectLanguage: Bool

    public enum RecognitionLevel: Sendable {
        case fast
        case accurate
    }

    public init(
        recognitionLevel: RecognitionLevel = .accurate,
        confidenceThreshold: Float = 0.0,
        languages: [String] = [],
        detectLanguage: Bool = true
    ) {
        self.recognitionLevel = recognitionLevel
        self.confidenceThreshold = confidenceThreshold
        self.languages = languages
        self.detectLanguage = detectLanguage
    }

    public func update(world: World) async {
        // Query for entities with IngestedDocumentComponent but no OCRResultComponent
        let documents = await world.query(IngestedDocumentComponent.self)

        for (entity, ingested) in documents {
            // Skip if already OCR'd
            if await world.hasComponent(entity, OCRResultComponent.self) {
                continue
            }

            // Skip if ingestion failed
            guard ingested.isComplete else {
                await Logger.shared.warning("Skipping OCR for incomplete document", category: "Diaplasion")
                await appendProcessingError(
                    config: AppendProcessingErrorConfiguration(
                        world: world,
                        entity: entity,
                        stage: .ocr,
                        code: "ocr.ingest_incomplete",
                        message: "Ingested document is incomplete",
                        retryPolicy: .noRetry
                    )
                )
                continue
            }

            if let textContent = ingested.textContent {
                let startTime = Date()
                let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.isEmpty {
                    await Logger.shared.warning("Skipping OCR for empty extracted text", category: "Diaplasion")
                    await appendProcessingError(
                        config: AppendProcessingErrorConfiguration(
                            world: world,
                            entity: entity,
                            stage: .textExtraction,
                            code: "text.empty",
                            message: "Extracted text is empty",
                            retryPolicy: .noRetry
                        )
                    )
                    let errorResult = OCRResultComponent(
                        text: "",
                        confidence: 0.0,
                        pageResults: [],
                        engine: "TextExtract",
                        processingTime: Date().timeIntervalSince(startTime)
                    )
                    await world.addComponent(entity, errorResult)
                    continue
                }

                var result = OCRResultComponent(
                    text: trimmed,
                    confidence: 1.0,
                    language: nil,
                    pageResults: [
                        PageOCRResult(
                            pageNumber: 1,
                            text: trimmed,
                            confidence: 1.0,
                            boundingBoxes: nil
                        )
                    ],
                    engine: "TextExtract",
                    processingTime: Date().timeIntervalSince(startTime)
                )

                if let language = detectLanguageCode(for: trimmed) {
                    result.language = language
                } else if detectLanguage {
                    await appendProcessingError(
                        config: AppendProcessingErrorConfiguration(
                            world: world,
                            entity: entity,
                            stage: .languageDetection,
                            code: "language.detect.failed",
                            message: "Could not determine dominant language",
                            retryPolicy: .noRetry,
                            context: ["textLength": "\(trimmed.count)"]
                        )
                    )
                }

                await world.addComponent(entity, result)
                await Logger.shared.info(
                    "Text extraction completed: \(trimmed.count) characters",
                    category: "Diaplasion"
                )
                continue
            }

            guard !ingested.pageImagePaths.isEmpty else {
                await Logger.shared.warning("Skipping OCR for missing page images", category: "Diaplasion")
                await appendProcessingError(
                    config: AppendProcessingErrorConfiguration(
                        world: world,
                        entity: entity,
                        stage: .ocr,
                        code: "ocr.no_pages",
                        message: "No page images available for OCR",
                        retryPolicy: .noRetry
                    )
                )
                continue
            }

            let startTime = Date()

            do {
                var result = try await performOCR(on: ingested)
                let processingTime = Date().timeIntervalSince(startTime)

                result.processingTime = processingTime
                result.engine = "Apple Vision"

                if let language = detectLanguageCode(for: result.text) {
                    result.language = language
                } else if detectLanguage {
                    await appendProcessingError(
                        config: AppendProcessingErrorConfiguration(
                            world: world,
                            entity: entity,
                            stage: .languageDetection,
                            code: "language.detect.failed",
                            message: "Could not determine dominant language",
                            retryPolicy: .noRetry,
                            context: ["textLength": "\(result.text.count)"]
                        )
                    )
                }

                await world.addComponent(entity, result)
                await Logger.shared.info(
                    "OCR completed: \(ingested.pageImagePaths.count) pages in \(String(format: "%.2f", processingTime))s",
                    category: "Diaplasion"
                )
            } catch {
                await Logger.shared.error("OCR failed: \(error)", category: "Diaplasion")
                await appendProcessingError(
                    config: AppendProcessingErrorConfiguration(
                        world: world,
                        entity: entity,
                        stage: .ocr,
                        code: "ocr.failed",
                        message: error.localizedDescription,
                        retryPolicy: .default,
                        context: ["pageCount": "\(ingested.pageImagePaths.count)"]
                    )
                )
                let errorResult = OCRResultComponent(
                    text: "",
                    confidence: 0.0,
                    pageResults: [],
                    engine: "Apple Vision",
                    processingTime: Date().timeIntervalSince(startTime)
                )
                await world.addComponent(entity, errorResult)
            }
        }
    }

    // MARK: - Private Implementation

    private func detectLanguageCode(for text: String) -> String? {
        guard detectLanguage else { return nil }
        #if canImport(NaturalLanguage)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else {
            return nil
        }
        return language.rawValue
        #else
        return nil
        #endif
    }

    #if canImport(Vision) && canImport(CoreGraphics)
    private func performOCR(on ingested: IngestedDocumentComponent) async throws -> OCRResultComponent {
        var pageResults: [PageOCRResult] = []
        var allText = ""
        var totalConfidence: Double = 0.0
        var wordCount = 0

        for (index, imagePath) in ingested.pageImagePaths.enumerated() {
            let pageNumber = index + 1
            let pageResult = try await ocrPage(at: imagePath, pageNumber: pageNumber)
            pageResults.append(pageResult)

            if !allText.isEmpty && !pageResult.text.isEmpty {
                allText += "\n\n"
            }
            allText += pageResult.text

            if let conf = pageResult.confidence {
                totalConfidence += conf
                wordCount += 1
            }
        }

        let avgConfidence = wordCount > 0 ? totalConfidence / Double(wordCount) : nil

        return OCRResultComponent(
            text: allText,
            confidence: avgConfidence,
            language: nil,
            pageResults: pageResults
        )
    }

    private func ocrPage(at imagePath: String, pageNumber: Int) async throws -> PageOCRResult {
        let url = URL(fileURLWithPath: imagePath)

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DiaplasionError.imageLoadFailed(path: imagePath)
        }

        // Create Vision request handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Configure text recognition request
        let request = VNRecognizeTextRequest()

        // Set recognition level
        switch recognitionLevel {
        case .fast:
            request.recognitionLevel = .fast
        case .accurate:
            request.recognitionLevel = .accurate
        }

        // Set languages if specified
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        }

        // Use revision 3 for best results on macOS 13+ / iOS 16+
        request.revision = VNRecognizeTextRequestRevision3

        // Run synchronously (Vision doesn't have async API)
        try handler.perform([request])

        guard let observations = request.results else {
            return PageOCRResult(pageNumber: pageNumber, text: "", confidence: nil, boundingBoxes: nil)
        }

        // Collect text and bounding boxes
        var textLines: [String] = []
        var boundingBoxes: [TextBoundingBox] = []
        var confidenceSum: Float = 0.0
        var confidenceCount = 0

        let imageWidth = Double(cgImage.width)
        let imageHeight = Double(cgImage.height)

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            // Filter by confidence threshold
            if candidate.confidence < confidenceThreshold {
                continue
            }

            textLines.append(candidate.string)
            confidenceSum += candidate.confidence
            confidenceCount += 1

            // Convert normalized bounding box to pixel coordinates
            // Vision uses bottom-left origin, we convert to top-left
            let box = observation.boundingBox
            let bbox = TextBoundingBox(
                x: box.origin.x * imageWidth,
                y: (1.0 - box.origin.y - box.height) * imageHeight,
                width: box.width * imageWidth,
                height: box.height * imageHeight,
                text: candidate.string,
                confidence: Double(candidate.confidence)
            )
            boundingBoxes.append(bbox)
        }

        let pageText = textLines.joined(separator: "\n")
        let avgConfidence = confidenceCount > 0 ? Double(confidenceSum / Float(confidenceCount)) : nil

        return PageOCRResult(
            pageNumber: pageNumber,
            text: pageText,
            confidence: avgConfidence,
            boundingBoxes: boundingBoxes
        )
    }
    #else
    private func performOCR(on ingested: IngestedDocumentComponent) async throws -> OCRResultComponent {
        throw DiaplasionError.ocrFailed(reason: "Vision framework not available")
    }
    #endif
}
