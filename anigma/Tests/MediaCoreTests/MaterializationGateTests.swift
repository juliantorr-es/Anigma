import Testing
import Foundation
import SaturationKit
import ContractsCore
@testable import MediaCore

@Suite("MaterializationGate Tests")
struct MaterializationGateTests {
    let loggingRing: SaturatedLoggingRing
    let gate: MaterializationGate
    
    init() throws {
        self.loggingRing = try SaturatedLoggingRing(capacity: 128)
        self.gate = MaterializationGate(loggingRing: loggingRing)
    }
    
    @Test("Authorizing allowed materialization reasons")
    func authorizeAllowedReasons() async throws {
        let reasons: [MaterializationReason] = [.finalArtifact, .debugSnapshot, .fallbackBoundary]
        
        for reason in reasons {
            let context = "test-media-\(reason.rawValue)"
            let receipt = try await gate.authorizeCopy(reason: reason, context: context)
            
            #expect(receipt.decision == .allowed)
            #expect(receipt.context == context)
            #expect(receipt.reason.contains(reason.rawValue))
        }
        
        // Verify telemetry
        let packets = await loggingRing.drain()
        #expect(packets.count == reasons.count)
        for (index, packet) in packets.enumerated() {
            #expect(packet.packetType == .heartbeat)
            #expect(packet.sequence == UInt32(index))
        }
    }
    
    @Test("Denying unsupported executor materialization")
    func denyUnsupportedExecutor() async throws {
        let reason: MaterializationReason = .unsupportedExecutor
        let context = "test-media-denied"
        
        await #expect(throws: MaterializationError.self) {
            try await gate.authorizeCopy(reason: reason, context: context)
        }
        
        // Verify telemetry still logged the attempt
        let packets = await loggingRing.drain()
        #expect(packets.count == 1)
        #expect(packets[0].packetType == .violation)
    }
    
    @Test("Event sequence increments correctly")
    func sequenceIncrements() async throws {
        _ = try await gate.authorizeCopy(reason: .finalArtifact, context: "ctx1")
        _ = try await gate.authorizeCopy(reason: .debugSnapshot, context: "ctx2")
        
        let packets = await loggingRing.drain()
        #expect(packets.count == 2)
        #expect(packets[0].sequence == 0)
        #expect(packets[1].sequence == 1)
    }
}
