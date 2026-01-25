//
//  DiaplasionPipeline.swift
//  DiaplasionPipeline
//
//  [Brief description of file purpose]
//

import ArgumentParser
import AnigmaCore
import CryptoKit
import DiaplasionModule
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif
#if canImport(CoreText)
import CoreText
#endif
#if canImport(Vision)
import Vision
#endif

@main
struct DiaplasionPipeline: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diaplasion-pipeline",
        abstract: "Runs the Diaplasion happy-path spine and emits deterministic artifacts."
    )

    @Option(
        name: .shortAndLong,
        help: "Path to the pipeline spec (default: bundled Diaplasion happy-path fixture)."
    )
    var spec: String?

    @Option(
        name: [.short, .customLong("output-base")],
        help: "Base directory for artifacts (default: Artifacts/diaplasion)."
    )
    var outputBase: String = "Artifacts/diaplasion"

    @Flag(name: [.customLong("replay")], inversion: .prefixedNo, help: "Re-run the pipeline trace without rewriting artifacts.")
    var replay: Bool = false

    func run() async throws {
        let repoRoot = try Self.repositoryRoot()
        let specSource = try Self.resolveSpecSource(specOption: spec, repoRoot: repoRoot)
        let specURL = specSource.url
        let specData = try Data(contentsOf: specURL)
        let specModel = try DiaplasionSpec.decode(from: specData)
        let pipelineVersion = DiaplasionModuleVersion.string
        let inputContext = try Self.hashInputs(specData: specData, inputURLs: specModel.inputURLs(relativeTo: specURL))
        let inputHash = inputContext.hash
        let artifactDir = try Self.artifactDirectory(
            base: URL(fileURLWithPath: outputBase, relativeTo: repoRoot),
            pipelineVersion: pipelineVersion,
            inputHash: inputHash
        )
        let traceURL = artifactDir.appendingPathComponent("trace.json")

        if replay {
        try Self.verifyReplay(
            traceURL: traceURL,
            spec: specModel,
            specURL: specURL,
            specSourceDescription: specSource.description,
            artifactDir: artifactDir,
            pipelineVersion: pipelineVersion,
            inputHash: inputHash
        )
            print("Replay succeeded for inputHash: \(inputHash)")
            return
        }

        let primaryInputURL = try Self.firstInputURL(for: specModel, specURL: specURL)
        let fallbackText = Self.placeholderPlainText(for: specModel)
        let ocrSettings = OCRSettings(level: "accurate", languages: ["en-US"], revision: 3)
        let (ocrText, ocrStep) = Self.executeOCRStep(
            imageURL: primaryInputURL,
            settings: ocrSettings,
            fallbackText: fallbackText
        )

        let normalizedText = Self.normalizeText(ocrText)
        let plainTextURL = artifactDir.appendingPathComponent("plain.txt")
        try normalizedText.write(to: plainTextURL, atomically: true, encoding: .utf8)
        let plainTextHash = Self.sha256Hex(data: Data(normalizedText.utf8))

        let pdfData = try Self.createSearchablePDFData(from: normalizedText)
        let pdfURL = artifactDir.appendingPathComponent("searchable.pdf")
        try pdfData.write(to: pdfURL)
        let pdfHash = Self.sha256Hex(data: pdfData)
        let pdfContentHash = Self.pdfContentHash(for: normalizedText, pipelineVersion: pipelineVersion)

        let gitCommit = Self.gitCommit(from: repoRoot)
        let trace = DiaplasionTrace(
            createdAt: Self.isoTimestamp(Date()),
            pipelineVersion: pipelineVersion,
            specPath: specURL.path,
            specSource: specSource.description,
            specDataHash: inputContext.specDataHash,
            inputHash: inputHash,
            inputDetails: inputContext.inputDetails,
            plainTextHash: plainTextHash,
            pdfHash: pdfHash,
            pdfContentHash: pdfContentHash,
            gitCommit: gitCommit,
            metadata: specModel.metadata ?? [:],
            steps: [
                ocrStep,
                TraceStep(
                    name: "writePlainText",
                    status: "success",
                    detail: "path=\(plainTextURL.path);hash=\(plainTextHash)"
                ),
                TraceStep(
                    name: "writePDF",
                    status: "success",
                    detail: "path=\(pdfURL.path);hash=\(pdfHash);contentHash=\(pdfContentHash)"
                )
            ]
        )

        let traceData = try JSONEncoder().encode(trace)
        try traceData.write(to: traceURL)

        print("Diaplasion happy-path run complete.")
        print(" - PDF: \(pdfURL.path)")
        print(" - Plain text: \(plainTextURL.path)")
        print(" - Trace: \(traceURL.path)")
    }

    private static func repositoryRoot() throws -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        while true {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent("Package.swift").path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                throw PipelineError.rootNotFound
            }
            current = parent
        }
    }

    private static func artifactDirectory(base: URL, pipelineVersion: String, inputHash: String) throws -> URL {
        let target = base
            .appendingPathComponent(pipelineVersion, isDirectory: true)
            .appendingPathComponent(inputHash, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    private static func computeInputHash(for spec: DiaplasionSpec, specURL: URL) throws -> String {
        var canonicalSpec = spec
        canonicalSpec.inputs.sort { $0.path < $1.path }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let specData = try encoder.encode(canonicalSpec)

        var hasher = SHA256()
        hasher.update(data: specData)

        for input in canonicalSpec.inputs {
            let resolved = URL(fileURLWithPath: input.path, relativeTo: specURL.deletingLastPathComponent()).standardizedFileURL
            let data = try Data(contentsOf: resolved)
            hasher.update(data: data)
        }

        return hasher.finalize().hexString
    }

    private static func placeholderPlainText(for spec: DiaplasionSpec) -> String {
        let headings = spec.inputs.map { $0.label ?? $0.path }
        return "Placeholder plain text for \(spec.title). Inputs: \(headings.joined(separator: ", "))."
    }

    private static func sha256Hex(data: Data) -> String {
        SHA256.hash(data: data).hexString
    }

    private static func isoTimestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func gitCommit(from repoRoot: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]
        process.currentDirectoryURL = repoRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }
        return String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func verifyReplay(
        traceURL: URL,
        spec: DiaplasionSpec,
        specURL: URL,
        specSourceDescription: String,
        artifactDir: URL,
        pipelineVersion: String,
        inputHash: String
    ) throws {
        guard FileManager.default.fileExists(atPath: traceURL.path) else {
            throw PipelineError.missingTrace
        }

        let traceData = try Data(contentsOf: traceURL)
        let trace = try JSONDecoder().decode(DiaplasionTrace.self, from: traceData)
        guard trace.pipelineVersion == pipelineVersion else {
            throw PipelineError.traceMismatch("Pipeline version mismatch: expected \(pipelineVersion), got \(trace.pipelineVersion)")
        }
        guard trace.inputHash == inputHash else {
            throw PipelineError.traceMismatch("Input hash mismatch: expected \(inputHash), got \(trace.inputHash)")
        }
        guard trace.specSource == specSourceDescription else {
            throw PipelineError.traceMismatch("Spec source mismatch: expected \(specSourceDescription), got \(trace.specSource)")
        }

        let specData = try Data(contentsOf: specURL)
        let replayContext = try hashInputs(specData: specData, inputURLs: spec.inputURLs(relativeTo: specURL))
        guard trace.specDataHash == replayContext.specDataHash else {
            throw PipelineError.traceMismatch("Spec data hash mismatch")
        }
        guard trace.inputDetails == replayContext.inputDetails else {
            throw PipelineError.traceMismatch("Input detail mismatch")
        }
        guard trace.inputHash == replayContext.hash else {
            throw PipelineError.traceMismatch("Input hash mismatch during replay")
        }

        let storedPlainPath = artifactDir.appendingPathComponent("plain.txt")
        let storedPlainData = try Data(contentsOf: storedPlainPath)
        guard sha256Hex(data: storedPlainData) == trace.plainTextHash else {
            throw PipelineError.traceMismatch("Stored plain text file does not match trace")
        }
        let storedPlainText = String(data: storedPlainData, encoding: .utf8) ?? ""

        let pdfData = try createSearchablePDFData(from: storedPlainText)
        let pdfHash = sha256Hex(data: pdfData)
        guard trace.pdfHash == pdfHash else {
            throw PipelineError.traceMismatch("PDF hash diverged: expected \(trace.pdfHash), got \(pdfHash)")
        }
        let pdfContentHash = pdfContentHash(for: storedPlainText, pipelineVersion: pipelineVersion)
        guard trace.pdfContentHash == pdfContentHash else {
            throw PipelineError.traceMismatch("PDF content hash mismatch")
        }

        let storedPdfPath = artifactDir.appendingPathComponent("searchable.pdf")
        let storedPdfData = try Data(contentsOf: storedPdfPath)

        guard sha256Hex(data: storedPdfData) == trace.pdfHash else {
            throw PipelineError.traceMismatch("Stored PDF file does not match trace")
        }

        print("Replay validation succeeded for artifact \(artifactDir.path)")
    }

    #if canImport(CoreGraphics) && canImport(CoreText)
    private static func createSearchablePDFData(
        from text: String,
        pageSize: CGSize = CGSize(width: 612, height: 792)
    ) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw PipelineError.pdfCreationFailed
        }

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PipelineError.pdfCreationFailed
        }

        let metadata = [
            "Title" as CFString: "Diaplasion searchable PDF" as CFString,
            "Author" as CFString: "Anigma" as CFString,
            "CreationDate" as CFString: CFDateCreate(nil, 0)!,
            "ModDate" as CFString: CFDateCreate(nil, 0)!
        ] as CFDictionary

        context.beginPDFPage(metadata)
        context.saveGState()

        let textRect = CGRect(x: 72, y: 72, width: pageSize.width - 144, height: pageSize.height - 144)
        context.translateBy(x: 0, y: pageSize.height)
        context.scaleBy(x: 1, y: -1)

        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(gray: 0, alpha: 1)
        ]
        guard let attributedString = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attributes as CFDictionary) else {
            fatalError("Failed to unwrap attributedString")
        }
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGMutablePath()
        path.addRect(textRect)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: CFAttributedStringGetLength(attributedString)), path, nil)
        CTFrameDraw(frame, context)

        context.restoreGState()
        context.endPDFPage()
        context.closePDF()

        return data as Data
    }
    #else
    private static func createSearchablePDFData(
        from text: String,
        pageSize: CGSize = CGSize(width: 612, height: 792)
    ) throws -> Data {
        throw PipelineError.platformUnsupported("PDF creation requires CoreGraphics and CoreText")
    }
    #endif

    private static func resolveSpecSource(specOption: String?, repoRoot: URL) throws -> SpecSource {
        if let spec = specOption {
            let resolved = URL(fileURLWithPath: spec, relativeTo: repoRoot).standardizedFileURL
            return .cli(resolved)
        } else {
            let bundleURL = try DiaplasionModuleResources.urlForHappyPathSpec()
            return .bundle(bundleURL)
        }
    }

    private static func hashInputs(specData: Data, inputURLs: [URL]) throws -> InputHashContext {
        var hasher = SHA256()
        hasher.update(data: specData)
        let specDataHash = SHA256.hash(data: specData).hexString

        let sortedInputs = inputURLs.sorted { $0.path < $1.path }
        var details: [TraceInputDetail] = []

        for url in sortedInputs {
            let data = try Data(contentsOf: url)
            hasher.update(data: data)
            let detail = TraceInputDetail(
                path: url.path,
                hash: SHA256.hash(data: data).hexString,
                byteCount: data.count
            )
            details.append(detail)
        }

        return InputHashContext(
            hash: hasher.finalize().hexString,
            specDataHash: specDataHash,
            inputDetails: details
        )
    }

    private static func executeOCRStep(
        imageURL: URL,
        settings: OCRSettings,
        fallbackText: String
    ) -> (String, TraceStep) {
        do {
            let result = try performOCR(from: imageURL, settings: settings)
            let confidence = result.confidence.map { String(format: "%.2f", $0) } ?? "n/a"
            let detail = "level=\(settings.level);lang=\(settings.languages.joined(separator: ","));revision=\(settings.revision);confidence=\(confidence)"
            let step = TraceStep(name: "OCR", status: "success", detail: detail)
            return (result.text, step)
        } catch {
            let step = TraceStep(name: "OCR", status: "failed", detail: error.localizedDescription)
            return (fallbackText, step)
        }
    }

    #if canImport(Vision)
    private static func performOCR(from imageURL: URL, settings: OCRSettings) throws -> OCRResult {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw PipelineError.imageLoadFailed(imageURL.path)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = settings.level == "accurate" ? .accurate : .fast
        request.recognitionLanguages = settings.languages
        request.revision = settings.revision
        request.usesLanguageCorrection = false

        try handler.perform([request])

        let observations = request.results ?? []
        var fragments: [String] = []
        var confidences: [Float] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            fragments.append(candidate.string)
            confidences.append(candidate.confidence)
        }

        let combined = fragments.joined(separator: "\n")
        let averageConfidence = confidences.isEmpty ? nil : Double(confidences.reduce(0, +) / Float(confidences.count))
        return OCRResult(text: combined, confidence: averageConfidence)
    }
    #else
    private static func performOCR(from imageURL: URL, settings: OCRSettings) throws -> OCRResult {
        throw PipelineError.platformUnsupported("Vision framework not available")
    }
    #endif

    private static func normalizeText(_ text: String) -> String {
        var normalized = text
        normalized = normalized.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.precomposedStringWithCanonicalMapping
    }

    private static func firstInputURL(for spec: DiaplasionSpec, specURL: URL) throws -> URL {
        let inputs = spec.inputURLs(relativeTo: specURL)
        guard let first = inputs.first else {
            throw PipelineError.missingInput("No inputs declared in spec")
        }
        return first
    }

    private static func pdfContentHash(for normalizedText: String, pipelineVersion: String) -> String {
        let payload = "\(pipelineVersion)|\(normalizedText)"
        return sha256Hex(data: Data(payload.utf8))
    }

}

private enum SpecSource: Sendable {
    case bundle(URL)
    case cli(URL)

    var url: URL {
        switch self {
        case .bundle(let url): return url
        case .cli(let url): return url
        }
    }

    var description: String {
        switch self {
        case .bundle(let url):
            return "bundle(\(url.lastPathComponent))"
        case .cli(let url):
            return "cli(\(url.path))"
        }
    }
}

private struct InputHashContext: Sendable {
    let hash: String
    let specDataHash: String
    let inputDetails: [TraceInputDetail]
}

private struct TraceInputDetail: Codable, Sendable, Equatable {
    let path: String
    let hash: String
    let byteCount: Int
}

private struct OCRSettings: Sendable {
    let level: String
    let languages: [String]
    let revision: Int
}

private struct OCRResult: Sendable {
    let text: String
    let confidence: Double?
}

private struct DiaplasionSpec: Codable, Sendable {
    var title: String
    var description: String?
    var inputs: [DiaplasionSpecInput]
    var metadata: [String: String]?

    static func load(from url: URL) throws -> DiaplasionSpec {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DiaplasionSpec.self, from: data)
    }

    func inputURLs(relativeTo specURL: URL) -> [URL] {
        inputs.compactMap { input in
            URL(fileURLWithPath: input.path, relativeTo: specURL.deletingLastPathComponent()).standardizedFileURL
        }
    }
}

private struct DiaplasionSpecInput: Codable, Sendable {
    var path: String
    var label: String?
}

private extension DiaplasionSpec {
    static func decode(from data: Data) throws -> DiaplasionSpec {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

private struct DiaplasionTrace: Codable {
    let createdAt: String
    let pipelineVersion: String
    let specPath: String
    let specSource: String
    let specDataHash: String
    let inputHash: String
    let inputDetails: [TraceInputDetail]
    let plainTextHash: String
    let pdfHash: String
    let pdfContentHash: String
    let gitCommit: String?
    let metadata: [String: String]
    let steps: [TraceStep]
}

private struct TraceStep: Codable {
    let name: String
    let status: String
    let detail: String?
}

private enum PipelineError: LocalizedError {
    case rootNotFound
    case missingInput(String)
    case missingTrace
    case traceMismatch(String)
    case imageLoadFailed(String)
    case pdfCreationFailed
    case platformUnsupported(String)

    var errorDescription: String? {
        switch self {
        case .rootNotFound:
            return "Unable to locate repo root (Package.swift)."
        case .missingInput(let detail):
            return "Missing pipeline input: \(detail)"
        case .missingTrace:
            return "Trace file is missing; run the pipeline before replaying."
        case .traceMismatch(let detail):
            return "Replay trace mismatch: \(detail)"
        case .imageLoadFailed(let path):
            return "Cannot load image at path: \(path)"
        case .pdfCreationFailed:
            return "Failed to render placeholder PDF."
        case .platformUnsupported(let detail):
            return "Platform unsupported: \(detail)"
        }
    }
}

private extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
