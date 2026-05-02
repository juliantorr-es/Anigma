//
//  OCREngineCoordinator.swift
//  AccessumModule
//
//  Swift-only OCR engine using Apple Vision framework.
//  No external CLI dependencies (Python, Node, Tesseract).
//
//  Designed for institutional deployment (CCSF DSPS) with governance integration.
//

import Foundation
import AnigmaCore

#if canImport(Vision)
import Vision
#endif

#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Engine Availability

/// Engine availability information.
public struct EngineAvailability: Sendable {
    public let visionAvailable: Bool
    public let visionVersion: String?
    public let ocrmypdfAvailable: Bool
    public let tesseractAvailable: Bool
    public let visionKitAvailable: Bool
    public let checkedAt: Date

    public var summary: String {
        if visionAvailable {
            return "Vision available"
        } else if ocrmypdfAvailable {
            return "OCRmyPDF available"
        } else if tesseractAvailable {
            return "Tesseract available"
        } else if visionKitAvailable {
            return "VisionKit available"
        } else {
            return "No engines available"
        }
    }

    public init(
        visionAvailable: Bool,
        visionVersion: String?,
        ocrmypdfAvailable: Bool = false,
        tesseractAvailable: Bool = false,
        visionKitAvailable: Bool = false,
        checkedAt: Date = Date()
    ) {
        self.visionAvailable = visionAvailable
        self.visionVersion = visionVersion
        self.ocrmypdfAvailable = ocrmypdfAvailable
        self.tesseractAvailable = tesseractAvailable
        self.visionKitAvailable = visionKitAvailable
        self.checkedAt = checkedAt
    }
}

// MARK: - OCR Processing Options

/// OCR processing options.
public struct OCRProcessingOptions: Sendable {
    public let language: String
    public let recognitionLevel: RecognitionLevel
    public let confidenceThreshold: Float
    public let timeoutSeconds: TimeInterval

    public enum RecognitionLevel: Sendable {
        case fast
        case accurate
    }

    public init(
        language: String = "en-US",
        recognitionLevel: RecognitionLevel = .accurate,
        confidenceThreshold: Float = 0.0,
        timeoutSeconds: TimeInterval = 300
    ) {
        self.language = language
        self.recognitionLevel = recognitionLevel
        self.confidenceThreshold = confidenceThreshold
        self.timeoutSeconds = timeoutSeconds
    }
}

// MARK: - Engine Results

/// Single engine attempt.
public struct OCREngineAttempt: Sendable {
    public let engine: OCREngine
    public let success: Bool
    public let processingTime: TimeInterval
    public let error: String?

    public init(engine: OCREngine, success: Bool, processingTime: TimeInterval, error: String? = nil) {
        self.engine = engine
        self.success = success
        self.processingTime = processingTime
        self.error = error
    }
}

/// Engine result.
public struct OCREngineResult: Sendable {
    public let text: String
    public let confidence: Double
    public let pageCount: Int
    public let engine: OCREngine

    public init(text: String, confidence: Double, pageCount: Int, engine: OCREngine) {
        self.text = text
        self.confidence = confidence
        self.pageCount = pageCount
        self.engine = engine
    }
}

/// Result of OCR coordination.
public struct OCRCoordinatorResult: Sendable {
    public let result: OCREngineResult
    public let updatedComponent: OCREngineComponent
    public let attempts: [OCREngineAttempt]
    public let usedFallback: Bool

    public init(result: OCREngineResult, updatedComponent: OCREngineComponent, attempts: [OCREngineAttempt], usedFallback: Bool) {
        self.result = result
        self.updatedComponent = updatedComponent
        self.attempts = attempts
        self.usedFallback = usedFallback
    }
}

// MARK: - Vision Engine

/// Vision engine using Apple Vision framework.
public actor VisionEngine: OCREngineProtocol {
    public let engine: OCREngine = .vision

    public init() {}

    public func isAvailable() async -> Bool {
        #if canImport(Vision)
        return true
        #else
        return false
        #endif
    }

    public func getVersion() async -> String? {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    public func process(url: URL, options: OCRProcessingOptions) async throws -> OCREngineResult {
        #if canImport(Vision)
        let startTime = Date()

        do {
            let (text, confidence, pageCount) = try await recognizeText(from: url, options: options)
            _ = Date().timeIntervalSince(startTime)

            return OCREngineResult(
                text: text,
                confidence: confidence,
                pageCount: pageCount,
                engine: .vision
            )
        } catch {
            throw OCREngineError.visionProcessingFailed(error: error)
        }
        #else
        throw OCREngineError.notAvailable
        #endif
    }

    #if canImport(Vision)
    private func recognizeText(from url: URL, options: OCRProcessingOptions) async throws -> (text: String, confidence: Double, pageCount: Int) {
        var textResult = ""
        var totalConfidence: Double = 0
        var pageCount = 0

        // Check file type
        let pathExtension = url.pathExtension.lowercased()
        let isPDF = pathExtension == "pdf"

        if isPDF {
            // Process PDF with Vision
            #if canImport(PDFKit)
            guard let document = PDFDocument(url: url) else {
                throw OCREngineError.invalidDocument
            }
            pageCount = document.pageCount

            for pageIndex in 0..<min(document.pageCount, 10) { // Limit pages for demo
                guard let page = document.page(at: pageIndex) else { continue }
                let pageImage = page.thumbnail(of: CGSize(width: 2000, height: 2000), for: .artBox)

                guard let cgImage = pageImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

                let pageText = try await recognizeText(from: cgImage, options: options)
                textResult += pageText.text + "\n\n"
                totalConfidence += pageText.confidence
            }
            #else
            throw OCREngineError.pdfNotSupported
            #endif
        } else {
            // Process image
            pageCount = 1
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw OCREngineError.imageLoadFailed
            }

            let pageText = try await recognizeText(from: cgImage, options: options)
            textResult = pageText.text
            totalConfidence = pageText.confidence
        }

        let avgConfidence = pageCount > 0 ? totalConfidence / Double(pageCount) : 0.0
        return (textResult, avgConfidence, pageCount)
    }

    private func recognizeText(from cgImage: CGImage, options: OCRProcessingOptions) async throws -> (text: String, confidence: Double) {
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest()

            // Set recognition level
            switch options.recognitionLevel {
            case .fast:
                request.recognitionLevel = .fast
            case .accurate:
                request.recognitionLevel = .accurate
            }

            // Set language
            request.recognitionLanguages = [options.language]

            // Use latest revision for best results
            request.revision = VNRecognizeTextRequestRevision3

            // Set minimum confidence
            request.minimumTextHeight = 0.01 // Allow small text

            do {
                try handler.perform([request])

                guard let observations = request.results else {
                    continuation.resume(returning: ("", 0.0))
                    return
                }

                var recognizedText = ""
                var confidenceSum: Double = 0
                var observationCount = 0

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }

                    // Filter by confidence threshold
                    if Float(candidate.confidence) < options.confidenceThreshold {
                        continue
                    }

                    recognizedText += candidate.string + "\n"
                    confidenceSum += Double(candidate.confidence)
                    observationCount += 1
                }

                let avgConfidence = observationCount > 0 ? confidenceSum / Double(observationCount) : 0.0
                continuation.resume(returning: (recognizedText.trimmingCharacters(in: .whitespacesAndNewlines), avgConfidence))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #endif
}

// MARK: - Engine Protocol

/// Protocol for OCR engines.
public protocol OCREngineProtocol: Sendable {
    var engine: OCREngine { get }
    func isAvailable() async -> Bool
    func getVersion() async -> String?
    func process(url: URL, options: OCRProcessingOptions) async throws -> OCREngineResult
}

// MARK: - Engine Coordinator

/// Coordinates OCR processing with Swift-only Vision engine.
public actor OCREngineCoordinator {
    private let visionEngine: VisionEngine
    private var cachedAvailability: EngineAvailability?
    private var lastAvailabilityCheck: Date?
    private let availabilityCacheDuration: TimeInterval = 300 // 5 minutes

    public init(visionEngine: VisionEngine = VisionEngine()) {
        self.visionEngine = visionEngine
    }

    /// Check availability of the Vision engine
    public func checkEngineAvailability() async -> EngineAvailability {
        // Return cached value if still valid
        if let cached = cachedAvailability,
           let lastCheck = lastAvailabilityCheck,
           Date().timeIntervalSince(lastCheck) < availabilityCacheDuration {
            return cached
        }

        let visionAvailable = await visionEngine.isAvailable()
        let visionVersion = await visionEngine.getVersion()

        let availability = EngineAvailability(
            visionAvailable: visionAvailable,
            visionVersion: visionVersion,
            ocrmypdfAvailable: false,
            tesseractAvailable: false,
            visionKitAvailable: visionAvailable,
            checkedAt: Date()
        )

        cachedAvailability = availability
        lastAvailabilityCheck = Date()
        return availability
    }

    /// Process a document using Vision engine
    public func process(
        url: URL,
        options: OCRProcessingOptions,
        engineComponent: OCREngineComponent
    ) async throws -> OCRCoordinatorResult {
        let startTime = Date()

        do {
            let result = try await visionEngine.process(url: url, options: options)
            let processingTime = Date().timeIntervalSince(startTime)

            let attempt = OCREngineAttempt(
                engine: .vision,
                success: true,
                processingTime: processingTime
            )

            // Update engine component
            var updatedComponent = engineComponent
            updatedComponent.engine = .vision
            updatedComponent.modelVersion = await visionEngine.getVersion()

            return OCRCoordinatorResult(
                result: result,
                updatedComponent: updatedComponent,
                attempts: [attempt],
                usedFallback: false
            )
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            _ = OCREngineAttempt(
                engine: .vision,
                success: false,
                processingTime: processingTime,
                error: error.localizedDescription
            )

            throw OCREngineError.visionProcessingFailed(error: error)
        }
    }

    /// Invalidate cached availability
    public func invalidateCache() {
        cachedAvailability = nil
        lastAvailabilityCheck = nil
    }
}

// MARK: - Engine Errors

public enum OCREngineError: Error, LocalizedError, Sendable {
    case notAvailable
    case visionProcessingFailed(error: Error)
    case invalidDocument
    case imageLoadFailed
    case pdfNotSupported
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Vision engine not available on this platform"
        case .visionProcessingFailed(let error):
            return "Vision processing failed: \(error.localizedDescription)"
        case .invalidDocument:
            return "Invalid or corrupted document"
        case .imageLoadFailed:
            return "Failed to load image"
        case .pdfNotSupported:
            return "PDF processing not supported on this platform"
        case .timeout:
            return "OCR processing timed out"
        }
    }
}
