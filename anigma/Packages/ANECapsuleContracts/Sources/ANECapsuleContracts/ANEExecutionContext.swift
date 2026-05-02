import Foundation
import ANEServicesCore

/// Execution context for ANE workloads
public struct ANEExecutionContext: Sendable {
    public let computeUnit: ANEComputeUnit
    public let priority: ANEExecutionPriority
    public let allowFallback: Bool
    public let maxRetries: Int
    
    public init(
        computeUnit: ANEComputeUnit = .neuralEngine,
        priority: ANEExecutionPriority = .interactive,
        allowFallback: Bool = true,
        maxRetries: Int = 1
    ) {
        self.computeUnit = computeUnit
        self.priority = priority
        self.allowFallback = allowFallback
        self.maxRetries = maxRetries
    }
    
    /// Create context from runtime profile
    public init(profile: ANERuntimeProfile) {
        self.computeUnit = profile.computeUnit
        self.priority = profile.priority
        self.allowFallback = profile.allowFallback
        self.maxRetries = 1 // Profile doesn't specify retries
    }
}
