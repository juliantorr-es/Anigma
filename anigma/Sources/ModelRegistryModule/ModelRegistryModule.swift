import Foundation
import AnigmaCore
import ContractsCore
import DatabaseCore

/// Model Registry: Governed model lifecycle management with provenance and compatibility tracking
/// Phase 0: Core registry with model identity, licensing, and backend compatibility
public actor ModelRegistryModule {
    private let database: ModelRegistryDatabase

    public init(database: ModelRegistryDatabase) {
        self.database = database
    }

    // MARK: - Model Registration

    /// Register a model with full provenance and governance
    public func registerModel(_ spec: ModelRegistrationSpec) async throws -> RegisteredModelRecord {
        // Validate license against allowlist
        let licenseDecision = validateLicense(spec.license)
        guard licenseDecision.allowed else {
            throw ModelRegistryError.licenseBlocked(
                modelID: spec.modelID,
                license: spec.license,
                reason: licenseDecision.reason
            )
        }

        // Create model record
        let record = RegisteredModelRecord(
            modelID: spec.modelID,
            modelHash: spec.modelHash,
            taskContract: spec.taskContract,
            backendKind: spec.backendKind,
            source: spec.source,
            license: spec.license,
            licenseDecision: licenseDecision.decision,
            artifactHashes: spec.artifactHashes,
            tokenizerHash: spec.tokenizerHash,
            conversionReceipts: spec.conversionReceipts,
            metadata: spec.metadata,
            trustTier: spec.trustTier,
            dimensions: spec.dimensions,
            registeredAt: Date()
        )

        try await database.insertModel(record)
        return record
    }

    /// Get model by ID and hash (strict identity)
    public func getModel(modelID: String, modelHash: String) async throws -> RegisteredModelRecord {
        guard let model = try await database.fetchModel(modelID: modelID, modelHash: modelHash) else {
            throw ModelRegistryError.notFound(modelID: modelID, modelHash: modelHash)
        }
        return model
    }

    /// Get model by ID only (returns latest registered version)
    public func getLatestModel(modelID: String) async throws -> RegisteredModelRecord {
        guard let model = try await database.fetchLatestModel(modelID: modelID) else {
            throw ModelRegistryError.modelIDNotFound(modelID)
        }
        return model
    }

    /// List all registered models
    public func listModels(
        taskContract: TaskContract? = nil,
        backendKind: BackendKind? = nil,
        trustTier: TrustTier? = nil
    ) async throws -> [RegisteredModelRecord] {
        return try await database.listModels(
            taskContract: taskContract,
            backendKind: backendKind,
            trustTier: trustTier
        )
    }

    /// Check if model is registered
    public func isRegistered(modelID: String, modelHash: String) async throws -> Bool {
        return try await database.fetchModel(modelID: modelID, modelHash: modelHash) != nil
    }

    // MARK: - License Validation

    private func validateLicense(_ license: String) -> (allowed: Bool, decision: String, reason: String) {
        let allowedLicenses = [
            "MIT", "Apache-2.0", "BSD-3-Clause", "CC-BY-4.0",
            "Apache License 2.0", "apache-2.0"
        ]

        let normalizedLicense = license.trimmingCharacters(in: .whitespacesAndNewlines)

        if allowedLicenses.contains(where: { normalizedLicense.localizedCaseInsensitiveContains($0) }) {
            return (true, "allowed", "License on allowlist")
        }

        return (false, "blocked", "License not on allowlist: \(license)")
    }
}

extension ModelRegistryModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // Create database adapter for governed database access
        let databaseAuthority = await runtime.database
        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
        
        // Create artifact storage adapter for unified artifact storage
        let artifactAuthority = await runtime.artifacts
        let _ = ArtifactStorageAdapter(artifactAuthority: artifactAuthority)
        
        // Register schema with runtime for automatic migrations
        let schema = SchemaMigration.schemaFromLegacyTables(
            name: "model_registry",
            module: "ModelRegistryModule",
            version: 1,
            createTableStatements: [
                """
                CREATE TABLE IF NOT EXISTS registered_models (
                    model_id TEXT NOT NULL,
                    model_hash TEXT NOT NULL,
                    task_contract TEXT NOT NULL,
                    backend_kind TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    source_identifier TEXT NOT NULL,
                    source_revision TEXT,
                    license TEXT NOT NULL,
                    license_decision TEXT NOT NULL,
                    artifact_hashes_json TEXT NOT NULL,
                    tokenizer_hash TEXT,
                    conversion_receipts_json TEXT,
                    metadata_json TEXT NOT NULL,
                    trust_tier TEXT NOT NULL,
                    dimensions INTEGER,
                    registered_at REAL NOT NULL,
                    PRIMARY KEY (model_id, model_hash)
                );
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_models_task ON registered_models(task_contract);
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_models_backend ON registered_models(backend_kind);
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_models_tier ON registered_models(trust_tier);
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_models_id ON registered_models(model_id);
                """
            ]
        )
        try await runtime.registerSchema(schema)
        
        // Initialize database with migrated schema
        let _ = try await ModelRegistryDatabase(dbActor: databaseAdapter as! DatabaseCore.DatabaseExecutor)
        
        // TODO: Migrate artifact storage from direct filesystem to ArtifactAuthority
        // Currently artifact storage is fragmented (e.g., HuggingFaceAdapter writes to local directory).
        // All artifact operations should be migrated to use artifactAdapter.
        // For now, store artifact adapter reference for future use.
        // Note: ModelRegistryModule currently doesn't have artifact storage operations.
    }
}

// MARK: - Data Types

public struct ModelRegistrationSpec: Codable, Sendable {
    public let modelID: String
    public let modelHash: String
    public let taskContract: TaskContract
    public let backendKind: BackendKind
    public let source: ModelSource
    public let license: String
    public let artifactHashes: [String: String] // filename -> hash
    public let tokenizerHash: String?
    public let conversionReceipts: [String]? // receipt IDs for conversions
    public let metadata: [String: String]
    public let trustTier: TrustTier
    public let dimensions: Int? // for embedding models

    public init(
        modelID: String,
        modelHash: String,
        taskContract: TaskContract,
        backendKind: BackendKind,
        source: ModelSource,
        license: String,
        artifactHashes: [String: String],
        tokenizerHash: String? = nil,
        conversionReceipts: [String]? = nil,
        metadata: [String: String] = [:],
        trustTier: TrustTier = .standard,
        dimensions: Int? = nil
    ) {
        self.modelID = modelID
        self.modelHash = modelHash
        self.taskContract = taskContract
        self.backendKind = backendKind
        self.source = source
        self.license = license
        self.artifactHashes = artifactHashes
        self.tokenizerHash = tokenizerHash
        self.conversionReceipts = conversionReceipts
        self.metadata = metadata
        self.trustTier = trustTier
        self.dimensions = dimensions
    }
}

public struct RegisteredModelRecord: Codable, Sendable {
    public let modelID: String
    public let modelHash: String
    public let taskContract: TaskContract
    public let backendKind: BackendKind
    public let source: ModelSource
    public let license: String
    public let licenseDecision: String
    public let artifactHashes: [String: String]
    public let tokenizerHash: String?
    public let conversionReceipts: [String]?
    public let metadata: [String: String]
    public let trustTier: TrustTier
    public let dimensions: Int?
    public let registeredAt: Date

    public init(
        modelID: String,
        modelHash: String,
        taskContract: TaskContract,
        backendKind: BackendKind,
        source: ModelSource,
        license: String,
        licenseDecision: String,
        artifactHashes: [String: String],
        tokenizerHash: String?,
        conversionReceipts: [String]?,
        metadata: [String: String],
        trustTier: TrustTier,
        dimensions: Int?,
        registeredAt: Date
    ) {
        self.modelID = modelID
        self.modelHash = modelHash
        self.taskContract = taskContract
        self.backendKind = backendKind
        self.source = source
        self.license = license
        self.licenseDecision = licenseDecision
        self.artifactHashes = artifactHashes
        self.tokenizerHash = tokenizerHash
        self.conversionReceipts = conversionReceipts
        self.metadata = metadata
        self.trustTier = trustTier
        self.dimensions = dimensions
        self.registeredAt = registeredAt
    }
}

public struct ModelSource: Codable, Sendable {
    public let type: String // "huggingface", "local", "bundled"
    public let identifier: String // repo id, path, bundle name
    public let revision: String? // commit SHA for HF

    public init(type: String, identifier: String, revision: String? = nil) {
        self.type = type
        self.identifier = identifier
        self.revision = revision
    }
}

public enum TaskContract: String, Codable, Sendable {
    case llmChat
    case embedding
    case transcription
    case classification
    case imageGeneration
    case speechSynthesis
}

public enum BackendKind: String, Codable, Sendable {
    case mlx
    case llama
    case deepseek
    case coreml
    case gguf
}

public enum TrustTier: String, Codable, Sendable {
    case standard
    case sensitive
    case restricted
    case experimental
}

// MARK: - Errors

public enum ModelRegistryError: Error, CustomStringConvertible {
    case notFound(modelID: String, modelHash: String)
    case modelIDNotFound(String)
    case licenseBlocked(modelID: String, license: String, reason: String)
    case invalidModelIdentity(modelID: String, modelHash: String, reason: String)

    public var description: String {
        switch self {
        case .notFound(let id, let hash):
            return "Model not found: \(id) hash \(hash)"
        case .modelIDNotFound(let id):
            return "No model registered with ID: \(id)"
        case .licenseBlocked(let id, let license, let reason):
            return "Model \(id) license '\(license)' blocked: \(reason)"
        case .invalidModelIdentity(let id, let hash, let reason):
            return "Invalid model identity \(id) hash \(hash): \(reason)"
        }
    }
}
