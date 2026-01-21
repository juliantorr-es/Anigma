//
//  SearchCommand.swift
//  AnigmaCLI
//
//  Command to search indexed codebase with hybrid retrieval.
//

import Foundation
import ArgumentParser
import AnigmaCLIDatabase
import AnigmaCLIProviders
import AnigmaCLIML

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search indexed codebase with hybrid retrieval"
    )

    @Argument(help: "Search query")
    var query: String

    @Option(name: .shortAndLong, help: "Repository root path")
    var repoRoot: String?

    @Option(name: .shortAndLong, help: "Maximum number of results")
    var limit: Int = 10

    @Option(name: .shortAndLong, help: "Filter by path prefix")
    var pathPrefix: String?

    @Flag(name: .long, help: "Disable vector search (lexical only)")
    var lexicalOnly: Bool = false

    @Flag(name: .long, help: "Show full chunk text")
    var fullText: Bool = false

    func run() async throws {
        let repoPath = repoRoot ?? FileManager.default.currentDirectoryPath

        print("🔍 Searching: \"\(query)\"")
        if let prefix = pathPrefix {
            print("📁 Path filter: \(prefix)")
        }
        print("🎯 Mode: \(lexicalOnly ? "Lexical only" : "Hybrid (lexical + vector)")")
        print()

        // Initialize database
        let config = CLIDatabaseConfig.default
        let db = CLIDatabaseActor(config: config)
        try await db.open()

        let indexManager = CLIIndexManager(database: db)
        let retrieval = CLIHybridRetrieval(database: db)
        let providerRegistry = ProviderRegistry()

        let mlIntegration = CLIMLIntegration(
            database: db,
            indexManager: indexManager,
            retrieval: retrieval,
            providerRegistry: providerRegistry
        )

        // Check if repository is indexed
        guard let status = try await indexManager.getIndexStatus(repoRoot: repoPath) else {
            print("❌ Repository not indexed. Run 'anigma-cli index' first.")
            throw ExitCode.failure
        }

        print("📊 Index status: \(status.chunkCount) chunks, \(status.embeddingCount) embeddings")
        print()

        // Perform search
        let results = try await mlIntegration.searchCodebase(
            query: query,
            limit: limit,
            pathPrefix: pathPrefix,
            useVector: !lexicalOnly
        )

        if results.isEmpty {
            print("No results found.")
            return
        }

        print("Found \(results.count) result(s):\n")

        for (index, hit) in results.enumerated() {
            print("[\(index + 1)] \(hit.sourcePath)")
            if !hit.sectionTitle.isEmpty {
                print("    Section: \(hit.sectionTitle)")
            }
            print("    Score: \(String(format: "%.4f", hit.score)) (\(hit.source.rawValue))")

            if fullText {
                // Fetch full chunk text
                let sql = "SELECT chunk_text FROM document_chunks WHERE chunk_id = ?"
                let rows = try await db.query(sql, parameters: [CLIParameter.text(hit.chunkID)])
                if let text = rows.first?["chunk_text"]?.asString {
                    print("    ---")
                    let preview = text.prefix(200)
                    print("    \(preview)\(text.count > 200 ? "..." : "")")
                }
            }

            print()
        }
    }
}
