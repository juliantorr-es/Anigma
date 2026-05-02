import Foundation

public enum ContextSanitizer {
    public struct Rule: Sendable, Hashable {
        public let ruleID: String
        public let pattern: String
        public let replacement: String

        public init(ruleID: String, pattern: String, replacement: String) {
            self.ruleID = ruleID
            self.pattern = pattern
            self.replacement = replacement
        }
    }

    public struct StorageConfiguration: Sendable, Hashable {
        public let rules: [Rule]
        public let preserveParagraphBoundaries: Bool

        public init(rules: [Rule] = [], preserveParagraphBoundaries: Bool = true) {
            self.rules = rules
            self.preserveParagraphBoundaries = preserveParagraphBoundaries
        }

        public static var ingestDefault: StorageConfiguration {
            StorageConfiguration(rules: [], preserveParagraphBoundaries: true)
        }
    }

    public static func sanitizeForStorage(
        _ text: String,
        configuration: StorageConfiguration = .ingestDefault
    ) -> String {
        var result = text.replacingOccurrences(of: "\0", with: "")
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")

        for rule in configuration.rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            let fullRange = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: fullRange, withTemplate: rule.replacement)
        }

        if configuration.preserveParagraphBoundaries {
            let lines = result.components(separatedBy: "\n")
            result = lines.map { line in
                let tabNormalized = line.replacingOccurrences(of: "\t", with: " ")
                return collapseSpaceRuns(tabNormalized).trimmingCharacters(in: .whitespaces)
            }.joined(separator: "\n")
        } else {
            let flattened = result
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
            result = collapseSpaceRuns(flattened).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func sanitizeProvenanceField(
        _ value: String?,
        fallback: String,
        maxLength: Int
    ) -> String {
        guard let value else { return fallback }

        var sanitized = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")

        sanitized = sanitized.unicodeScalars.map { scalar in
            CharacterSet.controlCharacters.contains(scalar) ? " " : String(scalar)
        }.joined()
        sanitized = sanitized
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else { return fallback }
        return String(sanitized.prefix(max(0, maxLength)))
    }

    private static func collapseSpaceRuns(_ value: String) -> String {
        value.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
    }
}

public enum ContextTokenizer {
    public static func words(in text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    public static func tokenCount(in text: String, policy: TokenizationPolicy) -> Int {
        guard !text.isEmpty else { return 0 }
        let tokenizer = SimpleWordTokenizer(policy: policy)
        return (try? tokenizer.tokenize(text: text).count) ?? words(in: text).count
    }
}
