import Foundation
import FoundationContracts
import SaturationKit
import AnigmaPrimitives

/// A Tier 2 Governance actor that coordinates media capture lifecycle and hardware-binding receipts.
/// Enforces permission compliance before authorizing capture executors.
public actor CaptureAuthority {
    private let permissionService: CapturePermissionService
    private let loggingRing: SaturatedLoggingRing
    private var activeSessions: [UUID: CaptureReceipt] = [:]
    private var eventSequence: UInt32 = 0
    
    public enum CaptureError: Error {
        case permissionDenied(PermissionState)
        case sessionNotFound
    }
    
    public init(permissionService: CapturePermissionService, loggingRing: SaturatedLoggingRing) {
        self.permissionService = permissionService
        self.loggingRing = loggingRing
    }
    
    /// Requests authorization to start a capture session.
    /// Returns a CaptureReceipt if permissions are granted.
    public func requestCapture(type: CaptureMediaType) async throws -> CaptureReceipt {
        // 1. Verify permission state via CapturePermissionService
        let (state, receipt) = await permissionService.authorizationStatus(for: type)
        
        guard state == .authorized, let permissionReceipt = receipt else {
            throw CaptureError.permissionDenied(state)
        }
        
        // 2. Generate a hardware-binding CaptureReceipt
        let captureReceipt = CaptureReceipt(
            id: UUID(),
            type: type,
            permissionAuditID: permissionReceipt.auditID,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        
        // 3. Register active session
        activeSessions[captureReceipt.id] = captureReceipt
        
        // 4. Log start event to SaturatedLoggingRing
        try await logCaptureEvent(receipt: captureReceipt, event: "START")
        
        return captureReceipt
    }
    
    /// Terminates an active capture session.
    public func endCapture(receipt: CaptureReceipt) async throws {
        guard activeSessions.removeValue(forKey: receipt.id) != nil else {
            throw CaptureError.sessionNotFound
        }
        
        // Log stop event to SaturatedLoggingRing
        try await logCaptureEvent(receipt: receipt, event: "STOP")
    }
    
    /// Returns a list of all currently active capture sessions.
    public func activeCaptureSessions() -> [CaptureReceipt] {
        return Array(activeSessions.values)
    }
    
    // MARK: - Internal Helpers
    
    private func logCaptureEvent(receipt: CaptureReceipt, event: String) async throws {
        let sequence = eventSequence
        eventSequence = eventSequence &+ 1
        
        let hashSource = "CaptureEvent:\(event):\(receipt.type.rawValue):\(receipt.id.uuidString)"
        let hash = BLAKE3Digest.digest(Data(hashSource.utf8))
        
        let packet = SaturatedHeartbeatPacket(
            missionID: receipt.id,
            packetType: .heartbeat,
            sequence: sequence,
            payloadHash: hash,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        
        try await loggingRing.appendFromCPU(packet)
    }
}
