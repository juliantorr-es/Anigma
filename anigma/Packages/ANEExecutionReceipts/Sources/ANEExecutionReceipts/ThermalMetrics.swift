import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct ThermalMetrics: Sendable, Codable, Hashable {
    public let state: ProcessInfo.ThermalState
    public let temperature: Double?
    public let fanSpeed: Int?
    
    public init(
        state: ProcessInfo.ThermalState,
        temperature: Double?,
        fanSpeed: Int?
    ) {
        self.state = state
        self.temperature = temperature
        self.fanSpeed = fanSpeed
    }
    
    private enum CodingKeys: String, CodingKey {
        case stateRawValue
        case temperature
        case fanSpeed
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawState = try container.decode(Int.self, forKey: .stateRawValue)
        self.state = ProcessInfo.ThermalState(rawValue: rawState) ?? .nominal
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        self.fanSpeed = try container.decodeIfPresent(Int.self, forKey: .fanSpeed)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state.rawValue, forKey: .stateRawValue)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(fanSpeed, forKey: .fanSpeed)
    }
    
    public static func == (lhs: ThermalMetrics, rhs: ThermalMetrics) -> Bool {
        lhs.state.rawValue == rhs.state.rawValue &&
        lhs.temperature == rhs.temperature &&
        lhs.fanSpeed == rhs.fanSpeed
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(state.rawValue)
        hasher.combine(temperature)
        hasher.combine(fanSpeed)
    }
}
