//
//  InspirationCLI.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Inspiration
//
//  CLI commands for inspiration indexing and management.
//

import Foundation
import ArgumentParser
import HarmoniaModule

/// CLI commands for inspiration management.
public struct InspirationCommands {
    private let indexStore: InspirationIndexStore
    private let indexService: InspirationIndexService
    private let pipelineService: InspirationPipelineService

    public init() async throws {
        self.indexStore = try InspirationIndexStore()
        self.indexService = InspirationIndexService(indexStore: indexStore)

        let stateStore = try InspirationStateStore()
        self.pipelineService = InspirationPipelineService(
            indexStore: indexStore,
            stateStore: stateStore,
            gatekeeper: InspirationGatekeeper(indexStore: indexStore)
        )
    }

    /// Index all repositories in the inspiration directory.
    public func index(inspirationPath: String) async throws {
        print("📚 Indexing inspiration directory at: \(inspirationPath)")

        let repos = try await indexService.indexInspirationDirectory(at: inspirationPath)

        print("✅ Indexed \(repos.count) repositories:")
        for repo in repos {
            print("  • \(repo.name) (\(repo.path))")
            if let license = repo.license {
                print("    License: \(license)")
            }
        }
    }

    /// List all indexed repositories.
    public func listRepos() async throws {
        let repos = try await indexService.getAllRepos()

        if repos.isEmpty {
            print("📭 No repositories indexed yet.")
            print("Run 'harmonia inspiration index' to index repositories.")
            return
        }

        print("📚 Indexed repositories (\(repos.count)):")
        for repo in repos {
            print("  • \(repo.name)")
            print("    Path: \(repo.path)")
            if let license = repo.license {
                print("    License: \(license)")
            }
            print("    Last indexed: \(repo.lastIndexed)")
            print()
        }
    }

    /// List patterns by kind.
    public func listPatterns(kind: String? = nil) async throws {
        if let kindString = kind,
           let patternKind = InspirationPattern.PatternKind(rawValue: kindString) {
            let patterns = try await indexService.getPatternsByKind(patternKind)
            printPatterns(patterns, kind: patternKind)
        } else {
            // List all patterns grouped by kind
            let allKinds = InspirationPattern.PatternKind.allCases
            var totalPatterns = 0

            for patternKind in allKinds {
                let patterns = try await indexService.getPatternsByKind(patternKind)
                if !patterns.isEmpty {
                    printPatterns(patterns, kind: patternKind)
                    totalPatterns += patterns.count
                }
            }

            if totalPatterns == 0 {
                print("📭 No patterns found.")
                print("Run 'harmonia inspiration index' to index repositories and extract patterns.")
            }
        }
    }

    /// Run the inspiration pipeline.
    public func runPipeline() async throws {
        print("🚀 Running inspiration pipeline...")

        let tasks = try await pipelineService.runPipeline()

        if tasks.isEmpty {
            print("📭 No tasks generated.")
            print("Make sure you have patterns indexed and proposals pending.")
        } else {
            print("✅ Generated \(tasks.count) tasks:")
            for task in tasks {
                print("  • [\(task.taskType.rawValue)] \(task.description)")
                print("    Component: \(task.targetComponent)")
                print("    Priority: \(task.priority)")
                print()
            }
        }
    }

    /// List pending tasks.
    public func listTasks() async throws {
        let tasks = try await pipelineService.getPendingTasks()

        if tasks.isEmpty {
            print("📭 No pending tasks.")
            print("Run 'harmonia inspiration pipeline' to generate tasks.")
            return
        }

        print("📋 Pending tasks (\(tasks.count)):")
        for task in tasks {
            print("  • [\(task.taskType.rawValue)] \(task.description)")
            print("    Component: \(task.targetComponent)")
            print("    Priority: \(task.priority)")
            print("    Created: \(task.createdAt)")
            print()
        }
    }

    /// Get pipeline status.
    public func status() async throws {
        let (state, pendingTasks) = try await pipelineService.getStatus()

        print("📊 Inspiration Pipeline Status")
        print("==============================")
        print("Last pattern check: \(state.lastPatternCheck)")
        print("Pending proposals: \(state.pendingProposalCount)")
        print("Implemented proposals: \(state.implementedProposalCount)")
        print("Blocked proposals: \(state.blockedProposalCount)")
        print("Pending tasks: \(pendingTasks)")
        print()

        // Show recent patterns
        let recentPatterns = try await getRecentPatterns(limit: 5)
        if !recentPatterns.isEmpty {
            print("Recent patterns:")
            for pattern in recentPatterns {
                print("  • [\(pattern.kind.rawValue)] \(pattern.description)")
            }
        }
    }

    /// Re-index repositories that need it.
    public func reindex() async throws {
        print("🔄 Re-indexing repositories...")

        let reindexedRepos = try await indexService.reindexIfNeeded()

        if reindexedRepos.isEmpty {
            print("✅ All repositories are up to date.")
        } else {
            print("✅ Re-indexed \(reindexedRepos.count) repositories:")
            for repo in reindexedRepos {
                print("  • \(repo.name)")
            }
        }
    }

    /// Import a GitHub repository.
    public func importGitHub(owner: String, repo: String, inspirationPath: String) async throws {
        print("🌐 Importing GitHub repository: \(owner)/\(repo)")

        let config = WebClientConfig(
            githubToken: ProcessInfo.processInfo.environment["GITHUB_TOKEN"]
        )

        let webClientService = try WebClientService(
            config: config,
            indexStore: indexStore
        )

        let importedRepo = try await webClientService.importGitHubRepo(
            owner: owner,
            repo: repo,
            inspirationPath: inspirationPath
        )

        print("✅ Imported repository: \(importedRepo.name)")
        print("   Path: \(importedRepo.path)")
        if let license = importedRepo.license {
            print("   License: \(license)")
        }

        // Run scouts on the new repository
        print("🔍 Running scouts on imported repository...")
        try await indexService.runScouts(on: importedRepo)
    }

    /// Search and import GitHub repositories.
    public func searchAndImport(query: String, language: String? = nil, limit: Int = 5, inspirationPath: String) async throws {
        print("🔍 Searching GitHub for: \(query)")
        if let language = language {
            print("   Language: \(language)")
        }

        let config = WebClientConfig(
            githubToken: ProcessInfo.processInfo.environment["GITHUB_TOKEN"]
        )

        let webClientService = try WebClientService(
            config: config,
            indexStore: indexStore
        )

        let importedRepos = try await webClientService.searchAndImportRepos(
            query: query,
            language: language,
            limit: limit,
            inspirationPath: inspirationPath
        )

        print("✅ Imported \(importedRepos.count) repositories:")
        for repo in importedRepos {
            print("  • \(repo.name)")
            if let license = repo.license {
                print("    License: \(license)")
            }
        }
    }

    // MARK: - Helper Methods

    private func printPatterns(_ patterns: [InspirationPattern], kind: InspirationPattern.PatternKind) {
        print("📋 \(kind.rawValue.capitalized) Patterns (\(patterns.count)):")
        for pattern in patterns {
            print("  • \(pattern.description)")
            print("    Language: \(pattern.language)")
            print("    Discovered: \(pattern.discoveredAt)")
            if !pattern.metadata.isEmpty {
                print("    Metadata: \(pattern.metadata)")
            }
            print()
        }
    }

    private func getRecentPatterns(limit: Int) async throws -> [InspirationPattern] {
        // This would need a proper query for recent patterns
        // For now, get all patterns and sort by date
        let allKinds = InspirationPattern.PatternKind.allCases
        var allPatterns: [InspirationPattern] = []

        for kind in allKinds {
            let patterns = try await indexService.getPatternsByKind(kind)
            allPatterns.append(contentsOf: patterns)
        }

        return allPatterns
            .sorted { $0.discoveredAt > $1.discoveredAt }
            .prefix(limit)
            .map { $0 }
    }
}

/// Argument parser for inspiration CLI commands.

public struct InspirationCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "harmonia-inspiration",
        abstract: "Manage inspiration repositories and patterns",
        subcommands: [
            IndexCommand.self,
            ListReposCommand.self,
            ListPatternsCommand.self,
            PipelineCommand.self,
            ListTasksCommand.self,
            StatusCommand.self,
            ReindexCommand.self,
            ImportGitHubCommand.self,
            SearchAndImportCommand.self
        ]
    )

    public init() {}
}

// MARK: - Subcommands

struct IndexCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Index all repositories in the inspiration directory"
    )

    @Option(name: .shortAndLong, help: "Path to inspiration directory")
    var path: String = "./inspiration"

    func run() async throws {
        let commands = try await InspirationCommands()
        try await commands.index(inspirationPath: path)
    }
}

struct ListReposCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-repos",
        abstract: "List all indexed repositories"
    )

    func run() async throws {
        let commands = try await InspirationCommands()
        try await commands.listRepos()
    }
}

struct ListPatternsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-patterns",
        abstract: "List patterns by kind"
    )

    @Option(name: .shortAndLong, help: "Filter by pattern kind")
    var kind: String?

    func run() async throws {
        let commands = try await InspirationCommands()
        try await commands.listPatterns(kind: kind)
    }
}

struct PipelineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pipeline",
        abstract: "Run the inspiration pipeline"
    )

    func run() async throws {
        let commands = try await InspirationCommands()
        try await commands.runPipeline()
    }
}

struct ListTasksCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-tasks",
        abstract: "List pending tasks"
    )

    func run() async throws {
        let commands = try await InspirationCommands()
        try await commands.listTasks()
    }
}

struct ReindexCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reindex",
        abstract: "Re-index repositories that need it"
    )

    func run() async throws {
        let commands = try await InspirationCommands()
        try await commands.reindex()
    }
}

struct ImportGitHubCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import-github",
        abstract: "Import a GitHub repository"
    )

    @Argument(help: "GitHub repository owner")
    var owner: String

    @Argument(help: "GitHub repository name")
    var repo: String

    @Option(name: .shortAndLong, help: "Path to inspiration directory")
    var path: String = "./inspiration"

    func run() async throws {
        let commands = try await InspirationCommands()
        try await commands.importGitHub(owner: owner, repo: repo, inspirationPath: path)
    }
}

struct SearchAndImportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search-import",
        abstract: "Search and import GitHub repositories"
    )

    @Argument(help: "Search query")
    var query: String

    @Option(name: .shortAndLong, help: "Filter by language")
    var language: String?

    @Option(name: .shortAndLong, help: "Maximum number of repositories to import")
    var limit: Int = 5

    @Option(name: .shortAndLong, help: "Path to inspiration directory")
    var path: String = "./inspiration"

    func run() async throws {
        let commands = try await InspirationCommands()
        try await commands.searchAndImport(
            query: query,
            language: language,
            limit: limit,
            inspirationPath: path
        )
    }
}
