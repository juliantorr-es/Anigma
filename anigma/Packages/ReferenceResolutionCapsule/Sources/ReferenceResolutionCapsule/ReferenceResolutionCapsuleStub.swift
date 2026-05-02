import Foundation
import CapsuleCore
import TelemetryCore
import CitationExtractionCapsule

public enum MatchStatus: Int32, Codable, Hashable, Sendable {
    case matched = 0
    case unmatched = 1
    case partiallyMatched = 2
    case failed = 3
}

public struct ResolvedReference: Codable, Hashable, Sendable {
    public var originalID: String
    public var doi: String?
    public var pubmedID: String?
    public var crossrefID: String?
    public var title: String
    public var authors: String
    public var year: String?
    public var journal: String?
    public var volume: String?
    public var issue: String?
    public var pages: String?
    public var confidence: Double
    public var matchStatus: MatchStatus

    public init(
        originalID: String,
        doi: String? = nil,
        pubmedID: String? = nil,
        crossrefID: String? = nil,
        title: String,
        authors: String,
        year: String? = nil,
        journal: String? = nil,
        volume: String? = nil,
        issue: String? = nil,
        pages: String? = nil,
        confidence: Double = 1.0,
        matchStatus: MatchStatus = .matched
    ) {
        self.originalID = originalID
        self.doi = doi
        self.pubmedID = pubmedID
        self.crossrefID = crossrefID
        self.title = title
        self.authors = authors
        self.year = year
        self.journal = journal
        self.volume = volume
        self.issue = issue
        self.pages = pages
        self.confidence = confidence
        self.matchStatus = matchStatus
    }
}

public struct ReferenceResolutionResult: Codable, Hashable, Sendable {
    public var resolvedReferences: [ResolvedReference]
    public var unresolvedReferences: [CitationReference]
    public var processingTime: UInt64

    public var processingTimeUs: UInt64 {
        processingTime
    }

    public init(
        resolvedReferences: [ResolvedReference],
        unresolvedReferences: [CitationReference],
        processingTime: UInt64 = 0
    ) {
        self.resolvedReferences = resolvedReferences
        self.unresolvedReferences = unresolvedReferences
        self.processingTime = processingTime
    }

    public init(
        resolvedReferences: [ResolvedReference],
        unresolvedReferences: [CitationReference],
        processingTimeUs: UInt64
    ) {
        self.init(
            resolvedReferences: resolvedReferences,
            unresolvedReferences: unresolvedReferences,
            processingTime: processingTimeUs
        )
    }
}

public struct ReferenceResolutionConfig: Codable, Hashable, Sendable {
    public var enableOnlineLookup: Bool = false
    public var enableFuzzyMatching: Bool = true
    public var fuzzyThreshold: Double = 0.8
    public var enableCaching: Bool = true
    public var cacheDir: String? = nil
    public var crossrefEndpoint: String? = nil
    public var pubmedEndpoint: String? = nil

    public static var `default`: ReferenceResolutionConfig {
        ReferenceResolutionConfig()
    }

    public init() {}
}

public actor ReferenceResolutionCapsule: IdentifiableCapsule {
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "reference-resolution-stub-v1"

    public init(
        config: ReferenceResolutionConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        _ = config
    }

    public func resolve(references: [CitationReference]) throws -> ReferenceResolutionResult {
        diagnostics.event(
            level: .debug,
            category: "referenceresolution.stub.resolve",
            message: "Reference resolution stub returned unresolved references",
            correlationID: nil,
            metadata: [
                "references": "\(references.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )

        return ReferenceResolutionResult(
            resolvedReferences: [],
            unresolvedReferences: references,
            processingTime: 0
        )
    }

    public func exportToBibTeX(reference: ResolvedReference) throws -> String {
        "@misc{\(reference.originalID), title={\(reference.title)}}"
    }

    public func exportToJSON(reference: ResolvedReference) throws -> String {
        let data = try JSONEncoder().encode(reference)
        return String(decoding: data, as: UTF8.self)
    }
}
