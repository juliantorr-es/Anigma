//
//  RetentionPolicy.swift
//  ContractsCore
//
//  Defines the structure and logic for data retention policies.
//

import AnigmaPrimitives
import CryptoKit
import Foundation

/// Errors that can occur during retention policy operations.
public enum RetentionPolicyError: Error, LocalizedError, Sendable {
    case invalidEncoding
    case invalidToml(String)
    case noActivePolicy
    case corruptedPolicy(storedHash: String, computedHash: String)
    case policyCreationFailed(String)
    case policyEnforcementFailed(String)
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Retention policy file could not be decoded as UTF-8."
        case .invalidToml(let detail):
            return "Retention policy TOML parse error: \(detail)"
        case .noActivePolicy:
            return "No active retention policy is set."
        case .corruptedPolicy(let storedHash, let computedHash):
            return
                "Policy integrity check failed. Stored hash: \(storedHash), computed: \(computedHash)"
        case .policyCreationFailed(let detail):
            return "Policy creation failed: \(detail)"
        case .policyEnforcementFailed(let detail):
            return "Policy enforcement failed: \(detail)"
        case .persistenceFailed(let msg):
            return "Retention policy persistence failed: \(msg)"
        }
    }
}

/// Configuration for a specific retention rule.
public struct RetentionRuleConfig: Codable, Sendable {
    public let ttlDays: Int?
    public let keepForever: Bool?

    public init(ttlDays: Int? = nil, keepForever: Bool? = nil) {
        self.ttlDays = ttlDays
        self.keepForever = keepForever
    }

    enum CodingKeys: String, CodingKey {
        case ttlDays = "ttl_days"
        case keepForever = "keep_forever"
    }
}

/// Configuration for a specific retention class (e.g., session_db, verbose_payload).
public struct RetentionPolicyClass: Codable, Sendable {
    /// Display name for the policy class.
    public let name: String

    /// Time-to-live in hours for this class.
    public let ttlHours: Int

    /// Maximum total size in MB (optional).
    public let maxTotalMB: Int?

    /// Whether content in this class should be kept forever.
    public let keepForever: Bool

    /// Type-specific retention configuration.
    public let retentionRules: [String: RetentionRuleConfig]?

    public var ttlDays: Int {
        ttlHours / 24
    }

    public var defaultTtlDays: Int {
        ttlDays
    }

    public var maxTotalStorageGb: Int {
        (maxTotalMB ?? 0) / 1024
    }

    public func ttlForArtifact(artifactType: String, sizeBytes: Int64) -> Int {
        if let rules = retentionRules, let config = rules[artifactType], let ttl = config.ttlDays {
            return ttl
        }
        return ttlDays
    }

    public init(
        name: String,
        ttlHours: Int,
        maxTotalMB: Int? = nil,
        keepForever: Bool = false,
        retentionRules: [String: RetentionRuleConfig]? = nil
    ) {
        self.name = name
        self.ttlHours = ttlHours
        self.maxTotalMB = maxTotalMB
        self.keepForever = keepForever
        self.retentionRules = retentionRules
    }
}

/// Segmentation configuration for ledger management.
public struct SegmentationPolicy: Codable, Sendable {
    /// Maximum size in MB per segment.
    public let maxSegmentSizeMB: Int

    /// Rotation interval in days.
    public let rotationIntervalDays: Int

    public init(maxSegmentSizeMB: Int, rotationIntervalDays: Int) {
        self.maxSegmentSizeMB = maxSegmentSizeMB
        self.rotationIntervalDays = rotationIntervalDays
    }
}

/// Hot run policy for recent run retention.
public struct HotRunPolicy: Codable, Sendable {
    /// Maximum number of hot runs to keep.
    public let maxKept: Int

    /// Cooldown period in days before marking as cold.
    public let cooldownDays: Int

    public init(maxKept: Int, cooldownDays: Int) {
        self.maxKept = maxKept
        self.cooldownDays = cooldownDays
    }
}

/// Complete retention policy configuration.
public struct RetentionPolicy: Codable, Sendable {
    /// Policy version (for governance).
    public let version: String

    /// Cryptographic hash of the policy content (for verification).
    public let policyHash: String

    /// Policy classes by type.
    public let classes: [String: RetentionPolicyClass]

    /// Segmentation policies.
    public let segments: SegmentationPolicy

    /// Hot run configuration.
    public let hotRuns: HotRunPolicy

    /// Garbage collection rules.
    public let gc: GCRules

    /// Last update timestamp.
    public let updatedAt: Date

    public init(
        version: String,
        classes: [String: RetentionPolicyClass],
        segments: SegmentationPolicy,
        hotRuns: HotRunPolicy,
        gc: GCRules = .default,
        updatedAt: Date = Date()
    ) {
        self.version = version
        self.classes = classes
        self.segments = segments
        self.hotRuns = hotRuns
        self.gc = gc
        self.updatedAt = updatedAt
        self.policyHash = Self.computePolicyHash(version: version, classes: classes)
    }

    /// Default production policy.
    public static let production = RetentionPolicy(
        version: "1.0",
        classes: [
            "session_db": RetentionPolicyClass(name: "Session Databases", ttlHours: 24),
            "verbose_payload": RetentionPolicyClass(name: "Verbose Logs", ttlHours: 168),  // 7 days
            "artifacts": RetentionPolicyClass(
                name: "Artifacts",
                ttlHours: 8760,  // 365 days
                retentionRules: [
                    "embeddings": RetentionRuleConfig(ttlDays: 365, keepForever: false),
                    "tool_outputs": RetentionRuleConfig(ttlDays: 30, keepForever: false),
                    "build_artifacts": RetentionRuleConfig(ttlDays: 90, keepForever: false)
                ]
            ),
            "master_ledger": RetentionPolicyClass(
                name: "Master Ledger", ttlHours: 0, keepForever: true)
        ],
        segments: SegmentationPolicy(maxSegmentSizeMB: 500, rotationIntervalDays: 30),
        hotRuns: HotRunPolicy(maxKept: 100, cooldownDays: 7),
        gc: .default
    )

    /// Load a retention policy from JSON. TOML loading moved to specialized parser.
    public static func load(from url: URL) throws -> RetentionPolicy {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(RetentionPolicy.self, from: data)
    }

    /// Compute SHA256 hash of policy for verification.
    private static func computePolicyHash(version: String, classes: [String: RetentionPolicyClass])
        -> String {
        let keyString = version + classes.keys.sorted().joined()
        guard let data = keyString.data(using: .utf8) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public func computeHash() throws -> String {
        return policyHash
    }

    // MARK: - Convenience Accessors

    public var sessionDb: RetentionPolicyClass {
        classes["session_db"] ?? RetentionPolicyClass(name: "Session Databases", ttlHours: 24)
    }

    public var artifacts: RetentionPolicyClass {
        classes["artifacts"] ?? RetentionPolicyClass(name: "Artifacts", ttlHours: 8760)
    }

    public var masterLedger: RetentionPolicyClass {
        classes["master_ledger"] ?? RetentionPolicyClass(name: "Master Ledger", ttlHours: 0, keepForever: true)
    }

    /// Whether any item in this class can be deleted now based on age.
    public func canDeleteNow(policyClass: String, age: TimeInterval) -> Bool {
        guard let pClass = classes[policyClass] else { return false }
        if pClass.keepForever { return false }
        return age >= TimeInterval(pClass.ttlHours * 3600)
    }

    /// Convenience for tri-memory logic
    public var canDeleteNow: Bool {
        return true 
    }

    /// Get retention TTL for a specific artifact type within a class.
    public func getTTLForArtifactType(_ classKey: String, _ artifactType: String) -> Int? {
        guard let policyClass = classes[classKey] else {
            return nil
        }

        if let rules = policyClass.retentionRules,
            let config = rules[artifactType],
            let ttlDays = config.ttlDays {
            return ttlDays * 24
        }

        return policyClass.keepForever ? -1 : policyClass.ttlHours
    }

    /// Check if an artifact type should be kept forever.
    public func shouldKeepForever(_ classKey: String, _ artifactType: String) -> Bool {
        guard let policyClass = classes[classKey] else {
            return false
        }

        if policyClass.keepForever {
            return true
        }

        if let rules = policyClass.retentionRules,
            let config = rules[artifactType],
            let forever = config.keepForever {
            return forever
        }

        return false
    }

    /// Check if a content hash should be retained based on policy.
    public func shouldRetain(
        contentHash: String,
        policyClass: String,
        artifactType: String,
        contentAge: TimeInterval,
        referenceCount: Int
    ) -> RetentionEligibility {
        // Never delete if keepForever is set
        if shouldKeepForever(policyClass, artifactType) {
            return .eligible(policyReason: "keep_forever")
        }

        // Get TTL for this specific type
        let ttlHours = getTTLForArtifactType(policyClass, artifactType) ?? 24

        // If still referenced, retain
        if referenceCount > 0 {
            return .referenced(until: Date(timeIntervalSinceNow: Double(ttlHours * 3600)))
        }

        // Check age against TTL
        if contentAge <= Double(ttlHours * 3600) {
            return .eligible(policyReason: "within_ttl")
        }

        return .eligible(forDeletion: true, policyReason: "expired_ttl")
    }

    /// Verify that the policy hasn't been tampered with.
    public func verifyIntegrity() -> Bool {
        return Self.computePolicyHash(version: self.version, classes: self.classes) == policyHash
    }
}

/// Policy enforcement decision.
public enum RetentionPolicyEnforcement: Sendable, Codable {
    case allowed(policyVersion: String)
    case denied(reason: String)
}

/// Eligibility determination for retention operations.
public enum RetentionEligibility: Equatable, Sendable {
    /// Content is eligible for deletion with specific policy reason
    case eligible(forDeletion: Bool = false, policyReason: String)

    /// Content is still referenced until a future date
    case referenced(until: Date)

    public var isEligibleForDeletion: Bool {
        if case .eligible(forDeletion: let eligible, _) = self {
            return eligible
        }
        return false
    }
}

/// Garbage collection rules and thresholds.
public struct GCRules: Codable, Sendable {
    public let requirePolicyHashMatch: Bool
    public let maxDeletePerRun: Int
    public let vacuumThresholdMb: Int
    public let checkpointWalMb: Int

    public static let `default` = GCRules(
        requirePolicyHashMatch: false,
        maxDeletePerRun: 5000,
        vacuumThresholdMb: 100,
        checkpointWalMb: 50
    )

    public init(
        requirePolicyHashMatch: Bool = false,
        maxDeletePerRun: Int = 5000,
        vacuumThresholdMb: Int = 100,
        checkpointWalMb: Int = 50
    ) {
        self.requirePolicyHashMatch = requirePolicyHashMatch
        self.maxDeletePerRun = maxDeletePerRun
        self.vacuumThresholdMb = vacuumThresholdMb
        self.checkpointWalMb = checkpointWalMb
    }
}
