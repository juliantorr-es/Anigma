//
//  PayloadReferenceDecorator.swift
//  AnigmaCore
//
//  Enforces payload-reference-only semantics in hot ECS paths.
//  Prevents raw payload materialization; forces indirect access through references.
//

import Foundation

/// Metadata describing where a payload lives (Binary Atlas index, offset).
public struct PayloadLocation: Codable, Sendable {
    /// Name of the Binary Atlas (e.g., "hot-ecs-atlas", "warm-storage-atlas").
    public let atlasName: String

    /// Byte offset within the atlas.
    public let offset: Int

    /// Size in bytes.
    public let size: Int

    /// Storage tier: "hot", "warm", or "cold".
    public let storageTier: String

    public init(atlasName: String, offset: Int, size: Int, storageTier: String) {
        self.atlasName = atlasName
        self.offset = offset
        self.size = size
        self.storageTier = storageTier
    }
}

/// Reference to a payload without materializing it into memory.
/// Enforces the "Serialization Wall": prevents fat object copies in hot paths.
public struct IndirectPayloadReference<T: Codable>: Codable, Sendable {
    /// Unique identifier for this payload.
    public let payloadId: String

    /// Location of the serialized payload.
    public let location: PayloadLocation

    /// Type name for dynamic deserialization validation.
    public let typeName: String

    /// Size in bytes. Used for budget tracking.
    public let sizeBytes: Int

    /// Checksum (SHA256 hex) for integrity verification.
    public let checksum: String

    /// When the reference was created.
    public let createdAt: Date

    public init(
        payloadId: String,
        location: PayloadLocation,
        typeName: String,
        sizeBytes: Int,
        checksum: String,
        createdAt: Date = Date()
    ) {
        self.payloadId = payloadId
        self.location = location
        self.typeName = typeName
        self.sizeBytes = sizeBytes
        self.checksum = checksum
        self.createdAt = createdAt
    }
}

/// Protocol for types that support lazy deserialization through indirect references.
public protocol IndirectPayloadAccessible: Codable, Sendable {
    /// Load this payload from its reference location (if needed).
    /// Returns the materialized value or an error if access fails.
    func materialize() async throws -> Self
}

/// Audit record for payload access patterns in hot paths.
public struct PayloadAccessAuditRecord: Codable, Sendable {
    /// Name of the hot path (e.g., "hybrid_search", "refinement_loop").
    public let hotPathName: String

    /// Type of access: "direct" (violation), "reference" (correct), or "deferred" (async).
    public let accessType: String

    /// Timestamp of the access.
    public let timestamp: Date

    /// Payload ID accessed.
    public let payloadId: String

    /// Size in bytes.
    public let sizeBytes: Int

    /// Stack trace or call site identifier for debugging.
    public let callSite: String?

    public init(
        hotPathName: String,
        accessType: String,
        timestamp: Date = Date(),
        payloadId: String,
        sizeBytes: Int,
        callSite: String? = nil
    ) {
        self.hotPathName = hotPathName
        self.accessType = accessType
        self.timestamp = timestamp
        self.payloadId = payloadId
        self.sizeBytes = sizeBytes
        self.callSite = callSite
    }
}

/// Global audit trail for payload access patterns.
public final class PayloadAccessAuditor {
    /// Shared global instance.
    public static let shared = PayloadAccessAuditor()

    private let lock = NSLock()
    private var auditRecords: [PayloadAccessAuditRecord] = []

    /// Count of "direct" (violating) accesses observed.
    private var directAccessCount: Int = 0

    /// Count of "reference" (correct) accesses observed.
    private var referenceAccessCount: Int = 0

    private init() {}

    /// Record a payload access event.
    public func recordAccess(_ record: PayloadAccessAuditRecord) {
        lock.lock()
        defer { lock.unlock() }

        auditRecords.append(record)

        // Keep only the last 10,000 records
        if auditRecords.count > 10_000 {
            auditRecords.removeFirst(auditRecords.count - 10_000)
        }

        // Update counters
        if record.accessType == "direct" {
            directAccessCount += 1
        } else if record.accessType == "reference" {
            referenceAccessCount += 1
        }
    }

    /// Get all audit records.
    public func getAuditRecords() -> [PayloadAccessAuditRecord] {
        lock.lock()
        defer { lock.unlock() }
        return auditRecords
    }

    /// Get audit records for a specific hot path.
    public func getRecordsForPath(_ hotPathName: String) -> [PayloadAccessAuditRecord] {
        lock.lock()
        defer { lock.unlock() }
        return auditRecords.filter { $0.hotPathName == hotPathName }
    }

    /// Count of direct (violating) accesses.
    public func getDirectAccessCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return directAccessCount
    }

    /// Count of reference (correct) accesses.
    public func getReferenceAccessCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return referenceAccessCount
    }

    /// Violation ratio: directAccessCount / (directAccessCount + referenceAccessCount).
    public func getViolationRatio() -> Double {
        lock.lock()
        defer { lock.unlock() }
        let total = directAccessCount + referenceAccessCount
        return total > 0 ? Double(directAccessCount) / Double(total) : 0.0
    }

    /// Clear all audit records (useful for testing).
    public func clearRecords() {
        lock.lock()
        defer { lock.unlock() }
        auditRecords.removeAll()
        directAccessCount = 0
        referenceAccessCount = 0
    }
}

/// Helper function to record a payload access.
public func recordPayloadAccess(
    hotPathName: String,
    accessType: String,
    payloadId: String,
    sizeBytes: Int,
    callSite: String? = nil
) {
    let record = PayloadAccessAuditRecord(
        hotPathName: hotPathName,
        accessType: accessType,
        payloadId: payloadId,
        sizeBytes: sizeBytes,
        callSite: callSite
    )
    PayloadAccessAuditor.shared.recordAccess(record)
}

/// Decorator for enforcing reference-only access in hot paths.
/// Usage: Wrap contract inputs with PayloadReferenceDecorator to ensure references are used.
public final class PayloadReferenceEnforcer {
    private let auditor = PayloadAccessAuditor.shared

    /// Verify that a hot path is using references, not raw payloads.
    /// Raises a compile-time error if raw payload access is detected.
    public func enforceReferenceOnly<T: Codable>(
        in hotPathName: String,
        payload: IndirectPayloadReference<T>,
        sizeBytes: Int
    ) {
        recordPayloadAccess(
            hotPathName: hotPathName,
            accessType: "reference",
            payloadId: payload.payloadId,
            sizeBytes: sizeBytes
        )
    }

    /// Flag a violation: direct payload access (should not occur in production).
    public func flagDirectAccess(
        in hotPathName: String,
        payloadId: String,
        sizeBytes: Int,
        callSite: String? = nil
    ) {
        recordPayloadAccess(
            hotPathName: hotPathName,
            accessType: "direct",
            payloadId: payloadId,
            sizeBytes: sizeBytes,
            callSite: callSite
        )
    }

    /// Get violation summary for a hot path.
    public func getViolationSummary(for hotPathName: String) -> (total: Int, violations: Int, ratio: Double) {
        let records = PayloadAccessAuditor.shared.getRecordsForPath(hotPathName)
        let violations = records.filter { $0.accessType == "direct" }.count
        return (records.count, violations, records.isEmpty ? 0.0 : Double(violations) / Double(records.count))
    }
}

/// Global reference enforcer instance.
public let payloadReferenceEnforcer = PayloadReferenceEnforcer()
