//
//  ResumableModelDownloader.swift
//  AnigmaCLI
//
//  HTTP-based model download with pause/resume support via HTTP Range.
//

import Foundation
import CryptoKit

public enum DownloadError: Error, LocalizedError {
    case invalidURL
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case diskSpaceInsufficient(required: Int64, available: Int64)
    case networkError(Error)
    case cancelled
    case invalidResponse(Int)
    case resumeFailed
    case paused
    case alreadyPaused
    case notPaused

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch - expected: \(expected), got: \(actual)"
        case .diskSpaceInsufficient(let required, let available):
            return "Insufficient disk space - need \(formatBytes(required)), have \(formatBytes(available))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .cancelled:
            return "Download cancelled"
        case .invalidResponse(let code):
            return "Invalid HTTP response: \(code)"
        case .resumeFailed:
            return "Failed to resume download"
        case .paused:
            return "Download is paused"
        case .alreadyPaused:
            return "Download is already paused"
        case .notPaused:
            return "Download is not paused"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return String(format: "%.2f %@", value, units[unitIndex])
    }
}

public struct DownloadProgress: Sendable {
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let percentage: Double
    public let speedBytesPerSecond: Double
    public let estimatedSecondsRemaining: Double?

    public var isComplete: Bool {
        totalBytes > 0 && bytesDownloaded >= totalBytes
    }

    public var formattedProgress: String {
        "\(formatBytes(bytesDownloaded)) / \(formatBytes(totalBytes))"
    }

    public var formattedSpeed: String {
        "\(formatBytes(Int64(speedBytesPerSecond)))/s"
    }

    private func formatBytes(_ bytes: Int64) -> String {
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

public enum DownloadState: Sendable {
    case downloading
    case paused(resumeData: Data)
    case completed(path: String)
    case failed(String)
}

public actor ResumableModelDownloader {
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var progressHandlers: [String: @Sendable (DownloadProgress) -> Void] = [:]
    private var stateHandlers: [String: @Sendable (DownloadState) -> Void] = [:]
    private var startTimes: [String: Date] = [:]
    private var lastProgressUpdate: [String: (bytes: Int64, time: Date)] = [:]
    private var resumeDataStore: [String: Data] = [:]

    private let session: URLSession
    private let fileManager = FileManager.default

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 3600
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    public func download(
        url: String,
        destinationPath: String,
        expectedChecksum: String? = nil,
        resumeFrom: Data? = nil,
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void,
        stateHandler: @escaping @Sendable (DownloadState) -> Void
    ) async throws -> String {
        guard let downloadURL = URL(string: url) else {
            throw DownloadError.invalidURL
        }

        let destinationURL = URL(fileURLWithPath: destinationPath)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let taskId = url
        progressHandlers[taskId] = progressHandler
        stateHandlers[taskId] = stateHandler
        startTimes[taskId] = Date()

        stateHandler(.downloading)

        defer {
            progressHandlers.removeValue(forKey: taskId)
            stateHandlers.removeValue(forKey: taskId)
            startTimes.removeValue(forKey: taskId)
            lastProgressUpdate.removeValue(forKey: taskId)
            activeTasks.removeValue(forKey: taskId)
        }

        let downloadedURL: URL
        do {
            if let resumeData = resumeFrom {
                downloadedURL = try await resumeDownload(
                    url: downloadURL,
                    taskId: taskId,
                    resumeData: resumeData
                )
            } else {
                downloadedURL = try await performDownload(url: downloadURL, taskId: taskId)
            }
        } catch let error as DownloadError {
            stateHandler(.failed(error.localizedDescription))
            throw error
        } catch let error as URLError {
            throw DownloadError.networkError(error)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: downloadedURL, to: destinationURL)

        if let expectedChecksum = expectedChecksum {
            let actualChecksum = try computeSHA256(url: destinationURL)
            guard actualChecksum == expectedChecksum else {
                try? fileManager.removeItem(at: destinationURL)
                throw DownloadError.checksumMismatch(
                    expected: expectedChecksum,
                    actual: actualChecksum
                )
            }
        }

        stateHandler(.completed(path: destinationPath))
        return destinationPath
    }

    public func pause(url: String) async throws -> Data? {
        guard let task = activeTasks[url] else {
            throw DownloadError.notPaused
        }

        return try await withCheckedThrowingContinuation { continuation in
            task.cancel(byProducingResumeData: { resumeData in
                if let data = resumeData {
                    self.resumeDataStore[url] = data
                    self.stateHandlers[url]?(.paused(resumeData: data))
                }
                self.activeTasks.removeValue(forKey: url)
                continuation.resume(returning: resumeData)
            })
        }
    }

    public func resume(
        url: String,
        resumeData: Data,
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void,
        stateHandler: @escaping @Sendable (DownloadState) -> Void
    ) async throws -> String {
        guard let downloadURL = URL(string: url) else {
            throw DownloadError.invalidURL
        }

        progressHandlers[url] = progressHandler
        stateHandlers[url] = stateHandler
        stateHandler(.downloading)

        let path = try await download(
            url: url,
            destinationPath: resumeDataStore[url]?.path ?? "",
            resumeFrom: resumeData,
            progressHandler: progressHandler,
            stateHandler: stateHandler
        )

        resumeDataStore.removeValue(forKey: url)
        return path
    }

    public func cancel(url: String) {
        activeTasks[url]?.cancel()
        activeTasks.removeValue(forKey: url)
        resumeDataStore.removeValue(forKey: url)
        stateHandlers[url]?(.cancelled)
        stateHandlers.removeValue(forKey: url)
    }

    public func getResumeData(url: String) -> Data? {
        resumeDataStore[url]
    }

    public func getState(url: String) -> DownloadState {
        if let task = activeTasks[url], task.state == .running {
            return .downloading
        }
        if let resumeData = resumeDataStore[url] {
            return .paused(resumeData: resumeData)
        }
        return .failed("Unknown state")
    }

    private func performDownload(url: URL, taskId: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let downloadTask = session.downloadTask(with: url) { location, response, error in
                if let error = error as? URLError {
                    if error.code == .cancelled {
                        continuation.resume(throwing: DownloadError.cancelled)
                    } else {
                        continuation.resume(throwing: DownloadError.networkError(error))
                    }
                    return
                }

                if let error = error {
                    continuation.resume(throwing: DownloadError.downloadFailed(error.localizedDescription))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: DownloadError.downloadFailed("Invalid response"))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: DownloadError.invalidResponse(httpResponse.statusCode))
                    return
                }

                guard let location = location else {
                    continuation.resume(throwing: DownloadError.downloadFailed("No file location"))
                    return
                }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.moveItem(at: location, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: DownloadError.downloadFailed(error.localizedDescription))
                }
            }

            let observation = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                guard let self = self else { return }
                Task {
                    await self.updateProgress(
                        taskId: taskId,
                        bytesDownloaded: progress.completedUnitCount,
                        totalBytes: progress.totalUnitCount
                    )
                }
            }

            activeTasks[taskId] = downloadTask
            downloadTask.resume()

            withExtendedLifetime(observation) {
                _ = observation
            }
        }
    }

    private func resumeDownload(url: URL, taskId: String, resumeData: Data) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let downloadTask = session.downloadTask(with: resumeData) { location, response, error in
                if let error = error as? URLError {
                    if error.code == .cancelled {
                        continuation.resume(throwing: DownloadError.cancelled)
                    } else {
                        continuation.resume(throwing: DownloadError.networkError(error))
                    }
                    return
                }

                if let error = error {
                    continuation.resume(throwing: DownloadError.downloadFailed(error.localizedDescription))
                    return
                }

                guard let location = location else {
                    continuation.resume(throwing: DownloadError.downloadFailed("No file location"))
                    return
                }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.moveItem(at: location, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: DownloadError.downloadFailed(error.localizedDescription))
                }
            }

            let observation = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                guard let self = self else { return }
                Task {
                    await self.updateProgress(
                        taskId: taskId,
                        bytesDownloaded: progress.completedUnitCount,
                        totalBytes: progress.totalUnitCount
                    )
                }
            }

            activeTasks[taskId] = downloadTask
            downloadTask.resume()

            withExtendedLifetime(observation) {
                _ = observation
            }
        }
    }

    private func updateProgress(taskId: String, bytesDownloaded: Int64, totalBytes: Int64) {
        guard let handler = progressHandlers[taskId],
              let startTime = startTimes[taskId] else {
            return
        }

        let now = Date()
        var speed: Double = 0

        if let last = lastProgressUpdate[taskId] {
            let deltaBytes = Double(bytesDownloaded - last.bytes)
            let deltaTime = now.timeIntervalSince(last.time)
            if deltaTime > 0 {
                speed = deltaBytes / deltaTime
            }
        } else if now.timeIntervalSince(startTime) > 0 {
            speed = Double(bytesDownloaded) / now.timeIntervalSince(startTime)
        }

        lastProgressUpdate[taskId] = (bytesDownloaded, now)

        var estimatedRemaining: Double?
        if speed > 0 && totalBytes > bytesDownloaded {
            let remainingBytes = totalBytes - bytesDownloaded
            estimatedRemaining = Double(remainingBytes) / speed
        }

        let percentage = totalBytes > 0 ? Double(bytesDownloaded) / Double(totalBytes) : 0

        let progress = DownloadProgress(
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            percentage: percentage,
            speedBytesPerSecond: speed,
            estimatedSecondsRemaining: estimatedRemaining
        )

        handler(progress)
    }

    private func computeSHA256(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty {
                return false
            }
            hasher.update(data: data)
            return true
        }) { }

        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
