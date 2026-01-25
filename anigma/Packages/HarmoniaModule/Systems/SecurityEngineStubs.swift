//
//  SecurityEngineStubs.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import DatabaseCore
@preconcurrency import Foundation
import AnigmaCore
import AnigmaPrimitives

/// Simple fallback factory used when the experimental security engine is unavailable.
public struct SecurityAwareMigrationEngineFactory {
    private let traceSink: MigrationTraceSink

    public init(traceSink: MigrationTraceSink) {
        self.traceSink = traceSink
        print("[INFO][SecurityFactory] SecurityAwareMigrationEngineFactory (stub) initialized with trace sink: \(type(of: traceSink))")
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
