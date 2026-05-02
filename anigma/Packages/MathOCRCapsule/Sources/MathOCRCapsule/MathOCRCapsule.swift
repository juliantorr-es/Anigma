// MathOCRCapsule - Swift wrapper for mathematical equation recognition
//
// This capsule provides high-performance equation recognition from PDF documents
// using the "Swift governs, C++ computes" architecture pattern.

import Foundation
import CapsuleCore
import TelemetryCore
import LayoutEngineCapsule

/// Equation bounding box representation
public struct EquationBoundingBox: Codable, Hashable, Sendable {
    /// Left coordinate
    public let left: Double
    
    /// Top coordinate
    public let top: Double
    
    /// Right coordinate
    public let right: Double
    
    /// Bottom coordinate
    public let bottom: Double
    
    /// Initialize a new bounding box
    ///
    /// - Parameters:
    ///   - left: Left coordinate
    ///   - top: Top coordinate
    ///   - right: Right coordinate
    ///   - bottom: Bottom coordinate
    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }
}

/// Mathematical symbol type
public enum MathSymbolType: Int32, Codable, Hashable, Sendable {
    /// Operator (+, -, ×, ÷, =, etc.)
    case operatorSymbol = 0
    /// Variable (x, y, z, etc.)
    case variable = 1
    /// Function (sin, cos, log, etc.)
    case function = 2
    /// Number
    case number = 3
    /// Parentheses/brackets
    case parenthesis = 4
    /// Punctuation (comma, semicolon, etc.)
    case punctuation = 5
    /// Other symbol
    case other = 6
}

/// Mathematical symbol representation
public struct MathSymbol: Codable, Hashable, Sendable {
    /// Symbol text (LaTeX or Unicode)
    public let text: String
    
    /// Bounding box
    public let bbox: EquationBoundingBox
    
    /// Symbol type
    public let symbolType: MathSymbolType
    
    /// Confidence score (0-1)
    public let confidence: Double
    
    /// Initialize a new mathematical symbol
    ///
    /// - Parameters:
    ///   - text: Symbol text
    ///   - bbox: Bounding box
    ///   - symbolType: Symbol type
    ///   - confidence: Confidence score
    public init(
        text: String,
        bbox: EquationBoundingBox,
        symbolType: MathSymbolType,
        confidence: Double = 1.0
    ) {
        self.text = text
        self.bbox = bbox
        self.symbolType = symbolType
        self.confidence = confidence
    }
}

/// Equation type
public enum EquationType: Int32, Codable, Hashable, Sendable {
    /// Inline equation
    case inline = 0
    /// Display equation (centered, numbered)
    case display = 1
    /// Equation array (multiple equations)
    case array = 2
    /// Other equation type
    case other = 3
}

/// Mathematical equation representation
public struct Equation: Codable, Hashable, Sendable {
    /// Equation ID
    public let equationID: String
    
    /// LaTeX representation
    public let latex: String
    
    /// Unicode representation
    public let unicode: String
    
    /// Symbols in the equation
    public let symbols: [MathSymbol]
    
    /// Bounding box
    public let bbox: EquationBoundingBox
    
    /// Page index
    public let pageIndex: Int
    
    /// Confidence score (0-1)
    public let confidence: Double
    
    /// Equation type
    public let equationType: EquationType
    
    /// Initialize a new equation
    ///
    /// - Parameters:
    ///   - equationID: Equation ID
    ///   - latex: LaTeX representation
    ///   - unicode: Unicode representation
    ///   - symbols: Symbols in the equation
    ///   - bbox: Bounding box
    ///   - pageIndex: Page index
    ///   - confidence: Confidence score
    ///   - equationType: Equation type
    public init(
        equationID: String,
        latex: String,
        unicode: String,
        symbols: [MathSymbol],
        bbox: EquationBoundingBox,
        pageIndex: Int,
        confidence: Double = 1.0,
        equationType: EquationType = .display
    ) {
        self.equationID = equationID
        self.latex = latex
        self.unicode = unicode
        self.symbols = symbols
        self.bbox = bbox
        self.pageIndex = pageIndex
        self.confidence = confidence
        self.equationType = equationType
    }
}

/// Equation recognition result
public struct EquationRecognitionResult: Codable, Hashable, Sendable {
    /// Recognized equations
    public let equations: [Equation]
    
    /// Total processing time in microseconds
    public let processingTimeUs: UInt64
    
    /// Initialize a new equation recognition result
    ///
    /// - Parameters:
    ///   - equations: Recognized equations
    ///   - processingTimeUs: Processing time in microseconds
    public init(
        equations: [Equation],
        processingTimeUs: UInt64 = 0
    ) {
        self.equations = equations
        self.processingTimeUs = processingTimeUs
    }
}

/// Equation recognition configuration
public struct EquationRecognitionConfig: Codable, Hashable, Sendable {
    /// Enable ML-based recognition (requires ONNX Runtime)
    public let enableMLRecognition: Bool
    
    /// Minimum equation area (in points²)
    public let minEquationArea: Double
    
    /// Enable symbol-level recognition
    public let enableSymbolRecognition: Bool
    
    /// Enable LaTeX generation
    public let enableLaTeXGeneration: Bool
    
    /// Enable Unicode generation
    public let enableUnicodeGeneration: Bool
    
    /// ONNX model path (optional)
    public let onnxModelPath: String?
    
    /// Custom symbol dictionary path (optional)
    public let symbolDictPath: String?
    
    /// Default configuration
    public static var `default`: EquationRecognitionConfig {
        EquationRecognitionConfig(
            enableMLRecognition: false,
            minEquationArea: 500.0,
            enableSymbolRecognition: true,
            enableLaTeXGeneration: true,
            enableUnicodeGeneration: true,
            onnxModelPath: nil,
            symbolDictPath: nil
        )
    }
    
    /// Initialize a new configuration
    ///
    /// - Parameters:
    ///   - enableMLRecognition: Enable ML-based recognition
    ///   - minEquationArea: Minimum equation area
    ///   - enableSymbolRecognition: Enable symbol-level recognition
    ///   - enableLaTeXGeneration: Enable LaTeX generation
    ///   - enableUnicodeGeneration: Enable Unicode generation
    ///   - onnxModelPath: ONNX model path
    ///   - symbolDictPath: Custom symbol dictionary path
    public init(
        enableMLRecognition: Bool = false,
        minEquationArea: Double = 500.0,
        enableSymbolRecognition: Bool = true,
        enableLaTeXGeneration: Bool = true,
        enableUnicodeGeneration: Bool = true,
        onnxModelPath: String? = nil,
        symbolDictPath: String? = nil
    ) {
        self.enableMLRecognition = enableMLRecognition
        self.minEquationArea = minEquationArea
        self.enableSymbolRecognition = enableSymbolRecognition
        self.enableLaTeXGeneration = enableLaTeXGeneration
        self.enableUnicodeGeneration = enableUnicodeGeneration
        self.onnxModelPath = onnxModelPath
        self.symbolDictPath = symbolDictPath
    }
}

/// Equation recognition capsule
public actor MathOCRCapsule: IdentifiableCapsule {
    private let handle: CapsuleHandle
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "math-ocr-v1"
    
    /// Initialize the equation recognition capsule
    ///
    /// - Parameters:
    ///   - config: Equation recognition configuration
    ///   - diagnostics: Optional diagnostics provider
    /// - Throws: If initialization fails
    public init(
        config: EquationRecognitionConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "MathOCRCapsule.init",
            category: "mathocr.init",
            correlationID: nil,
            tags: [
                "algorithm_version": Self.algorithmVersion,
                "enable_ml_recognition": "\(config.enableMLRecognition)",
                "min_equation_area": "\(config.minEquationArea)"
            ]
        )
        
        do {
            var cConfig = anigma_equation_recognition_config_t()
            cConfig.enable_ml_recognition = config.enableMLRecognition
            cConfig.min_equation_area = config.minEquationArea
            cConfig.enable_symbol_recognition = config.enableSymbolRecognition
            cConfig.enable_latex_generation = config.enableLaTeXGeneration
            cConfig.enable_unicode_generation = config.enableUnicodeGeneration
            cConfig.onnx_model_path = config.onnxModelPath?.cString(using: .utf8)
            cConfig.symbol_dict_path = config.symbolDictPath?.cString(using: .utf8)
            
            var cHandle = anigma_capsule_handle_t()
            let status = anigma_equation_recognition_capsule_create(&cConfig, &cHandle)
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                resolvedDiagnostics.event(
                    level: .error,
                    category: "mathocr.init",
                    message: "Failed to initialize equation recognition capsule: \(error)",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw error
            }
            
            self.handle = CapsuleHandle(rawValue: cHandle)
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "mathocr.init",
                message: "Failed to initialize equation recognition capsule: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    deinit {
        anigma_equation_recognition_capsule_destroy(handle.rawValue)
    }
    
    /// Recognize equations from PDF page layout
    ///
    /// - Parameters:
    ///   - pageIndex: Page index
    ///   - segments: Text segments from layout engine
    ///   - pageWidth: Page width in points
    ///   - pageHeight: Page height in points
    /// - Returns: Equation recognition result
    /// - Throws: If recognition fails
    public func recognizeFromSegments(
        pageIndex: Int,
        segments: [LayoutEngineCapsule.TextSegment],
        pageWidth: Double,
        pageHeight: Double
    ) throws -> EquationRecognitionResult {
        let span = diagnostics.beginSpan(
            name: "MathOCRCapsule.recognizeFromSegments",
            category: "mathocr.recognize",
            correlationID: nil,
            tags: [
                "page_index": "\(pageIndex)",
                "segment_count": "\(segments.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            // Convert segments to C array
            let cSegments = segments.map { $0.toCLayoutSegment() }
            
            var cResult = anigma_equation_recognition_result_t()
            let status = anigma_equation_recognition_extract_from_segments(
                handle.rawValue,
                Int32(pageIndex),
                cSegments,
                cSegments.count,
                pageWidth,
                pageHeight,
                &cResult
            )
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                span.end(status: .error)
                throw error
            }
            
            // Convert result to Swift
            let result = try convertResult(cResult)
            
            // Cleanup
            anigma_equation_recognition_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Recognize equations from PDF document
    ///
    /// - Parameters:
    ///   - pdfData: PDF document data
    /// - Returns: Equation recognition result
    /// - Throws: If recognition fails
    public func recognizeFromPDF(pdfData: Data) throws -> EquationRecognitionResult {
        let span = diagnostics.beginSpan(
            name: "MathOCRCapsule.recognizeFromPDF",
            category: "mathocr.recognize",
            correlationID: nil,
            tags: [
                "pdf_size": "\(pdfData.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            var cResult = anigma_equation_recognition_result_t()
            let status = anigma_equation_recognition_extract_from_pdf(
                handle.rawValue,
                pdfData.bytes.assumingMemoryBound(to: UInt8.self),
                pdfData.count,
                &cResult
            )
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                span.end(status: .error)
                throw error
            }
            
            // Convert result to Swift
            let result = try convertResult(cResult)
            
            // Cleanup
            anigma_equation_recognition_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Export equation to LaTeX
    ///
    /// - Parameter equation: Equation to export
    /// - Returns: LaTeX string
    /// - Throws: If export fails
    public func exportToLaTeX(equation: Equation) throws -> String {
        var latexPtr: UnsafePointer<CChar>? = nil
        var latexLen: size_t = 0
        
        let status = anigma_equation_export_to_latex(
            equation.toCEquation(),
            &latexPtr,
            &latexLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.from(status: status)
        }
        
        guard let latexPtr = latexPtr else {
            throw CapsuleError.internalError
        }
        
        let latex = String(cString: latexPtr, encoding: .utf8) ?? ""
        anigma_equation_free_export(latexPtr)
        
        return latex
    }
    
    /// Export equation to Unicode
    ///
    /// - Parameter equation: Equation to export
    /// - Returns: Unicode string
    /// - Throws: If export fails
    public func exportToUnicode(equation: Equation) throws -> String {
        var unicodePtr: UnsafePointer<CChar>? = nil
        var unicodeLen: size_t = 0
        
        let status = anigma_equation_export_to_unicode(
            equation.toCEquation(),
            &unicodePtr,
            &unicodeLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.from(status: status)
        }
        
        guard let unicodePtr = unicodePtr else {
            throw CapsuleError.internalError
        }
        
        let unicode = String(cString: unicodePtr, encoding: .utf8) ?? ""
        anigma_equation_free_export(unicodePtr)
        
        return unicode
    }
    
    /// Export equation to MathML
    ///
    /// - Parameter equation: Equation to export
    /// - Returns: MathML string
    /// - Throws: If export fails
    public func exportToMathML(equation: Equation) throws -> String {
        var mathmlPtr: UnsafePointer<CChar>? = nil
        var mathmlLen: size_t = 0
        
        let status = anigma_equation_export_to_mathml(
            equation.toCEquation(),
            &mathmlPtr,
            &mathmlLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.from(status: status)
        }
        
        guard let mathmlPtr = mathmlPtr else {
            throw CapsuleError.internalError
        }
        
        let mathml = String(cString: mathmlPtr, encoding: .utf8) ?? ""
        anigma_equation_free_export(mathmlPtr)
        
        return mathml
    }
    
    // MARK: - Private Methods
    
    private func convertResult(_ cResult: anigma_equation_recognition_result_t) throws -> EquationRecognitionResult {
        // TODO: Implement conversion from C result to Swift result
        // This would convert the C equation structures to Swift Equation objects
        
        return EquationRecognitionResult(
            equations: [],
            processingTimeUs: cResult.processing_time_us
        )
    }
}

// MARK: - Extension for LayoutEngineCapsule.TextSegment

extension LayoutEngineCapsule.TextSegment {
    func toCLayoutSegment() -> anigma_layout_segment_t {
        // TODO: Implement conversion
        return anigma_layout_segment_t()
    }
}

// MARK: - Extension for Equation

extension Equation {
    func toCEquation() -> anigma_equation_t {
        // TODO: Implement conversion
        return anigma_equation_t()
    }
}

// MARK: - Extension for EquationBoundingBox

extension EquationBoundingBox {
    var cBBox: anigma_equation_bbox_t {
        return anigma_equation_bbox_t(
            left: left,
            top: top,
            right: right,
            bottom: bottom
        )
    }
}
