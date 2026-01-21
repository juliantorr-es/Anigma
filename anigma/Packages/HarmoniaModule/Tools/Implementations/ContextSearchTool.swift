//
//  ContextSearchTool.swift
//  HarmoniaModule
//
//  Context-aware semantic search across indexed codebase content.
//

import AnigmaPrimitives
import DatabaseCore
import Foundation

public struct ContextSearchTool: Sendable {
    private let dbPath: String

    public init(dbPath: String? = nil) {
        self.dbPath = dbPath ?? Self.defaultDatabasePath()
    }

    public func execute(_ request: ToolCallRequest, session: SessionContext) async
        -> ToolCallResponse {
        let paramsData = Data(request.parameters.utf8)
        let parameters =
            (try? JSONSerialization.jsonObject(with: paramsData) as? [String: Any]) ?? [:]

        guard let query = parameters["query"] as? String, !query.isEmpty else {
            return ToolCallResponse(
                status: .failed,
                toolName: request.toolName,
                diagnosis: "Missing required parameter: query"
            )
        }

        let limit = parameters["limit"] as? Int ?? 10
        let safeLimit = max(0, limit)

        let db = DatabaseActor(dbPath: dbPath)
        let queryExpander = QueryExpander(dbActor: db)
        let analytics = SearchAnalytics(dbActor: db)
        let ranker = ResultRanker(dbActor: db)
        let semanticSearch = SemanticCodebaseSearch(dbActor: db)

        do {
            let expanded = try await queryExpander.expandQuery(query)
            let searchQuery = expanded.expanded.isEmpty
                ? query
                : expanded.expanded.joined(separator: " ")

            let rawResults = try await semanticSearch.search(query: searchQuery)
            let limitedResults = Array(rawResults.prefix(safeLimit))

            let rankInputs = limitedResults.map { result in
                SearchResultInput(
                    resultId: result.filePath,
                    text: result.fileDescription.isEmpty ? result.matchReason : result.fileDescription,
                    createdAt: Date(),
                    semanticScore: result.relevanceScore
                )
            }

            let ranked: [RankedResult]
            if rankInputs.isEmpty {
                ranked = []
            } else {
                ranked = try await ranker.rankResults(
                    results: rankInputs,
                    query: query,
                    userId: session.sessionId
                )
            }

            let resultById = Dictionary(uniqueKeysWithValues: limitedResults.map { ($0.filePath, $0) })

            let responseResults: [ContextSearchResult] = ranked.map { rankedResult in
                let raw = resultById[rankedResult.resultId]
                return ContextSearchResult(
                    filePath: rankedResult.resultId,
                    description: raw?.fileDescription ?? rankedResult.description,
                    matchReason: raw?.matchReason ?? rankedResult.rankingReason,
                    relevanceScore: raw?.relevanceScore ?? rankedResult.overallScore,
                    rankingScore: rankedResult.overallScore,
                    rankingReason: rankedResult.rankingReason,
                    matchingSymbols: raw?.matchingSymbols ?? [],
                    summary: raw?.summary
                )
            }

            let queryId = try await analytics.recordQuery(
                query: query,
                userId: session.sessionId,
                resultCount: responseResults.count
            )

            let response = ContextSearchResponse(
                query: query,
                expandedTerms: expanded.expanded,
                synonyms: expanded.synonyms,
                suggestions: expanded.suggestions,
                fuzzyMatches: expanded.fuzzyMatches,
                confidence: expanded.confidence,
                queryId: queryId,
                results: responseResults
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let resultData = try encoder.encode(response)

            return ToolCallResponse(
                status: .success,
                result: resultData,
                toolName: request.toolName,
                diagnosis: "Found \(responseResults.count) results"
            )
        } catch {
            return ToolCallResponse(
                status: .failed,
                toolName: request.toolName,
                diagnosis: "Context search failed: \(error.localizedDescription)"
            )
        }
    }

    private static func defaultDatabasePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())

        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

        return anigmaDir.appendingPathComponent("codebase.sqlite").path
    }
}

private struct ContextSearchResponse: Codable {
    let query: String
    let expandedTerms: [String]
    let synonyms: [QuerySynonym]
    let suggestions: [String]
    let fuzzyMatches: [FuzzyMatch]
    let confidence: Double
    let queryId: String
    let results: [ContextSearchResult]
}

private struct ContextSearchResult: Codable {
    let filePath: String
    let description: String
    let matchReason: String
    let relevanceScore: Double
    let rankingScore: Double
    let rankingReason: String
    let matchingSymbols: [CodeSymbol]
    let summary: String?
}
