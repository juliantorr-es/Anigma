//
//  MemorySystem.swift
//  AnigmaCore
//
//  ECS System for managing governed MemoryComponents.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import ContractsCore
import InferenceCore
import Foundation
import AnigmaPrimitives
import os.log

/// System responsible for the lifecycle and retrieval of governed memories.
public actor MemorySystem: System, Sendable {
    private let log = Logger(subsystem: "com.anigma.core", category: "memory")
    public nonisolated var name: String { "system.governance.memory" }

    public init() {}

    public func update(world: World) async {
        await pruneExpired(world: world)
    }

    /// Store a new memory for an entity (e.g., a User).
    public func storeMemory(
        fact: String,
        source: String,
        target: EntityId,
        tags: Set<String> = [],
        world: World,
        context: ExecutionContext
    ) async throws {
        // 1. Governance check: Can we store this memory?
        // 2. Lifecycle: Set expiration based on institutional policy
        let expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        let memory = MemoryComponent(
            fact: fact,
            source: source,
            expiresAt: expiresAt,
            tags: tags
        )

        // 3. Attach to entity in World
        await world.addComponent(target, memory)

        // 4. Record evidence
        _ = try? await context.recordEvidence(
            operation: .custom,
            payload: .custom(type: "memory_stored", data: ["fact_hash": fact.hashValue.description])
        )
    }

    /// Prune expired memories from the world.
    public func pruneExpired(world: World) async {
        let memories = await world.query(MemoryComponent.self)
        let now = Date()

        for (id, memory) in memories {
            if let expiration = memory.expiresAt, expiration < now {
                await world.removeComponent(id, MemoryComponent.self)
                log.info("MemorySystem: Pruned expired memory for entity \(id, privacy: .public)")
            }
        }
    }
}

extension ExecutionContext {
    fileprivate func recordEvidence(operation: CoreOperationType, payload: EvidencePayload) async throws -> CoreReceipt {
        // Simulated bridge to EvidenceAuthority
        return CoreReceipt(operationType: "dummy", principal: self.principal, outcome: .success, contentHash: "dummy", durationMs: 0)
    }
}
