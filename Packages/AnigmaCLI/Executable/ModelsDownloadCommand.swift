//
//  ModelsDownloadCommand.swift
//  AnigmaCLIExecutable
//
//  Model download commands with progress tracking and verification.
//

import ArgumentParser
import Foundation
import ModelRegistry
import ModelManagement
import ContractsCore

struct ModelsDownloadCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "download",
            abstract: "Download models from HuggingFace or URLs."
        )
    }

    @OptionGroup var output: OutputOptions

    @Option(name: .long, help: "HuggingFace repo id (e.g., mlx-community/Qwen2.5-7B-4bit).")
    var repo: String?

    @Option(name: .long, help: "HuggingFace revision (default: main).")
    var revision: String = "main"

    @Option(name: .long, help: "Direct download URL.")
    var url: String?

    @Option(name: .long, help: "Destination directory (defaults to Anigma model cache).")
    var dest: String?

    @Option(name: .long, help: "Expected SHA-256 checksum for verification.")
    var checksum: String?

    @Option(name: .long, help: "Model ID to register as.")
    var modelId: String?

    @Option(name: .long, help: "Task kind (inference|embedding|transcription).")
    var task: String?

    @Option(name: .long, help: "Backend (mlx|gguf|coreml).")
    var backend: String?

    @Option(name: .long, help: "Trust tier (first_class|compatible|experimental|quarantined).")
    var trustTier: String?

    @Flag(name: .long, help: "Auto-detect and download all required model files.")
    var autoDetect: Bool = false

    @Flag(name: .long, help: "Show detailed progress.")
    var verbose: Bool = false

    mutating func run() async throws {
        if (repo == nil && url == nil) || (repo != nil && url != nil) {
            throw ValidationError("Specify either --repo or --url.")
        }

        if let repo = repo {
            try await downloadFromHuggingFace(repo: repo)
        } else if let url = url {
            try await downloadFromURL(url: url)
        }
    }

    private func downloadFromHuggingFace(repo: String) async throws {
        print("🔍 Fetching model info for \(repo)...")

        let hfDownloader = HuggingFaceModelDownloader()

        // Fetch model info
        let modelInfo = try await hfDownloader.fetchModelInfo(repo: repo)
        print("✓ Found: \(modelInfo.modelId)")
        if let author = modelInfo.author {
            print("  Author: \(author)")
        }
        if let downloads = modelInfo.downloads {
            print("  Downloads: \(downloads)")
        }
        if let tags = modelInfo.tags, !tags.isEmpty {
            print("  Tags: \(tags.joined(separator: ", "))")
        }

        // List files
        let allFiles = try await hfDownloader.listFiles(repo: repo, revision: revision)
        let files = allFiles.filter { $0.isFile }

        print("📦 Found \(files.count) files")

        // Determine which files to download
        var filesToDownload: [String] = []

        if autoDetect {
            // Auto-detect essential files
            let essentialPatterns = [
                "config.json",
                "tokenizer.json",
                "tokenizer_config.json",
                "special_tokens_map.json",
                ".safetensors",
                ".gguf",
                ".mlmodel",
                ".mlpackage"
            ]

            filesToDownload = files.filter { fileInfo in
                essentialPatterns.contains { pattern in
                    fileInfo.path.hasSuffix(pattern) || fileInfo.path.contains(pattern)
                }
            }.map { $0.path }

            print("🎯 Auto-detected \(filesToDownload.count) essential files:")
            for file in filesToDownload.prefix(10) {
                print("  - \(file)")
            }
            if filesToDownload.count > 10 {
                print("  ... and \(filesToDownload.count - 10) more")
            }
        } else {
            // Download all files
            filesToDownload = files.map { $0.path }
        }

        guard !filesToDownload.isEmpty else {
            print("❌ No files to download")
            throw ExitCode.failure
        }

        // Determine destination
        let destinationDir: String
        if let dest = dest {
            destinationDir = dest
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            let cacheDir = appSupport
                .appendingPathComponent("Anigma/ModelCache", isDirectory: true)
                .appendingPathComponent(repo.replacingOccurrences(of: "/", with: "_"), isDirectory: true)
            try FileManager.default.createDirectory(
                at: cacheDir,
                withIntermediateDirectories: true
            )
            destinationDir = cacheDir.path
        }

        print("📂 Downloading to: \(destinationDir)")

        // Download files
        final class DownloadState: @unchecked Sendable {
            var currentFile = ""
            var lastProgress: Double = 0
        }
        let state = DownloadState()
        let verbose = self.verbose

        let downloadedFiles = try await hfDownloader.download(
            repo: repo,
            revision: revision,
            files: filesToDownload,
            destinationDirectory: destinationDir
        ) { [state, verbose] file, progress in
            if state.currentFile != file {
                if !state.currentFile.isEmpty {
                    print("\n✓ \(state.currentFile)")
                }
                state.currentFile = file
                state.lastProgress = 0
                print("⬇️  \(file)")
            }

            if verbose || Int(progress.percentage * 100) % 10 == 0 && Int(progress.percentage * 100) != Int(state.lastProgress * 100) {
                _ = Int(progress.percentage * 100)
                let speed = progress.formattedSpeed
                let eta = progress.estimatedSecondsRemaining.map { Self.formatTime($0) } ?? "unknown"
                print("   \(progress.formattedProgress) @ \(speed) - ETA: \(eta)")
                state.lastProgress = progress.percentage
            }
        }

        if !state.currentFile.isEmpty {
            print("\n✓ \(state.currentFile)")
        }

        print("\n✅ Downloaded \(downloadedFiles.count) files")

        // Register the model
        if let modelId = modelId {
            try await registerDownloadedModel(
                modelId: modelId,
                installPath: destinationDir,
                source: .huggingFace(repo: repo, revision: revision)
            )
        } else {
            print("\n💡 To register this model, run:")
            print("   anigma models import --path \(destinationDir) --model-id <id> --task <task> --backend <backend>")
        }
    }

    private func downloadFromURL(url: String) async throws {
        print("⬇️  Downloading from \(url)...")

        // Determine destination
        let destinationPath: String
        if let dest = dest {
            destinationPath = dest
        } else {
            let filename = URL(string: url)?.lastPathComponent ?? "model.bin"
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            let cacheDir = appSupport
                .appendingPathComponent("Anigma/ModelCache", isDirectory: true)
            try FileManager.default.createDirectory(
                at: cacheDir,
                withIntermediateDirectories: true
            )
            destinationPath = cacheDir.appendingPathComponent(filename).path
        }

        print("📂 Destination: \(destinationPath)")

        // Download
        let downloader = ModelDownloader()
        let task = ModelDownloadTask(
            url: url,
            destinationPath: destinationPath,
            expectedChecksum: checksum
        )

        final class URLDownloadState: @unchecked Sendable {
            var lastProgress: Double = 0
        }
        let state = URLDownloadState()
        let verbose = self.verbose

        let finalPath = try await downloader.download(task: task) { [state, verbose] progress in
            if verbose || Int(progress.percentage * 100) % 10 == 0 && Int(progress.percentage * 100) != Int(state.lastProgress * 100) {
                _ = Int(progress.percentage * 100)
                let speed = progress.formattedSpeed
                let eta = progress.estimatedSecondsRemaining.map { Self.formatTime($0) } ?? "unknown"
                print("   \(progress.formattedProgress) @ \(speed) - ETA: \(eta)")
                state.lastProgress = progress.percentage
            }
        }

        print("\n✅ Downloaded to: \(finalPath)")

        // Register if model ID provided
        if let modelId = modelId {
            try await registerDownloadedModel(
                modelId: modelId,
                installPath: finalPath,
                source: .localPath(finalPath)
            )
        } else {
            print("\n💡 To register this model, run:")
            print("   anigma models import --path \(finalPath) --model-id <id> --task <task> --backend <backend>")
        }
    }

    private func registerDownloadedModel(
        modelId: String,
        installPath: String,
        source: ModelSource
    ) async throws {
        print("\n📝 Registering model: \(modelId)")

        let taskKind = try task.map { raw -> ModelTaskKind in
            guard let kind = ModelTaskKind(rawValue: raw) else {
                throw ValidationError("Invalid task: \(raw)")
            }
            return kind
        } ?? .inference

        let backendKind = try backend.map { raw -> MLBackend in
            guard let kind = MLBackend(rawValue: raw) else {
                throw ValidationError("Invalid backend: \(raw)")
            }
            return kind
        } ?? inferBackend(installPath: installPath)

        let tierKind = try trustTier.map { raw -> ModelTrustTier in
            guard let kind = ModelTrustTier(rawValue: raw) else {
                throw ValidationError("Invalid trust tier: \(raw)")
            }
            return kind
        } ?? .compatible

        let license = LicenseDecision(
            declared: "downloaded",
            allowed: true,
            reason: "User download",
            timestamp: Date()
        )

        let spec = ModelSpec(
            id: modelId,
            source: source,
            task: taskKind,
            backend: backendKind,
            trustTier: tierKind,
            license: license,
            artifactHashes: [:],
            tokenizerHash: nil,
            conversionReceipt: nil,
            metadata: [:],
            registeredAt: Date(),
            verifiedAt: Date(),
            storageBytes: 0
        )

        let registryPath = try {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            let anigmaDir = appSupport.appendingPathComponent("Anigma", isDirectory: true)
            try FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)
            return anigmaDir.appendingPathComponent("models.sqlite").path
        }()

        let registry = try await ModelRegistryStore(storagePath: registryPath)
        let entry = try await registry.register(spec, installPath: installPath)

        print("✅ Registered: \(entry.id)")
        print("   Task: \(entry.spec.task.rawValue)")
        print("   Backend: \(entry.spec.backend.rawValue)")
        print("   Install: \(entry.installPath)")
    }

    private func inferBackend(installPath: String) -> MLBackend {
        let url = URL(fileURLWithPath: installPath)
        let ext = url.pathExtension.lowercased()

        if ext == "gguf" {
            return .gguf
        } else if ext == "mlmodel" || ext == "mlpackage" {
            return .coreml
        }

        return .mlx
    }

    private static func formatTime(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(mins)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        }
    }
}
