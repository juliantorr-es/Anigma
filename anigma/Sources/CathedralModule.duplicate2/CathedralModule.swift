//
//  CathedralModule.swift
//  CathedralModule
//
//  Evidence-driven coordination system for Phase H
//  Implements tamper-evident coordination with evidence enforcement
//

import Foundation
import DatabaseCore
import AnigmaCore
import ContractsCore

// MARK: - Cathedral Configuration

/// Cathedral coordination configuration
public struct CathedralConfig: Sendable, Codable {
    public let maxEvidenceChainLength: Int
    public let evidenceTimeoutSeconds: TimeInterval
    public let violationActionThreshold: EvidenceViolationSeverity
    public let requireFreshEvidence: Bool
    public let evidenceValidationMode: EvidenceValidationMode

    public init(
        maxEvidenceChainLength: Int = 1000,
        evidenceTimeoutSeconds: TimeInterval = 300,
        violationActionThreshold: EvidenceViolationSeverity = .high,
        requireFreshEvidence: Bool = true,
        evidenceValidationMode: EvidenceValidationMode = .strict
    ) {
        self.maxEvidenceChainLength = maxEvidenceChainLength
        self.evidenceTimeoutSeconds = evidenceTimeoutSeconds
        self.violationActionThreshold = violationActionThreshold
        self.requireFreshEvidence = requireFreshEvidence
        self.evidenceValidationMode = evidenceValidationMode
    }
}

// MARK: - Cathedral Errors

public enum CathedralError: Error, LocalizedError {
    case evidenceChainCorrupted(String)
    case evidenceTimeout(String)
    case unauthorizedEvidenceAccess(String)
    case invalidEvidenceFormat(String)
    case validationFailed([String])
    case databaseError(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case .evidenceChainCorrupted(let details):
            return "Evidence chain corrupted: \(details)"
        case .evidenceTimeout(let details):
            return "Evidence timeout: \(details)"
        case .unauthorizedEvidenceAccess(let details):
            return "Unauthorized evidence access: \(details)"
        case .invalidEvidenceFormat(let details):
            return "Invalid evidence format: \(details)"
        case .validationFailed(let violations):
            return "Evidence validation failed: \(violations.joined(separator: ", "))"
        case .databaseError(let details):
            return "Database error: \(details)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        }
    }
}

// MARK: - Cathedral Module Entry Point

public enum CathedralModule {
    public static let version = "2.0.0"
    public static let defaultConfig = CathedralConfig()

    /// Create a production Cathedral coordinator with full evidence enforcement
    public static func create(
        config: CathedralConfig = defaultConfig,
        database: LegacyDatabaseActor? = nil,
        mlService: CathedralMLService? = nil
    ) async -> CathedralCoordinator {
        let tamperSystem = TamperEvidenceSystem(database: database)

        // Load from database if provided
        if database != nil {
            try? await tamperSystem.loadFromDatabase()
        }

        let evidenceSubstrate = EvidenceSubstrate(
            tamperSystem: tamperSystem,
            config: config
        )

        return CathedralCoordinatorImpl(
            evidenceSubstrate: evidenceSubstrate,
            config: config,
            mlService: mlService
        )
    }

    /// Create a lightweight coordinator for testing
    public static func createForTesting(
        config: CathedralConfig = defaultConfig
    ) async -> CathedralCoordinator {
        return await create(config: config, database: nil)
    }
}
