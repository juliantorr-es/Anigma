import Foundation
import ANEServicesCore

public struct SystemCompatibility: Sendable, Codable {
    public let computeUnit: ANEComputeUnit
    public let isCompatible: Bool
    public let issues: [String]
    public let warnings: [String]
    
    public init(
        computeUnit: ANEComputeUnit,
        isCompatible: Bool,
        issues: [String],
        warnings: [String]
    ) {
        self.computeUnit = computeUnit
        self.isCompatible = isCompatible
        self.issues = issues
        self.warnings = warnings
    }
}

public struct ResourceAvailability: Sendable, Codable {
    public let computeUnit: ANEComputeUnit
    public let isAvailable: Bool
    public let issues: [String]
    public let warnings: [String]
    public let metrics: [String: Double]
    
    public init(
        computeUnit: ANEComputeUnit,
        isAvailable: Bool,
        issues: [String],
        warnings: [String],
        metrics: [String: Double] = [:]
    ) {
        self.computeUnit = computeUnit
        self.isAvailable = isAvailable
        self.issues = issues
        self.warnings = warnings
        self.metrics = metrics
    }
}

public struct PerformanceEstimate: Sendable, Codable {
    public let latencyMs: Double
    public let throughput: Double // items per second
    public let confidence: Double // 0.0 to 1.0
    
    public init(
        latencyMs: Double,
        throughput: Double,
        confidence: Double
    ) {
        self.latencyMs = latencyMs
        self.throughput = throughput
        self.confidence = confidence
    }
}
