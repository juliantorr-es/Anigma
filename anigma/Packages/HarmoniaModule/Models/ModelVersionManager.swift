//
//  ModelVersionManager.swift
//  HarmoniaModule
//
//  Version management, rollback support, and compatibility tracking for ML models.
//

import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation

// Simple error type for version management
public enum VersionManagerError: Error, Sendable {
    case versionNotFound(String)
    case invalidVersion(String)
    case rollbackFailed(String)
}

/// Model version information
public struct ModelVersion: Sendable, Codable {
    public let versionId: String
    public let modelId: String
    public let versionString: String
    public let releaseDate: Date
    public let downloadUrl: String?
    public let checksumSHA256: String
    public let sizeBytes: Int
    public let releaseNotes: String
    public let isStable: Bool
    public let isDeprecated: Bool
    public let compatibleFrameworks: [String]
    public let minimumMemoryMB: Int
    public let downloadedAt: Date?
    public let successfulInferences: Int
    public let failedInferences: Int

    public init(
        versionId: String,
        modelId: String,
        versionString: String,
        releaseDate: Date,
        downloadUrl: String?,
        checksumSHA256: String,
        sizeBytes: Int,
        releaseNotes: String,
        isStable: Bool,
        isDeprecated: Bool,
        compatibleFrameworks: [String],
        minimumMemoryMB: Int,
        downloadedAt: Date?,
        successfulInferences: Int,
        failedInferences: Int
    ) {
        self.versionId = versionId
        self.modelId = modelId
        self.versionString = versionString
        self.releaseDate = releaseDate
        self.downloadUrl = downloadUrl
        self.checksumSHA256 = checksumSHA256
        self.sizeBytes = sizeBytes
        self.releaseNotes = releaseNotes
        self.isStable = isStable
        self.isDeprecated = isDeprecated
        self.compatibleFrameworks = compatibleFrameworks
        self.minimumMemoryMB = minimumMemoryMB
        self.downloadedAt = downloadedAt
        self.successfulInferences = successfulInferences
        self.failedInferences = failedInferences
    }
}

/// Version compatibility information
public struct CompatibilityReport: Sendable, Codable {
    public let reportId: String
    public let fromVersion: String
    public let toVersion: String
    public let isCompatible: Bool
    public let breakingChanges: [String]
    public let deprecatedFeatures: [String]
    public let newCapabilities: [String]
    public let migrationSteps: [String]
    public let estimatedDowntimeSeconds: Int

    public init(
        reportId: String,
        fromVersion: String,
        toVersion: String,
        isCompatible: Bool,
        breakingChanges: [String],
        deprecatedFeatures: [String],
        newCapabilities: [String],
        migrationSteps: [String],
        estimatedDowntimeSeconds: Int
    ) {
        self.reportId = reportId
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.isCompatible = isCompatible
        self.breakingChanges = breakingChanges
        self.deprecatedFeatures = deprecatedFeatures
        self.newCapabilities = newCapabilities
        self.migrationSteps = migrationSteps
        self.estimatedDowntimeSeconds = estimatedDowntimeSeconds
    }
}

/// Rollback information
public struct RollbackInfo: Sendable, Codable {
    public let rollbackId: String
    public let modelId: String
    public let fromVersion: String
    public let toVersion: String
    public let reason: String
    public let timestamp: Date
    public let completionTime: TimeInterval?
    public let success: Bool
    public let errorMessage: String?

    public init(
        rollbackId: String,
        modelId: String,
        fromVersion: String,
        toVersion: String,
        reason: String,
        timestamp: Date,
        completionTime: TimeInterval?,
        success: Bool,
        errorMessage: String?
    ) {
        self.rollbackId = rollbackId
        self.modelId = modelId
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.reason = reason
        self.timestamp = timestamp
        self.completionTime = completionTime
        self.success = success
        self.errorMessage = errorMessage
    }
}

/// Version manager for ML models
public actor ModelVersionManager {
    private let dbActor: DatabaseActor?
    private var versions: [String: [ModelVersion]] = [:]
    private var rollbackHistory: [RollbackInfo] = []
    private var currentVersions: [String: String] = [:]

    public init(dbActor: DatabaseActor? = nil) {
        self.dbActor = dbActor
    }

    /// Register a new model version
    public func registerVersion(version: ModelVersion) async throws {
        let key = version.modelId
        var modelVersions = versions[key] ?? []
        modelVersions.append(version)
        versions[key] = modelVersions.sorted { versionCompare($0.versionString, $1.versionString) > 0 }
    }

    /// Get all versions for a model
    public func getVersions(modelId: String) -> [ModelVersion] {
        return (versions[modelId] ?? []).sorted { versionCompare($0.versionString, $1.versionString) > 0 }
    }

    /// Get latest stable version
    public func getLatestStableVersion(modelId: String) -> ModelVersion? {
        return getVersions(modelId: modelId).first { $0.isStable && !$0.isDeprecated }
    }

    /// Get current active version
    public func getCurrentVersion(modelId: String) -> ModelVersion? {
        guard let versionString = currentVersions[modelId] else { return nil }
        return getVersions(modelId: modelId).first { $0.versionString == versionString }
    }

    /// Set active version
    public func setActiveVersion(modelId: String, versionString: String) async throws {
        guard getVersions(modelId: modelId).contains(where: { $0.versionString == versionString }) else {
            throw VersionManagerError.versionNotFound(versionString)
        }

        currentVersions[modelId] = versionString
    }

    /// Check compatibility between versions
    public func checkCompatibility(
        modelId: String,
        fromVersion: String,
        toVersion: String
    ) -> CompatibilityReport {
        let versions = getVersions(modelId: modelId)

        guard let from = versions.first(where: { $0.versionString == fromVersion }),
              let to = versions.first(where: { $0.versionString == toVersion }) else {
            return CompatibilityReport(
                reportId: UUID().uuidString,
                fromVersion: fromVersion,
                toVersion: toVersion,
                isCompatible: false,
                breakingChanges: ["Version not found"],
                deprecatedFeatures: [],
                newCapabilities: [],
                migrationSteps: [],
                estimatedDowntimeSeconds: 0
            )
        }

        let isCompatible = versionCompare(toVersion, fromVersion) > 0
        let comparison = compareVersions(from: from, to: to)

        return CompatibilityReport(
            reportId: UUID().uuidString,
            fromVersion: fromVersion,
            toVersion: toVersion,
            isCompatible: isCompatible,
            breakingChanges: comparison.breaking,
            deprecatedFeatures: comparison.deprecated,
            newCapabilities: comparison.newFeatures,
            migrationSteps: generateMigrationSteps(from: from, to: to),
            estimatedDowntimeSeconds: estimateDowntime(from: from, to: to)
        )
    }

    /// Initiate rollback to a previous version
    public func initiateRollback(
        modelId: String,
        toVersion: String,
        reason: String
    ) async throws -> RollbackInfo {
        guard let currentVersion = getCurrentVersion(modelId: modelId) else {
            throw VersionManagerError.invalidVersion("no current version set")
        }

        let rollbackId = UUID().uuidString
        // Simulate rollback execution
        let startTime = Date()
        do {
            try await setActiveVersion(modelId: modelId, versionString: toVersion)

            let completionTime = Date().timeIntervalSince(startTime)
            let successfulRollback = RollbackInfo(
                rollbackId: rollbackId,
                modelId: modelId,
                fromVersion: currentVersion.versionString,
                toVersion: toVersion,
                reason: reason,
                timestamp: Date(),
                completionTime: completionTime,
                success: true,
                errorMessage: nil
            )

            rollbackHistory.append(successfulRollback)
            return successfulRollback
        } catch {
            let completionTime = Date().timeIntervalSince(startTime)
            let failedRollback = RollbackInfo(
                rollbackId: rollbackId,
                modelId: modelId,
                fromVersion: currentVersion.versionString,
                toVersion: toVersion,
                reason: reason,
                timestamp: Date(),
                completionTime: completionTime,
                success: false,
                errorMessage: error.localizedDescription
            )

            rollbackHistory.append(failedRollback)
            throw error
        }
    }

    /// Get rollback history
    public func getRollbackHistory(modelId: String, lastN: Int = 50) -> [RollbackInfo] {
        return Array(rollbackHistory
            .filter { $0.modelId == modelId }
            .suffix(lastN))
    }

    /// Check if upgrade is safe
    public func isSafeToUpgrade(modelId: String, toVersion: String) -> (safe: Bool, warnings: [String]) {
        guard let currentVersion = getCurrentVersion(modelId: modelId) else {
            return (false, ["No current version set"])
        }

        let compatibility = checkCompatibility(
            modelId: modelId,
            fromVersion: currentVersion.versionString,
            toVersion: toVersion
        )

        var warnings: [String] = []

        if !compatibility.isCompatible {
            warnings.append("Version upgrade is not fully compatible")
        }

        if !compatibility.breakingChanges.isEmpty {
            warnings.append("Breaking changes detected: \(compatibility.breakingChanges.count) changes")
        }

        if compatibility.estimatedDowntimeSeconds > 60 {
            warnings.append("Estimated downtime: \(compatibility.estimatedDowntimeSeconds)s")
        }

        if let newVersion = getVersions(modelId: modelId).first(where: { $0.versionString == toVersion }),
           !newVersion.isStable {
            warnings.append("Target version is not marked as stable")
        }

        return (compatibility.isCompatible, warnings)
    }

    /// Get version statistics
    public func getVersionStatistics(modelId: String) -> VersionStatistics {
        let versions = getVersions(modelId: modelId)

        let stableCount = versions.filter { $0.isStable }.count
        let deprecatedCount = versions.filter { $0.isDeprecated }.count
        let totalInferences = versions.reduce(0) { $0 + $1.successfulInferences + $1.failedInferences }

        let successCount = versions.reduce(0) { $0 + $1.successfulInferences }
        let successRate = totalInferences > 0 ? Double(successCount) / Double(totalInferences) : 0

        let newestVersion = versions.first
        let oldestVersion = versions.last

        return VersionStatistics(
            statisticsId: UUID().uuidString,
            modelId: modelId,
            totalVersions: versions.count,
            stableVersions: stableCount,
            deprecatedVersions: deprecatedCount,
            totalInferences: totalInferences,
            successRate: successRate,
            newestVersion: newestVersion?.versionString ?? "unknown",
            oldestVersion: oldestVersion?.versionString ?? "unknown",
            averageVersionAge: computeAverageAge(versions: versions)
        )
    }

    // MARK: - Private Helpers

    private func versionCompare(_ v1: String, _ v2: String) -> Int {
        // Simple semantic version comparison
        let v1Parts = v1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Parts.count, v2Parts.count)

        for i in 0..<maxLength {
            let part1 = i < v1Parts.count ? v1Parts[i] : 0
            let part2 = i < v2Parts.count ? v2Parts[i] : 0

            if part1 > part2 { return 1 }
            if part1 < part2 { return -1 }
        }

        return 0
    }

    private func compareVersions(from: ModelVersion, to: ModelVersion) -> (breaking: [String], deprecated: [String], newFeatures: [String]) {
        var breaking: [String] = []
        var deprecated: [String] = []
        var newFeatures: [String] = []

        // Parse release notes for changes (simple heuristic)
        let toNotes = to.releaseNotes.lowercased()

        if toNotes.contains("breaking") {
            breaking.append("API changes detected in release notes")
        }

        if toNotes.contains("deprecated") {
            deprecated.append("Features marked as deprecated")
        }

        if toNotes.contains("new") || toNotes.contains("added") {
            newFeatures.append("New features added")
        }

        return (breaking, deprecated, newFeatures)
    }

    private func generateMigrationSteps(from: ModelVersion, to: ModelVersion) -> [String] {
        var steps: [String] = []

        steps.append("1. Backup current model version \(from.versionString)")
        steps.append("2. Download model version \(to.versionString)")
        steps.append("3. Verify checksum: \(to.checksumSHA256.prefix(8))...")
        steps.append("4. Stop inference service")
        steps.append("5. Load new model weights")
        steps.append("6. Run compatibility tests")
        steps.append("7. Restart inference service")
        steps.append("8. Monitor performance metrics")

        return steps
    }

    private func estimateDowntime(from: ModelVersion, to: ModelVersion) -> Int {
        // Estimate based on model size and version difference
        let sizeFactor = to.sizeBytes / (1024 * 1024 * 1024)  // GB
        let versionDiff = abs(versionCompare(to.versionString, from.versionString))

        let baseTime = 30  // seconds
        let sizeTime = sizeFactor * 5  // 5 seconds per GB
        let diffFactor = versionDiff > 0 ? 10 : 0  // Major version changes add 10s

        return baseTime + Int(sizeTime) + diffFactor
    }

    private func computeAverageAge(versions: [ModelVersion]) -> TimeInterval {
        guard !versions.isEmpty else { return 0 }

        let now = Date()
        let ages = versions.map { now.timeIntervalSince($0.releaseDate) }
        return ages.reduce(0, +) / Double(ages.count)
    }
}

/// Version statistics
public struct VersionStatistics: Sendable, Codable {
    public let statisticsId: String
    public let modelId: String
    public let totalVersions: Int
    public let stableVersions: Int
    public let deprecatedVersions: Int
    public let totalInferences: Int
    public let successRate: Double
    public let newestVersion: String
    public let oldestVersion: String
    public let averageVersionAge: TimeInterval

    public init(
        statisticsId: String,
        modelId: String,
        totalVersions: Int,
        stableVersions: Int,
        deprecatedVersions: Int,
        totalInferences: Int,
        successRate: Double,
        newestVersion: String,
        oldestVersion: String,
        averageVersionAge: TimeInterval
    ) {
        self.statisticsId = statisticsId
        self.modelId = modelId
        self.totalVersions = totalVersions
        self.stableVersions = stableVersions
        self.deprecatedVersions = deprecatedVersions
        self.totalInferences = totalInferences
        self.successRate = successRate
        self.newestVersion = newestVersion
        self.oldestVersion = oldestVersion
        self.averageVersionAge = averageVersionAge
    }
}
