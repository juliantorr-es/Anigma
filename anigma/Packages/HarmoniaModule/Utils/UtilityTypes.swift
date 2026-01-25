//
//  UtilityTypes.swift
//  HarmoniaModule
//
//  Utility type definitions for various subsystems.
//

@preconcurrency import Foundation



// MARK: - File System Utilities

/// File access logger for audit trail
public actor FileAccessLogger {
    public init() {}
    
    // Stub implementation
}

/// File caching manager
public actor FileCachingManager {
    public init() {}
    
    // Stub implementation
}



/// Processing policy for engine configuration
public struct ProcessingPolicy: Sendable, Codable {
    public let maxConcurrentTasks: Int
    public let timeoutSeconds: TimeInterval
    
    public init(maxConcurrentTasks: Int = 4, timeoutSeconds: TimeInterval = 300) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.timeoutSeconds = timeoutSeconds
    }
}

/// Processing result from engine execution
public struct ProcessingResult: Sendable, Codable {
    public let success: Bool
    public let output: String
    public let duration: TimeInterval
    
    public init(success: Bool, output: String, duration: TimeInterval) {
        self.success = success
        self.output = output
        self.duration = duration
    }
}

/// Processing stage in pipeline
public enum ProcessingStage: String, Sendable, Codable, CaseIterable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
}

/// Processing task for engine execution
public struct ProcessingTask: Sendable, Codable {
    public let id: String
    public let command: String
    public let arguments: [String]
    public let environment: [String: String]?
    public let workingDirectory: String?
    
    public init(
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
public struct RedactionAuditTrailConfiguration: Sendable, Codable {
    public let enabled: Bool
    public let retentionDays: Int
    public let compressionEnabled: Bool
    
    public init(enabled: Bool = true, retentionDays: Int = 90, compressionEnabled: Bool = true) {
        self.enabled = enabled
        self.retentionDays = retentionDays
        self.compressionEnabled = compressionEnabled
    }
}

// MARK: - Scout Types





// MARK: - Store Configuration

/// Store retrieval evidence configuration
public struct StoreRetrievalEvidenceConfiguration: Sendable, Codable {
    public let enabled: Bool
    public let compression: Bool
    public let encryption: Bool
    
    public init(enabled: Bool = true, compression: Bool = true, encryption: Bool = false) {
        self.enabled = enabled
        self.compression = compression
        self.encryption = encryption
    }
}

// MARK: - Code Symbol Types

/// Code symbol for analysis
public struct CodeSymbol: Sendable, Codable {
    public let name: String
    public let kind: String
    public let location: String
    public let scope: String?
    
    public init(name: String, kind: String, location: String, scope: String? = nil) {
        self.name = name
        self.kind = kind
        self.location = location
        self.scope = scope
    }
}

// MARK: - Capability Grant

/// Capability grant for access control
public struct CapabilityGrant: Sendable, Codable {
    public let capability: String
    public let grantedAt: Date
    public let expiresAt: Date?
    public let conditions: [String: String]
    
    public init(
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
public struct Policy: @unchecked Sendable, Codable {
    public let id: String
    public let name: String
    public let rules: [String: String]
    
    public init(id: String, name: String, rules: [String: String]) {
        self.id = id
        self.name = name
        self.rules = rules
    }
}

/// Engine metadata
public struct Engine: Sendable, Codable {
    public let id: String
    public let name: String
    public let version: String
    
    public init(id: String, name: String, version: String) {
        self.id = id
        self.name = name
        self.version = version
    }
}