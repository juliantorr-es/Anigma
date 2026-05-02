import Testing
import Foundation
import ContractsCore
@testable import MediaCore

@Suite("PacketStreamAuthority Tests")
struct PacketStreamAuthorityTests {
    let authority: PacketStreamAuthority
    
    init() {
        self.authority = PacketStreamAuthority()
    }
    
    @Test("Registering a packet produces a valid reference")
    func testRegisterPacket() async {
        let data = Data([0x00, 0x01, 0x02, 0x03])
        let reference = await authority.register(packet: data, codec: "h264", mediaType: "video")
        
        #expect(reference.codec == "h264")
        #expect(reference.mediaType == "video")
        
        let resolved = await authority.resolveData(token: reference.token)
        #expect(resolved == data)
        
        let count = await authority.activePacketCount()
        #expect(count == 1)
    }
    
    @Test("Releasing a token removes it from the registry")
    func testReleaseToken() async {
        let data = Data([0xAA, 0xBB])
        let reference = await authority.register(packet: data, codec: "aac", mediaType: "audio")
        
        await authority.release(token: reference.token)
        
        let resolved = await authority.resolveData(token: reference.token)
        #expect(resolved == nil)
        
        let count = await authority.activePacketCount()
        #expect(count == 0)
    }
}
