import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct Signature: Sendable, Codable, Hashable {
    public let keyId: String
    public let algorithm: String
    public let value: String
    public let timestamp: Date
    
    public init(
        keyId: String,
        algorithm: String,
        value: String,
        timestamp: Date
    ) {
        self.keyId = keyId
        self.algorithm = algorithm
        self.value = value
        self.timestamp = timestamp
    }
}
