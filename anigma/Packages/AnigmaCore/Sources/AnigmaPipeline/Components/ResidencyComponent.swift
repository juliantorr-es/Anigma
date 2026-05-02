//
//  ResidencyComponent.swift
//  AnigmaCore
//
//  ECS Component for memory residency tracking and lifecycle management.
//  Implements the Memory Residency Contract from ADR-0014.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaPrimitives
import Foundation

/// Represents the residency state of a payload or component in memory hierarchy.
public enum ResidencyState: Codable, Sendable {
    /// Payload is not in memory; must be loaded before access.
    case unloaded
    /// Payload is loaded and available for access.
    case loaded
    /// Payload is pinned in memory; must not be evicted while pinned.
    case pinned
    /// Payload is in the process of being loaded.
    case loading
    /// Payload is in the process of being evicted.
    case evicting
    /// Payload was evicted and must be reloaded.
    case evicted
    /// Payload failed to load or was corrupted.
    case failed(String)
}

/// Represents pressure state of the memory system.
public enum MemoryPressure: String, Codable, Sendable {
    /// No pressure; normal operation.
    case normal
    /// Soft pressure; evict low-priority items, defer refinement.
    case soft
    /// Hard pressure; reject new loads, stop proactive work, preserve only critical data.
    case hard
    /// Critical pressure; in preserve-only mode.
    case critical
}

/// Load ticket for deferred payload loading with lifecycle tracking.
public struct LoadTicket: Identifiable, Sendable {
    public let id: UUID
    /// The entity that owns the payload.
    public let entityId: EntityId
    /// The payload type identifier (e.g., "pdf_page", "embedding_batch").
    public let payloadType: String
    /// Byte range or reference for partial loads.
    public let range: ClosedRange<Int>?
    /// When this ticket was created.
    public let createdAt: Date
    /// Maximum time this ticket remains valid.
    public let expiresAt: Date
    /// Priority (0=lowest, 100=highest) for load ordering.
    public let priority: Int
    /// Current state of the load request.
    public var state: ResidencyState

    public init(
        entityId: EntityId,
        payloadType: String,
        range: ClosedRange<Int>? = nil,
        priority: Int = 50,
        ttlSeconds: Int = 300
    ) {
        self.id = UUID()
        self.entityId = entityId
        self.payloadType = payloadType
        self.range = range
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(Double(ttlSeconds))
        self.priority = priority
        self.state = .unloaded
    }
}

/// Component that tracks memory residency for a payload or large data structure.
public struct ResidencyComponent: Component, Codable, Sendable {
    /// Unique identifier for this residency tracking.
    public let id: UUID

    /// Current residency state.
    public var state: ResidencyState

    /// Byte size of the payload when loaded.
    public let payloadSizeBytes: Int

    /// Content hash (SHA-256) of the immutable artifact.
    public let contentHash: String

    /// Location of the source artifact (e.g., "cold://hash" or file URL).
    public let sourceLocation: String

    /// Number of active pins on this payload.
    public var pinCount: Int = 0

    /// When this payload was last accessed.
    public var lastAccessedAt: Date

    /// Eviction priority (0=lowest, 100=highest). Higher priority resists eviction.
    public var evictionPriority: Int

    /// If true, this payload was loaded from cache and may be stale.
    public var isFromCache: Bool

    /// Policy-driven retention window. If set, payload cannot be evicted before this date.
    public var retainUntil: Date?

    public init(
        payloadSizeBytes: Int,
        contentHash: String,
        sourceLocation: String,
        evictionPriority: Int = 50
    ) {
        self.id = UUID()
        self.state = .unloaded
        self.payloadSizeBytes = payloadSizeBytes
        self.contentHash = contentHash
        self.sourceLocation = sourceLocation
        self.evictionPriority = evictionPriority
        self.lastAccessedAt = Date()
        self.isFromCache = false
    }

    /// Pin this payload in memory, preventing eviction.
    public mutating func pin() {
        pinCount += 1
        if case .loaded = state {
            state = .pinned
        }
    }

    /// Unpin this payload, allowing eviction if no other pins remain.
    public mutating func unpin() {
        pinCount = max(0, pinCount - 1)
        if pinCount == 0 {
            if case .pinned = state {
                state = .loaded
            }
        }
    }

    /// Check if this payload is currently pinned.
    public var isPinned: Bool {
        pinCount > 0
    }

    /// Check if this payload is eligible for eviction.
    public var isEvictable: Bool {
        !isPinned && (retainUntil == nil || retainUntil! < Date())
    }
}

/// Component that tracks memory budget constraints and pressure state.
public struct MemoryBudgetComponent: Component, Codable, Sendable {
    /// Unique identifier for this budget.
    public let id: UUID

    /// Maximum bytes allowed for hot ECS resident state.
    public let hotEcsResidentBudgetBytes: Int

    /// Maximum bytes for active retrieval packages in memory.
    public let retrievalPackageBudgetBytes: Int

    /// Maximum bytes for active agent context.
    public let agentContextBudgetBytes: Int

    /// Maximum bytes for trace/event buffers.
    public let traceEventBudgetBytes: Int

    /// Maximum bytes for projection caches.
    public let projectionCacheBudgetBytes: Int

    /// Maximum bytes for model/session caches.
    public let modelSessionCacheBudgetBytes: Int

    /// Maximum bytes for document refinement working sets.
    public let refinementWorkingSetBudgetBytes: Int

    /// Maximum bytes for concurrent payload loads.
    public let concurrentPayloadLoadBudgetBytes: Int

    // Current usage tracking
    public var hotEcsResidentBytesUsed: Int = 0
    public var retrievalPackageBytesUsed: Int = 0
    public var agentContextBytesUsed: Int = 0
    public var traceEventBytesUsed: Int = 0
    public var projectionCacheBytesUsed: Int = 0
    public var modelSessionCacheBytesUsed: Int = 0
    public var refinementWorkingSetBytesUsed: Int = 0
    public var concurrentPayloadLoadBytesUsed: Int = 0

    /// Current memory pressure state.
    public var pressureState: MemoryPressure = .normal

    /// Named budget owner (e.g., "refinement-pass-v1", "ui-projection-system").
    public let budgetOwner: String

    public init(
        hotEcsResidentBudgetBytes: Int = 100 * 1024 * 1024, // 100 MB
        retrievalPackageBudgetBytes: Int = 200 * 1024 * 1024, // 200 MB
        agentContextBudgetBytes: Int = 150 * 1024 * 1024, // 150 MB
        traceEventBudgetBytes: Int = 50 * 1024 * 1024, // 50 MB
        projectionCacheBudgetBytes: Int = 75 * 1024 * 1024, // 75 MB
        modelSessionCacheBudgetBytes: Int = 300 * 1024 * 1024, // 300 MB
        refinementWorkingSetBudgetBytes: Int = 250 * 1024 * 1024, // 250 MB
        concurrentPayloadLoadBudgetBytes: Int = 100 * 1024 * 1024, // 100 MB
        budgetOwner: String
    ) {
        self.id = UUID()
        self.hotEcsResidentBudgetBytes = hotEcsResidentBudgetBytes
        self.retrievalPackageBudgetBytes = retrievalPackageBudgetBytes
        self.agentContextBudgetBytes = agentContextBudgetBytes
        self.traceEventBudgetBytes = traceEventBudgetBytes
        self.projectionCacheBudgetBytes = projectionCacheBudgetBytes
        self.modelSessionCacheBudgetBytes = modelSessionCacheBudgetBytes
        self.refinementWorkingSetBudgetBytes = refinementWorkingSetBudgetBytes
        self.concurrentPayloadLoadBudgetBytes = concurrentPayloadLoadBudgetBytes
        self.budgetOwner = budgetOwner
    }

    /// Check if a load request for the given bytes would exceed soft pressure (80% threshold).
    public func wouldExceedSoftPressure(category: String, bytes: Int) -> Bool {
        let usedBytes = bytesUsedForCategory(category)
        let budgetBytes = budgetForCategory(category)
        return (usedBytes + bytes) > (budgetBytes * 80 / 100)
    }

    /// Check if a load request for the given bytes would exceed hard pressure (100% threshold).
    public func wouldExceedHardPressure(category: String, bytes: Int) -> Bool {
        let usedBytes = bytesUsedForCategory(category)
        let budgetBytes = budgetForCategory(category)
        return (usedBytes + bytes) > budgetBytes
    }

    /// Update pressure state based on current usage.
    public mutating func updatePressureState() {
        let totalUsed = hotEcsResidentBytesUsed + retrievalPackageBytesUsed + agentContextBytesUsed +
                       traceEventBytesUsed + projectionCacheBytesUsed + modelSessionCacheBytesUsed +
                       refinementWorkingSetBytesUsed + concurrentPayloadLoadBytesUsed
        let totalBudget = hotEcsResidentBudgetBytes + retrievalPackageBudgetBytes + agentContextBudgetBytes +
                         traceEventBudgetBytes + projectionCacheBudgetBytes + modelSessionCacheBudgetBytes +
                         refinementWorkingSetBudgetBytes + concurrentPayloadLoadBudgetBytes

        let percentUsed = totalBudget > 0 ? (totalUsed * 100) / totalBudget : 0

        if percentUsed >= 100 {
            pressureState = .critical
        } else if percentUsed >= 95 {
            pressureState = .hard
        } else if percentUsed >= 80 {
            pressureState = .soft
        } else {
            pressureState = .normal
        }
    }

    private func bytesUsedForCategory(_ category: String) -> Int {
        switch category {
        case "hotEcs": return hotEcsResidentBytesUsed
        case "retrieval": return retrievalPackageBytesUsed
        case "agentContext": return agentContextBytesUsed
        case "trace": return traceEventBytesUsed
        case "projection": return projectionCacheBytesUsed
        case "model": return modelSessionCacheBytesUsed
        case "refinement": return refinementWorkingSetBytesUsed
        case "concurrentLoad": return concurrentPayloadLoadBytesUsed
        default: return 0
        }
    }

    private func budgetForCategory(_ category: String) -> Int {
        switch category {
        case "hotEcs": return hotEcsResidentBudgetBytes
        case "retrieval": return retrievalPackageBudgetBytes
        case "agentContext": return agentContextBudgetBytes
        case "trace": return traceEventBudgetBytes
        case "projection": return projectionCacheBudgetBytes
        case "model": return modelSessionCacheBudgetBytes
        case "refinement": return refinementWorkingSetBudgetBytes
        case "concurrentLoad": return concurrentPayloadLoadBudgetBytes
        default: return 0
        }
    }
}

/// Component that tracks payloads referenced indirectly rather than held directly.
/// Used to enforce "payload-reference-only" rule in hot ECS paths.
public struct PayloadReferenceComponent: Component, Codable, Sendable {
    /// Unique identifier for this reference.
    public let id: UUID

    /// Content hash of the referenced payload.
    public let payloadHash: String

    /// Byte offset within the artifact where the payload begins.
    public let offsetBytes: Int

    /// Byte size of the payload.
    public let sizeBytes: Int

    /// The tier where this payload resides (hot, warm, cold).
    public let tier: String // "hot", "warm", or "cold"

    /// Whether this reference is currently valid (payload may have been evicted or changed).
    public var isValid: Bool = true

    /// When this reference was last validated.
    public var lastValidatedAt: Date

    public init(
        payloadHash: String,
        offsetBytes: Int,
        sizeBytes: Int,
        tier: String
    ) {
        self.id = UUID()
        self.payloadHash = payloadHash
        self.offsetBytes = offsetBytes
        self.sizeBytes = sizeBytes
        self.tier = tier
        self.lastValidatedAt = Date()
    }
}
