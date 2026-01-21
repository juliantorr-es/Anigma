//
//  SearchCommand.swift
//  HarmoniaCLI
//
//  Semantic search with audit trail recording.
//

import AnigmaCore
import ArgumentParser
import DatabaseCore
import Foundation

struct Search: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "search",
            abstract: "Perform semantic search on ledger events",
            discussion: """
                Search the master ledger using semantic queries with full audit trail.
                All searches are recorded for compliance and debugging.
                """
        )
    }

    @OptionGroup var output: OutputOptions

    @Argument(help: "Search query string")
    var query: String?

    @Flag(
        name: .long,
        help: "Show search history and audit trail."
    )
    var history: Bool = false

    @Flag(
        name: .long,
        help: "Display search statistics and analytics."
    )
    var stats: Bool = false

    @Option(
        name: .long,
        help: "Filter by event types (comma-separated)."
    )
    var eventTypes: String?

    @Option(
        name: .long,
        help: "Filter by agent IDs (comma-separated)."
    )
    var agentIds: String?

    @Option(
        name: .long,
        help: "Minimum relevance score (0.0-1.0)."
    )
    var minRelevance: Double?

    @Option(
        name: .long,
        help: "Maximum results to return."
    )
    var limit: Int = 50

    @Option(
        name: .long,
        help: "User ID for audit trail."
    )
    var userId: String?

    func run() async throws {
        let dbPath = getDatabasePath()
        let db = DatabaseActor(dbPath: dbPath)
        try await db.open()

        let searchManager = SemanticSearchManager(database: db)
        try await searchManager.initialize()

        if stats {
            print("📊 Search Statistics")
            print(String(repeating: "=", count: 50))

            let searchStats = try await searchManager.getSearchStats()
            print("Total Queries: \(searchStats.totalQueries)")
            print("Avg Execution Time: \(String(format: "%.2f", searchStats.avgExecutionTimeMs))ms")
            print("Indexed Events: \(searchStats.indexedEvents)")
            print(String(repeating: "=", count: 50))

            return
        }

        if history {
            print("📋 Search History")
            print(String(repeating: "=", count: 50))

            let searchHistory = try await searchManager.getSearchHistory(
                userId: userId, limit: limit)

            if searchHistory.isEmpty {
                print("No search history found.")
            } else {
                for record in searchHistory {
                    let timeStr = ISO8601DateFormatter().string(from: record.timestamp)
                    print("[\(timeStr)] \(record.queryText)")
                    print("  Results: \(record.resultCount), Time: \(record.executionTimeMs)ms")
                    if let userId = record.userId {
                        print("  User: \(userId)")
                    }
                    print()
                }
            }

            print(String(repeating: "=", count: 50))

            return
        }

        guard let query = query else {
            print("❌ Query string required")
            return
        }

        print("🔍 Searching: \"\(query)\"")

        // Build filters
        var filters: SearchFilters?
        if eventTypes != nil || agentIds != nil || minRelevance != nil {
            filters = SearchFilters(
                eventTypes: eventTypes?.split(separator: ",").map(String.init),
                agentIds: agentIds?.split(separator: ",").map(String.init),
                minRelevance: minRelevance
            )
        }

        // Execute search
        let result = try await searchManager.search(
            query: query,
            userId: userId,
            filters: filters,
            limit: limit
        )

        // Display results
        print("\n📊 Search Results")
        print(String(repeating: "=", count: 50))
        print("Query: \(result.query)")
        print("Results: \(result.totalCount)")
        print("Execution Time: \(result.executionTimeMs)ms")
        print(String(repeating: "=", count: 50))

        if result.results.isEmpty {
            print("No results found.")
        } else {
            for (index, item) in result.results.enumerated() {
                let relevancePercent = Int(item.relevanceScore * 100)
                print("\n\(index + 1). [\(relevancePercent)%] \(item.contentHash)")
                print("   Segment: \(item.segmentId)")
                print("   Event: \(item.eventId)")
                print("   Content: \(item.textContent.prefix(100))...")
            }
        }

        print("\n" + String(repeating: "=", count: 50))
        print("✅ Search completed")

        // Emit JSON output if requested
        if output.format == .json {
            try OutputWriter.emit(
                command: "search",
                payload: result,
                format: output.format
            )
        }
    }

    private func getDatabasePath() -> String {
        if let dbPath = ProcessInfo.processInfo.environment["HARMONIA_DB_PATH"] {
            return dbPath
        }
        return FileManager.default.currentDirectoryPath + "/harmonia.db"
    }
}
