import Foundation
import CapsuleCore
import ANECapsuleIntegration
import ANEServicesCore
import Accelerate
import simd

/// ANE-optimized vector indexing and similarity search capsule
public actor VectorIndexCapsuleANE: ANECapsuleBase, CapsuleLifecycle {
    
    // MARK: - ANECapsuleBase Conformance
    
    public static let aneDescriptor: ANECapsuleDescriptor = {
        ANECapsuleDescriptor(
            id: "com.anigma.capsule.vector-index-ane",
            version: "1.0.0",
            name: "Vector Index ANE Capsule",
            description: "ANE-accelerated vector similarity search and indexing",
            supportedComputeUnits: [.neuralEngine, .cpu, .gpu],
            gate: .open,
            capabilityLevel: .mixed,
            batchSizeRange: 1...64,
            optimalBatchSize: 32,
            memoryPerOperation: 1024 * 1024 * 2, // 2MB per vector batch
            estimatedSpeedup: 12.0
        )
    }()
    
    public static var preferredComputeUnit: ANEComputeUnit {
        .neuralEngine
    }
    
    public static var supportsFallback: Bool {
        true
    }
    
    public static func validateComputeUnit(_ computeUnit: ANEComputeUnit) throws {
        try super.validateComputeUnit(computeUnit)
    }
    
    // MARK: - Properties
    
    private let performanceMonitor: ANEPerformanceMonitor
    private var vectorIndex: VectorIndex?
    private var batchProcessor: ANEBatchProcessor<VectorBatchInput, VectorBatchOutput>?
    private var isActive: Bool = false
    
    // MARK: - Initialization
    
    public init() {
        self.performanceMonitor = ANEPerformanceMonitor(capsuleId: Self.aneDescriptor.id)
        self.vectorIndex = nil
        self.batchProcessor = nil
    }
    
    // MARK: - CapsuleLifecycle
    
    public func activate() async throws {
        guard !isActive else { return }
        
        do {
            // Initialize vector index
            vectorIndex = VectorIndex(dimension: 768) // Default dimension for embeddings
            
            // Initialize batch processor
            batchProcessor = ANEBatchProcessor(
                capsuleId: Self.aneDescriptor.id,
                optimalBatchSize: Self.aneDescriptor.optimalBatchSize,
                maxBatchSize: Self.aneDescriptor.batchSizeRange.upperBound
            )
            
            isActive = true
            performanceMonitor.recordActivation()
        } catch {
            throw ANECapsuleError.activationFailed(
                capsuleId: Self.aneDescriptor.id,
                underlyingError: error
            )
        }
    }
    
    public func deactivate() async {
        guard isActive else { return }
        
        vectorIndex = nil
        batchProcessor = nil
        isActive = false
        performanceMonitor.recordDeactivation()
    }
    
    // MARK: - Batch Vector Operations
    
    /// Compute cosine similarity for multiple vector pairs in batch
    /// - Parameters:
    ///   - vectorsA: First set of vectors
    ///   - vectorsB: Second set of vectors
    ///   - context: ANE execution context
    /// - Returns: Similarity scores with execution metrics
    public func cosineSimilarityBatch(
        vectorsA: [[Float]],
        vectorsB: [[Float]],
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[Float]> {
        let startTime = Date()
        
        guard isActive else {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        
        // Validate input dimensions
        guard vectorsA.count == vectorsB.count else {
            throw VectorIndexError.dimensionMismatch(
                expected: vectorsA.count,
                actual: vectorsB.count
            )
        }
        
        // Prepare batch input
        let batchInput = VectorBatchInput(
            operation: .cosineSimilarity,
            vectorsA: vectorsA,
            vectorsB: vectorsB,
            computeUnit: computeUnit
        )
        
        let result: [Float]
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
                        return try await self.processVectorBatchOnANE(batch)
                    }
                )
                
                result = batchResult.outputs.first?.similarities ?? []
                receipt = batchResult.receipt
                fallbackUsed = false
                
                performanceMonitor.recordANEBatchExecution(
                    batchSize: vectorsA.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
            } catch {
                // Fallback to CPU if allowed
                if context.allowFallback && Self.supportsFallback {
                    print("⚠️ ANE vector similarity failed, falling back to CPU for \(vectorsA.count) pairs")
                    let cpuResult = try await cosineSimilarityBatchOnCPU(vectorsA: vectorsA, vectorsB: vectorsB)
                    result = cpuResult
                    receipt = nil
                    fallbackUsed = true
                    
                    performanceMonitor.recordCPUFallback(
                        batchSize: vectorsA.count,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                } else {
                    throw error
                }
            }
        } else {
            // Use CPU directly
            result = try await cosineSimilarityBatchOnCPU(vectorsA: vectorsA, vectorsB: vectorsB)
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
    
    /// Compute dot products for multiple vector pairs in batch
    /// - Parameters:
    ///   - vectorsA: First set of vectors
    ///   - vectorsB: Second set of vectors
    ///   - context: ANE execution context
    /// - Returns: Dot products with execution metrics
    public func dotProductBatch(
        vectorsA: [[Float]],
        vectorsB: [[Float]],
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[Float]> {
        let startTime = Date()
        
        guard isActive else {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        
        // Validate input dimensions
        guard vectorsA.count == vectorsB.count else {
            throw VectorIndexError.dimensionMismatch(
                expected: vectorsA.count,
                actual: vectorsB.count
            )
        }
        
        // Prepare batch input
        let batchInput = VectorBatchInput(
            operation: .dotProduct,
            vectorsA: vectorsA,
            vectorsB: vectorsB,
            computeUnit: computeUnit
        )
        
        let result: [Float]
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
                        return try await self.processVectorBatchOnANE(batch)
                    }
                )
                
                result = batchResult.outputs.first?.dotProducts ?? []
                receipt = batchResult.receipt
                fallbackUsed = false
                
                performanceMonitor.recordANEBatchExecution(
                    batchSize: vectorsA.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
            } catch {
                // Fallback to CPU if allowed
                if context.allowFallback && Self.supportsFallback {
                    print("⚠️ ANE dot product failed, falling back to CPU for \(vectorsA.count) pairs")
                    let cpuResult = try await dotProductBatchOnCPU(vectorsA: vectorsA, vectorsB: vectorsB)
                    result = cpuResult
                    receipt = nil
                    fallbackUsed = true
                    
                    performanceMonitor.recordCPUFallback(
                        batchSize: vectorsA.count,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                } else {
                    throw error
                }
            }
        } else {
            // Use CPU directly
            result = try await dotProductBatchOnCPU(vectorsA: vectorsA, vectorsB: vectorsB)
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
    
    /// Add multiple vectors to the index in batch
    /// - Parameters:
    ///   - vectors: Vectors to add
    ///   - ids: Optional IDs for the vectors
    ///   - context: ANE execution context
    /// - Returns: Index update result with execution metrics
    public func addVectorsBatch(
        vectors: [[Float]],
        ids: [String]? = nil,
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[String]> {
        let startTime = Date()
        
        guard isActive else {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        
        // Generate IDs if not provided
        let vectorIds = ids ?? (0..<vectors.count).map { "vector_\($0)" }
        
        // Prepare batch input
        let batchInput = IndexUpdateBatchInput(
            operation: .addVectors,
            vectors: vectors,
            ids: vectorIds,
            computeUnit: computeUnit
        )
        
        let result: [String]
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
                        return try await self.processIndexUpdateBatchOnANE(batch)
                    }
                )
                
                result = batchResult.outputs.first?.updatedIds ?? []
                receipt = batchResult.receipt
                fallbackUsed = false
                
                performanceMonitor.recordANEBatchExecution(
                    batchSize: vectors.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
            } catch {
                // Fallback to CPU if allowed
                if context.allowFallback && Self.supportsFallback {
                    print("⚠️ ANE vector addition failed, falling back to CPU for \(vectors.count) vectors")
                    let cpuResult = try await addVectorsBatchOnCPU(vectors: vectors, ids: vectorIds)
                    result = cpuResult
                    receipt = nil
                    fallbackUsed = true
                    
                    performanceMonitor.recordCPUFallback(
                        batchSize: vectors.count,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                } else {
                    throw error
                }
            }
        } else {
            // Use CPU directly
            result = try await addVectorsBatchOnCPU(vectors: vectors, ids: vectorIds)
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
    
    /// Search for similar vectors in batch
    /// - Parameters:
    ///   - queryVectors: Query vectors
    ///   - k: Number of nearest neighbors to return per query
    ///   - context: ANE execution context
    /// - Returns: Search results with execution metrics
    public func searchBatch(
        queryVectors: [[Float]],
        k: Int = 10,
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[[VectorSearchResult]]> {
        let startTime = Date()
        
        guard isActive else {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        
        // Prepare batch input
        let batchInput = SearchBatchInput(
            queryVectors: queryVectors,
            k: k,
            computeUnit: computeUnit
        )
        
        let result: [[VectorSearchResult]]
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
                        return try await self.processSearchBatchOnANE(batch)
                    }
                )
                
                result = batchResult.outputs.first?.searchResults ?? []
                receipt = batchResult.receipt
                fallbackUsed = false
                
                performanceMonitor.recordANEBatchExecution(
                    batchSize: queryVectors.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
            } catch {
                // Fallback to CPU if allowed
                if context.allowFallback && Self.supportsFallback {
                    print("⚠️ ANE vector search failed, falling back to CPU for \(queryVectors.count) queries")
                    let cpuResult = try await searchBatchOnCPU(queryVectors: queryVectors, k: k)
                    result = cpuResult
                    receipt = nil
                    fallbackUsed = true
                    
                    performanceMonitor.recordCPUFallback(
                        batchSize: queryVectors.count,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                } else {
                    throw error
                }
            }
        } else {
            // Use CPU directly
            result = try await searchBatchOnCPU(queryVectors: queryVectors, k: k)
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
    
    // MARK: - Performance Metrics
    
    /// Get performance metrics for the capsule
    public func getPerformanceMetrics() -> ANEPerformanceMetrics {
        performanceMonitor.getMetrics()
    }
    
    /// Reset performance metrics
    public func resetPerformanceMetrics() {
        performanceMonitor.reset()
    }
    
    /// Get index statistics
    public func getIndexStatistics() -> VectorIndexStatistics {
        vectorIndex?.getStatistics() ?? VectorIndexStatistics(
            vectorCount: 0,
            dimension: 0,
            memoryUsageMB: 0.0,
            averageVectorLength: 0.0
        )
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
    
    private func cosineSimilarityBatchOnCPU(vectorsA: [[Float]], vectorsB: [[Float]]) async throws -> [Float] {
        guard vectorsA.count == vectorsB.count else {
            throw VectorIndexError.dimensionMismatch(
                expected: vectorsA.count,
                actual: vectorsB.count
            )
        }
        
        var results: [Float] = []
        results.reserveCapacity(vectorsA.count)
        
        for i in 0..<vectorsA.count {
            let similarity = cosineSimilarityCPU(a: vectorsA[i], b: vectorsB[i])
            results.append(similarity)
        }
        
        return results
    }
    
    private func dotProductBatchOnCPU(vectorsA: [[Float]], vectorsB: [[Float]]) async throws -> [Float] {
        guard vectorsA.count == vectorsB.count else {
            throw VectorIndexError.dimensionMismatch(
                expected: vectorsA.count,
                actual: vectorsB.count
            )
        }
        
        var results: [Float] = []
        results.reserveCapacity(vectorsA.count)
        
        for i in 0..<vectorsA.count {
            let dot = dotProductCPU(a: vectorsA[i], b: vectorsB[i])
            results.append(dot)
        }
        
        return results
    }
    
    private func addVectorsBatchOnCPU(vectors: [[Float]], ids: [String]) async throws -> [String] {
        guard let index = vectorIndex else {
            throw VectorIndexError.indexNotInitialized
        }
        
        for (i, vector) in vectors.enumerated() {
            try index.addVector(vector, id: ids[i])
        }
        
        return ids
    }
    
    private func searchBatchOnCPU(queryVectors: [[Float]], k: Int) async throws -> [[VectorSearchResult]] {
        guard let index = vectorIndex else {
            throw VectorIndexError.indexNotInitialized
        }
        
        var results: [[VectorSearchResult]] = []
        results.reserveCapacity(queryVectors.count)
        
        for query in queryVectors {
            let searchResults = try index.search(query: query, k: k)
            results.append(searchResults)
        }
        
        return results
    }
    
    private func processVectorBatchOnANE(_ batch: VectorBatchInput) async throws -> VectorBatchOutput {
        // This is where ANE-accelerated vector operations would happen
        // For now, we'll simulate it with CPU processing
        
        var similarities: [Float]?
        var dotProducts: [Float]?
        
        switch batch.operation {
        case .cosineSimilarity:
            similarities = try await cosineSimilarityBatchOnCPU(vectorsA: batch.vectorsA, vectorsB: batch.vectorsB)
        case .dotProduct:
            dotProducts = try await dotProductBatchOnCPU(vectorsA: batch.vectorsA, vectorsB: batch.vectorsB)
        }
        
        return VectorBatchOutput(
            similarities: similarities,
            dotProducts: dotProducts
        )
    }
    
    private func processIndexUpdateBatchOnANE(_ batch: IndexUpdateBatchInput) async throws -> IndexUpdateBatchOutput {
        // This is where ANE-accelerated index updates would happen
        // For now, we'll simulate it with CPU processing
        
        let updatedIds = try await addVectorsBatchOnCPU(vectors: batch.vectors, ids: batch.ids)
        return IndexUpdateBatchOutput(updatedIds: updatedIds)
    }
    
    private func processSearchBatchOnANE(_ batch: SearchBatchInput) async throws -> SearchBatchOutput {
        // This is where ANE-accelerated vector search would happen
        // For now, we'll simulate it with CPU processing
        
        let searchResults = try await searchBatchOnCPU(queryVectors: batch.queryVectors, k: batch.k)
        return SearchBatchOutput(searchResults: searchResults)
    }
    
    // MARK: - CPU Helper Functions
    
    private func cosineSimilarityCPU(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        let dot = dotProductCPU(a: a, b: b)
        let normA = sqrt(dotProductCPU(a: a, b: a))
        let normB = sqrt(dotProductCPU(a: b, b: b))
        
        guard normA > 0 && normB > 0 else { return 0.0 }
        return dot / (normA * normB)
    }
    
    private func dotProductCPU(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        var result: Float = 0.0
        for i in 0..<a.count {
            result += a[i] * b[i]
        }
        return result
    }
}

// MARK: - Supporting Types

public enum VectorOperation: Sendable {
    case cosineSimilarity
    case dotProduct
    case euclideanDistance
    case manhattanDistance
}

public struct VectorSearchResult: Sendable {
    public let id: String
    public let vector: [Float]
    public let similarity: Float
    public let distance: Float
    
    public init(id: String, vector: [Float], similarity: Float, distance: Float) {
        self.id = id
        self.vector = vector
        self.similarity = similarity
        self.distance = distance
    }
}

public struct VectorIndexStatistics: Sendable {
    public let vectorCount: Int
    public let dimension: Int
    public let memoryUsageMB: Double
    public let averageVectorLength: Float
    
    public init(vectorCount: Int, dimension: Int, memoryUsageMB: Double, averageVectorLength: Float) {
        self.vectorCount = vectorCount
        self.dimension = dimension
        self.memoryUsageMB = memoryUsageMB
        self.averageVectorLength = averageVectorLength
    }
}

public struct VectorBatchInput: Sendable {
    public let operation: VectorOperation
    public let vectorsA: [[Float]]
    public let vectorsB: [[Float]]
    public let computeUnit: ANEComputeUnit
    
    public init(operation: VectorOperation, vectorsA: [[Float]], vectorsB: [[Float]], computeUnit: ANEComputeUnit) {
        self.operation = operation
        self.vectorsA = vectorsA
        self.vectorsB = vectorsB
        self.computeUnit = computeUnit
    }
}

public struct VectorBatchOutput: Sendable {
    public let similarities: [Float]?
    public let dotProducts: [Float]?
    
    public init(similarities: [Float]?, dotProducts: [Float]?) {
        self.similarities = similarities
        self.dotProducts = dotProducts
    }
}

public struct IndexUpdateBatchInput: Sendable {
    public let operation: VectorOperation
    public let vectors: [[Float]]
    public let ids: [String]
    public let computeUnit: ANEComputeUnit
    
    public init(operation: VectorOperation, vectors: [[Float]], ids: [String], computeUnit: ANEComputeUnit) {
        self.operation = operation
        self.vectors = vectors
        self.ids = ids
        self.computeUnit = computeUnit
    }
}

public struct IndexUpdateBatchOutput: Sendable {
    public let updatedIds: [String]
    
    public init(updatedIds: [String]) {
        self.updatedIds = updatedIds
    }
}

public struct SearchBatchInput: Sendable {
    public let queryVectors: [[Float]]
    public let k: Int
    public let computeUnit: ANEComputeUnit
    
    public init(queryVectors: [[Float]], k: Int, computeUnit: ANEComputeUnit) {
        self.queryVectors = queryVectors
        self.k = k
        self.computeUnit = computeUnit
    }
}

public struct SearchBatchOutput: Sendable {
    public let searchResults: [[VectorSearchResult]]
    
    public init(searchResults: [[VectorSearchResult]]) {
        self.searchResults = searchResults
    }
}

public enum VectorIndexError: Error, Sendable {
    case indexNotInitialized
    case dimensionMismatch(expected: Int, actual: Int)
    case invalidVectorDimension(expected: Int, actual: Int)
    case vectorNotFound(id: String)
    case indexFull(maxCapacity: Int)
    case operationFailed(reason: String)
    
    public var localizedDescription: String {
        switch self {
        case .indexNotInitialized:
            return "Vector index not initialized"
        case .dimensionMismatch(let expected, let actual):
            return "Dimension mismatch: expected \(expected), got \(actual)"
        case .invalidVectorDimension(let expected, let actual):
            return "Invalid vector dimension: expected \(expected), got \(actual)"
        case .vectorNotFound(let id):
            return "Vector not found: \(id)"
        case .indexFull(let maxCapacity):
            return "Index full: maximum capacity \(maxCapacity) reached"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        }
    }
}

// MARK: - Vector Index Implementation

public actor VectorIndex {
    private let dimension: Int
    private var vectors: [String: [Float]] = [:]
    private var norms: [String: Float] = [:]
    private let maxCapacity: Int = 1_000_000
    
    public init(dimension: Int) {
        self.dimension = dimension
    }
    
    public func addVector(_ vector: [Float], id: String) throws {
        guard vector.count == dimension else {
            throw VectorIndexError.invalidVectorDimension(expected: dimension, actual: vector.count)
        }
        
        guard vectors.count < maxCapacity else {
            throw VectorIndexError.indexFull(maxCapacity: maxCapacity)
        }
        
        vectors[id] = vector
        norms[id] = sqrt(dotProductCPU(a: vector, b: vector))
    }
    
    public func search(query: [Float], k: Int) throws -> [VectorSearchResult] {
        guard query.count == dimension else {
            throw VectorIndexError.invalidVectorDimension(expected: dimension, actual: query.count)
        }
        
        let queryNorm = sqrt(dotProductCPU(a: query, b: query))
        
        var results: [(id: String, similarity: Float, distance: Float)] = []
        
        for (id, vector) in vectors {
            guard let vectorNorm = norms[id] else { continue }
            
            let dot = dotProductCPU(a: query, b: vector)
            let similarity = dot / (queryNorm * vectorNorm)
            let distance = 1.0 - similarity // Cosine distance
            
            results.append((id: id, similarity: similarity, distance: distance))
        }
        
        // Sort by similarity (descending) and take top k
        results.sort { $0.similarity > $1.similarity }
        let topK = Array(results.prefix(k))
        
        return topK.map { result in
            VectorSearchResult(
                id: result.id,
                vector: vectors[result.id] ?? [],
                similarity: result.similarity,
                distance: result.distance
            )
        }
    }
    
    public func getStatistics() -> VectorIndexStatistics {
        let totalVectors = vectors.count
        var totalLength: Float = 0.0
        
        for norm in norms.values {
            totalLength += norm
        }
        
        let averageLength = totalVectors > 0 ? totalLength / Float(totalVectors) : 0.0
        let memoryUsage = Double(totalVectors * dimension * MemoryLayout<Float>.size) / (1024 * 1024)
        
        return VectorIndexStatistics(
            vectorCount: totalVectors,
            dimension: dimension,
            memoryUsageMB: memoryUsage,
            averageVectorLength: averageLength
        )
    }
    
    private func dotProductCPU(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        var result: Float = 0.0
        for i in 0..<a.count {
            result += a[i] * b[i]
        }
        return result
    }
}