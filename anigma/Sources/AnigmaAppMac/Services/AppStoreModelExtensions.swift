//
//  AppStoreModelExtensions.swift
//  AnigmaAppMac
//
//  AppStore extensions for model management integration.
//

import Foundation
import SwiftUI
import Observation
import AnigmaCore
import AnigmaCLI

extension AppStore {
    // MARK: - Model Management Services

    nonisolated var hfKeychain: HuggingFaceKeychain {
        HuggingFaceKeychain()
    }

    nonisolated var modelSearchCache: ModelSearchCache {
        get async {
            let db = try! await DatabaseActor(storagePath: appConfig.storagePath)
            return try! await ModelSearchCache(database: db)
        }
    }

    nonisolated var hfClient: HuggingFaceHubClient {
        get async {
            let keychain = HuggingFaceKeychain()
            let cache = try! await ModelSearchCache(
                database: try! await DatabaseActor(storagePath: appConfig.storagePath)
            )
            return HuggingFaceHubClient(keychain: keychain, cache: cache)
        }
    }

    nonisolated var resumableDownloader: ResumableModelDownloader {
        ResumableModelDownloader()
    }

    nonisolated var downloadQueue: DownloadQueueManager {
        get async {
            let destinationDirectory = (try! await appConfig.modelsDirectory()).path
            let downloader = ResumableModelDownloader()
            return DownloadQueueManager(downloader: downloader, destinationDirectory: destinationDirectory)
        }
    }

    nonisolated var storageMonitor: StorageMonitor {
        StorageMonitor()
    }

    nonisolated var systemBenchmark: SystemBenchmark {
        SystemBenchmark()
    }

    // MARK: - Model Browser State

    @Published public var modelSearchResults: [HFSearchResult] = []
    @Published public var selectedHuggingFaceModel: HFSearchResult?
    @Published public var isSearchingModels: Bool = false
    @Published public var modelSearchError: String?

    @Published public var benchmarkResult: SystemBenchmark.Result?
    @Published public var isRunningBenchmark: Bool = false

    @Published public var activeDownloads: [DownloadQueueManager.ActiveDownload] = []
    @Published public var queuedDownloads: [DownloadQueueManager.QueuedDownload] = []

    @Published public var storageStatus: StorageMonitor.Status?
    @Published public var storageWarnings: [StorageMonitor.StorageWarning] = []

    // MARK: - Model Actions

    @MainActor
    public func searchHuggingFaceModels(query: String, filter: HFSearchFilter?) async {
        isSearchingModels = true
        modelSearchError = nil

        do {
            let client = await hfClient
            let results = try await client.searchModels(
                query: query,
                filter: filter ?? HFSearchFilter(query: query)
            )
            modelSearchResults = results
        } catch {
            modelSearchError = error.localizedDescription
        }

        isSearchingModels = false
    }

    @MainActor
    public func runSystemBenchmark() async {
        guard !isRunningBenchmark else { return }
        isRunningBenchmark = true

        let result = await systemBenchmark.runBenchmark()
        benchmarkResult = result

        isRunningBenchmark = false
    }

    @MainActor
    public func downloadModel(repo: String, files: [String], priority: JobPriority = .normal) async {
        let queue = await downloadQueue
        for file in files {
            _ = try? await queue.enqueue(repo: repo, file: file, priority: priority)
        }
        await refreshDownloadState()
    }

    @MainActor
    public func pauseDownload(jobId: JobId) async {
        let queue = await downloadQueue
        try? await queue.pause(jobId: jobId)
        await refreshDownloadState()
    }

    @MainActor
    public func resumeDownload(jobId: JobId) async {
        let queue = await downloadQueue
        try? await queue.resume(jobId: jobId)
        await refreshDownloadState()
    }

    @MainActor
    public func cancelDownload(jobId: JobId) async {
        let queue = await downloadQueue
        try? await queue.cancel(jobId: jobId)
        await refreshDownloadState()
    }

    @MainActor
    public func cancelAllDownloads() async {
        let queue = await downloadQueue
        await queue.cancelAll()
        await refreshDownloadState()
    }

    @MainActor
    public func refreshDownloadState() async {
        let queue = await downloadQueue
        activeDownloads = await queue.getAllDownloads()
        queuedDownloads = await queue.getQueuedDownloads()
    }

    @MainActor
    public func refreshStorageStatus() async {
        let monitor = storageMonitor
        storageStatus = await monitor.getStatus()
        storageWarnings = await monitor.getWarnings()
    }

    // MARK: - Storage Warning Helper

    public var storageWarning: String? {
        guard let warning = storageWarnings.first else { return nil }
        return warning.message
    }

    // MARK: - Model Filtering

    public func filterModels(
        taskType: ModelTaskType? = nil,
        backend: MLBackend? = nil,
        maxSizeGB: Int? = nil
    ) -> [ModelRegistryEntry] {
        var filtered = modelRegistry.installedModels

        if let task = taskType {
            filtered = filtered.filter { model in
                model.backendCompatibility?.supportedBackends.contains { $0.rawValue == task.rawValue } ?? false
            }
        }

        if let backend = backend {
            filtered = filtered.filter { model in
                model.backendCompatibility?.supportedBackends.contains(backend.rawValue) ?? false
            }
        }

        return filtered
    }

    // MARK: - Model Recommendations

    public func getRecommendedModels() -> [HFSearchResult] {
        guard let tier = benchmarkResult?.tier else { return [] }

        return modelSearchResults.filter { model in
            guard let size = model.size else { return true }
            let sizeGB = Double(size) / (1024 * 1024 * 1024)
            return sizeGB <= Double(tier.maxModelSizeGB)
        }
    }
}
