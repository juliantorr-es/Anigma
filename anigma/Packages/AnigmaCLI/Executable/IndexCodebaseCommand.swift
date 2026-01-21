//
//  IndexCodebaseCommand.swift
//  AnigmaCLI
//
//  Command to index a codebase with FTS5 + vector embeddings.
//

import Foundation
import ArgumentParser
import AnigmaCLIDatabase
import AnigmaCLIProviders
import AnigmaCLIML

struct IndexCodebaseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "index-ml",
        abstract: "Index codebase with FTS5 and vector embeddings"
    )

    @Option(name: .shortAndLong, help: "Repository root path")
    var repoRoot: String?

    @Option(name: .shortAndLong, help: "Git commit to index (default: HEAD)")
    var commit: String = "HEAD"

    @Option(name: .shortAndLong, help: "Embedding model ID")
    var embeddingModel: String?

    @Flag(name: .long, help: "Skip embedding generation (lexical indexing only)")
    var noEmbeddings: Bool = false

    @Flag(name: .long, help: "Force re-index even if commit already indexed")
    var force: Bool = false

    @Option(name: .long, help: "Path to ML Worker executable")
    var mlWorkerPath: String?

    func run() async throws {
        let repoPath = repoRoot ?? FileManager.default.currentDirectoryPath

        // Validate repository
        guard FileManager.default.fileExists(atPath: repoPath + "/.git") else {
            print("❌ Not a git repository: \(repoPath)")
            throw ExitCode.failure
        }

        print("🔍 Indexing repository at: \(repoPath)")
        print("📌 Commit: \(commit)")

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

        // Configure ML
        let mlPath = mlWorkerPath ?? findMLWorker()
        await mlIntegration.configure(
            mlWorkerPath: mlPath,
            embeddingModel: embeddingModel,
            chatModel: nil
        )

        // Check if already indexed
        if !force {
            if let status = try await indexManager.getIndexStatus(repoRoot: repoPath) {
                if status.commit == commit {
                    print("✅ Already indexed at commit \(commit)")
                    print("   Chunks: \(status.chunkCount)")
                    print("   Embeddings: \(status.embeddingCount)")
                    print("   Indexed: \(status.indexedAt)")
                    print("Use --force to re-index")
                    return
                }
            }
        }

        // Get list of files to index
        let files = try getFilesToIndex(repoPath: repoPath)
        print("📁 Found \(files.count) files to index")

        // Perform indexing
        if noEmbeddings {
            let result = try await indexManager.indexRepository(
                repoRoot: repoPath,
                commit: commit,
                files: files
            )

            print("✅ Indexing complete!")
            print("   Chunks created: \(result.chunksCreated)")
            print("   Chunks reused: \(result.chunksReused)")
            print("   Duration: \(String(format: "%.2f", result.duration))s")
        } else {
            let result = try await mlIntegration.indexCodebaseWithEmbeddings(
                repoRoot: repoPath,
                commit: commit,
                files: files,
                embeddingModel: embeddingModel
            ) { status in
                print("   \(status)")
            }

            print("✅ Indexing complete!")
            print("   Chunks created: \(result.indexingResult.chunksCreated)")
            print("   Chunks reused: \(result.indexingResult.chunksReused)")
            print("   Embeddings generated: \(result.embeddingsGenerated)")
            print("   Duration: \(String(format: "%.2f", result.indexingResult.duration))s")
        }

        // Show index status
        if let status = try await indexManager.getIndexStatus(repoRoot: repoPath) {
            print("\n📊 Index Status:")
            print("   Commit: \(status.commit)")
            print("   Total chunks: \(status.chunkCount)")
            print("   Total embeddings: \(status.embeddingCount)")
            print("   Indexed at: \(status.indexedAt)")
        }
    }

    private func getFilesToIndex(repoPath: String) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-C", repoPath,
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        // Filter for code/doc files
        let extensions = [
            ".swift", ".py", ".js", ".ts", ".jsx", ".tsx",
            ".md", ".txt", ".json", ".yaml", ".yml",
            ".c", ".cpp", ".h", ".hpp", ".rs", ".go"
        ]

        return output
            .split(separator: "\n")
            .map { String($0) }
            .filter { path in
                extensions.contains { path.hasSuffix($0) }
            }
    }

    private func findMLWorker() -> String? {
        // Try common locations
        let candidates = [
            "./.build/debug/ml-worker",
            "./.build/release/ml-worker",
            "/usr/local/bin/ml-worker",
            ProcessInfo.processInfo.environment["ML_WORKER_PATH"]
        ].compactMap { $0 }

        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
