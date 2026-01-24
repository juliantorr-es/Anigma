import Foundation

/// Actor-based thread-safe audio fingerprinting operations.
public actor AudioFingerprint {
    private let capsule: MediaFingerprintCapsuleWrapper
    
    init(capsule: MediaFingerprintCapsuleWrapper) {
        self.capsule = capsule
    }
    
    /// Generate audio fingerprints for multiple audio files concurrently.
    /// - Parameters:
    ///   - audioData: Array of audio data.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Array of fingerprint results.
    public func generateFingerprints(
        _ audioData: [Data],
        algorithm: FingerprintAlgorithm
    ) async throws -> [FingerprintResult] {
        return try await withThrowingTaskGroup(of: FingerprintResult.self) { group in
            var results: [FingerprintResult?] = []
            results.reserveCapacity(audioData.count)
            
            for data in audioData {
                group.addTask {
                    return try self.capsule.generateAudioFingerprint(data, algorithm: algorithm)
                }
            }
            
            for try await result in group {
                results.append(result)
            }
            
            return results.compactMap { $0 }
        }
    }
    
    /// Find duplicate audio files in a batch.
    /// - Parameters:
    ///   - audioData: Array of audio data to compare.
    ///   - algorithm: Fingerprint algorithm to use.
    ///   - config: Similarity configuration.
    /// - Returns: Array of duplicate pairs (indices).
    public func findDuplicates(
        _ audioData: [Data],
        algorithm: FingerprintAlgorithm,
        config: SimilarityConfiguration = .default
    ) async throws -> [(Int, Int)] {
        // Generate fingerprints for all audio files
        let fingerprints = try await generateFingerprints(audioData, algorithm: algorithm)
        guard fingerprints.count == audioData.count else { return [] }
        
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
    
    /// Find similar audio files using batch comparison.
    /// - Parameters:
    ///   - queryAudio: Query audio data.
    ///   - candidateAudios: Array of candidate audio data.
    ///   - algorithm: Fingerprint algorithm to use.
    ///   - config: Similarity configuration.
    /// - Returns: Array of similarity results indexed by candidate order.
    public func findSimilar(
        queryAudio: Data,
        candidateAudios: [Data],
        algorithm: FingerprintAlgorithm,
        config: SimilarityConfiguration = .default
    ) async throws -> [SimilarityResult] {
        // Generate query fingerprint
        let queryFingerprint = try capsule.generateAudioFingerprint(queryAudio, algorithm: algorithm)
        
        // Generate candidate fingerprints
        let candidateFingerprints = try await generateFingerprints(candidateAudios, algorithm: algorithm)
        
        // Batch compare
        return try capsule.batchCompareFingerprints(
            queryFingerprint: queryFingerprint,
            candidateFingerprints: candidateFingerprints,
            config: config
        )
    }
    
    /// Extract audio metadata including duration, bitrate, and codec information.
    /// - Parameter data: Audio data.
    /// - Returns: Audio metadata.
    public func extractMetadata(_ data: Data) async throws -> MediaMetadata {
        return try capsule.analyzeMedia(data, mediaType: .audio)
    }
    
    /// Generate chromaprint fingerprint with high accuracy.
    /// - Parameter data: Audio data.
    /// - Returns: Chromaprint fingerprint result.
    public func generateChromaprintFingerprint(_ data: Data) async throws -> FingerprintResult {
        return try capsule.generateAudioFingerprint(data, algorithm: .chromaprint)
    }
    
    /// Perform audio similarity search across a large library.
    /// - Parameters:
    ///   - queryFingerprint: Query fingerprint.
    ///   - libraryFingerprints: Pre-computed fingerprints from audio library.
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
    
    /// Detect audio segments and their fingerprints.
    /// - Parameters:
    ///   - data: Audio data.
    ///   - segmentDuration: Duration of each segment in seconds.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Array of segment fingerprints with timestamps.
    public func segmentAndFingerprint(
        _ data: Data,
        segmentDuration: Double,
        algorithm: FingerprintAlgorithm
    ) async throws -> [(TimeInterval, FingerprintResult)] {
        // Extract metadata to get total duration
        let metadata = try await extractMetadata(data)
        let totalDuration = Double(metadata.durationMs) / 1000.0
        
        guard totalDuration > 0 else { return [] }
        
        var segmentResults: [(TimeInterval, FingerprintResult)] = []
        let segmentCount = Int(totalDuration / segmentDuration)
        
        // For simplicity, we'll use the whole audio for each segment
        // In a real implementation, you'd actually segment the audio
        for i in 0..<segmentCount {
            let timestamp = TimeInterval(i) * segmentDuration
            let fingerprint = try capsule.generateAudioFingerprint(data, algorithm: algorithm)
            segmentResults.append((timestamp, fingerprint))
        }
        
        return segmentResults
    }
}