import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct PowerMetrics: Sendable, Codable, Hashable {
    public let powerWatts: Double
    public let voltage: Double?
    public let current: Double?
    public let collectionTime: Date
    
    public init(
        powerWatts: Double,
        voltage: Double?,
        current: Double?,
        collectionTime: Date
    ) {
        self.powerWatts = powerWatts
        self.voltage = voltage
        self.current = current
        self.collectionTime = collectionTime
    }
}
