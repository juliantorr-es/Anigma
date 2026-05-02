//
//  TurboQuantKVCacheTests.swift
//  TurboQuantKVCacheTests
//
//  TD Task: td-sli-2026-4.2 - Implement Base KV Cache Structure
//  TD Task: td-sli-2026-4.3 - Add Quantization Layer
//
//  Compliance: 100% TD Doctrine compliant
//  - Tests for Tier 3 Executor components
//  - Tests all quantizer implementations
//  - Tests KV cache block management
//  - Tests prefix sharing
//

import Foundation
import InferenceContracts
import KVCacheContracts
import Metal
import SaturationInferenceCore
import Testing
import TurboQuantKVCache

// MARK: - Test Configuration

/// Test configuration for KV cache
private let testPool = UnifiedMemoryPool()
private let testModelId = SaturatedModelReference.ID("test-model")
private let testCacheId = KVCacheID("test-cache")

// MARK: - Quantizer Tests

@Suite("Quantizer Tests")
struct QuantizerTests {
    
    @Test("NoOp Quantizer - Compression")
    func testNoOpQuantizerCompression() throws {
        let pool = testPool
        let quantizer = NoOpQuantizer(pool: pool)
        
        let testData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let inputTensor = UnifiedTensor.fromArray(testData, dtype: .float32, pool: pool)
        
        let compressed = try quantizer.compress(inputTensor)
        
        #expect(compressed.shape == inputTensor.shape)
        #expect(compressed.dtype == inputTensor.dtype)
        #expect(compressed.elementCount == inputTensor.elementCount)
    }
    
    @Test("NoOp Quantizer - Decompression")
    func testNoOpQuantizerDecompression() throws {
        let pool = testPool
        let quantizer = NoOpQuantizer(pool: pool)
        
        let testData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let inputTensor = UnifiedTensor.fromArray(testData, dtype: .float32, pool: pool)
        
        let compressed = try quantizer.compress(inputTensor)
        let decompressed = try quantizer.decompress(compressed)
        
        let originalValues = inputTensor.read() as [Float]
        let resultValues = decompressed.read() as [Float]
        
        #expect(originalValues == resultValues)
    }
    
    @Test("NoOp Quantizer - Properties")
    func testNoOpQuantizerProperties() {
        let pool = testPool
        let quantizer = NoOpQuantizer(pool: pool)
        
        #expect(quantizer.compressionMode == .none)
        #expect(quantizer.compressionRatio == 1.0)
        #expect(quantizer.isLossy == false)
    }
    
    @Test("FP8 Quantizer - Properties")
    func testFP8QuantizerProperties() {
        let pool = testPool
        let quantizer = FP8Quantizer(pool: pool)
        
        #expect(quantizer.compressionMode == .fp8)
        #expect(quantizer.compressionRatio == 2.0)
        #expect(quantizer.isLossy == false)
    }
    
    @Test("INT8 Symmetric Quantizer - Properties")
    func testINT8SymmetricQuantizerProperties() {
        let pool = testPool
        let quantizer = INT8SymmetricQuantizer(pool: pool)
        
        #expect(quantizer.compressionMode == .int8Symmetric)
        #expect(quantizer.compressionRatio == 2.0)
        #expect(quantizer.isLossy == true)
    }
    
    @Test("INT4 Symmetric Quantizer - Properties")
    func testINT4SymmetricQuantizerProperties() {
        let pool = testPool
        let quantizer = INT4SymmetricQuantizer(pool: pool)
        
        #expect(quantizer.compressionMode == .int4Symmetric)
        #expect(quantizer.compressionRatio == 4.0)
        #expect(quantizer.isLossy == true)
    }
    
    @Test("INT2 Quantizer - Properties")
    func testINT2QuantizerProperties() {
        let pool = testPool
        let quantizer = INT2Quantizer(pool: pool)
        
        #expect(quantizer.compressionMode == .int2)
        #expect(quantizer.compressionRatio == 8.0)
        #expect(quantizer.isLossy == true)
    }
    
    @Test("TurboQuant Quantizer - Properties")
    func testTurboQuantQuantizerProperties() {
        let pool = testPool
        let quantizer = TurboQuantQuantizer(bits: 4, pool: pool)
        
        #expect(quantizer.compressionMode == .turboQuant(bits: 4))
        #expect(quantizer.compressionRatio == 4.0)
        #expect(quantizer.isLossy == true)
    }
    
    @Test("Coupled Quantization Quantizer - Properties")
    func testCoupledQuantizationQuantizerProperties() {
        let pool = testPool
        let quantizer = CoupledQuantizationQuantizer(pool: pool)
        
        #expect(quantizer.compressionMode == .coupledQuantization)
        #expect(quantizer.compressionRatio == 16.0)
        #expect(quantizer.isLossy == true)
    }
    
    @Test("Adaptive Quantizer - Properties")
    func testAdaptiveQuantizerProperties() {
        let pool = testPool
        let quantizer = AdaptiveQuantizer(bitRange: 2...8, pool: pool)
        
        if case let .adaptive(range) = quantizer.compressionMode {
            #expect(range.lowerBound == 2)
            #expect(range.upperBound == 8)
        } else {
            Issue.record("Adaptive quantizer mode mismatch")
        }
        #expect(quantizer.compressionRatio > 2.0)
        #expect(quantizer.isLossy == true)
    }
}

// MARK: - Quantizer Registry Tests

@Suite("Quantizer Registry Tests")
struct QuantizerRegistryTests {
    
    @Test("Get NoOp Quantizer")
    func testGetNoOpQuantizer() {
        let pool = testPool
        let quantizer = KVQuantizerRegistry.getQuantizer(for: .none, pool: pool)
        
        #expect(quantizer.compressionMode == .none)
    }
    
    @Test("Get FP8 Quantizer")
    func testGetFP8Quantizer() {
        let pool = testPool
        let quantizer = KVQuantizerRegistry.getQuantizer(for: .fp8, pool: pool)
        
        #expect(quantizer.compressionMode == .fp8)
    }
    
    @Test("Get INT8 Symmetric Quantizer")
    func testGetINT8SymmetricQuantizer() {
        let pool = testPool
        let quantizer = KVQuantizerRegistry.getQuantizer(for: .int8Symmetric, pool: pool)
        
        #expect(quantizer.compressionMode == .int8Symmetric)
    }
    
    @Test("Get INT4 Symmetric Quantizer")
    func testGetINT4SymmetricQuantizer() {
        let pool = testPool
        let quantizer = KVQuantizerRegistry.getQuantizer(for: .int4Symmetric, pool: pool)
        
        #expect(quantizer.compressionMode == .int4Symmetric)
    }
    
    @Test("Get TurboQuant Quantizer")
    func testGetTurboQuantQuantizer() {
        let pool = testPool
        let quantizer = KVQuantizerRegistry.getQuantizer(
            for: .turboQuant(bits: 4),
            pool: pool
        )
        
        if case let .turboQuant(bits) = quantizer.compressionMode {
            #expect(bits == 4)
        } else {
            Issue.record("TurboQuant quantizer mode mismatch")
        }
    }
    
    @Test("Get Coupled Quantization Quantizer")
    func testGetCoupledQuantizationQuantizer() {
        let pool = testPool
        let quantizer = KVQuantizerRegistry.getQuantizer(
            for: .coupledQuantization,
            pool: pool
        )
        
        #expect(quantizer.compressionMode == .coupledQuantization)
    }
    
    @Test("Get Quantizer Name")
    func testGetQuantizerName() {
        #expect(KVQuantizerRegistry.getQuantizerName(for: .none) == "NoOp")
        #expect(KVQuantizerRegistry.getQuantizerName(for: .fp8) == "FP8")
        #expect(KVQuantizerRegistry.getQuantizerName(for: .int8Symmetric) == "INT8_Symmetric")
        #expect(KVQuantizerRegistry.getQuantizerName(for: .int4Symmetric) == "INT4_Symmetric")
        #expect(KVQuantizerRegistry.getQuantizerName(for: .int2) == "INT2")
        
        let name = KVQuantizerRegistry.getQuantizerName(for: .turboQuant(bits: 4))
        #expect(name.contains("TurboQuant"))
        #expect(name.contains("4"))
    }
}

// MARK: - KV Cache Tests

@Suite("KV Cache Tests")
struct KVCacheTests {
    
    @Test("Create Cache")
    func testCreateCache() {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            config: .default,
            pool: testPool
        )
        
        #expect(cache.cacheId == testCacheId)
        #expect(cache.modelId == testModelId)
        #expect(cache.usedMemoryBytes == 0)
    }
    
    @Test("Create Sequence")
    func testCreateSequence() {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let sequence = cache.createSequence(sequenceId: "seq-1")
        
        #expect(sequence.sequenceId == "seq-1")
        #expect(sequence.modelId == testModelId)
        #expect(sequence.blockReferences.isEmpty)
        #expect(sequence.currentPosition == 0)
    }
    
    @Test("Get Sequence")
    func testGetSequence() {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let _ = cache.createSequence(sequenceId: "seq-1")
        
        let sequence = cache.getSequence("seq-1")
        #expect(sequence != nil)
        #expect(sequence?.sequenceId == "seq-1")
    }
    
    @Test("Allocate Block")
    func testAllocateBlock() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            config: .default,
            pool: testPool
        )
        
        let keyData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let valueData: [Float] = [5.0, 6.0, 7.0, 8.0]
        
        let (blockReference, receipt) = try cache.allocateBlock(
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 4,
            keyData: keyData,
            valueData: valueData,
            compressionMode: .none
        )
        
        #expect(blockReference.blockId.count > 0)
        #expect(blockReference.tokenCount == 4)
        #expect(blockReference.compressionMode == .none)
        #expect(receipt.blockId == blockReference.blockId)
        #expect(receipt.sequenceId == "seq-1")
    }
    
    @Test("Get Block")
    func testGetBlock() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let keyData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let valueData: [Float] = [5.0, 6.0, 7.0, 8.0]
        
        let (blockReference, _) = try cache.allocateBlock(
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 4,
            keyData: keyData,
            valueData: valueData
        )
        
        let block = cache.getBlock(blockReference.blockId)
        #expect(block != nil)
        #expect(block?.reference.blockId == blockReference.blockId)
    }
    
    @Test("Append to Sequence")
    func testAppendToSequence() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            config: .default,
            pool: testPool
        )
        
        let _ = cache.createSequence(sequenceId: "seq-1")
        
        let keyData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let valueData: [Float] = [5.0, 6.0, 7.0, 8.0]
        
        let blockRefs = try cache.appendToSequence(
            sequenceId: "seq-1",
            keyData: keyData,
            valueData: valueData
        )
        
        #expect(blockRefs.count == 1)
        
        let sequence = cache.getSequence("seq-1")
        #expect(sequence?.blockReferences.count == 1)
        #expect(sequence?.currentPosition == 4)
    }
    
    @Test("Get Stats")
    func testGetStats() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let stats = cache.getStats()
        
        #expect(stats.cacheId == testCacheId)
        #expect(stats.modelId == testModelId)
        #expect(stats.totalBlocks == 0)
        #expect(stats.usedTokens == 0)
    }
    
    @Test("Clear Cache")
    func testClearCache() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let _ = cache.createSequence(sequenceId: "seq-1")
        
        let keyData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let valueData: [Float] = [5.0, 6.0, 7.0, 8.0]
        
        let _ = try cache.allocateBlock(
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 4,
            keyData: keyData,
            valueData: valueData
        )
        
        cache.clear()
        
        #expect(cache.usedMemoryBytes == 0)
        #expect(cache.blocks.isEmpty)
        #expect(cache.sequences.isEmpty)
    }
}

// MARK: - Compression Tests

@Suite("Compression Tests")
struct CompressionTests {
    
    @Test("Compress Block")
    func testCompressBlock() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let keyData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let valueData: [Float] = [5.0, 6.0, 7.0, 8.0]
        
        let (blockReference, _) = try cache.allocateBlock(
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 4,
            keyData: keyData,
            valueData: valueData,
            compressionMode: .none
        )
        
        let receipt = try cache.compressBlock(blockReference.blockId, mode: .fp8)
        
        #expect(receipt.blockId == blockReference.blockId)
        #expect(receipt.compressionMode == .fp8)
        #expect(receipt.originalSize > 0)
    }
    
    @Test("Decompress Block")
    func testDecompressBlock() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let keyData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let valueData: [Float] = [5.0, 6.0, 7.0, 8.0]
        
        let (blockReference, _) = try cache.allocateBlock(
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 4,
            keyData: keyData,
            valueData: valueData,
            compressionMode: .none
        )
        
        let _ = try cache.compressBlock(blockReference.blockId, mode: .fp8)
        
        let (decompressedKey, decompressedValue) = try cache.decompressBlock(blockReference.blockId)
        
        #expect(decompressedKey.elementCount == 4)
        #expect(decompressedValue.elementCount == 4)
    }
    
    @Test("Memory Pressure Check")
    func testMemoryPressure() {
        let config = KVCacheConfig(
            maxTokens: 1000,
            memoryBudgetBytes: 1024 * 1024,  // 1MB
            headroomFraction: 0.1
        )
        
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            config: config,
            pool: testPool
        )
        
        // With no allocations, should not be under pressure
        #expect(cache.isUnderMemoryPressure() == false)
        #expect(cache.getMemoryPressure() == 0.0)
    }
}

// MARK: - Prefix Sharing Tests

@Suite("Prefix Sharing Tests")
struct PrefixSharingTests {
    
    @Test("Check for Shareable Prefix - None")
    func testNoShareablePrefix() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let sequence1: [Int] = [1, 2, 3, 4, 5]
        let sequence2: [Int] = [6, 7, 8, 9, 10]
        
        let _ = cache.checkForShareablePrefix(
            sequenceId: "seq-1",
            tokens: sequence1
        )
        
        let result = cache.checkForShareablePrefix(
            sequenceId: "seq-2",
            tokens: sequence2
        )
        
        #expect(result == nil)
    }
    
    @Test("Check for Shareable Prefix - Partial")
    func testPartialShareablePrefix() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let sequence1: [Int] = [1, 2, 3, 4, 5]
        let sequence2: [Int] = [1, 2, 3, 8, 9]
        
        let _ = cache.checkForShareablePrefix(
            sequenceId: "seq-1",
            tokens: sequence1
        )
        
        let result = cache.checkForShareablePrefix(
            sequenceId: "seq-2",
            tokens: sequence2
        )
        
        #expect(result != nil)
        if let result = result {
            #expect(result.shareableTokenCount == 3)
        }
    }
    
    @Test("Check for Shareable Prefix - Full")
    func testFullShareablePrefix() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let sequence1: [Int] = [1, 2, 3, 4, 5]
        let sequence2: [Int] = [1, 2, 3, 4, 5, 6]
        
        let _ = cache.checkForShareablePrefix(
            sequenceId: "seq-1",
            tokens: sequence1
        )
        
        let result = cache.checkForShareablePrefix(
            sequenceId: "seq-2",
            tokens: sequence2
        )
        
        #expect(result != nil)
        if let result = result {
            #expect(result.shareableTokenCount == 5)
        }
    }
    
    @Test("Common Prefix Length")
    func testCommonPrefixLength() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let sequence1: [Int] = [1, 2, 3, 4, 5]
        let sequence2: [Int] = [1, 2, 3, 8, 9]
        
        let _ = cache.checkForShareablePrefix(
            sequenceId: "seq-1",
            tokens: sequence1
        )
        
        let _ = cache.checkForShareablePrefix(
            sequenceId: "seq-2",
            tokens: sequence2
        )
        
        let length = cache.getCommonPrefixLength(between: "seq-1", and: "seq-2")
        #expect(length == 3)
    }
}

// MARK: - Cache Tier Tests

@Suite("Cache Tier Tests")
struct CacheTierTests {
    
    @Test("GPU Cache Tier - Create")
    func testGPUCacheTierCreate() {
        let tier = GPUCacheTier(capacityBytes: 1024 * 1024, pool: testPool)
        
        #expect(tier.name == "GPU")
        #expect(tier.capacityBytes == 1024 * 1024)
        #expect(tier.usedBytes == 0)
        #expect(tier.hasCapacity == true)
    }
    
    @Test("CPU Cache Tier - Create")
    func testCPUCacheTierCreate() {
        let tier = CPUCacheTier(capacityBytes: 1024 * 1024, pool: testPool)
        
        #expect(tier.name == "CPU")
        #expect(tier.capacityBytes == 1024 * 1024)
        #expect(tier.usedBytes == 0)
        #expect(tier.hasCapacity == true)
    }
    
    @Test("CPU Cache Tier - Store and Retrieve")
    func testCPUCacheTierStoreRetrieve() throws {
        let tier = CPUCacheTier(capacityBytes: 1024 * 1024, pool: testPool)
        
        let data: [Float] = [1.0, 2.0, 3.0, 4.0]
        let tensor = UnifiedTensor.fromArray(data, dtype: .float32, pool: testPool)
        
        let location = try tier.storeTensor(tensor, blockId: "block-1")
        
        if case .cpu = location {
            // Expected
        } else {
            Issue.record("CPU cache tier returned wrong location type")
        }
        
        let retrieved = try tier.retrieveTensor(
            blockId: "block-1",
            shape: tensor.shape,
            dtype: tensor.dtype
        )
        
        #expect(retrieved.elementCount == tensor.elementCount)
    }
}

// MARK: - Radix Tree Tests

@Suite("Radix Tree Tests")
struct RadixTreeTests {
    
    @Test("Find Common Prefix Length")
    func testFindCommonPrefixLength() {
        let tree = RadixTree()
        
        let seq1: [Int] = [1, 2, 3, 4, 5]
        let seq2: [Int] = [1, 2, 3, 8, 9]
        
        tree.registerSequence("seq-1", tokens: seq1)
        tree.registerSequence("seq-2", tokens: seq2)
        
        let length = tree.findCommonPrefixLength(between: "seq-1", and: "seq-2")
        #expect(length == 3)
    }
    
    @Test("Find Shareable Prefix")
    func testFindShareablePrefix() {
        let tree = RadixTree()
        
        let seq1: [Int] = [1, 2, 3, 4, 5]
        
        tree.registerSequence("seq-1", tokens: seq1)
        
        let result = tree.findShareablePrefix(for: "seq-2", tokens: [1, 2, 3, 8, 9])
        
        #expect(result != nil)
        if let result = result {
            #expect(result.shareableSequenceId == "seq-1")
            #expect(result.shareableTokenCount == 3)
        }
    }
    
    @Test("Insert Sequence")
    func testInsertSequence() {
        let tree = RadixTree()
        
        let seq1: [Int] = [1, 2, 3]
        let blockRef = KVCacheBlockReference(
            blockId: "block-1",
            modelId: testModelId,
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 3,
            compressionMode: .none,
            compressedSizeBytes: 48,
            uncompressedSizeBytes: 48,
            storageLocation: .gpu(heapId: "heap-0", offset: 0)
        )
        
        tree.insertSequence("seq-1", tokens: seq1, blockReference: blockRef)
        
        let result = tree.findPrefixPath(for: [1, 2])
        #expect(result != nil)
        if let result = result {
            #expect(result.depth == 2)
        }
    }
    
    @Test("Has Prefix")
    func testHasPrefix() {
        let tree = RadixTree()
        
        let seq1: [Int] = [1, 2, 3]
        let blockRef = KVCacheBlockReference(
            blockId: "block-1",
            modelId: testModelId,
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 3,
            compressionMode: .none,
            compressedSizeBytes: 48,
            uncompressedSizeBytes: 48,
            storageLocation: .gpu(heapId: "heap-0", offset: 0)
        )
        
        tree.insertSequence("seq-1", tokens: seq1, blockReference: blockRef)
        
        #expect(tree.hasPrefix([1, 2]) == true)
        #expect(tree.hasPrefix([1, 2, 3]) == true)
        #expect(tree.hasPrefix([1, 2, 3, 4]) == false)
        #expect(tree.hasPrefix([5, 6]) == false)
    }
}

// MARK: - Sendable Conformance Tests

@Suite("Sendable Conformance Tests")
struct SendableConformanceTests {
    
    @Test("KVCache is Sendable")
    func testKVCacheSendable() {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        // This should compile if KVCache is Sendable
        let _: any Sendable = cache
    }
    
    @Test("KVCacheBlock is Sendable")
    func testKVCacheBlockSendable() throws {
        let cache = KVCache(
            cacheId: testCacheId,
            modelId: testModelId,
            pool: testPool
        )
        
        let keyData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let valueData: [Float] = [5.0, 6.0, 7.0, 8.0]
        
        let (blockReference, _) = try cache.allocateBlock(
            sequenceId: "seq-1",
            tokenStart: 0,
            tokenCount: 4,
            keyData: keyData,
            valueData: valueData
        )
        
        let block = cache.getBlock(blockReference.blockId)
        
        // This should compile if KVCacheBlock is Sendable
        let _: any Sendable = block
    }
    
    @Test("All Quantizers are Sendable")
    func testQuantizersSendable() {
        let pool = testPool
        
        let quantizers: [any KVQuantizerType] = [
            NoOpQuantizer(pool: pool),
            FP8Quantizer(pool: pool),
            INT8SymmetricQuantizer(pool: pool),
            INT8AsymmetricQuantizer(pool: pool),
            INT4SymmetricQuantizer(pool: pool),
            INT4AsymmetricQuantizer(pool: pool),
            INT2Quantizer(pool: pool),
            TurboQuantQuantizer(bits: 4, pool: pool),
            CoupledQuantizationQuantizer(pool: pool),
            AdaptiveQuantizer(bitRange: 2...8, pool: pool)
        ]
        
        for quantizer in quantizers {
            // This should compile if all quantizers are Sendable
            let _: any Sendable = quantizer
        }
    }
}
