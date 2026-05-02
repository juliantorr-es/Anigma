import Foundation
import ContextumModule
import ContractsCore
import AnigmaHostMac
import MLWorkerCommon
import CryptoKit

// Type disambiguation: Both ContextumModule and ContractsCore define EmbeddingComputing
// Import specific types to help the compiler
@MainActor
public final class ContextumIntegration {
    private let mlWorkerClient: MLWorkerClient
    private let modelRegistry: ModelRegistry

    public init(
        mlWorkerClient: MLWorkerClient,
        modelRegistry: ModelRegistry
    ) {
        self.mlWorkerClient = mlWorkerClient
        self.modelRegistry = modelRegistry
    }

    /// Create MLWorkerEmbeddingExecutor with injected dependencies
    public func createEmbeddingExecutor() -> MLWorkerEmbeddingExecutor {
        // Create concrete implementation types
        let computing = ConcreteEmbeddingComputing(mlWorkerClient: mlWorkerClient)
        let registry = ConcreteModelRegistry(appRegistry: modelRegistry)

        // Note: ConcreteEmbeddingComputing implements ContextumModule.EmbeddingComputing
        // (returns EmbeddingComputeResult, not ContractsCore.EmbeddingResult)
        return MLWorkerEmbeddingExecutor(
            embeddingComputing: computing,
            modelRegistry: registry
        )
    }
}

// MARK: - Concrete Implementations

/// Concrete type wrapping MLWorkerClient for embedding computation
/// Conforms to ContextumModule.EmbeddingComputing (not ContractsCore.EmbeddingComputing)
private struct ConcreteEmbeddingComputing: ContextumModule.EmbeddingComputing {
    let mlWorkerClient: MLWorkerClient

    func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> ContextumModule.EmbeddingComputeResult {
        var vectors: [[Double]] = []
        var inputHashes: [String] = []

        for input in inputs {
            let inputHash = SHA256.hash(data: Data(input.utf8))
                .compactMap { String(format: "%02x", $0) }
                .joined()
            inputHashes.append(inputHash)

            let artifactRef = MLWorkerCommon.MLArtifactRef(
                path: "",
                hash: inputHash
            )

            let response = try await mlWorkerClient.runTask(
                engine: "mlx",
                task: .embed,
                inputs: [artifactRef],
                options: MLTaskOptions(
                    seed: 42,
                    maxTokens: nil,
                    temperature: nil,
                    topP: nil,
                    outputDirectory: nil
                )
            )

            guard let output = response.outputs.first else {
                throw EmbeddingError.outputMismatch
            }

            let vectorData = try Data(contentsOf: URL(fileURLWithPath: output.path))
            let decoder = JSONDecoder()
            let vector = try decoder.decode([Double].self, from: vectorData)

            vectors.append(vector)
        }

        let dimension = vectors.first?.count ?? 0

        return ContextumModule.EmbeddingComputeResult(
            vectors: vectors,
            dimension: dimension,
            inputHashes: inputHashes
        )
    }
}

/// Concrete type wrapping ModelRegistry for ContextumModule access
private actor ConcreteModelRegistry: ContextumModule.ModelRegistryProtocol {
    private let appRegistry: ModelRegistry
    private var usageCounts: [String: Int] = [:]

    init(appRegistry: ModelRegistry) {
        self.appRegistry = appRegistry
    }

    func find(id: String) async throws -> ContextumModule.ModelRegistryEntry? {
        guard let appModelSpec = try await appRegistry.find(id: id) else {
            return nil
        }

        let contractsModelSpec = try convertToContractsModelSpec(appModelSpec)
        return ContextumModule.ModelRegistryEntry(id: id, spec: contractsModelSpec)
    }

    func recordUsage(_ id: String) async throws {
        usageCounts[id, default: 0] += 1
    }

    private func convertToContractsModelSpec(_ appSpec: ModelSpec) throws -> ContractsCore.ModelSpec {
        let source: ContractsCore.ModelSource
        switch appSpec.source.type {
        case .huggingface:
            source = .huggingFace(
                repo: appSpec.source.location,
                revision: appSpec.source.revision ?? "main"
            )
        case .local:
            source = .localPath(appSpec.source.location)
        case .bundled:
            source = .bundled(appSpec.source.location)
        }

        let task = convertTaskKind(appSpec.taskKind)
        let backend = convertBackend(appSpec.backendFormat)
        let trustTier = convertTrustTier(appSpec.trustTier)
        let license = ContractsCore.LicenseDecision(
            declared: appSpec.license ?? "unknown",
            allowed: true,
            reason: nil,
            extraTerms: [],
            timestamp: Date()
        )

        return ContractsCore.ModelSpec(
            id: appSpec.modelId,
            source: source,
            task: task,
            backend: backend,
            trustTier: trustTier,
            license: license,
            artifactHashes: ["main": appSpec.modelHash],
            tokenizerHash: appSpec.tokenizerHash,
            conversionReceipt: nil,
            metadata: [
                "dimension": appSpec.dimension.map(String.init) ?? "",
                "version": ""
            ]
        )
    }

    private func convertTaskKind(_ task: TaskKind) -> ContractsCore.ModelTaskKind {
        switch task {
        case .embedding: return .embedding
        case .inference: return .inference
        case .classification: return .classification
        case .transcription: return .transcription
        case .imageGeneration: return .imageGeneration
        case .speechSynthesis: return .speechSynthesis
        }
    }

    private func convertBackend(_ backend: String) -> ContractsCore.MLBackend {
        switch backend.lowercased() {
        case "mlx": return .mlx
        case "gguf": return .gguf
        case "coreml": return .coreml
        default: return .mlx
        }
    }

    private func convertTrustTier(_ tier: TrustTier) -> ContractsCore.ModelTrustTier {
        switch tier {
        case .firstClass: return .firstClass
        case .compatible: return .compatible
        case .experimental: return .experimental
        }
    }
}

// MARK: - Type Aliases for App ModelSpec

// Note: Types are already available from AnigmaAppMac module
// ModelSpec, ModelSourceType, TaskKind, TrustTier are directly accessible
