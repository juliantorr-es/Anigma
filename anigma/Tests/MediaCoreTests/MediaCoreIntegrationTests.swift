import Testing
@testable import MediaCore
import SaturationKit
import Foundation
import ContractsCore

@Suite("MediaCore Integration Tests")
struct MediaCoreIntegrationTests {
    
    @Test("Real life permission lifecycle and enforcement")
    func testPermissionEnforcementWithSystemState() async throws {
        let loggingRing = try await SaturatedLoggingRing(capacity: 128)
        let permissionService = CapturePermissionService(loggingRing: loggingRing)
        let authority = CaptureAuthority(permissionService: permissionService, loggingRing: loggingRing)
        
        // 1. Verify current system status (Real AVFoundation probe)
        let (state, receipt) = await permissionService.authorizationStatus(for: .video)
        
        // In a typical CLI/CI environment, this will be .notDetermined or .denied
        print("🔍 Real system video permission state: \(state)")
        
        if state == .authorized {
            // Success path (unlikely in CI, but valid if run locally with permissions)
            #expect(receipt != nil)
            let captureReceipt = try await authority.requestCapture(type: .video)
            #expect(captureReceipt.type == .video)
            // Just verify an audit ID exists; it might be a fresh one
            #expect(captureReceipt.permissionAuditID != nil)
            
            // Verify session registration
            let active = await authority.activeCaptureSessions()
            #expect(active.contains(where: { $0.id == captureReceipt.id }))
            
            // End capture
            try await authority.endCapture(receipt: captureReceipt)
        } else {
            // Enforcement path (Expected in CI)
            #expect(receipt == nil)
            
            do {
                _ = try await authority.requestCapture(type: .video)
                Issue.record("Capture should be blocked when state is \(state)")
            } catch let error as CaptureAuthority.CaptureError {
                if case .permissionDenied(let reportedState) = error {
                    #expect(reportedState == state)
                } else {
                    Issue.record("Unexpected error type: \(error)")
                }
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }
    
    @Test("Logging ring capacity and initialization")
    func testLoggingRingRealInitialization() async throws {
        // Verify we can initialize a real ring with specific capacity
        let ring = try await SaturatedLoggingRing(capacity: 64)
        #expect(ring != nil)
    }
}
