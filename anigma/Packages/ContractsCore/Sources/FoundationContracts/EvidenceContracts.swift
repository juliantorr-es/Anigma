import Foundation

/// A cryptographic fingerprint for a media buffer (frame or audio block).
/// Provides tamper-evident proof of the buffer's exact state at a point in time.
public struct MediaFingerprint: Sendable, Codable, Hashable {
    /// The cryptographic hash of the buffer data.
    public let hash: String
    /// The algorithm used to generate the hash (e.g., "sha256").
    public let algorithm: String
    /// The timestamp when the fingerprint was generated.
    public let timestamp: UInt64
    
    public init(hash: String, algorithm: String, timestamp: UInt64) {
        self.hash = hash
        self.algorithm = algorithm
        self.timestamp = timestamp
    }
}
