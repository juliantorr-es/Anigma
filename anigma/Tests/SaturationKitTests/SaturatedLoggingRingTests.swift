import Testing
@testable import SaturationKit
import CryptoKit
import Foundation
#if canImport(Metal)
import Metal
#endif

struct SaturatedLoggingRingTests {

    @Test func heartbeatPayloadHashMatchesOfficialBLAKE3AndNotSHA256() throws {
        let payload = Data()
        let hash = try SaturatedHeartbeatPacket.payloadHash(
            for: payload,
            preferMetalDigest: false
        )

        #expect(hex(hash.bytes) == "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262")
        #expect(hex(hash.bytes) != sha256Hex(payload))
        #expect(hash.substrate == .cpuFallback)
    }

    @Test func heartbeatPayloadHashSubstrateLabelTracksExecutionPath() throws {
        let payload = Data("saturated-heartbeat".utf8)
        let hash = try SaturatedHeartbeatPacket.payloadHash(for: payload)

        #if canImport(Metal)
        if MTLCreateSystemDefaultDevice() != nil {
            #expect(hash.substrate == .metalDigest)
        } else {
            #expect(hash.substrate == .cpuFallback)
        }
        #else
        #expect(hash.substrate == .cpuFallback)
        #endif
        #expect(hash.bytes == Blake3Digest.digest(payload))
    }

    @Test func heartbeatPacketEncodingRoundTrips() throws {
        let packet = makePacket(sequence: 7)
        let encoded = packet.canonicalBinaryEncoding()

        #expect(encoded.count == SaturatedHeartbeatPacket.extendedEncodedLength)
        #expect(try SaturatedHeartbeatPacket(decoding: encoded) == packet)
    }

    @Test func ringHaltsProducerOnOverflow() async throws {
        let ring = try SaturatedLoggingRing(capacity: 2, overflowPolicy: .haltProducer)

        try await ring.appendFromCPU(makePacket(sequence: 1))
        try await ring.appendFromCPU(makePacket(sequence: 2))
        
        await #expect(throws: SaturatedLoggingRingError.ringFull) {
            try await ring.appendFromCPU(makePacket(sequence: 3))
        }

        let metadata = await ring.metadata()
        let drainedSequences = await ring.drain().map(\.sequence)
        #expect((metadata.statusBits & SaturatedLoggingRing.overflowStatusBit) == SaturatedLoggingRing.overflowStatusBit)
        #expect(drainedSequences == [1, 2])
    }

    @Test func ringCanOverwriteOldestWhenConfigured() async throws {
        let ring = try SaturatedLoggingRing(capacity: 2, overflowPolicy: .overwriteOldest)

        try await ring.appendFromCPU(makePacket(sequence: 1))
        try await ring.appendFromCPU(makePacket(sequence: 2))
        try await ring.appendFromCPU(makePacket(sequence: 3))

        let drainedSequences = await ring.drain().map(\.sequence)
        #expect(drainedSequences == [2, 3])
    }

    @Test func snapshotUsesMetadataPlusFixedWidthSlots() async throws {
        let ring = try SaturatedLoggingRing(capacity: 2)
        try await ring.appendFromCPU(makePacket(sequence: 1))

        let snapshot = await ring.snapshotBinary()
        #expect(
            snapshot.count ==
            SaturatedLoggingRingMetadata.encodedLength + 2 * SaturatedHeartbeatPacket.extendedEncodedLength
        )
    }

    @Test func writeCombinePlanWaitsBelowThreshold() async throws {
        let ring = try SaturatedLoggingRing(capacity: 8)
        try await ring.appendFromCPU(makePacket(sequence: 1))
        try await ring.appendFromCPU(makePacket(sequence: 2))

        let plan = await ring.writeCombinePlan(
            policy: SaturatedWriteCombinePolicy(maxBatchSize: 4, flushThreshold: 3)
        )

        #expect(plan.availablePackets == 2)
        #expect(!plan.shouldFlush)
        #expect(plan.packetCount == 2)
        #expect(plan.remainingPackets == 0)
        #expect(plan.sequenceRange == 1...2)
    }

    @Test func writeCombinePlanFlushesAtThreshold() async throws {
        let ring = try SaturatedLoggingRing(capacity: 8)
        try await ring.appendFromCPU(makePacket(sequence: 1))
        try await ring.appendFromCPU(makePacket(sequence: 2))
        try await ring.appendFromCPU(makePacket(sequence: 3))
        try await ring.appendFromCPU(makePacket(sequence: 4))
        try await ring.appendFromCPU(makePacket(sequence: 5))

        let plan = await ring.writeCombinePlan(
            policy: SaturatedWriteCombinePolicy(maxBatchSize: 4, flushThreshold: 3)
        )

        #expect(plan.availablePackets == 5)
        #expect(plan.shouldFlush)
        #expect(plan.packetCount == 4)
        #expect(plan.remainingPackets == 1)
        #expect(plan.sequenceRange == 1...4)
    }

    @Test func flushWriteCombinedBatchProducesDeterministicMetadata() async throws {
        let ring = try SaturatedLoggingRing(capacity: 8)
        try await ring.appendFromCPU(makePacket(sequence: 10))
        try await ring.appendFromCPU(makePacket(sequence: 11))
        try await ring.appendFromCPU(makePacket(sequence: 12))

        let batch = try await ring.flushWriteCombinedBatch(
            policy: SaturatedWriteCombinePolicy(maxBatchSize: 4, flushThreshold: 3)
        )

        #expect(batch != nil)
        #expect(batch?.sequenceRange == 10...12)
        #expect(batch?.packetCount == 3)
        #expect(batch?.packetTypes == [.heartbeat, .heartbeat, .heartbeat])
        #expect(batch?.combinedHash.substrate == .cpuFallback)

        let metadata = await ring.metadata()
        #expect(metadata.consumerIndex == 3)
        #expect(metadata.producerIndex == 3)
    }

    @Test func flushWriteCombinedBatchReturnsNilWhenNoFlushNeeded() async throws {
        let ring = try SaturatedLoggingRing(capacity: 8)
        try await ring.appendFromCPU(makePacket(sequence: 1))

        let batch = try await ring.flushWriteCombinedBatch(
            policy: SaturatedWriteCombinePolicy(maxBatchSize: 4, flushThreshold: 3)
        )

        #expect(batch == nil)
        let remaining = await ring.drain()
        #expect(remaining.map(\.sequence) == [1])
    }

    #if canImport(Metal)
    @Test func probeShaderCompilesWhenMetalDeviceExists() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Swift Testing uses issue recording/skipping.
            // For now, we skip via return if device is nil.
            return 
        }

        let compression = MetalBlake3Compression()
        #expect(try compression.compileProbeLibrary(device: device) == .shaderLibraryCompiled)
    }
    #endif

    @Test func planBatchDrainWithNoPackets() async throws {
        let ring = try SaturatedLoggingRing(capacity: 4)
        
        let plan = await ring.planBatchDrain()
        #expect(plan.packetCount == 0)
        #expect(plan.flushReason == .noMorePackets)
        #expect(plan.estimatedByteSize == SaturatedLoggingRingMetadata.encodedLength)
    }

    @Test func planBatchDrainWithSinglePacket() async throws {
        let ring = try SaturatedLoggingRing(capacity: 4)
        try await ring.appendFromCPU(makePacket(sequence: 1))

        let plan = await ring.planBatchDrain()
        #expect(plan.packetCount == 1)
        #expect(plan.startIndex == 0)
        #expect(plan.endIndex == 1)
        #expect(plan.flushReason == .noMorePackets)
        #expect(plan.firstSequence == 1)
        #expect(plan.lastSequence == 1)
    }

    @Test func planBatchDrainRespectsDrainLimit() async throws {
        let ring = try SaturatedLoggingRing(capacity: 10)
        for i in 1...5 {
            try await ring.appendFromCPU(makePacket(sequence: UInt32(i)))
        }

        let plan = await ring.planBatchDrain(drainLimit: 3)
        #expect(plan.packetCount == 3)
        #expect(plan.flushReason == .drainLimit)
        #expect(plan.firstSequence == 1)
        #expect(plan.lastSequence == 3)
    }

    @Test func planBatchDrainCalculatesCorrectByteSize() async throws {
        let ring = try SaturatedLoggingRing(capacity: 10)
        try await ring.appendFromCPU(makePacket(sequence: 1))

        let plan = await ring.planBatchDrain()
        let expectedSize = SaturatedLoggingRingMetadata.encodedLength + SaturatedHeartbeatPacket.extendedEncodedLength
        #expect(plan.estimatedByteSize == expectedSize)
    }

    @Test func writeCombineBufferPlanBatchWithinThreshold() async throws {
        let wcb = WriteCombineBuffer(sizeThresholdBytes: 512)
        
        let batch = wcb.planBatch(
            availableCount: 100,
            consumerIndex: 0,
            packetSize: 72,
            metadataSize: 32,
            drainLimit: nil,
            firstSequenceIfAvailable: 1,
            lastSequenceIfAvailable: 100
        )
        
        #expect(batch.packetCount > 0)
        #expect(batch.packetCount < 100) // Should be limited by threshold
        #expect(batch.startIndex == 0)
        #expect(batch.flushReason == .sizeThreshold)
    }

    @Test func writeCombineBufferRespectsDrainLimit() async throws {
        let wcb = WriteCombineBuffer(sizeThresholdBytes: 2048)
        
        let batch = wcb.planBatch(
            availableCount: 100,
            consumerIndex: 0,
            packetSize: 72,
            metadataSize: 32,
            drainLimit: 5,
            firstSequenceIfAvailable: 1,
            lastSequenceIfAvailable: 100
        )
        
        #expect(batch.packetCount == 5)
        #expect(batch.flushReason == .drainLimit)
        #expect(batch.endIndex == 5)
    }

    @Test func writeCombineBufferShouldFlushThreshold() async throws {
        let wcb = WriteCombineBuffer(sizeThresholdBytes: 256)
        
        #expect(wcb.shouldFlush(currentBatchSize: 100, packetSize: 200))
        #expect(!wcb.shouldFlush(currentBatchSize: 100, packetSize: 50))
    }

    @Test func planBatchDrainSequenceTracking() async throws {
        let ring = try SaturatedLoggingRing(capacity: 8)
        try await ring.appendFromCPU(makePacket(sequence: 10))
        try await ring.appendFromCPU(makePacket(sequence: 20))
        try await ring.appendFromCPU(makePacket(sequence: 30))

        let plan = await ring.planBatchDrain()
        #expect(plan.packetCount == 3)
        #expect(plan.firstSequence == 10)
        #expect(plan.lastSequence == 30)
    }

    @Test func planBatchDrainConsistentBetweenCalls() async throws {
        let ring = try SaturatedLoggingRing(capacity: 8)
        try await ring.appendFromCPU(makePacket(sequence: 100))
        try await ring.appendFromCPU(makePacket(sequence: 101))

        let plan1 = await ring.planBatchDrain()
        let plan2 = await ring.planBatchDrain()

        #expect(plan1.packetCount == plan2.packetCount)
        #expect(plan1.startIndex == plan2.startIndex)
        #expect(plan1.endIndex == plan2.endIndex)
        #expect(plan1.firstSequence == plan2.firstSequence)
    }

    private func makePacket(sequence: UInt32) -> SaturatedHeartbeatPacket {
        SaturatedHeartbeatPacket(
            missionID: UUID(uuidString: "00112233-4455-6677-8899-aabbccddeeff")!,
            packetType: .heartbeat,
            sequence: sequence,
            payloadHash: Array(repeating: UInt8(sequence), count: SaturatedHeartbeatPacket.hashLength),
            timestamp: 1_700_000_000 + UInt64(sequence)
        )
    }

    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256Hex(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }
}