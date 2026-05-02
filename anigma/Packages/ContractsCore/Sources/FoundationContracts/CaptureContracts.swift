import Foundation

/// Portable media types for capture.
public enum CaptureMediaType: String, Sendable, Codable {
    case video
    case audio
}

/// Portable permission states, mapping to native platform states (e.g., TCC).
public enum PermissionState: String, Sendable, Codable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

/// A governance receipt proving that a permission check was performed.
public struct PermissionReceipt: Sendable, Codable {
    public let type: CaptureMediaType
    public let state: PermissionState
    public let timestamp: UInt64
    public let auditID: UUID
    
    public init(type: CaptureMediaType, state: PermissionState, timestamp: UInt64, auditID: UUID) {
        self.type = type
        self.state = state
        self.timestamp = timestamp
        self.auditID = auditID
    }
}

/// A hardware-binding receipt representing an authorized active capture session.
public struct CaptureReceipt: Sendable, Codable, Hashable {
    public let id: UUID
    public let type: CaptureMediaType
    public let permissionAuditID: UUID
    public let timestamp: UInt64
    
    public init(id: UUID, type: CaptureMediaType, permissionAuditID: UUID, timestamp: UInt64) {
        self.id = id
        self.type = type
        self.permissionAuditID = permissionAuditID
        self.timestamp = timestamp
    }
}

/// Configuration for a capture session.
public struct CaptureConfiguration: Sendable, Codable {
    public let fps: Int
    public let preset: String
    
    public init(fps: Int = 30, preset: String = "hd1280x720") {
        self.fps = fps
        self.preset = preset
    }
    
    public static let standard = CaptureConfiguration()
}
