import Foundation
import ANEServicesCore
import CapsuleCore
import ANECapsuleContracts

public actor ANECapabilityRegistry {
    private var capabilities: [String: ANECapability] = [:]
    private var capsuleToCapability: [String: String] = [:] // capsuleId -> capabilityId
    
    public init() {}
    
    public func register(_ capability: ANECapability) {
        capabilities[capability.id] = capability
    }
    
    public func registerCapability(_ capability: ANECapability, forCapsule capsuleId: String) {
        register(capability)
        capsuleToCapability[capsuleId] = capability.id
    }
    
    public func capability(for id: String) -> ANECapability? {
        capabilities[id]
    }
    
    public func capability(forCapsule capsuleId: String) -> ANECapability? {
        guard let capabilityId = capsuleToCapability[capsuleId] else {
            return nil
        }
        return capabilities[capabilityId]
    }
    
    public func allCapabilities() -> [ANECapability] {
        Array(capabilities.values).sorted { $0.displayName < $1.displayName }
    }
    
    public func capabilities(byLevel level: ANECapabilityLevel) -> [ANECapability] {
        capabilities.values.filter { $0.level == level }
    }
    
    public func capabilities(forComputeUnit computeUnit: ANEComputeUnit) -> [ANECapability] {
        capabilities.values.filter { $0.canRunOn(computeUnit) }
    }
    
    public func findBestCapability(
        requiredLevel: ANECapabilityLevel? = nil,
        preferredComputeUnit: ANEComputeUnit? = nil,
        minPerformanceScore: Double? = nil,
        maxMemoryMB: Int? = nil
    ) -> ANECapability? {
        let filtered = capabilities.values.filter { capability in
            if let requiredLevel = requiredLevel, capability.level != requiredLevel {
                return false
            }
            if let preferredComputeUnit = preferredComputeUnit,
               !capability.canRunOn(preferredComputeUnit) {
                return false
            }
            if let minPerformanceScore = minPerformanceScore {
                let preferredUnit = preferredComputeUnit ?? capability.preferredComputeUnit
                if let profile = capability.performanceProfile[preferredUnit],
                   profile.score < minPerformanceScore {
                    return false
                }
            }
            if let maxMemoryMB = maxMemoryMB {
                let preferredUnit = preferredComputeUnit ?? capability.preferredComputeUnit
                if capability.memoryRequirement(for: preferredUnit) > maxMemoryMB {
                    return false
                }
            }
            return true
        }
        
        return filtered.sorted { a, b in
            let aScore = a.performanceProfile[a.preferredComputeUnit]?.score ?? 0
            let bScore = b.performanceProfile[b.preferredComputeUnit]?.score ?? 0
            return aScore > bScore
        }.first
    }
}
