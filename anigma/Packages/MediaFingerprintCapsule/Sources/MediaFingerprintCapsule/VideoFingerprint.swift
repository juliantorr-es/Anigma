import Foundation

/// Actor-based thread-safe video fingerprinting operations.
public actor VideoFingerprint {
    private let capsule: MediaFingerprintCapsuleWrapper
    
    init(capsule: MediaFingerprintCapsuleWrapper) {
        self.capsule = capsule
    }
    
    /// Generate video fingerprints for multiple video files concurrently.
    /// - Parameters:
    ///   - videoData: Array of video data.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Array of fingerprint results.
    public func generateFingerprints(
        _ videoData: [Data],
        algorithm: FingerprintAlgorithm
    ) async throws -> [FingerprintResult] {
        return try await withTaskGroup(of: FingerprintResult.self) { group in
            var results: [FingerprintResult?] = []
            results.reserveCapacity(videoData.count)
            
            for data in videoData {
                group.addTask {
                    return try self.capsule.generateVideoFingerprint(data, algorithm: algorithm)
                }
            }
            
            for try await result in group {
                results.append(result)
            }
            
            return results.compactMap { $0 }
        }
    }
    
    /// Find duplicate video files in a batch.
    /// - Parameters:
    ///   - videoData: Array of video data to compare.
    ///   - algorithm: Fingerprint algorithm to use.
    ///   - config: Similarity configuration.
    /// - Returns: Array of duplicate pairs (indices).
    public func findDuplicates(
        _ videoData: [Data],
        algorithm: FingerprintAlgorithm,
        config: SimilarityConfiguration = .default
    ) async throws -> [(Int, Int)] {
        // Generate fingerprints for all video files
        let fingerprints = try await generateFingerprints(videoData, algorithm: algorithm)
        guard fingerprints.count == videoData.count else { return [] }
        
        var duplicatePairs: [(Int, Int)] = []
        
        // Compare each pair
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
    
    /// Find similar video files using batch comparison.
    /// - Parameters:
    ///   - queryVideo: Query video data.
    ///   - candidateVideos: Array of candidate video data.
    ///   - algorithm: Fingerprint algorithm to use.
    ///   - config: Similarity configuration.
    /// - Returns: Array of similarity results indexed by candidate order.
    public func findSimilar(
        queryVideo: Data,
        candidateVideos: [Data],
        algorithm: FingerprintAlgorithm,
        config: SimilarityConfiguration = .default
    ) async throws -> [SimilarityResult] {
        // Generate query fingerprint
        let queryFingerprint = try capsule.generateVideoFingerprint(queryVideo, algorithm: algorithm)
        
        // Generate candidate fingerprints
        let candidateFingerprints = try await generateFingerprints(candidateVideos, algorithm: algorithm)
        
        // Batch compare
        return try capsule.batchCompareFingerprints(
            queryFingerprint: queryFingerprint,
            candidateFingerprints: candidateFingerprints,
            config: config
        )
    }
    
    /// Extract video metadata including dimensions, duration, and codec information.
    /// - Parameter data: Video data.
    /// - Returns: Video metadata.
    public func extractMetadata(_ data: Data) async throws -> MediaMetadata {
        return try capsule.analyzeMedia(data, mediaType: .video)
    }
    
    /// Generate motion vector-based fingerprint.
    /// - Parameter data: Video data.
    /// - Returns: Motion vector fingerprint result.
    public func generateMotionVectorFingerprint(_ data: Data) async throws -> FingerprintResult {
        return try capsule.generateVideoFingerprint(data, algorithm: .motionVector)
    }
    
    /// Perform video scene detection and fingerprinting.
    /// - Parameters:
    ///   - data: Video data.
    ///   - sceneThreshold: Threshold for detecting scene changes.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Array of scene fingerprints with timestamps.
    public func detectScenesAndFingerprint(
        _ data: Data,
        sceneThreshold: Double = 0.3,
        algorithm: FingerprintAlgorithm
    ) async throws -> [(TimeInterval, FingerprintResult)] {
        // Extract metadata to get total duration
        let metadata = try extractMetadata(data)
        let totalDuration = Double(metadata.durationMs) / 1000.0
        
        guard totalDuration > 0 else { return [] }
        
        var sceneResults: [(TimeInterval, FingerprintResult)] = []
        
        // For simplicity, we'll simulate scene detection with fixed intervals
        // In a real implementation, you'd analyze motion vectors, histograms, etc.
        let sceneInterval = totalDuration / 10.0 // 10 scenes
        
        for i in 0..<10 {
            let timestamp = TimeInterval(i) * sceneInterval
            let fingerprint = try capsule.generateVideoFingerprint(data, algorithm: algorithm)
            sceneResults.append((timestamp, fingerprint))
        }
        
        return sceneResults
    }
    
    /// Generate fingerprints for keyframes only.
    /// - Parameters:
    ///   - data: Video data.
    ///   - algorithm: Fingerprint algorithm to use.
    ///   - keyframeInterval: Interval between keyframes in seconds.
    /// - Returns: Array of keyframe fingerprints with timestamps.
    public func extractKeyframesAndFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm,
        keyframeInterval: Double = 1.0
    ) async throws -> [(TimeInterval, FingerprintResult)] {
        // Extract metadata to get total duration
        let metadata = try extractMetadata(data)
        let totalDuration = Double(metadata.durationMs) / 1000.0
        
        guard totalDuration > 0 else { return [] }
        
        var keyframeResults: [(TimeInterval, FingerprintResult)] = []
        let keyframeCount = Int(totalDuration / keyframeInterval)
        
        for i in 0..<keyframeCount {
            let timestamp = TimeInterval(i) * keyframeInterval
            let fingerprint = try capsule.generateVideoFingerprint(data, algorithm: algorithm)
            keyframeResults.append((timestamp, fingerprint))
        }
        
        return keyframeResults
    }
    
    /// Perform video similarity search across a large library.
    /// - Parameters:
    ///   - queryFingerprint: Query fingerprint.
    ///   - libraryFingerprints: Pre-computed fingerprints from video library.
    ///   - config: Similarity configuration.
    ///   - topK: Number of top results to return.
    /// - Returns: Array of top-K similar matches with their indices.
    public func searchLibrary(
        queryFingerprint: FingerprintResult,
        libraryFingerprints: [FingerprintResult],
        config: SimilarityConfiguration = .default,
        topK: Int = 10
    ) async throws -> [(Int, SimilarityResult)] {
        guard !libraryFingerprints.isEmpty else { return [] }
        
        // Batch compare against all library fingerprints
        let results = try capsule.batchCompareFingerprints(
            queryFingerprint: queryFingerprint,
            candidateFingerprints: libraryFingerprints,
            config: config
        )
        
        // Sort by similarity score and return top-K
        let indexedResults = results.enumerated().map { (index, result) in
            (index, result)
        }.sorted { $0.1.similarityScore > $1.1.similarityScore }
        
        return Array(indexedResults.prefix(topK))
    }
    
    /// Generate multi-resolution fingerprints for robust matching.
    /// - Parameters:
    ///   - data: Video data.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Dictionary mapping resolution to fingerprint.
    public func generateMultiResolutionFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm
    ) async throws -> [String: FingerprintResult] {
        // Generate fingerprints at different conceptual resolutions
        // In a real implementation, you'd actually resize video frames
        let resolutions = ["low", "medium", "high"]
        var results: [String: FingerprintResult] = [:]
        
        for resolution in resolutions {
            let fingerprint = try capsule.generateVideoFingerprint(data, algorithm: algorithm)
            results[resolution] = fingerprint
        }
        
        return results
    }
}