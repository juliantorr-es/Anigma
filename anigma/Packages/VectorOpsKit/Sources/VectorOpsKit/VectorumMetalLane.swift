import Foundation

#if canImport(Metal)
import Metal
#endif

final class VectorumMetalLane: @unchecked Sendable {
    private enum Op: UInt32 {
        case add = 0
        case subtract = 1
        case hadamard = 2
        case scale = 3
        case absDiff = 4
        case square = 5
        case reduceSum = 6
    }

    #if canImport(Metal)
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var elementwisePipeline: MTLComputePipelineState?
    private var reductionPipeline: MTLComputePipelineState?
    #endif

    init() {
        #if canImport(Metal)
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            self.device = nil
            self.commandQueue = nil
            self.elementwisePipeline = nil
            self.reductionPipeline = nil
            return
        }

        let source = Self.kernelSource
        do {
            let library = try device.makeLibrary(source: source, options: nil)
            guard let elementwiseFunction = library.makeFunction(name: "vectorum_elementwise"),
                  let reductionFunction = library.makeFunction(name: "vectorum_reduce_sum") else {
                self.device = nil
                self.commandQueue = nil
                self.elementwisePipeline = nil
                self.reductionPipeline = nil
                return
            }

            self.device = device
            self.commandQueue = commandQueue
            self.elementwisePipeline = try device.makeComputePipelineState(function: elementwiseFunction)
            self.reductionPipeline = try device.makeComputePipelineState(function: reductionFunction)
        } catch {
            self.device = nil
            self.commandQueue = nil
            self.elementwisePipeline = nil
            self.reductionPipeline = nil
        }
        #else
        // Metal unavailable; keep the lane dormant.
        #endif
    }

    func add(_ lhs: [Float], _ rhs: [Float]) -> [Float]? {
        elementwise(lhs: lhs, rhs: rhs, scalar: 0, op: .add)
    }

    func subtract(_ lhs: [Float], _ rhs: [Float]) -> [Float]? {
        elementwise(lhs: lhs, rhs: rhs, scalar: 0, op: .subtract)
    }

    func hadamard(_ lhs: [Float], _ rhs: [Float]) -> [Float]? {
        elementwise(lhs: lhs, rhs: rhs, scalar: 0, op: .hadamard)
    }

    func scale(_ vector: [Float], by scalar: Float) -> [Float]? {
        elementwise(lhs: vector, rhs: vector, scalar: scalar, op: .scale)
    }

    func absDifference(_ lhs: [Float], _ rhs: [Float]) -> [Float]? {
        elementwise(lhs: lhs, rhs: rhs, scalar: 0, op: .absDiff)
    }

    func square(_ vector: [Float]) -> [Float]? {
        elementwise(lhs: vector, rhs: vector, scalar: 0, op: .square)
    }

    func dotProduct(_ lhs: [Float], _ rhs: [Float]) -> Float? {
        guard let hadamard = hadamard(lhs, rhs) else { return nil }
        return reduceSum(hadamard)
    }

    func sum(_ vector: [Float]) -> Float? {
        reduceSum(vector)
    }

    private func elementwise(lhs: [Float], rhs: [Float], scalar: Float, op: Op) -> [Float]? {
        #if canImport(Metal)
        guard lhs.count == rhs.count else { return nil }
        guard !lhs.isEmpty else { return [] }
        guard let device,
              let commandQueue,
              let pipeline = elementwisePipeline,
              let lhsBuffer = lhs.withUnsafeBytes({
                  device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
              }),
              let rhsBuffer = rhs.withUnsafeBytes({
                  device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
              }),
              let outputBuffer = device.makeBuffer(length: lhs.count * MemoryLayout<Float>.size, options: .storageModeShared) else {
            return nil
        }

        var count = UInt32(lhs.count)
        var scalarValue = scalar
        var opValue = op.rawValue

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(lhsBuffer, offset: 0, index: 0)
        encoder.setBuffer(rhsBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.size, index: 3)
        encoder.setBytes(&scalarValue, length: MemoryLayout<Float>.size, index: 4)
        encoder.setBytes(&opValue, length: MemoryLayout<UInt32>.size, index: 5)

        let maxWidth = min(256, pipeline.maxTotalThreadsPerThreadgroup, max(1, lhs.count))
        var threadgroupWidth = 1
        while threadgroupWidth * 2 <= maxWidth {
            threadgroupWidth *= 2
        }
        let threadsPerThreadgroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        let gridSize = MTLSize(width: lhs.count, height: 1, depth: 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let pointer = outputBuffer.contents().assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: pointer, count: lhs.count))
        #else
        return nil
        #endif
    }

    private func reduceSum(_ vector: [Float]) -> Float? {
        #if canImport(Metal)
        guard !vector.isEmpty else { return 0 }
        guard let device,
              let commandQueue,
              let pipeline = reductionPipeline,
              let inputBuffer = vector.withUnsafeBytes({
                  device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
              }) else {
            return nil
        }

        var count = UInt32(vector.count)
        let maxWidth = min(256, pipeline.maxTotalThreadsPerThreadgroup, max(1, vector.count))
        var threadgroupWidth = 1
        while threadgroupWidth * 2 <= maxWidth {
            threadgroupWidth *= 2
        }
        let groupCount = (vector.count + threadgroupWidth - 1) / threadgroupWidth
        guard let partialsBuffer = device.makeBuffer(length: max(1, groupCount) * MemoryLayout<Float>.size, options: .storageModeShared),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(partialsBuffer, offset: 0, index: 1)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.size, index: 2)

        let threadsPerThreadgroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: groupCount, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let pointer = partialsBuffer.contents().assumingMemoryBound(to: Float.self)
        let partials = Array(UnsafeBufferPointer(start: pointer, count: groupCount))
        if partials.count == 1 {
            return partials[0]
        }
        return partials.reduce(0, +)
        #else
        return nil
        #endif
    }

    #if canImport(Metal)
    private static let kernelSource = """
    #include <metal_stdlib>
    using namespace metal;

    enum VectorumOp : uint {
        add = 0,
        subtract = 1,
        hadamard = 2,
        scale = 3,
        absDiff = 4,
        square = 5,
        reduceSum = 6
    };

    kernel void vectorum_elementwise(
        device const float* lhs [[buffer(0)]],
        device const float* rhs [[buffer(1)]],
        device float* output [[buffer(2)]],
        constant uint& count [[buffer(3)]],
        constant float& scalar [[buffer(4)]],
        constant uint& op [[buffer(5)]],
        uint id [[thread_position_in_grid]]
    ) {
        if (id >= count) {
            return;
        }

        const float a = lhs[id];
        const float b = rhs[id];

        switch (op) {
        case 0:
            output[id] = a + b;
            break;
        case 1:
            output[id] = a - b;
            break;
        case 2:
            output[id] = a * b;
            break;
        case 3:
            output[id] = a * scalar;
            break;
        case 4:
            output[id] = fabs(a - b);
            break;
        case 5:
            output[id] = a * a;
            break;
        default:
            output[id] = 0.0;
            break;
        }
    }

    kernel void vectorum_reduce_sum(
        device const float* input [[buffer(0)]],
        device float* partials [[buffer(1)]],
        constant uint& count [[buffer(2)]],
        uint tid [[thread_index_in_threadgroup]],
        uint groupId [[threadgroup_position_in_grid]],
        uint gid [[thread_position_in_grid]],
        uint threadsPerGroup [[threads_per_threadgroup]]
    ) {
        threadgroup float scratch[256];
        const uint lane = tid;
        scratch[lane] = gid < count ? input[gid] : 0.0;
        threadgroup_barrier(mem_flags::mem_threadgroup);

        for (uint stride = threadsPerGroup / 2; stride > 0; stride /= 2) {
            if (lane < stride) {
                scratch[lane] += scratch[lane + stride];
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
        }

        if (lane == 0) {
            partials[groupId] = scratch[0];
        }
    }
    """
    #endif
}
