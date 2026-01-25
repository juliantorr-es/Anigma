//
//  MigrationTaskRow+Convenience.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

@preconcurrency import Foundation
import AnigmaPrimitives

extension MigrationTaskRow {
    public init(
        id: String,
        projectId: UUID,
        engineType: String,
        featureCategory: String,
        status: String,
        priority: Int,
        findingId: String?
    ) {
        self.init(
            id: id,
            engineType: engineType,
            featureCategory: featureCategory,
            status: status,
            priority: priority,
            projectId: projectId,
            findingId: findingId
        )
    }
}
