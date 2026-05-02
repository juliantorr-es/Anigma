#if canImport(Metal)
import Foundation
import Metal
import OSLog

final class CosineSimilarityMetalBackend {
    struct CapabilitySnapshot: Sendable {
        let deviceName: String
        let registryID: UInt64
        let hasUnifiedMemory: Bool
        let isLowPower: Bool
        let maxBufferLengthBytes: Int
        let recommendedMaxWorkingSetSizeBytes: Int
        let threadExecutionWidth: Int
        let maxThreadsPerThreadgroup: Int
        let minOffloadCount: Int
        let minOffloadDimension: Int
    }

    struct WorkloadAssessment: Sendable {
        let isSupported: Bool
        let shouldOffload: Bool
        let reason: String
    }

    private static let logger = Logger(
        subsystem: "com.anigma.CosineSimilarityCapsule",
        category: "MetalBackend"
    )

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    private let thresholdPipelineState: MTLComputePipelineState
    private let capabilities: CapabilitySnapshot

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let pipelineStates = Self.makePipelineStates(device: device) else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.pipelineState = pipelineStates.batch
        self.thresholdPipelineState = pipelineStates.threshold
        self.capabilities = Self.detectCapabilities(device: device, pipelineState: pipelineStates.batch)

        Self.logger.info(
            "Metal capability snapshot: device=\(self.capabilities.deviceName, privacy: .public) unified=\(self.capabilities.hasUnifiedMemory, privacy: .public) lowPower=\(self.capabilities.isLowPower, privacy: .public) maxBufferBytes=\(self.capabilities.maxBufferLengthBytes, privacy: .public) recommendedWorkingSetBytes=\(self.capabilities.recommendedMaxWorkingSetSizeBytes, privacy: .public) threadExecutionWidth=\(self.capabilities.threadExecutionWidth, privacy: .public) maxThreadsPerThreadgroup=\(self.capabilities.maxThreadsPerThreadgroup, privacy: .public) minOffloadCount=\(self.capabilities.minOffloadCount, privacy: .public) minOffloadDimension=\(self.capabilities.minOffloadDimension, privacy: .public)"
        )
    }

    private struct PipelineStates {
        let batch: MTLComputePipelineState
        let threshold: MTLComputePipelineState
    }

    private enum KernelIndex {
        static let query = 0
        static let candidates = 1
        static let results = 2
        static let dimension = 3
        static let count = 4
        static let queryNorm = 5
        static let threshold = 6
    }

    private static func makePipelineStates(device: MTLDevice) -> PipelineStates? {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        inline float cosine_similarity_for_candidate(
            device const float *query,
            device const float *candidates,
            uint dimension,
            float queryMagnitude,
            uint gid
        ) {
            uint offset = gid * dimension;
            float dot = 0.0f;
            float candidateNorm = 0.0f;

            for (uint i = 0; i < dimension; ++i) {
                float q = query[i];
                float c = candidates[offset + i];
                dot += q * c;
                candidateNorm += c * c;
            }

            float denom = queryMagnitude * sqrt(candidateNorm);
            return denom > 0.0f ? dot / denom : 0.0f;
        }

        kernel void cosine_batch(
            device const float *query [[buffer(0)]],
            device const float *candidates [[buffer(1)]],
            device float *results [[buffer(2)]],
            constant uint &dimension [[buffer(3)]],
            constant uint &count [[buffer(4)]],
            constant float &queryMagnitude [[buffer(5)]],
            uint gid [[thread_position_in_grid]]
        ) {
            if (gid >= count) {
                return;
            }

            results[gid] = cosine_similarity_for_candidate(
                query,
                candidates,
                dimension,
                queryMagnitude,
                gid
            );
        }

        kernel void cosine_batch_threshold(
            device const float *query [[buffer(0)]],
            device const float *candidates [[buffer(1)]],
            device float *results [[buffer(2)]],
            constant uint &dimension [[buffer(3)]],
            constant uint &count [[buffer(4)]],
            constant float &queryMagnitude [[buffer(5)]],
            constant float &minSimilarity [[buffer(6)]],
            uint gid [[thread_position_in_grid]]
        ) {
            if (gid >= count) {
                return;
            }

            float similarity = cosine_similarity_for_candidate(
                query,
                candidates,
                dimension,
                queryMagnitude,
                gid
            );
            results[gid] = similarity >= minSimilarity ? similarity : -2.0f;
        }
        """

        guard let library = try? device.makeLibrary(source: source, options: nil),
              let batchFunction = library.makeFunction(name: "cosine_batch"),
              let thresholdFunction = library.makeFunction(name: "cosine_batch_threshold") else {
            return nil
        }

        guard let batch = try? device.makeComputePipelineState(function: batchFunction),
              let threshold = try? device.makeComputePipelineState(function: thresholdFunction) else {
            return nil
        }

        return PipelineStates(batch: batch, threshold: threshold)
    }

    private static func computeQueryNorm(_ query: [Float]) -> Float {
        var sum = 0.0
        for value in query {
            let scalar = Double(value)
            sum += scalar * scalar
        }
        return Float(sum.squareRoot())
    }

    func computeBatch(
        query: [Float],
        candidates: [Float],
        count: Int,
        dimension: Int
    ) -> [Float]? {
        let queryNorm = Self.computeQueryNorm(query)
        return runBatchKernel(
            pipelineState: pipelineState,
            query: query,
            candidates: candidates,
            count: count,
            dimension: dimension,
            queryNorm: queryNorm
        )
    }

    func computeBatchThreshold(
        query: [Float],
        candidates: [Float],
        count: Int,
        dimension: Int,
        minSimilarity: Float
    ) -> (results: [Float], passedCount: Int)? {
        let queryNorm = Self.computeQueryNorm(query)
        guard let results = runBatchKernel(
            pipelineState: thresholdPipelineState,
            query: query,
            candidates: candidates,
            count: count,
            dimension: dimension,
            queryNorm: queryNorm,
            minSimilarity: minSimilarity
        ) else {
            return nil
        }

        var passedCount = 0
        for score in results where score >= minSimilarity {
            passedCount += 1
        }

        return (results, passedCount)
    }

    func capabilitySnapshot() -> CapabilitySnapshot {
        capabilities
    }

    func assessWorkload(count: Int, dimension: Int) -> WorkloadAssessment {
        guard count > 0, dimension > 0 else {
            return WorkloadAssessment(
                isSupported: false,
                shouldOffload: false,
                reason: "non-positive workload"
            )
        }

        let floatStride = MemoryLayout<Float>.stride
        let totalElements = count.multipliedReportingOverflow(by: dimension)
        guard !totalElements.overflow else {
            return WorkloadAssessment(
                isSupported: false,
                shouldOffload: false,
                reason: "workload element count overflow"
            )
        }

        let candidateBytes = totalElements.partialValue.multipliedReportingOverflow(by: floatStride)
        let queryBytes = dimension.multipliedReportingOverflow(by: floatStride)
        let resultBytes = count.multipliedReportingOverflow(by: floatStride)
        guard !candidateBytes.overflow, !queryBytes.overflow, !resultBytes.overflow else {
            return WorkloadAssessment(
                isSupported: false,
                shouldOffload: false,
                reason: "workload byte-size overflow"
            )
        }

        let maxBufferLength = capabilities.maxBufferLengthBytes
        if queryBytes.partialValue > maxBufferLength ||
            resultBytes.partialValue > maxBufferLength ||
            candidateBytes.partialValue > maxBufferLength {
            return WorkloadAssessment(
                isSupported: false,
                shouldOffload: false,
                reason: "buffer length exceeds device maxBufferLength"
            )
        }

        let estimatedWorkingSet = candidateBytes.partialValue + queryBytes.partialValue + resultBytes.partialValue
        let recommendedWorkingSet = capabilities.recommendedMaxWorkingSetSizeBytes
        if recommendedWorkingSet > 0, estimatedWorkingSet > recommendedWorkingSet {
            return WorkloadAssessment(
                isSupported: false,
                shouldOffload: false,
                reason: "estimated working set exceeds recommended device working set"
            )
        }

        let meetsOffloadThreshold = count >= capabilities.minOffloadCount &&
            dimension >= capabilities.minOffloadDimension

        if !meetsOffloadThreshold {
            return WorkloadAssessment(
                isSupported: true,
                shouldOffload: false,
                reason: "below offload thresholds count>=\(capabilities.minOffloadCount), dimension>=\(capabilities.minOffloadDimension)"
            )
        }

        return WorkloadAssessment(
            isSupported: true,
            shouldOffload: true,
            reason: "meets capability-aware offload thresholds"
        )
    }

    private func runBatchKernel(
        pipelineState: MTLComputePipelineState,
        query: [Float],
        candidates: [Float],
        count: Int,
        dimension: Int,
        queryNorm: Float,
        minSimilarity: Float? = nil
    ) -> [Float]? {
        let assessment = assessWorkload(count: count, dimension: dimension)
        guard assessment.isSupported,
              query.count == dimension,
              candidates.count == count * dimension else {
            Self.logger.debug(
                "Skipping Metal kernel dispatch: reason=\(assessment.reason, privacy: .public) count=\(count, privacy: .public) dimension=\(dimension, privacy: .public)"
            )
            return nil
        }

        var results = [Float](repeating: 0.0, count: count)

        return query.withUnsafeBufferPointer { queryPtr in
            candidates.withUnsafeBufferPointer { candidatePtr in
                guard let queryBase = queryPtr.baseAddress,
                      let candidateBase = candidatePtr.baseAddress else {
                    return nil
                }

                guard let queryBuffer = device.makeBuffer(
                    bytes: queryBase,
                    length: queryPtr.count * MemoryLayout<Float>.stride,
                    options: .storageModeShared
                ),
                let candidatesBuffer = device.makeBuffer(
                    bytes: candidateBase,
                    length: candidatePtr.count * MemoryLayout<Float>.stride,
                    options: .storageModeShared
                ),
                let resultsBuffer = device.makeBuffer(
                    length: results.count * MemoryLayout<Float>.stride,
                    options: .storageModeShared
                ) else {
                    return nil
                }

                var dimensionValue = UInt32(dimension)
                var countValue = UInt32(count)
                var queryNormValue = queryNorm

                return withUnsafeBytes(of: &dimensionValue) { dimensionBytes in
                    withUnsafeBytes(of: &countValue) { countBytes in
                        withUnsafeBytes(of: &queryNormValue) { queryNormBytes in
                            guard let dimensionBase = dimensionBytes.baseAddress,
                                  let countBase = countBytes.baseAddress,
                                  let queryNormBase = queryNormBytes.baseAddress,
                                  let dimensionBuffer = device.makeBuffer(
                                    bytes: dimensionBase,
                                    length: dimensionBytes.count,
                                    options: .storageModeShared
                                  ),
                                  let countBuffer = device.makeBuffer(
                                    bytes: countBase,
                                    length: countBytes.count,
                                    options: .storageModeShared
                                  ),
                                  let queryNormBuffer = device.makeBuffer(
                                    bytes: queryNormBase,
                                    length: queryNormBytes.count,
                                    options: .storageModeShared
                                  ),
                                  let commandBuffer = commandQueue.makeCommandBuffer(),
                                  let encoder = commandBuffer.makeComputeCommandEncoder() else {
                                return nil
                            }

                            encoder.setComputePipelineState(pipelineState)
                            encoder.setBuffer(queryBuffer, offset: 0, index: KernelIndex.query)
                            encoder.setBuffer(candidatesBuffer, offset: 0, index: KernelIndex.candidates)
                            encoder.setBuffer(resultsBuffer, offset: 0, index: KernelIndex.results)
                            encoder.setBuffer(dimensionBuffer, offset: 0, index: KernelIndex.dimension)
                            encoder.setBuffer(countBuffer, offset: 0, index: KernelIndex.count)
                            encoder.setBuffer(queryNormBuffer, offset: 0, index: KernelIndex.queryNorm)

                            if let minSimilarity {
                                var thresholdValue = minSimilarity
                                guard let thresholdBuffer = device.makeBuffer(
                                    bytes: &thresholdValue,
                                    length: MemoryLayout<Float>.stride,
                                    options: .storageModeShared
                                ) else {
                                    return nil
                                }
                                encoder.setBuffer(thresholdBuffer, offset: 0, index: KernelIndex.threshold)
                            }

                            let gridSize = MTLSize(width: count, height: 1, depth: 1)
                            let threadgroupWidth = min(pipelineState.threadExecutionWidth, max(1, count))
                            let threadsPerThreadgroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)

                            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerThreadgroup)
                            encoder.endEncoding()

                            commandBuffer.commit()
                            commandBuffer.waitUntilCompleted()

                            guard commandBuffer.status == .completed else {
                                return nil
                            }

                            let resultPointer = resultsBuffer.contents().bindMemory(to: Float.self, capacity: count)
                            for index in 0..<count {
                                results[index] = resultPointer[index]
                            }

                            return results
                        }
                    }
                }
            }
        }
    }

    func computeBatchWithNorm(
        query: [Float],
        queryNorm: Float,
        candidates: [Float],
        count: Int,
        dimension: Int
    ) -> [Float]? {
        runBatchKernel(
            pipelineState: pipelineState,
            query: query,
            candidates: candidates,
            count: count,
            dimension: dimension,
            queryNorm: queryNorm
        )
    }
    
    func shouldOffload(count: Int, dimension: Int) -> Bool {
        assessWorkload(count: count, dimension: dimension).shouldOffload
    }

    private static func detectCapabilities(
        device: MTLDevice,
        pipelineState: MTLComputePipelineState
    ) -> CapabilitySnapshot {
        let defaultCountThreshold = 64
        let defaultDimensionThreshold = 128

        var minOffloadCount = defaultCountThreshold
        var minOffloadDimension = defaultDimensionThreshold

        if device.isLowPower {
            minOffloadCount += 64
            minOffloadDimension += 32
        }
        if !device.hasUnifiedMemory {
            minOffloadCount += 64
        }
        if pipelineState.threadExecutionWidth >= 64 {
            minOffloadDimension = max(96, minOffloadDimension - 32)
        } else if pipelineState.threadExecutionWidth < 32 {
            minOffloadDimension += 32
        }
        if pipelineState.maxTotalThreadsPerThreadgroup < 512 {
            minOffloadCount += 32
        }

        return CapabilitySnapshot(
            deviceName: device.name,
            registryID: device.registryID,
            hasUnifiedMemory: device.hasUnifiedMemory,
            isLowPower: device.isLowPower,
            maxBufferLengthBytes: device.maxBufferLength,
            recommendedMaxWorkingSetSizeBytes: Int(device.recommendedMaxWorkingSetSize),
            threadExecutionWidth: pipelineState.threadExecutionWidth,
            maxThreadsPerThreadgroup: pipelineState.maxTotalThreadsPerThreadgroup,
            minOffloadCount: minOffloadCount,
            minOffloadDimension: minOffloadDimension
        )
    }
}
#else
import Foundation

final class CosineSimilarityMetalBackend {
    struct CapabilitySnapshot: Sendable {
        let deviceName: String
        let registryID: UInt64
        let hasUnifiedMemory: Bool
        let isLowPower: Bool
        let maxBufferLengthBytes: Int
        let recommendedMaxWorkingSetSizeBytes: Int
        let threadExecutionWidth: Int
        let maxThreadsPerThreadgroup: Int
        let minOffloadCount: Int
        let minOffloadDimension: Int
    }

    struct WorkloadAssessment: Sendable {
        let isSupported: Bool
        let shouldOffload: Bool
        let reason: String
    }

    init?() { nil }

    func computeBatch(
        query: [Float],
        candidates: [Float],
        count: Int,
        dimension: Int
    ) -> [Float]? {
        _ = (query, candidates, count, dimension)
        return nil
    }

    func computeBatchThreshold(
        query: [Float],
        candidates: [Float],
        count: Int,
        dimension: Int,
        minSimilarity: Float
    ) -> (results: [Float], passedCount: Int)? {
        _ = (query, candidates, count, dimension, minSimilarity)
        return nil
    }

    func computeBatchWithNorm(
        query: [Float],
        queryNorm: Float,
        candidates: [Float],
        count: Int,
        dimension: Int
    ) -> [Float]? {
        _ = (query, queryNorm, candidates, count, dimension)
        return nil
    }

    func shouldOffload(count: Int, dimension: Int) -> Bool {
        _ = (count, dimension)
        return false
    }

    func assessWorkload(count: Int, dimension: Int) -> WorkloadAssessment {
        _ = (count, dimension)
        return WorkloadAssessment(
            isSupported: false,
            shouldOffload: false,
            reason: "Metal unavailable on this platform"
        )
    }

    func capabilitySnapshot() -> CapabilitySnapshot {
        CapabilitySnapshot(
            deviceName: "unavailable",
            registryID: 0,
            hasUnifiedMemory: false,
            isLowPower: false,
            maxBufferLengthBytes: 0,
            recommendedMaxWorkingSetSizeBytes: 0,
            threadExecutionWidth: 0,
            maxThreadsPerThreadgroup: 0,
            minOffloadCount: Int.max,
            minOffloadDimension: Int.max
        )
    }
}
#endif
