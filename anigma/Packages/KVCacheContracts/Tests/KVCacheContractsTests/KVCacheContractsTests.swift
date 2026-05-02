//
//  KVCacheContractsTests.swift
//  KVCacheContractsTests
//
//  Tests for KV Cache Compression portable contracts
//
//  TD Task: td-sli-2026-4.1 - Design KV Cache Compression Architecture
//

import XCTest
import KVCacheContracts

final class KVCacheContractsTests: XCTestCase {

    // MARK: - Compression Mode Tests

    func testCompressionModeCompressionRatio() {
        // None should have ratio of 1.0 (no compression)
        XCTAssertEqual(KVCacheCompressionMode.none.compressionRatio, 1.0)
        
        // FP8: 2x compression (16 bits -> 8 bits)
        XCTAssertEqual(KVCacheCompressionMode.fp8.compressionRatio, 2.0)
        
        // INT8: 2x compression
        XCTAssertEqual(KVCacheCompressionMode.int8Asymmetric.compressionRatio, 2.0)
        XCTAssertEqual(KVCacheCompressionMode.int8Symmetric.compressionRatio, 2.0)
        
        // INT4: 4x compression
        XCTAssertEqual(KVCacheCompressionMode.int4Asymmetric.compressionRatio, 4.0)
        XCTAssertEqual(KVCacheCompressionMode.int4Symmetric.compressionRatio, 4.0)
        
        // INT2: 8x compression
        XCTAssertEqual(KVCacheCompressionMode.int2.compressionRatio, 8.0)
        
        // TurboQuant with 4 bits: 4x compression
        XCTAssertEqual(KVCacheCompressionMode.turboQuant(bits: 4).compressionRatio, 4.0)
        XCTAssertEqual(KVCacheCompressionMode.turboQuant(bits: 3).compressionRatio, 16.0 / 3.0)
        
        // Coupled Quantization: 16x (1 bit per channel)
        XCTAssertEqual(KVCacheCompressionMode.coupledQuantization.compressionRatio, 16.0)
        
        // Adaptive with range 4...8: uses lower bound (4 bits) = 4x
        XCTAssertEqual(KVCacheCompressionMode.adaptive(bitRange: 4...8).compressionRatio, 4.0)
    }

    func testCompressionModeBitsPerElement() {
        XCTAssertEqual(KVCacheCompressionMode.none.bitsPerElement, 16)
        XCTAssertEqual(KVCacheCompressionMode.fp8.bitsPerElement, 8)
        XCTAssertEqual(KVCacheCompressionMode.int8Asymmetric.bitsPerElement, 8)
        XCTAssertEqual(KVCacheCompressionMode.int8Symmetric.bitsPerElement, 8)
        XCTAssertEqual(KVCacheCompressionMode.int4Asymmetric.bitsPerElement, 4)
        XCTAssertEqual(KVCacheCompressionMode.int4Symmetric.bitsPerElement, 4)
        XCTAssertEqual(KVCacheCompressionMode.int2.bitsPerElement, 2)
        XCTAssertEqual(KVCacheCompressionMode.turboQuant(bits: 4).bitsPerElement, 4)
        XCTAssertEqual(KVCacheCompressionMode.coupledQuantization.bitsPerElement, 1)
        XCTAssertEqual(KVCacheCompressionMode.adaptive(bitRange: 4...8).bitsPerElement, 4)
    }

    func testCompressionModeIsQuantized() {
        XCTAssertFalse(KVCacheCompressionMode.none.isQuantized)
        XCTAssertTrue(KVCacheCompressionMode.fp8.isQuantized)
        XCTAssertTrue(KVCacheCompressionMode.int8Asymmetric.isQuantized)
        XCTAssertTrue(KVCacheCompressionMode.turboQuant(bits: 4).isQuantized)
    }

    func testCompressionModeIsLossy() {
        XCTAssertFalse(KVCacheCompressionMode.none.isLossy)
        XCTAssertFalse(KVCacheCompressionMode.fp8.isLossy)  // FP8 maintains fidelity
        XCTAssertTrue(KVCacheCompressionMode.int8Asymmetric.isLossy)
        XCTAssertTrue(KVCacheCompressionMode.int4Asymmetric.isLossy)
        XCTAssertTrue(KVCacheCompressionMode.int2.isLossy)
        XCTAssertTrue(KVCacheCompressionMode.turboQuant(bits: 4).isLossy)
        XCTAssertTrue(KVCacheCompressionMode.coupledQuantization.isLossy)
        XCTAssertTrue(KVCacheCompressionMode.adaptive(bitRange: 4...8).isLossy)
    }

    func testCompressionModeCaseIterable() {
        let allCases = KVCacheCompressionMode.allCases
        XCTAssertTrue(allCases.count >= 8)
        XCTAssertTrue(allCases.contains(.none))
        XCTAssertTrue(allCases.contains(.fp8))
        XCTAssertTrue(allCases.contains(.int4Asymmetric))
    }

    // MARK: - Storage Location Tests

    func testStorageLocationIsInFastMemory() {
        XCTAssertTrue(KVCacheStorageLocation.gpu(heapId: "heap-1", offset: 0).isInFastMemory)
        XCTAssertFalse(KVCacheStorageLocation.cpu(mmapPath: nil, offset: 0).isInFastMemory)
        XCTAssertFalse(KVCacheStorageLocation.disk(path: "/tmp/kv", offset: 0).isInFastMemory)
        XCTAssertFalse(KVCacheStorageLocation.remote(url: "http://", offset: 0).isInFastMemory)
        XCTAssertFalse(KVCacheStorageLocation.unallocated.isInFastMemory)
    }

    func testStorageLocationIsLocal() {
        XCTAssertTrue(KVCacheStorageLocation.gpu(heapId: "heap-1", offset: 0).isLocal)
        XCTAssertTrue(KVCacheStorageLocation.cpu(mmapPath: nil, offset: 0).isLocal)
        XCTAssertFalse(KVCacheStorageLocation.disk(path: "/tmp/kv", offset: 0).isLocal)
        XCTAssertFalse(KVCacheStorageLocation.remote(url: "http://", offset: 0).isLocal)
        XCTAssertFalse(KVCacheStorageLocation.unallocated.isLocal)
    }

    // MARK: - Config Tests

    func testKVCacheConfigDefault() {
        let config = KVCacheConfig.default
        
        XCTAssertEqual(config.maxTokens, 1_000_000)
        XCTAssertEqual(config.defaultCompression, .none)
        XCTAssertTrue(config.enablePrefixSharing)
        XCTAssertEqual(config.maxSequences, 100)
        XCTAssertEqual(config.blockSizeTokens, 1024)
        XCTAssertEqual(config.memoryBudgetBytes, 0)
        XCTAssertEqual(config.headroomFraction, 0.1)
        XCTAssertTrue(config.enableAutoCompression)
        XCTAssertEqual(config.targetCompressionRatio, 4.0)
    }

    func testKVCacheConfigFP8() {
        let config = KVCacheConfig.fp8
        
        XCTAssertEqual(config.defaultCompression, .fp8)
        XCTAssertFalse(config.enableAutoCompression)
        XCTAssertEqual(config.targetCompressionRatio, 2.0)
    }

    func testKVCacheConfigINT4() {
        let config = KVCacheConfig.int4
        
        XCTAssertEqual(config.defaultCompression, .int4Asymmetric)
        XCTAssertFalse(config.enableAutoCompression)
        XCTAssertEqual(config.targetCompressionRatio, 4.0)
    }

    func testKVCacheConfigTurboQuant() {
        let config = KVCacheConfig.turboQuant
        
        if case .turboQuant(let bits) = config.defaultCompression {
            XCTAssertEqual(bits, 4)
        } else {
            XCTFail("Expected turboQuant compression mode")
        }
        XCTAssertFalse(config.enableAutoCompression)
    }

    // MARK: - Block Reference Tests

    func testKVCacheBlockReferenceCompressionRatio() {
        let reference = KVCacheBlockReference(
            blockId: "block-1",
            modelId: "model-1",
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 100,
            compressionMode: .int4Asymmetric,
            compressedSizeBytes: 1000,
            uncompressedSizeBytes: 4000,
            storageLocation: .gpu(heapId: "heap-1", offset: 0)
        )
        
        XCTAssertEqual(reference.compressionRatio, 4.0)
    }

    func testKVCacheBlockReferenceZeroUncompressedSize() {
        let reference = KVCacheBlockReference(
            blockId: "block-1",
            modelId: "model-1",
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 0,
            compressionMode: .none,
            compressedSizeBytes: 0,
            uncompressedSizeBytes: 0,
            storageLocation: .unallocated
        )
        
        XCTAssertEqual(reference.compressionRatio, 1.0)
    }

    // MARK: - Sequence Reference Tests

    func testKVCacheSequenceReferenceTokenCount() {
        let blocks = [
            KVCacheBlockReference(
                blockId: "block-1",
                modelId: "model-1",
                sequenceId: "seq-1",
                tokenStart: 0,
                tokenCount: 100,
                compressionMode: .none,
                compressedSizeBytes: 2000,
                uncompressedSizeBytes: 2000,
                storageLocation: .unallocated
            ),
            KVCacheBlockReference(
                blockId: "block-2",
                modelId: "model-1",
                sequenceId: "seq-1",
                tokenStart: 100,
                tokenCount: 50,
                compressionMode: .none,
                compressedSizeBytes: 1000,
                uncompressedSizeBytes: 1000,
                storageLocation: .unallocated
            )
        ]
        
        let sequence = KVCacheSequenceReference(
            sequenceId: "seq-1",
            modelId: "model-1",
            blockReferences: blocks,
            currentPosition: 150,
            isComplete: false
        )
        
        XCTAssertEqual(sequence.tokenCount, 150)
    }

    // MARK: - Stats Tests

    func testKVCacheStatsCompressionRatio() {
        let stats = KVCacheStats(
            cacheId: "cache-1",
            modelId: "model-1",
            totalBlocks: 100,
            allocatedBlocks: 80,
            freeBlocks: 20,
            totalTokenCapacity: 100_000,
            usedTokens: 80_000,
            compressedSizeBytes: 10_000_000,
            uncompressedSizeBytes: 40_000_000,
            activeSequences: 10,
            sharedBlocks: 5,
            memoryByTier: [:],
            compressionStats: [:],
            blockSizeDistribution: [:]
        )
        
        XCTAssertEqual(stats.compressionRatio, 4.0)
        XCTAssertEqual(stats.utilization, 0.8)
        XCTAssertEqual(stats.memorySavingsBytes, 30_000_000)
        XCTAssertEqual(stats.memorySavingsPercentage, 75.0)
    }

    func testKVCacheStatsZeroUncompressed() {
        let stats = KVCacheStats(
            cacheId: "cache-1",
            modelId: "model-1",
            totalBlocks: 0,
            allocatedBlocks: 0,
            freeBlocks: 0,
            totalTokenCapacity: 0,
            usedTokens: 0,
            compressedSizeBytes: 0,
            uncompressedSizeBytes: 0,
            activeSequences: 0,
            sharedBlocks: 0,
            memoryByTier: [:],
            compressionStats: [:],
            blockSizeDistribution: [:]
        )
        
        XCTAssertEqual(stats.compressionRatio, 1.0)
        XCTAssertEqual(stats.utilization, 0.0)
        XCTAssertEqual(stats.memorySavingsPercentage, 0.0)
    }

    // MARK: - Compression Mode Stats Tests

    func testCompressionModeStatsRatio() {
        let stats = CompressionModeStats(
            blockCount: 100,
            compressedSizeBytes: 5_000_000,
            uncompressedSizeBytes: 20_000_000
        )
        
        XCTAssertEqual(stats.compressionRatio, 4.0)
    }

    func testCompressionModeStatsZeroUncompressed() {
        let stats = CompressionModeStats(
            blockCount: 0,
            compressedSizeBytes: 0,
            uncompressedSizeBytes: 0
        )
        
        XCTAssertEqual(stats.compressionRatio, 1.0)
    }

    // MARK: - Receipt Tests

    func testKVCacheCompressionReceipt() {
        let receipt = KVCacheCompressionReceipt(
            blockId: "block-1",
            compressionMode: .int4Asymmetric,
            originalSize: 10_000,
            compressedSize: 2_500,
            compressionTime: 0.001
        )
        
        XCTAssertEqual(receipt.blockId, "block-1")
        XCTAssertEqual(receipt.compressionMode, .int4Asymmetric)
        XCTAssertEqual(receipt.originalSize, 10_000)
        XCTAssertEqual(receipt.compressedSize, 2_500)
        XCTAssertEqual(receipt.compressionRatio, 4.0)
        XCTAssertEqual(receipt.compressionTime, 0.001)
    }

    func testKVCacheAllocationReceipt() {
        let receipt = KVCacheAllocationReceipt(
            blockId: "block-1",
            sequenceId: "seq-1",
            tokenCount: 1000,
            compressionMode: .fp8,
            storageLocation: .gpu(heapId: "heap-1", offset: 0),
            sizeBytes: 4000
        )
        
        XCTAssertEqual(receipt.blockId, "block-1")
        XCTAssertEqual(receipt.sequenceId, "seq-1")
        XCTAssertEqual(receipt.tokenCount, 1000)
        XCTAssertEqual(receipt.compressionMode, .fp8)
        XCTAssertEqual(receipt.sizeBytes, 4000)
    }

    // MARK: - Error Tests

    func testKVCacheErrorCases() {
        let errors: [KVCacheError] = [
            .cacheFull,
            .blockNotFound("block-1"),
            .sequenceNotFound("seq-1"),
            .compressionFailed(.int4Asymmetric),
            .decompressionFailed(.turboQuant(bits: 4)),
            .memoryBudgetExceeded,
            .invalidBlockSize,
            .generationMismatch(expected: 5, actual: 4),
            .storageUnavailable(.gpu(heapId: "heap-1", offset: 0)),
            .unsupportedCompressionMode(.custom("unknown"))
        ]
        
        XCTAssertEqual(errors.count, 10)
    }

    // MARK: - Codable Tests

    func testKVCacheCompressionModeCodable() throws {
        let mode = KVCacheCompressionMode.turboQuant(bits: 4)
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(KVCacheCompressionMode.self, from: data)
        
        XCTAssertEqual(mode, decoded)
    }

    func testKVCacheStorageLocationCodable() throws {
        let location = KVCacheStorageLocation.gpu(heapId: "heap-1", offset: 1000)
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(KVCacheStorageLocation.self, from: data)
        
        XCTAssertEqual(location, decoded)
    }

    func testKVCacheConfigCodable() throws {
        let config = KVCacheConfig.fp8
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(KVCacheConfig.self, from: data)
        
        XCTAssertEqual(config.maxTokens, decoded.maxTokens)
        XCTAssertEqual(config.defaultCompression, decoded.defaultCompression)
    }

    func testKVCacheBlockReferenceCodable() throws {
        let reference = KVCacheBlockReference(
            blockId: "block-1",
            modelId: "model-1",
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 100,
            compressionMode: .int4Asymmetric,
            compressedSizeBytes: 1000,
            uncompressedSizeBytes: 4000,
            storageLocation: .cpu(mmapPath: nil, offset: 0)
        )
        
        let data = try JSONEncoder().encode(reference)
        let decoded = try JSONDecoder().decode(KVCacheBlockReference.self, from: data)
        
        XCTAssertEqual(reference.blockId, decoded.blockId)
        XCTAssertEqual(reference.tokenCount, decoded.tokenCount)
        XCTAssertEqual(reference.compressionMode, decoded.compressionMode)
    }

    func testKVCacheStatsCodable() throws {
        let stats = KVCacheStats(
            cacheId: "cache-1",
            modelId: "model-1",
            totalBlocks: 100,
            allocatedBlocks: 80,
            freeBlocks: 20,
            totalTokenCapacity: 100_000,
            usedTokens: 80_000,
            compressedSizeBytes: 10_000_000,
            uncompressedSizeBytes: 40_000_000,
            activeSequences: 10,
            sharedBlocks: 5,
            memoryByTier: [.gpu(heapId: "heap-1", offset: 0): 5_000_000],
            compressionStats: [.int4Asymmetric: CompressionModeStats(
                blockCount: 50,
                compressedSizeBytes: 5_000_000,
                uncompressedSizeBytes: 20_000_000
            )],
            blockSizeDistribution: [1024: 50, 512: 30]
        )
        
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(KVCacheStats.self, from: data)
        
        XCTAssertEqual(stats.cacheId, decoded.cacheId)
        XCTAssertEqual(stats.usedTokens, decoded.usedTokens)
        XCTAssertEqual(stats.compressionRatio, decoded.compressionRatio, accuracy: 0.001)
    }

    // MARK: - Hashable Tests

    func testKVCacheCompressionModeHashable() {
        let mode1 = KVCacheCompressionMode.int4Asymmetric
        let mode2 = KVCacheCompressionMode.int4Asymmetric
        let mode3 = KVCacheCompressionMode.fp8
        
        XCTAssertEqual(mode1.hashValue, mode2.hashValue)
        XCTAssertNotEqual(mode1.hashValue, mode3.hashValue)
    }

    func testKVCacheStorageLocationHashable() {
        let loc1 = KVCacheStorageLocation.gpu(heapId: "heap-1", offset: 0)
        let loc2 = KVCacheStorageLocation.gpu(heapId: "heap-1", offset: 0)
        let loc3 = KVCacheStorageLocation.gpu(heapId: "heap-2", offset: 0)
        
        XCTAssertEqual(loc1.hashValue, loc2.hashValue)
        XCTAssertNotEqual(loc1.hashValue, loc3.hashValue)
    }

    // MARK: - Sendable Tests

    func testAllTypesAreSendable() {
        // These should compile without errors
        let _: any Sendable = KVCacheCompressionMode.none
        let _: any Sendable = KVCacheStorageLocation.unallocated
        let _: any Sendable = KVCacheConfig.default
        let _: any Sendable = KVCacheBlockReference(
            blockId: "test",
            modelId: "test",
            sequenceId: "test",
            tokenStart: 0,
            tokenCount: 0,
            compressionMode: .none,
            compressedSizeBytes: 0,
            uncompressedSizeBytes: 0,
            storageLocation: .unallocated
        )
        let _: any Sendable = KVCacheStats(
            cacheId: "test",
            modelId: "test",
            totalBlocks: 0,
            allocatedBlocks: 0,
            freeBlocks: 0,
            totalTokenCapacity: 0,
            usedTokens: 0,
            compressedSizeBytes: 0,
            uncompressedSizeBytes: 0,
            activeSequences: 0,
            sharedBlocks: 0,
            memoryByTier: [:],
            compressionStats: [:],
            blockSizeDistribution: [:]
        )
    }
}
