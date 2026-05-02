//
//  AuditEntry.swift
//  ContractsCore
//
//  Represents a single entry in the audit log.
//

import FoundationContracts
import AnigmaPrimitives
import Foundation

/// Represents a single entry in the audit log.
public struct AuditEntry: Sendable, Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let engineId: String
    public let operation: String
    public let command: String?
    public let arguments: [String]?
    public let error: String?
    public let metadata: [String: String]?

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        engineId: String,
        operation: String,
        command: String?,
        arguments: [String]?,
        error: String?,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.engineId = engineId
        self.operation = operation
        self.command = command
        self.arguments = arguments
        self.error = error
        self.metadata = metadata
    }
}
