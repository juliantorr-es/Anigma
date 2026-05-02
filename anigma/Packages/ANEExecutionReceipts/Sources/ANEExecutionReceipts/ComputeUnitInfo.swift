import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct ComputeUnitInfo: Sendable, Codable, Hashable {
    public let unitType: ANEComputeUnit
    public let availability: ComputeUnitAvailability
    public let capabilities: [String: AnyCodable]
    
    public init(
        unitType: ANEComputeUnit,
        availability: ComputeUnitAvailability,
        capabilities: [String: AnyCodable]
    ) {
        self.unitType = unitType
        self.availability = availability
        self.capabilities = capabilities
    }
    
    enum CodingKeys: String, CodingKey {
        case unitType
        case availability
        case capabilities
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(unitType)
        hasher.combine(availability)
    }
    
    public static func == (lhs: ComputeUnitInfo, rhs: ComputeUnitInfo) -> Bool {
        lhs.unitType == rhs.unitType && lhs.availability == rhs.availability
    }
}
