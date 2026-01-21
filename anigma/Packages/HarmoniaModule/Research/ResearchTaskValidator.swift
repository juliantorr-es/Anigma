//
//  ResearchTaskValidator.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import Foundation

/// Lightweight research task validator used when the full research module is unavailable.
public actor ResearchTaskValidator {
    public init() {}

    public func createMigrationTaskWithResearchValidation(
        from finding: ScoutFinding,
        db: OpaquePointer?,
        featureCategory: String?
    ) async throws -> String? {
        return createMigrationTask(
            from: finding,
            db: db,
            featureCategory: featureCategory,
            researchBundleId: nil
        )
    }
}
