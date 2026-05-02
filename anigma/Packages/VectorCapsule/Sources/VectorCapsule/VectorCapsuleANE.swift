import Foundation
import CapsuleCore

/// ANE-optimized vector capsule for batch vector math operations
/// Note: This is a placeholder implementation that will be enhanced with actual ANE acceleration
public final class VectorCapsuleANE: IdentifiableCapsule, CapsuleLifecycle {
    /// Unique identifier for this capsule instance
    public let id: String
    
    /// Performance metrics collector
    private let metricsLock = NSLock()
    private var _metrics: [String: Any] = [:]
    
    private var metrics: [String: Any] {
        get { metricsLock.withLock { _metrics } }
        set { metricsLock.withLock { _metrics = newValue } }
    }
    private let doubleScratchPool = ReusableArrayPool<Double>(maxBuffers: 2)
    
    /// Initialize ANE-optimized vector capsule
    /// - Parameters:
    ///   - id: Unique identifier for this capsule instance
    public init(id: String = UUID().uuidString) {
        self.id = id
    }
    
    // MARK: - CapsuleLifecycle
    
    /// Activate the capsule
    public func activate() async throws {
        metrics["activationTime"] = Date()
        metrics["status"] = "active"
    }
    
    /// Deactivate the capsule
    public func deactivate() async {
        metrics["deactivationTime"] = Date()
        metrics["status"] = "inactive"
    }
    
    // MARK: - Batch Vector Math Operations
    
    /// Batch calculate dot products
    /// - Parameters:
    ///   - vectorPairs: Array of vector pairs to calculate dot products for
    /// - Returns: Array of dot products
    public func batchDotProducts(_ vectorPairs: [([Double], [Double])]) async throws -> [Double] {
        let startTime = Date()
        
        // Execute dot products sequentially
        var dotProducts: [Double] = []
        dotProducts.reserveCapacity(vectorPairs.count)
        for pair in vectorPairs {
            let dotProduct = calculateDotProduct(pair.0, pair.1)
            dotProducts.append(dotProduct)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        recordMetric("batchDotProducts", time: executionTime, count: vectorPairs.count)
        
        return dotProducts
    }
    
    /// Batch calculate vector norms
    /// - Parameters:
    ///   - vectors: Array of vectors to calculate norms for
    /// - Returns: Array of norms
    public func batchVectorNorms(_ vectors: [[Double]]) async throws -> [Double] {
        let startTime = Date()
        
        // Execute norm calculations sequentially
        var norms: [Double] = []
        norms.reserveCapacity(vectors.count)
        for vector in vectors {
            let norm = calculateVectorNorm(vector)
            norms.append(norm)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        recordMetric("batchVectorNorms", time: executionTime, count: vectors.count)
        
        return norms
    }
    
    /// Batch normalize vectors
    /// - Parameters:
    ///   - vectors: Array of vectors to normalize
    /// - Returns: Array of normalized vectors
    public func batchNormalizeVectors(_ vectors: [[Double]]) async throws -> [[Double]] {
        let startTime = Date()
        
        // Execute normalization sequentially
        var normalizedVectors: [[Double]] = []
        for vector in vectors {
            let normalized = normalizeVector(vector)
            normalizedVectors.append(normalized)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        recordMetric("batchNormalizeVectors", time: executionTime, count: vectors.count)
        
        return normalizedVectors
    }
    
    /// Batch add vectors
    /// - Parameters:
    ///   - vectorPairs: Array of vector pairs to add
    /// - Returns: Array of sum vectors
    public func batchAddVectors(_ vectorPairs: [([Double], [Double])]) async throws -> [[Double]] {
        let startTime = Date()
        
        // Execute vector addition sequentially
        var sumVectors: [[Double]] = []
        for pair in vectorPairs {
            let sum = addVectors(pair.0, pair.1)
            sumVectors.append(sum)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        recordMetric("batchAddVectors", time: executionTime, count: vectorPairs.count)
        
        return sumVectors
    }
    
    /// Batch subtract vectors
    /// - Parameters:
    ///   - vectorPairs: Array of vector pairs to subtract
    /// - Returns: Array of difference vectors
    public func batchSubtractVectors(_ vectorPairs: [([Double], [Double])]) async throws -> [[Double]] {
        let startTime = Date()
        
        // Execute vector subtraction sequentially
        var diffVectors: [[Double]] = []
        for pair in vectorPairs {
            let diff = subtractVectors(pair.0, pair.1)
            diffVectors.append(diff)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        recordMetric("batchSubtractVectors", time: executionTime, count: vectorPairs.count)
        
        return diffVectors
    }
    
    /// Batch scale vectors
    /// - Parameters:
    ///   - vectorScalarPairs: Array of vector-scalar pairs to scale
    /// - Returns: Array of scaled vectors
    public func batchScaleVectors(_ vectorScalarPairs: [([Double], Double)]) async throws -> [[Double]] {
        let startTime = Date()
        
        // Execute vector scaling sequentially
        var scaledVectors: [[Double]] = []
        for pair in vectorScalarPairs {
            let scaled = scaleVector(pair.0, by: pair.1)
            scaledVectors.append(scaled)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        recordMetric("batchScaleVectors", time: executionTime, count: vectorScalarPairs.count)
        
        return scaledVectors
    }
    
    // MARK: - Performance Monitoring
    
    /// Get performance metrics for the capsule
    /// - Returns: Dictionary of performance metrics
    public func getMetrics() -> [String: Any] {
        return metrics
    }
    
    /// Reset performance metrics
    public func resetMetrics() {
        metrics.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func calculateDotProduct(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }
        var sum = 0.0
        for i in 0..<a.count {
            sum += a[i] * b[i]
        }
        return sum
    }
    
    private func calculateVectorNorm(_ vector: [Double]) -> Double {
        var sum = 0.0
        for value in vector {
            sum += value * value
        }
        return sqrt(sum)
    }
    
    private func normalizeVector(_ vector: [Double]) -> [Double] {
        let norm = calculateVectorNorm(vector)
        guard norm > 0 else { return vector }
        return doubleScratchPool.withBuffer(minimumCapacity: vector.count) { scratch in
            scratch.append(contentsOf: repeatElement(0.0, count: vector.count))
            for i in 0..<vector.count {
                scratch[i] = vector[i] / norm
            }
            return Array(scratch)
        }
    }

    private func addVectors(_ a: [Double], _ b: [Double]) -> [Double] {
        guard a.count == b.count else { return [] }
        return doubleScratchPool.withBuffer(minimumCapacity: a.count) { scratch in
            scratch.reserveCapacity(a.count)
            for i in 0..<a.count {
                scratch.append(a[i] + b[i])
            }
            return Array(scratch)
        }
    }

    private func subtractVectors(_ a: [Double], _ b: [Double]) -> [Double] {
        guard a.count == b.count else { return [] }
        return doubleScratchPool.withBuffer(minimumCapacity: a.count) { scratch in
            scratch.reserveCapacity(a.count)
            for i in 0..<a.count {
                scratch.append(a[i] - b[i])
            }
            return Array(scratch)
        }
    }

    private func scaleVector(_ vector: [Double], by scalar: Double) -> [Double] {
        return doubleScratchPool.withBuffer(minimumCapacity: vector.count) { scratch in
            scratch.append(contentsOf: repeatElement(0.0, count: vector.count))
            for i in 0..<vector.count {
                scratch[i] = vector[i] * scalar
            }
            return Array(scratch)
        }
    }
    
    private func recordMetric(_ operation: String, time: TimeInterval, count: Int) {
        let key = "\(operation)_metrics"
        if var operationMetrics = metrics[key] as? [String: Any] {
            operationMetrics["totalTime"] = (operationMetrics["totalTime"] as? TimeInterval ?? 0) + time
            operationMetrics["totalCount"] = (operationMetrics["totalCount"] as? Int ?? 0) + count
            operationMetrics["averageTime"] = (operationMetrics["totalTime"] as? TimeInterval ?? 0) / Double(max(1, operationMetrics["totalCount"] as? Int ?? 1))
            metrics[key] = operationMetrics
        } else {
            metrics[key] = [
                "totalTime": time,
                "totalCount": count,
                "averageTime": time / Double(count),
                "lastExecution": Date()
            ]
        }
    }
}
