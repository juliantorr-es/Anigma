//
//  BrailleExportSystem.swift
//  DiaplasionModule
//
//  Extracted from DiaplasionSystems.swift
//  System that generates braille-ready output using Unified English Braille (UEB).
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Braille Export System

/// System that generates braille-ready output using Unified English Braille (UEB).
public struct BrailleExportSystem: System {
    public var name: String { "BrailleExport" }

    /// Braille grade for translation
    public enum BrailleGrade: String, Codable, Sendable {
        case grade1  // Uncontracted - letter by letter
        case grade2  // Contracted - uses standard contractions
    }

    /// Output format for braille files
    public enum BrailleOutputFormat: String, Codable, Sendable {
        case brf  // Braille Ready Format (ASCII)
        case pef  // Portable Embosser Format (XML)
    }

    /// Configuration for braille export
    public struct Configuration: Sendable {
        public let grade: BrailleGrade
        public let outputFormats: Set<BrailleOutputFormat>
        public let cellsPerLine: Int
        public let linesPerPage: Int
        public let outputDirectory: String?

        public init(
            grade: BrailleGrade = .grade2,
            outputFormats: Set<BrailleOutputFormat> = [.brf],
            cellsPerLine: Int = 40,
            linesPerPage: Int = 25,
            outputDirectory: String? = nil
        ) {
            self.grade = grade
            self.outputFormats = outputFormats
            self.cellsPerLine = cellsPerLine
            self.linesPerPage = linesPerPage
            self.outputDirectory = outputDirectory
        }
    }

    private let configuration: Configuration
    private let translator: UEBTranslator

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.translator = UEBTranslator(grade: configuration.grade)
    }

    public func update(world: World) async {
        // Query all entities - we'll filter for braille targets
        let entities = await world.allEntities()

        for entityId in entities {
            guard let chunked = await world.getComponent(entityId, ChunkedTextComponent.self),
                  let request = await world.getComponent(entityId, TransformRequestComponent.self),
                  request.targetFormats.contains(.brailleReady),
                  request.status == .processing else {
                continue
            }

            await Logger.shared.debug("BrailleExportSystem processing entity \(entityId)", category: "Diaplasion")

            do {
                // Translate chunks to braille
                var brailleChunks: [BrailleChunk] = []
                for chunk in chunked.chunks {
                    let brailleText = translator.translate(chunk.text)
                    brailleChunks.append(BrailleChunk(
                        original: chunk,
                        brailleText: brailleText,
                        grade: configuration.grade
                    ))
                }

                // Determine output directory
                let outputDir = configuration.outputDirectory ?? FileManager.default.temporaryDirectory
                    .appendingPathComponent("braille_\(UUID().uuidString)")
                    .path
                try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

                var outputs: [OutputFormat: OutputReference] = [:]

                // Generate BRF if requested
                if configuration.outputFormats.contains(.brf) {
                    let brfPath = (outputDir as NSString).appendingPathComponent("\(request.requestId).brf")
                    try generateBRF(chunks: brailleChunks, to: brfPath)

                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: brfPath)[.size] as? Int64) ?? 0
                    outputs[.brailleReady] = OutputReference(
                        format: .brailleReady,
                        uri: brfPath,
                        fileSize: fileSize
                    )

                    await Logger.shared.info("Generated BRF: \(brfPath)", category: "Diaplasion")
                }

                // Generate PEF if requested
                if configuration.outputFormats.contains(.pef) {
                    let pefPath = (outputDir as NSString).appendingPathComponent("\(request.requestId).pef")
                    try generatePEF(chunks: brailleChunks, to: pefPath, requestId: request.requestId)

                    await Logger.shared.info("Generated PEF: \(pefPath)", category: "Diaplasion")
                }

                // Update or create AccessibleOutputComponent
                var accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
                    ?? AccessibleOutputComponent()
                for (format, ref) in outputs {
                    accessible.outputs[format] = ref
                }
                accessible.qaStatus = .pending
                await world.addComponent(entityId, accessible)

            } catch {
                await Logger.shared.error("BrailleExportSystem failed: \(error)", category: "Diaplasion")
            }
        }
    }

    /// Generate BRF (Braille Ready Format) file.
    /// BRF uses ASCII characters to represent braille cells for embossers.
    private func generateBRF(chunks: [BrailleChunk], to path: String) throws {
        var output = ""
        var currentLine = ""
        var lineCount = 0

        for chunk in chunks {
            // Add heading marker if needed
            if chunk.original.chunkType == .heading {
                // Flush current line
                if !currentLine.isEmpty {
                    output += currentLine + "\r\n"
                    currentLine = ""
                    lineCount += 1
                }
                // Add blank line before heading
                if lineCount > 0 {
                    output += "\r\n"
                    lineCount += 1
                }
            }

            // Word-wrap braille text to cells per line
            let words = chunk.brailleText.split(separator: " ")
            for word in words {
                let wordStr = String(word)

                if currentLine.isEmpty {
                    currentLine = wordStr
                } else if currentLine.count + 1 + wordStr.count <= configuration.cellsPerLine {
                    currentLine += " " + wordStr
                } else {
                    // Line is full, emit it
                    output += currentLine + "\r\n"
                    lineCount += 1
                    currentLine = wordStr

                    // Page break if needed
                    if lineCount >= configuration.linesPerPage {
                        output += "\u{0C}"  // Form feed for page break
                        lineCount = 0
                    }
                }
            }

            // Paragraph break
            if chunk.original.chunkType == .paragraph {
                if !currentLine.isEmpty {
                    output += currentLine + "\r\n"
                    currentLine = ""
                    lineCount += 1
                }
                output += "\r\n"  // Blank line between paragraphs
                lineCount += 1
            }
        }

        // Flush remaining content
        if !currentLine.isEmpty {
            output += currentLine + "\r\n"
        }

        try output.write(toFile: path, atomically: true, encoding: .ascii)
    }

    /// Generate PEF (Portable Embosser Format) file.
    /// PEF is an XML format for digital braille documents.
    private func generatePEF(chunks: [BrailleChunk], to path: String, requestId: String) throws {
        var pef = """
        <?xml version="1.0" encoding="UTF-8"?>
        <pef version="2008-1" xmlns="http://www.daisy.org/ns/2008/pef">
          <head>
            <meta xmlns:dc="http://purl.org/dc/elements/1.1/">
              <dc:identifier>\(requestId)</dc:identifier>
              <dc:format>application/x-pef+xml</dc:format>
              <dc:date>\(ISO8601DateFormatter().string(from: Date()))</dc:date>
            </meta>
          </head>
          <body>
            <volume cols="\(configuration.cellsPerLine)" rows="\(configuration.linesPerPage)" rowgap="0" duplex="true">
              <section>

        """

        var currentPage: [String] = []
        var currentRow = ""

        func emitPage() {
            if !currentRow.isEmpty {
                currentPage.append(currentRow)
                currentRow = ""
            }
            if !currentPage.isEmpty {
                pef += "        <page>\n"
                for row in currentPage {
                    // Convert braille ASCII to Unicode braille
                    let unicodeBraille = brailleASCIIToUnicode(row)
                    pef += "          <row>\(unicodeBraille)</row>\n"
                }
                pef += "        </page>\n"
                currentPage = []
            }
        }

        for chunk in chunks {
            let words = chunk.brailleText.split(separator: " ")
            for word in words {
                let wordStr = String(word)

                if currentRow.isEmpty {
                    currentRow = wordStr
                } else if currentRow.count + 1 + wordStr.count <= configuration.cellsPerLine {
                    currentRow += " " + wordStr
                } else {
                    currentPage.append(currentRow)
                    currentRow = wordStr

                    if currentPage.count >= configuration.linesPerPage {
                        emitPage()
                    }
                }
            }

            // Paragraph break
            if !currentRow.isEmpty {
                currentPage.append(currentRow)
                currentRow = ""
            }
            currentPage.append("")  // Blank line
        }

        emitPage()

        pef += """
              </section>
            </volume>
          </body>
        </pef>
        """

        try pef.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Convert North American Braille ASCII to Unicode braille characters.
    private func brailleASCIIToUnicode(_ ascii: String) -> String {
        // North American Braille ASCII to Unicode mapping
        let asciiToBraille: [Character: Character] = [
            " ": "\u{2800}", // Blank
            "A": "\u{2801}", "B": "\u{2803}", "C": "\u{2809}", "D": "\u{2819}",
            "E": "\u{2811}", "F": "\u{280B}", "G": "\u{281B}", "H": "\u{2813}",
            "I": "\u{280A}", "J": "\u{281A}", "K": "\u{2805}", "L": "\u{2807}",
            "M": "\u{280D}", "N": "\u{281D}", "O": "\u{2815}", "P": "\u{280F}",
            "Q": "\u{281F}", "R": "\u{2817}", "S": "\u{280E}", "T": "\u{281E}",
            "U": "\u{2825}", "V": "\u{2827}", "W": "\u{283A}", "X": "\u{282D}",
            "Y": "\u{283D}", "Z": "\u{2835}",
            "1": "\u{2801}", "2": "\u{2803}", "3": "\u{2809}", "4": "\u{2819}",
            "5": "\u{2811}", "6": "\u{280B}", "7": "\u{281B}", "8": "\u{2813}",
            "9": "\u{280A}", "0": "\u{281A}",
            ",": "\u{2802}", ";": "\u{2806}", ":": "\u{2812}", ".": "\u{2832}",
            "!": "\u{2816}", "?": "\u{2826}", "'": "\u{2804}", "-": "\u{2824}"
        ]

        return String(ascii.uppercased().map { asciiToBraille[$0] ?? $0 })
    }
}

/// Represents a chunk of text translated to braille.
private struct BrailleChunk {
    let original: TextChunk
    let brailleText: String
    let grade: BrailleExportSystem.BrailleGrade
}

/// Pure-Swift UEB (Unified English Braille) translator.
///
/// This implements a subset of UEB rules for basic text translation.
/// For full UEB compliance, consider liblouis integration.
///
/// ## Grade 1 (Uncontracted)
/// Direct letter-to-braille mapping with number and capital indicators.
///
/// ## Grade 2 (Contracted)
/// Includes 180+ contractions for common words and letter combinations.
/// This implementation covers the most common contractions.
private struct UEBTranslator {
    let grade: BrailleExportSystem.BrailleGrade

    // UEB letter representations in North American Braille ASCII
    private let letterMap: [Character: String] = [
        "a": "A", "b": "B", "c": "C", "d": "D", "e": "E",
        "f": "F", "g": "G", "h": "H", "i": "I", "j": "J",
        "k": "K", "l": "L", "m": "M", "n": "N", "o": "O",
        "p": "P", "q": "Q", "r": "R", "s": "S", "t": "T",
        "u": "U", "v": "V", "w": "W", "x": "X", "y": "Y", "z": "Z"
    ]

    // Number indicator (dots 3456)
    private let numberIndicator = "#"

    // Capital indicator (dot 6)
    private let capitalIndicator = ","

    // Numbers use same patterns as letters a-j
    private let numberMap: [Character: String] = [
        "1": "A", "2": "B", "3": "C", "4": "D", "5": "E",
        "6": "F", "7": "G", "8": "H", "9": "I", "0": "J"
    ]

    // Grade 2 whole-word contractions (most common)
    private let wholeWordContractions: [String: String] = [
        "but": "B", "can": "C", "do": "D", "every": "E",
        "from": "F", "go": "G", "have": "H", "just": "J",
        "knowledge": "K", "like": "L", "more": "M", "not": "N",
        "people": "P", "quite": "Q", "rather": "R", "so": "S",
        "that": "T", "us": "U", "very": "V", "will": "W",
        "it": "X", "you": "Y", "as": "Z",
        "and": "&", "for": "=", "of": "(", "the": "!",
        "with": ")", "child": "*", "shall": "%", "this": "?",
        "which": "<", "out": ">", "still": "/"
    ]

    // Grade 2 part-word contractions (letter combinations)
    private let partWordContractions: [String: String] = [
        "ing": "+", "tion": ";", "ness": ":", "ment": "!",
        "ound": "$", "ance": "@", "ence": "`", "ong": "\\",
        "ful": "]", "ity": "~", "ble": "}", "ght": "["
    ]

    func translate(_ text: String) -> String {
        var result = ""
        let words = text.components(separatedBy: .whitespaces)

        for (index, word) in words.enumerated() {
            if index > 0 { result += " " }
            result += translateWord(word)
        }

        return result
    }

    private func translateWord(_ word: String) -> String {
        // Skip empty words
        guard !word.isEmpty else { return "" }

        // Preserve punctuation at start and end
        var prefix = ""
        var suffix = ""
        var core = word

        while let first = core.first, !first.isLetter && !first.isNumber {
            prefix += translatePunctuation(first)
            core.removeFirst()
        }

        while let last = core.last, !last.isLetter && !last.isNumber {
            suffix = translatePunctuation(last) + suffix
            core.removeLast()
        }

        guard !core.isEmpty else { return prefix + suffix }

        // Check for whole-word contraction (Grade 2 only)
        if grade == .grade2 {
            if let contraction = wholeWordContractions[core.lowercased()] {
                let needsCap = core.first?.isUppercase ?? false
                return prefix + (needsCap ? capitalIndicator : "") + contraction + suffix
            }
        }

        // Translate character by character with contractions
        return prefix + translateCharacters(core) + suffix
    }

    private func translateCharacters(_ text: String) -> String {
        var result = ""
        var remaining = text.lowercased()
        var originalIndex = text.startIndex
        var inNumber = false

        while !remaining.isEmpty {
            var matched = false

            // Check for part-word contractions (Grade 2 only)
            if grade == .grade2 {
                for (pattern, contraction) in partWordContractions.sorted(by: { $0.key.count > $1.key.count }) {
                    if remaining.hasPrefix(pattern) {
                        result += contraction
                        remaining.removeFirst(pattern.count)
                        originalIndex = text.index(originalIndex, offsetBy: pattern.count)
                        matched = true
                        inNumber = false
                        break
                    }
                }
            }

            if !matched {
                let char = remaining.removeFirst()
                let originalChar = text[originalIndex]
                originalIndex = text.index(after: originalIndex)

                if char.isNumber {
                    if !inNumber {
                        result += numberIndicator
                        inNumber = true
                    }
                    result += numberMap[char] ?? String(char)
                } else if char.isLetter {
                    inNumber = false
                    if originalChar.isUppercase {
                        result += capitalIndicator
                    }
                    result += letterMap[char] ?? String(char)
                } else {
                    inNumber = false
                    result += translatePunctuation(char)
                }
            }
        }

        return result
    }

    private func translatePunctuation(_ char: Character) -> String {
        switch char {
        case ".": return "4"
        case ",": return "1"
        case ";": return "2"
        case ":": return "3"
        case "!": return "6"
        case "?": return "8"
        case "'", "\u{2018}", "\u{2019}": return "'"  // straight and curly apostrophes
        case "\"", "\u{201C}", "\u{201D}": return "7"  // straight and curly quotes
        case "(": return "9"
        case ")": return "0"
        case "-", "\u{2013}", "\u{2014}": return "-"  // hyphen, en-dash, em-dash
        case "/": return "_"
        case "@": return ".A"
        case "#": return ".N"
        case "$": return ".S"
        case "%": return ".P"
        case "&": return ".&"
        case "*": return ".*"
        default: return String(char)
        }
    }
}
