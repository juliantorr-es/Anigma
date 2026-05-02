//
//  ModelDownloader.swift
//  AnigmaCLI
//
//  HTTP-based model download system with progress tracking, resumption, and verification.
//

import Foundation
import CryptoKit
import AnigmaSidecar

public enum ModelDownloadError: Error, CustomStringConvertible {
    case invalidURL(String)
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case diskSpaceInsufficient(required: Int64, available: Int64)
    case networkError(Error)
    case cancelled
    case invalidResponse(Int)

    public var description: String {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch - expected: \(expected), got: \(actual)"
        case .diskSpaceInsufficient(let required, let available):
            return "Insufficient disk space - need \(required) bytes, have \(available) bytes"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .cancelled:
            return "Download cancelled"
        case .invalidResponse(let code):
            return "Invalid HTTP response: \(code)"
        }
    }
}

public struct ModelDownloadProgress {
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let percentage: Double
    public let speedBytesPerSecond: Double
    public let estimatedSecondsRemaining: Double?

    public var isComplete: Bool {
        bytesDownloaded >= totalBytes && totalBytes > 0
    }

    public var formattedSpeed: String {
        formatBytes(Int64(speedBytesPerSecond)) + "/s"
    }

    public var formattedProgress: String {
        "\(formatBytes(bytesDownloaded)) / \(formatBytes(totalBytes)) (\(Int(percentage * 100))%)"
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

public struct ModelDownloadTask {
    public let url: String
    public let destinationPath: String
    public let expectedChecksum: String?
    public let totalBytes: Int64?

    public init(url: String, destinationPath: String, expectedChecksum: String? = nil, totalBytes: Int64? = nil) {
        self.url = url
        self.destinationPath = destinationPath
        self.expectedChecksum = expectedChecksum
        self.totalBytes = totalBytes
    }
}

public actor ModelDownloader {
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var progressHandlers: [String: @Sendable (ModelDownloadProgress) -> Void] = [:]
    private var startTimes: [String: Date] = [:]
    private var lastProgressUpdate: [String: (bytes: Int64, time: Date)] = [:]

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
        task: ModelDownloadTask,
        progressHandler: @escaping @Sendable (ModelDownloadProgress) -> Void
    ) async throws -> String {
        guard let url = URL(string: task.url) else {
            throw ModelDownloadError.invalidURL(task.url)
        }

        let destinationURL = URL(fileURLWithPath: task.destinationPath)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Check disk space
        if let totalBytes = task.totalBytes {
            try checkDiskSpace(required: totalBytes, at: destinationURL)
        }

        // Store progress handler
        let taskId = task.url
        progressHandlers[taskId] = progressHandler
        startTimes[taskId] = Date()

        defer {
            progressHandlers.removeValue(forKey: taskId)
            startTimes.removeValue(forKey: taskId)
            lastProgressUpdate.removeValue(forKey: taskId)
            activeTasks.removeValue(forKey: taskId)
        }

        // Perform download
        let downloadedURL: URL
        do {
            downloadedURL = try await performDownload(url: url, taskId: taskId)
        } catch let error as URLError {
            throw ModelDownloadError.networkError(error)
        } catch {
            throw error
        }

        // Move to final destination
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: downloadedURL, to: destinationURL)

        // Verify checksum if provided
        if let expectedChecksum = task.expectedChecksum {
            let actualChecksum = try computeSHA256(url: destinationURL)
            guard actualChecksum == expectedChecksum else {
                try? fileManager.removeItem(at: destinationURL)
                throw ModelDownloadError.checksumMismatch(
                    expected: expectedChecksum,
                    actual: actualChecksum
                )
            }
        }

        return destinationURL.path
    }

    public func cancel(url: String) {
        activeTasks[url]?.cancel()
        activeTasks.removeValue(forKey: url)
    }

    public func cancelAll() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    private func performDownload(url: URL, taskId: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let downloadTask = session.downloadTask(with: url) { location, response, error in
                if let error = error as? URLError, error.code == .cancelled {
                    continuation.resume(throwing: ModelDownloadError.cancelled)
                    return
                }

                if let error = error {
                    continuation.resume(throwing: ModelDownloadError.networkError(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: ModelDownloadError.downloadFailed("Invalid response"))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: ModelDownloadError.invalidResponse(httpResponse.statusCode))
                    return
                }

                guard let location = location else {
                    continuation.resume(throwing: ModelDownloadError.downloadFailed("No file location"))
                    return
                }

                // Move to temporary location to prevent cleanup
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.moveItem(at: location, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: ModelDownloadError.downloadFailed(error.localizedDescription))
                }
            }

            // Track progress
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

            // Keep observation alive
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
        let elapsedSeconds = now.timeIntervalSince(startTime)

        // Calculate speed
        var speed: Double = 0
        if let last = lastProgressUpdate[taskId] {
            let deltaBytes = Double(bytesDownloaded - last.bytes)
            let deltaTime = now.timeIntervalSince(last.time)
            if deltaTime > 0 {
                speed = deltaBytes / deltaTime
            }
        } else if elapsedSeconds > 0 {
            speed = Double(bytesDownloaded) / elapsedSeconds
        }

        lastProgressUpdate[taskId] = (bytesDownloaded, now)

        // Estimate remaining time
        var estimatedRemaining: Double?
        if speed > 0 {
            let remainingBytes = totalBytes - bytesDownloaded
            estimatedRemaining = Double(remainingBytes) / speed
        }

        let percentage = totalBytes > 0 ? Double(bytesDownloaded) / Double(totalBytes) : 0

        let progress = ModelDownloadProgress(
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            percentage: percentage,
            speedBytesPerSecond: speed,
            estimatedSecondsRemaining: estimatedRemaining
        )

        handler(progress)
    }

    private func checkDiskSpace(required: Int64, at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values.volumeAvailableCapacityForImportantUsage else {
            return
        }

        let requiredWithBuffer = Int64(Double(required) * 1.1)
        guard available >= requiredWithBuffer else {
            throw ModelDownloadError.diskSpaceInsufficient(
                required: requiredWithBuffer,
                available: available
            )
        }
    }

    private func computeSHA256(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty {
                break
            }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

public actor HuggingFaceModelDownloader {
    private let downloader = ModelDownloader()
    private let baseURL = "https://huggingface.co"
    private var bridge: SidecarBridge?

    public init() {}

    internal func initialize() async {
        self.bridge = try? await SidecarBridge.create(clientName: "anigma-cli-downloader")
    }

    public func download(
        repo: String,
        revision: String = "main",
        files: [String],
        destinationDirectory: String,
        progressHandler: @escaping @Sendable (String, ModelDownloadProgress) -> Void
    ) async throws -> [String: String] {
        if let bridge = bridge {
            let response = try await bridge.installModel(modelId: repo, repo: repo, revision: revision)
            if let error = response.error {
                throw ModelDownloadError.downloadFailed(error.message)
            }
            // Return mapping of files to their new home if available
            // This is simplified since Daemon might have a different structure
            return [:] 
        }
        
        var downloadedFiles: [String: String] = [:]

        for file in files {
            let fileURL = "\(baseURL)/\(repo)/resolve/\(revision)/\(file)"
            let destinationPath = URL(fileURLWithPath: destinationDirectory)
                .appendingPathComponent(file)
                .path

            let downloadTask = ModelDownloadTask(
                url: fileURL,
                destinationPath: destinationPath
            )

            let path = try await downloader.download(task: downloadTask) { progress in
                progressHandler(file, progress)
            }

            downloadedFiles[file] = path
        }

        return downloadedFiles
    }

    public func fetchModelInfo(repo: String) async throws -> HuggingFaceModelInfo {
        let apiURL = "https://huggingface.co/api/models/\(repo)"
        guard let url = URL(string: apiURL) else {
            throw ModelDownloadError.invalidURL(apiURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelDownloadError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        return try JSONDecoder().decode(HuggingFaceModelInfo.self, from: data)
    }

    public func listFiles(repo: String, revision: String = "main") async throws -> [HuggingFaceFileInfo] {
        let apiURL = "https://huggingface.co/api/models/\(repo)/tree/\(revision)"
        guard let url = URL(string: apiURL) else {
            throw ModelDownloadError.invalidURL(apiURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelDownloadError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        return try JSONDecoder().decode([HuggingFaceFileInfo].self, from: data)
    }

    public func cancel(repo: String, file: String) {
        let fileURL = "\(baseURL)/\(repo)/resolve/main/\(file)"
        Task {
            await downloader.cancel(url: fileURL)
        }
    }

    public func cancelAll() {
        Task {
            await downloader.cancelAll()
        }
    }
}

public struct HuggingFaceModelInfo: Codable, Sendable {
    public let modelId: String
    public let author: String?
    public let downloads: Int?
    public let likes: Int?
    public let tags: [String]?
    public let pipeline_tag: String?
    public let library_name: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "id"
        case author
        case downloads
        case likes
        case tags
        case pipeline_tag
        case library_name
    }
}

public struct HuggingFaceFileInfo: Codable, Sendable {
    public let path: String
    public let size: Int64?
    public let type: String
    public let oid: String?

    public var isFile: Bool {
        type == "file"
    }
}
