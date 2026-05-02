import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct CPUUsage: Sendable, Codable, Hashable {
    public let user: Double
    public let system: Double
    public let idle: Double
    public let collectionTime: Date
    
    public var total: Double {
        user + system + idle
    }
    
    public init(
        user: Double,
        system: Double,
        idle: Double,
        collectionTime: Date
    ) {
        self.user = user
        self.system = system
        self.idle = idle
        self.collectionTime = collectionTime
    }
}
