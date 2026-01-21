//
//  SlotManagementSystem.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import DatabaseCore
//
//  SlotManagementSystem.swift
//  HarmoniaModule/Systems
//
//  System that synchronizes ECS state with the ModelConcurrencyController.
//  Migrated from: Harmonia/OrchestrumCore/ECS/Systems.swift
//

import AnigmaCore
import Foundation

/// System that synchronizes ECS state with the ModelConcurrencyController.
/// This system bridges the existing concurrency controller with ECS representation.
public struct SlotManagementSystem: System {
    public let name = "SlotManagementSystem"

    private let controller: ModelConcurrencyController

    public init(controller: ModelConcurrencyController) {
        self.controller = controller
    }

    public func update(world: World) async {
        let stats = await controller.stats()

        // Update or create concurrency state entities for each model kind
        let modelKinds = await controller.modelKinds()
        for kind in modelKinds {
            let stateComponent = ConcurrencyStateComponent(
                modelKind: kind.rawValue,
                limit: stats.limits[kind] ?? 0,
                inFlight: stats.inFlight[kind] ?? 0,
                waiting: stats.waiting[kind] ?? 0,
                lastUpdated: Date()
            )

            // Find existing entity or create new one
            let existingEntities = await world.query(ConcurrencyStateComponent.self)
            let existing = existingEntities.first { $0.1.modelKind == kind.rawValue }

            if let (entity, _) = existing {
                await world.addComponent(entity, stateComponent)
            } else {
                let entity = await world.createEntity()
                await world.addComponent(entity, stateComponent)
                await world.addComponent(entity, NameComponent(
                    name: "concurrency.\(kind.rawValue)",
                    displayName: "\(kind.rawValue.capitalized) Pool"
                ))
                await world.addComponent(entity, TagComponent("concurrency", "pool"))
            }
        }
    }
}
