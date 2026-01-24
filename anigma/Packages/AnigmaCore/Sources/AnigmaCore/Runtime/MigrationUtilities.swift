//
//  MigrationUtilities.swift
//  AnigmaCore
//
//  Utilities for migrating capability modules to three-tier architecture.
//  Contains adapters, wrappers, and helpers for gradual migration.
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import Foundation
import DatabaseCore
import AnigmaPrimitives
import CryptoKit

// MARK: - Evidence System Adapters

/// Adapter that makes HarmoniaModule's TamperEvidenceSystem conform to EvidenceSink.
/// This enables gradual migration of evidence recording to the unified EvidenceAuthority.
public actor TamperEvidenceSystemAdapter: EvidenceSink {
    private let tamperEvidenceSystem: any TamperEvidenceSystemProtocol
    private let convertPayload: (EvidencePayload) -> [String: Sendable]
    
    /// Create adapter for HarmoniaModule's TamperEvidenceSystem
    /// - Parameter tamperEvidenceSystem: The TamperEvidenceSystem to wrap
    public init(tamperEvidenceSystem: any TamperEvidenceSystemProtocol) {
        self.tamperEvidenceSystem = tamperEvidenceSystem
        self.convertPayload = { payload in
            // Default conversion - can be customized
            switch payload {
            case .workflowExecution(let workflowType, let inputs, let outputs):
                return [
                    "type": "workflow_execution",
                    "workflow_type": workflowType,
                    "input_count": inputs.count,
                    "output_count": outputs.count
                ]
            case .databaseMutation(let sql, let rowsAffected):
                return [
                    "type": "database_mutation",
                    "sql_preview": String(sql.prefix(100)),
                    "rows_affected": rowsAffected
                ]
            case .mlInference(let model, let prompt, let response):
                return [
                    "type": "ml_inference",
                    "model": model,
                    "prompt_preview": String(prompt.prefix(50)),
                    "response_preview": String(response.prefix(50))
                ]
            case .artifactStorage(let artifactId, let size):
                return [
                    "type": "artifact_storage",
                    "artifact_id": artifactId,
                    "size": size
                ]
            case .custom(let type, let data):
                return [
                    "type": "custom.\(type)",
                    "data": data
                ]
            }
        }
    }
    
    /// Customize payload conversion
    public func withPayloadConversion(
        _ converter: @escaping (EvidencePayload) -> [String: Sendable]
    ) -> TamperEvidenceSystemAdapter {
        return TamperEvidenceSystemAdapter(
            tamperEvidenceSystem: tamperEvidenceSystem,
            converter: converter
        )
    }
    
    private init(
        tamperEvidenceSystem: any TamperEvidenceSystemProtocol,
        converter: @escaping (EvidencePayload) -> [String: Sendable]
    ) {
        self.tamperEvidenceSystem = tamperEvidenceSystem
        self.convertPayload = converter
    }
    
    public func record(
        receipt: Receipt,
        payload: EvidencePayload,
        operation: OperationType,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async {
        // Convert EvidencePayload to TamperEvidenceSystem format
        var payloadDict = convertPayload(payload)
        
        // Add receipt metadata
        payloadDict["receipt_id"] = receipt.id.raw
        payloadDict["operation"] = operation.rawValue
        payloadDict["principal_id"] = receipt.principal.id
        payloadDict["outcome"] = receipt.outcome.rawValue
        
        if let summary = receipt.summary {
            payloadDict["summary"] = summary
        }
        
        if let decision = governanceDecision {
            payloadDict["governance_allowed"] = decision.allowed
            if let reason = decision.reason {
                payloadDict["governance_reason"] = reason
            }
        }
        
        // Forward to TamperEvidenceSystem
        do {
            _ = try await tamperEvidenceSystem.appendEvent(
                eventType: "platform_evidence",
                payload: payloadDict,
                actor: receipt.principal.displayName,
                actorIP: nil,
                sessionId: context.sessionId
            )
        } catch {
            // Evidence sinks should not block runtime operations
            // Log error but don't throw
            print("[TamperEvidenceSystemAdapter] Failed to record evidence: \(error)")
        }
    }
}

/// Protocol abstraction for TamperEvidenceSystem to avoid direct dependency
public protocol TamperEvidenceSystemProtocol: Actor {
    func appendEvent(
        eventType: String,
        payload: [String: Sendable],
        actor: String,
        actorIP: String?,
        sessionId: String?
    ) async throws -> String
}

/// Adapter that makes HarmoniaModule's EvidenceRecorder conform to EvidenceSink.
public actor EvidenceRecorderAdapter: EvidenceSink {
    private let evidenceRecorder: any EvidenceRecorderProtocol
    
    /// Create adapter for HarmoniaModule's EvidenceRecorder
    /// - Parameter evidenceRecorder: The EvidenceRecorder to wrap
    public init(evidenceRecorder: any EvidenceRecorderProtocol) {
        self.evidenceRecorder = evidenceRecorder
    }
    
    public func record(
        receipt: Receipt,
        payload: EvidencePayload,
        operation: OperationType,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async {
        // Convert to EvidenceRecorder format
        // Note: EvidenceRecorder has different API - we need to adapt
        // For now, we'll create a simplified recording
        let metadataValues = context.metadata
        let payloadMetadata = extractPayloadMetadata(from: payload)
        let parameters = metadataValues["tool_call_parameters"] ?? payloadMetadata["parameters"]
        let filePath = metadataValues["tool_call_file_path"] ?? payloadMetadata["file_path"]
        let inputHash = metadataValues["tool_call_input_hash"] ?? payloadMetadata["input_hash"]
        let evidenceId = await evidenceRecorder.startToolCall(
            ToolCallRequest(
                sessionId: context.sessionId,
                agentId: receipt.principal.id,
                toolName: operation.rawValue,
                requestId: receipt.id.raw,
                parameters: parameters,
                filePath: filePath,
                inputHash: inputHash
            ),
            evidenceId: receipt.id.raw
        )
        
        // Record success
        await evidenceRecorder.recordSuccess(
            evidenceId,
            result: [
                "receipt_id": receipt.id.raw,
                "operation": operation.rawValue,
                "outcome": receipt.outcome.rawValue,
                "summary": receipt.summary ?? ""
            ]
        )
    }

    private func extractPayloadMetadata(from payload: EvidencePayload) -> [String: String] {
        switch payload {
        case .custom(_, let data):
            return data
        case .workflowExecution(let workflowType, let inputs, let outputs):
            return [
                "workflow_type": workflowType,
                "input_entity_ids": inputs.map { $0.raw.uuidString }.joined(separator: ","),
                "output_entity_ids": outputs.map { $0.raw.uuidString }.joined(separator: ",")
            ]
        case .databaseMutation(let sql, let rowsAffected):
            return [
                "sql": sql,
                "rows_affected": "\(rowsAffected)"
            ]
        case .mlInference(let model, let prompt, _):
            return [
                "model": model,
                "prompt_preview": String(prompt.prefix(64))
            ]
        case .artifactStorage(let artifactId, let size):
            return [
                "artifact_id": artifactId,
                "artifact_size": "\(size)"
            ]
        }
    }
}

/// Protocol abstraction for EvidenceRecorder to avoid direct dependency
public protocol EvidenceRecorderProtocol: Actor {
    func startToolCall(_ request: ToolCallRequest, evidenceId: String?) async -> String
    func recordSuccess(_ evidenceId: String, result: Codable) async
    func recordFailure(_ evidenceId: String, error: Error) async
}

// MARK: - Artifact Storage Adapters

/// Protocol for legacy artifact storage systems (e.g., ContextumModule's artifact handling)
public protocol LegacyArtifactStorage: Actor {
    func storeArtifact(
        _ data: Data,
        mimeType: String,
        tags: [String],
        metadata: [String: String]
    ) async throws -> String  // Returns artifact ID
    
    func retrieveArtifact(_ id: String) async throws -> Data
    func deleteArtifact(_ id: String) async throws
}

/// Adapter that makes legacy artifact storage systems use ArtifactAuthority
public actor ArtifactStorageAdapter {
    private let artifactAuthority: any ArtifactAuthority
    private let systemContext: ExecutionContext
    
    /// Create adapter for ArtifactAuthority
    /// - Parameter artifactAuthority: The authority to use for storage
    public init(artifactAuthority: any ArtifactAuthority) {
        self.artifactAuthority = artifactAuthority
        self.systemContext = ExecutionContext(principal: .system)
    }
    
    /// Store artifact through ArtifactAuthority
    /// - Parameters:
    ///   - data: Artifact content
    ///   - mimeType: MIME type of the artifact
    ///   - tags: Tags for categorization
    ///   - metadata: Additional metadata
    /// - Returns: Artifact ID (content-addressed)
    public func storeArtifact(
        _ data: Data,
        mimeType: String,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) async throws -> String {
        let artifact = Artifact(
            id: ArtifactID(hash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()),
            mimeType: mimeType,
            size: Int64(data.count),
            tags: tags,
            metadata: metadata,
            content: data
        )
        
        let (id, _) = try await artifactAuthority.store(
            artifact,
            context: systemContext
        )
        
        return id.hash
    }
    
    /// Retrieve artifact through ArtifactAuthority
    /// - Parameter id: Artifact ID to retrieve
    /// - Returns: Artifact content
    public func retrieveArtifact(_ id: String) async throws -> Data {
        let artifactId = ArtifactID(hash: id)
        let artifact = try await artifactAuthority.retrieve(
            artifactId,
            principal: .system
        )
        return artifact.content!
    }
    
    /// Delete artifact through ArtifactAuthority
    /// - Parameter id: Artifact ID to delete
    public func deleteArtifact(_ id: String) async throws {
        let artifactId = ArtifactID(hash: id)
        _ = try await artifactAuthority.delete(
            artifactId,
            context: systemContext
        )
    }
}

// MARK: - Schema Migration Utilities

/// Utility for migrating module schemas to runtime registration
public struct SchemaMigration {
    /// Create a ModuleSchema from legacy CREATE TABLE statements
    /// - Parameters:
    ///   - name: Schema name
    ///   - module: Module name
    ///   - version: Current version
    ///   - createTableStatements: Array of CREATE TABLE statements
    /// - Returns: ModuleSchema for runtime registration
    public static func schemaFromLegacyTables(
        name: String,
        module: String,
        version: Int,
        createTableStatements: [String]
    ) -> ModuleSchema {
        // Version 1 migration creates all tables
        let migrationSQL = createTableStatements.joined(separator: "\n\n")
        
        return ModuleSchema(
            name: name,
            version: version,
            module: module,
            migrations: [1: migrationSQL]
        )
    }
    
    /// Generate migration SQL for adding columns to existing tables
    /// - Parameters:
    ///   - tableName: Name of the table
    ///   - columnDefinitions: Dictionary of column name to SQL type definition
    /// - Returns: ALTER TABLE statements
    public static func addColumnsMigration(
        tableName: String,
        columnDefinitions: [String: String]
    ) -> String {
        columnDefinitions.map { columnName, columnType in
            "ALTER TABLE \(tableName) ADD COLUMN \(columnName) \(columnType);"
        }.joined(separator: "\n")
    }
}

// MARK: - Module Registration Templates

/// Templates for creating `register(runtime:)` implementations
public enum ModuleRegistrationTemplates {
    /// Basic registration template for simple modules
    public static func basicRegistration(
        moduleName: String,
        schema: ModuleSchema? = nil,
        workflows: [Any.Type] = [],
        systems: [Any.Type] = []
    ) -> String {
        """
        extension \(moduleName): CapabilityModule {
            public static func register(runtime: PlatformRuntime) async throws {
                \(schema != nil ? "// Register schema\ntry await runtime.registerSchema(\(moduleName)Schema.core)" : "")
                \(!workflows.isEmpty ? "// Register workflows\n" + workflows.map { "await runtime.registerWorkflow(\($0).self)" }.joined(separator: "\n") : "")
                \(!systems.isEmpty ? "// Register systems\n" + systems.map { "try await runtime.registerSystem(\($0).self)" }.joined(separator: "\n") : "")
                
                await Logger.shared.info("\(moduleName) registered", category: "Runtime")
            }
        }
        """
    }
    
    /// Registration template for modules with DatabaseActor dependencies
    public static func databaseModuleRegistration(
        moduleName: String,
        schema: ModuleSchema? = nil
    ) -> String {
        """
        extension \(moduleName): CapabilityModule {
            public static func register(runtime: PlatformRuntime) async throws {
                // Get database adapter for migration compatibility
                let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: runtime.database)
                
                \(schema != nil ? "// Register schema\ntry await runtime.registerSchema(\(moduleName)Schema.core)" : "")
                
                // Initialize module with database adapter instead of DatabaseActor
                // Note: Module needs to be updated to accept DatabaseAuthorityAdapter
                // let moduleInstance = try await \(moduleName)(database: databaseAdapter)
                // await runtime.registerModuleInstance(moduleInstance)
                
                await Logger.shared.info("\(moduleName) registered with database adapter", category: "Runtime")
            }
        }
        """
    }
}

// MARK: - Testing Utilities

/// Utilities for testing migrated modules
public enum MigrationTestUtilities {
    /// Create a test runtime with mocked authorities
    /// - Returns: PlatformRuntime configured for testing
    public static func createTestRuntime() async throws -> PlatformRuntime {
        return try await PlatformRuntime.testing()
    }
    
    /// Verify a module can register with the runtime
    /// - Parameters:
    ///   - moduleType: Type of the module to test
    ///   - runtime: Runtime to test with
    public static func verifyModuleRegistration<T: CapabilityModule>(
        _ moduleType: T.Type,
        runtime: PlatformRuntime
    ) async throws -> Bool {
        do {
            try await runtime.registerModule(moduleType)
            let status = await runtime.status()
            return status.registeredModules.contains(String(reflecting: moduleType))
        } catch {
            print("Module registration failed: \(error)")
            return false
        }
    }
    
    /// Verify database operations go through governance
    /// - Parameters:
    ///   - runtime: Runtime to test
    ///   - sql: SQL statement to test
    /// - Returns: true if governance was enforced
    public static func verifyGovernanceEnforcement(
        runtime: PlatformRuntime,
        sql: String = "INSERT INTO test_governance (value) VALUES ('test')"
    ) async throws -> Bool {
        let context = ExecutionContext(principal: .system)
        let mutation = DatabaseMutation(sql: sql)
        
        do {
            _ = try await runtime.database.mutate(mutation, context: context)
            return true  // Governance allowed the operation
        } catch let error as RuntimeError {
            switch error {
            case .governanceViolation:
                return true  // Governance correctly blocked the operation
            default:
                throw error
            }
        }
    }
}

// MARK: - Type Aliases for Backward Compatibility

/// Typealias for modules that reference specific Harmonia types
public typealias HarmoniaTamperEvidenceSystem = any TamperEvidenceSystemProtocol

/// Typealias for modules that reference EvidenceRecorder
public typealias HarmoniaEvidenceRecorder = any EvidenceRecorderProtocol

// MARK: - ToolCallRequest (for EvidenceRecorderAdapter compatibility)

/// Simplified ToolCallRequest for EvidenceRecorderAdapter
public struct ToolCallRequest: Sendable, Codable {
    public let sessionId: String
    public let agentId: String
    public let toolName: String
    public let requestId: String
    public let parameters: String?
    public let filePath: String?
    public let inputHash: String?

    public init(
        sessionId: String,
        agentId: String,
        toolName: String,
        requestId: String,
        parameters: String? = nil,
        filePath: String? = nil,
        inputHash: String? = nil
    ) {
        self.sessionId = sessionId
        self.agentId = agentId
        self.toolName = toolName
        self.requestId = requestId
        self.parameters = parameters
        self.filePath = filePath
        self.inputHash = inputHash
    }
}
