//
//  QueryExpander.swift
//  HarmoniaModule
//
//  Query expansion with synonym mapping, suggestions, and fuzzy matching.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import InferenceCore
import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation

/// Expanded query result
public struct ExpandedQuery: Sendable, Codable {
    /// Original query
    public let original: String

    /// Expanded query terms
    public let expanded: [String]

    /// Synonym suggestions
    public let synonyms: [QuerySynonym]

    /// Related search suggestions
    public let suggestions: [String]

    /// Fuzzy matches for typos
    public let fuzzyMatches: [FuzzyMatch]

    /// Query interpretation confidence
    public let confidence: Double

    public init(
        original: String,
        expanded: [String],
        synonyms: [QuerySynonym],
        suggestions: [String],
        fuzzyMatches: [FuzzyMatch],
        confidence: Double
    ) {
        self.original = original
        self.expanded = expanded
        self.synonyms = synonyms
        self.suggestions = suggestions
        self.fuzzyMatches = fuzzyMatches
        self.confidence = confidence
    }
}

/// Query synonym
public struct QuerySynonym: Sendable, Codable {
    public let term: String
    public let synonyms: [String]
    public let context: String  // e.g., "programming", "data", "build"
    public let frequency: Int

    public init(
        term: String,
        synonyms: [String],
        context: String,
        frequency: Int
    ) {
        self.term = term
        self.synonyms = synonyms
        self.context = context
        self.frequency = frequency
    }
}

/// Fuzzy match for potential typos
public struct FuzzyMatch: Sendable, Codable {
    public let original: String
    public let suggested: String
    public let similarity: Double  // 0-1

    public init(
        original: String,
        suggested: String,
        similarity: Double
    ) {
        self.original = original
        self.suggested = suggested
        self.similarity = similarity
    }
}

/// Query expansion with learned term mappings
public actor QueryExpander {
    private let dbActor: (any DatabaseAuthority)?
    private var schemaInitialized = false
    private let commonSynonyms: [String: [String]] = [
        "build": ["compile", "assemble", "construct", "make"],
        "test": ["check", "validate", "verify", "trial"],
        "debug": ["troubleshoot", "diagnose", "fix", "error"],
        "optimize": ["improve", "enhance", "accelerate", "performance"],
        "error": ["failure", "bug", "issue", "problem"],
        "warning": ["caution", "alert", "notice"],
        "cache": ["store", "buffer", "temporary"],
        "search": ["query", "find", "lookup", "seek"],
        "performance": ["speed", "efficiency", "latency", "throughput"]
    ]

    public init(dbActor: (any DatabaseAuthority)? = nil) {
        self.dbActor = dbActor
    }

    /// Expand a search query
    public func expandQuery(_ query: String) async throws -> ExpandedQuery {
        try await ensureSchema()
        let tokens = tokenize(query)
        var expanded = tokens
        var synonyms: [QuerySynonym] = []
        var suggestions: [String] = []
        var fuzzyMatches: [FuzzyMatch] = []

        // Process each token
        for token in tokens {
            // Find synonyms
            let tokenSynonyms = await findSynonyms(for: token)
            if !tokenSynonyms.isEmpty {
                expanded.append(contentsOf: tokenSynonyms.map { $0.synonyms }.flatMap { $0 })
                synonyms.append(contentsOf: tokenSynonyms)
            }

            // Find fuzzy matches for potential typos
            let fuzzy = findFuzzyMatches(for: token)
            fuzzyMatches.append(contentsOf: fuzzy)
        }

        // Generate related suggestions
        suggestions = await generateSuggestions(from: tokens)

        // Remove duplicates
        expanded = Array(Set(expanded))
        suggestions = Array(Set(suggestions))

        // Calculate confidence based on expansion coverage
        let confidence = min(1.0, Double(expanded.count) / Double(tokens.count))

        return ExpandedQuery(
            original: query,
            expanded: expanded,
            synonyms: synonyms,
            suggestions: suggestions,
            fuzzyMatches: fuzzyMatches,
            confidence: confidence
        )
    }

    /// Learn new term mapping from successful search
    public func learnTermMapping(
        originalTerm: String,
        successfulAlternative: String,
        context: String
    ) async throws {
        try await ensureSchema()
        guard let db = dbActor else { return }

        let timestamp = Int(Date().timeIntervalSince1970)

        try await db.execute(
            """
            INSERT OR REPLACE INTO term_mappings (id, original_term, alternative_term, context, frequency, learned_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(UUID().uuidString),
                .text(originalTerm),
                .text(successfulAlternative),
                .text(context),
                .int(1),
                .int(timestamp)
            ]
        )
    }

    /// Get learned term mappings
    public func getLearnedMappings() async throws -> [String: [String]] {
        try await ensureSchema()
        guard let db = dbActor else { return [:] }

        let rows = try await db.executeQuery(
            """
            SELECT original_term, GROUP_CONCAT(alternative_term, ',') as alternatives
            FROM term_mappings
            GROUP BY original_term
            """
        )

        var mappings: [String: [String]] = [:]

        for row in rows {
            guard let originalTerm = row.string(for: "original_term"),
                  let alternativesStr = row.string(for: "alternatives") else {
                continue
            }

            let alternatives = alternativesStr.split(separator: ",").map(String.init)
            mappings[originalTerm] = alternatives
        }

        return mappings
    }

    /// Find synonyms for a term
    private func findSynonyms(for term: String) async -> [QuerySynonym] {
        var results: [QuerySynonym] = []

        // Check built-in synonyms
        if let builtInSynonyms = commonSynonyms[term.lowercased()] {
            results.append(QuerySynonym(
                term: term,
                synonyms: builtInSynonyms,
                context: "general",
                frequency: 10
            ))
        }

        // Check learned mappings
        guard let db = dbActor else { return results }

        let rows = try? await db.executeQuery(
            """
            SELECT DISTINCT alternative_term, context, COUNT(*) as frequency
            FROM term_mappings
            WHERE original_term = ?
            GROUP BY alternative_term, context
            """,
            parameters: [.text(term.lowercased())]
        )

        if let rows = rows {
            for row in rows {
                guard let altTerm = row.string(for: "alternative_term"),
                      let context = row.string(for: "context"),
                      let frequency = row.int(for: "frequency") else {
                    continue
                }

                results.append(QuerySynonym(
                    term: term,
                    synonyms: [altTerm],
                    context: context,
                    frequency: frequency
                ))
            }
        }

        return results
    }

    /// Find fuzzy matches (potential typos)
    private func findFuzzyMatches(for term: String) -> [FuzzyMatch] {
        var matches: [FuzzyMatch] = []

        // Check against common terms
        let commonTerms = Array(commonSynonyms.keys)

        for commonTerm in commonTerms {
            let similarity = levenshteinSimilarity(term.lowercased(), commonTerm.lowercased())
            if similarity > 0.75 && similarity < 1.0 {
                matches.append(FuzzyMatch(
                    original: term,
                    suggested: commonTerm,
                    similarity: similarity
                ))
            }
        }

        // Sort by similarity descending
        matches.sort { $0.similarity > $1.similarity }

        return matches.prefix(3).map { $0 }
    }

    /// Generate related search suggestions
    private func generateSuggestions(from tokens: [String]) async -> [String] {
        var suggestions: [String] = []

        // Common search patterns
        let patterns = [
            "recent \(tokens.joined(separator: " "))",
            "most \(tokens.joined(separator: " "))",
            "\(tokens.joined(separator: " ")) in last week",
            "\(tokens.joined(separator: " ")) by priority"
        ]

        suggestions.append(contentsOf: patterns)

        // Combine with synonyms
        if tokens.count > 1 {
            let firstToken = tokens[0]
            let restTokens = Array(tokens.dropFirst())

            if let synonyms = commonSynonyms[firstToken.lowercased()] {
                for synonym in synonyms {
                    let suggestion = [synonym] + restTokens
                    suggestions.append(suggestion.joined(separator: " "))
                }
            }
        }

        return Array(Set(suggestions))
    }

    /// Tokenize query string
    private func tokenize(_ query: String) -> [String] {
        return query.split(separator: " ").map(String.init)
    }

    /// Compute Levenshtein similarity (0-1)
    private func levenshteinSimilarity(_ a: String, _ b: String) -> Double {
        let maxLength = max(a.count, b.count)
        guard maxLength > 0 else { return 1.0 }

        let distance = levenshteinDistance(a, b)
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Compute Levenshtein distance
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let aCount = aChars.count
        let bCount = bChars.count

        if aCount == 0 { return bCount }
        if bCount == 0 { return aCount }

        var matrix = Array(repeating: Array(repeating: 0, count: bCount + 1), count: aCount + 1)

        for i in 0...aCount {
            matrix[i][0] = i
        }
        for j in 0...bCount {
            matrix[0][j] = j
        }

        for i in 1...aCount {
            for j in 1...bCount {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[aCount][bCount]
    }

    private func ensureSchema() async throws {
        guard let db = dbActor else { return }
        if !schemaInitialized {
            try await SearchSchema.apply(using: db)
            schemaInitialized = true
        }
    }
}
