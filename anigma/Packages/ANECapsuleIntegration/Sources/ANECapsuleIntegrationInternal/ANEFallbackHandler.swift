import Foundation
import ANEServicesCore

/// ANE fallback handler for graceful degradation to CPU/GPU when ANE is unavailable
public actor ANEFallbackHandler {
    /// Fallback execution strategy
    public enum FallbackStrategy: String, Sendable, Codable {
        case immediate = "IMMEDIATE"      // Fallback immediately on first ANE failure
        case progressive = "PROGRESSIVE"  // Gradually increase fallback usage
        case conservative = "CONSERVATIVE" // Only fallback when absolutely necessary
        case disabled = "DISABLED"        // Never fallback, fail instead
    }
    
    /// Fallback execution mode
    public enum FallbackMode: String, Sendable, Codable {
        case cpu = "CPU"                  // Fallback to CPU execution
        case gpu = "GPU"                  // Fallback to GPU execution
        case hybrid = "HYBRID"            // Use CPU/GPU hybrid execution
        case distributed = "DISTRIBUTED"  // Distribute across available compute units
    }
    
    /// Fallback execution result
    public struct FallbackResult: Sendable {
        public let outputs: [ANEAnyPayload]
        public let computeUnitUsed: ANEComputeUnit
        public let executionTime: TimeInterval
        public let memoryUsedMB: Double
        public let powerUsedWatts: Double
        public let fallbackReason: FallbackReason
        public let performancePenalty: Double // 1.0 = no penalty, >1.0 = slower
        
        public init(
            outputs: [ANEAnyPayload],
            computeUnitUsed: ANEComputeUnit,
            executionTime: TimeInterval,
            memoryUsedMB: Double,
            powerUsedWatts: Double,
            fallbackReason: FallbackReason,
            performancePenalty: Double = 1.0
        ) {
            self.outputs = outputs
            self.computeUnitUsed = computeUnitUsed
            self.executionTime = executionTime
            self.memoryUsedMB = memoryUsedMB
            self.powerUsedWatts = powerUsedWatts
            self.fallbackReason = fallbackReason
            self.performancePenalty = performancePenalty
        }
    }
    
    /// Reason for fallback
    public enum FallbackReason: String, Sendable, Codable {
        case aneUnavailable = "ANE_UNAVAILABLE"
        case aneOverloaded = "ANE_OVERLOADED"
        case memoryConstraint = "MEMORY_CONSTRAINT"
        case powerConstraint = "POWER_CONSTRAINT"
        case thermalConstraint = "THERMAL_CONSTRAINT"
        case executionFailed = "EXECUTION_FAILED"
        case timeout = "TIMEOUT"
        case manualOverride = "MANUAL_OVERRIDE"
        case performanceOptimization = "PERFORMANCE_OPTIMIZATION"
    }
    
    /// Fallback configuration
    public struct FallbackConfig: Sendable {
        public let strategy: FallbackStrategy
        public let defaultMode: FallbackMode
        public let maxPerformancePenalty: Double
        public let retryCount: Int
        public let retryDelaySeconds: TimeInterval
        public let enablePerformanceMonitoring: Bool
        public let enableAdaptiveFallback: Bool
        
        public init(
            strategy: FallbackStrategy = .progressive,
            defaultMode: FallbackMode = .cpu,
            maxPerformancePenalty: Double = 3.0,
            retryCount: Int = 1,
            retryDelaySeconds: TimeInterval = 0.1,
            enablePerformanceMonitoring: Bool = true,
            enableAdaptiveFallback: Bool = true
        ) {
            self.strategy = strategy
            self.defaultMode = defaultMode
            self.maxPerformancePenalty = maxPerformancePenalty
            self.retryCount = retryCount
            self.retryDelaySeconds = retryDelaySeconds
            self.enablePerformanceMonitoring = enablePerformanceMonitoring
            self.enableAdaptiveFallback = enableAdaptiveFallback
        }
    }
    
    /// Fallback statistics
    public struct FallbackStatistics: Sendable {
        public let totalFallbacks: Int
        public let successfulFallbacks: Int
        public let failedFallbacks: Int
        public let averagePerformancePenalty: Double
        public let averageExecutionTime: TimeInterval
        public let mostCommonReason: FallbackReason
        public let cpuFallbacks: Int
        public let gpuFallbacks: Int
        public let hybridFallbacks: Int
        public let fallbackRate: Double
        
        public init(
            totalFallbacks: Int = 0,
            successfulFallbacks: Int = 0,
            failedFallbacks: Int = 0,
            averagePerformancePenalty: Double = 0.0,
            averageExecutionTime: TimeInterval = 0.0,
            mostCommonReason: FallbackReason = .aneUnavailable,
            cpuFallbacks: Int = 0,
            gpuFallbacks: Int = 0,
            hybridFallbacks: Int = 0,
            fallbackRate: Double = 0.0
        ) {
            self.totalFallbacks = totalFallbacks
            self.successfulFallbacks = successfulFallbacks
            self.failedFallbacks = failedFallbacks
            self.averagePerformancePenalty = averagePerformancePenalty
            self.averageExecutionTime = averageExecutionTime
            self.mostCommonReason = mostCommonReason
            self.cpuFallbacks = cpuFallbacks
            self.gpuFallbacks = gpuFallbacks
            self.hybridFallbacks = hybridFallbacks
            self.fallbackRate = fallbackRate
        }
    }
    
    /// Fallback error
    public enum FallbackError: Error, Sendable, LocalizedError {
        case fallbackDisabled
        case performancePenaltyExceeded(penalty: Double, max: Double)
        case allFallbackOptionsExhausted
        case invalidFallbackMode(requested: FallbackMode, available: [FallbackMode])
        case executionFailedOnAllUnits
        case memoryConstraintOnFallback(requiredMB: Double, availableMB: Double)
        case powerConstraintOnFallback(requiredWatts: Double, availableWatts: Double)
        
        public var errorDescription: String? {
            switch self {
            case .fallbackDisabled:
                return "Fallback execution is disabled"
            case .performancePenaltyExceeded(let penalty, let max):
                return "Performance penalty \(String(format: "%.1f", penalty))x exceeds maximum \(String(format: "%.1f", max))x"
            case .allFallbackOptionsExhausted:
                return "All fallback options have been exhausted"
            case .invalidFallbackMode(let requested, let available):
                return "Requested fallback mode \(requested.rawValue) not available. Available: \(available.map { $0.rawValue }.joined(separator: ", "))"
            case .executionFailedOnAllUnits:
                return "Execution failed on all available compute units"
            case .memoryConstraintOnFallback(let requiredMB, let availableMB):
                return "Memory constraint on fallback: required \(String(format: "%.1f", requiredMB))MB, available \(String(format: "%.1f", availableMB))MB"
            case .powerConstraintOnFallback(let requiredWatts, let availableWatts):
                return "Power constraint on fallback: required \(String(format: "%.1f", requiredWatts))W, available \(String(format: "%.1f", availableWatts))W"
            }
        }
    }
    
    private let config: FallbackConfig
    private var fallbackHistory: [FallbackRecord] = []
    private var performanceMetrics: [String: PerformanceMetric] = [:]
    private var availableFallbackModes: Set<FallbackMode> = [.cpu]
    private let maxHistorySize = 1000
    private var adaptiveFallbackEnabled: Bool = true
    
    public init(config: FallbackConfig = FallbackConfig()) {
        self.config = config
        self.adaptiveFallbackEnabled = config.enableAdaptiveFallback
        Task { [weak self] in
            await self?.discoverAvailableFallbackModes()
        }
    }
    
    /// Execute a batch using fallback compute units
    public func executeBatch(
        inputs: [ANEAnyPayload],
        capsuleId: String,
        characteristics: ANEWorkloadCharacteristics,
        computeUnit: ANEComputeUnit = .cpu,
        fallbackReason: FallbackReason = .aneUnavailable
    ) async throws -> [ANEAnyPayload] {
        let startTime = Date()
        
        // Check if fallback is disabled
        if config.strategy == .disabled {
            throw FallbackError.fallbackDisabled
        }
        
        // Determine fallback mode
        let fallbackMode = try determineFallbackMode(
            for: computeUnit,
            capsuleId: capsuleId,
            characteristics: characteristics,
            reason: fallbackReason
        )
        
        // Estimate performance penalty
        let estimatedPenalty = estimatePerformancePenalty(
            for: fallbackMode,
            characteristics: characteristics
        )
        
        // Check performance penalty limit
        if estimatedPenalty > config.maxPerformancePenalty {
            throw FallbackError.performancePenaltyExceeded(
                penalty: estimatedPenalty,
                max: config.maxPerformancePenalty
            )
        }
        
        // Execute with fallback
        let outputs: [ANEAnyPayload]
        let actualComputeUnit: ANEComputeUnit
        
        do {
            (outputs, actualComputeUnit) = try await executeWithFallbackMode(
                inputs: inputs,
                capsuleId: capsuleId,
                characteristics: characteristics,
                mode: fallbackMode,
                retryCount: config.retryCount
            )
        } catch {
            // Try alternative fallback modes if available
            if config.retryCount > 0 {
                let alternativeModes = getAlternativeFallbackModes(for: fallbackMode)
                for alternativeMode in alternativeModes {
                    do {
                        (outputs, actualComputeUnit) = try await executeWithFallbackMode(
                            inputs: inputs,
                            capsuleId: capsuleId,
                            characteristics: characteristics,
                            mode: alternativeMode,
                            retryCount: 0 // Don't retry within retry
                        )
                        // Success with alternative mode
                        break
                    } catch {
                        continue
                    }
                }
                throw FallbackError.executionFailedOnAllUnits
            } else {
                throw error
            }
        }
        
        // Calculate execution metrics
        let executionTime = Date().timeIntervalSince(startTime)
        let actualPenalty = executionTime / (characteristics.estimatedANETime * Double(inputs.count))
        
        let memoryUsed = Double(characteristics.memoryForBatch(batchSize: inputs.count)) / (1024 * 1024)
        let powerUsed = estimatePowerUsage(
            for: characteristics,
            batchSize: inputs.count,
            computeUnit: actualComputeUnit
        )
        
        // Record fallback execution
        let record = FallbackRecord(
            capsuleId: capsuleId,
            batchSize: inputs.count,
            requestedComputeUnit: computeUnit,
            actualComputeUnit: actualComputeUnit,
            fallbackMode: fallbackMode,
            fallbackReason: fallbackReason,
            executionTime: executionTime,
            performancePenalty: actualPenalty,
            memoryUsedMB: memoryUsed,
            powerUsedWatts: powerUsed,
            success: true
        )
        
        recordFallback(record)
        
        // Update performance metrics
        if config.enablePerformanceMonitoring {
            updatePerformanceMetrics(
                capsuleId: capsuleId,
                fallbackMode: fallbackMode,
                executionTime: executionTime,
                performancePenalty: actualPenalty
            )
        }
        
        return outputs
    }
    
    /// Get fallback statistics
    public func getStatistics() -> FallbackStatistics {
        guard !fallbackHistory.isEmpty else {
            return FallbackStatistics()
        }
        
        let recentHistory = getRecentHistory(period: 300.0) // Last 5 minutes
        
        let totalFallbacks = recentHistory.count
        let successfulFallbacks = recentHistory.filter { $0.success }.count
        let failedFallbacks = totalFallbacks - successfulFallbacks
        
        let averagePerformancePenalty = recentHistory.reduce(0.0) { $0 + $1.performancePenalty } / Double(totalFallbacks)
        let averageExecutionTime = recentHistory.reduce(0.0) { $0 + $1.executionTime } / Double(totalFallbacks)
        
        // Find most common reason
        let reasonCounts = Dictionary(grouping: recentHistory, by: { $0.fallbackReason })
            .mapValues { $0.count }
        let mostCommonReason = reasonCounts.max(by: { $0.value < $1.value })?.key ?? .aneUnavailable
        
        let cpuFallbacks = recentHistory.filter { $0.fallbackMode == .cpu }.count
        let gpuFallbacks = recentHistory.filter { $0.fallbackMode == .gpu }.count
        let hybridFallbacks = recentHistory.filter { $0.fallbackMode == .hybrid }.count
        
        // Calculate fallback rate (fallbacks per total executions would need total execution count)
        let fallbackRate = 0.0 // This would need total execution count from caller
        
        return FallbackStatistics(
            totalFallbacks: totalFallbacks,
            successfulFallbacks: successfulFallbacks,
            failedFallbacks: failedFallbacks,
            averagePerformancePenalty: averagePerformancePenalty,
            averageExecutionTime: averageExecutionTime,
            mostCommonReason: mostCommonReason,
            cpuFallbacks: cpuFallbacks,
            gpuFallbacks: gpuFallbacks,
            hybridFallbacks: hybridFallbacks,
            fallbackRate: fallbackRate
        )
    }
    
    /// Get recommended fallback mode for a capsule
    public func getRecommendedFallbackMode(
        for capsuleId: String,
        characteristics: ANEWorkloadCharacteristics
    ) -> FallbackMode {
        // Check performance history for this capsule
        if let metrics = performanceMetrics[capsuleId] {
            // Find mode with best performance
            let bestMode = metrics.modePerformance.min(by: { $0.value.averagePenalty < $1.value.averagePenalty })?.key
            
            if let bestMode = bestMode, availableFallbackModes.contains(bestMode) {
                return bestMode
            }
        }
        
        // Default based on characteristics
        if characteristics.computeIntensity == .high && availableFallbackModes.contains(.gpu) {
            return .gpu
        } else if characteristics.computeIntensity == .medium && availableFallbackModes.contains(.hybrid) {
            return .hybrid
        } else {
            return .cpu
        }
    }
    
    /// Check if fallback should be attempted
    public func shouldAttemptFallback(
        for capsuleId: String,
        characteristics: ANEWorkloadCharacteristics,
        reason: FallbackReason
    ) -> Bool {
        switch config.strategy {
        case .immediate:
            return true
        case .progressive:
            // Check recent fallback rate for this capsule
            let recentFallbacks = getRecentHistory(period: 60.0).filter { $0.capsuleId == capsuleId }
            let fallbackRate = Double(recentFallbacks.count) / 60.0 // fallbacks per second
            
            // Allow fallback if rate is low, otherwise throttle
            return fallbackRate < 1.0
        case .conservative:
            // Only fallback for critical reasons
            return reason == .aneUnavailable || reason == .executionFailed || reason == .timeout
        case .disabled:
            return false
        }
    }
    
    /// Enable or disable adaptive fallback
    public func setAdaptiveFallbackEnabled(_ enabled: Bool) {
        adaptiveFallbackEnabled = enabled
    }
    
    /// Get available fallback modes
    public func getAvailableFallbackModes() -> Set<FallbackMode> {
        availableFallbackModes
    }
    
    /// Clear fallback history
    public func clearHistory() {
        fallbackHistory.removeAll()
        performanceMetrics.removeAll()
    }
    
    // MARK: - Private Methods
    
    private struct FallbackRecord: Sendable {
        let capsuleId: String
        let batchSize: Int
        let requestedComputeUnit: ANEComputeUnit
        let actualComputeUnit: ANEComputeUnit
        let fallbackMode: FallbackMode
        let fallbackReason: FallbackReason
        let executionTime: TimeInterval
        let performancePenalty: Double
        let memoryUsedMB: Double
        let powerUsedWatts: Double
        let success: Bool
        let timestamp: Date = Date()
    }
    
    private struct PerformanceMetric: Sendable {
        var modePerformance: [FallbackMode: ModePerformance]
        var totalExecutions: Int
        var averagePenalty: Double
        
        struct ModePerformance: Sendable {
            var executionCount: Int
            var totalTime: TimeInterval
            var averagePenalty: Double
        }
        
        init() {
            self.modePerformance = [:]
            self.totalExecutions = 0
            self.averagePenalty = 0.0
        }
    }
    
    private func discoverAvailableFallbackModes() {
        // Discover available fallback modes on the system
        // This would typically check:
        // 1. CPU capabilities
        // 2. GPU availability and capabilities
        // 3. Memory constraints
        // 4. Power constraints
        
        // For now, assume CPU is always available
        var modes: Set<FallbackMode> = [.cpu]
        
        // Check if GPU might be available (simulated)
        let gpuAvailable = Bool.random() // Simulate GPU availability check
        if gpuAvailable {
            modes.insert(.gpu)
            modes.insert(.hybrid)
        }
        
        // Check if distributed execution might be possible
        // This would require multiple compute units
        if modes.count > 1 {
            modes.insert(.distributed)
        }
        
        availableFallbackModes = modes
        print("Discovered available fallback modes: \(modes.map { $0.rawValue }.joined(separator: ", "))")
    }
    
    private func determineFallbackMode(
        for computeUnit: ANEComputeUnit,
        capsuleId: String,
        characteristics: ANEWorkloadCharacteristics,
        reason: FallbackReason
    ) throws -> FallbackMode {
        // If a specific compute unit was requested, try to match it
        let requestedMode: FallbackMode
        switch computeUnit {
        case .cpu:
            requestedMode = .cpu
        case .gpu:
            requestedMode = .gpu
        case .neuralEngine:
            // ANE requested but unavailable, use default or recommended
            if adaptiveFallbackEnabled {
                requestedMode = getRecommendedFallbackMode(for: capsuleId, characteristics: characteristics)
            } else {
                requestedMode = config.defaultMode
            }
        case .all:
            requestedMode = config.defaultMode
        }
        
        // Check if requested mode is available
        guard availableFallbackModes.contains(requestedMode) else {
            // Try to find an alternative
            let alternative = findAlternativeMode(for: requestedMode)
            guard let alternative = alternative else {
                throw FallbackError.invalidFallbackMode(
                    requested: requestedMode,
                    available: Array(availableFallbackModes)
                )
            }
            return alternative
        }
        
        return requestedMode
    }
    
    private func findAlternativeMode(for mode: FallbackMode) -> FallbackMode? {
        // Find the best alternative mode
        switch mode {
        case .gpu:
            // Try hybrid, then cpu
            if availableFallbackModes.contains(.hybrid) {
                return .hybrid
            } else if availableFallbackModes.contains(.cpu) {
                return .cpu
            }
        case .hybrid:
            // Try distributed, then gpu, then cpu
            if availableFallbackModes.contains(.distributed) {
                return .distributed
            } else if availableFallbackModes.contains(.gpu) {
                return .gpu
            } else if availableFallbackModes.contains(.cpu) {
                return .cpu
            }
        case .distributed:
            // Try hybrid, then gpu, then cpu
            if availableFallbackModes.contains(.hybrid) {
                return .hybrid
            } else if availableFallbackModes.contains(.gpu) {
                return .gpu
            } else if availableFallbackModes.contains(.cpu) {
                return .cpu
            }
        case .cpu:
            // CPU is the baseline, no alternative needed
            return .cpu
        }
        
        return nil
    }
    
    private func getAlternativeFallbackModes(for mode: FallbackMode) -> [FallbackMode] {
        var alternatives: [FallbackMode] = []
        
        switch mode {
        case .cpu:
            if availableFallbackModes.contains(.gpu) { alternatives.append(.gpu) }
            if availableFallbackModes.contains(.hybrid) { alternatives.append(.hybrid) }
            if availableFallbackModes.contains(.distributed) { alternatives.append(.distributed) }
        case .gpu:
            if availableFallbackModes.contains(.cpu) { alternatives.append(.cpu) }
            if availableFallbackModes.contains(.hybrid) { alternatives.append(.hybrid) }
            if availableFallbackModes.contains(.distributed) { alternatives.append(.distributed) }
        case .hybrid:
            if availableFallbackModes.contains(.cpu) { alternatives.append(.cpu) }
            if availableFallbackModes.contains(.gpu) { alternatives.append(.gpu) }
            if availableFallbackModes.contains(.distributed) { alternatives.append(.distributed) }
        case .distributed:
            if availableFallbackModes.contains(.cpu) { alternatives.append(.cpu) }
            if availableFallbackModes.contains(.gpu) { alternatives.append(.gpu) }
            if availableFallbackModes.contains(.hybrid) { alternatives.append(.hybrid) }
        }
        
        return alternatives
    }
    
    private func executeWithFallbackMode(
        inputs: [ANEAnyPayload],
        capsuleId: String,
        characteristics: ANEWorkloadCharacteristics,
        mode: FallbackMode,
        retryCount: Int
    ) async throws -> ([ANEAnyPayload], ANEComputeUnit) {
        let computeUnit: ANEComputeUnit
        let executionFunction: () async throws -> [ANEAnyPayload]
        
        switch mode {
        case .cpu:
            computeUnit = .cpu
            executionFunction = {
                try await self.executeOnCPU(
                    inputs: inputs,
                    capsuleId: capsuleId,
                    characteristics: characteristics
                )
            }
        case .gpu:
            computeUnit = .gpu
            executionFunction = {
                try await self.executeOnGPU(
                    inputs: inputs,
                    capsuleId: capsuleId,
                    characteristics: characteristics
                )
            }
        case .hybrid:
            computeUnit = .all // Use both CPU and GPU
            executionFunction = {
                try await self.executeHybrid(
                    inputs: inputs,
                    capsuleId: capsuleId,
                    characteristics: characteristics
                )
            }
        case .distributed:
            computeUnit = .all
            executionFunction = {
                try await self.executeDistributed(
                    inputs: inputs,
                    capsuleId: capsuleId,
                    characteristics: characteristics
                )
            }
        }
        
        // Execute with retries
        var lastError: Error?
        
        for attempt in 0...retryCount {
            if attempt > 0 {
                // Delay before retry
                try await Task.sleep(nanoseconds: UInt64(config.retryDelaySeconds * 1_000_000_000))
            }
            
            do {
                let outputs = try await executionFunction()
                return (outputs, computeUnit)
            } catch {
                lastError = error
                print("⚠️ Fallback execution attempt \(attempt + 1) failed: \(error)")
                continue
            }
        }
        
        throw lastError ?? FallbackError.executionFailedOnAllUnits
    }
    
    private func executeOnCPU(
        inputs: [ANEAnyPayload],
        capsuleId: String,
        characteristics: ANEWorkloadCharacteristics
    ) async throws -> [ANEAnyPayload] {
        // Simulate CPU execution
        let executionTime = characteristics.estimatedCPUTime * Double(inputs.count)
        
        // Add some variability
        let variability = Double.random(in: 0.8...1.2)
        let actualTime = executionTime * variability
        
        // Simulate processing delay
        if actualTime > 0 {
            try await Task.sleep(nanoseconds: UInt64(actualTime * 1_000_000_000))
        }
        
        // Return placeholder results
        // STUB_TRACK: ane-cpu-fallback – CPU fallback using simulated execution
        print("⚠️  STUB INVOKED: ANEFallbackHandler.executeOnCPU()")
        print("   CPU fallback using simulated timing - not actual execution")
        return Array(repeating: ANEAnyPayload("CPU_Result"), count: inputs.count)
    }
    
    private func executeOnGPU(
        inputs: [ANEAnyPayload],
        capsuleId: String,
        characteristics: ANEWorkloadCharacteristics
    ) async throws -> [ANEAnyPayload] {
        // Simulate GPU execution
        // GPU is typically faster than CPU for parallel workloads
        let gpuSpeedup = 2.0 // Assume 2x speedup over CPU
        let executionTime = (characteristics.estimatedCPUTime / gpuSpeedup) * Double(inputs.count)
        
        // Add some variability
        let variability = Double.random(in: 0.7...1.3)
        let actualTime = executionTime * variability
        
        // Simulate processing delay
        if actualTime > 0 {
            try await Task.sleep(nanoseconds: UInt64(actualTime * 1_000_000_000))
        }
        
        // Return placeholder results
        // STUB_TRACK: ane-gpu-fallback – GPU fallback using simulated execution
        print("⚠️  STUB INVOKED: ANEFallbackHandler.executeOnGPU()")
        print("   GPU fallback using simulated timing - not actual execution")
        return Array(repeating: ANEAnyPayload("GPU_Result"), count: inputs.count)
    }
    
    private func executeHybrid(
        inputs: [ANEAnyPayload],
        capsuleId: String,
        characteristics: ANEWorkloadCharacteristics
    ) async throws -> [ANEAnyPayload] {
        // Simulate hybrid CPU/GPU execution
        // Split workload between CPU and GPU
        let cpuCount = inputs.count / 2
        let gpuCount = inputs.count - cpuCount
        
        // Execute in parallel
        async let cpuResults = executeOnCPU(
            inputs: Array(inputs.prefix(cpuCount)),
            capsuleId: capsuleId,
            characteristics: characteristics
        )
        
        async let gpuResults = executeOnGPU(
            inputs: Array(inputs.suffix(gpuCount)),
            capsuleId: capsuleId,
            characteristics: characteristics
        )
        
        let (cpuOutputs, gpuOutputs) = try await (cpuResults, gpuResults)
        
        // Combine results
        return cpuOutputs + gpuOutputs
    }
    
    private func executeDistributed(
        inputs: [ANEAnyPayload],
        capsuleId: String,
        characteristics: ANEWorkloadCharacteristics
    ) async throws -> [ANEAnyPayload] {
        // Simulate distributed execution across all available compute units
        // For now, just use hybrid execution
        return try await executeHybrid(
            inputs: inputs,
            capsuleId: capsuleId,
            characteristics: characteristics
        )
    }
    
    private func estimatePerformancePenalty(
        for mode: FallbackMode,
        characteristics: ANEWorkloadCharacteristics
    ) -> Double {
        // Estimate performance penalty compared to ANE
        let aneTime = characteristics.estimatedANETime
        let cpuTime = characteristics.estimatedCPUTime
        
        guard aneTime > 0 else { return 1.0 }
        
        let estimatedTime: Double
        switch mode {
        case .cpu:
            estimatedTime = cpuTime
        case .gpu:
            estimatedTime = cpuTime * 0.5 // Assume GPU is 2x faster than CPU
        case .hybrid:
            estimatedTime = cpuTime * 0.75 // Assume hybrid is 1.33x faster than CPU
        case .distributed:
            estimatedTime = cpuTime * 0.6 // Assume distributed is 1.67x faster than CPU
        }
        
        return estimatedTime / aneTime
    }
    
    private func estimatePowerUsage(
        for characteristics: ANEWorkloadCharacteristics,
        batchSize: Int,
        computeUnit: ANEComputeUnit
    ) -> Double {
        let basePower: Double
        switch computeUnit {
        case .cpu:
            basePower = 1.0
        case .gpu:
            basePower = 5.0
        case .neuralEngine:
            basePower = 2.0
        case .all:
            basePower = 3.0 // Average of CPU and GPU
        }
        
        let intensityFactor: Double
        switch characteristics.computeIntensity {
        case .low: intensityFactor = 0.5
        case .medium: intensityFactor = 1.0
        case .high: intensityFactor = 1.5
        }
        
        let batchSizeFactor = Double(batchSize) / Double(characteristics.optimalBatchSize)
        
        return basePower * intensityFactor * batchSizeFactor
    }
    
    private func recordFallback(_ record: FallbackRecord) {
        fallbackHistory.append(record)
        
        // Trim history if needed
        if fallbackHistory.count > maxHistorySize {
            fallbackHistory.removeFirst(fallbackHistory.count - maxHistorySize)
        }
    }
    
    private func getRecentHistory(period: TimeInterval) -> [FallbackRecord] {
        let cutoffDate = Date().addingTimeInterval(-period)
        return fallbackHistory.filter { $0.timestamp >= cutoffDate }
    }
    
    private func updatePerformanceMetrics(
        capsuleId: String,
        fallbackMode: FallbackMode,
        executionTime: TimeInterval,
        performancePenalty: Double
    ) {
        var metrics = performanceMetrics[capsuleId] ?? PerformanceMetric()
        
        // Update mode performance
        var modePerf = metrics.modePerformance[fallbackMode] ?? 
            PerformanceMetric.ModePerformance(executionCount: 0, totalTime: 0.0, averagePenalty: 0.0)
        
        modePerf.executionCount += 1
        modePerf.totalTime += executionTime
        modePerf.averagePenalty = (modePerf.averagePenalty * Double(modePerf.executionCount - 1) + performancePenalty) / Double(modePerf.executionCount)
        
        metrics.modePerformance[fallbackMode] = modePerf
        metrics.totalExecutions += 1
        metrics.averagePenalty = (metrics.averagePenalty * Double(metrics.totalExecutions - 1) + performancePenalty) / Double(metrics.totalExecutions)
        
        performanceMetrics[capsuleId] = metrics
    }
}
