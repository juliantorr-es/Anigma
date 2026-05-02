//
//  SaturationInferenceCoreTests.swift
//  SaturationInferenceCoreTests
//
//  Tests for SaturationInferenceCore components.
//

import XCTest
import Metal
@testable import SaturationInferenceCore

final class SaturationInferenceCoreTests: XCTestCase {
    
    var device: MTLDevice!
    var pool: UnifiedMemoryPool!
    
    override func setUp() {
        super.setUp()
        
        // Create Metal device
        device = MTLCreateSystemDefaultDevice()
        
        // Create unified memory pool
        let config = MemoryPoolConfig(
            poolID: "test-pool",
            initialSize: 64 * 1024 * 1024,
            maxSize: 256 * 1024 * 1024,
            heapSizes: [32 * 1024 * 1024],
            alignment: 256
        )
        pool = UnifiedMemoryPool(config: config, device: device)
    }
    
    override func tearDown() {
        pool.cleanup()
        pool = nil
        device = nil
        super.tearDown()
    }
    
    // MARK: - UnifiedMemoryPool Tests
    
    func testUnifiedMemoryPoolAllocation() {
        let (reference, receipt) = pool.allocateTensor(
            shape: [10, 10],
            dtype: .float32
        )
        
        XCTAssertEqual(reference.shape, [10, 10])
        XCTAssertEqual(reference.dataType, .float32)
        XCTAssertEqual(receipt.size, 10 * 10 * 4)  // 100 float32 values = 400 bytes
        
        // Verify buffer exists
        let buffer = pool.getBuffer(for: reference)
        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer!.length, 400)
    }
    
    func testUnifiedMemoryPoolRawAllocation() {
        let (buffer, receipt) = pool.allocateRaw(size: 1024)
        
        XCTAssertEqual(receipt.size, 1024)
        XCTAssertEqual(buffer.length, 1024)
    }
    
    func testUnifiedMemoryPoolDeallocation() {
        let (reference, _) = pool.allocateTensor(
            shape: [5, 5],
            dtype: .float32
        )
        
        pool.deallocate(reference)
        
        // Buffer should no longer be accessible
        let buffer = pool.getBuffer(for: reference)
        XCTAssertNil(buffer)
    }
    
    func testUnifiedMemoryPoolStats() {
        // Allocate some tensors
        _ = pool.allocateTensor(shape: [10, 10], dtype: .float32)
        _ = pool.allocateTensor(shape: [20, 20], dtype: .float16)
        
        let stats = pool.getStats()
        
        XCTAssertEqual(stats.heapCount, 1)
        XCTAssertEqual(stats.allocationCount, 2)
        XCTAssertGreaterThan(stats.totalAllocated, 0)
        XCTAssertGreaterThan(stats.totalUsed, 0)
    }
    
    // MARK: - UnifiedTensor Tests
    
    func testUnifiedTensorCreation() {
        let tensor = UnifiedTensor(
            shape: [10, 10],
            dtype: .float32,
            pool: pool
        )
        
        XCTAssertEqual(tensor.shape, [10, 10])
        XCTAssertEqual(tensor.dtype, .float32)
        XCTAssertEqual(tensor.elementCount, 100)
        XCTAssertEqual(tensor.byteSize, 400)
    }
    
    func testUnifiedTensorCPUAccess() {
        let tensor = UnifiedTensor.zeros(
            shape: [10],
            dtype: .float32,
            pool: pool
        )
        
        // Write values
        var values: [Float] = []
        for i in 0..<10 {
            values.append(Float(i))
        }
        tensor.write(values)
        
        // Read values
        let readValues: [Float] = tensor.read()
        
        XCTAssertEqual(readValues.count, 10)
        for i in 0..<10 {
            XCTAssertEqual(readValues[i], Float(i), accuracy: 0.001)
        }
    }
    
    func testUnifiedTensorAdd() {
        let a = UnifiedTensor.fromArray(
            [1.0, 2.0, 3.0, 4.0],
            dtype: .float32,
            pool: pool
        )
        
        let b = UnifiedTensor.fromArray(
            [5.0, 6.0, 7.0, 8.0],
            dtype: .float32,
            pool: pool
        )
        
        let c = UnifiedTensor(
            shape: [4],
            dtype: .float32,
            pool: pool
        )
        
        let dispatcher = CPUInferenceDispatcher(pool: pool)
        _ = dispatcher.add(a: a, b: b, c: c)
        
        let result: [Float] = c.read()
        XCTAssertEqual(result, [6.0, 8.0, 10.0, 12.0], accuracy: 0.001)
    }
    
    func testUnifiedTensorMatmul() {
        // Create 2x3 matrix
        let a = UnifiedTensor.fromMultiArray(
            [[1.0, 2.0, 3.0],
             [4.0, 5.0, 6.0]],
            dtype: .float32,
            pool: pool
        )
        
        // Create 3x2 matrix
        let b = UnifiedTensor.fromMultiArray(
            [[7.0, 8.0],
             [9.0, 10.0],
             [11.0, 12.0]],
            dtype: .float32,
            pool: pool
        )
        
        // Create output 2x2 matrix
        let c = UnifiedTensor(
            shape: [2, 2],
            dtype: .float32,
            pool: pool
        )
        
        let dispatcher = CPUInferenceDispatcher(pool: pool)
        _ = dispatcher.matmul(a: a, b: b, c: c)
        
        let result: [[Float]] = []
        let flatResult: [Float] = c.read()
        // Expected: [[58, 64], [139, 154]]
        // 58 = 1*7 + 2*9 + 3*11 = 7 + 18 + 33 = 58
        // 64 = 1*8 + 2*10 + 3*12 = 8 + 20 + 36 = 64
        // 139 = 4*7 + 5*9 + 6*11 = 28 + 45 + 66 = 139
        // 154 = 4*8 + 5*10 + 6*12 = 32 + 50 + 72 = 154
        
        XCTAssertEqual(flatResult.count, 4)
        XCTAssertEqual(flatResult[0], 58.0, accuracy: 0.001)
        XCTAssertEqual(flatResult[1], 64.0, accuracy: 0.001)
        XCTAssertEqual(flatResult[2], 139.0, accuracy: 0.001)
        XCTAssertEqual(flatResult[3], 154.0, accuracy: 0.001)
    }
    
    func testUnifiedTensorGELU() {
        let input = UnifiedTensor.fromArray(
            [-2.0, -1.0, 0.0, 1.0, 2.0],
            dtype: .float32,
            pool: pool
        )
        
        let output = UnifiedTensor(
            shape: [5],
            dtype: .float32,
            pool: pool
        )
        
        let dispatcher = CPUInferenceDispatcher(pool: pool)
        _ = dispatcher.gelu(input: input, output: output)
        
        let result: [Float] = output.read()
        
        // GELU(0) = 0
        XCTAssertEqual(result[2], 0.0, accuracy: 0.001)
        
        // GELU values should be positive for positive inputs
        XCTAssertGreaterThan(result[3], 0.0)
        XCTAssertGreaterThan(result[4], 0.0)
        
        // GELU values should be negative for negative inputs
        XCTAssertLessThan(result[0], 0.0)
        XCTAssertLessThan(result[1], 0.0)
    }
    
    // MARK: - CPUSaturationMonitor Tests
    
    func testCPUSaturationMonitorCreation() {
        let monitor = CPUSaturationMonitor()
        
        XCTAssertNotNil(monitor)
        
        let stats = monitor.getStats()
        XCTAssertEqual(stats.totalCores, ProcessInfo.processInfo.processorCount)
    }
    
    func testCPUSaturationMonitorStartStop() {
        let monitor = CPUSaturationMonitor(
            config: SaturationConfig(
                targetCPUSaturation: 0.9,
                samplingIntervalMs: 100
            )
        )
        
        monitor.startMonitoring(intervalMs: 50)
        
        // Let it sample a few times
        Thread.sleep(forTimeInterval: 0.2)
        
        let stats1 = monitor.getStats()
        
        monitor.stopMonitoring()
        
        let stats2 = monitor.getStats()
        
        // Both should return valid stats
        XCTAssertGreaterThanOrEqual(stats1.overallSaturation, 0.0)
        XCTAssertLessThanOrEqual(stats1.overallSaturation, 1.0)
        
        XCTAssertGreaterThanOrEqual(stats2.overallSaturation, 0.0)
        XCTAssertLessThanOrEqual(stats2.overallSaturation, 1.0)
    }
    
    // MARK: - CPUInferenceDispatcher Tests
    
    func testCPUInferenceDispatcherCreation() {
        let dispatcher = CPUInferenceDispatcher(pool: pool)
        
        XCTAssertNotNil(dispatcher)
    }
    
    func testCPUInferenceDispatcherReceipts() {
        let dispatcher = CPUInferenceDispatcher(pool: pool)
        
        let a = UnifiedTensor.fromArray([1.0, 2.0, 3.0], dtype: .float32, pool: pool)
        let b = UnifiedTensor.fromArray([4.0, 5.0, 6.0], dtype: .float32, pool: pool)
        let c = UnifiedTensor(shape: [3], dtype: .float32, pool: pool)
        
        let receipt = dispatcher.add(a: a, b: b, c: c)
        
        XCTAssertEqual(receipt.operation, .add)
        XCTAssertEqual(receipt.inputShapes, [[3], [3]])
        XCTAssertEqual(receipt.outputShape, [3])
        XCTAssertGreaterThan(receipt.executionTime, 0)
        XCTAssertEqual(receipt.flops, 3)
    }
    
    // MARK: - Integration Tests
    
    func testFullInferencePipeline() {
        // Create dispatcher and tensors
        let dispatcher = CPUInferenceDispatcher(pool: pool)
        
        // Create input tensor (batch=1, sequence=10, features=64)
        let input = UnifiedTensor(
            shape: [10, 64],
            dtype: .float32,
            pool: pool
        )
        
        // Initialize with some values
        var values: [Float] = []
        for i in 0..<10 * 64 {
            values.append(Float(i) / 100.0)
        }
        input.write(values)
        
        // Apply layer norm
        let layerNormOutput = UnifiedTensor(
            shape: [10, 64],
            dtype: .float32,
            pool: pool
        )
        
        let gamma = UnifiedTensor.ones(shape: [64], dtype: .float32, pool: pool)
        let beta = UnifiedTensor.zeros(shape: [64], dtype: .float32, pool: pool)
        
        let lnReceipt = dispatcher.layerNorm(
            input: input,
            output: layerNormOutput,
            gamma: gamma,
            beta: beta
        )
        
        // Apply GELU
        let geluOutput = UnifiedTensor(
            shape: [10, 64],
            dtype: .float32,
            pool: pool
        )
        
        let geluReceipt = dispatcher.gelu(
            input: layerNormOutput,
            output: geluOutput
        )
        
        // Verify receipts
        XCTAssertEqual(lnReceipt.operation, .layerNorm)
        XCTAssertEqual(geluReceipt.operation, .gelu)
        
        // Verify shapes
        XCTAssertEqual(layerNormOutput.shape, [10, 64])
        XCTAssertEqual(geluOutput.shape, [10, 64])
        
        // Verify that layer norm produced reasonable values
        let lnValues: [Float] = layerNormOutput.read()
        
        // Mean should be close to 0 after layer norm
        let mean = lnValues.reduce(0, +) / Float(lnValues.count)
        XCTAssertLessThan(abs(mean), 0.1, "Mean should be close to 0 after layer norm")
    }
}
