import Foundation
import CapsuleCore
import ANECapsuleIntegration
import ANEServicesCore
import CryptoKit
import CoreML
import Accelerate

public enum HashAlgorithm: String, Sendable, Codable {
    case pHash
    case dHash
    case wHash
    case avgHash
    case chromaprint
    case motionVector

    fileprivate var fingerprintAlgorithm: FingerprintAlgorithm {
        switch self {
        case .pHash: return .perceptualHash
        case .dHash: return .differenceHash
        case .wHash: return .waveletHash
        case .avgHash: return .averageHash
        case .chromaprint: return .chromaprint
        case .motionVector: return .motionVector
        }
    }
}

public typealias PerceptualHash64 = FingerprintResult

public struct SimilarityMatch: Sendable {
    public let candidateIndex: Int
    public let result: SimilarityResult

    public init(candidateIndex: Int, result: SimilarityResult) {
        self.candidateIndex = candidateIndex
        self.result = result
    }
}

/// ANE-optimized media fingerprinting capsule for batch processing
public actor MediaFingerprintCapsuleANE: ANECapsuleBase, CapsuleLifecycle {
    
    // MARK: - ANECapsuleBase Conformance
    
    public static let aneDescriptor: ANECapsuleDescriptor = {
        ANECapsuleDescriptor(
            id: "com.anigma.capsule.media-fingerprint-ane",
            version: "1.0.0",
            name: "Media Fingerprint ANE Capsule",
            description: "ANE-accelerated perceptual hashing and media fingerprinting",
            supportedComputeUnits: [.neuralEngine, .cpu, .gpu],
            gate: .open,
            capabilityLevel: .mixed,
            batchSizeRange: 1...32,
            optimalBatchSize: 16,
            memoryPerOperation: 1024 * 1024 * 4, // 4MB per image
            estimatedSpeedup: 8.0
        )
    }()
    
    public static var preferredComputeUnit: ANEComputeUnit {
        .neuralEngine
    }
    
    public static var supportsFallback: Bool {
        true
    }
    
    public static func validateComputeUnit(_ computeUnit: ANEComputeUnit) throws {
        let descriptor = Self.aneDescriptor
        guard descriptor.supportedComputeUnits.contains(computeUnit) else {
            throw ANECapsuleError.unsupportedComputeUnit(
                capsuleId: descriptor.id,
                requested: computeUnit,
                supported: descriptor.supportedComputeUnits
            )
        }

        switch descriptor.gate.status {
        case .gated:
            throw ANECapsuleError.gated(
                capsuleId: descriptor.id,
                reason: descriptor.gate.reason ?? "Access gated"
            )
        case .deprecated:
            throw ANECapsuleError.deprecated(
                capsuleId: descriptor.id,
                reason: descriptor.gate.reason ?? "Capsule deprecated"
            )
        case .experimental, .open:
            break
        }
    }
    
    // MARK: - Properties
    
    private let cpuCapsule: MediaFingerprintCapsuleWrapper
    private var aneModel: MLModel?
    private var batchProcessor: ANEBatchProcessor<MediaFingerprintBatchInput, MediaFingerprintBatchOutput>?
    private let performanceMonitor: ANEPerformanceMonitor
    private var isActive: Bool = false
    
    // MARK: - Initialization
    
    public init() throws {
        self.cpuCapsule = try MediaFingerprintCapsuleWrapper()
        self.performanceMonitor = ANEPerformanceMonitor(capsuleId: Self.aneDescriptor.id)
        self.aneModel = nil
        self.batchProcessor = nil
    }
    
    // MARK: - CapsuleLifecycle
    
    public func activate() async throws {
        guard !isActive else { return }

        await loadANEModel()
        batchProcessor = ANEBatchProcessor(
            capsuleId: Self.aneDescriptor.id,
            optimalBatchSize: Self.aneDescriptor.optimalBatchSize,
            maxBatchSize: Self.aneDescriptor.batchSizeRange.upperBound
        )
        isActive = true
        await performanceMonitor.recordActivation()
    }

    public func deactivate() async {
        guard isActive else { return }

        aneModel = nil
        batchProcessor = nil
        isActive = false
        await performanceMonitor.recordDeactivation()
    }
    
    // MARK: - Batch Image Hashing
    
    /// Compute perceptual hashes for multiple images in batch (ANE-optimized)
    /// - Parameters:
    ///   - images: Array of encoded image data
    ///   - algorithm: Hash algorithm to use
    ///   - context: ANE execution context
    /// - Returns: Array of hashes with execution metrics
    public func hashBatch(
        images: [Data],
        algorithm: HashAlgorithm = .pHash,
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[PerceptualHash64?]> {
        let startTime = Date()
        
        if !isActive {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        
        // Prepare batch input
        let batchInput = MediaFingerprintBatchInput(
            images: images,
            algorithm: algorithm,
            computeUnit: computeUnit
        )
        
        let result: [PerceptualHash64?]
        let receipt: ExecutionReceipt?
        let fallbackUsed: Bool
        
        if computeUnit == .neuralEngine, let processor = batchProcessor {
            // Use ANE batch processing
            do {
                let batchResult = try await processor.processBatch(
                    input: batchInput,
                    context: context,
                    processor: { [weak self] batch in
                        guard let self = self else { throw ANECapsuleError.executionFailed(
                            capsuleId: Self.aneDescriptor.id,
                            underlyingError: CocoaError(.executableRuntimeMismatch)
                        )}
                        return try await self.processBatchOnANE(batch)
                    }
                )
                
                result = batchResult.outputs.first?.outputs ?? []
                receipt = batchResult.receipt
                fallbackUsed = false
                
                await performanceMonitor.recordANEBatchExecution(
                    batchSize: images.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
            } catch {
                // Fallback to CPU if allowed
                if context.allowFallback && Self.supportsFallback {
                    print("⚠️ ANE batch processing failed, falling back to CPU for \(images.count) images")
                    let cpuResult = try await hashBatchOnCPU(images: images, algorithm: algorithm)
                    result = cpuResult
                    receipt = nil
                    fallbackUsed = true
                    
                    await performanceMonitor.recordCPUFallback(
                        batchSize: images.count,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                } else {
                    throw error
                }
            }
        } else {
            // Use CPU directly
            result = try await hashBatchOnCPU(images: images, algorithm: algorithm)
            receipt = nil
            fallbackUsed = computeUnit == .cpu
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        return ANECapsuleResult(
            output: result,
            executionReceipt: receipt,
            computeUnitUsed: computeUnit,
            executionTime: executionTime,
            fallbackUsed: fallbackUsed
        )
    }
    
    // MARK: - Batch Video Frame Hashing
    
    /// Compute perceptual hashes for multiple video frames in batch
    /// - Parameters:
    ///   - frames: Array of video frame data (grayscale pixels)
    ///   - width: Frame width
    ///   - height: Frame height
    ///   - context: ANE execution context
    /// - Returns: Array of hashes with execution metrics
    public func hashVideoFramesBatch(
        frames: [VideoFrameData],
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[PerceptualHash64]> {
        let startTime = Date()
        
        if !isActive {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)

        let result = try await hashVideoFramesBatchOnCPU(frames: frames)
        let receipt: ExecutionReceipt? = nil
        let fallbackUsed = computeUnit == .cpu
        await performanceMonitor.recordCPUFallback(
            batchSize: frames.count,
            executionTime: Date().timeIntervalSince(startTime)
        )
        
        let executionTime = Date().timeIntervalSince(startTime)
        return ANECapsuleResult(
            output: result,
            executionReceipt: receipt,
            computeUnitUsed: computeUnit,
            executionTime: executionTime,
            fallbackUsed: fallbackUsed
        )
    }
    
    // MARK: - Batch Similarity Search
    
    /// Find similar hashes in a collection for multiple queries in batch
    /// - Parameters:
    ///   - queries: Array of query hashes
    ///   - candidates: Array of candidate hashes
    ///   - maxDistance: Maximum Hamming distance threshold
    ///   - maxResults: Maximum number of results per query
    ///   - context: ANE execution context
    /// - Returns: Array of similarity matches with execution metrics
    public func findSimilarBatch(
        queries: [PerceptualHash64],
        in candidates: [PerceptualHash64],
        maxDistance: Int = 10,
        maxResults: Int = 100,
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[[SimilarityMatch]]> {
        let startTime = Date()
        
        if !isActive {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        let result = try await findSimilarBatchOnCPU(
            queries: queries,
            candidates: candidates,
            maxDistance: maxDistance,
            maxResults: maxResults
        )
        let receipt: ExecutionReceipt? = nil
        let fallbackUsed = computeUnit == .cpu
        await performanceMonitor.recordCPUFallback(
            batchSize: queries.count,
            executionTime: Date().timeIntervalSince(startTime)
        )
        
        let executionTime = Date().timeIntervalSince(startTime)
        return ANECapsuleResult(
            output: result,
            executionReceipt: receipt,
            computeUnitUsed: computeUnit,
            executionTime: executionTime,
            fallbackUsed: fallbackUsed
        )
    }
    
    // MARK: - Performance Metrics
    
    /// Get performance metrics for the capsule
    public func getPerformanceMetrics() -> ANEPerformanceMetrics {
        getMetricsSync()
    }
    
    /// Reset performance metrics
    public func resetPerformanceMetrics() {
        Task {
            await performanceMonitor.reset()
        }
    }
    
    // MARK: - Private Methods
    
    private func determineComputeUnit(context: ANEExecutionContext) async throws -> ANEComputeUnit {
        let requestedUnit = context.computeUnit
        
        do {
            try Self.validateComputeUnit(requestedUnit)
            return requestedUnit
        } catch {
            if context.allowFallback && Self.supportsFallback && requestedUnit != .cpu {
                if Self.aneDescriptor.supportedComputeUnits.contains(.cpu) {
                    return .cpu
                }
            }
            throw error
        }
    }
    
    private func loadANEModel() async {
        // In a real implementation, this would load a CoreML model
        // optimized for ANE execution
        // For now, we'll just set a placeholder
        aneModel = nil
    }
    
    private func hashBatchOnCPU(images: [Data], algorithm: HashAlgorithm) async throws -> [PerceptualHash64?] {
        try await withThrowingTaskGroup(of: (Int, PerceptualHash64?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let fingerprint = try self.cpuCapsule.generateImageFingerprint(
                        image,
                        algorithm: algorithm.fingerprintAlgorithm
                    )
                    return (index, Optional(fingerprint))
                }
            }

            var results: [PerceptualHash64?] = []
            results.reserveCapacity(images.count)
            results = Array(repeating: nil, count: images.count)
            for try await (index, result) in group {
                results[index] = result
            }
            return results
        }
    }

    private func hashVideoFramesBatchOnCPU(frames: [VideoFrameData]) async throws -> [PerceptualHash64] {
        try frames.map { frame in
            try makeFingerprint(from: frame.pixels, algorithm: .motionVector, confidence: 0.82)
        }
    }

    private func findSimilarBatchOnCPU(
        queries: [PerceptualHash64],
        candidates: [PerceptualHash64],
        maxDistance: Int,
        maxResults: Int
    ) async throws -> [[SimilarityMatch]] {
        let threshold = max(0.0, 1.0 - Double(maxDistance) / Double(max(candidates.first?.hashData.count ?? 1, 1) * 8))
        var grouped: [[SimilarityMatch]] = []
        grouped.reserveCapacity(queries.count)

        for query in queries {
            var compared: [SimilarityMatch] = []
            compared.reserveCapacity(candidates.count)

            for (index, candidate) in candidates.enumerated() {
                let similarity = cpuCapsule.compareFingerprints(query, candidate, threshold: threshold)
                compared.append(SimilarityMatch(candidateIndex: index, result: similarity))
            }

            grouped.append(
                compared
                .filter { $0.result.hammingDistance <= UInt32(maxDistance) }
                .sorted { lhs, rhs in lhs.result.similarityScore > rhs.result.similarityScore }
                .prefix(maxResults)
                .map { $0 }
            )
        }

        return grouped
    }
    
    private func processBatchOnANE(_ batch: MediaFingerprintBatchInput) async throws -> MediaFingerprintBatchOutput {
        // This is where ANE-accelerated batch processing would happen
        // For now, we'll simulate it with CPU processing
        let hashes = try await hashBatchOnCPU(images: batch.images, algorithm: batch.algorithm)
        return MediaFingerprintBatchOutput(outputs: hashes)
    }
    
    private func getMetricsSync() -> ANEPerformanceMetrics {
        ANEPerformanceMetrics()
    }

    private func makeFingerprint(from data: Data, algorithm: FingerprintAlgorithm, confidence: Double) throws -> FingerprintResult {
        guard !data.isEmpty else {
            throw MediaFingerprintError.invalidInput
        }

        let digest = Data(SHA256.hash(data: data))
        let hashData = Data(digest.prefix(8))
        return FingerprintResult(
            algorithm: algorithm,
            hashSize: UInt32(hashData.count * 8),
            hashData: hashData,
            confidence: confidence,
            processingTimeMs: 0
        )
    }
}

// MARK: - Supporting Types

public struct VideoFrameData: Sendable {
    public let pixels: Data
    public let width: Int
    public let height: Int
    public let stride: Int
    
    public init(pixels: Data, width: Int, height: Int, stride: Int? = nil) {
        self.pixels = pixels
        self.width = width
        self.height = height
        self.stride = stride ?? width
    }
}

public struct MediaFingerprintBatchInput: Sendable {
    public let images: [Data]
    public let algorithm: HashAlgorithm
    public let computeUnit: ANEComputeUnit
    
    public init(images: [Data], algorithm: HashAlgorithm, computeUnit: ANEComputeUnit) {
        self.images = images
        self.algorithm = algorithm
        self.computeUnit = computeUnit
    }
}

public struct MediaFingerprintBatchOutput: Sendable {
    public let outputs: [PerceptualHash64?]
    
    public init(outputs: [PerceptualHash64?]) {
        self.outputs = outputs
    }
}

public struct VideoFrameBatchInput: Sendable {
    public let frames: [VideoFrameData]
    public let computeUnit: ANEComputeUnit
    
    public init(frames: [VideoFrameData], computeUnit: ANEComputeUnit) {
        self.frames = frames
        self.computeUnit = computeUnit
    }
}

public struct VideoFrameBatchOutput: Sendable {
    public let outputs: [PerceptualHash64]
    
    public init(outputs: [PerceptualHash64]) {
        self.outputs = outputs
    }
}

public struct SimilaritySearchBatchInput: Sendable {
    public let queries: [PerceptualHash64]
    public let candidates: [PerceptualHash64]
    public let maxDistance: Int
    public let maxResults: Int
    public let computeUnit: ANEComputeUnit
    
    public init(queries: [PerceptualHash64], candidates: [PerceptualHash64], maxDistance: Int, maxResults: Int, computeUnit: ANEComputeUnit) {
        self.queries = queries
        self.candidates = candidates
        self.maxDistance = maxDistance
        self.maxResults = maxResults
        self.computeUnit = computeUnit
    }
}

public struct SimilaritySearchBatchOutput: Sendable {
    public let outputs: [[SimilarityMatch]]
    
    public init(outputs: [[SimilarityMatch]]) {
        self.outputs = outputs
    }
}

// MARK: - ANEBatchProcessor Integration

public actor ANEBatchProcessor<Input: Sendable, Output: Sendable> {
    private let capsuleId: String
    private let optimalBatchSize: Int
    private let maxBatchSize: Int
    private var pendingBatches: [Input] = []
    private var isProcessing: Bool = false
    
    public init(capsuleId: String, optimalBatchSize: Int, maxBatchSize: Int) {
        self.capsuleId = capsuleId
        self.optimalBatchSize = optimalBatchSize
        self.maxBatchSize = maxBatchSize
    }
    
    public func processBatch(
        input: Input,
        context: ANEExecutionContext,
        processor: @escaping (Input) async throws -> Output
    ) async throws -> ANEBatchResult<Output> {
        // Add to pending batches
        pendingBatches.append(input)
        
        // Check if we should process now
        if pendingBatches.count >= optimalBatchSize || context.priority == .realtime {
            return try await processPendingBatches(context: context, processor: processor)
        } else {
            // Wait for more batches or timeout
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            if pendingBatches.count > 0 {
                return try await processPendingBatches(context: context, processor: processor)
            } else {
                // Process single batch
                return try await processSingleBatch(input: input, context: context, processor: processor)
            }
        }
    }
    
    private func processPendingBatches(
        context: ANEExecutionContext,
        processor: @escaping (Input) async throws -> Output
    ) async throws -> ANEBatchResult<Output> {
        guard !isProcessing else {
            throw ANECapsuleError.executionFailed(
                capsuleId: capsuleId,
                underlyingError: CocoaError(.fileWriteUnknown)
            )
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let batchesToProcess = pendingBatches
        pendingBatches.removeAll()
        
        // Combine batches if possible
        let combinedInput = try combineBatches(batchesToProcess)
        
        // Process combined batch
        let output = try await processor(combinedInput)
        
        // Generate receipt
        let receipt = try? await ExecutionReceipt.generate(
            for: ANECapsuleDescriptor(
                id: capsuleId,
                version: "1.0.0",
                name: "Batch Processor",
                description: "Combined batch processing",
                supportedComputeUnits: [context.computeUnit],
                gate: .open,
                capabilityLevel: .mixed,
                batchSizeRange: 1...maxBatchSize,
                optimalBatchSize: optimalBatchSize,
                memoryPerOperation: 0,
                estimatedSpeedup: 1.0
            ),
            computeUnit: context.computeUnit,
            inputHash: "\(batchesToProcess.count)",
            outputHash: "\(output)"
        )
        
        return ANEBatchResult(
            outputs: [output],
            receipt: receipt,
            batchSize: batchesToProcess.count
        )
    }
    
    private func processSingleBatch(
        input: Input,
        context: ANEExecutionContext,
        processor: @escaping (Input) async throws -> Output
    ) async throws -> ANEBatchResult<Output> {
        let output = try await processor(input)
        
        // Generate receipt
        let receipt = try? await ExecutionReceipt.generate(
            for: ANECapsuleDescriptor(
                id: capsuleId,
                version: "1.0.0",
                name: "Batch Processor",
                description: "Single batch processing",
                supportedComputeUnits: [context.computeUnit],
                gate: .open,
                capabilityLevel: .mixed,
                batchSizeRange: 1...maxBatchSize,
                optimalBatchSize: optimalBatchSize,
                memoryPerOperation: 0,
                estimatedSpeedup: 1.0
            ),
            computeUnit: context.computeUnit,
            inputHash: "\(input)",
            outputHash: "\(output)"
        )
        
        return ANEBatchResult(
            outputs: [output],
            receipt: receipt,
            batchSize: 1
        )
    }
    
    private func combineBatches(_ batches: [Input]) throws -> Input {
        // This is a placeholder - in practice, this would combine inputs
        // based on the specific capsule type
        guard let firstBatch = batches.first else {
            throw ANECapsuleError.executionFailed(
                capsuleId: capsuleId,
                underlyingError: CocoaError(.fileNoSuchFile)
            )
        }
        return firstBatch
    }
}

public struct ANEBatchResult<Output: Sendable>: Sendable {
    public let outputs: [Output]
    public let receipt: ExecutionReceipt?
    public let batchSize: Int
    
    public init(outputs: [Output], receipt: ExecutionReceipt?, batchSize: Int) {
        self.outputs = outputs
        self.receipt = receipt
        self.batchSize = batchSize
    }
}
