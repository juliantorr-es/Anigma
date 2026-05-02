import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct SystemInfo: Sendable, Codable, Hashable {
    public let osVersion: String
    public let architecture: String
    public let modelIdentifier: String
    public let thermalState: ProcessInfo.ThermalState
    public let lowPowerMode: Bool
    
    public init(
        osVersion: String,
        architecture: String,
        modelIdentifier: String,
        thermalState: ProcessInfo.ThermalState,
        lowPowerMode: Bool
    ) {
        self.osVersion = osVersion
        self.architecture = architecture
        self.modelIdentifier = modelIdentifier
        self.thermalState = thermalState
        self.lowPowerMode = lowPowerMode
    }
    
    private enum CodingKeys: String, CodingKey {
        case osVersion
        case architecture
        case modelIdentifier
        case thermalStateRawValue
        case lowPowerMode
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.osVersion = try container.decode(String.self, forKey: .osVersion)
        self.architecture = try container.decode(String.self, forKey: .architecture)
        self.modelIdentifier = try container.decode(String.self, forKey: .modelIdentifier)
        let rawThermalState = try container.decode(Int.self, forKey: .thermalStateRawValue)
        self.thermalState = ProcessInfo.ThermalState(rawValue: rawThermalState) ?? .nominal
        self.lowPowerMode = try container.decode(Bool.self, forKey: .lowPowerMode)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(modelIdentifier, forKey: .modelIdentifier)
        try container.encode(thermalState.rawValue, forKey: .thermalStateRawValue)
        try container.encode(lowPowerMode, forKey: .lowPowerMode)
    }
    
    public static func == (lhs: SystemInfo, rhs: SystemInfo) -> Bool {
        lhs.osVersion == rhs.osVersion &&
        lhs.architecture == rhs.architecture &&
        lhs.modelIdentifier == rhs.modelIdentifier &&
        lhs.thermalState.rawValue == rhs.thermalState.rawValue &&
        lhs.lowPowerMode == rhs.lowPowerMode
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(osVersion)
        hasher.combine(architecture)
        hasher.combine(modelIdentifier)
        hasher.combine(thermalState.rawValue)
        hasher.combine(lowPowerMode)
    }
}
