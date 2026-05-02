import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct HardwareEvidence: Sendable, Codable, Hashable {
    public let systemInfo: SystemInfo
    public let computeUnitInfo: ComputeUnitInfo
    public let attestation: HardwareAttestation
    public let collectionTime: Date
    
    public var isValid: Bool {
        // Check attestation validity
        guard attestation.generationTime <= Date() else { return false }
        guard !attestation.hash.isEmpty else { return false }
        
        // Check system info validity
        guard !systemInfo.osVersion.isEmpty else { return false }
        guard !systemInfo.architecture.isEmpty else { return false }
        
        return true
    }
    
    public init(
        systemInfo: SystemInfo,
        computeUnitInfo: ComputeUnitInfo,
        attestation: HardwareAttestation,
        collectionTime: Date
    ) {
        self.systemInfo = systemInfo
        self.computeUnitInfo = computeUnitInfo
        self.attestation = attestation
        self.collectionTime = collectionTime
    }
}
