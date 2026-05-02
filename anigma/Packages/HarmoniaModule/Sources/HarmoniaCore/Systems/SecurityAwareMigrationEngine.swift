import HarmoniaWorkflowContracts

import ContractsCore

//
//  SecurityEngineStubs.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import Foundation
import DatabaseCore
import os.log
@preconcurrency import Foundation
import AnigmaCore
import AnigmaPrimitives

/// Fallback factory used when the production security engine is unavailable.
/// ⚠️ STUB: This provides a bypass to the standard MigrationEngine without full security instrumentation.
private let log = Logger(subsystem: "com.anigma.harmonia", category: "security")
public struct SecurityAwareMigrationEngineFactory {
    private let traceSink: MigrationTraceSink

    public init(traceSink: MigrationTraceSink) {
        self.traceSink = traceSink
        print("⚠️  STUB INVOKED: SecurityAwareMigrationEngineFactory (Experimental fallback)")
        print("   FALLING BACK TO STANDARD MIGRATION ENGINE. Lacks advanced instrumentation.")
        log.warning("[SECURITY] SecurityAwareMigrationEngineFactory (stub) used with trace sink: \(type(of: traceSink))")
    }

    public func engine(for task: MigrationTaskRow) -> (any MigrationEngine)? {
        // Fall back to the regular migration engine when security instrumentation is absent.
        return MigrationEngineFactory.engine(for: task, traceSink: traceSink)
    }
}

/// Minimal blocked engine placeholder used by the core step engine.
public struct BlockedMigrationEngine: MigrationEngine {
    public let reason: String

    public init(reason: String = "blocked by security policy") {
        self.reason = reason
    }

    public func process(task: MigrationTaskRow, db: OpaquePointer?) async throws -> AnigmaPrimitives.MigrationResult {
        return .failed(errorDescription: reason)
    }
}
