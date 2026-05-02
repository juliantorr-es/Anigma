import Foundation

/// Possible visibility states for the trusted Governance Strip UI.
public enum GovernanceStripState: String, Sendable, Codable {
    /// No active capture or ingestion.
    case inactive
    /// Capturing normally with verified governance receipts.
    case active
    /// Performance issue detected (e.g. low FPS, stall), but governance receipt is still valid.
    case degraded
    /// Governance failure detected: receipt revoked, session unauthorized, or hijacking suspected.
    case compromised
}

/// Real-time health metrics for a media capture stream.
public struct StreamHealthMetrics: Sendable, Codable {
    public let fps: Double
    public let droppedFrames: Int
    public let receiptIsValid: Bool
    public let timestamp: UInt64
    
    public init(fps: Double, droppedFrames: Int, receiptIsValid: Bool, timestamp: UInt64) {
        self.fps = fps
        self.droppedFrames = droppedFrames
        self.receiptIsValid = receiptIsValid
        self.timestamp = timestamp
    }
}
