import Foundation
import TelemetryCore
import ANEServicesCore
import ANEExecutionReceipts
import ANECapsuleContracts

public typealias ANETelemetryCategory = TelemetryCategory
public typealias ANETelemetryPayload = [String: TelemetryValue]

public struct ANECapsuleResult<Output: Sendable>: Sendable {
    public let output: Output
    public let executionReceipt: ExecutionReceipt?
    public let computeUnitUsed: ANEComputeUnit
    public let executionTime: TimeInterval
    public let fallbackUsed: Bool

    public init(
        output: Output,
        executionReceipt: ExecutionReceipt? = nil,
        computeUnitUsed: ANEComputeUnit,
        executionTime: TimeInterval,
        fallbackUsed: Bool = false
    ) {
        self.output = output
        self.executionReceipt = executionReceipt
        self.computeUnitUsed = computeUnitUsed
        self.executionTime = executionTime
        self.fallbackUsed = fallbackUsed
    }
}

public struct ANEPerformanceMetrics: Sendable {
    public var totalBatches: Int
    public var totalWorkloads: Int
    public var successfulBatches: Int
    public var failedBatches: Int
    public var fallbackBatches: Int
    public var averageBatchSize: Double
    public var averageExecutionTime: TimeInterval
    public var aneBatches: Int
    public var cpuBatches: Int
    public var gpuBatches: Int
    public var successRate: Double
    public var fallbackRate: Double

    public init(
        totalBatches: Int = 0,
        totalWorkloads: Int = 0,
        successfulBatches: Int = 0,
        failedBatches: Int = 0,
        fallbackBatches: Int = 0,
        averageBatchSize: Double = 0,
        averageExecutionTime: TimeInterval = 0,
        aneBatches: Int = 0,
        cpuBatches: Int = 0,
        gpuBatches: Int = 0,
        successRate: Double = 0,
        fallbackRate: Double = 0
    ) {
        self.totalBatches = totalBatches
        self.totalWorkloads = totalWorkloads
        self.successfulBatches = successfulBatches
        self.failedBatches = failedBatches
        self.fallbackBatches = fallbackBatches
        self.averageBatchSize = averageBatchSize
        self.averageExecutionTime = averageExecutionTime
        self.aneBatches = aneBatches
        self.cpuBatches = cpuBatches
        self.gpuBatches = gpuBatches
        self.successRate = successRate
        self.fallbackRate = fallbackRate
    }
}

public actor ANEPerformanceMonitor {
    private let capsuleId: String
    private var metrics = ANEPerformanceMetrics()
    private var activationCount = 0
    private var deactivationCount = 0

    public init(capsuleId: String = "") {
        self.capsuleId = capsuleId
    }

    public func recordActivation() {
        activationCount += 1
    }

    public func recordDeactivation() {
        deactivationCount += 1
    }

    public func recordANEBatchExecution(batchSize: Int, executionTime: TimeInterval) {
        updateMetrics(batchSize: batchSize, executionTime: executionTime, isANE: true, fallbackUsed: false)
    }

    public func recordCPUFallback(batchSize: Int, executionTime: TimeInterval) {
        updateMetrics(batchSize: batchSize, executionTime: executionTime, isANE: false, fallbackUsed: true)
    }

    public func getMetrics() -> ANEPerformanceMetrics {
        metrics
    }

    public func reset() {
        metrics = ANEPerformanceMetrics()
    }

    private func updateMetrics(batchSize: Int, executionTime: TimeInterval, isANE: Bool, fallbackUsed: Bool) {
        metrics.totalBatches += 1
        metrics.totalWorkloads += batchSize
        metrics.successfulBatches += 1
        metrics.averageBatchSize = metrics.totalBatches == 0 ? 0 : Double(metrics.totalWorkloads) / Double(metrics.totalBatches)
        metrics.averageExecutionTime = metrics.totalBatches == 0 ? 0 : ((metrics.averageExecutionTime * Double(metrics.totalBatches - 1)) + executionTime) / Double(metrics.totalBatches)
        metrics.successRate = metrics.totalBatches == 0 ? 0 : Double(metrics.successfulBatches) / Double(metrics.totalBatches)
        if isANE {
            metrics.aneBatches += 1
        } else {
            metrics.cpuBatches += 1
        }
        if fallbackUsed {
            metrics.fallbackBatches += 1
        }
        metrics.fallbackRate = metrics.totalBatches == 0 ? 0 : Double(metrics.fallbackBatches) / Double(metrics.totalBatches)
    }
}

public extension ANEGateInfo {
    static var open: ANEGateInfo {
        ANEGateInfo(status: .open)
    }
}

public extension ANECapsuleDescriptor {
    var name: String { displayName }
    var description: String { tags.first ?? displayName }
    var capabilityLevel: ANECapabilityLevel { ANECapabilityLevel.fromComputeUnits(supportedComputeUnits) }
    var batchSizeRange: ClosedRange<Int> { 1...32 }
    var optimalBatchSize: Int { 16 }
    var memoryPerOperation: Int { 0 }
    var estimatedSpeedup: Double { 1.0 }

    init(
        id: String,
        version: String,
        name: String,
        description: String,
        supportedComputeUnits: [ANEComputeUnit],
        gate: ANEGateInfo,
        capabilityLevel _: ANECapabilityLevel,
        batchSizeRange _: ClosedRange<Int>,
        optimalBatchSize _: Int,
        memoryPerOperation _: Int,
        estimatedSpeedup _: Double
    ) {
        let units = Set(supportedComputeUnits)
        self.init(
            id: id,
            displayName: name,
            version: version,
            gate: gate,
            supportedComputeUnits: units,
            defaultComputeUnit: units.contains(.neuralEngine) ? .neuralEngine : (units.first ?? .all),
            tags: [description]
        )
    }
}
