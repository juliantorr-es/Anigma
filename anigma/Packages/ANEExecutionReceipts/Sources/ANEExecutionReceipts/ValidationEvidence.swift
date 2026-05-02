import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct ValidationEvidence: Sendable, Codable, Hashable {
    public let inputHash: String
    public let outputHash: String
    public let capsuleHash: String
    public let computeUnitHash: String
    
    public init(
        inputHash: String,
        outputHash: String,
        capsuleHash: String,
        computeUnitHash: String
    ) {
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.capsuleHash = capsuleHash
        self.computeUnitHash = computeUnitHash
    }
}
