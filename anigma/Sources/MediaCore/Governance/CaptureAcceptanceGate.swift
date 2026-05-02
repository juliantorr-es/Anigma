import Foundation
import FoundationContracts
import SaturationKit
import AnigmaPrimitives

/// A Tier 2 Governance actor that monitors capture health and enforces stream continuity.
/// Validates incoming frames against the capture receipt and drives the Governance Strip UI.
public actor CaptureAcceptanceGate {
    private let captureAuthority: CaptureAuthority
    private let receipt: CaptureReceipt
    private let loggingRing: SaturatedLoggingRing
    
    private var frameTimestamps: [Date] = []
    private var droppedFrameCount: Int = 0
    private var currentState: GovernanceStripState = .inactive
    private var stateContinuation: AsyncStream<GovernanceStripState>.Continuation?
    
    /// Thresholds for health monitoring.
    private let fpsDegradedThreshold: Double = 10.0
    private let windowSize: Int = 30
    
    public init(captureAuthority: CaptureAuthority, receipt: CaptureReceipt, loggingRing: SaturatedLoggingRing) {
        self.captureAuthority = captureAuthority
        self.receipt = receipt
        self.loggingRing = loggingRing
    }
    
    /// Reactive stream of visibility states for the trusted UI.
    public var stripStateStream: AsyncStream<GovernanceStripState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
            continuation.yield(self.currentState)
            continuation.onTermination = { @Sendable _ in }
        }
    }
    
    /// Wraps an incoming capture stream with health and governance monitoring.
    /// Rejects frames and transitions to .compromised if the capture session is revoked.
    public func monitor(stream: AsyncThrowingStream<FrameReference, Error>) -> AsyncThrowingStream<FrameReference, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                self.transition(to: .active)
                
                do {
                    for try await frame in stream {
                        // 1. Governance Check: Verify receipt is still active
                        let isValid = await verifyReceipt()
                        if !isValid {
                            try await logCompromisedEvent()
                            self.transition(to: .compromised)
                            continuation.finish()
                            return
                        }
                        
                        // 2. Health Check: Track FPS
                        updateMetrics()
                        
                        // 3. Pass-through
                        continuation.yield(frame)
                    }
                    self.transition(to: .inactive)
                    continuation.finish()
                } catch {
                    self.transition(to: .inactive)
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Internal Helpers
    
    private func verifyReceipt() async -> Bool {
        let activeSessions = await captureAuthority.activeCaptureSessions()
        return activeSessions.contains { $0.id == receipt.id }
    }
    
    private func updateMetrics() {
        let now = Date()
        frameTimestamps.append(now)
        if frameTimestamps.count > windowSize {
            frameTimestamps.removeFirst()
        }
        
        let fps = calculateFPS()
        if fps < fpsDegradedThreshold && currentState == .active {
            transition(to: .degraded)
        } else if fps >= fpsDegradedThreshold && currentState == .degraded {
            transition(to: .active)
        }
    }
    
    private func calculateFPS() -> Double {
        guard frameTimestamps.count >= 2 else { return 0 }
        let duration = frameTimestamps.last!.timeIntervalSince(frameTimestamps.first!)
        guard duration > 0 else { return 0 }
        return Double(frameTimestamps.count - 1) / duration
    }
    
    private func transition(to state: GovernanceStripState) {
        guard state != currentState else { return }
        currentState = state
        stateContinuation?.yield(state)
        
        // Audit state changes
        Task {
            try? await logStateTransition(state)
        }
    }
    
    private func logStateTransition(_ state: GovernanceStripState) async throws {
        let hashSource = "GateStateTransition:\(receipt.id.uuidString):\(state.rawValue)"
        let hash = BLAKE3Digest.digest(Data(hashSource.utf8))
        
        let packet = SaturatedHeartbeatPacket(
            missionID: receipt.id,
            packetType: .heartbeat,
            sequence: 0, // In Phase 0 we simplify sequence for this log
            payloadHash: hash,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        
        try await loggingRing.appendFromCPU(packet)
    }
    
    private func logCompromisedEvent() async throws {
        let hashSource = "CRITICAL:GovernanceCompromised:\(receipt.id.uuidString)"
        let hash = BLAKE3Digest.digest(Data(hashSource.utf8))
        
        let packet = SaturatedHeartbeatPacket(
            missionID: receipt.id,
            packetType: .heartbeat,
            sequence: 0,
            payloadHash: hash,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        
        try await loggingRing.appendFromCPU(packet)
    }
}
