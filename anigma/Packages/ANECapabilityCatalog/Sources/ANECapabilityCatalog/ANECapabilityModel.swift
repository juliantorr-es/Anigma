import Foundation
import ANEServicesCore
import CapsuleCore
import ANECapsuleContracts

public struct ANECapability: Sendable, Codable, Hashable {
    public let id: String
    public let displayName: String
    public let level: ANECapabilityLevel
    public let supportedComputeUnits: Set<ANEComputeUnit>
    public let preferredComputeUnit: ANEComputeUnit
    public let supportsFallback: Bool
    public let performanceProfile: [ANEComputeUnit: PerformanceProfile]
    public let memoryRequirements: [ANEComputeUnit: Int]
    public let powerProfile: [ANEComputeUnit: PowerProfile]
    public let optimizationHints: OptimizationHints
    
    public init(
        id: String,
        displayName: String,
        level: ANECapabilityLevel,
        supportedComputeUnits: Set<ANEComputeUnit>,
        preferredComputeUnit: ANEComputeUnit,
        supportsFallback: Bool = true,
        performanceProfile: [ANEComputeUnit: PerformanceProfile] = [:],
        memoryRequirements: [ANEComputeUnit: Int] = [:],
        powerProfile: [ANEComputeUnit: PowerProfile] = [:],
        optimizationHints: OptimizationHints = OptimizationHints()
    ) {
        self.id = id
        self.displayName = displayName
        self.level = level
        self.supportedComputeUnits = supportedComputeUnits
        self.preferredComputeUnit = preferredComputeUnit
        self.supportsFallback = supportsFallback
        self.performanceProfile = performanceProfile
        self.memoryRequirements = memoryRequirements
        self.powerProfile = powerProfile
        self.optimizationHints = optimizationHints
    }
    
    public static func fromDescriptor(_ descriptor: ANECapsuleDescriptor) -> ANECapability {
        let level = ANECapabilityLevel.fromComputeUnits(descriptor.supportedComputeUnits)
        return ANECapability(
            id: descriptor.id,
            displayName: descriptor.displayName,
            level: level,
            supportedComputeUnits: descriptor.supportedComputeUnits,
            preferredComputeUnit: descriptor.defaultComputeUnit,
            supportsFallback: descriptor.supportedComputeUnits.contains(.cpu)
        )
    }
    
    public func canRunOn(_ computeUnit: ANEComputeUnit) -> Bool {
        if computeUnit == .all {
            return !supportedComputeUnits.isEmpty
        }
        return supportedComputeUnits.contains(computeUnit)
    }
    
    public func bestComputeUnit(
        preferred: ANEComputeUnit? = nil,
        availableUnits: Set<ANEComputeUnit> = Set(ANEComputeUnit.allCases)
    ) -> ANEComputeUnit? {
        let preferredUnit = preferred ?? preferredComputeUnit
        if canRunOn(preferredUnit) && availableUnits.contains(preferredUnit) {
            return preferredUnit
        }
        for unit in supportedComputeUnits.sorted(by: { $0.rawValue < $1.rawValue }) {
            if availableUnits.contains(unit) {
                return unit
            }
        }
        return nil
    }
    
    public func performanceEstimate(for computeUnit: ANEComputeUnit) -> PerformanceProfile? {
        return performanceProfile[computeUnit]
    }
    
    public func memoryRequirement(for computeUnit: ANEComputeUnit) -> Int {
        return memoryRequirements[computeUnit] ?? 0
    }
    
    public func powerProfile(for computeUnit: ANEComputeUnit) -> PowerProfile? {
        return powerProfile[computeUnit]
    }
}

public struct PerformanceProfile: Sendable, Codable, Hashable {
    public let opsPerSecond: Double?
    public let latencyMs: Double?
    public let throughput: Double?
    public let source: ProfileSource
    public let timestamp: Date
    
    public init(
        opsPerSecond: Double? = nil,
        latencyMs: Double? = nil,
        throughput: Double? = nil,
        source: ProfileSource = .estimated,
        timestamp: Date = Date()
    ) {
        self.opsPerSecond = opsPerSecond
        self.latencyMs = latencyMs
        self.throughput = throughput
        self.source = source
        self.timestamp = timestamp
    }
    
    public var score: Double {
        var score = 0.0
        if let ops = opsPerSecond { score += log10(ops) * 0.4 }
        if let latency = latencyMs, latency > 0 { score += (1000.0 / latency) * 0.4 }
        if let throughput = throughput { score += log10(throughput) * 0.2 }
        return score
    }
}

public struct PowerProfile: Sendable, Codable, Hashable {
    public let powerWatts: Double
    public let efficiency: Double?
    public let thermalProfile: ThermalProfile
    
    public init(
        powerWatts: Double,
        efficiency: Double? = nil,
        thermalProfile: ThermalProfile = .balanced
    ) {
        self.powerWatts = powerWatts
        self.efficiency = efficiency
        self.thermalProfile = thermalProfile
    }
}

public enum ThermalProfile: String, Sendable, Codable, CaseIterable {
    case cool = "COOL"
    case balanced = "BALANCED"
    case warm = "WARM"
    case hot = "HOT"
    
    public var maxContinuousDuration: TimeInterval? {
        switch self {
        case .cool: return nil
        case .balanced: return 3600
        case .warm: return 900
        case .hot: return 300
        }
    }
}

public enum ProfileSource: String, Sendable, Codable, CaseIterable {
    case measured = "MEASURED"
    case estimated = "ESTIMATED"
    case manufacturer = "MANUFACTURER"
    case benchmark = "BENCHMARK"
}

public struct OptimizationHints: Sendable, Codable, Hashable {
    public let preferredBatchSize: Int?
    public let useMixedPrecision: Bool
    public let enableQuantization: Bool
    public let cacheHints: CacheHints
    public let memoryAlignment: Int
    public let threadingConfig: ThreadingConfig
    
    public init(
        preferredBatchSize: Int? = nil,
        useMixedPrecision: Bool = true,
        enableQuantization: Bool = false,
        cacheHints: CacheHints = CacheHints(),
        memoryAlignment: Int = 64,
        threadingConfig: ThreadingConfig = ThreadingConfig()
    ) {
        self.preferredBatchSize = preferredBatchSize
        self.useMixedPrecision = useMixedPrecision
        self.enableQuantization = enableQuantization
        self.cacheHints = cacheHints
        self.memoryAlignment = memoryAlignment
        self.threadingConfig = threadingConfig
    }
}

public struct CacheHints: Sendable, Codable, Hashable {
    public let preferredSizeMB: Int
    public let lineSizeBytes: Int
    public let preferWriteBack: Bool
    
    public init(
        preferredSizeMB: Int = 16,
        lineSizeBytes: Int = 64,
        preferWriteBack: Bool = true
    ) {
        self.preferredSizeMB = preferredSizeMB
        self.lineSizeBytes = lineSizeBytes
        self.preferWriteBack = preferWriteBack
    }
}

public struct ThreadingConfig: Sendable, Codable, Hashable {
    public let preferredThreadCount: Int?
    public let useThreadAffinity: Bool
    public let threadPriority: ThreadPriority
    
    public init(
        preferredThreadCount: Int? = nil,
        useThreadAffinity: Bool = true,
        threadPriority: ThreadPriority = .normal
    ) {
        self.preferredThreadCount = preferredThreadCount
        self.useThreadAffinity = useThreadAffinity
        self.threadPriority = threadPriority
    }
}

public enum ThreadPriority: String, Sendable, Codable, CaseIterable {
    case low = "LOW"
    case normal = "NORMAL"
    case high = "HIGH"
    case realtime = "REALTIME"
}
