//
//  PolicyEvolutionFramework.swift
//  HarmoniaModule
//
//  Policy evolution framework for Phase 9.3.
//  Enables versioned policy updates with rollback and A/B testing.
//

import Foundation

/// Versioned scoring policy for Phase 9.3.
/// Tracks policy versions with explicit rollback and evolution control.
public struct VersionedScoringPolicy: Codable, Sendable {
    public let version: String
    public let majorVersion: Int
    public let minorVersion: Int
    public let patchVersion: Int
    public let releaseDate: Int64
    public let errorWeight: Int
    public let warningWeight: Int
    public let complexityWeight: Int
    public let recencyBonus: Int
    public let description: String
    public let experimental: Bool

    public init(
        majorVersion: Int,
        minorVersion: Int,
        patchVersion: Int,
        releaseDate: Int64,
        errorWeight: Int,
        warningWeight: Int,
        complexityWeight: Int,
        recencyBonus: Int,
        description: String,
        experimental: Bool = false
    ) {
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.patchVersion = patchVersion
        self.releaseDate = releaseDate
        self.errorWeight = errorWeight
        self.warningWeight = warningWeight
        self.complexityWeight = complexityWeight
        self.recencyBonus = recencyBonus
        self.description = description
        self.experimental = experimental

        // Generate semantic version string
        self.version = "v\(majorVersion).\(minorVersion).\(patchVersion)"
    }

    /// Create a new version from existing policy.
    public func nextMinorVersion(
        changeReason: String,
        errorWeight: Int? = nil,
        warningWeight: Int? = nil,
        complexityWeight: Int? = nil,
        recencyBonus: Int? = nil
    ) -> VersionedScoringPolicy {
        return VersionedScoringPolicy(
            majorVersion: majorVersion,
            minorVersion: minorVersion + 1,
            patchVersion: 0,
            releaseDate: Int64(Date().timeIntervalSince1970),
            errorWeight: errorWeight ?? self.errorWeight,
            warningWeight: warningWeight ?? self.warningWeight,
            complexityWeight: complexityWeight ?? self.complexityWeight,
            recencyBonus: recencyBonus ?? self.recencyBonus,
            description: changeReason
        )
    }
}

/// Policy registry for managing multiple versions.
public struct Phase9PolicyRegistry: Sendable {
    private var policies: [String: VersionedScoringPolicy]
    private var currentPolicyVersion: String

    public init() {
        self.policies = [:]
        self.currentPolicyVersion = ""

        // Register default policy v1.0.0
        let defaultPolicy = VersionedScoringPolicy(
            majorVersion: 1,
            minorVersion: 0,
            patchVersion: 0,
            releaseDate: Int64(Date().timeIntervalSince1970),
            errorWeight: 100,
            warningWeight: 50,
            complexityWeight: -10,
            recencyBonus: 5,
            description: "Phase 9.1 baseline scoring policy"
        )

        policies[defaultPolicy.version] = defaultPolicy
        currentPolicyVersion = defaultPolicy.version
    }

    /// Register a new policy version.
    public mutating func registerPolicy(_ policy: VersionedScoringPolicy) throws {
        // Validate version doesn't already exist
        guard policies[policy.version] == nil else {
            throw PolicyRegistryError.versionAlreadyExists(policy.version)
        }

        // Validate version is higher than current
        guard isVersionNewer(policy.version, than: currentPolicyVersion) else {
            throw PolicyRegistryError.versionNotProgressive(
                new: policy.version,
                current: currentPolicyVersion
            )
        }

        policies[policy.version] = policy
    }

    /// Get current active policy.
    public func getCurrentPolicy() -> VersionedScoringPolicy? {
        return policies[currentPolicyVersion]
    }

    /// Get policy by version string.
    public func getPolicy(version: String) -> VersionedScoringPolicy? {
        return policies[version]
    }

    /// Switch to a different policy version.
    public mutating func switchToVersion(_ version: String) throws {
        guard policies[version] != nil else {
            throw PolicyRegistryError.versionNotFound(version)
        }

        currentPolicyVersion = version
    }

    /// Rollback to previous version.
    public mutating func rollback() throws {
        guard getCurrentPolicy() != nil else {
            throw PolicyRegistryError.noPolicyActive
        }

        // Find previous version
        let sortedVersions = policies.keys.sorted { v1, v2 in
            isVersionNewer(v1, than: v2)
        }

        guard let currentIndex = sortedVersions.firstIndex(of: currentPolicyVersion),
              currentIndex > 0 else {
            throw PolicyRegistryError.cannotRollback("No previous version available")
        }

        currentPolicyVersion = sortedVersions[currentIndex - 1]
    }

    /// Check if version1 is newer than version2.
    private func isVersionNewer(_ version1: String, than version2: String) -> Bool {
        let components1 = parseVersion(version1)
        let components2 = parseVersion(version2)

        if components1.major != components2.major {
            return components1.major > components2.major
        }
        if components1.minor != components2.minor {
            return components1.minor > components2.minor
        }
        return components1.patch > components2.patch
    }

    /// Parse semantic version string.
    private func parseVersion(_ version: String) -> (major: Int, minor: Int, patch: Int) {
        let cleaned = version.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let components = cleaned.split(separator: ".").compactMap { Int($0) }

        let major = !components.isEmpty ? components[0] : 0
        let minor = components.count > 1 ? components[1] : 0
        let patch = components.count > 2 ? components[2] : 0

        return (major, minor, patch)
    }
}

/// A/B test configuration for policy experimentation.
public struct PolicyABTest: Sendable {
    public let testId: String
    public let controlVersion: String
    public let experimentalVersion: String
    public let splitPercentage: Int // 0-100
    public let startTime: Int64
    public let endTime: Int64
    public let metrics: [String: String]

    public init(
        testId: String,
        controlVersion: String,
        experimentalVersion: String,
        splitPercentage: Int,
        startTime: Int64,
        endTime: Int64
    ) {
        self.testId = testId
        self.controlVersion = controlVersion
        self.experimentalVersion = experimentalVersion
        self.splitPercentage = max(0, min(100, splitPercentage))
        self.startTime = startTime
        self.endTime = endTime
        self.metrics = [:]
    }

    /// Determine which version to use based on deterministic assignment.
    public func assignVersion(sessionId: String) -> String {
        // Use session ID hash for deterministic assignment
        let hash = sessionId.hashValue
        let assigned = (abs(hash) % 100) < splitPercentage
        return assigned ? experimentalVersion : controlVersion
    }
}

/// Policy effectiveness metrics tracker.
public actor PolicyMetricsTracker {

    private var metrics: [String: PolicyMetric] = [:]

    /// Track a metric for a policy version.
    public func recordMetric(
        version: String,
        metricName: String,
        value: Double
    ) {
        let key = "\(version)-\(metricName)"

        if metrics[key] == nil {
            metrics[key] = PolicyMetric(
                version: version,
                metricName: metricName,
                values: []
            )
        }

        metrics[key]?.values.append(value)
    }

    /// Get average metric for a version.
    public func getAverageMetric(version: String, metricName: String) -> Double? {
        let key = "\(version)-\(metricName)"
        guard let metric = metrics[key], !metric.values.isEmpty else {
            return nil
        }

        return metric.values.reduce(0, +) / Double(metric.values.count)
    }

    /// Compare metrics between two versions.
    public func compareVersions(
        version1: String,
        version2: String,
        metricName: String
    ) -> VersionComparison? {
        guard let avg1 = getAverageMetric(version: version1, metricName: metricName),
              let avg2 = getAverageMetric(version: version2, metricName: metricName) else {
            return nil
        }

        let percentDifference = ((avg2 - avg1) / avg1) * 100

        return VersionComparison(
            version1: version1,
            version2: version2,
            metric: metricName,
            value1: avg1,
            value2: avg2,
            percentDifference: percentDifference
        )
    }
}

/// Metric tracking structure.
public struct PolicyMetric: Sendable {
    public let version: String
    public let metricName: String
    public var values: [Double]
}

/// Result of comparing two policy versions.
public struct VersionComparison: Sendable {
    public let version1: String
    public let version2: String
    public let metric: String
    public let value1: Double
    public let value2: Double
    public let percentDifference: Double

    public var isImproved: Bool {
        // Positive difference means version2 is better
        return percentDifference > 0
    }
}

/// Errors in policy evolution.
public enum PolicyRegistryError: Error, LocalizedError {
    case versionAlreadyExists(String)
    case versionNotFound(String)
    case versionNotProgressive(new: String, current: String)
    case noPolicyActive
    case cannotRollback(String)

    public var localizedDescription: String? {
        switch self {
        case .versionAlreadyExists(let version):
            return "Policy version \(version) already registered"
        case .versionNotFound(let version):
            return "Policy version \(version) not found"
        case .versionNotProgressive(let new, let current):
            return "New version \(new) must be higher than current \(current)"
        case .noPolicyActive:
            return "No policy version is active"
        case .cannotRollback(let reason):
            return "Cannot rollback: \(reason)"
        }
    }
}
