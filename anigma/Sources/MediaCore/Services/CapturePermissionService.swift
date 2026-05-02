import Foundation
import AVFoundation
import FoundationContracts
import SaturationKit
import AnigmaPrimitives

/// Internal protocol to allow deterministic AVFoundation permission providers in tests.
internal protocol PermissionProvider: Sendable {
    func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus
    func requestAccess(for mediaType: AVMediaType) async -> Bool
}

/// Native macOS provider using AVFoundation.
internal struct AVFoundationPermissionProvider: PermissionProvider {
    func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: mediaType)
    }
    
    func requestAccess(for mediaType: AVMediaType) async -> Bool {
        return await AVCaptureDevice.requestAccess(for: mediaType)
    }
}

/// A Tier 2 Governance Service that manages AVFoundation permissions.
/// Maps native TCC states to portable Anigma descriptors and issues audit receipts.
public actor CapturePermissionService {
    private let provider: PermissionProvider
    private let loggingRing: SaturatedLoggingRing
    private var eventSequence: UInt32 = 0
    
    public init(loggingRing: SaturatedLoggingRing) {
        self.provider = AVFoundationPermissionProvider()
        self.loggingRing = loggingRing
    }
    
    /// Internal initializer for dependency injection in tests.
    internal init(provider: PermissionProvider, loggingRing: SaturatedLoggingRing) {
        self.provider = provider
        self.loggingRing = loggingRing
    }
    
    /// Returns the current authorization status and an optional receipt.
    public func authorizationStatus(for type: CaptureMediaType) -> (PermissionState, PermissionReceipt?) {
        let nativeType = mapToNative(type)
        let nativeStatus = provider.authorizationStatus(for: nativeType)
        let state = mapFromNative(nativeStatus)
        
        let receipt = state == .authorized ? generateReceipt(for: type, state: state) : nil
        return (state, receipt)
    }
    
    /// Requests access to the specified media type.
    public func requestAccess(for type: CaptureMediaType) async -> (PermissionState, PermissionReceipt) {
        let nativeType = mapToNative(type)
        _ = await provider.requestAccess(for: nativeType)
        
        // Re-check status after request
        let nativeStatus = provider.authorizationStatus(for: nativeType)
        let state = mapFromNative(nativeStatus)
        
        let receipt = generateReceipt(for: type, state: state)
        
        // Audit the request via SaturatedLoggingRing
        try? await logPermissionAudit(receipt: receipt)
        
        return (state, receipt)
    }
    
    // MARK: - Internal Helpers
    
    private func mapToNative(_ type: CaptureMediaType) -> AVMediaType {
        switch type {
        case .video: return .video
        case .audio: return .audio
        }
    }
    
    private func mapFromNative(_ status: AVAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .denied
        }
    }
    
    private func generateReceipt(for type: CaptureMediaType, state: PermissionState) -> PermissionReceipt {
        return PermissionReceipt(
            type: type,
            state: state,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
            auditID: UUID()
        )
    }
    
    private func logPermissionAudit(receipt: PermissionReceipt) async throws {
        let sequence = eventSequence
        eventSequence = eventSequence &+ 1
        
        let hashSource = "PermissionCheck:\(receipt.type.rawValue):\(receipt.state.rawValue):\(receipt.auditID.uuidString)"
        let hash = BLAKE3Digest.digest(Data(hashSource.utf8))
        
        let packet = SaturatedHeartbeatPacket(
            missionID: UUID(),
            packetType: .heartbeat,
            sequence: sequence,
            payloadHash: hash,
            timestamp: receipt.timestamp
        )
        
        try await loggingRing.appendFromCPU(packet)
    }
}
