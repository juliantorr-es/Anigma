//
//  InferenceContractsTests.swift
//  InferenceContractsTests
//
//  Tests for portable inference contracts.
//

import XCTest
import InferenceContracts

final class InferenceContractsTests: XCTestCase {
    
    func testTensorDataTypeByteSizes() {
        XCTAssertEqual(TensorDataType.float32.byteSize, 4)
        XCTAssertEqual(TensorDataType.float16.byteSize, 2)
        XCTAssertEqual(TensorDataType.float8.byteSize, 1)
        XCTAssertEqual(TensorDataType.bfloat16.byteSize, 2)
        XCTAssertEqual(TensorDataType.int8.byteSize, 1)
        XCTAssertEqual(TensorDataType.int4.byteSize, 1)
        XCTAssertEqual(TensorDataType.int32.byteSize, 4)
        XCTAssertEqual(TensorDataType.uint8.byteSize, 1)
    }
    
    func testKVCacheCompressionRatios() {
        XCTAssertEqual(KVCacheCompressionMode.disabled.compressionRatio, 1.0)
        XCTAssertEqual(KVCacheCompressionMode.int8Symmetric.compressionRatio, 2.0)
        XCTAssertEqual(KVCacheCompressionMode.int8Asymmetric.compressionRatio, 2.0)
        XCTAssertEqual(KVCacheCompressionMode.int4Symmetric.compressionRatio, 4.0)
        XCTAssertEqual(KVCacheCompressionMode.int4Asymmetric.compressionRatio, 4.0)
        XCTAssertEqual(KVCacheCompressionMode.adaptive.compressionRatio, 3.0)
    }
    
    func testUnifiedTensorReferenceCodable() throws {
        let reference = UnifiedTensorReference(
            id: "test-tensor",
            shape: [1, 2, 3],
            dataType: .float32,
            memoryPoolID: "pool-1",
            offset: 100,
            stride: [3, 2, 1]
        )
        
        let data = try JSONEncoder().encode(reference)
        let decoded = try JSONDecoder().decode(UnifiedTensorReference.self, from: data)
        
        XCTAssertEqual(reference.id, decoded.id)
        XCTAssertEqual(reference.shape, decoded.shape)
        XCTAssertEqual(reference.dataType, decoded.dataType)
        XCTAssertEqual(reference.memoryPoolID, decoded.memoryPoolID)
        XCTAssertEqual(reference.offset, decoded.offset)
        XCTAssertEqual(reference.stride, decoded.stride)
    }
    
    func testMemoryPoolConfigDefault() {
        let config = MemoryPoolConfig.default
        
        XCTAssertEqual(config.poolID, "default")
        XCTAssertEqual(config.initialSize, 256 * 1024 * 1024)
        XCTAssertEqual(config.maxSize, 2 * 1024 * 1024 * 1024)
        XCTAssertEqual(config.heapSizes, [64 * 1024 * 1024, 128 * 1024 * 1024, 256 * 1024 * 1024])
        XCTAssertEqual(config.alignment, 256)
    }
    
    func testSaturationConfigDefault() {
        let config = SaturationConfig.default
        
        XCTAssertEqual(config.targetCPUSaturation, 0.95)
        XCTAssertEqual(config.targetGPUSaturation, 0.95)
        XCTAssertEqual(config.targetANESaturation, 0.90)
        XCTAssertEqual(config.samplingIntervalMs, 100)
        XCTAssertEqual(config.backpressureThreshold, 0.85)
    }
    
    func testSaturatedModelReference() {
        let model = SaturatedModelReference(
            id: "test-model",
            modelHash: "abc123",
            parameterCount: 7000000000,
            quantized: true,
            quantizationBits: 4,
            predigested: true,
            memoryEstimate: 15 * 1024 * 1024 * 1024
        )
        
        XCTAssertEqual(model.id, "test-model")
        XCTAssertEqual(model.modelHash, "abc123")
        XCTAssertEqual(model.parameterCount, 7000000000)
        XCTAssertTrue(model.quantized)
        XCTAssertEqual(model.quantizationBits, 4)
        XCTAssertTrue(model.predigested)
        XCTAssertEqual(model.memoryEstimate, 15 * 1024 * 1024 * 1024)
    }
    
    func testInferencePhaseCodable() throws {
        let prefill = InferencePhase.prefill
        let decode = InferencePhase.decode
        
        let prefillData = try JSONEncoder().encode(prefill)
        let decodedPrefill = try JSONDecoder().decode(InferencePhase.self, from: prefillData)
        XCTAssertEqual(prefill, decodedPrefill)
        
        let decodeData = try JSONEncoder().encode(decode)
        let decodedDecode = try JSONDecoder().decode(InferencePhase.self, from: decodeData)
        XCTAssertEqual(decode, decodedDecode)
    }
    
    func testComputeUnitPreferenceCodable() throws {
        let allCases: [ComputeUnitPreference] = [
            .any, .cpuOnly, .gpuPreferred, .gpuOnly, .anePreferred, .aneOnly
        ]
        
        for preference in allCases {
            let data = try JSONEncoder().encode(preference)
            let decoded = try JSONDecoder().decode(ComputeUnitPreference.self, from: data)
            XCTAssertEqual(preference, decoded)
        }
    }
    
    func testSaturatedInferenceConfigDefault() {
        let config = SaturatedInferenceConfig()
        
        XCTAssertEqual(config.phase, .prefill)
        XCTAssertEqual(config.kvCacheConfig.maxTokens, 4096)
        XCTAssertEqual(config.saturationConfig.targetCPUSaturation, 0.95)
        XCTAssertEqual(config.computeUnitPreference, .any)
        XCTAssertNil(config.numThreads)
        XCTAssertNil(config.batchSize)
    }
}
