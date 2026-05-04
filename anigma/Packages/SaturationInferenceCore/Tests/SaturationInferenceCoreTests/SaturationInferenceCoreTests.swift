//
//  SaturationInferenceCoreTests.swift
//  SaturationInferenceCoreTests
//
//  Tests for SaturationInferenceCore components.
//  Migrated to Swift Testing framework.
//

import Testing
import Metal
import InferenceContracts
import AnigmaTestSupport
@testable import SaturationInferenceCore

// Test fixture for setup/teardown
struct SaturationInferenceCoreFixture {
    var device: MTLDevice
    var pool: UnifiedMemoryPool
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.deviceCreationFailed
        }
        self.device = device
        
        let config = MemoryPoolConfig(
            poolID: "test-pool",
            initialSize: 64 * 1024 * 1024,
            maxSize: 256 * 1024 * 1024,
            heapSizes: [32 * 1024 * 1024],
            alignment: 256
        )
        self.pool = UnifiedMemoryPool(config: config, device: device)
    }
    
    mutating func cleanup() {
        pool.cleanup()
    }
}

enum TestError: Error {
    case deviceCreationFailed
}

@Suite("SaturationInferenceCore Tests")
struct SaturationInferenceCoreTests {
    
    // MARK: - UnifiedMemoryPool Tests
    
    @Test("UnifiedMemoryPool allocation")
    func testUnifiedMemoryPoolAllocation() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let (reference, receipt) = fixture.pool.allocateTensor(
            shape: [10, 10],
            dtype: .float32
        )
        
        #expect(reference.shape == [10, 10])
        #expect(reference.dataType == .float32)
        #expect(receipt.size == 10 * 10 * 4)  // 100 float32 values = 400 bytes
        
        // Verify buffer exists
        let buffer = fixture.pool.getBuffer(for: reference)
        #expect(buffer != nil)
        #expect(buffer!.length == 400)
    }
    
    @Test("UnifiedMemoryPool raw allocation")
    func testUnifiedMemoryPoolRawAllocation() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let (buffer, receipt) = fixture.pool.allocateRaw(size: 1024)
        
        #expect(receipt.size == 1024)
        #expect(buffer.length == 1024)
    }
    
    @Test("UnifiedMemoryPool deallocation")
    func testUnifiedMemoryPoolDeallocation() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let (reference, _) = fixture.pool.allocateTensor(
            shape: [5, 5],
            dtype: .float32
        )
        
        fixture.pool.deallocate(reference)
        
        // Buffer should no longer be accessible
        let buffer = fixture.pool.getBuffer(for: reference)
        #expect(buffer == nil)
    }
    
    @Test("UnifiedMemoryPool stats")
    func testUnifiedMemoryPoolStats() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        // Allocate some tensors
        _ = fixture.pool.allocateTensor(shape: [10, 10], dtype: .float32)
        _ = fixture.pool.allocateTensor(shape: [20, 20], dtype: .float16)
        
        let stats = fixture.pool.getStats()
        
        #expect(stats.heapCount == 1)
        #expect(stats.allocationCount == 2)
        #expect(stats.totalAllocated > 0)
        #expect(stats.totalUsed > 0)
    }
    
    // MARK: - UnifiedTensor Tests
    
    @Test("UnifiedTensor creation")
    func testUnifiedTensorCreation() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let tensor = UnifiedTensor(
            shape: [10, 10],
            dtype: .float32,
            pool: fixture.pool
        )
        
        #expect(tensor.shape == [10, 10])
        #expect(tensor.dtype == .float32)
        #expect(tensor.elementCount == 100)
        #expect(tensor.byteSize == 400)
    }
    
    @Test("UnifiedTensor CPU access")
    func testUnifiedTensorCPUAccess() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let tensor = UnifiedTensor.zeros(
            shape: [10],
            dtype: .float32,
            pool: fixture.pool
        )
        
        // Write values
        var values: [Float] = []
        for i in 0..<10 {
            values.append(Float(i))
        }
        tensor.write(values)
        
        // Read values
        let readValues: [Float] = tensor.read()
        
        #expect(readValues.count == 10)
        for i in 0..<10 {
            #expect(readValues[i] == Float(i), "Mismatch at index \(i)")
        }
    }
    
    @Test("UnifiedTensor addition")
    func testUnifiedTensorAdd() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let a = UnifiedTensor.fromArray(
            [1.0, 2.0, 3.0, 4.0],
            dtype: .float32,
            pool: fixture.pool
        )
        
        let b = UnifiedTensor.fromArray(
            [5.0, 6.0, 7.0, 8.0],
            dtype: .float32,
            pool: fixture.pool
        )
        
        let c = UnifiedTensor(
            shape: [4],
            dtype: .float32,
            pool: fixture.pool
        )
        
        let dispatcher = CPUInferenceDispatcher(pool: fixture.pool)
        _ = dispatcher.add(a: a, b: b, c: c)
        
        let result: [Float] = c.read()
        #expect(result.count == 4)
        #expect(result[0] ≈ 6.0 ± 0.001)
        #expect(result[1] ≈ 8.0 ± 0.001)
        #expect(result[2] ≈ 10.0 ± 0.001)
        #expect(result[3] ≈ 12.0 ± 0.001)
    }
    
    @Test("UnifiedTensor matrix multiplication")
    func testUnifiedTensorMatmul() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        // Create 2x3 matrix
        let a = UnifiedTensor.fromMultiArray(
            [[1.0, 2.0, 3.0],
             [4.0, 5.0, 6.0]],
            dtype: .float32,
            pool: fixture.pool
        )
        
        // Create 3x2 matrix
        let b = UnifiedTensor.fromMultiArray(
            [[7.0, 8.0],
             [9.0, 10.0],
             [11.0, 12.0]],
            dtype: .float32,
            pool: fixture.pool
        )
        
        // Create output 2x2 matrix
        let c = UnifiedTensor(
            shape: [2, 2],
            dtype: .float32,
            pool: fixture.pool
        )
        
        let dispatcher = CPUInferenceDispatcher(pool: fixture.pool)
        _ = dispatcher.matmul(a: a, b: b, c: c)
        
        let flatResult: [Float] = c.read()
        // Expected: [[58, 64], [139, 154]]
        #expect(flatResult.count == 4)
        #expect(flatResult[0] ≈ 58.0 ± 0.001)
        #expect(flatResult[1] ≈ 64.0 ± 0.001)
        #expect(flatResult[2] ≈ 139.0 ± 0.001)
        #expect(flatResult[3] ≈ 154.0 ± 0.001)
    }
    
    @Test("UnifiedTensor GELU")
    func testUnifiedTensorGELU() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let input = UnifiedTensor.fromArray(
            [-2.0, -1.0, 0.0, 1.0, 2.0],
            dtype: .float32,
            pool: fixture.pool
        )
        
        let output = UnifiedTensor(
            shape: [5],
            dtype: .float32,
            pool: fixture.pool
        )
        
        let dispatcher = CPUInferenceDispatcher(pool: fixture.pool)
        _ = dispatcher.gelu(input: input, output: output)
        
        let result: [Float] = output.read()
        
        // GELU(0) = 0
        #expect(result[2] ≈ 0.0 ± 0.001)
        
        // GELU values should be positive for positive inputs
        #expect(result[3] > 0.0)
        #expect(result[4] > 0.0)
        
        // GELU values should be negative for negative inputs
        #expect(result[0] < 0.0)
        #expect(result[1] < 0.0)
    }
    
    // MARK: - CPUSaturationMonitor Tests
    
    @Test("CPUSaturationMonitor creation")
    func testCPUSaturationMonitorCreation() {
        let monitor = CPUSaturationMonitor()
        
        #expect(monitor != nil)
        
        let stats = monitor.getStats()
        #expect(stats.totalCores == ProcessInfo.processInfo.processorCount)
    }
    
    @Test("CPUSaturationMonitor start/stop")
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
        #expect(stats1.overallSaturation >= 0.0)
        #expect(stats1.overallSaturation <= 1.0)
        
        #expect(stats2.overallSaturation >= 0.0)
        #expect(stats2.overallSaturation <= 1.0)
    }
    
    // MARK: - CPUInferenceDispatcher Tests
    
    @Test("CPUInferenceDispatcher creation")
    func testCPUInferenceDispatcherCreation() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let dispatcher = CPUInferenceDispatcher(pool: fixture.pool)
        
        #expect(dispatcher != nil)
    }
    
    @Test("CPUInferenceDispatcher receipts")
    func testCPUInferenceDispatcherReceipts() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        let dispatcher = CPUInferenceDispatcher(pool: fixture.pool)
        
        let a = UnifiedTensor.fromArray([1.0, 2.0, 3.0], dtype: .float32, pool: fixture.pool)
        let b = UnifiedTensor.fromArray([4.0, 5.0, 6.0], dtype: .float32, pool: fixture.pool)
        let c = UnifiedTensor(shape: [3], dtype: .float32, pool: fixture.pool)
        
        let receipt = dispatcher.add(a: a, b: b, c: c)
        
        #expect(receipt.operation == .add)
        #expect(receipt.inputShapes == [[3], [3]])
        #expect(receipt.outputShape == [3])
        #expect(receipt.executionTime > 0)
        #expect(receipt.flops == 3)
    }
    
    // MARK: - Integration Tests
    
    @Test("Full inference pipeline")
    func testFullInferencePipeline() throws {
        var fixture = try SaturationInferenceCoreFixture()
        defer { fixture.cleanup() }
        
        // Create dispatcher and tensors
        let dispatcher = CPUInferenceDispatcher(pool: fixture.pool)
        
        // Create input tensor (batch=1, sequence=10, features=64)
        let input = UnifiedTensor(
            shape: [10, 64],
            dtype: .float32,
            pool: fixture.pool
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
            pool: fixture.pool
        )
        
        let gamma = UnifiedTensor.ones(shape: [64], dtype: .float32, pool: fixture.pool)
        let beta = UnifiedTensor.zeros(shape: [64], dtype: .float32, pool: fixture.pool)
        
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
            pool: fixture.pool
        )
        
        let geluReceipt = dispatcher.gelu(
            input: layerNormOutput,
            output: geluOutput
        )
        
        // Verify receipts
        #expect(lnReceipt.operation == .layerNorm)
        #expect(geluReceipt.operation == .gelu)
        
        // Verify shapes
        #expect(layerNormOutput.shape == [10, 64])
        #expect(geluOutput.shape == [10, 64])
        
        // Verify that layer norm produced reasonable values
        let lnValues: [Float] = layerNormOutput.read()
        
        // Mean should be close to 0 after layer norm
        let mean = lnValues.reduce(0, +) / Float(lnValues.count)
        #expect(abs(mean) < 0.1, "Mean should be close to 0 after layer norm")
    }
}
