import Foundation
import ANEServicesCore
import CapsuleCore

// MARK: - Re-exported Modules
@_exported import ANECapsuleContracts
@_exported import ANECapabilityCatalog
@_exported import ANEExecutionReceipts
@_exported import ANEPlacementCoreML

/// Protocol for ANE-optimized capsules providing descriptor-based offloading
public protocol ANECapsuleBase {
    /// Associated descriptor for the ANE capsule
    static var aneDescriptor: ANECapsuleDescriptor { get }
}

extension ANECapsuleBase {
    /// Validate that the capsule can run on the requested compute unit
    public func validatePlacement(requestedComputeUnit: ANEComputeUnit) throws {
        let descriptor = Self.aneDescriptor
        
        guard descriptor.supportedComputeUnits.contains(requestedComputeUnit) else {
            throw ANECapsuleError.unsupportedComputeUnit(
                capsuleId: descriptor.id,
                requested: requestedComputeUnit,
                supported: descriptor.supportedComputeUnits
            )
        }
        
        // Check gate status
        switch descriptor.gate.status {
        case .gated:
            throw ANECapsuleError.gated(
                capsuleId: descriptor.id,
                reason: descriptor.gate.reason ?? "Access gated"
            )
        case .deprecated:
            throw ANECapsuleError.deprecated(
                capsuleId: descriptor.id,
                reason: descriptor.gate.reason ?? "Capsule deprecated"
            )
        case .experimental:
            // Allow experimental but log warning
            break
        case .open:
            // Open gates are fine
            break
        }
    }
}
