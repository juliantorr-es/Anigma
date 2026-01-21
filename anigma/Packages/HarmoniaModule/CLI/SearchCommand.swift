//
//  SearchCommand.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import ArgumentParser
import Foundation
import DatabaseCore

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Hybrid lexical + vector search over indexed chunks"
    )

    @Argument(help: "Query text")
    var query: String

    @Option(name: .long, help: "Retrieval mode: lexical, vector, or hybrid")
    var mode: String = "hybrid"

    @Option(name: .long, help: "Maximum number of results to return")
    var limit: Int = 10

    @Option(name: .long, help: "Path prefix to restrict search scope")
    var pathPrefix: String?

    @Option(name: .long, help: "Model ID for vector search")
    var modelID: String?

    @Option(name: .long, help: "Output format: json or table")
    var format: String = "table"

    func run() async throws {
        // Parse retrieval mode
        let retrievalMode: RetrievalMode
        switch mode.lowercased() {
        case "lexical":
            retrievalMode = .lexical
        case "vector":
            retrievalMode = .vector
        case "hybrid":
            retrievalMode = .hybrid
        default:
            throw ValidationError.invalidMode(mode)
        }

        // Create retrieval request
        let request = RetrievalRequest(
            query: query,
            mode: retrievalMode,
            limit: limit,
            pathPrefix: pathPrefix,
            modelID: modelID
        )

        // Initialize services (simplified for CLI)
        let db = DatabaseActor()
        try await db.open()
        let policyGate = PolicyGate()
        let evidence = GovernedEvidenceRecorder(masterDb: db)
        let loopBreaker = ToolCallLoopBreaker()

        // Create retrieval service without embedding provider for now
        let retrieval = RetrievalService(
            db: db,
            policyGate: policyGate,
            evidence: evidence,
            loopBreaker: loopBreaker,
            embedder: nil
        )

        // Execute search
        let hits = try await retrieval.retrieve(request)

        // Output results
        if format.lowercased() == "json" {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            let json = try encoder.encode(hits)
            print(String(data: json, encoding: .utf8)!)
        } else {
            // Table format
            print("Score\tSource Path\tSection\tChunk ID")
            print("-----\t-----------\t-------\t---------")
            for hit in hits {
                let score = String(format: "%.3f", hit.score)
                let section = hit.sectionTitle.isEmpty ? "<no section>" : hit.sectionTitle
                print("\(score)\t\(hit.sourcePath)\t\(section)\t\(hit.chunkID)")
            }
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidInput(String)
    case invalidMode(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .invalidMode(let mode):
            return "Invalid mode: \(mode). Use lexical, vector, or hybrid."
        }
    }
}
