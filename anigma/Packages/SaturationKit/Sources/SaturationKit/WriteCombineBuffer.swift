import Foundation

/// Deterministic metadata for a batched drain operation.
/// Describes the planned batch boundaries and flush triggers.
public struct WriteCombineBatchMetadata: Sendable, Equatable {
    /// Index in the ring where this batch starts (inclusive).
    public let startIndex: UInt32
    
    /// Index in the ring where this batch ends (exclusive).
    public let endIndex: UInt32
    
    /// Number of packets in this batch.
    public let packetCount: UInt32
    
    /// Reason this batch was flushed.
    public let flushReason: FlushReason
    
    /// Byte size of the encoded batch (metadata + packets).
    public let estimatedByteSize: Int
    
    /// Sequence number of the first packet in the batch (if available).
    public let firstSequence: UInt32?
    
    /// Sequence number of the last packet in the batch (if available).
    public let lastSequence: UInt32?
    
    public enum FlushReason: String, Sendable, Equatable {
        /// Batch reaches size threshold.
        case sizeThreshold
        /// Drain call with explicit limit triggered the batch.
        case drainLimit
        /// Ring has no more packets available to batch.
        case noMorePackets
        /// Explicit flush requested.
        case explicit
    }
    
    public init(
        startIndex: UInt32,
        endIndex: UInt32,
        packetCount: UInt32,
        flushReason: FlushReason,
        estimatedByteSize: Int,
        firstSequence: UInt32?,
        lastSequence: UInt32?
    ) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.packetCount = packetCount
        self.flushReason = flushReason
        self.estimatedByteSize = estimatedByteSize
        self.firstSequence = firstSequence
        self.lastSequence = lastSequence
    }
}

/// Conservative write-combine buffer for batching heartbeat drain operations.
/// Accumulates packets and flushes according to size thresholds and explicit requests.
public struct WriteCombineBuffer: Sendable {
    /// Target maximum bytes per batch.
    /// Flushed when this size would be exceeded.
    private let sizeThresholdBytes: Int
    
    /// Initial capacity for the batch array (preallocated).
    private let initialCapacity: Int
    
    public init(
        sizeThresholdBytes: Int = 1024 * 32,
        initialCapacity: Int = 256
    ) {
        self.sizeThresholdBytes = sizeThresholdBytes
        self.initialCapacity = initialCapacity
    }
    
    /// Plan a deterministic batch from available ring packets.
    /// Returns batch metadata describing what would be drained and why.
    ///
    /// - Parameters:
    ///   - availableCount: Number of packets available in the ring.
    ///   - consumerIndex: Current consumer index in the ring.
    ///   - packetSize: Size of each encoded packet (e.g., SaturatedHeartbeatPacket.encodedLength).
    ///   - metadataSize: Size of ring metadata header.
    ///   - drainLimit: Optional explicit limit from drain() call.
    ///   - firstSequenceIfAvailable: First packet sequence if packets are available.
    ///   - lastSequenceIfAvailable: Last packet sequence if packets are available.
    ///
    /// - Returns: Batch metadata with planned boundaries and flush reason.
    public func planBatch(
        availableCount: Int,
        consumerIndex: UInt32,
        packetSize: Int,
        metadataSize: Int,
        drainLimit: Int? = nil,
        firstSequenceIfAvailable: UInt32? = nil,
        lastSequenceIfAvailable: UInt32? = nil
    ) -> WriteCombineBatchMetadata {
        guard availableCount > 0 else {
            // No packets available
            return WriteCombineBatchMetadata(
                startIndex: consumerIndex,
                endIndex: consumerIndex,
                packetCount: 0,
                flushReason: .noMorePackets,
                estimatedByteSize: metadataSize,
                firstSequence: nil,
                lastSequence: nil
            )
        }
        
        // If explicit drain limit provided, respect it
        if let limit = drainLimit {
            let count = min(limit, availableCount)
            let endIndex = consumerIndex &+ UInt32(count)
            let byteSize = metadataSize + (count * packetSize)
            return WriteCombineBatchMetadata(
                startIndex: consumerIndex,
                endIndex: endIndex,
                packetCount: UInt32(count),
                flushReason: .drainLimit,
                estimatedByteSize: byteSize,
                firstSequence: firstSequenceIfAvailable,
                lastSequence: lastSequenceIfAvailable
            )
        }
        
        // Calculate how many packets fit within size threshold
        _ = (metadataSize + packetSize) // Silencing unused variable warning
        let maxPacketsPerBatch = max(1, (sizeThresholdBytes - metadataSize) / packetSize)
        let packetsToBatch = min(maxPacketsPerBatch, availableCount)
        
        let endIndex = consumerIndex &+ UInt32(packetsToBatch)
        let byteSize = metadataSize + (packetsToBatch * packetSize)
        let flushReason: WriteCombineBatchMetadata.FlushReason = 
            packetsToBatch < availableCount ? .sizeThreshold : .noMorePackets
        
        return WriteCombineBatchMetadata(
            startIndex: consumerIndex,
            endIndex: endIndex,
            packetCount: UInt32(packetsToBatch),
            flushReason: flushReason,
            estimatedByteSize: byteSize,
            firstSequence: firstSequenceIfAvailable,
            lastSequence: lastSequenceIfAvailable
        )
    }
    
    /// Determine if a batch should flush before adding another packet.
    /// Returns true if adding a packet would exceed the size threshold.
    ///
    /// - Parameters:
    ///   - currentBatchSize: Current accumulated byte size (including metadata).
    ///   - packetSize: Size of the packet to potentially add.
    ///
    /// - Returns: True if flush needed to stay within threshold.
    public func shouldFlush(currentBatchSize: Int, packetSize: Int) -> Bool {
        currentBatchSize + packetSize > sizeThresholdBytes
    }
}
