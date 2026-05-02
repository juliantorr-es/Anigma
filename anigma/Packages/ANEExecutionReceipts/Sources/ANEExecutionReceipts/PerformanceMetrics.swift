import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct PerformanceMetrics: Sendable, Codable, Hashable {
    public let executionTime: TimeInterval
    public let cpuUsage: CPUUsage
    public let memoryUsageMB: Int
    public let powerWatts: Double
    public let thermalMetrics: ThermalMetrics
    public let collectionTime: Date
    
    public init(
        executionTime: TimeInterval,
        cpuUsage: CPUUsage,
        memoryUsageMB: Int,
        powerWatts: Double,
        thermalMetrics: ThermalMetrics,
        collectionTime: Date
    ) {
        self.executionTime = executionTime
        self.cpuUsage = cpuUsage
        self.memoryUsageMB = memoryUsageMB
        self.powerWatts = powerWatts
        self.thermalMetrics = thermalMetrics
        self.collectionTime = collectionTime
    }
}
