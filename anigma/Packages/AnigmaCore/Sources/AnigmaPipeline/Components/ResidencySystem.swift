//
//  ResidencySystem.swift
//  AnigmaCore
//
//  ECS System for memory residency lifecycle management.
//  Implements load, pin, unpin, evict, spill, reload semantics per ADR-0014.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import ContractsCore
import Foundation
import AnigmaPrimitives
import os.log

/// Errors that can occur during residency operations.
public enum ResidencyError: Error, Sendable {
    case payloadNotFound(String)
    case loadFailed(String)
    case budgetExceeded(category: String, requested: Int, available: Int)
    case payloadCorrupted(hash: String)
    case invalidState(ResidencyState)
}

/// System responsible for managing memory residency, paging, and eviction lifecycle.
public actor ResidencySystem: System, Sendable {
    private let log = Logger(subsystem: "com.anigma.core", category: "residency")
    public nonisolated var name: String { "system.memory.residency" }

    public init() {}

    public func update(world: World) async {
        // Periodic maintenance: update pressure states, process load tickets, evict if needed.
        await updatePressureStates(world: world)
        await processExpiredTickets(world: world)
        await evictUnpinnedPayloadsIfNeeded(world: world)
    }
    
    // Note: The World actor must be accessed via await since it's actor-isolated.
    // These public methods use nonisolated access where possible for ergonomics.

    // MARK: - Load Lifecycle

    /// Pin a payload in memory, preventing eviction.
    /// Real implementation will be integrated with the refinement system.
    nonisolated public func pin(entityId: EntityId) {
        // Stub: actual implementation will update ResidencyComponent via World
        log.info("ResidencySystem: Pin requested for entity \(entityId)")
    }

    /// Unpin a payload, potentially allowing eviction.
    /// Real implementation will be integrated with the refinement system.
    nonisolated public func unpin(entityId: EntityId) {
        // Stub: actual implementation will update ResidencyComponent via World
        log.info("ResidencySystem: Unpin requested for entity \(entityId)")
    }

    /// Evict a payload from memory if not pinned.
    /// Real implementation will be integrated with the refinement system.
    nonisolated public func evict(entityId: EntityId) {
        // Stub: actual implementation will update ResidencyComponent via World
        log.info("ResidencySystem: Evict requested for entity \(entityId)")
    }

    // MARK: - Pressure Management

    private func updatePressureStates(world: World) async {
        let budgets = await world.query(MemoryBudgetComponent.self)
        for (entityId, budget) in budgets {
            var updatedBudget = budget
            updatedBudget.updatePressureState()
            await world.removeComponent(entityId, MemoryBudgetComponent.self)
            await world.addComponent(entityId, updatedBudget)
        }
    }

    private func evictUnpinnedPayloadsIfNeeded(world: World) async {
        let budgets = await world.query(MemoryBudgetComponent.self)
        guard let (_, budget) = budgets.first else { return }

        // Under hard pressure, evict lowest-priority unpinned payloads.
        // This is a stub; real implementation will iterate residencies and evict.
        if case .hard = budget.pressureState {
            log.info("ResidencySystem: Hard pressure detected; eviction logic would run")
        }
    }

    private func processExpiredTickets(world: World) async {
        let references = await world.query(PayloadReferenceComponent.self)
        let now = Date()
        
        for (entityId, ref) in references {
            // Mark stale references as invalid
            if ref.lastValidatedAt.addingTimeInterval(3600) < now {
                var updated = ref
                updated.isValid = false
                await world.removeComponent(entityId, PayloadReferenceComponent.self)
                await world.addComponent(entityId, updated)
            }
        }
    }
}

// MARK: - Residency Testing Helpers

#if DEBUG
extension ResidencySystem {
    /// Test helper to inspect current residency state.
    nonisolated public func inspectResidency(entityId: EntityId) -> String {
        "inspectResidency(for entity: \(entityId)) - would return ResidencyComponent"
    }

    /// Test helper to force a specific pressure state.
    nonisolated public func setPressureState(_ state: MemoryPressure) {
        log.info("ResidencySystem: Pressure state set to \(state.rawValue) (test mode)")
    }
}
#endif
