import Testing
import Foundation
import SaturationKit
@testable import MediaCore

@Suite("Logging Ring Internal Tests")
struct LoggingRingInternalTests {
    
    @Test("Multiple appends and drains work correctly")
    func multipleAppendDrain() async throws {
        let ring = try SaturatedLoggingRing(capacity: 10)
        
        for i in 0..<5 {
            let packet = SaturatedHeartbeatPacket(
                missionID: UUID(),
                packetType: .heartbeat,
                sequence: UInt32(i),
                payloadHash: [UInt8](repeating: UInt8(i), count: 32),
                timestamp: UInt64(i)
            )
            try await ring.appendFromCPU(packet)
        }
        
        let packets = await ring.drain()
        #expect(packets.count == 5)
        for i in 0..<5 {
            #expect(packets[i].sequence == UInt32(i))
        }
    }
    
    @Test("Metadata synchronization between CPU and shared memory")
    func metadataSync() async throws {
        let ring = try SaturatedLoggingRing(capacity: 10)
        
        let packet = SaturatedHeartbeatPacket(
            missionID: UUID(),
            packetType: .heartbeat,
            sequence: 42,
            payloadHash: [UInt8](repeating: 0, count: 32),
            timestamp: 12345
        )
        try await ring.appendFromCPU(packet)
        
        let meta = await ring.metadata()
        #expect(meta.producerIndex == 1)
        #expect(meta.consumerIndex == 0)
    }
}
