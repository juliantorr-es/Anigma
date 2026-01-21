//
//  VectorumModule.swift
//  VectorumModule
//
//  [Brief description of file purpose]
//

import ContractsCore
import Foundation
import AnigmaCore
import CapabilityCore

#if canImport(HarmoniaModule)
import HarmoniaModule
#endif

#if canImport(CanonicalTokenizer)
import CanonicalTokenizer
#endif

#if canImport(DatabaseCore)
import DatabaseCore
#endif

#if canImport(ModelRegistryModule)
import ModelRegistryModule
#endif

/// Type alias to resolve EmbeddingResult ambiguity between ContractsCore and AnigmaCore
typealias EmbeddingResult = ContractsCore.EmbeddingResult

/// VectorumModule - embedding computation capabilities
public enum VectorumModule: CapabilityModule {
    public static let version = "0.1.0"

    public static func register(runtime: PlatformRuntime) async throws {
        await Logger.shared.info("VectorumModule registered", category: "VectorumModule")
        
        // Register CoreML embedding capability if available
        #if canImport(CoreML) && canImport(HarmoniaModule)
        // Create ModelRegistryModule instance if available for model path resolution
        var modelRegistry: ModelRegistryModule? = nil
        #if canImport(ModelRegistryModule) && canImport(DatabaseCore)
        do {
            let databaseAuthority = await runtime.database
            let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
            let modelDb = try await ModelRegistryDatabase(dbActor: databaseAdapter)
            modelRegistry = ModelRegistryModule(database: modelDb)
            await Logger.shared.info(
                "ModelRegistryModule created for CoreMLEmbeddingComputer",
                category: "VectorumModule"
            )
        } catch {
            await Logger.shared.warning(
                "Failed to create ModelRegistryModule: \(error.localizedDescription). CoreMLEmbeddingComputer will fall back to direct file paths.",
                category: "VectorumModule"
            )
        }
        #else
        await Logger.shared.info(
            "ModelRegistryModule not available - CoreMLEmbeddingComputer will use direct file paths",
            category: "VectorumModule"
        )
        #endif
        
        let coreMLProvider = CoreMLEmbeddingComputer(modelRegistry: modelRegistry)
        await CapabilityRegistry.shared.register(provider: coreMLProvider)
        await Logger.shared.info(
            "CoreMLEmbeddingComputer registered as capability provider",
            category: "VectorumModule"
        )
        #else
        await Logger.shared.info(
            "CoreML/HarmoniaModule not available - skipping CoreMLEmbeddingComputer registration",
            category: "VectorumModule"
        )
        #endif
    }
}

/// Deterministic embedding backend used for testing and pipeline wiring.
public final class DeterministicEmbeddingComputer: EmbeddingComputing {
    private let dimension: Int

    public init(dimension: Int = 4) {
        self.dimension = dimension
    }

    public func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> ContractsCore.EmbeddingResult {
        let vectors = inputs.map { text in
            let hash = ContractKeyDerivation.sha256Hex(Data(text.utf8))
            return stride(from: 0, to: dimension, by: 1).map { index in
                let slice = hash.dropFirst(index * 2).prefix(2)
                let value = Int(slice, radix: 16) ?? 0
                return normalize ? Double(value % 100) / 100.0 : Double(value)
            }
        }
        let hashes = inputs.map { ContractKeyDerivation.sha256Hex(Data($0.utf8)) }
        return ContractsCore.EmbeddingResult(
            modelID: modelID,
            modelVersion: modelVersion,
            dimension: dimension,
            vectors: vectors,
            inputHashes: hashes
        )
    }
}

/// Adapter for the ml-worker embedding backend using the JSON line protocol.
public final class MLWorkerEmbeddingComputer: EmbeddingComputing {
    private let mlWorkerPath: String
    private let engine: MLWorkerEngine

    public init(mlWorkerPath: String, engine: MLWorkerEngine = .mlx) {
        self.mlWorkerPath = mlWorkerPath
        self.engine = engine
    }

    public func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> ContractsCore.EmbeddingResult {
        guard !inputs.isEmpty else {
            return ContractsCore.EmbeddingResult(modelID: modelID, modelVersion: modelVersion, dimension: 0, vectors: [], inputHashes: [])
        }

        var vectors: [[Double]] = []
        var inputHashes: [String] = []
        vectors.reserveCapacity(inputs.count)
        inputHashes.reserveCapacity(inputs.count)

        for (index, input) in inputs.enumerated() {
            let inputHash = ContractKeyDerivation.sha256Hex(Data(input.utf8))
            inputHashes.append(inputHash)

            let inputFile = try writeTempInput(input: input)
            defer { try? FileManager.default.removeItem(at: inputFile) }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("vectorum-ml-worker-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: outputDir) }

            let request = MLWorkerRequest(
                requestId: "vectorum-\(UUID().uuidString)",
                runId: "vectorum-\(UUID().uuidString)",
                stepId: "embed-\(index)",
                engine: engine,
                task: .embed,
                inputs: [MLArtifactRef(path: inputFile.path, hash: inputHash)],
                options: MLTaskOptions(seed: 42, outputDirectory: outputDir.path)
            )

            let response = try execute(request: request, mlWorkerPath: mlWorkerPath)
            guard response.status == .completed else {
                throw MLWorkerEmbeddingError.failed(response.errorMessage ?? "ml-worker failed")
            }

            guard let output = response.outputs.first else {
                throw MLWorkerEmbeddingError.failed("ml-worker returned no outputs")
            }

            let embedding = try loadEmbedding(fromHeaderPath: output.path)
            let vector = normalize ? normalizeVector(embedding.vector) : embedding.vector
            vectors.append(vector)
        }

        let dimension = vectors.first?.count ?? 0
        return ContractsCore.EmbeddingResult(
            modelID: modelID,
            modelVersion: modelVersion,
            dimension: dimension,
            vectors: vectors,
            inputHashes: inputHashes
        )
    }
}

public enum MLWorkerEmbeddingError: Error, LocalizedError {
    case failed(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .failed(let message):
            return "ml-worker embedding failed: \(message)"
        case .invalidResponse(let message):
            return "ml-worker response invalid: \(message)"
        }
    }
}

/// Adapter that wraps a BufferEmbeddingCapability to implement EmbeddingComputing.
/// This bridges the gap between Float-based GPU-optimized embedding computation
/// and Double-based EmbeddingComputing protocol.
public final class BufferEmbeddingAdapter: EmbeddingComputing {
    private let bufferCapability: BufferEmbeddingCapability
    private let tokenize: (String) throws -> TokenBuffer
    
    /// Initialize with custom tokenization closure.
    public init(
        bufferCapability: BufferEmbeddingCapability,
        tokenize: @escaping (String) throws -> TokenBuffer
    ) {
        self.bufferCapability = bufferCapability
        self.tokenize = tokenize
    }
    
    /// Convenience initializer with SimpleWordTokenizer from CanonicalTokenizer.
    #if canImport(CanonicalTokenizer)
    public convenience init(
        bufferCapability: BufferEmbeddingCapability,
        tokenizerPolicy: TokenizationPolicy
    ) {
        let tokenizer = SimpleWordTokenizer(policy: tokenizerPolicy)
        self.init(
            bufferCapability: bufferCapability,
            tokenize: { text in try tokenizer.tokenize(text: text) }
        )
    }
    #endif
    
    /// Convenience initializer with simple word-level tokenizer.
    /// This is a placeholder; use CanonicalTokenizer when available.
    public convenience init(bufferCapability: BufferEmbeddingCapability) {
        self.init(
            bufferCapability: bufferCapability,
            tokenize: { text in
                // Simple word-level tokenization (placeholder)
                // In production, replace with CanonicalTokenizer
                let words = text.split(separator: " ").map(String.init)
                let tokenIds = words.map { Int32(abs($0.hashValue) % 30_000) }
                let attentionMask = Array(repeating: UInt8(1), count: tokenIds.count)
                return TokenBuffer(
                    tokenIds: tokenIds,
                    attentionMask: attentionMask,
                    tokenTypeIds: nil
                )
            }
        )
    }
    
    public func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> ContractsCore.EmbeddingResult {
        // Tokenize inputs
        let tokenBuffers = try inputs.map { try tokenize($0) }
        
        // Compute embeddings using buffer capability
        let floatVectors = try await bufferCapability.computeEmbeddings(
            modelID: modelID,
            modelVersion: modelVersion,
            tokenBuffers: tokenBuffers,
            normalize: normalize
        )
        
        // Convert Float to Double for EmbeddingComputing protocol
        let doubleVectors = floatVectors.map { $0.map(Double.init) }
        
        // Compute input hashes (for provenance)
        let inputHashes = inputs.map { ContractKeyDerivation.sha256Hex(Data($0.utf8)) }
        
        // Get embedding dimension
        let dimension = try await bufferCapability.embeddingDimension(
            modelID: modelID,
            modelVersion: modelVersion
        )
        
        return ContractsCore.EmbeddingResult(
            modelID: modelID,
            modelVersion: modelVersion,
            dimension: dimension,
            vectors: doubleVectors,
            inputHashes: inputHashes
        )
    }
}

private struct WorkerEmbeddingHeader: Codable {
    let dataPath: String
    let embeddingDimension: Int?
    let shape: [Int]?
}

private struct LoadedEmbedding {
    let vector: [Double]
}

private func writeTempInput(input: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("vectorum-input-\(UUID().uuidString).txt")
    try input.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func execute(request: MLWorkerRequest, mlWorkerPath: String) throws -> MLWorkerResponse {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: mlWorkerPath)
    process.arguments = ["--engine", request.engine.rawValue]

    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()

    let encoder = JSONEncoder()
    let payload = try encoder.encode(request)
    stdinPipe.fileHandleForWriting.write(payload + Data("\n".utf8))
    stdinPipe.fileHandleForWriting.closeFile()

    process.waitUntilExit()

    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: stdout, encoding: .utf8) else {
        throw MLWorkerEmbeddingError.invalidResponse("Unable to decode stdout")
    }

    guard let line = output.split(separator: "\n").first else {
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw MLWorkerEmbeddingError.invalidResponse("No response line. stderr: \(stderr)")
    }

    let decoder = JSONDecoder()
    return try decoder.decode(MLWorkerResponse.self, from: Data(line.utf8))
}

private func loadEmbedding(fromHeaderPath path: String) throws -> LoadedEmbedding {
    let headerURL = URL(fileURLWithPath: path)
    let headerData = try Data(contentsOf: headerURL)
    let header = try JSONDecoder().decode(WorkerEmbeddingHeader.self, from: headerData)

    let dataURL: URL
    if header.dataPath.hasPrefix("/") {
        dataURL = URL(fileURLWithPath: header.dataPath)
    } else {
        dataURL = headerURL.deletingLastPathComponent().appendingPathComponent(header.dataPath)
    }

    let rawData = try Data(contentsOf: dataURL)
    let floatCount = rawData.count / MemoryLayout<Float>.size
    let floats: [Float] = rawData.withUnsafeBytes { raw in
        let buffer = raw.bindMemory(to: Float.self)
        return Array(buffer.prefix(floatCount))
    }
    let vector = floats.map(Double.init)
    return LoadedEmbedding(vector: vector)
}

private func normalizeVector(_ vector: [Double]) -> [Double] {
    let norm = sqrt(vector.reduce(0.0) { $0 + $1 * $1 })
    guard norm > 0 else { return vector }
    return vector.map { $0 / norm }
}
