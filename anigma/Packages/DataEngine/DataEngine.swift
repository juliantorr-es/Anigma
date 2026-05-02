// DataEngine Module
// Implements the compute pipeline for Anigma's data spine.

@_exported import DataCore
import AnigmaSystemSpine
import Foundation

public actor DataEngine {
    public var policy: DataGovernancePolicy
    private let cacheManager: CacheManager

    private let ingestionEngine = IngestionEngine()
    private let profilingEngine = ProfilingEngine()
    private let transformEngine = TransformEngine()
    private let queryEngine = QueryEngine()

    /// Event subscription IDs for cleanup.
    /// Internal visibility is required because event wiring lives in a separate file extension.
    var eventSubscriptionIds: [UUID] = []

    public init(policy: DataGovernancePolicy = .standard, cacheConfig: CacheConfig = CacheConfig()) {
        self.policy = policy
        self.cacheManager = CacheManager(config: cacheConfig)
        
        // Setup event subscriptions
        Task { await setupEventSubscriptions() }
    }
    
    deinit {}

    public func ingest(source: URL, options: IngestionOptions = IngestionOptions()) async throws -> Artifact {
        // Check governance
        // In a real implementation, we might check if the source is allowed

        let ir = try await ingestionEngine.ingest(source: source, options: options)

        // Wrap IR in Artifact
        // In a real system, we'd serialize the IR and store it.
        // Here we assume the IR's storagePointer is the artifact's content.

        return Artifact(
            id: UUID().uuidString,
            type: .tabularIR,
            contentHash: ir.storagePointer, // Using path as hash for now
            metadata: ["rowCount": String(ir.rowCount)]
        )
    }

    public func profile(artifact: Artifact) async throws -> ProfileArtifact {
        // Check cache
        if await cacheManager.get(key: "profile-\(artifact.id)") != nil {
            // In reality, we'd need to cast or wrap the ProfileArtifact in an Artifact
            // For now, we'll just recompute to avoid complex casting logic in this spine
        }

        // Reconstruct IR from Artifact (assuming artifact points to the file)
        // This is a simplification. In a real system, we'd deserialize the IR.
        let ir = TabularIR(
            schema: TableSchema(columns: []), // Schema is lost in this simplification
            rowCount: Int(artifact.metadata["rowCount"] ?? "0") ?? 0,
            storagePointer: artifact.contentHash,
            parsingDiagnostics: []
        )

        let profile = try await profilingEngine.profile(ir: ir)

        // Cache result (conceptually)
        // await cacheManager.set(key: "profile-\(artifact.id)", artifact: ...)

        return profile
    }

    public func transform(artifact: Artifact, transform: TransformIR) async throws -> (Artifact, ChangeArtifact) {
        // Check governance
        if policy.requireApprovalForTransforms {
            // In a real system, this would trigger an approval flow or throw if not pre-approved
            // For this spine, we'll assume the caller handles the approval process and calls this
            // only when approved, OR we return a "pending" status.
            // Here we'll just proceed for the spine demo.
        }

        // Reconstruct IR
        let ir = TabularIR(
            schema: TableSchema(columns: []),
            rowCount: Int(artifact.metadata["rowCount"] ?? "0") ?? 0,
            storagePointer: artifact.contentHash,
            parsingDiagnostics: []
        )

        let (newIR, change) = try await transformEngine.apply(transform: transform, to: ir)

        let newArtifact = Artifact(
            id: UUID().uuidString,
            type: .tabularIR,
            contentHash: newIR.storagePointer,
            metadata: ["rowCount": String(newIR.rowCount)]
        )

        return (newArtifact, change)
    }

    public func query(viewSpec: ViewSpec) async throws -> Artifact {
        // Check cache
        let cacheKey = "query-\(viewSpec.sourceSnapshotId)-\(viewSpec.query.hash)"
        if let cached = await cacheManager.get(key: cacheKey) {
            return cached
        }

        // Execute Query
        let ir = try await queryEngine.execute(viewSpec: viewSpec)

        let result = Artifact(
            id: UUID().uuidString,
            type: .tabularIR,
            contentHash: ir.storagePointer,
            metadata: ["rowCount": String(ir.rowCount)]
        )

        await cacheManager.set(key: cacheKey, artifact: result)
        return result
    }

    public func render(viewSpec: ViewSpec) async throws -> Artifact {
        throw DataEngineError.renderingUnsupported(viewSpec.sourceSnapshotId)
    }
}

public enum DataEngineError: LocalizedError, Sendable {
    case renderingUnsupported(String)

    public var errorDescription: String? {
        switch self {
        case .renderingUnsupported(let source):
            return "DataEngine.render() is not implemented for source \(source)"
        }
    }
}
