import Foundation
import ANEServicesCore

/// ANE capsule capability levels for compute unit allocation
public enum ANECapabilityLevel: String, Codable, Sendable, CaseIterable {
    /// Capsule requires ANE and cannot run on CPU/GPU
    case aneOnly = "ANE_ONLY"

    /// Capsule can run on ANE but has CPU/GPU fallback
    case mixed = "MIXED"

    /// Capsule runs on CPU only (ANE not supported)
    case cpuOnly = "CPU_ONLY"

    /// Determine capability level from supported compute units
    public static func fromComputeUnits(_ units: Set<ANEComputeUnit>) -> ANECapabilityLevel {
        if units.contains(.neuralEngine) && units.count == 1 {
            return .aneOnly
        } else if units.contains(.neuralEngine) && units.count > 1 {
            return .mixed
        } else {
            return .cpuOnly
        }
    }
}
