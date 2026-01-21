//
//  IndexCommand.swift
//  AnigmaCLIExecutable
//
//  Index command for creating and managing search indexes.
//

import AnigmaCLICore
import AnigmaCLIDatabase
import AnigmaCLIProviders
import AnigmaCLIML
import ArgumentParser
import Foundation

struct AnigmaIndexCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "index",
            abstract: "Manage code search indexes.",
            subcommands: [
                IndexCreateCommand.self,
                IndexStatusCommand.self,
                IndexSearchCommand.self
            ]
        )
    }
}

// MARK: - Index Create

struct IndexCreateCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "create",
            abstract: "Create or update search index for a repository."
        )
    }

    @Option(name: .long, help: "Repository root path.")
    var repoRoot: String = FileManager.default.currentDirectoryPath

    @Option(name: .long, help: "Git commit to index.")
    var commit: String?

    @Option(name: .long, help: "File patterns to include (glob).")
    var include: String = "**/*.swift"

    @Flag(name: .long, help: "Generate embeddings.")
    var embeddings: Bool = false

    @Option(name: .long, help: "Embedding model ID.")
    var modelID: String = "default"

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)

        try await db.open()
        defer { db.close() }

        let indexer = CLIIndexManager(database: db)

        // Get current commit if not specified
        let commitHash = try commit ?? getCurrentGitCommit(repoRoot: repoRoot)

        // Find files matching pattern
        let files = try findFiles(in: repoRoot, pattern: include)

        print("Indexing \(files.count) files at commit \(commitHash)...")

        if embeddings {
            print("Initializing ML integration for embeddings...")
            let retrieval = CLIHybridRetrieval(database: db)
            let providerRegistry = ProviderRegistry()

            let mlIntegration = CLIMLIntegration(
                database: db,
                indexManager: indexer,
                retrieval: retrieval,
                providerRegistry: providerRegistry
            )

            // Use real embedding generation via CLIMLIntegration
            let result = try await mlIntegration.indexCodebaseWithEmbeddings(
                repoRoot: repoRoot,
                commit: commitHash,
                files: files,
                embeddingModel: modelID == "default" ? nil : modelID
            ) { status in
                print("  \(status)")
            }

            print("✅ Indexed \(result.indexingResult.chunksCreated) new chunks")
            print("✅ Generated \(result.embeddingsGenerated) embeddings")
            print("⏱  Duration: \(String(format: "%.2f", result.indexingResult.duration))s")

        } else {
            // Lexical only
            let result = try await indexer.indexRepository(
                repoRoot: repoRoot,
                commit: commitHash,
                files: files
            )

            print("✅ Indexed \(result.chunksCreated) new chunks, reused \(result.chunksReused) chunks")
            print("⏱  Duration: \(String(format: "%.2f", result.duration))s")
        }
    }

    private func getCurrentGitCommit(repoRoot: String) throws -> String {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let commit = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw IndexError.gitCommandFailed
        }

        return commit
    }

    private func findFiles(in directory: String, pattern: String) throws -> [String] {
        // Simple implementation - find all Swift files
        // In production, use proper glob matching
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: directory)

        var files: [String] = []

        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".swift") {
                files.append(file)
            }
        }

        return files
    }
}

// MARK: - Index Status

struct IndexStatusCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "status",
            abstract: "Show index status for a repository."
        )
    }

    @Option(name: .long, help: "Repository root path.")
    var repoRoot: String = FileManager.default.currentDirectoryPath

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)

        try await db.open()
        defer { db.close() }

        let indexer = CLIIndexManager(database: db)

        guard let status = try await indexer.getIndexStatus(repoRoot: repoRoot) else {
            print("❌ No index found for repository: \(repoRoot)")
            return
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium

        print("📊 Index Status")
        print("  Commit:     \(status.commit)")
        print("  Chunks:     \(status.chunkCount)")
        print("  Embeddings: \(status.embeddingCount)")
        print("  Indexed at: \(formatter.string(from: status.indexedAt))")

        let vectorAvailable = await db.isVectorAvailable()
        if vectorAvailable {
            if let version = await db.getVectorVersion() {
                print("  Vector:     enabled (v\(version))")
            } else {
                print("  Vector:     enabled")
            }
        } else {
            print("  Vector:     disabled (lexical-only mode)")
        }
    }
}

// MARK: - Index Search

struct IndexSearchCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "search",
            abstract: "Search the index."
        )
    }

    @Argument(help: "Search query.")
    var query: String

    @Option(name: .long, help: "Search mode (lexical|vector|hybrid).")
    var mode: String = "hybrid"

    @Option(name: .long, help: "Maximum results to return.")
    var limit: Int = 10

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)

        try await db.open()
        defer { db.close() }

        let retrieval = CLIHybridRetrieval(database: db)

        let searchMode: CLIRetrievalMode
        switch mode.lowercased() {
        case "lexical":
            searchMode = .lexical
        case "vector":
            searchMode = .vector
        default:
            searchMode = .hybrid
        }

        let request = CLIRetrievalRequest(
            query: query,
            mode: searchMode,
            limit: limit
        )

        print("🔍 Searching for: '\(query)' (mode: \(mode))")

        let hits = try await retrieval.search(request)

        if hits.isEmpty {
            print("❌ No results found")
            return
        }

        print("\n📄 Found \(hits.count) results:\n")

        for (index, hit) in hits.enumerated() {
            let scoreStr = String(format: "%.4f", hit.score)
            print("[\(index + 1)] \(hit.sourcePath)")
            print("    Score: \(scoreStr) (\(hit.source.rawValue))")
            print("    Chunk: \(hit.chunkID)")
            print("")
        }
    }
}

enum IndexError: Error {
    case gitCommandFailed
}
