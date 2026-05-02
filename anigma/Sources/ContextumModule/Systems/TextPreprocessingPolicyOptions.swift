import Foundation
import CanonicalTokenizer

public enum TextPreprocessingPolicyConfigurationError: Error, LocalizedError, Equatable {
    case invalidPolicyJSON(String)
    case invalidSanitizerRulesJSON(String)
    case invalidEnvironmentValue(variable: String, value: String, allowed: [String])
    case invalidInteger(variable: String, value: String)
    case tokenizerHashEmpty
    case tokenizerMaxLengthOutOfRange(Int, allowed: ClosedRange<Int>)
    case invalidSanitizationRule(ruleID: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidPolicyJSON(let reason):
            return "Invalid preprocessing policy JSON: \(reason)"
        case .invalidSanitizerRulesJSON(let reason):
            return "Invalid sanitizer rules JSON: \(reason)"
        case .invalidEnvironmentValue(let variable, let value, let allowed):
            return "\(variable) has invalid value '\(value)'. Allowed: \(allowed.joined(separator: ", "))"
        case .invalidInteger(let variable, let value):
            return "\(variable) must be a valid integer, received '\(value)'"
        case .tokenizerHashEmpty:
            return "Tokenizer hash cannot be empty"
        case .tokenizerMaxLengthOutOfRange(let value, let allowed):
            return "Tokenizer maxLength \(value) is outside safe range \(allowed.lowerBound)...\(allowed.upperBound)"
        case .invalidSanitizationRule(let ruleID, let reason):
            return "Invalid sanitization rule '\(ruleID)': \(reason)"
        }
    }
}

public struct TextPreprocessingPolicyOptions: Sendable, Hashable, Codable {
    public struct TokenizerOptions: Sendable, Hashable, Codable {
        public var tokenizerHash: String?
        public var maxLength: Int?
        public var padding: PaddingStrategy?
        public var truncation: TruncationStrategy?

        public init(
            tokenizerHash: String? = nil,
            maxLength: Int? = nil,
            padding: PaddingStrategy? = nil,
            truncation: TruncationStrategy? = nil
        ) {
            self.tokenizerHash = tokenizerHash
            self.maxLength = maxLength
            self.padding = padding
            self.truncation = truncation
        }
    }

    public struct SanitizerOptions: Sendable, Hashable, Codable {
        public var rules: [TextSanitizationRule]?
        public var preserveParagraphBoundaries: Bool?

        public init(
            rules: [TextSanitizationRule]? = nil,
            preserveParagraphBoundaries: Bool? = nil
        ) {
            self.rules = rules
            self.preserveParagraphBoundaries = preserveParagraphBoundaries
        }
    }

    public var normalizationForm: UnicodeForm?
    public var boundaryType: BoundaryType?
    public var tokenizer: TokenizerOptions?
    public var sanitizer: SanitizerOptions?

    public init(
        normalizationForm: UnicodeForm? = nil,
        boundaryType: BoundaryType? = nil,
        tokenizer: TokenizerOptions? = nil,
        sanitizer: SanitizerOptions? = nil
    ) {
        self.normalizationForm = normalizationForm
        self.boundaryType = boundaryType
        self.tokenizer = tokenizer
        self.sanitizer = sanitizer
    }

    public static let safeTokenLengthRange = 1...8192

    public var isEmpty: Bool {
        normalizationForm == nil
            && boundaryType == nil
            && tokenizer == nil
            && sanitizer == nil
    }

    public func applying(
        to base: TextPreprocessingConfiguration = .ingestDefault
    ) throws -> TextPreprocessingConfiguration {
        guard !isEmpty else { return base }

        let effectiveNormalizationForm = normalizationForm ?? base.normalizationForm
        let effectiveBoundaryType = boundaryType ?? base.boundaryType

        var tokenizationPolicy = base.tokenizerPolicyConfiguration.tokenizationPolicy
        if let tokenizer {
            let tokenizerHash = try Self.validatedTokenizerHash(
                tokenizer.tokenizerHash ?? tokenizationPolicy.tokenizerHash
            )
            let maxLength = try Self.validatedTokenizerLength(
                tokenizer.maxLength ?? tokenizationPolicy.maxLength
            )
            tokenizationPolicy = TokenizationPolicy(
                tokenizerHash: tokenizerHash,
                maxLength: maxLength,
                padding: tokenizer.padding ?? tokenizationPolicy.padding,
                truncation: tokenizer.truncation ?? tokenizationPolicy.truncation
            )
        }

        var sanitizerPolicy = base.sanitizerPolicyConfiguration
        if let sanitizer {
            let rules = sanitizer.rules ?? sanitizerPolicy.rules
            try Self.validateSanitizationRules(rules)
            sanitizerPolicy = TextPreprocessingConfiguration.SanitizerPolicyConfiguration(
                rules: rules,
                preserveParagraphBoundaries: sanitizer.preserveParagraphBoundaries
                    ?? sanitizerPolicy.preserveParagraphBoundaries
            )
        }

        return TextPreprocessingConfiguration(
            normalizationForm: effectiveNormalizationForm,
            boundaryType: effectiveBoundaryType,
            tokenizerPolicyConfiguration: .init(tokenizationPolicy: tokenizationPolicy),
            sanitizerPolicyConfiguration: sanitizerPolicy
        )
    }

    public static func fromEnvironment(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> TextPreprocessingPolicyOptions {
        var options = TextPreprocessingPolicyOptions()

        if let json = environment[EnvironmentKeys.policyJSON],
           !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            options = try parsePolicyJSON(json)
        }

        if let value = environment[EnvironmentKeys.normalizationForm],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            options.normalizationForm = try parseNormalizationForm(
                value,
                variable: EnvironmentKeys.normalizationForm
            )
        }

        if let value = environment[EnvironmentKeys.boundaryType],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            options.boundaryType = try parseBoundaryType(
                value,
                variable: EnvironmentKeys.boundaryType
            )
        }

        var tokenizerOptions = options.tokenizer ?? .init()
        var tokenizerChanged = false
        if let value = environment[EnvironmentKeys.tokenizerHash] {
            tokenizerOptions.tokenizerHash = value
            tokenizerChanged = true
        }
        if let value = environment[EnvironmentKeys.tokenizerMaxLength] {
            guard let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw TextPreprocessingPolicyConfigurationError.invalidInteger(
                    variable: EnvironmentKeys.tokenizerMaxLength,
                    value: value
                )
            }
            tokenizerOptions.maxLength = parsed
            tokenizerChanged = true
        }
        if let value = environment[EnvironmentKeys.tokenizerPadding] {
            tokenizerOptions.padding = try parsePadding(
                value,
                variable: EnvironmentKeys.tokenizerPadding
            )
            tokenizerChanged = true
        }
        if let value = environment[EnvironmentKeys.tokenizerTruncation] {
            tokenizerOptions.truncation = try parseTruncation(
                value,
                variable: EnvironmentKeys.tokenizerTruncation
            )
            tokenizerChanged = true
        }
        if tokenizerChanged {
            options.tokenizer = tokenizerOptions
        }

        var sanitizerOptions = options.sanitizer ?? .init()
        var sanitizerChanged = false
        if let value = environment[EnvironmentKeys.sanitizerPreserveParagraphBoundaries] {
            sanitizerOptions.preserveParagraphBoundaries = try parseBoolean(
                value,
                variable: EnvironmentKeys.sanitizerPreserveParagraphBoundaries
            )
            sanitizerChanged = true
        }
        if let value = environment[EnvironmentKeys.sanitizerRulesJSON],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sanitizerOptions.rules = try parseRulesJSON(value)
            sanitizerChanged = true
        }
        if sanitizerChanged {
            options.sanitizer = sanitizerOptions
        }

        return options
    }

    private static func validatedTokenizerHash(_ hash: String) throws -> String {
        let trimmed = hash.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TextPreprocessingPolicyConfigurationError.tokenizerHashEmpty
        }
        return trimmed
    }

    private static func validatedTokenizerLength(_ length: Int) throws -> Int {
        guard safeTokenLengthRange.contains(length) else {
            throw TextPreprocessingPolicyConfigurationError.tokenizerMaxLengthOutOfRange(
                length,
                allowed: safeTokenLengthRange
            )
        }
        return length
    }

    private static func validateSanitizationRules(_ rules: [TextSanitizationRule]) throws {
        for rule in rules {
            let trimmedRuleID = rule.ruleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRuleID.isEmpty else {
                throw TextPreprocessingPolicyConfigurationError.invalidSanitizationRule(
                    ruleID: rule.ruleID,
                    reason: "ruleID cannot be empty"
                )
            }
            do {
                _ = try NSRegularExpression(pattern: rule.pattern)
            } catch {
                throw TextPreprocessingPolicyConfigurationError.invalidSanitizationRule(
                    ruleID: trimmedRuleID,
                    reason: "invalid regex pattern '\(rule.pattern)': \(error.localizedDescription)"
                )
            }
        }
    }
}

extension TextPreprocessingPolicyOptions {
    private enum EnvironmentKeys {
        static let policyJSON = "ANIGMA_TEXT_PREPROCESSING_POLICY_JSON"
        static let normalizationForm = "ANIGMA_TEXT_PREPROCESSING_NORMALIZATION_FORM"
        static let boundaryType = "ANIGMA_TEXT_PREPROCESSING_BOUNDARY_TYPE"
        static let tokenizerHash = "ANIGMA_TOKENIZER_HASH"
        static let tokenizerMaxLength = "ANIGMA_TOKENIZER_MAX_LENGTH"
        static let tokenizerPadding = "ANIGMA_TOKENIZER_PADDING"
        static let tokenizerTruncation = "ANIGMA_TOKENIZER_TRUNCATION"
        static let sanitizerPreserveParagraphBoundaries = "ANIGMA_SANITIZER_PRESERVE_PARAGRAPH_BOUNDARIES"
        static let sanitizerRulesJSON = "ANIGMA_SANITIZER_RULES_JSON"
    }

    private static func parsePolicyJSON(_ value: String) throws -> TextPreprocessingPolicyOptions {
        let data = Data(value.utf8)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(error.localizedDescription)
        }
        guard let dictionary = object as? [String: Any] else {
            throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                "Top-level JSON object must be a dictionary"
            )
        }

        var options = TextPreprocessingPolicyOptions()

        if let normalizationValue = Self.value(in: dictionary, keys: ["normalizationForm", "normalization_form"]) {
            guard let normalizationRaw = normalizationValue as? String else {
                throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                    "normalizationForm must be a string"
                )
            }
            options.normalizationForm = try parseNormalizationForm(
                normalizationRaw,
                variable: EnvironmentKeys.policyJSON
            )
        }

        if let boundaryValue = Self.value(in: dictionary, keys: ["boundaryType", "boundary_type"]) {
            guard let boundaryRaw = boundaryValue as? String else {
                throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                    "boundaryType must be a string"
                )
            }
            options.boundaryType = try parseBoundaryType(
                boundaryRaw,
                variable: EnvironmentKeys.policyJSON
            )
        }

        if let tokenizerValue = Self.value(in: dictionary, keys: ["tokenizer"]) {
            guard let tokenizerDict = tokenizerValue as? [String: Any] else {
                throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                    "tokenizer must be an object"
                )
            }
            options.tokenizer = try parseTokenizerDictionary(
                tokenizerDict,
                variable: EnvironmentKeys.policyJSON
            )
        }

        if let sanitizerValue = Self.value(in: dictionary, keys: ["sanitizer"]) {
            guard let sanitizerDict = sanitizerValue as? [String: Any] else {
                throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                    "sanitizer must be an object"
                )
            }
            options.sanitizer = try parseSanitizerDictionary(
                sanitizerDict
            )
        }

        return options
    }

    private static func parseTokenizerDictionary(
        _ dictionary: [String: Any],
        variable: String
    ) throws -> TokenizerOptions {
        var tokenizer = TokenizerOptions()

        if let rawHashValue = value(in: dictionary, keys: ["tokenizerHash", "tokenizer_hash"]) {
            guard let rawHash = rawHashValue as? String else {
                throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                    "tokenizer.tokenizerHash must be a string"
                )
            }
            tokenizer.tokenizerHash = rawHash
        }
        if let rawMaxLength = value(in: dictionary, keys: ["maxLength", "max_length"]) {
            guard let maxLength = intValue(rawMaxLength) else {
                throw TextPreprocessingPolicyConfigurationError.invalidInteger(
                    variable: variable,
                    value: String(describing: rawMaxLength)
                )
            }
            tokenizer.maxLength = maxLength
        }
        if let rawPaddingValue = value(in: dictionary, keys: ["padding"]) {
            guard let rawPadding = rawPaddingValue as? String else {
                throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                    "tokenizer.padding must be a string"
                )
            }
            tokenizer.padding = try parsePadding(rawPadding, variable: variable)
        }
        if let rawTruncationValue = value(in: dictionary, keys: ["truncation"]) {
            guard let rawTruncation = rawTruncationValue as? String else {
                throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                    "tokenizer.truncation must be a string"
                )
            }
            tokenizer.truncation = try parseTruncation(rawTruncation, variable: variable)
        }

        return tokenizer
    }

    private static func parseSanitizerDictionary(
        _ dictionary: [String: Any]
    ) throws -> SanitizerOptions {
        var sanitizer = SanitizerOptions()

        if let rawPreserve = value(in: dictionary, keys: ["preserveParagraphBoundaries", "preserve_paragraph_boundaries"]) {
            guard let preserve = boolValue(rawPreserve) else {
                throw TextPreprocessingPolicyConfigurationError.invalidPolicyJSON(
                    "sanitizer.preserveParagraphBoundaries must be a boolean"
                )
            }
            sanitizer.preserveParagraphBoundaries = preserve
        }

        if let rawRules = value(in: dictionary, keys: ["rules"]) {
            sanitizer.rules = try parseRules(rawRules)
        }

        return sanitizer
    }

    private static func parseRulesJSON(_ value: String) throws -> [TextSanitizationRule] {
        let data = Data(value.utf8)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TextPreprocessingPolicyConfigurationError.invalidSanitizerRulesJSON(error.localizedDescription)
        }
        return try parseRules(object)
    }

    private static func parseRules(_ value: Any) throws -> [TextSanitizationRule] {
        guard let items = value as? [[String: Any]] else {
            throw TextPreprocessingPolicyConfigurationError.invalidSanitizerRulesJSON(
                "Rules must be an array of objects"
            )
        }

        return try items.map { item in
            guard let pattern = item["pattern"] as? String else {
                throw TextPreprocessingPolicyConfigurationError.invalidSanitizerRulesJSON(
                    "Each rule requires a string 'pattern'"
                )
            }
            let replacement: String
            if let replacementValue = item["replacement"] {
                guard let replacementString = replacementValue as? String else {
                    throw TextPreprocessingPolicyConfigurationError.invalidSanitizerRulesJSON(
                        "Each rule 'replacement' must be a string"
                    )
                }
                replacement = replacementString
            } else {
                replacement = ""
            }
            guard let ruleID = (item["ruleID"] as? String)
                ?? (item["ruleId"] as? String)
                ?? (item["rule_id"] as? String) else {
                throw TextPreprocessingPolicyConfigurationError.invalidSanitizerRulesJSON(
                    "Each rule requires a string 'ruleID'"
                )
            }
            return TextSanitizationRule(ruleID: ruleID, pattern: pattern, replacement: replacement)
        }
    }

    private static func parseNormalizationForm(
        _ value: String,
        variable: String
    ) throws -> UnicodeForm {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "none": return .none
        case "nfc": return .nfc
        case "nfd": return .nfd
        case "nfkc": return .nfkc
        case "nfkd": return .nfkd
        default:
            throw TextPreprocessingPolicyConfigurationError.invalidEnvironmentValue(
                variable: variable,
                value: value,
                allowed: ["none", "nfc", "nfd", "nfkc", "nfkd"]
            )
        }
    }

    private static func parseBoundaryType(
        _ value: String,
        variable: String
    ) throws -> BoundaryType {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "character": return .character
        case "grapheme": return .grapheme
        case "word": return .word
        case "sentence": return .sentence
        case "line": return .line
        default:
            throw TextPreprocessingPolicyConfigurationError.invalidEnvironmentValue(
                variable: variable,
                value: value,
                allowed: ["character", "grapheme", "word", "sentence", "line"]
            )
        }
    }

    private static func parsePadding(
        _ value: String,
        variable: String
    ) throws -> PaddingStrategy {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "none":
            return .none
        case "max_length", "maxlength", "max-length":
            return .maxLength
        default:
            if normalized.hasPrefix("fixed:") {
                let rawLength = String(normalized.dropFirst("fixed:".count))
                guard let length = Int(rawLength) else {
                    throw TextPreprocessingPolicyConfigurationError.invalidInteger(
                        variable: variable,
                        value: value
                    )
                }
                _ = try validatedTokenizerLength(length)
                return .fixed(length)
            }
            throw TextPreprocessingPolicyConfigurationError.invalidEnvironmentValue(
                variable: variable,
                value: value,
                allowed: ["none", "max_length", "fixed:<n>"]
            )
        }
    }

    private static func parseTruncation(
        _ value: String,
        variable: String
    ) throws -> TruncationStrategy {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "none": return .none
        case "longest_first", "longestfirst": return .longestFirst
        case "only_first", "onlyfirst": return .onlyFirst
        case "only_second", "onlysecond": return .onlySecond
        default:
            throw TextPreprocessingPolicyConfigurationError.invalidEnvironmentValue(
                variable: variable,
                value: value,
                allowed: ["none", "longest_first", "only_first", "only_second"]
            )
        }
    }

    private static func parseBoolean(
        _ value: String,
        variable: String
    ) throws -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            throw TextPreprocessingPolicyConfigurationError.invalidEnvironmentValue(
                variable: variable,
                value: value,
                allowed: ["true", "false"]
            )
        }
    }

    private static func intValue(_ value: Any) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func boolValue(_ value: Any) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "on":
                return true
            case "0", "false", "no", "off":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private static func value(in dictionary: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = dictionary[key] {
                return value
            }
        }
        return nil
    }
}

public extension TextPreprocessingConfiguration {
    func applying(
        policyOptions: TextPreprocessingPolicyOptions
    ) throws -> TextPreprocessingConfiguration {
        try policyOptions.applying(to: self)
    }

    static func fromEnvironment(
        base: TextPreprocessingConfiguration = .ingestDefault,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> TextPreprocessingConfiguration {
        let options = try TextPreprocessingPolicyOptions.fromEnvironment(environment: environment)
        return try options.applying(to: base)
    }
}
