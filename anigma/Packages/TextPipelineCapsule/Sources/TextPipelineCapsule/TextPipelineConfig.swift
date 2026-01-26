import Foundation

public enum UnicodeForm: Int, Sendable, Codable {
    case none = 0
    case nfc = 1
    case nfd = 2
    case nfkc = 3
    case nfkd = 4
}

public enum CaseMode: Int, Sendable, Codable {
    case none = 0
    case lower = 1
    case upper = 2
    case title = 3
    case fold = 4
}

public enum DiacriticMode: Int, Sendable, Codable {
    case keep = 0
    case strip = 1
    case normalize = 2
}

public struct TextPipelineConfig: Sendable, Codable {
    public var unicodeForm: UnicodeForm
    public var caseMode: CaseMode
    public var diacriticMode: DiacriticMode
    public var preserveWhitespace: Bool
    public var preserveLineBreaks: Bool
    public var determinismTier: Int

    public init(
        unicodeForm: UnicodeForm = .nfkc,
        caseMode: CaseMode = .fold,
        diacriticMode: DiacriticMode = .keep,
        preserveWhitespace: Bool = true,
        preserveLineBreaks: Bool = true,
        determinismTier: Int = 1
    ) {
        self.unicodeForm = unicodeForm
        self.caseMode = caseMode
        self.diacriticMode = diacriticMode
        self.preserveWhitespace = preserveWhitespace
        self.preserveLineBreaks = preserveLineBreaks
        self.determinismTier = determinismTier
    }
}
