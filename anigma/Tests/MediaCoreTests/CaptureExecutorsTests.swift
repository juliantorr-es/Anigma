import Testing
import Foundation
import AVFoundation
import ContractsCore
@testable import MediaCore

@Suite("Capture Executors Tests")
struct CaptureExecutorsTests {
    let surfaceAuthority: SurfaceAuthority
    
    init() {
        self.surfaceAuthority = SurfaceAuthority()
    }
    
    @Test("CameraCaptureExecutor initialization validation")
    func testCameraInit() throws {
        let videoReceipt = CaptureReceipt(id: UUID(), type: .video, permissionAuditID: UUID(), timestamp: 0)
        let audioReceipt = CaptureReceipt(id: UUID(), type: .audio, permissionAuditID: UUID(), timestamp: 0)
        
        // Should succeed
        let _ = try CameraCaptureExecutor(surfaceAuthority: surfaceAuthority, receipt: videoReceipt)
        
        // Should fail
        #expect(throws: CameraCaptureExecutor.CameraError.invalidReceiptType) {
            try CameraCaptureExecutor(surfaceAuthority: surfaceAuthority, receipt: audioReceipt)
        }
    }
    
    @Test("MicrophoneCaptureExecutor initialization validation")
    func testMicrophoneInit() throws {
        let audioAuthority = AudioBufferAuthority()
        let videoReceipt = CaptureReceipt(id: UUID(), type: .video, permissionAuditID: UUID(), timestamp: 0)
        let audioReceipt = CaptureReceipt(id: UUID(), type: .audio, permissionAuditID: UUID(), timestamp: 0)
        
        // Should succeed
        let _ = try MicrophoneCaptureExecutor(audioAuthority: audioAuthority, receipt: audioReceipt)
        
        // Should fail
        #expect(throws: MicrophoneCaptureExecutor.MicrophoneError.invalidReceiptType) {
            try MicrophoneCaptureExecutor(audioAuthority: audioAuthority, receipt: videoReceipt)
        }
    }
}
