//
//  CapabilityResolutionSystem.swift
//  CapabilityCore
//
//  ECS system that processes capability requests.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

/// System that processes capability requests and records results.
public actor CapabilityResolutionSystem: AsyncSystem {
    public nonisolated var name: String { "CapabilityResolution" }
    public nonisolated var dependencies: [String] { [] }
    public nonisolated var readComponents: [any Component.Type] {
        [CapabilityRequestComponent.self]
    }
    public nonisolated var writeComponents: [any Component.Type] {
        [CapabilityResultComponent.self]
    }

    private let registry: CapabilityRegistry
    private let governance: CapabilityRegistry.CapabilityGovernance?
    private let auditLog: CapabilityRegistry.CapabilityAuditLog?

    public init(
        registry: CapabilityRegistry = .shared,
        governance: CapabilityRegistry.CapabilityGovernance? = nil,
        auditLog: CapabilityRegistry.CapabilityAuditLog? = nil
    ) {
        self.registry = registry
        self.governance = governance
        self.auditLog = auditLog
    }

    public func update(world: World) async throws {
        let requests = await world.query(CapabilityRequestComponent.self)

        for (entityId, request) in requests {
            // Check if already processed
            if await world.hasComponent(entityId, CapabilityResultComponent.self) {
                continue
            }

            // Resolve with governance if available
            let principal = request.context["principal"] ?? "system"

            if let governance {
                let decision = await governance.canResolve(
                    capabilityId: request.capabilityId,
                    principal: principal,
                    context: request.context
                )

                guard decision.allowed else {
                    await recordFailure(
                        world: world,
                        entityId: entityId,
                        request: request,
                        error: decision.reason ?? "Governance denied"
                    )
                    continue
                }
            }

            // Check if capability exists
            let providerCount = await registry.providerCount(for: request.capabilityId)

            if providerCount > 0 {
                await recordSuccess(
                    world: world,
                    entityId: entityId,
                    request: request
                )
            } else {
                await recordFailure(
                    world: world,
                    entityId: entityId,
                    request: request,
                    error: "Capability not found: \(request.capabilityId)"
                )
            }
        }
    }

    // MARK: - Private Helpers

    private func recordSuccess(
        world: World,
        entityId: EntityId,
        request: CapabilityRequestComponent
    ) async {
        let result = CapabilityResultComponent(
            capabilityId: request.capabilityId,
            success: true,
            metadata: request.context
        )
        await world.addComponent(entityId, result)

        // Audit log
        await auditLog?.logResolution(
            capabilityId: request.capabilityId,
            principal: request.context["principal"] ?? "system",
            success: true,
            metadata: request.context
        )
    }

    private func recordFailure(
        world: World,
        entityId: EntityId,
        request: CapabilityRequestComponent,
        error: String
    ) async {
        let result = CapabilityResultComponent(
            capabilityId: request.capabilityId,
            success: false,
            error: error,
            metadata: request.context
        )
        await world.addComponent(entityId, result)

        // Audit log
        await auditLog?.logResolution(
            capabilityId: request.capabilityId,
            principal: request.context["principal"] ?? "system",
            success: false,
            metadata: ["error": error]
        )
    }
}
