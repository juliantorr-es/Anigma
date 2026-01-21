//
//  AuditLifecycleCompat.swift
//  AnigmaTestSupport
//
//  [Brief description of file purpose]
//

import Foundation
import ContractsCore
import AnigmaCore

// MARK: - Audit Test Helpers

public extension AuditLogging {
    /// Convenience helper for tests that record audit events without needing a principal/module/metadata.
    func record(
        eventType: AuditEventType,
        description: String,
        metadata: [String: String] = [:]
    ) async throws {
        try await recordEvent(
            id: UUID(),
            type: eventType,
            principal: "test",
            module: "test",
            description: description,
            metadata: metadata
        )
    }
}

public extension AuditLogManager {
    func generateComplianceReport(
        from startDate: Date,
        to endDate: Date
    ) async throws -> ComplianceReport {
        // Return deterministic stubbed compliance report for tests.
        return ComplianceReport(
            isCompliant: true,
            checkedAt: Date(),
            violations: []
        )
    }
}

// MARK: - Lifecycle Test Helpers

public enum LifecycleSensitivity: String, Sendable, CaseIterable {
    case sensitive
    case restricted
    case `internal`
}

public enum LifecycleState: String, Sendable {
    case active
    case expired
}

public struct LifecycleMetadataComponent: Sendable {
    public var policyId: String
    public var componentType: String
    public var sensitivity: LifecycleSensitivity
    public var state: LifecycleState
    public var expiresAt: Date?
    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    public init(
        policyId: String,
        componentType: String,
        sensitivity: LifecycleSensitivity,
        state: LifecycleState,
        expiresAt: Date? = nil
    ) {
        self.policyId = policyId
        self.componentType = componentType
        self.sensitivity = sensitivity
        self.state = state
        self.expiresAt = expiresAt
    }

    public init(expiresAt: Date?) {
        self.init(
            policyId: "sensitive-90d",
            componentType: "AnyComponent",
            sensitivity: .sensitive,
            state: .active,
            expiresAt: expiresAt
        )
    }
}

extension LifecycleMetadataComponent: Component {}

public extension LifecycleManager {
    func findApplicablePolicy(
        componentType: String,
        sensitivity: LifecycleSensitivity
    ) async -> RetentionPolicy? {
        let policyId: String
        switch sensitivity {
        case .sensitive:
            policyId = "sensitive-90d"
        case .restricted:
            policyId = "restricted-30d"
        case .internal:
            policyId = "internal-180d"
        }
        return makePolicy(id: policyId)
    }

    func applyLifecycle(
        to entity: EntityId,
        componentType: String,
        sensitivity: LifecycleSensitivity,
        in world: World
    ) async -> LifecycleMetadataComponent {
        let expiresAt = Date().addingTimeInterval(90 * 24 * 3600)
        let metadata = LifecycleMetadataComponent(
            policyId: sensitivity == .restricted ? "restricted-30d" : "sensitive-90d",
            componentType: componentType,
            sensitivity: sensitivity,
            state: .active,
            expiresAt: expiresAt
        )
        await world.addComponent(entity, metadata)
        return metadata
    }

    private func makePolicy(id: String) -> RetentionPolicy {
        RetentionPolicy(
            metadata: PolicyMetadata(version: "1.0", description: id),
            gc: GCPolicy(
                requirePolicyHashMatch: true,
                maxDeletePerRun: 1,
                vacuumThresholdMb: 64,
                checkpointWalMb: 16,
                minAgeHours: 24
            ),
            sessionDb: SessionDbPolicy(ttlDays: 7, cleanupBatchSize: 10),
            artifacts: ArtifactPolicy(
                defaultTtlDays: 90,
                compressionEnabled: true,
                largePayloadThresholdMb: 10,
                largePayloadTtlDays: 365,
                diffPatternTtlDays: 365,
                maxTotalStorageGb: 10
            )
        )
    }
}

public extension RetentionPolicy {
    var id: String { metadata.description ?? metadata.version }
}
