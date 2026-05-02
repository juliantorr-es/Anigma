//
//  CoreMLEmbeddingComputer.swift
//  HarmoniaModule
//
//  CoreML-backed implementation of BufferEmbeddingCapability.
//  Following "Swift governs, compute computes": tokenization happens in Swift,
//  embedding computation happens in CoreML with Metal/MPS acceleration.
//  Uses task-based delegation: spawns one delegate per embedding request.
//
//  Enhanced with ANE capsule integration:
//  1. Contract validation before model loading and execution
//  2. Placement verification using PlacementVerifier
//  3. Execution receipt generation for all inference calls
//  4. Fallback routing based on capability declarations
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import InferenceCore
import os.log
@preconcurrency import Foundation
import ContractsCore
import CapabilityCore
import ANECapsuleIntegration
import ANEServicesCore
import CryptoKit

#if canImport(CoreML)
import CoreML
#endif

/// CoreML-backed embedding computer with task-based delegation.
/// Implements BufferEmbeddingCapability for Metal/MPS accelerated embedding.
/// Enhanced with contract validation, placement verification, execution receipts, and fallback routing.
private let logger = Logger(subsystem: "com.anigma.harmonia", category: "actor")
public actor CoreMLEmbeddingComputer: BufferEmbeddingCapability, CapabilityProvider {
    /// Model cache: modelID -> loaded MLModel
    #if canImport(CoreML)
    private var modelCache: [String: MLModel] = [:]
    #endif
    /// Model dimension cache: modelID -> embedding dimension
    private var dimensionCache: [String: Int] = [:]
    /// Contract cache: modelID -> CoreMLArtifactContract
    private var contractCache: [String: CoreMLArtifactContract] = [:]
    /// Placement verifier for ANE compatibility checking
    private let placementVerifier: PlacementVerifier
    /// Execution receipt manager for audit trails
    private let receiptManager: ExecutionReceiptManager
    /// Logger for placement and execution debugging
    private let logger: CoreMLEmbeddingLogger
    
    public init(
        placementVerifier: PlacementVerifier = PlacementVerifier(),
        receiptManager: ExecutionReceiptManager = ExecutionReceiptManager(),
        logger: CoreMLEmbeddingLogger = CoreMLEmbeddingLogger()
    ) {
        self.placementVerifier = placementVerifier
        self.receiptManager = receiptManager
        self.logger = logger
    }
    
// MARK: - CapabilityProvider

public nonisolated let providerId: String = "anigma.provider.embedding.coreml"

public nonisolated var supportedCapabilities: [String] {
    [BufferEmbeddingCapability.capabilityId]
}
}

// MARK: - ANE Capsule Integration

// ANE capsule descriptor for CoreML embedding computer
public extension CoreMLEmbeddingComputer {
    static let aneCapsuleDescriptor = ANECapsuleDescriptor(
        id: "anigma.capsule.embedding.coreml",
        displayName: "CoreML Embedding Computer",
        version: "1.0.0",
        gate: ANEGateInfo(status: .open),
        supportedComputeUnits: [.cpu, .gpu, .neuralEngine, .all],
        defaultComputeUnit: .all,
        tags: ["embedding", "coreml", "inference", "ane"]
    )
}

/// Runtime profile for embedding computations
public struct CoreMLEmbeddingProfile: Sendable {
    public let computeUnit: ANEComputeUnit
    public let allowFallback: Bool
    public let requireContractValidation: Bool
    public let generateExecutionReceipts: Bool
    public let maxBatchSize: Int
    public let parityMode: CoreMLParityMode
    public let paritySampleCount: Int
    public let parityTolerance: Double
    
    public init(
        computeUnit: ANEComputeUnit = .all,
        allowFallback: Bool = true,
        requireContractValidation: Bool = true,
        generateExecutionReceipts: Bool = true,
        maxBatchSize: Int = 8,
        parityMode: CoreMLParityMode = .off,
        paritySampleCount: Int = 1,
        parityTolerance: Double = 0.001
    ) {
        self.computeUnit = computeUnit
        self.allowFallback = allowFallback
        self.requireContractValidation = requireContractValidation
        self.generateExecutionReceipts = generateExecutionReceipts
        self.maxBatchSize = maxBatchSize
        self.parityMode = parityMode
        self.paritySampleCount = paritySampleCount
        self.parityTolerance = parityTolerance
    }
}

/// Parity validation mode for compute routing.
public enum CoreMLParityMode: String, Sendable {
    case off
    case sampled
    case strict
}

/// Execution plan returned by the compute scheduler.
public struct CoreMLExecutionPlan: Sendable {
    public let requestedComputeUnit: ANEComputeUnit
    public let primaryComputeUnit: ANEComputeUnit
    public let fallbackComputeUnits: [ANEComputeUnit]
    public let parityMode: CoreMLParityMode
    public let paritySampleCount: Int
    public let parityTolerance: Double
    public let useDoubleBuffering: Bool
    public let reason: String

    public init(
        requestedComputeUnit: ANEComputeUnit,
        primaryComputeUnit: ANEComputeUnit,
        fallbackComputeUnits: [ANEComputeUnit],
        parityMode: CoreMLParityMode,
        paritySampleCount: Int,
        parityTolerance: Double,
        useDoubleBuffering: Bool,
        reason: String
    ) {
        self.requestedComputeUnit = requestedComputeUnit
        self.primaryComputeUnit = primaryComputeUnit
        self.fallbackComputeUnits = fallbackComputeUnits
        self.parityMode = parityMode
        self.paritySampleCount = paritySampleCount
        self.parityTolerance = parityTolerance
        self.useDoubleBuffering = useDoubleBuffering
        self.reason = reason
    }
}

/// Result of a parity validation pass.
public struct CoreMLParityOutcome: Sendable {
    public let embeddings: [[Float]]
    public let computeUnitUsed: ANEComputeUnit

    public init(embeddings: [[Float]], computeUnitUsed: ANEComputeUnit) {
        self.embeddings = embeddings
        self.computeUnitUsed = computeUnitUsed
    }
}

/// Small scheduler that chooses an explicit compute order and fallback chain.
private actor CoreMLComputeScheduler {
    func makePlan(
        modelID: String,
        modelVersion: String?,
        tokenBuffers: [TokenBuffer],
        profile: CoreMLEmbeddingProfile
    ) -> CoreMLExecutionPlan {
        let primary = preferredPrimaryUnit(for: profile, tokenCount: tokenBuffers.count)
        let fallbackComputeUnits = computeFallbackChain(
            for: primary,
            profile: profile
        )
        let reason = buildReason(
            modelID: modelID,
            modelVersion: modelVersion,
            primary: primary,
            fallbacks: fallbackComputeUnits,
            tokenCount: tokenBuffers.count,
            profile: profile
        )

        return CoreMLExecutionPlan(
            requestedComputeUnit: profile.computeUnit,
            primaryComputeUnit: primary,
            fallbackComputeUnits: fallbackComputeUnits,
            parityMode: profile.parityMode,
            paritySampleCount: max(1, min(profile.paritySampleCount, tokenBuffers.count)),
            parityTolerance: profile.parityTolerance,
            useDoubleBuffering: tokenBuffers.count > 1 && profile.maxBatchSize > 1,
            reason: reason
        )
    }

    private func preferredPrimaryUnit(
        for profile: CoreMLEmbeddingProfile,
        tokenCount: Int
    ) -> ANEComputeUnit {
        switch profile.computeUnit {
        case .neuralEngine:
            return .neuralEngine
        case .gpu:
            return .gpu
        case .cpu:
            return .cpu
        case .all:
            return tokenCount > 1 ? .neuralEngine : .gpu
        }
    }

    private func computeFallbackChain(
        for primary: ANEComputeUnit,
        profile: CoreMLEmbeddingProfile
    ) -> [ANEComputeUnit] {
        guard profile.allowFallback else { return [] }

        switch primary {
        case .neuralEngine:
            return [.gpu, .cpu]
        case .gpu:
            return [.cpu]
        case .cpu:
            return []
        case .all:
            return [.neuralEngine, .gpu, .cpu]
        }
    }

    private func buildReason(
        modelID: String,
        modelVersion: String?,
        primary: ANEComputeUnit,
        fallbacks: [ANEComputeUnit],
        tokenCount: Int,
        profile: CoreMLEmbeddingProfile
    ) -> String {
        let modelSuffix = modelVersion.map { "@\($0)" } ?? ""
        let fallbackLabel = fallbacks.isEmpty
            ? "no fallback"
            : "fallbacks: \(fallbacks.map { $0.rawValue }.joined(separator: "→"))"
        return "model=\(modelID)\(modelSuffix), tokens=\(tokenCount), primary=\(primary.rawValue), \(fallbackLabel), parity=\(profile.parityMode.rawValue)"
    }
}
    
// MARK: - BufferEmbeddingCapability

public func computeEmbeddings(
    modelID: String,
    modelVersion: String?,
    tokenBuffers: [TokenBuffer],
    normalize: Bool
) async throws -> [[Float]] {
    try await computeEmbeddings(
        modelID: modelID,
        modelVersion: modelVersion,
        tokenBuffers: tokenBuffers,
        normalize: normalize,
        profile: CoreMLEmbeddingProfile()
    )
}

/// Enhanced compute embeddings with ANE capsule integration
    public func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        tokenBuffers: [TokenBuffer],
        normalize: Bool,
        profile: CoreMLEmbeddingProfile
    ) async throws -> [[Float]] {
        #if canImport(CoreML)
        let startTime = Date()
        let executionId = UUID().uuidString
        let scheduler = CoreMLComputeScheduler()

        do {
            // Log execution start
            logger.logExecutionStart(
                executionId: executionId,
                modelID: modelID,
                tokenBufferCount: tokenBuffers.count,
                profile: profile
            )

            // 1. Contract validation (if required)
            if profile.requireContractValidation {
                try await validateContract(
                    modelID: modelID,
                    modelVersion: modelVersion,
                    executionId: executionId
                )
            }

            // 2. Build an explicit compute routing plan.
            let executionPlan = await scheduler.makePlan(
                modelID: modelID,
                modelVersion: modelVersion,
                tokenBuffers: tokenBuffers,
                profile: profile
            )
            log.info("[\(executionId)] Compute plan: \(executionPlan.reason)")

            // 3. Placement verification and model loading.
            let modelURL = try await resolveModelURL(modelID: modelID, modelVersion: modelVersion)
            let (model, placementResult, computeUnitUsed) = try await verifyAndLoadModel(
                modelURL: modelURL,
                modelID: modelID,
                modelVersion: modelVersion,
                profile: profile,
                executionPlan: executionPlan,
                executionId: executionId
            )

            // 4. Process token buffers with execution receipts
            let embeddings = try await processTokenBuffers(
                model: model,
                tokenBuffers: tokenBuffers,
                normalize: normalize,
                profile: profile,
                placementResult: placementResult,
                executionId: executionId
            )

            // 5. Validate parity for CPU/GPU/ANE routing when requested.
            let parityOutcome = try await validateParityIfNeeded(
                primaryEmbeddings: embeddings,
                modelURL: modelURL,
                modelID: modelID,
                modelVersion: modelVersion,
                tokenBuffers: tokenBuffers,
                normalize: normalize,
                profile: profile,
                executionPlan: executionPlan,
                primaryComputeUnit: computeUnitUsed,
                executionId: executionId
            )
            let finalEmbeddings = parityOutcome?.embeddings ?? embeddings
            let finalComputeUnitUsed = parityOutcome?.computeUnitUsed ?? computeUnitUsed

            // 6. Generate execution receipt (if required)
            if profile.generateExecutionReceipts {
                try await generateExecutionReceipt(
                    executionId: executionId,
                    modelID: modelID,
                    tokenBuffers: tokenBuffers,
                    embeddings: finalEmbeddings,
                    profile: profile,
                    computeUnitUsed: finalComputeUnitUsed,
                    startTime: startTime,
                    success: true
                )
            }

            // Log execution completion
            logger.logExecutionCompletion(
                executionId: executionId,
                success: true,
                embeddingCount: finalEmbeddings.count
            )

            return finalEmbeddings
        } catch {
            // Log execution failure
            logger.logExecutionFailure(
                executionId: executionId,
                error: error,
                modelID: modelID
            )

            // Generate failure receipt (if required)
            if profile.generateExecutionReceipts {
                try? await generateExecutionReceipt(
                    executionId: executionId,
                    modelID: modelID,
                    tokenBuffers: tokenBuffers,
                    embeddings: [],
                    profile: profile,
                    computeUnitUsed: profile.computeUnit,
                    startTime: startTime,
                    success: false,
                    error: error
                )
            }

            throw error
        }
        #else
        throw CoreMLEmbeddingError.coreMLNotAvailable
        #endif
    }
    
public func embeddingDimension(
    modelID: String,
    modelVersion: String?
) async throws -> Int {
    #if canImport(CoreML)
    let cacheKey = modelCacheKey(modelID: modelID, modelVersion: modelVersion)
    if let cached = dimensionCache[cacheKey] {
        return cached
    }
    
    // Load model to determine dimension
    let model = try await loadModel(modelID: modelID, modelVersion: modelVersion)
    let dimension = try inferEmbeddingDimension(model: model)
    
    // Cache dimension
    dimensionCache[cacheKey] = dimension
    return dimension
    #else
    throw CoreMLEmbeddingError.coreMLNotAvailable
    #endif
}

// MARK: - Enhanced Model Loading with Contract Validation

#if canImport(CoreML)
private func validateContract(
    modelID: String,
    modelVersion: String?,
    executionId: String
) async throws {
    let cacheKey = modelCacheKey(modelID: modelID, modelVersion: modelVersion)
    
    // Check cache first
    if let cachedContract = contractCache[cacheKey] {
        logger.logContractValidation(
            executionId: executionId,
            modelID: modelID,
            cached: true
        )
        return
    }
    
    // Resolve model path
    let modelPath = try await resolveModelPath(modelID: modelID, modelVersion: modelVersion)
    let modelURL = URL(fileURLWithPath: modelPath)
    
    // Load and validate contract
    logger.logContractValidationStart(
        executionId: executionId,
        modelID: modelID,
        modelURL: modelURL
    )
    
    // In a real implementation, this would load a contract file associated with the model
    // For now, we'll create a minimal contract for demonstration
    let contract = try createMinimalContract(for: modelURL, modelID: modelID)
    
    // Validate contract invariants
    try CoreMLArtifactContract.validateInvariants(contract)
    
    // Cache contract
    contractCache[cacheKey] = contract
    
    logger.logContractValidationCompletion(
        executionId: executionId,
        modelID: modelID,
        success: true
    )
}

private func createMinimalContract(for modelURL: URL, modelID: String) throws -> CoreMLArtifactContract {
    // Create minimal schema
    let schema = CoreMLSchema(
        description: "Embedding model: \(modelID)",
        inputs: [
            IOTensorSpec(
                name: "input_ids",
                dataType: .int32,
                shape: TensorShape(batch: -1, channels: 1, height: 1, width: 512), // Example shape
                coordinateSystem: CoordinateSystem()
            ),
            IOTensorSpec(
                name: "attention_mask",
                dataType: .float32,
                shape: TensorShape(batch: -1, channels: 1, height: 1, width: 512),
                coordinateSystem: CoordinateSystem()
            )
        ],
        outputs: [
            IOTensorSpec(
                name: "embedding",
                dataType: .float32,
                shape: TensorShape(batch: -1, channels: 1, height: 1, width: 768), // Example embedding dimension
                coordinateSystem: CoordinateSystem()
            )
        ],
        modelType: "embedding"
    )
    
    // Create limits
    let limits = CoreMLLimits(
        hard: HardLimits(
            maxBatchSize: 32,
            maxMemoryBytes: 2 * 1024 * 1024 * 1024, // 2GB
            maxInferenceTimeMs: 5000,
            maxModelSizeBytes: 500 * 1024 * 1024, // 500MB
            maxInputSizeBytes: 100 * 1024 * 1024, // 100MB
            maxOutputSizeBytes: 100 * 1024 * 1024 // 100MB
        ),
        soft: SoftLimits(
            recommendedBatchSize: 8,
            targetMemoryBytes: 512 * 1024 * 1024, // 512MB
            targetInferenceTimeMs: 1000
        )
    )
    
    // Create versioning
    let versioning = CoreMLVersion(
        semantic: "1.0.0",
        build: "1",
        architectureFingerprint: ArchitectureFingerprint(
            architecture: "Transformer",
            opsetVersion: "1",
            coremlVersion: "5.0",
            compilerVersion: "1.0"
        )
    )
    
    // Create capability
    let capability = CoreMLCapability(
        hardwareCapability: .mixed,
        performanceProfiles: [
            PerformanceProfile(
                hardware: "ANE",
                expectedInferenceTimeMs: 50,
                expectedMemoryBytes: 256 * 1024 * 1024
            ),
            PerformanceProfile(
                hardware: "GPU",
                expectedInferenceTimeMs: 100,
                expectedMemoryBytes: 512 * 1024 * 1024
            ),
            PerformanceProfile(
                hardware: "CPU",
                expectedInferenceTimeMs: 500,
                expectedMemoryBytes: 1024 * 1024 * 1024
            )
        ],
        minOSVersion: "14.0",
        minCoreMLVersion: "5.0"
    )
    
    // Create artifact
    let artifact = CoreMLArtifact(
        artifactId: UUID().uuidString,
        modelHash: try computeModelHash(at: modelURL),
        schema: schema,
        limits: limits,
        versioning: versioning,
        capability: capability,
        metadata: ["model_id": modelID]
    )
    
    return CoreMLArtifactContract(artifact)
}

private func computeModelHash(at modelURL: URL) throws -> String {
    let fileManager = FileManager.default
    guard let attributes = try? fileManager.attributesOfItem(atPath: modelURL.path),
          let fileSize = attributes[.size] as? UInt64 else {
        return "unknown"
    }
    
    // Simplified hash for demonstration
    let hashData = "\(modelURL.path):\(fileSize)".data(using: .utf8)!
    let hash = SHA256.hash(data: hashData)
    return hash.map { String(format: "%02x", $0) }.joined()
}

    private func verifyAndLoadModel(
        modelURL: URL,
        modelID: String,
        modelVersion: String?,
        profile: CoreMLEmbeddingProfile,
        executionPlan: CoreMLExecutionPlan,
        executionId: String
    ) async throws -> (MLModel, CoreMLCompatibilityResult?, ANEComputeUnit) {
        let placementResult = try await verifyPlacementForPlan(
            modelURL: modelURL,
            modelID: modelID,
            profile: profile,
            executionPlan: executionPlan,
            executionId: executionId
        )

        let cacheKey = modelCacheKey(
            modelID: modelID,
            modelVersion: modelVersion,
            computeUnit: placementResult.computeUnit
        )

        if let cachedModel = modelCache[cacheKey] {
            logger.logModelCacheHit(
                executionId: executionId,
                modelID: modelID,
                cacheKey: cacheKey
            )
            return (cachedModel, placementResult.result, placementResult.computeUnit)
        }

        logger.logModelLoadingStart(
            executionId: executionId,
            modelID: modelID,
            computeUnit: placementResult.computeUnit
        )

        let model = try await loadModel(
            modelURL: modelURL,
            modelID: modelID,
            computeUnit: placementResult.computeUnit
        )

        logger.logModelLoadingCompletion(
            executionId: executionId,
            modelID: modelID,
            success: true
        )

        return (model, placementResult.result, placementResult.computeUnit)
    }

    private func verifyPlacementForPlan(
        modelURL: URL,
        modelID: String,
        profile: CoreMLEmbeddingProfile,
        executionPlan: CoreMLExecutionPlan,
        executionId: String
    ) async throws -> (result: CoreMLCompatibilityResult?, computeUnit: ANEComputeUnit) {
        let candidateUnits = [executionPlan.primaryComputeUnit] + executionPlan.fallbackComputeUnits

        for computeUnit in candidateUnits {
            if computeUnit != .cpu {
                logger.logPlacementVerificationStart(
                    executionId: executionId,
                    modelID: modelID,
                    requestedComputeUnit: computeUnit
                )
            }

            let compatibility = try await placementVerifier.verifyCoreMLModel(
                at: modelURL,
                requestedComputeUnit: computeUnit
            )

            if compatibility.isCompatible {
                if computeUnit != .cpu {
                    logger.logPlacementVerificationSuccess(
                        executionId: executionId,
                        modelID: modelID,
                        computeUnit: computeUnit
                    )
                }
                return (compatibility, computeUnit)
            }

            if !profile.allowFallback {
                throw PlacementError.systemIncompatible(
                    computeUnit: computeUnit,
                    reasons: compatibility.issues
                )
            }

            if let nextUnit = candidateUnits.drop(while: { $0 != computeUnit }).dropFirst().first {
                logger.logPlacementFallback(
                    executionId: executionId,
                    modelID: modelID,
                    originalComputeUnit: computeUnit,
                    issues: compatibility.issues
                )
                _ = nextUnit
            }
        }

        throw PlacementError.systemIncompatible(
            computeUnit: executionPlan.primaryComputeUnit,
            reasons: ["No compatible compute unit available"]
        )
    }

    private func processTokenBuffers(
        model: MLModel,
        tokenBuffers: [TokenBuffer],
        normalize: Bool,
        profile: CoreMLEmbeddingProfile,
        placementResult: CoreMLCompatibilityResult?,
        executionId: String
    ) async throws -> [[Float]] {
        var embeddings: [[Float]] = []
        embeddings.reserveCapacity(tokenBuffers.count)
        _ = placementResult

        guard !tokenBuffers.isEmpty else {
            return embeddings
        }

        // Process in batches if profile specifies max batch size.
        // Double-buffer the CPU-side preparation so the next batch is staged while
        // the current batch is executing on CoreML/Metal.
        let batchSize = max(1, min(profile.maxBatchSize, tokenBuffers.count))
        let batchSlices = makeBatchSlices(totalCount: tokenBuffers.count, batchSize: batchSize)
        let totalBatches = batchSlices.count
        let delegate = CoreMLTaskDelegate(
            model: model,
            executionId: executionId,
            logger: logger
        )

        var currentBatchIndex = batchSlices[0].index
        var nextPreparationTask: Task<[PreparedTokenBuffer], Error>?
        var currentPreparedBatch = try await prepareBatch(
            tokenBuffers: Array(tokenBuffers[batchSlices[0].range]),
            executionId: executionId,
            batchIndex: currentBatchIndex,
            logger: logger
        )

        if batchSlices.count > 1 {
            let nextSlice = batchSlices[1]
            nextPreparationTask = Task {
                try await prepareBatch(
                    tokenBuffers: Array(tokenBuffers[nextSlice.range]),
                    executionId: executionId,
                    batchIndex: nextSlice.index,
                    logger: logger
                )
            }
        }

        while true {
            logger.logBatchProcessingStart(
                executionId: executionId,
                batchIndex: currentBatchIndex,
                batchSize: currentPreparedBatch.count,
                totalBatches: totalBatches
            )

            for preparedBuffer in currentPreparedBatch {
                let embedding = try await delegate.computeEmbedding(
                    preparedBuffer: preparedBuffer,
                    normalize: normalize
                )
                embeddings.append(embedding)
            }

            logger.logBatchProcessingCompletion(
                executionId: executionId,
                batchIndex: currentBatchIndex,
                success: true
            )

            guard let nextTask = nextPreparationTask else {
                break
            }

            currentBatchIndex += 1
            currentPreparedBatch = try await nextTask.value

            let nextSliceIndex = currentBatchIndex + 1
            if nextSliceIndex < batchSlices.count {
                let nextSlice = batchSlices[nextSliceIndex]
                nextPreparationTask = Task {
                    try await prepareBatch(
                        tokenBuffers: Array(tokenBuffers[nextSlice.range]),
                        executionId: executionId,
                        batchIndex: nextSlice.index,
                        logger: logger
                    )
                }
            } else {
                nextPreparationTask = nil
            }
        }

        return embeddings
    }

    private func validateParityIfNeeded(
        primaryEmbeddings: [[Float]],
        modelURL: URL,
        modelID: String,
        modelVersion: String?,
        tokenBuffers: [TokenBuffer],
        normalize: Bool,
        profile: CoreMLEmbeddingProfile,
        executionPlan: CoreMLExecutionPlan,
        primaryComputeUnit: ANEComputeUnit,
        executionId: String
    ) async throws -> CoreMLParityOutcome? {
        guard profile.parityMode != .off, primaryComputeUnit != .cpu, !tokenBuffers.isEmpty else {
            return nil
        }

        let sampleCount = max(1, min(executionPlan.paritySampleCount, tokenBuffers.count))
        let sampleBuffers = Array(tokenBuffers.prefix(sampleCount))
        let cpuModel = try await loadModel(
            modelURL: modelURL,
            modelID: modelID,
            computeUnit: .cpu,
            modelVersion: modelVersion
        )

        let cpuSampleEmbeddings = try await processTokenBuffers(
            model: cpuModel,
            tokenBuffers: sampleBuffers,
            normalize: normalize,
            profile: profile,
            placementResult: nil,
            executionId: executionId
        )

        guard embeddingsMatchParity(
            primary: Array(primaryEmbeddings.prefix(sampleCount)),
            fallback: cpuSampleEmbeddings,
            tolerance: executionPlan.parityTolerance
        ) else {
            if profile.allowFallback {
                logger.logExecutionFailure(
                    executionId: executionId,
                    error: CoreMLEmbeddingError.parityCheckFailed(
                        reason: "CPU shadow mismatch for \(modelID)"
                    ),
                    modelID: modelID
                )

                let cpuFullEmbeddings = try await processTokenBuffers(
                    model: cpuModel,
                    tokenBuffers: tokenBuffers,
                    normalize: normalize,
                    profile: profile,
                    placementResult: nil,
                    executionId: executionId
                )
                return CoreMLParityOutcome(
                    embeddings: cpuFullEmbeddings,
                    computeUnitUsed: .cpu
                )
            }

            throw CoreMLEmbeddingError.parityCheckFailed(
                reason: "CPU shadow mismatch for \(modelID)"
            )
        }

        return nil
    }

    private func embeddingsMatchParity(
        primary: [[Float]],
        fallback: [[Float]],
        tolerance: Double
    ) -> Bool {
        guard primary.count == fallback.count, !primary.isEmpty else {
            return false
        }

        for (lhs, rhs) in zip(primary, fallback) {
            guard lhs.count == rhs.count else { return false }

            let maxDelta = zip(lhs, rhs).map { abs($0 - $1) }.max() ?? 0
            if Double(maxDelta) > tolerance {
                return false
            }

            let lhsNorm = sqrt(lhs.reduce(0.0) { $0 + Double($1 * $1) })
            let rhsNorm = sqrt(rhs.reduce(0.0) { $0 + Double($1 * $1) })
            guard lhsNorm > 0, rhsNorm > 0 else { continue }

            let dot = zip(lhs, rhs).reduce(0.0) { $0 + Double($1.0 * $1.1) }
            let cosine = dot / (lhsNorm * rhsNorm)
            if cosine < 1.0 - tolerance {
                return false
            }
        }

        return true
    }

    func makeBatchSlices(totalCount: Int, batchSize: Int) -> [BatchSlice] {
        guard totalCount > 0 else { return [] }
        let size = max(1, batchSize)
        return Array(
            stride(from: 0, to: totalCount, by: size).enumerated().map { batchIndex, start in
                let end = min(start + size, totalCount)
                return BatchSlice(index: batchIndex, range: start..<end)
            }
        )
    }

struct BatchSlice: Equatable {
    let index: Int
    let range: Range<Int>
}

private func prepareBatch(
    tokenBuffers: [TokenBuffer],
    executionId: String,
    batchIndex: Int,
    logger: CoreMLEmbeddingLogger
) async throws -> [PreparedTokenBuffer] {
    await logger.logBatchPreparationStart(
        executionId: executionId,
        batchIndex: batchIndex,
        batchSize: tokenBuffers.count
    )

    let prepared = try tokenBuffers.map { tokenBuffer in
        try PreparedTokenBuffer(tokenBuffer: tokenBuffer)
    }

    await logger.logBatchPreparationCompletion(
        executionId: executionId,
        batchIndex: batchIndex,
        batchSize: prepared.count
    )

    return prepared
}

private func generateExecutionReceipt(
    executionId: String,
    modelID: String,
    tokenBuffers: [TokenBuffer],
    embeddings: [[Float]],
    profile: CoreMLEmbeddingProfile,
    computeUnitUsed: ANEComputeUnit,
    startTime: Date,
    success: Bool,
    error: Error? = nil
) async throws {
    let endTime = Date()
    let executionDuration = endTime.timeIntervalSince(startTime)
    
    // Compute input hash
    let inputData = try JSONEncoder().encode(tokenBuffers)
    let inputHash = SHA256.hash(data: inputData).map { String(format: "%02x", $0) }.joined()
    
    // Compute output hash
    let outputData = try JSONEncoder().encode(embeddings)
    let outputHash = SHA256.hash(data: outputData).map { String(format: "%02x", $0) }.joined()
    
    // Create capsule descriptor
    let descriptor = ANECapsuleDescriptor(
        id: "anigma.capsule.embedding.coreml",
        displayName: "CoreML Embedding Computer",
        version: "1.0.0",
        gate: ANEGateInfo(status: .open),
        supportedComputeUnits: [.cpu, .gpu, .neuralEngine, .all],
        defaultComputeUnit: .all,
        tags: ["embedding", "coreml", "inference", "ane"]
    )
    
    // Generate execution receipt
    let receipt = try await ExecutionReceipt.generate(
        for: descriptor,
        computeUnit: computeUnitUsed,
        inputHash: inputHash,
        outputHash: outputHash,
        performanceMetrics: PerformanceMetrics(
            executionTime: executionDuration,
            cpuUsage: CPUUsage(
                user: 0.0, // Would be collected from system
                system: 0.0,
                idle: 1.0,
                collectionTime: endTime
            ),
            memoryUsageMB: 0, // Would be collected from system
            powerWatts: 0.0, // Would be collected from system
            thermalMetrics: ThermalMetrics(
                state: ProcessInfo.processInfo.thermalState,
                temperature: nil,
                fanSpeed: nil
            ),
            collectionTime: endTime
        )
    )
    
    // Store receipt
    await receiptManager.store(receipt)
    
    logger.logExecutionReceiptGenerated(
        executionId: executionId,
        receiptId: receipt.receiptId,
        success: success,
        error: error?.localizedDescription
    )
}
#endif
    
    public func supportsModel(
        modelID: String,
        modelVersion: String?
    ) async -> Bool {
        do {
            _ = try await embeddingDimension(modelID: modelID, modelVersion: modelVersion)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Model Loading
    
    #if canImport(CoreML)
    private func loadModel(modelID: String, modelVersion: String?) async throws -> MLModel {
        let modelURL = try await resolveModelURL(modelID: modelID, modelVersion: modelVersion)
        return try await loadModel(modelURL: modelURL, modelID: modelID, computeUnit: .all, modelVersion: modelVersion)
    }
    
    private func loadModel(
        modelURL: URL,
        modelID: String,
        computeUnit: ANEComputeUnit,
        modelVersion: String?
    ) async throws -> MLModel {
        let cacheKey = modelCacheKey(
            modelID: modelID,
            modelVersion: modelVersion,
            computeUnit: computeUnit
        )

        if let cached = modelCache[cacheKey] {
            return cached
        }

        let compiledModelURL = try await MLModel.compileModel(at: modelURL)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = configurationForComputeUnit(computeUnit)

        let model = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
        modelCache[cacheKey] = model
        return model
    }

    private func resolveModelURL(modelID: String, modelVersion: String?) async throws -> URL {
        let modelPath = try await resolveModelPath(modelID: modelID, modelVersion: modelVersion)
        return URL(fileURLWithPath: modelPath)
    }

    private func resolveModelPath(modelID: String, modelVersion: String?) async throws -> String {
        let fileManager = FileManager.default
        
        // Check if modelID is already a path to a CoreML model file
        let possibleExtensions = [".mlpackage", ".mlmodel"]
        
        for ext in possibleExtensions {
            let path = "\(modelID)\(ext)"
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        
        // Fallback or model registry integration could go here
        throw CoreMLEmbeddingError.modelNotFound(modelID: modelID, modelVersion: modelVersion)
    }
    
    private func inferEmbeddingDimension(model: MLModel) throws -> Int {
        let outputDescriptions = model.modelDescription.outputDescriptionsByName
        let embeddingOutputNames = ["embedding", "output", "features", "last_hidden_state"]
        
        for outputName in embeddingOutputNames {
            if let output = outputDescriptions[outputName] {
                if output.type == .multiArray {
                    if let shapeConstraint = output.multiArrayConstraint {
                        let shape = shapeConstraint.shape
                        if shape.count == 2 && shape[0] == 1 {
                            return shape[1].intValue
                        } else if shape.count == 1 {
                            return shape[0].intValue
                        }
                    }
                }
            }
        }
        
        if let firstOutput = outputDescriptions.values.first {
            if firstOutput.type == .multiArray,
               let shapeConstraint = firstOutput.multiArrayConstraint {
                let shape = shapeConstraint.shape
                if shape.count >= 1 {
                    return shape.last!.intValue
                }
            }
        }
        
        throw CoreMLEmbeddingError.cannotInferDimension
    }
    #endif
    
    // MARK: - Utility
    
    private func modelCacheKey(modelID: String, modelVersion: String?) -> String {
        if let version = modelVersion {
            return "\(modelID)@\(version)"
        }
        return modelID
    }

    private func modelCacheKey(
        modelID: String,
        modelVersion: String?,
        computeUnit: ANEComputeUnit
    ) -> String {
        "\(modelCacheKey(modelID: modelID, modelVersion: modelVersion))#\(computeUnit.rawValue)"
    }

    private func configurationForComputeUnit(_ computeUnit: ANEComputeUnit) -> MLComputeUnits {
        switch computeUnit {
        case .neuralEngine:
            return .cpuAndNeuralEngine
        case .gpu:
            return .cpuAndGPU
        case .cpu:
            return .cpuOnly
        case .all:
            return .all
        }
    }

// MARK: - Task Delegate

#if canImport(CoreML)
private actor CoreMLTaskDelegate {
    private let model: MLModel
    private let executionId: String
    private let logger: CoreMLEmbeddingLogger
    
    init(model: MLModel, executionId: String, logger: CoreMLEmbeddingLogger) {
        self.model = model
        self.executionId = executionId
        self.logger = logger
    }
    
    func computeEmbedding(
        preparedBuffer: PreparedTokenBuffer,
        normalize: Bool
    ) async throws -> [Float] {
        let inferenceStart = Date()
        let tokenBuffer = preparedBuffer.tokenBuffer
        
        logger.logInferenceStart(
            executionId: executionId,
            tokenBufferId: tokenBuffer.id?.uuidString ?? "unknown",
            sequenceLength: tokenBuffer.tokenIds.count
        )
        
        do {
            let input = CoreMLEmbeddingInput(
                input_ids: preparedBuffer.inputIds,
                attention_mask: preparedBuffer.attentionMask
            )
            
            let prediction = try await model.prediction(from: input)
            
            guard let embeddingFeature = prediction.featureValue(for: "embedding") else {
                throw CoreMLEmbeddingError.invalidOutput("Model output does not contain 'embedding' feature")
            }
            
            guard let multiArray = embeddingFeature.multiArrayValue else {
                throw CoreMLEmbeddingError.invalidOutput("Embedding output is not a multi-array")
            }
            
            let embedding = multiArray.toFloatArray()
            let result = normalize ? normalizeVector(embedding) : embedding
            
            let inferenceDuration = Date().timeIntervalSince(inferenceStart)
            
            logger.logInferenceCompletion(
                executionId: executionId,
                tokenBufferId: tokenBuffer.id?.uuidString ?? "unknown",
                duration: inferenceDuration,
                embeddingDimension: embedding.count
            )
            
            return result
        } catch {
            logger.logInferenceFailure(
                executionId: executionId,
                tokenBufferId: tokenBuffer.id?.uuidString ?? "unknown",
                error: error
            )
            throw error
        }
    }
    
    private func normalizeVector(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0.0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}

#if canImport(CoreML)
private struct PreparedTokenBuffer: @unchecked Sendable {
    let tokenBuffer: TokenBuffer
    let inputIds: MLMultiArray
    let attentionMask: MLMultiArray

    init(tokenBuffer: TokenBuffer) throws {
        self.tokenBuffer = tokenBuffer
        self.inputIds = try PreparedTokenBuffer.makeInputArray(tokenBuffer: tokenBuffer)
        self.attentionMask = try PreparedTokenBuffer.makeAttentionMask(tokenBuffer: tokenBuffer)
    }

    private static func makeInputArray(tokenBuffer: TokenBuffer) throws -> MLMultiArray {
        let sequenceLength = tokenBuffer.tokenIds.count
        let shape = [NSNumber(value: 1), NSNumber(value: sequenceLength)]

        guard let array = try? MLMultiArray(shape: shape, dataType: .int32) else {
            throw CoreMLEmbeddingError.inputPreparationFailed
        }

        for (index, tokenId) in tokenBuffer.tokenIds.enumerated() {
            array[index] = NSNumber(value: tokenId)
        }

        return array
    }

    private static func makeAttentionMask(tokenBuffer: TokenBuffer) throws -> MLMultiArray {
        let sequenceLength = tokenBuffer.attentionMask.count
        let shape = [NSNumber(value: 1), NSNumber(value: sequenceLength)]

        guard let array = try? MLMultiArray(shape: shape, dataType: .float32) else {
            throw CoreMLEmbeddingError.inputPreparationFailed
        }

        for (index, maskValue) in tokenBuffer.attentionMask.enumerated() {
            array[index] = NSNumber(value: Float(maskValue))
        }

        return array
    }
}
#endif

private class CoreMLEmbeddingInput: NSObject, MLFeatureProvider {
    let input_ids: MLMultiArray
    let attention_mask: MLMultiArray
    
    var featureNames: Set<String> {
        return ["input_ids", "attention_mask"]
    }
    
    init(input_ids: MLMultiArray, attention_mask: MLMultiArray) {
        self.input_ids = input_ids
        self.attention_mask = attention_mask
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "input_ids":
            return MLFeatureValue(multiArray: input_ids)
        case "attention_mask":
            return MLFeatureValue(multiArray: attention_mask)
        default:
            return nil
        }
    }
}

extension MLMultiArray {
    func toFloatArray() -> [Float] {
        let count = self.count
        var floats = [Float](repeating: 0, count: count)
        for i in 0..<count {
            floats[i] = self[i].floatValue
        }
        return floats
    }
}
#endif

// MARK: - Logger

/// Logger for CoreML embedding computer with placement and execution tracking
public actor CoreMLEmbeddingLogger {
    private let logLevel: LogLevel
    
    public enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    public init(logLevel: LogLevel = .info) {
        self.logLevel = logLevel
    }
    
    // MARK: - Execution Logging
    
    func logExecutionStart(
        executionId: String,
        modelID: String,
        tokenBufferCount: Int,
        profile: CoreMLEmbeddingProfile
    ) {
        log(.info, "[\(executionId)] Starting execution: model=\(modelID), buffers=\(tokenBufferCount), computeUnit=\(profile.computeUnit)")
    }
    
    func logExecutionCompletion(
        executionId: String,
        success: Bool,
        embeddingCount: Int
    ) {
        log(.info, "[\(executionId)] Execution completed: success=\(success), embeddings=\(embeddingCount)")
    }
    
    func logExecutionFailure(
        executionId: String,
        error: Error,
        modelID: String
    ) {
        log(.error, "[\(executionId)] Execution failed: model=\(modelID), error=\(error.localizedDescription)")
    }
    
    // MARK: - Contract Validation Logging
    
    func logContractValidation(
        executionId: String,
        modelID: String,
        cached: Bool
    ) {
        log(.debug, "[\(executionId)] Contract validation: model=\(modelID), cached=\(cached)")
    }
    
    func logContractValidationStart(
        executionId: String,
        modelID: String,
        modelURL: URL
    ) {
        log(.info, "[\(executionId)] Starting contract validation: model=\(modelID), url=\(modelURL.path)")
    }
    
    func logContractValidationCompletion(
        executionId: String,
        modelID: String,
        success: Bool
    ) {
        let level: LogLevel = success ? .info : .error
        log(level, "[\(executionId)] Contract validation completed: model=\(modelID), success=\(success)")
    }
    
    // MARK: - Placement Verification Logging
    
    func logPlacementVerificationStart(
        executionId: String,
        modelID: String,
        requestedComputeUnit: ANEComputeUnit
    ) {
        log(.info, "[\(executionId)] Starting placement verification: model=\(modelID), computeUnit=\(requestedComputeUnit)")
    }
    
    func logPlacementVerificationSuccess(
        executionId: String,
        modelID: String,
        computeUnit: ANEComputeUnit
    ) {
        log(.info, "[\(executionId)] Placement verification successful: model=\(modelID), computeUnit=\(computeUnit)")
    }
    
    func logPlacementFallback(
        executionId: String,
        modelID: String,
        originalComputeUnit: ANEComputeUnit,
        issues: [String]
    ) {
        log(.warning, "[\(executionId)] Placement fallback triggered: model=\(modelID), original=\(originalComputeUnit), issues=\(issues.joined(separator: ", "))")
    }
    
    func logPlacementFallbackSuccess(
        executionId: String,
        modelID: String,
        fallbackComputeUnit: ANEComputeUnit
    ) {
        log(.info, "[\(executionId)] Placement fallback successful: model=\(modelID), fallback=\(fallbackComputeUnit)")
    }
    
    // MARK: - Model Loading Logging
    
    func logModelCacheHit(
        executionId: String,
        modelID: String,
        cacheKey: String
    ) {
        log(.debug, "[\(executionId)] Model cache hit: model=\(modelID), key=\(cacheKey)")
    }
    
    func logModelLoadingStart(
        executionId: String,
        modelID: String,
        computeUnit: ANEComputeUnit
    ) {
        log(.info, "[\(executionId)] Loading model: model=\(modelID), computeUnit=\(computeUnit)")
    }
    
    func logModelLoadingCompletion(
        executionId: String,
        modelID: String,
        success: Bool
    ) {
        let level: LogLevel = success ? .info : .error
        log(level, "[\(executionId)] Model loading completed: model=\(modelID), success=\(success)")
    }
    
    // MARK: - Batch Processing Logging
    
    func logBatchProcessingStart(
        executionId: String,
        batchIndex: Int,
        batchSize: Int,
        totalBatches: Int
    ) {
        log(.debug, "[\(executionId)] Processing batch \(batchIndex + 1)/\(totalBatches): size=\(batchSize)")
    }
    
    func logBatchProcessingCompletion(
        executionId: String,
        batchIndex: Int,
        success: Bool
    ) {
        log(.debug, "[\(executionId)] Batch \(batchIndex + 1) completed: success=\(success)")
    }

    func logBatchPreparationStart(
        executionId: String,
        batchIndex: Int,
        batchSize: Int
    ) {
        log(.debug, "[\(executionId)] Preparing batch \(batchIndex + 1): size=\(batchSize)")
    }

    func logBatchPreparationCompletion(
        executionId: String,
        batchIndex: Int,
        batchSize: Int
    ) {
        log(.debug, "[\(executionId)] Batch \(batchIndex + 1) prepared: size=\(batchSize)")
    }
    
    // MARK: - Inference Logging
    
    func logInferenceStart(
        executionId: String,
        tokenBufferId: String,
        sequenceLength: Int
    ) {
        log(.debug, "[\(executionId)] Starting inference: buffer=\(tokenBufferId), seqLen=\(sequenceLength)")
    }
    
    func logInferenceCompletion(
        executionId: String,
        tokenBufferId: String,
        duration: TimeInterval,
        embeddingDimension: Int
    ) {
        log(.debug, "[\(executionId)] Inference completed: buffer=\(tokenBufferId), duration=\(String(format: "%.3f", duration))s, dim=\(embeddingDimension)")
    }
    
    func logInferenceFailure(
        executionId: String,
        tokenBufferId: String,
        error: Error
    ) {
        log(.error, "[\(executionId)] Inference failed: buffer=\(tokenBufferId), error=\(error.localizedDescription)")
    }
    
    // MARK: - Execution CoreReceipt Logging
    
    func logExecutionReceiptGenerated(
        executionId: String,
        receiptId: String,
        success: Bool,
        error: String? = nil
    ) {
        if success {
            log(.info, "[\(executionId)] Execution receipt generated: receipt=\(receiptId)")
        } else {
            log(.error, "[\(executionId)] Execution receipt generated (failure): receipt=\(receiptId), error=\(error ?? "unknown")")
        }
    }
    
    // MARK: - Private Methods
    
    private func log(_ level: LogLevel, _ message: String) {
        guard level >= logLevel else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let levelString = String(describing: level).uppercased()
        
        log.info("[\(timestamp)] [\(levelString)] \(message)")
    }
}

// MARK: - Errors

public enum CoreMLEmbeddingError: Error, LocalizedError {
    case coreMLNotAvailable
    case modelNotFound(modelID: String, modelVersion: String?)
    case inputPreparationFailed
    case invalidOutput(String)
    case cannotInferDimension
    case contractValidationFailed(String)
    case placementVerificationFailed(String)
    case parityCheckFailed(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .coreMLNotAvailable:
            return "CoreML is not available on this platform"
        case .modelNotFound(let modelID, let modelVersion):
            return "CoreML model '\(modelID)' not found"
        case .inputPreparationFailed:
            return "Failed to prepare input tensor"
        case .invalidOutput(let reason):
            return "Invalid model output: \(reason)"
        case .cannotInferDimension:
            return "Cannot infer embedding dimension"
        case .contractValidationFailed(let reason):
            return "Contract validation failed: \(reason)"
        case .placementVerificationFailed(let reason):
            return "Placement verification failed: \(reason)"
        case .parityCheckFailed(let reason):
            return "Parity check failed: \(reason)"
        }
    }
}
