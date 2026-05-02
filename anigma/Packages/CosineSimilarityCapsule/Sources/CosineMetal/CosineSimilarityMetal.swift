// ============================================================================
// Cosine Similarity Metal Implementation
// ============================================================================
// GPU-accelerated cosine similarity computation using Metal
// Falls back to CPU implementation when Metal is unavailable
// ============================================================================

import Metal
import Foundation

/// Metal-based cosine similarity computation
public class CosineSimilarityMetal {
    
    // Metal device and compute pipeline
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let computePipelineState: MTLComputePipelineState
    private let maxBufferSize: Int
    
    // Fallback to CPU implementation
    private let cpuFallback: CosineSimilarityNative
    
    public init?() {
        // Try to get Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        
        self.device = device
        self.cpuFallback = CosineSimilarityNative()
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue
        
        // Load Metal shader
        guard let computePipelineState = Self.createComputePipelineState(device: device) else {
            return nil
        }
        self.computePipelineState = computePipelineState
        
        // Set reasonable buffer size limit (e.g., 1MB)
        self.maxBufferSize = 1024 * 1024
    }
    
    private static func createComputePipelineState(device: MTLDevice) -> MTLComputePipelineState? {
        // Metal shader source for cosine similarity
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        kernel void compute_cosine_similarity(
            device const float* query [[buffer(0)]],
            device const float* candidates [[buffer(1)]],
            device float* results [[buffer(2)]],
            uint dimension [[buffer(3)]],
            uint num_candidates [[buffer(4)]],
            uint thread_index [[thread_position_in_grid]]
        ) {
            if (thread_index >= num_candidates) {
                return;
            }
            
            const uint candidate_offset = thread_index * dimension;
            float dot = 0.0;
            float norm_query = 0.0;
            float norm_candidate = 0.0;
            
            for (uint i = 0; i < dimension; i++) {
                float q = query[i];
                float c = candidates[candidate_offset + i];
                dot += q * c;
                norm_query += q * q;
                norm_candidate += c * c;
            }
            
            float magnitude = sqrt(norm_query) * sqrt(norm_candidate);
            if (magnitude > 0.0) {
                results[thread_index] = dot / magnitude;
            } else {
                results[thread_index] = 0.0;
            }
        }
        """
        
        // Create library from source
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            print("Failed to create Metal library: \(error)")
            return nil
        }
        
        // Create compute pipeline state
        guard let function = library.makeFunction(name: "compute_cosine_similarity") else {
            print("Failed to find compute function")
            return nil
        }
        
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create compute pipeline state: \(error)")
            return nil
        }
    }
    
    /// Performance metrics
    public struct PerformanceMetrics {
        public var gpuExecutionTime: TimeInterval = 0
        public var cpuFallbackCount: Int = 0
        public var bufferAllocationTime: TimeInterval = 0
        public var totalOperations: Int = 0
        public var gpuOperations: Int = 0
        public var cpuOperations: Int = 0
        
        public var gpuUtilizationRate: Double {
            guard totalOperations > 0 else { return 0 }
            return Double(gpuOperations) / Double(totalOperations)
        }
    }
    
    private var metrics = PerformanceMetrics()
    
    /// Compute cosine similarity between query and multiple candidates
    /// - Parameters:
    ///   - query: Query vector
    ///   - candidates: Array of candidate vectors
    ///   - dimension: Dimension of vectors
    ///   - useGPU: Force GPU computation (falls back to CPU if Metal unavailable)
    /// - Returns: Array of similarity scores
    public func computeCosineSimilarity(
        query: [Float],
        candidates: [[Float]],
        dimension: Int,
        useGPU: Bool = true
    ) -> [Float] {
        // Validate inputs
        guard !query.isEmpty, dimension > 0, !candidates.isEmpty else {
            return Array(repeating: 0.0, count: candidates.count)
        }
        
        metrics.totalOperations += candidates.count
        
        // Check if we should use GPU
        guard useGPU, 
              query.count == dimension, 
              candidates.allSatisfy({ $0.count == dimension }),
              candidates.count * dimension * MemoryLayout<Float>.stride <= maxBufferSize else {
            // Fall back to CPU implementation
            metrics.cpuFallbackCount += 1
            metrics.cpuOperations += candidates.count
            return cpuFallback.computeCosineSimilarityBatch(query: query, candidates: candidates, dimension: dimension)
        }
        
        metrics.gpuOperations += candidates.count
        return computeWithMetal(query: query, candidates: candidates, dimension: dimension)
    }
    
    /// Compute large batches by chunking into smaller batches
    /// - Parameters:
    ///   - query: Query vector
    ///   - candidates: Array of candidate vectors
    ///   - dimension: Dimension of vectors
    ///   - batchSize: Size of each batch (default: 1000)
    ///   - useGPU: Force GPU computation
    /// - Returns: Array of similarity scores
    public func computeLargeBatch(
        query: [Float],
        candidates: [[Float]],
        dimension: Int,
        batchSize: Int = 1000,
        useGPU: Bool = true
    ) -> [Float] {
        guard !candidates.isEmpty else { return [] }
        
        var allResults = [Float]()
        allResults.reserveCapacity(candidates.count)
        
        for batchStart in stride(from: 0, to: candidates.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, candidates.count)
            let batch = Array(candidates[batchStart..<batchEnd])
            let batchResults = computeCosineSimilarity(
                query: query, 
                candidates: batch, 
                dimension: dimension,
                useGPU: useGPU
            )
            allResults.append(contentsOf: batchResults)
        }
        
        return allResults
    }
    
    /// Get current performance metrics
    public func getPerformanceMetrics() -> PerformanceMetrics {
        return metrics
    }
    
    /// Reset performance metrics
    public func resetPerformanceMetrics() {
        metrics = PerformanceMetrics()
    }
    
    private func computeWithMetal(query: [Float], candidates: [[Float]], dimension: Int) -> [Float] {
        let numCandidates = candidates.count
        var results = [Float](repeating: 0.0, count: numCandidates)
        
        let startTime = DispatchTime.now()
        
        // Create Metal buffers
        let bufferAllocStart = DispatchTime.now()
        guard let queryBuffer = device.makeBuffer(bytes: query, length: query.count * MemoryLayout<Float>.stride),
              let candidatesBuffer = device.makeBuffer(bytes: candidates.flatMap { $0 }, 
                                                       length: candidates.count * dimension * MemoryLayout<Float>.stride),
              let resultsBuffer = device.makeBuffer(bytes: &results, 
                                                    length: results.count * MemoryLayout<Float>.stride, 
                                                    options: .storageModeShared) else {
            return cpuFallback.computeCosineSimilarityBatch(query: query, candidates: candidates, dimension: dimension)
        }
        let bufferAllocTime = DispatchTime.now().uptimeNanoseconds - bufferAllocStart.uptimeNanoseconds
        metrics.bufferAllocationTime += Double(bufferAllocTime) / 1_000_000_000.0 // Convert to seconds
        
        // Create dimension and count buffers
        var dimValue = UInt32(dimension)
        var countValue = UInt32(numCandidates)
        
        guard let dimensionBuffer = device.makeBuffer(bytes: &dimValue, length: MemoryLayout<UInt32>.stride),
              let countBuffer = device.makeBuffer(bytes: &countValue, length: MemoryLayout<UInt32>.stride) else {
            return cpuFallback.computeCosineSimilarityBatch(query: query, candidates: candidates, dimension: dimension)
        }
        
        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return cpuFallback.computeCosineSimilarityBatch(query: query, candidates: candidates, dimension: dimension)
        }
        
        // Set up compute encoder
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(queryBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(candidatesBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(resultsBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(dimensionBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 4)
        
        // Configure thread groups
        let threadGroupSize = MTLSize(width: computePipelineState.threadExecutionWidth, height: 1, depth: 1)
        let gridSize = MTLSize(width: numCandidates, height: 1, depth: 1)
        
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        // Execute and wait for completion
        let gpuStartTime = DispatchTime.now()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let gpuExecutionTime = DispatchTime.now().uptimeNanoseconds - gpuStartTime.uptimeNanoseconds
        metrics.gpuExecutionTime += Double(gpuExecutionTime) / 1_000_000_000.0 // Convert to seconds
        
        // Copy results back
        let resultPointer = resultsBuffer.contents()
        let resultArray = resultPointer.bindMemory(to: Float.self, capacity: numCandidates)
        var finalResults = [Float]()
        for i in 0..<numCandidates {
            finalResults.append(resultArray[i])
        }
        
        let totalTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        print("Metal compute: \(numCandidates) candidates, \(String(format: "%.3f", Double(totalTime)/1_000_000.0))ms total, \(String(format: "%.3f", metrics.gpuExecutionTime * 1000))ms GPU")
        
        return finalResults
    }
    
    /// Check if Metal is available
    public static func isMetalAvailable() -> Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
}

// Wrapper to integrate with existing capsule architecture
exension CosineSimilarityMetal: CosineSimilarityProvider {
    public func computeCosineSimilarity(query: [Float], candidate: [Float], dimension: Int) -> Float {
        return computeCosineSimilarity(query: query, candidates: [candidate], dimension: dimension, useGPU: true).first ?? 0.0
    }
    
    public func computeCosineSimilarityBatch(query: [Float], candidates: [[Float]], dimension: Int) -> [Float] {
        return computeCosineSimilarity(query: query, candidates: candidates, dimension: dimension, useGPU: true)
    }
}