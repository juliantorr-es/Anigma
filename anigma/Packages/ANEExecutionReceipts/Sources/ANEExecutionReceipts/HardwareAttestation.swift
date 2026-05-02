import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct HardwareAttestation: Sendable, Codable, Hashable {
    public let hash: String
    public let generationTime: Date
    public let attestationType: String
    
    public init(
        hash: String,
        generationTime: Date,
        attestationType: String
    ) {
        self.hash = hash
        self.generationTime = generationTime
        self.attestationType = attestationType
    }
}
