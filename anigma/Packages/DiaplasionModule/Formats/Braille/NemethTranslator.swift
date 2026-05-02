import AnigmaPrimitives

import AnigmaPrimitives

//
//  NemethTranslator.swift
//  DiaplasionModule
//
//  Translates mathematical expressions to Nemeth Braille.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

/// Translates mathematical expressions to Nemeth Braille notation.
public struct NemethTranslator: Sendable {
    
    // MARK: - Configuration
    
    /// Enable Nemeth math translation
    public let enableNemeth: Bool
    
    /// Include math indicators in Braille
    public let includeMathIndicators: Bool
    
    /// Use simplified Nemeth for basic expressions
    public let useSimplifiedNemeth: Bool
    
    // MARK: - Initialization
    
    public init(
        enableNemeth: Bool? = nil,
        includeMathIndicators: Bool = true,
        useSimplifiedNemeth: Bool = false
    ) {
        self.enableNemeth = enableNemeth ?? DiaplasionConfiguration.brailleEnableNemeth
        self.includeMathIndicators = includeMathIndicators
        self.useSimplifiedNemeth = useSimplifiedNemeth
    }
    
    // MARK: - Public Interface
    
    /// Translate mathematical expressions in text to Nemeth Braille.
    public func translateNemeth(_ text: String) -> String {
        guard enableNemeth else { return text }
        
        var translatedText = text
        
        // Process mathematical expressions in order of complexity
        translatedText = translateFractions(translatedText)
        translatedText = translateSuperscriptsAndSubscripts(translatedText)
        translatedText = translateGreekLetters(translatedText)
        translatedText = translateMathematicalOperators(translatedText)
        translatedText = translateMathematicalFunctions(translatedText)
        translatedText = translateParenthesesAndBrackets(translatedText)
        translatedText = translateEqualitiesAndInequalities(translatedText)
        translatedText = translateSquareRootsAndPowers(translatedText)
        
        // Add math indicators if enabled
        if includeMathIndicators {
            translatedText = addMathIndicators(translatedText)
        }
        
        return translatedText
    }
    
    /// Detect if text contains mathematical content.
    public func containsMathematicalContent(_ text: String) -> Bool {
        // Check for common mathematical indicators
        let mathPatterns = [
            #"\d+/\d+"#, // Fractions
            #"[a-zA-Z]\^[0-9]+"#, // Superscripts
            #"[a-zA-Z]_[0-9]+"#, // Subscripts
            #"√[\d\w]+"#, // Square roots
            #"α|β|γ|δ|ε|ζ|η|θ|ι|κ|λ|μ|ν|ξ|ο|π|ρ|σ|τ|υ|φ|χ|ψ|ω"#, // Greek letters
            #"[±≤≥≠≈]"#, // Mathematical symbols
            #"[∑∏∫]"# // Calculus symbols
        ]
        
        for pattern in mathPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Private Translation Methods
    
    private func translateFractions(_ text: String) -> String {
        // Translate simple fractions like "1/2" to Nemeth
        return text.replacingOccurrences(
            of: #"(\d+)/(\d+)"#,
            with: "$1⠤$2", // Nemeth fraction indicator
            options: .regularExpression
        )
    }
    
    private func translateSuperscriptsAndSubscripts(_ text: String) -> String {
        var translated = text
        
        // Translate superscripts (e.g., x^2)
        translated = translated.replacingOccurrences(
            of: #"([a-zA-Z])\^(\d+)"#,
            with: "$1⠘⠼$2", // Superscript indicator
            options: .regularExpression
        )
        
        // Translate subscripts (e.g., H_2O)
        translated = translated.replacingOccurrences(
            of: #"([a-zA-Z])_(\d+)"#,
            with: "$1⠰⠼$2", // Subscript indicator
            options: .regularExpression
        )
        
        return translated
    }
    
    private func translateGreekLetters(_ text: String) -> String {
        let greekToNemeth: [String: String] = [
            "α": "⠨⠁", // alpha
            "β": "⠨⠃", // beta
            "γ": "⠨⠛", // gamma
            "δ": "⠨⠙", // delta
            "ε": "⠨⠑", // epsilon
            "ζ": "⠨⠵", // zeta
            "η": "⠨⠱", // eta
            "θ": "⠨⠹", // theta
            "ι": "⠨⠊", // iota
            "κ": "⠨⠅", // kappa
            "λ": "⠨⠇", // lambda
            "μ": "⠨⠍", // mu
            "ν": "⠨⠝", // nu
            "ξ": "⠨⠭", // xi
            "π": "⠨⏋", // pi
            "ρ": "⠨⠗", // rho
            "σ": "⠨⠎", // sigma
            "τ": "⠨⠞", // tau
            "υ": "⠨⥖", // upsilon
            "φ": "⠨⠋", // phi
            "χ": "⠨⠯", // chi
            "ψ": "⠨⠽", // psi
            "ω": "⠨⺚"  // omega
        ]
        
        var translated = text
        for (greek, nemeth) in greekToNemeth {
            translated = translated.replacingOccurrences(of: greek, with: nemeth)
        }
        return translated
    }
    
    private func translateMathematicalOperators(_ text: String) -> String {
        let operatorsToNemeth: [String: String] = [
            "+": "⠖",     // plus
            "-": "⠤",     // minus
            "×": "⠈⠡",   // multiplication
            "÷": "⠨⠌",   // division
            "±": "⠸⠖",   // plus-minus
            "≈": "⠈⠱",   // approximately equal
            "≠": "⠈⠂",   // not equal
            "≤": "⠈⠅",   // less than or equal
            "≥": "⠈⠂⠅", // greater than or equal
            "<": "⠈⠣",   // less than
            ">": "⠈⠒",   // greater than
            "∞": "⠼⠿",   // infinity
            "∑": "⠨⠠",   // summation
            "∏": "⠨⠏",   // product
            "∫": "⠨⠮"    // integral
        ]
        
        var translated = text
        for (operatorSymbol, nemeth) in operatorsToNemeth {
            translated = translated.replacingOccurrences(of: operatorSymbol, with: nemeth)
        }
        return translated
    }
    
    private func translateMathematicalFunctions(_ text: String) -> String {
        var translated = text
        
        // Common mathematical functions
        let functionsToNemeth: [String: String] = [
            "sin": "⠎",
            "cos": "⠉",
            "tan": "⠞",
            "log": "⠇",
            "ln": "⠇⠝",
            "exp": "⠑⠏"
        ]
        
        for (function, nemeth) in functionsToNemeth {
            translated = translated.replacingOccurrences(
                of: "\(function)(",
                with: "\(nemeth)⠷"
            )
        }
        
        return translated
    }
    
    private func translateParenthesesAndBrackets(_ text: String) -> String {
        var translated = text
        
        // Mathematical parentheses
        translated = translated.replacingOccurrences(of: "(", with: "⠷")
        translated = translated.replacingOccurrences(of: ")", with: "⠾")
        
        // Square brackets
        translated = translated.replacingOccurrences(of: "[", with: "⠈⠇")
        translated = translated.replacingOccurrences(of: "]", with: "⠈⠾")
        
        // Curly braces
        translated = translated.replacingOccurrences(of: "{", with: "⠨⠇")
        translated = translated.replacingOccurrences(of: "}", with: "⠨⠾")
        
        return translated
    }
    
    private func translateEqualitiesAndInequalities(_ text: String) -> String {
        var translated = text
        
        // Equals sign
        translated = translated.replacingOccurrences(of: "=", with: "⠈⠂")
        
        // Not equal sign
        translated = translated.replacingOccurrences(of: "≠", with: "⠈⠂⠿")
        
        return translated
    }
    
    private func translateSquareRootsAndPowers(_ text: String) -> String {
        var translated = text
        
        // Square root symbol
        translated = translated.replacingOccurrences(of: "√", with: "⠨⠣")
        
        // Powers (alternative notation)
        translated = translated.replacingOccurrences(
            of: #"(\w+)\^(\d+)"#,
            with: "⠷$1⠾⠘⠼$2",
            options: .regularExpression
        )
        
        return translated
    }
    
    private func addMathIndicators(_ text: String) -> String {
        // Add Nemeth math indicators around mathematical expressions
        var withIndicators = text
        
        // Simple pattern to identify math expressions
        let mathPattern = #"([⠼⠐⠠⠮⠏⠎⠉⠞⠇⠨⠏⠑⠜⠱⠤⠖⠈⠣⠈⠒⠈⠅⠈⠂⠒⠾⠈⠇⠈⠾⠨⠇⠨⠾⠘⠰⠣⠿]+)"#
        
        // Wrap identified math expressions with indicators
        // This is a simplified approach - in practice, you'd use more sophisticated parsing
        withIndicators = "⠸⠨" + withIndicators + "⠨⠱"
        
        return withIndicators
    }
}

// MARK: - Braille Mathematical Symbols

extension NemethTranslator {
    
    /// Get common Nemeth mathematical symbols.
    public static var commonSymbols: [Character: String] {
        return [
            "0": "⠼⠚",
            "1": "⠼⠁",
            "2": "⠼⠃",
            "3": "⠼⠉",
            "4": "⠼⠙",
            "5": "⠼⠑",
            "6": "⠼⠋",
            "7": "⠼⠛",
            "8": "⠼⠓",
            "9": "⠼⠊",
            ".": "⠲",
            ",": "⠂",
            ";": "⠆",
            ":": "⠒",
            "?": "⠦",
            "!": "⠖"
        ]
    }
    
    /// Get Nemeth mathematical operators.
    public static var operators: [String: String] {
        return [
            "+": "⠖",
            "-": "⠤",
            "×": "⠈⠡",
            "÷": "⠨⠌",
            "=": "⠈⠂",
            "≠": "⠈⠂⠿",
            "<": "⠈⠣",
            ">": "⠈⠒",
            "≤": "⠈⠅",
            "≥": "⠈⠂⠅",
            "√": "⠨⠣",
            "∞": "⠼⠿",
            "π": "⠨⏋",
            "∑": "⠨⠠",
            "∏": "⠨⠏",
            "∫": "⠨⠮"
        ]
    }
    
    /// Get Nemeth function indicators.
    public static var functions: [String: String] {
        return [
            "sin": "⠎",
            "cos": "⠉",
            "tan": "⠞",
            "cot": "⠉⠤",
            "sec": "⠎⠔",
            "csc": "⠎⠎",
            "log": "⠇",
            "ln": "⠇⠝",
            "exp": "⠑⠏",
            "lim": "⠇⠊",
            "min": "⠍⠊",
            "max": "⠍⠭"
        ]
    }
}

// MARK: - System Integration

/// System that applies Nemeth Braille translation to mathematical content.
public struct NemethTranslationSystem: System {
    public var name: String { "NemethTranslation" }
    
    private let translator: NemethTranslator
    
    public init(translator: NemethTranslator = NemethTranslator()) {
        self.translator = translator
    }
    
    public func update(world: World) async {
        let entities = await world.query(
            ChunkedTextComponent.self,
            TransformRequestComponent.self
        )
        
        for (entity, chunked, transform) in entities {
            // Skip if not processing Braille
            if !transform.targetFormats.contains(.brailleReady) {
                continue
            }
            
            // Skip if already processed
            if await world.hasComponent(entity, NemethTranslatedComponent.self) {
                continue
            }
            
            // Process chunks for mathematical content
            let translatedChunks = processChunksForNemeth(chunked.chunks)
            
            let component = NemethTranslatedComponent(
                originalChunks: chunked.chunks,
                translatedChunks: translatedChunks,
                translationDate: Date(),
                containsMath: translatedChunks.contains { $0.containsMathematicalContent }
            )
            
            await world.addComponent(entity, component)
            
            if component.containsMath {
                logInfo(
                    "Applied Nemeth Braille translation to entity \(entity)",
                    category: "Diaplasion"
                )
            }
        }
    }
    
    private func processChunksForNemeth(_ chunks: [TextChunk]) -> [NemethTranslatedChunk] {
        return chunks.map { chunk in
            let translatedText = translator.translateNemeth(chunk.text)
            let hasMath = translator.containsMathematicalContent(chunk.text)
            
            return NemethTranslatedChunk(
                originalText: chunk.text,
                translatedText: translatedText,
                chunkType: chunk.chunkType,
                pageNumber: chunk.pageNumber ?? 0,
                containsMathematicalContent: hasMath,
                wasModified: translatedText != chunk.text
            )
        }
    }
}

/// Component containing Nemeth Braille translation results.
public struct NemethTranslatedComponent: Component {
    public let originalChunks: [TextChunk]
    public let translatedChunks: [NemethTranslatedChunk]
    public let translationDate: Date
    public let containsMath: Bool
    
    public init(
        originalChunks: [TextChunk],
        translatedChunks: [NemethTranslatedChunk],
        translationDate: Date,
        containsMath: Bool
    ) {
        self.originalChunks = originalChunks
        self.translatedChunks = translatedChunks
        self.translationDate = translationDate
        self.containsMath = containsMath
    }
}

/// A chunk of text with Nemeth Braille translation applied.
public struct NemethTranslatedChunk: Sendable {
    public let originalText: String
    public let translatedText: String
    public let chunkType: ChunkType
    public let pageNumber: Int
    public let containsMathematicalContent: Bool
    public let wasModified: Bool
    
    public init(
        originalText: String,
        translatedText: String,
        chunkType: ChunkType,
        pageNumber: Int,
        containsMathematicalContent: Bool,
        wasModified: Bool
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.chunkType = chunkType
        self.pageNumber = pageNumber
        self.containsMathematicalContent = containsMathematicalContent
        self.wasModified = wasModified
    }
}