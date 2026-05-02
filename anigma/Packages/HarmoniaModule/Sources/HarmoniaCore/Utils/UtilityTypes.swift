import HarmoniaWorkflowContracts

import ContractsCore

//
//  UtilityTypes.swift
//  HarmoniaModule
//
//  Utility type definitions for various subsystems.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
@preconcurrency import Foundation



// MARK: - File System Utilities

/// File access logger for audit trail
actor FileAccessLogger {
    init() {}
    
    func logAccess(filePath: String, size: Int, type: String, duration: TimeInterval) async throws {
        // Stub
    }
    
    struct Stats: Sendable {
        let totalAccesses: Int
        let lastAccessTime: Date
        let accessFrequency: Double
        let averageAccessTime: TimeInterval
    }
    
    func getStats(filePath: String) async throws -> Stats {
        return Stats(totalAccesses: 0, lastAccessTime: Date(), accessFrequency: 0, averageAccessTime: 0)
    }
}

/// File caching manager
actor FileCachingManager {
    init() {}
    
    struct CachedFile: Sendable {
        let content: String
        let hash: String
    }
    
    func get(_ filePath: String) async -> CachedFile? {
        return nil
    }
    
    func cache(filePath: String, content: String, hash: String) async throws {
        // Stub
    }
}



/// Processing policy for engine configuration
struct ProcessingPolicy: Sendable, Codable {
    let maxConcurrentTasks: Int
    let timeoutSeconds: TimeInterval
    
    init(maxConcurrentTasks: Int = 4, timeoutSeconds: TimeInterval = 300) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.timeoutSeconds = timeoutSeconds
    }
}

/// Processing result from engine execution
struct ProcessingResult: Sendable, Codable {
    let success: Bool
    let output: String
    let duration: TimeInterval
    
    init(success: Bool, output: String, duration: TimeInterval) {
        self.success = success
        self.output = output
        self.duration = duration
    }
}

/// Processing stage in pipeline
enum ProcessingStage: String, Sendable, Codable, CaseIterable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
}

/// Processing task for engine execution
struct ProcessingTask: Sendable, Codable {
    let id: String
    let command: String
    let arguments: [String]
    let environment: [String: String]?
    let workingDirectory: String?
    
    init(
        id: String,
        command: String,
        arguments: [String],
        environment: [String: String]? = nil,
        workingDirectory: String? = nil
    ) {
        self.id = id
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
    }
}

// MARK: - Redaction System

/// Redaction audit trail configuration
struct RedactionAuditTrailConfiguration: Sendable, Codable {
    let enabled: Bool
    let retentionDays: Int
    let compressionEnabled: Bool
    
    init(enabled: Bool = true, retentionDays: Int = 90, compressionEnabled: Bool = true) {
        self.enabled = enabled
        self.retentionDays = retentionDays
        self.compressionEnabled = compressionEnabled
    }
}

// MARK: - Scout Types





// MARK: - Store Configuration

/// Store retrieval evidence configuration
struct StoreRetrievalEvidenceConfiguration: Sendable, Codable {
    let enabled: Bool
    let compression: Bool
    let encryption: Bool
    
    init(enabled: Bool = true, compression: Bool = true, encryption: Bool = false) {
        self.enabled = enabled
        self.compression = compression
        self.encryption = encryption
    }
}

// MARK: - Code Symbol Types

/// Code symbol for analysis
struct CodeSymbol: Sendable, Codable {
    let name: String
    let kind: String
    let location: String
    let scope: String?
    
    init(name: String, kind: String, location: String, scope: String? = nil) {
        self.name = name
        self.kind = kind
        self.location = location
        self.scope = scope
    }
}

// MARK: - Capability Grant

/// Capability grant for access control
struct CapabilityGrant: Sendable, Codable {
    let capability: String
    let grantedAt: Date
    let expiresAt: Date?
    let conditions: [String: String]
    
    init(
        capability: String,
        grantedAt: Date = Date(),
        expiresAt: Date? = nil,
        conditions: [String: String] = [:]
    ) {
        self.capability = capability
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.conditions = conditions
    }
}

// MARK: - Policy Types

/// Policy for governance
struct Policy: @unchecked Sendable, Codable {
    let id: String
    let name: String
    let rules: [String: String]
    
    init(id: String, name: String, rules: [String: String]) {
        self.id = id
        self.name = name
        self.rules = rules
    }
}

/// Engine metadata
struct Engine: Sendable, Codable {
    let id: String
    let name: String
    let version: String
    
    init(id: String, name: String, version: String) {
        self.id = id
        self.name = name
        self.version = version
    }
}
