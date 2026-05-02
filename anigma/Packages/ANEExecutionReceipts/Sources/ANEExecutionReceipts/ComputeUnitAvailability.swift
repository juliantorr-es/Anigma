import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public enum ComputeUnitAvailability: Sendable, Codable, Hashable {
    case available
    case unavailable(reason: String)
    case partial(availableUnits: [ANEComputeUnit])
    
    public var isAvailable: Bool {
        switch self {
        case .available:
            return true
        case .unavailable:
            return false
        case .partial:
            return true
        }
    }
}
