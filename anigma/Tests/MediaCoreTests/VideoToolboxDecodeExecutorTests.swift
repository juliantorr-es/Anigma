import Testing
import Foundation
@preconcurrency import VideoToolbox
import CoreMedia
import AVFoundation
import ContractsCore
import SaturationKit
@testable import MediaCore

@Suite("VideoToolboxDecodeExecutor Tests")
struct VideoToolboxDecodeExecutorTests {
    let surfaceAuthority: SurfaceAuthority
    let packetAuthority: PacketStreamAuthority
    let loggingRing: SaturatedLoggingRing
    let executor: VideoToolboxDecodeExecutor
    
    init() throws {
        self.surfaceAuthority = SurfaceAuthority()
        self.packetAuthority = PacketStreamAuthority()
        self.loggingRing = try SaturatedLoggingRing(capacity: 100)
        self.executor = VideoToolboxDecodeExecutor(
            surfaceAuthority: surfaceAuthority,
            packetAuthority: packetAuthority,
            loggingRing: loggingRing
        )
    }
    
    @Test("Decoding H.264 bitstream produces registered FrameReference")
    func decodeH264() async throws {
        // 1. Get real MP4 fixture
        let fixtureURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/test.mp4")
            
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            // Skip test if fixture generation failed
            return
        }
        
        let asset = AVAsset(url: fixtureURL)
        let reader = try AVAssetReader(asset: asset)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoToolboxDecodeExecutor.DecodeError.noOutput
        }
        
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()
        
        var sampleBuffer = output.copyNextSampleBuffer()
        while let sb = sampleBuffer, CMSampleBufferGetNumSamples(sb) == 0 {
            sampleBuffer = output.copyNextSampleBuffer()
        }
        
        guard let finalSampleBuffer = sampleBuffer else {
            throw VideoToolboxDecodeExecutor.DecodeError.missingSampleBuffer
        }
        
        // 2. Register into PacketStreamAuthority as Any
        let packetToken = await packetAuthority.register(
            packet: finalSampleBuffer as Any,
            codec: "h264",
            mediaType: "video"
        )
        
        let contract = VideoDecodeContract(packetToken: packetToken.token, codec: "h264")
        
        // 3. Execute
        let result = try await executor.execute(contract: contract)
        guard case .videoFrame(let frameRef) = result else {
            Issue.record("Expected MediaReference.videoFrame")
            return
        }
        
        // 4. Verify Output
        #expect(frameRef.width == 64)
        #expect(frameRef.height == 64)
        
        // 5. Verify Registry
        let count = await surfaceAuthority.activeSurfaceCount()
        #expect(count == 1)
        
        // 6. Verify Telemetry
        let packets = await loggingRing.drain()
        #expect(packets.count == 1)
        #expect(packets[0].packetType == .heartbeat)
    }
}

