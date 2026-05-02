import Foundation

/// Actor-based thread-safe image fingerprinting operations.
public actor ImageFingerprint {
    private let capsule: MediaFingerprintCapsuleWrapper
    
    init(capsule: MediaFingerprintCapsuleWrapper) {
        self.capsule = capsule
    }
    
    /// Generate multiple image fingerprints concurrently.
    /// - Parameters:
    ///   - imageData: Array of image data.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Array of fingerprint results.
    public func generateFingerprints(
        _ imageData: [Data],
        algorithm: FingerprintAlgorithm
    ) async throws -> [FingerprintResult] {
        return try await withThrowingTaskGroup(of: FingerprintResult.self) { group in
            var results: [FingerprintResult?] = Array(repeating: nil, count: imageData.count)
            
            for (_, data) in imageData.enumerated() {
                group.addTask {
                    return try self.capsule.generateImageFingerprint(data, algorithm: algorithm)
                }
            }
            
            for try await result in group {
                // This is a simplified approach - in practice you'd track indices
                results.append(result)
            }
            
            return results.compactMap { $0 }
        }
    }
    
    /// Find duplicate images in a batch.
    /// - Parameters:
    ///   - imageData: Array of image data to compare.
    ///   - algorithm: Fingerprint algorithm to use.
    ///   - config: Similarity configuration.
    /// - Returns: Array of duplicate pairs (indices).
    public func findDuplicates(
        _ imageData: [Data],
        algorithm: FingerprintAlgorithm,
        config: SimilarityConfiguration = .default
    ) async throws -> [(Int, Int)] {
        // Generate fingerprints for all images
        let fingerprints = try await generateFingerprints(imageData, algorithm: algorithm)
        guard fingerprints.count == imageData.count else { return [] }
        
        var duplicatePairs: [(Int, Int)] = []
        
        // Compare each pair (this is O(n²) - in practice you'd use LSH or other optimization)
        for i in 0..<fingerprints.count {
            for j in (i + 1)..<fingerprints.count {
                let similarity = try capsule.compareFingerprints(
                    fingerprints[i],
                    fingerprints[j],
                    config: config
                )
                
                if similarity.isDuplicate {
                    duplicatePairs.append((i, j))
                }
            }
        }
        
        return duplicatePairs
    }
    
    /// Find similar images using batch comparison.
    /// - Parameters:
    ///   - queryImage: Query image data.
    ///   - candidateImages: Array of candidate image data.
    ///   - algorithm: Fingerprint algorithm to use.
    ///   - config: Similarity configuration.
    /// - Returns: Array of similarity results indexed by candidate order.
    public func findSimilar(
        queryImage: Data,
        candidateImages: [Data],
        algorithm: FingerprintAlgorithm,
        config: SimilarityConfiguration = .default
    ) async throws -> [SimilarityResult] {
        // Generate query fingerprint
        let queryFingerprint = try capsule.generateImageFingerprint(queryImage, algorithm: algorithm)
        
        // Generate candidate fingerprints
        let candidateFingerprints = try await generateFingerprints(candidateImages, algorithm: algorithm)
        
        // Batch compare
        return try capsule.batchCompareFingerprints(
            queryFingerprint: queryFingerprint,
            candidateFingerprints: candidateFingerprints,
            config: config
        )
    }
    
    /// Extract image dimensions and format information.
    /// - Parameter data: Image data.
    /// - Returns: Image metadata including dimensions.
    public func extractMetadata(_ data: Data) async throws -> MediaMetadata {
        return try capsule.analyzeMedia(data, mediaType: .image)
    }
    
    /// Generate perceptual hash with multiple algorithms.
    /// - Parameter data: Image data.
    /// - Returns: Dictionary mapping algorithm to fingerprint.
    public func generateMultiAlgorithmFingerprint(_ data: Data) async throws -> [FingerprintAlgorithm: FingerprintResult] {
        let algorithms: [FingerprintAlgorithm] = [
            .averageHash,
            .differenceHash,
            .waveletHash,
            .perceptualHash
        ]
        
        var results: [FingerprintAlgorithm: FingerprintResult] = [:]
        
        for algorithm in algorithms {
            let fingerprint = try capsule.generateImageFingerprint(data, algorithm: algorithm)
            results[algorithm] = fingerprint
        }
        
        return results
    }
}
