//
//  StorageMonitor.swift
//  AnigmaCore
//
//  Storage monitoring with 20% free space warning threshold.
//

import Foundation

public actor StorageMonitor {
    public enum WarningLevel: Double, Sendable {
        case normal = 0.80
        case warning = 0.90
        case critical = 0.95
    }

    public struct Status: Sendable {
        public let totalBytes: UInt64
        public let availableBytes: UInt64
        public let usedBytes: UInt64
        public let percentageUsed: Double
        public let warningLevel: WarningLevel
        public let modelStorageBytes: UInt64
        public let cacheStorageBytes: UInt64

        public var shouldWarn: Bool {
            percentageUsed > WarningLevel.normal.rawValue
        }

        public var shouldAlert: Bool {
            percentageUsed > WarningLevel.warning.rawValue
        }

        public var formattedAvailable: String {
            formatBytes(availableBytes)
        }

        public var formattedTotal: String {
            formatBytes(totalBytes)
        }

        public var formattedUsed: String {
            formatBytes(usedBytes)
        }

        public var formattedModelStorage: String {
            formatBytes(modelStorageBytes)
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

    public struct StorageWarning: Identifiable, Sendable {
        public let id: String
        public let level: WarningLevel
        public let message: String
        public let recommendedAction: String

        public var icon: String {
            switch level {
            case .normal: return "exclamationmark.triangle"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }

    private let pathsToMonitor: [URL]
    private let warningThreshold: Double
    private let fileManager = FileManager.default

    public init(
        pathsToMonitor: [URL]? = nil,
        warningThreshold: Double = 0.80
    ) {
        if let paths = pathsToMonitor {
            self.pathsToMonitor = paths
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let home = FileManager.default.homeDirectoryForCurrentUser

            var paths: [URL] = [home]
            paths.append(contentsOf: caches)
            paths.append(contentsOf: appSupport)
            self.pathsToMonitor = paths
        }
        self.warningThreshold = warningThreshold
    }

    public func getStatus() async -> Status {
        guard let root = pathsToMonitor.first else {
            return emptyStatus()
        }

        do {
            let values = try root.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])

            let totalBytes = values.volumeTotalCapacity ?? 0
            let availableBytes = values.volumeAvailableCapacityForImportantUsage
                ?? values.volumeAvailableCapacity ?? 0
            let usedBytes = totalBytes > availableBytes ? totalBytes - availableBytes : 0
            let percentageUsed = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0

            let modelStorage = await calculateModelStorage()
            let cacheStorage = await calculateCacheStorage()

            return Status(
                totalBytes: UInt64(totalBytes),
                availableBytes: UInt64(availableBytes),
                usedBytes: UInt64(usedBytes),
                percentageUsed: percentageUsed,
                warningLevel: determineWarningLevel(percentageUsed: percentageUsed),
                modelStorageBytes: modelStorage,
                cacheStorageBytes: cacheStorage
            )
        } catch {
            return emptyStatus()
        }
    }

    public func getWarnings() async -> [StorageWarning] {
        let status = await getStatus()
        var warnings: [StorageWarning] = []

        if status.percentageUsed > WarningLevel.critical.rawValue {
            warnings.append(StorageWarning(
                id: "critical",
                level: .critical,
                message: "Critical: Only \(status.formattedAvailable) remaining",
                recommendedAction: "Delete unused models or clear cache immediately"
            ))
        } else if status.percentageUsed > WarningLevel.warning.rawValue {
            warnings.append(StorageWarning(
                id: "warning",
                level: .warning,
                message: "Warning: Only \(status.formattedAvailable) remaining",
                recommendedAction: "Consider deleting unused models or clearing cache"
            ))
        } else if status.percentageUsed > warningThreshold {
            warnings.append(StorageWarning(
                id: "normal",
                level: .normal,
                message: "Low disk space: \(status.formattedAvailable) available",
                recommendedAction: "Monitor usage and clean up if needed"
            ))
        }

        return warnings
    }

    public func checkSpaceAvailable(requiredBytes: Int64, bufferPercent: Double = 0.10) async throws {
        let status = await getStatus()
        let requiredWithBuffer = Int64(Double(requiredBytes) * (1.0 + bufferPercent))

        guard status.availableBytes >= UInt64(requiredWithBuffer) else {
            throw StorageError.insufficientSpace(
                required: requiredWithBuffer,
                available: Int64(status.availableBytes)
            )
        }
    }

    public func getVolumeInfo(for path: URL) async -> Status? {
        do {
            let values = try path.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])

            let totalBytes = values.volumeTotalCapacity ?? 0
            let availableBytes = values.volumeAvailableCapacityForImportantUsage
                ?? values.volumeAvailableCapacity ?? 0
            let usedBytes = totalBytes > availableBytes ? totalBytes - availableBytes : 0
            let percentageUsed = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0

            return Status(
                totalBytes: UInt64(totalBytes),
                availableBytes: UInt64(availableBytes),
                usedBytes: UInt64(usedBytes),
                percentageUsed: percentageUsed,
                warningLevel: determineWarningLevel(percentageUsed: percentageUsed),
                modelStorageBytes: 0,
                cacheStorageBytes: 0
            )
        } catch {
            return nil
        }
    }

    public func calculateStorageBreakdown() async -> StorageBreakdown {
        let status = await getStatus()

        return StorageBreakdown(
            totalBytes: status.totalBytes,
            availableBytes: status.availableBytes,
            usedBytes: status.usedBytes,
            systemBytes: status.usedBytes - status.modelStorageBytes - status.cacheStorageBytes,
            modelStorageBytes: status.modelStorageBytes,
            cacheStorageBytes: status.cacheStorageBytes,
            otherBytes: 0
        )
    }

    private func calculateModelStorage() async -> UInt64 {
        var total: UInt64 = 0

        for path in pathsToMonitor {
            let modelsPath = path.appendingPathComponent("Models", isDirectory: true)
            let modelsAnigmaPath = path.appendingPathComponent(".anigma", isDirectory: true)

            total += await calculateDirectorySize(at: modelsPath)
            total += await calculateDirectorySize(at: modelsAnigmaPath)
        }

        return total
    }

    private func calculateCacheStorage() async -> UInt64 {
        var total: UInt64 = 0

        for path in pathsToMonitor {
            let cachesPath = path.appendingPathComponent("Caches", isDirectory: true)
            total += await calculateDirectorySize(at: cachesPath)
        }

        return total
    }

    private func calculateDirectorySize(at url: URL) async -> UInt64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: UInt64 = 0

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let size = values.fileSize else {
                continue
            }
            total += UInt64(size)
        }

        return total
    }

    private func determineWarningLevel(percentageUsed: Double) -> WarningLevel {
        if percentageUsed > WarningLevel.critical.rawValue {
            return .critical
        } else if percentageUsed > WarningLevel.warning.rawValue {
            return .warning
        }
        return .normal
    }

    private func emptyStatus() -> Status {
        Status(
            totalBytes: 0,
            availableBytes: 0,
            usedBytes: 0,
            percentageUsed: 0,
            warningLevel: .normal,
            modelStorageBytes: 0,
            cacheStorageBytes: 0
        )
    }
}

public struct StorageBreakdown: Sendable {
    public let totalBytes: UInt64
    public let availableBytes: UInt64
    public let usedBytes: UInt64
    public let systemBytes: UInt64
    public let modelStorageBytes: UInt64
    public let cacheStorageBytes: UInt64
    public let otherBytes: UInt64

    public var percentageUsed: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    public var percentageModels: Double {
        guard usedBytes > 0 else { return 0 }
        return Double(modelStorageBytes) / Double(usedBytes) * 100
    }

    public var percentageCache: Double {
        guard usedBytes > 0 else { return 0 }
        return Double(cacheStorageBytes) / Double(usedBytes) * 100
    }
}

public enum StorageError: Error, LocalizedError {
    case insufficientSpace(required: Int64, available: Int64)
    case pathNotFound(URL)
    case permissionDenied(URL)

    public var errorDescription: String? {
        switch self {
        case .insufficientSpace(let required, let available):
            return "Insufficient disk space - need \(required) bytes, have \(available) bytes"
        case .pathNotFound(let url):
            return "Storage path not found: \(url.path)"
        case .permissionDenied(let url):
            return "Permission denied for: \(url.path)"
        }
    }
}
