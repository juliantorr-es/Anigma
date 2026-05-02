import Foundation
import ANEServicesCore

public struct PlacementConstraints: Sendable, Codable {
    public let preferredComputeUnit: ANEComputeUnit?
    public let maxPowerWatts: Double?
    public let maxMemoryMB: Int?
    public let minPerformanceScore: Double?
    public let requireANE: Bool
    public let allowFallback: Bool
    
    public init(
        preferredComputeUnit: ANEComputeUnit? = nil,
        maxPowerWatts: Double? = nil,
        maxMemoryMB: Int? = nil,
        minPerformanceScore: Double? = nil,
        requireANE: Bool = false,
        allowFallback: Bool = true
    ) {
        self.preferredComputeUnit = preferredComputeUnit
        self.maxPowerWatts = maxPowerWatts
        self.maxMemoryMB = maxMemoryMB
        self.minPerformanceScore = minPerformanceScore
        self.requireANE = requireANE
        self.allowFallback = allowFallback
    }
}

public struct PlacementRecommendation: Sendable, Codable {
    public let capsuleId: String
    public let recommendations: [ComputeUnitRecommendation]
    public let constraints: PlacementConstraints
    public let timestamp: Date
    
    public init(
        capsuleId: String,
        recommendations: [ComputeUnitRecommendation],
        constraints: PlacementConstraints,
        timestamp: Date = Date()
    ) {
        self.capsuleId = capsuleId
        self.recommendations = recommendations
        self.constraints = constraints
        self.timestamp = timestamp
    }
    
    public var bestRecommendation: ComputeUnitRecommendation? {
        recommendations.first
    }
}

public struct ComputeUnitRecommendation: Sendable, Codable {
    public let computeUnit: ANEComputeUnit
    public let score: Double
    public let compatibility: SystemCompatibility
    public let resourceAvailability: ResourceAvailability
    public let estimatedPerformance: PerformanceEstimate
    public let estimatedPower: Double
    
    public init(
        computeUnit: ANEComputeUnit,
        score: Double,
        compatibility: SystemCompatibility,
        resourceAvailability: ResourceAvailability,
        estimatedPerformance: PerformanceEstimate,
        estimatedPower: Double
    ) {
        self.computeUnit = computeUnit
        self.score = score
        self.compatibility = compatibility
        self.resourceAvailability = resourceAvailability
        self.estimatedPerformance = estimatedPerformance
        self.estimatedPower = estimatedPower
    }
}
