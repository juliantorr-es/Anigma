//
//  ModelCommands.swift
//  AnigmaCLI
//
//  CLI commands for model management: search, download, list, status, storage.
//

import Foundation
import ArgumentParser
import AnigmaCore
import DatabaseCore

public struct ModelCommands: ParsableCommand {
    public init() {}
    public static let configuration = CommandConfiguration(
        commandName: "model",
        abstract: "Model management commands for HuggingFace",
        subcommands: [
            ModelSearch.self,
            ModelDownload.self,
            ModelList.self,
            ModelStatus.self,
            ModelBenchmark.self,
            ModelStorage.self,
            ModelCancel.self
        ]
    )
}

public struct ModelSearch: ParsableCommand {
    public init() {}
    @Argument(help: "Search query") var query: String

    @Option(name: .shortAndLong, help: "Filter by task type")
    var task: String?

    @Option(name: .shortAndLong, help: "Limit results")
    var limit: Int = 20

    @Option(name: .shortAndLong, help: "Sort by")
    var sort: String = "downloads"

    public func run() async throws {
        let keychain = HuggingFaceKeychain()
        let hasToken = await keychain.hasToken

        print("HuggingFace Model Search")
        print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        print("Query: '\(query)'")
        print("Results: \(limit)")
        if let task = task {
            print("Task filter: \(task)")
        }
        print("Token: \(hasToken ? "Yes" : "No")")
        print()

        let db = try await DatabaseActor(path: ".")
        let cache = try await ModelSearchCache(database: db)
        let client = try await HuggingFaceHubClient(keychain: keychain, cache: cache)

        let filter = HFSearchFilter(
            query: query,
            task: task.flatMap { ModelTaskType(rawValue: $0) },
            sort: sort,
            limit: limit
        )

        let results = try await client.searchModels(query: query, filter: filter)

        for (index, result) in results.enumerated() {
            print("\(index + 1). \(result.id)")
            print("   Author: \(result.author)")
            print("   Size: \(result.formattedSize)")
            print("   Downloads: \(result.downloads.formatted())")
            if let task = result.taskType {
                print("   Task: \(task.displayName)")
            }
            print()
        }

        print("Found \(results.count) models")
    }
}

public struct ModelDownload: ParsableCommand {
    public init() {}
    @Argument(help: "Repository ID (e.g., 'TheBloke/Mistral-7B-GGUF')") var repo: String

    @Option(name: .shortAndLong, help: "File to download (default: all files)")
    var file: String?

    @Option(name: .shortAndLong, help: "Priority (low, normal, high, critical)")
    var priority: String = "normal"

    @Flag(name: .shortAndLong, help: "Resume from paused download")
    var resume: Bool = false

    public func run() async throws {
        let keychain = HuggingFaceKeychain()
        let db = try await DatabaseActor(path: ".")
        let cache = try await ModelSearchCache(database: db)
        let client = try await HuggingFaceHubClient(keychain: keychain, cache: cache)

        print("Downloading model: \(repo)")
        print()

        let detail = try await client.getModelInfo(repo: repo)

        let filesToDownload: [String]
        if let file = file {
            filesToDownload = [file]
        } else {
            filesToDownload = detail.files.filter { $0.isFile }.map { $0.path }
        }

        print("Files to download:")
        for file in filesToDownload {
            let fileInfo = detail.files.first { $0.path == file }
            print("  - \(file) (\(fileInfo?.formattedSize ?? "unknown"))")
        }
        print()

        let destinationDirectory = "./Models/\(repo.replacingOccurrences(of: "/", with: "_"))"
        let downloader = ResumableModelDownloader()
        let queue = DownloadQueueManager(downloader: downloader, destinationDirectory: destinationDirectory)

        for file in filesToDownload {
            let jobId = try await queue.enqueue(
                repo: repo,
                file: file,
                priority: JobPriority(rawValue: Int(priority) ?? 1) ?? .normal
            )
            print("Queued: \(file) (Job: \(jobId.raw.prefix(8)))")
        }

        print()
        print("Use 'anigma-cli model status' to check progress")
    }
}

public struct ModelList: ParsableCommand {
    public init() {}
    @Flag(name: .shortAndLong, help: "Show detailed information")
    var verbose: Bool = false

    public func run() async throws {
        print("Installed Models")
        print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        print()

        let database: any DatabaseExecutor = try await DatabaseActor(path: ".")
        let statement = "SELECT * FROM installed_models ORDER BY installed_at DESC"
        let rows = try await database.query(statement)

        if rows.isEmpty {
            print("No models installed")
            return
        }

        for (index, row) in rows.enumerated() {
            guard let id = row.string(for: "id"),
                  let name = row.string(for: "name") else {
                continue
            }

            let sizeGB = row.double(for: "size_gb") ?? 0
            let path = row.string(for: "path") ?? "unknown"
            let quantization = row.string(for: "quantization") ?? "unknown"

            print("\(index + 1). \(name)")
            if verbose {
                print("   ID: \(id)")
                print("   Size: \(String(format: "%.2f", sizeGB)) GB")
                print("   Quantization: \(quantization)")
                print("   Path: \(path)")
            }
            print()
        }

        print("Total: \(rows.count) models")
    }
}

public struct ModelStatus: ParsableCommand {
    public init() {}
    @Option(name: .shortAndLong, help: "Show detailed status")
    var verbose: Bool = false

    public func run() async throws {
        print("Model Download Status")
        print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        print()

        let downloader = ResumableModelDownloader()
        let queue = DownloadQueueManager(downloader: downloader, destinationDirectory: "./Models")

        let status = await queue.getQueueStatus()
        print("Active downloads: \(status.activeCount)")
        print("Queued: \(status.queuedCount)")
        print("Completed: \(status.completedCount)")
        print("Failed: \(status.failedCount)")
        print("Can start more: \(status.canStartMore)")
        print()

        let active = await queue.getAllDownloads()
        if !active.isEmpty {
            print("Active Downloads:")
            print("-" .padding(toLength: 40, withPad: "-", startingAt: 0))
            for download in active {
                print("  \(download.repo)")
                print("    File: \(download.file)")
                print("    Progress: \(download.progress.formattedProgress)")
                print("    Speed: \(download.progress.formattedSpeed)")
                print()
            }
        }

        let queued = await queue.getQueuedDownloads()
        if !queued.isEmpty {
            print("Queued Downloads:")
            print("-" .padding(toLength: 40, withPad: "-", startingAt: 0))
            for download in queued {
                print("  \(download.repo)/\(download.file)")
                print("    Priority: \(download.priority)")
                print()
            }
        }
    }
}

public struct ModelCancel: ParsableCommand {
    public init() {}
    @Argument(help: "Job ID to cancel (or 'all' to cancel all)")
    var jobId: String

    @Flag(name: .shortAndLong, help: "Cancel all downloads")
    var all: Bool = false

    public func run() async throws {
        let downloader = ResumableModelDownloader()
        let queue = DownloadQueueManager(downloader: downloader, destinationDirectory: "./Models")

        if all {
            await queue.cancelAll()
            print("Cancelled all downloads")
        } else if jobId == "all" {
            await queue.cancelAll()
            print("Cancelled all downloads")
        } else {
            print("Cancel not yet implemented for specific job IDs")
        }
    }
}

public struct ModelBenchmark: ParsableCommand {
    public init() {}
    @Flag(name: .shortAndLong, help: "Quick assessment only")
    var quick: Bool = false

    public func run() async throws {
        print("System Benchmark")
        print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        print()

        let benchmark = SystemBenchmark()

        if quick {
            let tier = await benchmark.quickAssess()
            print("Quick Assessment:")
            print("  Tier: \(tier.displayName)")
            print("  Recommended models: \(tier.recommendedModelSize)")
        } else {
            print("Running full benchmark...")
            let result = await benchmark.runBenchmark()
            print()
            print("Results:")
            print("  Overall Score: \(result.formattedScore)/100")
            print("  CPU Score: \(String(format: "%.0f", result.cpuScore))")
            if let gpu = result.gpuScore {
                print("  GPU Score: \(String(format: "%.0f", gpu))")
            }
            print("  Memory: \(result.memoryGB) GB")
            print("  Storage Score: \(String(format: "%.0f", result.storageScore))")
            print()
            print("  Tier: \(result.tier.displayName)")
            print("  \(result.tierDescription)")
            print()
            print("  Recommended:")
            print("    Max model size: \(result.recommendedModelSize)")
            print("    Backends: \(result.recommendedBackends.map { $0.displayName }.joined(separator: ", "))")
        }
    }
}

public struct ModelStorage: ParsableCommand {
    public init() {}
    @Flag(name: .shortAndLong, help: "Show detailed breakdown")
    var verbose: Bool = false

    public func run() async throws {
        print("Storage Status")
        print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        print()

        let monitor = StorageMonitor()
        let status = await monitor.getStatus()
        let warnings = await monitor.getWarnings()
        let breakdown = await monitor.calculateStorageBreakdown()

        print("Storage Overview:")
        print("  Total: \(status.formattedTotal)")
        print("  Used: \(status.formattedUsed)")
        print("  Available: \(status.formattedAvailable)")
        print("  Usage: \(Int(status.percentageUsed * 100))%")
        print()

        if !warnings.isEmpty {
            print("Warnings:")
            for warning in warnings {
                print("  [\(warning.level.rawValue.uppercased())] \(warning.message)")
            }
            print()
        }

        if verbose {
            print("Breakdown:")
            print("  Models: \(formatBytes(breakdown.modelStorageBytes))")
            print("  Cache: \(formatBytes(breakdown.cacheStorageBytes))")
            print("  System: \(formatBytes(breakdown.systemBytes))")
        }

        let modelDir = "./Models"
        let modelSize = calculateDirectorySize(at: modelDir)
        print()
        print("Local models directory: \(modelDir)")
        print("Local models size: \(formatBytes(modelSize))")
    }

    private func calculateDirectorySize(at path: String) -> UInt64 {
        let url = URL(fileURLWithPath: path)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let size = values.fileSize else { continue }
            total += UInt64(size)
        }
        return total
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return String(format: "%.2f %@", value, units[unitIndex])
    }
}
