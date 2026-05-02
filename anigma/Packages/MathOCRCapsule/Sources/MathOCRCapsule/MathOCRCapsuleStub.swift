import Foundation
import CapsuleCore
import LayoutEngineCapsule
import TelemetryCore

public struct EquationBoundingBox: Codable, Hashable, Sendable {
    public var left: Double
    public var top: Double
    public var right: Double
    public var bottom: Double

    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }
}

public enum MathSymbolType: Int32, Codable, Hashable, Sendable {
    case operatorSymbol = 0
    case variable = 1
    case function = 2
    case number = 3
    case parenthesis = 4
    case punctuation = 5
    case other = 6
}

public struct EquationSymbol: Codable, Hashable, Sendable {
    public var text: String
    public var symbolType: MathSymbolType?
    public var positionInEquation: Int

    public init(text: String, symbolType: MathSymbolType? = nil, positionInEquation: Int = 0) {
        self.text = text
        self.symbolType = symbolType
        self.positionInEquation = positionInEquation
    }
}

public struct Equation: Codable, Hashable, Sendable {
    public var equationID: String
    public var boundingBox: EquationBoundingBox
    public var latex: String
    public var unicode: String
    public var mathml: String
    public var symbols: [EquationSymbol]
    public var pageIndex: Int
    public var confidence: Double

    public init(
        equationID: String = UUID().uuidString,
        boundingBox: EquationBoundingBox,
        latex: String,
        unicode: String,
        mathml: String,
        symbols: [EquationSymbol] = [],
        pageIndex: Int = 0,
        confidence: Double = 1.0
    ) {
        self.equationID = equationID
        self.boundingBox = boundingBox
        self.latex = latex
        self.unicode = unicode
        self.mathml = mathml
        self.symbols = symbols
        self.pageIndex = pageIndex
        self.confidence = confidence
    }
}

public struct EquationRecognitionResult: Codable, Hashable, Sendable {
    public var equations: [Equation]
    public var processingTime: UInt64

    public var processingTimeUs: UInt64 {
        processingTime
    }

    public init(equations: [Equation] = [], processingTime: UInt64 = 0) {
        self.equations = equations
        self.processingTime = processingTime
    }

    public init(equations: [Equation] = [], processingTimeUs: UInt64) {
        self.init(equations: equations, processingTime: processingTimeUs)
    }
}

public struct EquationRecognitionConfig: Codable, Hashable, Sendable {
    public var enableMLRecognition: Bool = false
    public var minEquationArea: Double = 500.0
    public var enableSymbolRecognition: Bool = true
    public var enableLaTeXGeneration: Bool = true
    public var enableUnicodeGeneration: Bool = true
    public var onnxModelPath: String? = nil
    public var symbolDictPath: String? = nil

    public static var `default`: EquationRecognitionConfig {
        EquationRecognitionConfig()
    }

    public init() {}
}

public actor MathOCRCapsule: IdentifiableCapsule {
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "math-ocr-stub-v1"

    public init(
        config: EquationRecognitionConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        _ = config
    }

    public func recognizeEquations(
        from segments: [TextSegment],
        pageIndex: Int,
        pageWidth: Double,
        pageHeight: Double
    ) throws -> EquationRecognitionResult {
        diagnostics.event(
            level: .debug,
            category: "mathocr.stub.recognize",
            message: "Math OCR stub returned no equations",
            correlationID: nil,
            metadata: [
                "segments": "\(segments.count)",
                "page_index": "\(pageIndex)",
                "page_width": "\(pageWidth)",
                "page_height": "\(pageHeight)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        return EquationRecognitionResult(equations: [], processingTime: 0)
    }

    public func recognizeFromSegments(
        pageIndex: Int,
        segments: [TextSegment],
        pageWidth: Double,
        pageHeight: Double
    ) throws -> EquationRecognitionResult {
        try recognizeEquations(
            from: segments,
            pageIndex: pageIndex,
            pageWidth: pageWidth,
            pageHeight: pageHeight
        )
    }

    public func recognizeFromPDF(pdfData: Data) throws -> EquationRecognitionResult {
        diagnostics.event(
            level: .debug,
            category: "mathocr.stub.recognize_pdf",
            message: "Math OCR PDF stub returned no equations",
            correlationID: nil,
            metadata: [
                "pdf_size": "\(pdfData.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        return EquationRecognitionResult(equations: [], processingTime: 0)
    }

    public func exportToLaTeX(equation: Equation) throws -> String {
        equation.latex
    }

    public func exportToUnicode(equation: Equation) throws -> String {
        equation.unicode
    }

    public func exportToMathML(equation: Equation) throws -> String {
        equation.mathml
    }
}
