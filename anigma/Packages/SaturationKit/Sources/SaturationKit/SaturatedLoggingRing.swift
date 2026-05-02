import Foundation
import AnigmaNativeShims

#if canImport(Metal)
@preconcurrency import Metal
#endif

public enum SaturatedLoggingRingError: Error, Equatable, Sendable {
    case invalidCapacity(Int)
    case ringFull
    case packetTooShort(Int)
    case unknownPacketType(UInt32)
    case memoryAllocationFailed
}

public enum SaturatedLoggingRingOverflowPolicy: Sendable, Equatable {
    case haltProducer
    case overwriteOldest
}

public struct SaturatedWriteCombinePolicy: Sendable, Equatable {
    public let maxBatchSize: Int
    public let flushThreshold: Int

    public init(maxBatchSize: Int, flushThreshold: Int) {
        self.maxBatchSize = maxBatchSize
        self.flushThreshold = flushThreshold
    }
}

public struct SaturatedWriteCombineBatch: Sendable, Equatable {
    public let sequenceRange: ClosedRange<UInt32>
    public let packetCount: Int
    public let packetTypes: [SaturatedHeartbeatPacketType]
    public let combinedHash: SaturatedHeartbeatPayloadHash

    public init(
        sequenceRange: ClosedRange<UInt32>,
        packetCount: Int,
        packetTypes: [SaturatedHeartbeatPacketType],
        combinedHash: SaturatedHeartbeatPayloadHash
    ) {
        self.sequenceRange = sequenceRange
        self.packetCount = packetCount
        self.packetTypes = packetTypes
        self.combinedHash = combinedHash
    }
}

public struct SaturatedWriteCombinePlan: Sendable, Equatable {
    public let availablePackets: Int
    public let shouldFlush: Bool
    public let packetCount: Int
    public let remainingPackets: Int
    public let sequenceRange: ClosedRange<UInt32>?

    public init(
        availablePackets: Int,
        shouldFlush: Bool,
        packetCount: Int,
        remainingPackets: Int,
        sequenceRange: ClosedRange<UInt32>?
    ) {
        self.availablePackets = availablePackets
        self.shouldFlush = shouldFlush
        self.packetCount = packetCount
        self.remainingPackets = remainingPackets
        self.sequenceRange = sequenceRange
    }
}

public struct SaturatedLoggingRingMetadata: Sendable, Equatable {
    public static let encodedLength = 32

    public let producerIndex: UInt32
    public let consumerIndex: UInt32
    public let ringSize: UInt32
    public let statusBits: UInt32

    public init(producerIndex: UInt32, consumerIndex: UInt32, ringSize: UInt32, statusBits: UInt32) {
        self.producerIndex = producerIndex
        self.consumerIndex = consumerIndex
        self.ringSize = ringSize
        self.statusBits = statusBits
    }

    public func canonicalBinaryEncoding() -> Data {
        var data = Data(capacity: Self.encodedLength)
        data.appendLittleEndian(producerIndex)
        data.appendLittleEndian(consumerIndex)
        data.appendLittleEndian(ringSize)
        data.appendLittleEndian(statusBits)
        // Add 16 bytes of padding to reach 32 bytes
        data.append(Data(repeating: 0, count: 16))
        return data
    }
}

public actor SaturatedLoggingRing {
    public static let overflowStatusBit: UInt32 = 1 << 0

    internal let capacity: Int
    private let overflowPolicy: SaturatedLoggingRingOverflowPolicy
    private var packets: [SaturatedHeartbeatPacket?]
    private var producerIndex: UInt32 = 0
    private var consumerIndex: UInt32 = 0
    private var statusBits: UInt32 = 0
    private let writeCombineBuffer: WriteCombineBuffer
    
    nonisolated(unsafe) internal let rawBuffer: UnsafeMutableRawBufferPointer?

    #if canImport(Metal)
    nonisolated(unsafe) internal let sharedBuffer: MTLBuffer?
    #endif

    public init(
        capacity: Int,
        overflowPolicy: SaturatedLoggingRingOverflowPolicy = .haltProducer
    ) throws {
        guard capacity > 0 else {
            throw SaturatedLoggingRingError.invalidCapacity(capacity)
        }

        self.capacity = capacity
        self.overflowPolicy = overflowPolicy
        self.packets = Array(repeating: nil, count: capacity)
        self.writeCombineBuffer = WriteCombineBuffer()
        
        let byteLength = SaturatedLoggingRingMetadata.encodedLength
            + capacity * SaturatedHeartbeatPacket.extendedEncodedLength
        
        let ptr = malloc(byteLength)
        guard let ptr = ptr else {
            throw SaturatedLoggingRingError.memoryAllocationFailed
        }
        self.rawBuffer = UnsafeMutableRawBufferPointer(start: ptr, count: byteLength)
        self.rawBuffer?.initializeMemory(as: UInt8.self, repeating: 0)
        
        // Initialize metadata in raw buffer
        let metadataPtr = ptr.assumingMemoryBound(to: anigma_evidence_ring_metadata_t.self)
        metadataPtr.pointee.ring_size = UInt32(capacity)

        #if canImport(Metal)
        self.sharedBuffer = nil
        #endif
    }

    #if canImport(Metal)
    public init(
        capacity: Int,
        device: MTLDevice,
        overflowPolicy: SaturatedLoggingRingOverflowPolicy = .haltProducer
    ) throws {
        guard capacity > 0 else {
            throw SaturatedLoggingRingError.invalidCapacity(capacity)
        }

        self.capacity = capacity
        self.overflowPolicy = overflowPolicy
        self.packets = Array(repeating: nil, count: capacity)
        self.writeCombineBuffer = WriteCombineBuffer()
        let byteLength = SaturatedLoggingRingMetadata.encodedLength
            + capacity * SaturatedHeartbeatPacket.extendedEncodedLength
        self.sharedBuffer = device.makeBuffer(length: byteLength, options: [.storageModeShared])
        self.rawBuffer = nil
        
        if let sharedBuffer {
            Self.write(metadata: SaturatedLoggingRingMetadata(
                producerIndex: 0,
                consumerIndex: 0,
                ringSize: UInt32(capacity),
                statusBits: 0
            ), to: sharedBuffer)
        }
    }

    public func metalBuffer() -> MTLBuffer? {
        writeMetadataToMetalBuffer()
        return sharedBuffer
    }
    #endif

    deinit {
        if let rawBuffer = rawBuffer {
            free(rawBuffer.baseAddress)
        }
    }

    public nonisolated func cEvidenceRing() -> anigma_evidence_ring_t {
        let basePtr: UnsafeMutableRawPointer
        #if canImport(Metal)
        if let sharedBuffer = sharedBuffer {
            basePtr = sharedBuffer.contents()
        } else if let rawBuffer = rawBuffer {
            basePtr = rawBuffer.baseAddress!
        } else {
            fatalError("SaturatedLoggingRing has no valid buffer")
        }
        #else
        basePtr = rawBuffer!.baseAddress!
        #endif

        let metadataPtr = basePtr.assumingMemoryBound(to: anigma_evidence_ring_metadata_t.self)
        let packetsPtr = basePtr.advanced(by: SaturatedLoggingRingMetadata.encodedLength)
            .assumingMemoryBound(to: anigma_evidence_packet_t.self)
        
        metadataPtr.pointee.ring_size = UInt32(capacity)
        
        return anigma_evidence_ring_t(metadata: metadataPtr, packets: packetsPtr)
    }

    public func metadata() -> SaturatedLoggingRingMetadata {
        syncFromSharedMemory()
        return SaturatedLoggingRingMetadata(
            producerIndex: producerIndex,
            consumerIndex: consumerIndex,
            ringSize: UInt32(capacity),
            statusBits: statusBits
        )
    }

    public func appendFromCPU(_ packet: SaturatedHeartbeatPacket) throws {
        syncFromSharedMemory()
        let unread = producerIndex &- consumerIndex
        if unread >= UInt32(capacity) {
            switch overflowPolicy {
            case .haltProducer:
                statusBits |= Self.overflowStatusBit
                writeMetadataToSharedMemory()
                throw SaturatedLoggingRingError.ringFull
            case .overwriteOldest:
                consumerIndex = producerIndex &- UInt32(capacity) &+ 1
                statusBits |= Self.overflowStatusBit
            }
        }

        let slot = Int(producerIndex % UInt32(capacity))
        packets[slot] = packet
        producerIndex = producerIndex &+ 1
        
        writeToSharedMemory(packet: packet, at: slot)
        writeMetadataToSharedMemory()
    }

    public func drain(limit: Int? = nil) -> [SaturatedHeartbeatPacket] {
        syncFromSharedMemory()
        let available = Int(producerIndex &- consumerIndex)
        let count = min(limit ?? available, available)
        guard count > 0 else { return [] }

        var drained: [SaturatedHeartbeatPacket] = []
        drained.reserveCapacity(count)
        for _ in 0..<count {
            let slot = Int(consumerIndex % UInt32(capacity))
            if let packet = packets[slot] {
                drained.append(packet)
            }
            packets[slot] = nil
            consumerIndex = consumerIndex &+ 1
        }
        
        writeMetadataToSharedMemory()
        return drained
    }

    public func planBatchDrain(drainLimit: Int? = nil) -> WriteCombineBatchMetadata {
        syncFromSharedMemory()
        
        let available = Int(producerIndex &- consumerIndex)
        var firstSequence: UInt32? = nil
        var lastSequence: UInt32? = nil
        
        if available > 0 {
            let countToCheck = min(drainLimit ?? available, available)
            for i in 0..<countToCheck {
                let absoluteIndex = consumerIndex &+ UInt32(i)
                let slot = Int(absoluteIndex % UInt32(capacity))
                if let packet = packets[slot] {
                    if firstSequence == nil {
                        firstSequence = packet.sequence
                    }
                    lastSequence = packet.sequence
                }
            }
        }
        
        return writeCombineBuffer.planBatch(
            availableCount: available,
            consumerIndex: consumerIndex,
            packetSize: SaturatedHeartbeatPacket.extendedEncodedLength,
            metadataSize: SaturatedLoggingRingMetadata.encodedLength,
            drainLimit: drainLimit,
            firstSequenceIfAvailable: firstSequence,
            lastSequenceIfAvailable: lastSequence
        )
    }

    public func writeCombinePlan(policy: SaturatedWriteCombinePolicy) -> SaturatedWriteCombinePlan {
        precondition(policy.maxBatchSize > 0, "maxBatchSize must be > 0")
        precondition(policy.flushThreshold > 0, "flushThreshold must be > 0")
        syncFromSharedMemory()

        let availablePackets = Int(producerIndex &- consumerIndex)
        let packetCount = min(availablePackets, policy.maxBatchSize)
        let shouldFlush = availablePackets >= policy.flushThreshold || availablePackets >= policy.maxBatchSize
        let remainingPackets = max(0, availablePackets - packetCount)

        let sequenceRange: ClosedRange<UInt32>?
        if packetCount > 0 {
            let start = packet(atAbsoluteIndex: consumerIndex)?.sequence ?? consumerIndex
            let endIndex = consumerIndex &+ UInt32(packetCount - 1)
            let end = packet(atAbsoluteIndex: endIndex)?.sequence ?? endIndex
            sequenceRange = start...end
        } else {
            sequenceRange = nil
        }

        return SaturatedWriteCombinePlan(
            availablePackets: availablePackets,
            shouldFlush: shouldFlush,
            packetCount: packetCount,
            remainingPackets: remainingPackets,
            sequenceRange: sequenceRange
        )
    }

    public func flushWriteCombinedBatch(
        policy: SaturatedWriteCombinePolicy
    ) throws -> SaturatedWriteCombineBatch? {
        let plan = writeCombinePlan(policy: policy)
        guard plan.shouldFlush, plan.packetCount > 0 else {
            return nil
        }

        let drained = drain(limit: plan.packetCount)
        guard let first = drained.first, let last = drained.last else {
            return nil
        }

        let packetTypes = drained.map(\.packetType)
        let combinedHash = try Self.combinedHash(for: drained)
        return SaturatedWriteCombineBatch(
            sequenceRange: first.sequence...last.sequence,
            packetCount: drained.count,
            packetTypes: packetTypes,
            combinedHash: combinedHash
        )
    }

    private func syncFromSharedMemory() {
        let basePtr: UnsafeMutableRawPointer
        #if canImport(Metal)
        if let sharedBuffer = sharedBuffer {
            basePtr = sharedBuffer.contents()
        } else if let rawBuffer = rawBuffer {
            basePtr = rawBuffer.baseAddress!
        } else {
            return
        }
        #else
        basePtr = rawBuffer!.baseAddress!
        #endif

        let metadataPointer = basePtr.assumingMemoryBound(to: UInt32.self)
        let gpuProducerIndex = metadataPointer[0]
        let gpuConsumerIndex = metadataPointer[1]
        let gpuStatusBits = metadataPointer[3]

        guard gpuProducerIndex != producerIndex || gpuConsumerIndex != consumerIndex || gpuStatusBits != statusBits else {
            return
        }

        let packetBase = basePtr.advanced(by: SaturatedLoggingRingMetadata.encodedLength)
        let readable = min(Int(gpuProducerIndex &- gpuConsumerIndex), capacity)
        for offset in 0..<readable {
            let absoluteIndex = gpuConsumerIndex &+ UInt32(offset)
            let slot = Int(absoluteIndex % UInt32(capacity))
            let packetOffset = slot * SaturatedHeartbeatPacket.extendedEncodedLength
            let packetData = Data(
                bytes: packetBase.advanced(by: packetOffset),
                count: SaturatedHeartbeatPacket.extendedEncodedLength
            )
            packets[slot] = try? SaturatedHeartbeatPacket(decoding: packetData)
        }

        producerIndex = gpuProducerIndex
        consumerIndex = gpuConsumerIndex
        statusBits = gpuStatusBits
    }

    private func writeMetadataToSharedMemory() {
        let meta = SaturatedLoggingRingMetadata(
            producerIndex: producerIndex,
            consumerIndex: consumerIndex,
            ringSize: UInt32(capacity),
            statusBits: statusBits
        )
        
        #if canImport(Metal)
        if let sharedBuffer = sharedBuffer {
            Self.write(metadata: meta, to: sharedBuffer)
        }
        #endif
        if let rawBuffer = rawBuffer {
            let encoded = meta.canonicalBinaryEncoding()
            encoded.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                rawBuffer.baseAddress!.copyMemory(
                    from: baseAddress,
                    byteCount: SaturatedLoggingRingMetadata.encodedLength
                )
            }
        }
    }

    private func writeToSharedMemory(packet: SaturatedHeartbeatPacket, at slot: Int) {
        let encoded = packet.canonicalBinaryEncoding()
        let packetOffset = SaturatedLoggingRingMetadata.encodedLength + slot * SaturatedHeartbeatPacket.extendedEncodedLength
        
        encoded.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            
            #if canImport(Metal)
            if let sharedBuffer = sharedBuffer {
                sharedBuffer.contents().advanced(by: packetOffset).copyMemory(
                    from: baseAddress,
                    byteCount: SaturatedHeartbeatPacket.extendedEncodedLength
                )
            }
            #endif
            
            if let rawBuffer = rawBuffer {
                rawBuffer.baseAddress!.advanced(by: packetOffset).copyMemory(
                    from: baseAddress,
                    byteCount: SaturatedHeartbeatPacket.extendedEncodedLength
                )
            }
        }
    }

    #if canImport(Metal)
    private static func write(metadata: SaturatedLoggingRingMetadata, to sharedBuffer: MTLBuffer) {
        let encoded = metadata.canonicalBinaryEncoding()
        encoded.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            sharedBuffer.contents().copyMemory(
                from: baseAddress,
                byteCount: SaturatedLoggingRingMetadata.encodedLength
            )
        }
    }

    private func writeMetadataToMetalBuffer() {
        guard let sharedBuffer else { return }
        Self.write(metadata: metadata(), to: sharedBuffer)
    }
    #endif

    public func snapshotBinary() -> Data {
        syncFromSharedMemory()
        var data = metadata().canonicalBinaryEncoding()
        for offset in 0..<capacity {
            let absoluteIndex = consumerIndex &+ UInt32(offset)
            let slot = Int(absoluteIndex % UInt32(capacity))
            if let packet = packets[slot] {
                data.append(packet.canonicalBinaryEncoding())
            } else {
                data.append(Data(repeating: 0, count: SaturatedHeartbeatPacket.extendedEncodedLength))
            }
        }
        return data
    }

    private func packet(atAbsoluteIndex absoluteIndex: UInt32) -> SaturatedHeartbeatPacket? {
        let slot = Int(absoluteIndex % UInt32(capacity))
        return packets[slot]
    }

    private static func combinedHash(
        for packets: [SaturatedHeartbeatPacket]
    ) throws -> SaturatedHeartbeatPayloadHash {
        var data = Data()
        data.reserveCapacity(packets.count * SaturatedHeartbeatPacket.extendedEncodedLength)
        for packet in packets {
            data.append(packet.canonicalBinaryEncoding())
        }
        return try SaturatedHeartbeatPacket.payloadHash(for: data, preferMetalDigest: false)
    }
}
