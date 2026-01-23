//
//  DownloadQueueManager.swift
//  AnigmaCLI
//
//  Manages model download queue with concurrency limiting (max 3 concurrent).
//

import Foundation
import AnigmaCore

public actor DownloadQueueManager {
    public static let maxConcurrentDownloads = 3

    public struct ActiveDownload: Identifiable, Sendable {
        public let id: JobId
        public let repo: String
        public let file: String
        public var progress: DownloadProgress
        public var state: DownloadState
        public let startedAt: Date
        public var updatedAt: Date
    }

    public struct QueuedDownload: Identifiable, Sendable {
        public let id: JobId
        public let repo: String
        public let file: String
        public let priority: JobPriority
        public let queuedAt: Date
    }

    public struct QueueStatus: Sendable {
        public let activeCount: Int
        public let queuedCount: Int
        public let completedCount: Int
        public let failedCount: Int
        public let canStartMore: Bool
    }

    private var queue: [JobId: QueuedDownload] = [:]
    private var active: [JobId: ActiveDownload] = [:]
    private var completed: [JobId: ActiveDownload] = [:]
    private var failed: [JobId: (download: ActiveDownload, error: String)] = [:]
    private var downloader: ResumableModelDownloader

    private let baseURL = "https://huggingface.co"
    private let destinationDirectory: String

    public init(
        downloader: ResumableModelDownloader,
        destinationDirectory: String
    ) {
        self.downloader = downloader
        self.destinationDirectory = destinationDirectory
    }

    public func enqueue(
        repo: String,
        file: String,
        priority: JobPriority = .normal,
        destinationPath: String? = nil
    ) async throws -> JobId {
        let jobId = JobId()

        let queued = QueuedDownload(
            id: jobId,
            repo: repo,
            file: file,
            priority: priority,
            queuedAt: Date()
        )

        queue[jobId] = queued

        await processQueue()

        return jobId
    }

    public func pause(jobId: JobId) async throws {
        guard let download = active[jobId] else {
            throw DownloadQueueError.jobNotFound
        }

        let fileURL = "\(baseURL)/\(download.repo)/resolve/main/\(download.file)"
        let resumeData = try await downloader.pause(url: fileURL)

        download.state = .paused(resumeData: resumeData ?? Data())
        download.updatedAt = Date()

        active.removeValue(forKey: jobId)
        queue[jobId] = QueuedDownload(
            id: jobId,
            repo: download.repo,
            file: download.file,
            priority: .normal,
            queuedAt: Date()
        )

        await processQueue()
    }

    public func resume(jobId: JobId) async throws {
        guard let download = completed[jobId] ?? failed[jobId]?.download else {
            throw DownloadQueueError.jobNotFound
        }

        let fileURL = "\(baseURL)/\(download.repo)/resolve/main/\(download.file)"
        let resumeData = try await downloader.getResumeData(url: fileURL)

        guard let data = resumeData else {
            throw DownloadQueueError.noResumeData
        }

        try await enqueue(
            repo: download.repo,
            file: download.file,
            priority: .high
        )
    }

    public func cancel(jobId: JobId) async throws {
        if let download = active[jobId] {
            let fileURL = "\(baseURL)/\(download.repo)/resolve/main/\(download.file)"
            await downloader.cancel(url: fileURL)
            active.removeValue(forKey: jobId)
        } else if let queued = queue[jobId] {
            queue.removeValue(forKey: jobId)
        } else if let completed = completed[jobId] {
            completed.removeValue(forKey: jobId)
        } else if let failed = failed[jobId] {
            self.failed.removeValue(forKey: jobId)
        }

        await processQueue()
    }

    public func cancelAll() async {
        for jobId in active.keys {
            let download = active[jobId]
            let fileURL = "\(baseURL)/\(download?.repo ?? "")/resolve/main/\(download?.file ?? "")"
            await downloader.cancel(url: fileURL)
        }
        active.removeAll()
        queue.removeAll()
    }

    public func getStatus(jobId: JobId) -> DownloadStatus? {
        if let download = active[jobId] {
            return DownloadStatus(
                jobId: jobId,
                repo: download.repo,
                file: download.file,
                progress: download.progress,
                state: download.state,
                isActive: true,
                queuedAt: download.startedAt
            )
        } else if let queued = queue[jobId] {
            return DownloadStatus(
                jobId: jobId,
                repo: queued.repo,
                file: queued.file,
                progress: nil,
                state: .downloading,
                isActive: false,
                queuedAt: queued.queuedAt
            )
        } else if let completed = completed[jobId] {
            return DownloadStatus(
                jobId: jobId,
                repo: completed.repo,
                file: completed.file,
                progress: completed.progress,
                state: .completed(path: ""),
                isActive: false,
                queuedAt: completed.startedAt
            )
        }
        return nil
    }

    public func getQueueStatus() -> QueueStatus {
        QueueStatus(
            activeCount: active.count,
            queuedCount: queue.count,
            completedCount: completed.count,
            failedCount: failed.count,
            canStartMore: active.count < Self.maxConcurrentDownloads
        )
    }

    public func getAllDownloads() -> [ActiveDownload] {
        Array(active.values)
    }

    public func getQueuedDownloads() -> [QueuedDownload] {
        Array(queue.values).sorted { $0.priority > $1.priority }
    }

    private func processQueue() async {
        guard active.count < Self.maxConcurrentDownloads else { return }

        let sortedQueue = queue.values
            .sorted { $0.priority > $1.priority }

        for item in sortedQueue {
            guard active.count < Self.maxConcurrentDownloads else { break }

            queue.removeValue(forKey: item.id)

            await startDownload(item: item)
        }
    }

    private func startDownload(item: QueuedDownload) async {
        let fileURL = "\(baseURL)/\(item.repo)/resolve/main/\(item.file)"
        let destinationPath = "\(destinationDirectory)/\(item.repo)_\(item.file)"
        let directoryURL = URL(fileURLWithPath: destinationPath).deletingLastPathComponent()

        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let activeDownload = ActiveDownload(
            id: item.id,
            repo: item.repo,
            file: item.file,
            progress: DownloadProgress(
                bytesDownloaded: 0,
                totalBytes: 0,
                percentage: 0,
                speedBytesPerSecond: 0,
                estimatedSecondsRemaining: nil
            ),
            state: .downloading,
            startedAt: Date(),
            updatedAt: Date()
        )

        active[item.id] = activeDownload

        Task {
            do {
                let path = try await downloader.download(
                    url: fileURL,
                    destinationPath: destinationPath,
                    progressHandler: { [weak self] progress in
                        Task { await self?.updateProgress(jobId: item.id, progress: progress) }
                    },
                    stateHandler: { [weak self] state in
                        Task { await self?.handleStateChange(jobId: item.id, state: state) }
                    }
                )

                await handleCompletion(jobId: item.id, path: path)
            } catch {
                await handleFailure(jobId: item.id, error: error)
            }
        }
    }

    private func updateProgress(jobId: JobId, progress: DownloadProgress) {
        if var download = active[jobId] {
            download.progress = progress
            download.updatedAt = Date()
            active[jobId] = download
        }
    }

    private func handleStateChange(jobId: JobId, state: DownloadState) {
        if var download = active[jobId] {
            download.state = state
            download.updatedAt = Date()
            active[jobId] = download
        }
    }

    private func handleCompletion(jobId: JobId, path: String) async {
        guard var download = active.removeValue(forKey: jobId) else { return }

        download.state = .completed(path: path)
        download.updatedAt = Date()
        completed[jobId] = download

        await processQueue()
    }

    private func handleFailure(jobId: JobId, error: Error) async {
        guard var download = active.removeValue(forKey: jobId) else { return }

        download.state = .failed(error.localizedDescription)
        download.updatedAt = Date()
        failed[jobId] = (download, error.localizedDescription)

        await processQueue()
    }
}

public struct DownloadStatus: Sendable {
    public let jobId: JobId
    public let repo: String
    public let file: String
    public let progress: DownloadProgress?
    public let state: DownloadState
    public let isActive: Bool
    public let queuedAt: Date

    public var isComplete: Bool {
        if case .completed = state { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }
}

public enum DownloadQueueError: Error, LocalizedError {
    case jobNotFound
    case noResumeData
    case alreadyActive
    case queueFull

    public var errorDescription: String? {
        switch self {
        case .jobNotFound:
            return "Download job not found"
        case .noResumeData:
            return "No resume data available"
        case .alreadyActive:
            return "Download is already active"
        case .queueFull:
            return "Download queue is full"
        }
    }
}
