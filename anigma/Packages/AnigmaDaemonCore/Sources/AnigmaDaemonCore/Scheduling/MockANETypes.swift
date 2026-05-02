//
//  MockANETypes.swift
//  AnigmaDaemonCore
//
//  Mock types for ANE scheduling when full dependencies aren't available.
//

import Foundation

// MARK: - Mock ANE Types

/// Mock ANE compute unit
public enum MockANEComputeUnit: String, Sendable, Codable, CaseIterable {
    case cpu
    case gpu
    case neuralEngine
    case all
}

/// Mock ANE capability level
public enum MockANECapabilityLevel: String, Sendable, Codable, CaseIterable {
    case aneOnly = "ANE_ONLY"
    case mixed = "MIXED"
    case cpuOnly = "CPU_ONLY"
    
    public static func fromComputeUnits(_ units: Set<MockANEComputeUnit>) -> MockANECapabilityLevel {
        if units.contains(.neuralEngine) && units.count == 1 {
            return .aneOnly
        } else if units.contains(.cpu) && units.count == 1 {
            return .cpuOnly
        } else {
            return .mixed
        }
    }
}

/// Mock ANE capability
public struct MockANECapability: Sendable, Codable, Hashable {
    public let id: String
    public let displayName: String
    public let level: MockANECapabilityLevel
    public let supportedComputeUnits: Set<MockANEComputeUnit>
    public let preferredComputeUnit: MockANEComputeUnit
    public let supportsFallback: Bool
    
    public init(
        id: String,
        displayName: String,
        level: MockANECapabilityLevel,
        supportedComputeUnits: Set<MockANEComputeUnit>,
        preferredComputeUnit: MockANEComputeUnit,
        supportsFallback: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.level = level
        self.supportedComputeUnits = supportedComputeUnits
        self.preferredComputeUnit = preferredComputeUnit
        self.supportsFallback = supportsFallback
    }
    
    public func canRunOn(_ computeUnit: MockANEComputeUnit) -> Bool {
        if computeUnit == .all {
            return !supportedComputeUnits.isEmpty
        }
        return supportedComputeUnits.contains(computeUnit)
    }
    
    public func bestComputeUnit(
        preferred: MockANEComputeUnit? = nil,
        availableUnits: Set<MockANEComputeUnit> = Set(MockANEComputeUnit.allCases)
    ) -> MockANEComputeUnit? {
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
}

/// Mock default capabilities
public enum MockDefaultANECapabilities {
    public static let embeddingANEOnly = MockANECapability(
        id: "anigma.capability.embedding.ane_only",
        displayName: "ANE-Only Embedding",
        level: .aneOnly,
        supportedComputeUnits: [.neuralEngine],
        preferredComputeUnit: .neuralEngine,
        supportsFallback: false
    )
    
    public static let embeddingMixed = MockANECapability(
        id: "anigma.capability.embedding.mixed",
        displayName: "Mixed ANE/CPU Embedding",
        level: .mixed,
        supportedComputeUnits: [.neuralEngine, .cpu],
        preferredComputeUnit: .neuralEngine,
        supportsFallback: true
    )
    
    public static let cpuOnly = MockANECapability(
        id: "anigma.capability.cpu_only",
        displayName: "CPU-Only Computation",
        level: .cpuOnly,
        supportedComputeUnits: [.cpu],
        preferredComputeUnit: .cpu,
        supportsFallback: false
    )
    
    public static func defaultForLevel(_ level: MockANECapabilityLevel) -> MockANECapability {
        switch level {
        case .aneOnly:
            return embeddingANEOnly
        case .mixed:
            return embeddingMixed
        case .cpuOnly:
            return cpuOnly
        }
    }
}

/// Mock capability registry
public actor MockANECapabilityRegistry {
    private var capabilities: [String: MockANECapability] = [:]
    
    public init() {
        self.capabilities = [
            MockDefaultANECapabilities.embeddingANEOnly.id: MockDefaultANECapabilities.embeddingANEOnly,
            MockDefaultANECapabilities.embeddingMixed.id: MockDefaultANECapabilities.embeddingMixed,
            MockDefaultANECapabilities.cpuOnly.id: MockDefaultANECapabilities.cpuOnly
        ]
    }
    
    public func register(_ capability: MockANECapability) {
        capabilities[capability.id] = capability
    }
    
    public func capability(for id: String) -> MockANECapability? {
        capabilities[id]
    }
    
    public func allCapabilities() -> [MockANECapability] {
        Array(capabilities.values).sorted { $0.displayName < $1.displayName }
    }
    
    public func capabilities(byLevel level: MockANECapabilityLevel) -> [MockANECapability] {
        capabilities.values.filter { $0.level == level }
    }
    
    public func capabilities(forComputeUnit computeUnit: MockANEComputeUnit) -> [MockANECapability] {
        capabilities.values.filter { $0.canRunOn(computeUnit) }
    }
    
    public func findBestCapability(
        requiredLevel: MockANECapabilityLevel? = nil,
        preferredComputeUnit: MockANEComputeUnit? = nil,
        minPerformanceScore: Double? = nil,
        maxMemoryMB: Int? = nil
    ) -> MockANECapability? {
        let filtered = capabilities.values.filter { capability in
            if let requiredLevel = requiredLevel, capability.level != requiredLevel {
                return false
            }
            
            if let preferredComputeUnit = preferredComputeUnit,
               !capability.canRunOn(preferredComputeUnit) {
                return false
            }
            
            return true
        }
        
        return filtered.first
    }
}

/// Mock CoreML artifact contract
public struct MockCoreMLArtifactContract: Sendable, Codable {
    public let id: String
    public let artifactPath: String
    public let modelType: String
    public let version: String
    public let supportedComputeUnits: [String]
    public let metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        artifactPath: String,
        modelType: String,
        version: String = "1.0.0",
        supportedComputeUnits: [String] = ["cpu", "gpu", "neuralEngine"],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.artifactPath = artifactPath
        self.modelType = modelType
        self.version = version
        self.supportedComputeUnits = supportedComputeUnits
        self.metadata = metadata
    }
}

/// Mock placement verifier
public actor MockPlacementVerifier {
    public init() {}
    
    public func verifyPlacement(
        capability: MockANECapability,
        computeUnit: MockANEComputeUnit
    ) -> Bool {
        return capability.canRunOn(computeUnit)
    }
}

/// Mock execution receipt manager
public actor MockExecutionReceiptManager {
    public init() {}
    
    public func generateReceipt(
        forJob jobId: String,
        computeUnit: MockANEComputeUnit,
        success: Bool
    ) -> MockExecutionReceipt {
        return MockExecutionReceipt(
            id: UUID().uuidString,
            jobId: jobId,
            computeUnit: computeUnit,
            success: success,
            timestamp: Date()
        )
    }
}

/// Mock execution receipt
public struct MockExecutionReceipt: Sendable, Codable {
    public let id: String
    public let jobId: String
    public let computeUnit: MockANEComputeUnit
    public let success: Bool
    public let timestamp: Date
    
    public init(
        id: String,
        jobId: String,
        computeUnit: MockANEComputeUnit,
        success: Bool,
        timestamp: Date
    ) {
        self.id = id
        self.jobId = jobId
        self.computeUnit = computeUnit
        self.success = success
        self.timestamp = timestamp
    }
}

/// Mock thermal monitor
public actor MockThermalMonitor {
    public struct ThermalState: Sendable, Codable {
        public let temperature: Double
        public let timestamp: Date
        public let thermalPressure: ThermalPressure
        
        public init(
            temperature: Double = 0.0,
            timestamp: Date = Date(),
            thermalPressure: ThermalPressure = .nominal
        ) {
            self.temperature = temperature
            self.timestamp = timestamp
            self.thermalPressure = thermalPressure
        }
    }
    
    public enum ThermalPressure: String, Sendable, Codable, CaseIterable {
        case nominal = "NOMINAL"
        case moderate = "MODERATE"
        case heavy = "HEAVY"
        case critical = "CRITICAL"
    }
    
    public private(set) var currentState: ThermalState
    
    public init() {
        self.currentState = ThermalState()
    }
    
    public func update() {
        let temperature = Double.random(in: 30...90)
        let pressure: ThermalPressure
        
        switch temperature {
        case ..<50: pressure = .nominal
        case 50..<70: pressure = .moderate
        case 70..<85: pressure = .heavy
        default: pressure = .critical
        }
        
        currentState = ThermalState(
            temperature: temperature,
            timestamp: Date(),
            thermalPressure: pressure
        )
    }
}

/// Mock power monitor
public actor MockPowerMonitor {
    public struct PowerConsumption: Sendable, Codable {
        public let currentWatts: Double
        public let timestamp: Date
        public let powerState: PowerState
        
        public init(
            currentWatts: Double = 0.0,
            timestamp: Date = Date(),
            powerState: PowerState = .normal
        ) {
            self.currentWatts = currentWatts
            self.timestamp = timestamp
            self.powerState = powerState
        }
    }
    
    public enum PowerState: String, Sendable, Codable, CaseIterable {
        case normal = "NORMAL"
        case elevated = "ELEVATED"
        case high = "HIGH"
        case critical = "CRITICAL"
    }
    
    public private(set) var currentConsumption: PowerConsumption
    
    public init() {
        self.currentConsumption = PowerConsumption()
    }
    
    public func update() {
        let watts = Double.random(in: 0...15)
        let state: PowerState
        
        switch watts {
        case ..<5: state = .normal
        case 5..<10: state = .elevated
        case 10..<13: state = .high
        default: state = .critical
        }
        
        currentConsumption = PowerConsumption(
            currentWatts: watts,
            timestamp: Date(),
            powerState: state
        )
    }
}
