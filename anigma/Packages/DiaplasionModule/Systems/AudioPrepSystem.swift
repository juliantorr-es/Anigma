//
//  AudioPrepSystem.swift
//  DiaplasionModule
//
//  Extracted from DiaplasionSystems.swift
//  System that prepares text for audio/TTS output with SSML markup.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Audio Prep System

/// System that prepares text for audio/TTS output with SSML markup.
public struct AudioPrepSystem: System {
    public var name: String { "AudioPrep" }

    /// Configuration for audio preparation
    public struct Configuration: Sendable {
        /// Pause duration after paragraphs (in seconds)
        public let paragraphPause: Double
        /// Pause duration after headings (in seconds)
        public let headingPause: Double
        /// Pause duration after sentences (in seconds)
        public let sentencePause: Double
        /// Speaking rate adjustment for headings (1.0 = normal)
        public let headingRate: Double
        /// Output directory for SSML files
        public let outputDirectory: String?
        /// Whether to generate plain text alongside SSML
        public let generatePlainText: Bool

        public init(
            paragraphPause: Double = 0.8,
            headingPause: Double = 1.2,
            sentencePause: Double = 0.3,
            headingRate: Double = 0.9,
            outputDirectory: String? = nil,
            generatePlainText: Bool = true
        ) {
            self.paragraphPause = paragraphPause
            self.headingPause = headingPause
            self.sentencePause = sentencePause
            self.headingRate = headingRate
            self.outputDirectory = outputDirectory
            self.generatePlainText = generatePlainText
        }
    }

    private let configuration: Configuration
    private let normalizer: TextNormalizer

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.normalizer = TextNormalizer()
    }

    public func update(world: World) async {
        let entities = await world.allEntities()

        for entityId in entities {
            guard let chunked = await world.getComponent(entityId, ChunkedTextComponent.self),
                  let request = await world.getComponent(entityId, TransformRequestComponent.self),
                  request.targetFormats.contains(.audioReady),
                  request.status == .processing else {
                continue
            }

            logDebug("AudioPrepSystem processing entity \(entityId)", category: "Diaplasion")

            do {
                // Determine output directory
                let outputDir = configuration.outputDirectory ?? FileManager.default.temporaryDirectory
                    .appendingPathComponent("audio_\(UUID().uuidString)")
                    .path
                try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

                // Generate SSML
                let ssmlPath = (outputDir as NSString).appendingPathComponent("\(request.requestId).ssml")
                let ssml = generateSSML(chunks: chunked.chunks, requestId: request.requestId)
                try ssml.write(toFile: ssmlPath, atomically: true, encoding: .utf8)

                var outputs: [OutputFormat: OutputReference] = [:]

                let fileSize = (try? FileManager.default.attributesOfItem(atPath: ssmlPath)[.size] as? Int64) ?? 0
                outputs[.audioReady] = OutputReference(
                    format: .audioReady,
                    uri: ssmlPath,
                    fileSize: fileSize
                )

                logInfo("Generated SSML: \(ssmlPath)", category: "Diaplasion")

                // Generate plain text if requested
                if configuration.generatePlainText {
                    let textPath = (outputDir as NSString).appendingPathComponent("\(request.requestId)_audio.txt")
                    let plainText = generatePlainText(chunks: chunked.chunks)
                    try plainText.write(toFile: textPath, atomically: true, encoding: .utf8)

                    logDebug("Generated plain text: \(textPath)", category: "Diaplasion")
                }

                // Generate chapter manifest for audiobook tools
                let manifestPath = (outputDir as NSString).appendingPathComponent("\(request.requestId)_chapters.json")
                let manifest = generateChapterManifest(chunks: chunked.chunks, requestId: request.requestId)
                try manifest.write(toFile: manifestPath, atomically: true, encoding: .utf8)

                // Update or create AccessibleOutputComponent
                var accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
                    ?? AccessibleOutputComponent()
                for (format, ref) in outputs {
                    accessible.outputs[format] = ref
                }
                accessible.qaStatus = .pending
                await world.addComponent(entityId, accessible)

            } catch {
                logError("AudioPrepSystem failed: \(error)", category: "Diaplasion")
            }
        }
    }

    /// Generate SSML with prosody hints for natural TTS output.
    private func generateSSML(chunks: [TextChunk], requestId: String) -> String {
        var ssml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <speak version="1.1" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">

        """

        var chapterNumber = 0

        for chunk in chunks {
            let normalizedText = normalizer.normalize(chunk.text)
            let escapedText = escapeXML(normalizedText)

            switch chunk.chunkType {
            case .heading:
                chapterNumber += 1
                // Heading: slower rate, higher emphasis, longer pause after
                ssml += """
                  <mark name="chapter\(chapterNumber)"/>
                  <prosody rate="\(Int(configuration.headingRate * 100))%" pitch="+5%">
                    <emphasis level="strong">\(escapedText)</emphasis>
                  </prosody>
                  <break time="\(Int(configuration.headingPause * 1000))ms"/>

                """

            case .paragraph:
                // Normal paragraph with sentence-level structure
                let sentences = splitIntoSentences(escapedText)
                ssml += "  <p>\n"
                for sentence in sentences {
                    ssml += "    <s>\(sentence)</s>\n"
                }
                ssml += "  </p>\n"
                ssml += "  <break time=\"\(Int(configuration.paragraphPause * 1000))ms\"/>\n"

            case .listItem:
                // List items with slight pause before
                ssml += "  <break time=\"200ms\"/>\n"
                ssml += "  <s>\(escapedText)</s>\n"

            case .quote:
                // Quotes with slight pitch change to indicate quotation
                ssml += """
                  <prosody pitch="-2%">
                    <p>\(escapedText)</p>
                  </prosody>
                  <break time="\(Int(configuration.paragraphPause * 1000))ms"/>

                """

            case .caption, .footnote:
                // Captions and footnotes: slightly faster, lower volume
                ssml += """
                  <prosody rate="105%" volume="-2dB">
                    <s>\(escapedText)</s>
                  </prosody>
                  <break time="300ms"/>

                """

            default:
                // Default handling
                ssml += "  <s>\(escapedText)</s>\n"
                ssml += "  <break time=\"\(Int(configuration.sentencePause * 1000))ms\"/>\n"
            }
        }

        ssml += "</speak>\n"
        return ssml
    }

    /// Generate plain text suitable for TTS engines that don't support SSML.
    private func generatePlainText(chunks: [TextChunk]) -> String {
        var text = ""

        for chunk in chunks {
            let normalized = normalizer.normalize(chunk.text)

            switch chunk.chunkType {
            case .heading:
                // Double newline before headings
                if !text.isEmpty { text += "\n\n" }
                text += normalized + "\n\n"

            case .paragraph:
                text += normalized + "\n\n"

            case .listItem:
                text += "• " + normalized + "\n"

            default:
                text += normalized + "\n"
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate a JSON chapter manifest for audiobook generation tools.
    private func generateChapterManifest(chunks: [TextChunk], requestId: String) -> String {
        var chapters: [[String: Any]] = []
        var currentChapter: [String: Any]?
        var chunkIndex = 0

        for chunk in chunks {
            if chunk.chunkType == .heading {
                // Save previous chapter if exists
                if let chapter = currentChapter {
                    chapters.append(chapter)
                }
                // Start new chapter
                currentChapter = [
                    "title": chunk.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    "startChunkIndex": chunkIndex
                ]
            }
            chunkIndex += 1
        }

        // Save final chapter
        if let chapter = currentChapter {
            chapters.append(chapter)
        }

        // If no chapters found, create a single chapter
        if chapters.isEmpty {
            chapters.append([
                "title": "Content",
                "startChunkIndex": 0
            ])
        }

        let manifest: [String: Any] = [
            "requestId": requestId,
            "chapterCount": chapters.count,
            "totalChunks": chunks.count,
            "chapters": chapters
        ]

        // Manual JSON serialization to avoid JSONSerialization issues with Any
        return serializeManifest(manifest)
    }

    private func serializeManifest(_ manifest: [String: Any]) -> String {
        var json = "{\n"
        json += "  \"requestId\": \"\(manifest["requestId"] as? String ?? "")\",\n"
        json += "  \"chapterCount\": \(manifest["chapterCount"] as? Int ?? 0),\n"
        json += "  \"totalChunks\": \(manifest["totalChunks"] as? Int ?? 0),\n"
        json += "  \"chapters\": [\n"

        if let chapters = manifest["chapters"] as? [[String: Any]] {
            for (index, chapter) in chapters.enumerated() {
                let title = (chapter["title"] as? String ?? "").replacingOccurrences(of: "\"", with: "\\\"")
                let startIndex = chapter["startChunkIndex"] as? Int ?? 0
                json += "    {\"title\": \"\(title)\", \"startChunkIndex\": \(startIndex)}"
                if index < chapters.count - 1 { json += "," }
                json += "\n"
            }
        }

        json += "  ]\n"
        json += "}\n"
        return json
    }

    /// Split text into sentences for SSML <s> elements.
    private func splitIntoSentences(_ text: String) -> [String] {
        // Simple sentence splitting on . ! ? followed by space or end
        let pattern = #"[.!?]+[\s]+|[.!?]+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [text]
        }

        var sentences: [String] = []
        var lastEnd = text.startIndex

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        for match in matches {
            if let range = Range(match.range, in: text) {
                let sentenceEnd = range.upperBound
                let sentence = String(text[lastEnd..<sentenceEnd]).trimmingCharacters(in: .whitespaces)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                lastEnd = sentenceEnd
            }
        }

        // Add remaining text
        if lastEnd < text.endIndex {
            let remaining = String(text[lastEnd...]).trimmingCharacters(in: .whitespaces)
            if !remaining.isEmpty {
                sentences.append(remaining)
            }
        }

        return sentences.isEmpty ? [text] : sentences
    }

    /// Escape XML special characters.
    private func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

/// Text normalizer for TTS preparation.
///
/// Converts numbers, abbreviations, and symbols to spoken forms
/// for more natural text-to-speech output.
private struct TextNormalizer {

    // Common abbreviations
    private let abbreviations: [String: String] = [
        "Dr.": "Doctor",
        "Mr.": "Mister",
        "Mrs.": "Missus",
        "Ms.": "Miss",
        "Jr.": "Junior",
        "Sr.": "Senior",
        "St.": "Saint",
        "Ave.": "Avenue",
        "Blvd.": "Boulevard",
        "Rd.": "Road",
        "etc.": "etcetera",
        "e.g.": "for example",
        "i.e.": "that is",
        "vs.": "versus",
        "Prof.": "Professor",
        "Inc.": "Incorporated",
        "Ltd.": "Limited",
        "Corp.": "Corporation",
        "Dept.": "Department",
        "approx.": "approximately",
        "govt.": "government"
    ]

    // Symbols to spoken form
    private let symbols: [String: String] = [
        "@": " at ",
        "&": " and ",
        "%": " percent",
        "$": " dollars",
        "€": " euros",
        "£": " pounds",
        "¥": " yen",
        "+": " plus ",
        "=": " equals ",
        "#": " number ",
        "©": " copyright ",
        "®": " registered ",
        "™": " trademark "
    ]

    func normalize(_ text: String) -> String {
        var result = text

        // Expand abbreviations
        for (abbrev, expansion) in abbreviations {
            result = result.replacingOccurrences(of: abbrev, with: expansion)
        }

        // Replace symbols
        for (symbol, spoken) in symbols {
            result = result.replacingOccurrences(of: symbol, with: spoken)
        }

        // Normalize numbers in text
        result = normalizeNumbers(result)

        // Clean up multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Convert numbers to spoken form.
    private func normalizeNumbers(_ text: String) -> String {
        // Match standalone numbers (not part of words)
        let pattern = #"\b(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        var result = text
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange).reversed()

        for match in matches {
            if let range = Range(match.range, in: result) {
                let numberStr = String(result[range]).replacingOccurrences(of: ",", with: "")
                if let number = Double(numberStr) {
                    let spoken = numberToWords(number)
                    result.replaceSubrange(range, with: spoken)
                }
            }
        }

        return result
    }

    /// Convert a number to spoken words.
    private func numberToWords(_ number: Double) -> String {
        // Handle decimals
        if number != floor(number) {
            let intPart = Int(number)
            let decimalPart = String(format: "%.2f", number).split(separator: ".").last ?? ""
            return "\(numberToWords(Double(intPart))) point \(String(decimalPart).map { String($0) }.joined(separator: " "))"
        }

        let n = Int(number)

        if n == 0 { return "zero" }
        if n < 0 { return "negative \(numberToWords(Double(-n)))" }

        let ones = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                   "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
                   "seventeen", "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

        if n < 20 {
            return ones[n]
        } else if n < 100 {
            let remainder = n % 10
            return tens[n / 10] + (remainder > 0 ? "-\(ones[remainder])" : "")
        } else if n < 1000 {
            let remainder = n % 100
            return "\(ones[n / 100]) hundred" + (remainder > 0 ? " \(numberToWords(Double(remainder)))" : "")
        } else if n < 1_000_000 {
            let thousands = n / 1000
            let remainder = n % 1000
            return "\(numberToWords(Double(thousands))) thousand" + (remainder > 0 ? " \(numberToWords(Double(remainder)))" : "")
        } else if n < 1_000_000_000 {
            let millions = n / 1_000_000
            let remainder = n % 1_000_000
            return "\(numberToWords(Double(millions))) million" + (remainder > 0 ? " \(numberToWords(Double(remainder)))" : "")
        } else {
            // For very large numbers, just read digits
            return String(n).map { String($0) }.joined(separator: " ")
        }
    }
}
