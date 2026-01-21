import Foundation

// MARK: - Model Registry
// Durable, queryable registry of installed models with provenance

/// Registry entry with full governance metadata
public struct ModelRegistryEntry: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let spec: ModelSpec
    public let installPath: String
    public let status: ModelStatus
    public let lastVerified: Date
    public let usageCount: Int64
    public let lastUsed: Date?

    public init(
        id: String,
        spec: ModelSpec,
        installPath: String,
        status: ModelStatus = .ready,
        lastVerified: Date = Date(),
        usageCount: Int64 = 0,
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.spec = spec
        self.installPath = installPath
        self.status = status
        self.lastVerified = lastVerified
        self.usageCount = usageCount
        self.lastUsed = lastUsed
    }
}

/// Model installation and verification status
public enum ModelStatus: String, Codable, Sendable {
    case downloading = "downloading"
    case verifying = "verifying"
    case converting = "converting"
    case ready = "ready"
    case degraded = "degraded"       // Files present but verification failed
    case quarantined = "quarantined" // License or policy blocked
}

/// Query filter for registry searches
public struct ModelQuery: Sendable {
    public let taskKind: ModelTaskKind?
    public let backend: MLBackend?
    public let trustTier: ModelTrustTier?
    public let runnableOnly: Bool
    public let sourcePattern: String?

    public init(
        taskKind: ModelTaskKind? = nil,
        backend: MLBackend? = nil,
        trustTier: ModelTrustTier? = nil,
        runnableOnly: Bool = false,
        sourcePattern: String? = nil
    ) {
        self.taskKind = taskKind
        self.backend = backend
        self.trustTier = trustTier
        self.runnableOnly = runnableOnly
        self.sourcePattern = sourcePattern
    }
}

/// Model registry persistence and query interface
public protocol ModelRegistryProtocol: Sendable {
    func register(_ spec: ModelSpec, installPath: String) async throws -> ModelRegistryEntry
    func find(id: String) async throws -> ModelRegistryEntry?
    func query(_ filter: ModelQuery) async throws -> [ModelRegistryEntry]
    func update(_ id: String, status: ModelStatus) async throws
    func recordUsage(_ id: String) async throws
    func verifyIntegrity(_ id: String) async throws -> Bool
    func delete(_ id: String) async throws
    func listAll() async throws -> [ModelRegistryEntry]
}

/// Import result from HuggingFace or local source
public struct ModelImportResult: Sendable {
    public let spec: ModelSpec
    public let installPath: String
    public let conversionNeeded: Bool
    public let warnings: [String]

    public init(
        spec: ModelSpec,
        installPath: String,
        conversionNeeded: Bool = false,
        warnings: [String] = []
    ) {
        self.spec = spec
        self.installPath = installPath
        self.conversionNeeded = conversionNeeded
        self.warnings = warnings
    }
}

/// HuggingFace model descriptor inferred from repo metadata
public struct HFModelDescriptor: Sendable {
    public let repoId: String
    public let revision: String
    public let inferredTask: ModelTaskKind?
    public let compatibleBackends: [MLBackend]
    public let license: String?
    public let safetensors: Bool
    public let gguf: Bool
    public let mlx: Bool
    public let estimatedSizeBytes: Int64?
    public let tags: [String]

    public var isRunnable: Bool {
        !compatibleBackends.isEmpty && inferredTask != nil
    }

    public init(
        repoId: String,
        revision: String,
        inferredTask: ModelTaskKind? = nil,
        compatibleBackends: [MLBackend] = [],
        license: String? = nil,
        safetensors: Bool = false,
        gguf: Bool = false,
        mlx: Bool = false,
        estimatedSizeBytes: Int64? = nil,
        tags: [String] = []
    ) {
        self.repoId = repoId
        self.revision = revision
        self.inferredTask = inferredTask
        self.compatibleBackends = compatibleBackends
        self.license = license
        self.safetensors = safetensors
        self.gguf = gguf
        self.mlx = mlx
        self.estimatedSizeBytes = estimatedSizeBytes
        self.tags = tags
    }
}
