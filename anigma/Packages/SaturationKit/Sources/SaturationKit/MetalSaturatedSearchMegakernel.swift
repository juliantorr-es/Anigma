import Foundation
import Metal
import AnigmaPrimitives
import SaturationKitCore

/// A high-performance Metal-accelerated search kernel with ICB support.
/// This kernel moves the core similarity search and telemetry capture to the GPU.
public final class MetalSaturatedSearchMegakernel: @unchecked Sendable {
    
    private let device: MTLDevice
    private let pipelineState: MTLComputePipelineState
    private let icbArgumentLock = NSLock()
    private var retainedICBArgumentBuffers: [MTLBuffer] = []
    
    public enum Error: Swift.Error {
        case deviceInitializationFailed
        case pipelineStateCreationFailed(String)
        case bufferCreationFailed
        case shaderNotFound
    }
    
    public init(device: MTLDevice) throws {
        self.device = device
        
        // In a production app, we'd load from the default library.
        // For the prototype, we assume the shader is compiled or available.
        guard let library = device.makeDefaultLibrary() else {
            throw Error.shaderNotFound
        }
        
        guard let function = library.makeFunction(name: "saturated_vector_search") else {
            throw Error.shaderNotFound
        }
        
        do {
            self.pipelineState = try Self.makePipelineState(device: device, function: function)
        } catch {
            throw Error.pipelineStateCreationFailed(error.localizedDescription)
        }
    }
    
    /// Initializes with an explicit shader source string (useful for testing or dynamic kernels).
    public init(device: MTLDevice, source: String) throws {
        self.device = device
        
        let options = MTLCompileOptions()
        let library = try device.makeLibrary(source: source, options: options)
        
        guard let function = library.makeFunction(name: "saturated_vector_search") else {
            throw Error.shaderNotFound
        }
        
        do {
            self.pipelineState = try Self.makePipelineState(device: device, function: function)
        } catch {
            throw Error.pipelineStateCreationFailed(error.localizedDescription)
        }
    }

    private static func makePipelineState(device: MTLDevice, function: MTLFunction) throws -> MTLComputePipelineState {
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.computeFunction = function
        descriptor.supportIndirectCommandBuffers = true
        return try device.makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
    }
    
    /// Executes a saturated search on the GPU.
    ///
    /// - Parameters:
    ///   - query: The query vector.
    ///   - candidates: Contiguous flat array of candidate vectors (SoA format).
    ///   - dimension: Dimension of each vector.
    ///   - threshold: Similarity threshold.
    ///   - loggingRing: The saturated logging ring for GPU telemetry.
    /// - Returns: Indices of selected candidates.
    public func search(
        query: [Float],
        candidates: [Float],
        dimension: Int,
        threshold: Float,
        loggingRing: SaturatedLoggingRing
    ) async throws -> [UInt32] {
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.deviceInitializationFailed
        }
        
        // 1. Prepare Buffers
        let queryBuffer = device.makeBuffer(bytes: query, length: query.count * MemoryLayout<Float>.size, options: .storageModeShared)
        let candidatesBuffer = device.makeBuffer(bytes: candidates, length: candidates.count * MemoryLayout<Float>.size, options: .storageModeShared)
        
        let candidateCount = candidates.count / dimension
        let similarityBuffer = device.makeBuffer(length: candidateCount * MemoryLayout<Float>.size, options: .storageModeShared)
        let selectedIndicesBuffer = device.makeBuffer(length: candidateCount * MemoryLayout<UInt32>.size, options: .storageModeShared)
        let selectedCountBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size, options: .storageModeShared)
        let heartbeatPayloadHash = try SaturatedHeartbeatPacket.payloadHash(
            for: Self.heartbeatPayloadData(query: query, candidates: candidates, dimension: dimension, threshold: threshold),
            preferMetalDigest: true
        )
        var heartbeatPayloadHashBytes = heartbeatPayloadHash.bytes
        let heartbeatPayloadHashBuffer = device.makeBuffer(bytes: &heartbeatPayloadHashBytes, length: heartbeatPayloadHashBytes.count, options: .storageModeShared)
        
        guard let qBuf = queryBuffer, let cBuf = candidatesBuffer, let sBuf = similarityBuffer,
              let siBuf = selectedIndicesBuffer, let scBuf = selectedCountBuffer,
              let hbBuf = heartbeatPayloadHashBuffer else {
            throw Error.bufferCreationFailed
        }
        scBuf.contents().assumingMemoryBound(to: UInt32.self).pointee = 0
        
        // 2. Set Up Telemetry (Logging Ring)
        guard let ringBuffer = await loggingRing.metalBuffer() else {
            throw Error.bufferCreationFailed
        }
        
        // 3. Encode Kernel
        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(qBuf, offset: 0, index: 0)
        encoder.setBuffer(cBuf, offset: 0, index: 1)
        encoder.setBuffer(sBuf, offset: 0, index: 2)
        encoder.setBuffer(siBuf, offset: 0, index: 3)
        encoder.setBuffer(scBuf, offset: 0, index: 4)
        encoder.setBuffer(ringBuffer, offset: 0, index: 5)
        encoder.setBuffer(ringBuffer, offset: 32, index: 6)
        encoder.setBuffer(hbBuf, offset: 0, index: 7)
        
        var dim = UInt32(dimension)
        var thresh = threshold
        var candidateCountValue = UInt32(candidateCount)
        encoder.setBytes(&dim, length: MemoryLayout<UInt32>.size, index: 8)
        encoder.setBytes(&thresh, length: MemoryLayout<Float>.size, index: 9)
        encoder.setBytes(&candidateCountValue, length: MemoryLayout<UInt32>.size, index: 10)
        
        let threadgroupSize = MTLSize(width: min(pipelineState.maxTotalThreadsPerThreadgroup, candidateCount), height: 1, depth: 1)
        let gridSize = MTLSize(width: candidateCount, height: 1, depth: 1)
        
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            commandBuffer.addCompletedHandler { buffer in
                if let error = buffer.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            commandBuffer.commit()
        }
        
        let count = scBuf.contents().assumingMemoryBound(to: UInt32.self).pointee
        let resultsPointer = siBuf.contents().assumingMemoryBound(to: UInt32.self)
        let results = Array(UnsafeBufferPointer(start: resultsPointer, count: Int(count)))
        
        return results
    }

    /// Encodes a search mission into an Indirect Command Buffer (ICB).
    /// This allows Phase 2's autonomous GPU-driven execution.
    public func encodeSearchToICB(
        icb: MTLIndirectCommandBuffer,
        index: Int,
        queryBuffer: MTLBuffer,
        candidatesBuffer: MTLBuffer,
        similarityBuffer: MTLBuffer,
        selectedIndicesBuffer: MTLBuffer,
        selectedCountBuffer: MTLBuffer,
        ringBuffer: MTLBuffer,
        heartbeatPayloadHashBuffer: MTLBuffer,
        dimension: Int,
        threshold: Float,
        candidateCount: Int
    ) {
        let command = icb.indirectComputeCommandAt(index)
        command.setComputePipelineState(pipelineState)
        command.setKernelBuffer(queryBuffer, offset: 0, at: 0)
        command.setKernelBuffer(candidatesBuffer, offset: 0, at: 1)
        command.setKernelBuffer(similarityBuffer, offset: 0, at: 2)
        command.setKernelBuffer(selectedIndicesBuffer, offset: 0, at: 3)
        command.setKernelBuffer(selectedCountBuffer, offset: 0, at: 4)
        command.setKernelBuffer(ringBuffer, offset: 0, at: 5)
        command.setKernelBuffer(ringBuffer, offset: 32, at: 6)
        command.setKernelBuffer(heartbeatPayloadHashBuffer, offset: 0, at: 7)

        var dim = UInt32(dimension)
        var thresh = threshold
        var candidateCountValue = UInt32(candidateCount)
        if let dimensionBuffer = device.makeBuffer(bytes: &dim, length: MemoryLayout<UInt32>.size, options: .storageModeShared),
           let thresholdBuffer = device.makeBuffer(bytes: &thresh, length: MemoryLayout<Float>.size, options: .storageModeShared),
           let candidateCountBuffer = device.makeBuffer(bytes: &candidateCountValue, length: MemoryLayout<UInt32>.size, options: .storageModeShared) {
            command.setKernelBuffer(dimensionBuffer, offset: 0, at: 8)
            command.setKernelBuffer(thresholdBuffer, offset: 0, at: 9)
            command.setKernelBuffer(candidateCountBuffer, offset: 0, at: 10)
            icbArgumentLock.lock()
            retainedICBArgumentBuffers.append(contentsOf: [heartbeatPayloadHashBuffer, dimensionBuffer, thresholdBuffer, candidateCountBuffer])
            icbArgumentLock.unlock()
        }
        
        let threadgroupSize = MTLSize(width: min(pipelineState.maxTotalThreadsPerThreadgroup, candidateCount), height: 1, depth: 1)
        let gridSize = MTLSize(width: candidateCount, height: 1, depth: 1)
        
        command.concurrentDispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
    }

    /// Creates an ICB for batch search missions.
    public func makeICB(count: Int) -> MTLIndirectCommandBuffer? {
        let desc = MTLIndirectCommandBufferDescriptor()
        desc.commandTypes = .concurrentDispatchThreads
        desc.inheritBuffers = false
        desc.inheritPipelineState = false
        desc.maxKernelBufferBindCount = 11
        return device.makeIndirectCommandBuffer(descriptor: desc, maxCommandCount: count, options: .storageModeShared)
    }

    private static func heartbeatPayloadData(query: [Float], candidates: [Float], dimension: Int, threshold: Float) -> Data {
        var data = Data()
        data.reserveCapacity((query.count + candidates.count + 2) * MemoryLayout<Float>.size)
        for value in query {
            data.appendLittleEndian(value)
        }
        for value in candidates {
            data.appendLittleEndian(value)
        }
        data.appendLittleEndian(UInt32(dimension))
        data.appendLittleEndian(threshold)
        return data
    }
}
