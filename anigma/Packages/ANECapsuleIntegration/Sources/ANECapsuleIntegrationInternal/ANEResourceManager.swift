import Foundation
import ANEServicesCore

/// ANE resource manager for memory and power constraint enforcement
public actor ANEResourceManager {
    /// Resource constraints for ANE operations
    public struct ResourceConstraints: Sendable {
        public let memoryLimitMB: Int
        public let powerLimitWatts: Double
        public let maxConcurrentBatches: Int
        public let thermalLimitCelsius: Double
        public let memorySafetyMarginMB: Int
        public let powerSafetyMarginWatts: Double
        
        public init(
            memoryLimitMB: Int = 512,
            powerLimitWatts: Double = 15.0,
            maxConcurrentBatches: Int = 4,
            thermalLimitCelsius: Double = 85.0,
            memorySafetyMarginMB: Int = 64,
            powerSafetyMarginWatts: Double = 2.0
        ) {
            self.memoryLimitMB = memoryLimitMB
            self.powerLimitWatts = powerLimitWatts
            self.maxConcurrentBatches = maxConcurrentBatches
            self.thermalLimitCelsius = thermalLimitCelsius
            self.memorySafetyMarginMB = memorySafetyMarginMB
            self.powerSafetyMarginWatts = powerSafetyMarginWatts
        }
    }
    
    /// Resource usage snapshot
    public struct ResourceUsage: Sendable {
        public let memoryUsedMB: Double
        public let memoryAvailableMB: Double
        public let memoryUtilization: Double
        public let powerUsedWatts: Double
        public let powerAvailableWatts: Double
        public let powerUtilization: Double
        public let activeBatches: Int
        public let thermalState: ThermalState
        public let timestamp: Date
        
        public init(
            memoryUsedMB: Double,
            memoryAvailableMB: Double,
            memoryUtilization: Double,
            powerUsedWatts: Double,
            powerAvailableWatts: Double,
            powerUtilization: Double,
            activeBatches: Int,
            thermalState: ThermalState,
            timestamp: Date = Date()
        ) {
            self.memoryUsedMB = memoryUsedMB
            self.memoryAvailableMB = memoryAvailableMB
            self.memoryUtilization = memoryUtilization
            self.powerUsedWatts = powerUsedWatts
            self.powerAvailableWatts = powerAvailableWatts
            self.powerUtilization = powerUtilization
            self.activeBatches = activeBatches
            self.thermalState = thermalState
            self.timestamp = timestamp
        }
    }
    
    /// Thermal state of the system
    public enum ThermalState: String, Sendable, Codable {
        case nominal = "NOMINAL"
        case fair = "FAIR"
        case serious = "SERIOUS"
        case critical = "CRITICAL"
        
        /// Determine thermal state from temperature
        public static func fromTemperature(_ temperature: Double, limit: Double = 85.0) -> ThermalState {
            if temperature >= limit {
                return .critical
            } else if temperature >= limit * 0.85 {
                return .serious
            } else if temperature >= limit * 0.7 {
                return .fair
            } else {
                return .nominal
            }
        }
    }
    
    /// Resource allocation strategy
    public enum AllocationStrategy: String, Sendable, Codable {
        case conservative = "CONSERVATIVE"  // Leave more headroom
        case balanced = "BALANCED"          // Use resources efficiently
        case aggressive = "AGGRESSIVE"      // Maximize utilization
    }
    
    /// Resource constraint violation
    public enum ResourceError: Error, Sendable, LocalizedError {
        case memoryLimitExceeded(usedMB: Double, limitMB: Int)
        case powerLimitExceeded(usedWatts: Double, limitWatts: Double)
        case thermalLimitExceeded(temperature: Double, limitCelsius: Double)
        case tooManyConcurrentBatches(current: Int, limit: Int)
        case insufficientMemory(requiredMB: Double, availableMB: Double)
        case insufficientPower(requiredWatts: Double, availableWatts: Double)
        case systemUnderThermalPressure(state: ThermalState)
        
        public var errorDescription: String? {
            switch self {
            case .memoryLimitExceeded(let usedMB, let limitMB):
                return "Memory limit exceeded: used \(String(format: "%.1f", usedMB))MB, limit \(limitMB)MB"
            case .powerLimitExceeded(let usedWatts, let limitWatts):
                return "Power limit exceeded: used \(String(format: "%.1f", usedWatts))W, limit \(String(format: "%.1f", limitWatts))W"
            case .thermalLimitExceeded(let temperature, let limitCelsius):
                return "Thermal limit exceeded: \(String(format: "%.1f", temperature))°C, limit \(String(format: "%.1f", limitCelsius))°C"
            case .tooManyConcurrentBatches(let current, let limit):
                return "Too many concurrent batches: \(current), limit \(limit)"
            case .insufficientMemory(let requiredMB, let availableMB):
                return "Insufficient memory: required \(String(format: "%.1f", requiredMB))MB, available \(String(format: "%.1f", availableMB))MB"
            case .insufficientPower(let requiredWatts, let availableWatts):
                return "Insufficient power: required \(String(format: "%.1f", requiredWatts))W, available \(String(format: "%.1f", availableWatts))W"
            case .systemUnderThermalPressure(let state):
                return "System under thermal pressure: \(state.rawValue)"
            }
        }
    }
    
    /// Resource manager statistics
    public struct ResourceStatistics: Sendable {
        public let totalMemoryAllocatedMB: Double
        public let totalPowerAllocatedWatts: Double
        public let peakMemoryUsageMB: Double
        public let peakPowerUsageWatts: Double
        public let totalBatchesProcessed: Int
        public let memoryConstraintViolations: Int
        public let powerConstraintViolations: Int
        public let thermalConstraintViolations: Int
        public let memoryUtilizationRate: Double
        public let powerUtilizationRate: Double
        public let averageBatchMemoryMB: Double
        public let averageBatchPowerWatts: Double
        
        public init(
            totalMemoryAllocatedMB: Double = 0.0,
            totalPowerAllocatedWatts: Double = 0.0,
            peakMemoryUsageMB: Double = 0.0,
            peakPowerUsageWatts: Double = 0.0,
            totalBatchesProcessed: Int = 0,
            memoryConstraintViolations: Int = 0,
            powerConstraintViolations: Int = 0,
            thermalConstraintViolations: Int = 0,
            memoryUtilizationRate: Double = 0.0,
            powerUtilizationRate: Double = 0.0,
            averageBatchMemoryMB: Double = 0.0,
            averageBatchPowerWatts: Double = 0.0
        ) {
            self.totalMemoryAllocatedMB = totalMemoryAllocatedMB
            self.totalPowerAllocatedWatts = totalPowerAllocatedWatts
            self.peakMemoryUsageMB = peakMemoryUsageMB
            self.peakPowerUsageWatts = peakPowerUsageWatts
            self.totalBatchesProcessed = totalBatchesProcessed
            self.memoryConstraintViolations = memoryConstraintViolations
            self.powerConstraintViolations = powerConstraintViolations
            self.thermalConstraintViolations = thermalConstraintViolations
            self.memoryUtilizationRate = memoryUtilizationRate
            self.powerUtilizationRate = powerUtilizationRate
            self.averageBatchMemoryMB = averageBatchMemoryMB
            self.averageBatchPowerWatts = averageBatchPowerWatts
        }
    }
    
    private let constraints: ResourceConstraints
    private let allocationStrategy: AllocationStrategy
    private var currentMemoryUsageBytes: Int = 0
    private var currentPowerUsageWatts: Double = 0.0
    private var activeBatches: Set<UUID> = []
    private var peakMemoryUsageBytes: Int = 0
    private var peakPowerUsageWatts: Double = 0.0
    private var totalMemoryAllocatedBytes: Int = 0
    private var totalPowerAllocatedWatts: Double = 0.0
    private var totalBatchesProcessed: Int = 0
    private var constraintViolations: [ResourceError] = []
    private var systemTemperature: Double = 40.0 // Default temperature
    private var temperatureUpdateTimer: Timer?
    private let maxConstraintViolationHistory = 100
    
    public init(
        memoryLimitMB: Int = 512,
        powerLimitWatts: Double = 15.0,
        allocationStrategy: AllocationStrategy = .balanced
    ) {
        self.constraints = ResourceConstraints(
            memoryLimitMB: memoryLimitMB,
            powerLimitWatts: powerLimitWatts
        )
        self.allocationStrategy = allocationStrategy
        Task { [weak self] in
            await self?.startTemperatureMonitoring()
        }
    }
    
    deinit {
        temperatureUpdateTimer?.invalidate()
    }
    
    /// Check if a batch can be accepted given current resource constraints
    public func canAcceptBatch(
        memoryRequired: Int,
        powerRequired: Double
    ) -> Bool {
        do {
            try validateResourceConstraints(
                memoryRequired: memoryRequired,
                powerRequired: powerRequired
            )
            return true
        } catch {
            return false
        }
    }
    
    /// Reserve resources for a batch
    public func reserveResources(
        memoryRequired: Int,
        powerRequired: Double,
        batchId: UUID = UUID()
    ) throws {
        try validateResourceConstraints(
            memoryRequired: memoryRequired,
            powerRequired: powerRequired
        )
        
        // Update current usage
        currentMemoryUsageBytes += memoryRequired
        currentPowerUsageWatts += powerRequired
        
        // Update peaks
        peakMemoryUsageBytes = max(peakMemoryUsageBytes, currentMemoryUsageBytes)
        peakPowerUsageWatts = max(peakPowerUsageWatts, currentPowerUsageWatts)
        
        // Update totals
        totalMemoryAllocatedBytes += memoryRequired
        totalPowerAllocatedWatts += powerRequired
        
        // Track active batch
        activeBatches.insert(batchId)
        
        // Check thermal constraints
        try checkThermalConstraints()
    }
    
    /// Release resources after batch completion
    public func releaseResources(
        memoryUsed: Int,
        powerUsed: Double,
        batchId: UUID
    ) {
        currentMemoryUsageBytes -= memoryUsed
        currentPowerUsageWatts -= powerUsed
        
        // Ensure values don't go negative
        currentMemoryUsageBytes = max(currentMemoryUsageBytes, 0)
        currentPowerUsageWatts = max(currentPowerUsageWatts, 0.0)
        
        // Remove from active batches
        activeBatches.remove(batchId)
        
        // Increment processed count
        totalBatchesProcessed += 1
    }
    
    /// Convenience method for batch processor
    public func recordBatchCompletion(
        memoryUsed: Int,
        powerUsed: Double
    ) {
        // This is called after batch completion to update statistics
        // The actual resource release happens in releaseResources
        // This method is for tracking completion statistics
    }
    
    /// Get current resource usage
    public func getCurrentUsage() -> ResourceUsage {
        let memoryUsedMB = Double(currentMemoryUsageBytes) / (1024 * 1024)
        let memoryAvailableMB = Double(constraints.memoryLimitMB) - memoryUsedMB
        let memoryUtilization = memoryUsedMB / Double(constraints.memoryLimitMB)
        
        let powerAvailableWatts = constraints.powerLimitWatts - currentPowerUsageWatts
        let powerUtilization = currentPowerUsageWatts / constraints.powerLimitWatts
        
        let thermalState = ThermalState.fromTemperature(
            systemTemperature,
            limit: constraints.thermalLimitCelsius
        )
        
        return ResourceUsage(
            memoryUsedMB: memoryUsedMB,
            memoryAvailableMB: memoryAvailableMB,
            memoryUtilization: memoryUtilization,
            powerUsedWatts: currentPowerUsageWatts,
            powerAvailableWatts: powerAvailableWatts,
            powerUtilization: powerUtilization,
            activeBatches: activeBatches.count,
            thermalState: thermalState
        )
    }
    
    /// Get resource manager statistics
    public func getStatistics() -> ResourceStatistics {
        let memoryUtilizationRate = Double(peakMemoryUsageBytes) / Double(constraints.memoryLimitMB * 1024 * 1024)
        let powerUtilizationRate = peakPowerUsageWatts / constraints.powerLimitWatts
        
        let averageBatchMemoryMB = totalBatchesProcessed > 0 ? 
            Double(totalMemoryAllocatedBytes) / Double(totalBatchesProcessed * 1024 * 1024) : 0.0
        let averageBatchPowerWatts = totalBatchesProcessed > 0 ? 
            totalPowerAllocatedWatts / Double(totalBatchesProcessed) : 0.0
        
        let memoryViolations = constraintViolations.filter {
            if case .memoryLimitExceeded = $0 { return true }
            if case .insufficientMemory = $0 { return true }
            return false
        }.count
        
        let powerViolations = constraintViolations.filter {
            if case .powerLimitExceeded = $0 { return true }
            if case .insufficientPower = $0 { return true }
            return false
        }.count
        
        let thermalViolations = constraintViolations.filter {
            if case .thermalLimitExceeded = $0 { return true }
            if case .systemUnderThermalPressure = $0 { return true }
            return false
        }.count
        
        return ResourceStatistics(
            totalMemoryAllocatedMB: Double(totalMemoryAllocatedBytes) / (1024 * 1024),
            totalPowerAllocatedWatts: totalPowerAllocatedWatts,
            peakMemoryUsageMB: Double(peakMemoryUsageBytes) / (1024 * 1024),
            peakPowerUsageWatts: peakPowerUsageWatts,
            totalBatchesProcessed: totalBatchesProcessed,
            memoryConstraintViolations: memoryViolations,
            powerConstraintViolations: powerViolations,
            thermalConstraintViolations: thermalViolations,
            memoryUtilizationRate: memoryUtilizationRate,
            powerUtilizationRate: powerUtilizationRate,
            averageBatchMemoryMB: averageBatchMemoryMB,
            averageBatchPowerWatts: averageBatchPowerWatts
        )
    }
    
    /// Get recent constraint violations
    public func getRecentViolations(limit: Int = 10) -> [ResourceError] {
        Array(constraintViolations.suffix(limit))
    }
    
    /// Clear constraint violation history
    public func clearViolationHistory() {
        constraintViolations.removeAll()
    }
    
    /// Set system temperature (for testing or external monitoring)
    public func setSystemTemperature(_ temperature: Double) {
        systemTemperature = temperature
    }
    
    /// Get recommended batch size based on current resource availability
    public func getRecommendedBatchSize(
        memoryPerOperation: Int,
        powerPerOperation: Double,
        desiredBatchSize: Int = 32
    ) -> Int {
        let currentUsage = getCurrentUsage()
        
        // Calculate available resources with safety margin
        let availableMemoryMB = currentUsage.memoryAvailableMB - Double(constraints.memorySafetyMarginMB)
        let availablePowerWatts = currentUsage.powerAvailableWatts - constraints.powerSafetyMarginWatts
        
        guard availableMemoryMB > 0 && availablePowerWatts > 0 else {
            return 0
        }
        
        // Calculate maximum batch size based on each constraint
        let memoryLimitedSize = Int(availableMemoryMB * 1024 * 1024) / memoryPerOperation
        let powerLimitedSize = Int(availablePowerWatts / powerPerOperation)
        
        // Also consider thermal state
        let thermalLimitedSize: Int
        switch currentUsage.thermalState {
        case .nominal:
            thermalLimitedSize = desiredBatchSize
        case .fair:
            thermalLimitedSize = desiredBatchSize * 3 / 4
        case .serious:
            thermalLimitedSize = desiredBatchSize / 2
        case .critical:
            thermalLimitedSize = 0
        }
        
        // Also consider concurrent batch limit
        let batchLimit = constraints.maxConcurrentBatches - currentUsage.activeBatches
        let concurrencyLimitedSize = batchLimit > 0 ? desiredBatchSize : 0
        
        // Take the minimum of all constraints
        let maxSize = min(
            memoryLimitedSize,
            powerLimitedSize,
            thermalLimitedSize,
            concurrencyLimitedSize,
            desiredBatchSize
        )
        
        // Apply allocation strategy
        let recommendedSize: Int
        switch allocationStrategy {
        case .conservative:
            recommendedSize = maxSize * 2 / 3
        case .balanced:
            recommendedSize = maxSize * 3 / 4
        case .aggressive:
            recommendedSize = maxSize
        }
        
        return max(1, recommendedSize)
    }
    
    /// Check if system is under thermal pressure
    public func isUnderThermalPressure() -> Bool {
        let thermalState = ThermalState.fromTemperature(
            systemTemperature,
            limit: constraints.thermalLimitCelsius
        )
        return thermalState == .serious || thermalState == .critical
    }
    
    /// Get thermal throttling recommendation
    public func getThermalThrottlingRecommendation() -> Double {
        let thermalState = ThermalState.fromTemperature(
            systemTemperature,
            limit: constraints.thermalLimitCelsius
        )
        
        switch thermalState {
        case .nominal:
            return 1.0 // No throttling
        case .fair:
            return 0.75 // 25% throttling
        case .serious:
            return 0.5 // 50% throttling
        case .critical:
            return 0.25 // 75% throttling
        }
    }
    
    // MARK: - Private Methods
    
    private func validateResourceConstraints(
        memoryRequired: Int,
        powerRequired: Double
    ) throws {
        // Check memory constraint with safety margin
        let memoryLimitWithMargin = constraints.memoryLimitMB - constraints.memorySafetyMarginMB
        let projectedMemoryMB = Double(currentMemoryUsageBytes + memoryRequired) / (1024 * 1024)
        
        if projectedMemoryMB > Double(memoryLimitWithMargin) {
            let error = ResourceError.memoryLimitExceeded(
                usedMB: projectedMemoryMB,
                limitMB: memoryLimitWithMargin
            )
            constraintViolations.append(error)
            throw error
        }
        
        // Check power constraint with safety margin
        let powerLimitWithMargin = constraints.powerLimitWatts - constraints.powerSafetyMarginWatts
        let projectedPowerWatts = currentPowerUsageWatts + powerRequired
        
        if projectedPowerWatts > powerLimitWithMargin {
            let error = ResourceError.powerLimitExceeded(
                usedWatts: projectedPowerWatts,
                limitWatts: powerLimitWithMargin
            )
            constraintViolations.append(error)
            throw error
        }
        
        // Check concurrent batch limit
        if activeBatches.count >= constraints.maxConcurrentBatches {
            let error = ResourceError.tooManyConcurrentBatches(
                current: activeBatches.count,
                limit: constraints.maxConcurrentBatches
            )
            constraintViolations.append(error)
            throw error
        }
        
        // Check thermal constraints
        try checkThermalConstraints()
        
        // Trim violation history if needed
        if constraintViolations.count > maxConstraintViolationHistory {
            constraintViolations.removeFirst(constraintViolations.count - maxConstraintViolationHistory)
        }
    }
    
    private func checkThermalConstraints() throws {
        let thermalState = ThermalState.fromTemperature(
            systemTemperature,
            limit: constraints.thermalLimitCelsius
        )
        
        // Check if temperature exceeds limit
        if systemTemperature >= constraints.thermalLimitCelsius {
            let error = ResourceError.thermalLimitExceeded(
                temperature: systemTemperature,
                limitCelsius: constraints.thermalLimitCelsius
            )
            constraintViolations.append(error)
            throw error
        }
        
        // Check if system is under thermal pressure
        if thermalState == .serious || thermalState == .critical {
            let error = ResourceError.systemUnderThermalPressure(state: thermalState)
            constraintViolations.append(error)
            throw error
        }
    }
    
    private func startTemperatureMonitoring() {
        // Simulate temperature updates
        temperatureUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.updateSystemTemperature()
            }
        }
    }
    
    private func updateSystemTemperature() {
        // Simulate temperature changes based on current usage
        let baseTemperature = 40.0 // Base temperature
        let memoryHeatFactor = Double(currentMemoryUsageBytes) / Double(constraints.memoryLimitMB * 1024 * 1024) * 10.0
        let powerHeatFactor = currentPowerUsageWatts / constraints.powerLimitWatts * 15.0
        let batchHeatFactor = Double(activeBatches.count) / Double(constraints.maxConcurrentBatches) * 5.0
        
        // Add some random variation
        let randomVariation = Double.random(in: -2.0...2.0)
        
        // Calculate new temperature
        let newTemperature = baseTemperature + memoryHeatFactor + powerHeatFactor + batchHeatFactor + randomVariation
        
        // Apply thermal inertia (temperature doesn't change instantly)
        systemTemperature = systemTemperature * 0.7 + newTemperature * 0.3
        
        // Ensure temperature doesn't go below ambient
        systemTemperature = max(systemTemperature, 35.0)
        
        // Log if temperature is getting high
        if systemTemperature > constraints.thermalLimitCelsius * 0.8 {
            print("⚠️ System temperature rising: \(String(format: "%.1f", systemTemperature))°C")
        }
    }
}
