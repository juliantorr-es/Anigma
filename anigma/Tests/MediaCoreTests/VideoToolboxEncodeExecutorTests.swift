import Testing
import Foundation
import CoreVideo
import ContractsCore
@testable import MediaCore

@Suite("VideoToolboxEncodeExecutor Tests")
struct VideoToolboxEncodeExecutorTests {
    let surfaceAuthority: SurfaceAuthority
    let packetAuthority: PacketStreamAuthority
    
    init() {
        self.surfaceAuthority = SurfaceAuthority()
        self.packetAuthority = PacketStreamAuthority()
    }
    
    @Test("Encoding a native surface produces a bitstream packet")
    func testEncodeFrame() async throws {
        let executor = VideoToolboxEncodeExecutor(
            surfaceAuthority: surfaceAuthority,
            packetAuthority: packetAuthority
        )
        
        // 1. Create a native CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            128, 128,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pb = pixelBuffer else { return }
        
        // 2. Register it with SurfaceAuthority
        let reference = await surfaceAuthority.register(pixelBuffer: pb)
        
        // 3. Encode
        let contract = VideoEncodeContract(sourceFrame: reference, targetCodec: "h264")
        let result = try await executor.execute(contract: contract)
        
        if case .packetStream(let packet) = result {
            #expect(packet.codec == "h264")
            let data = await packetAuthority.resolveData(token: packet.token)
            #expect(data != nil)
            #expect(data!.count > 0)
        } else {
            Issue.record("Expected packetStream result")
        }
    }
}
