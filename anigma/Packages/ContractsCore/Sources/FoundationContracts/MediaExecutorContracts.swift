import Foundation
import AnigmaPrimitives

/// Output from a media decoding operation.
/// Contains a portable FrameReference and an audit proof of zero-copy continuity.
public struct DecodeOutput: Sendable, Codable {
    public let frame: FrameReference
    public let proof: ZeroCopyProof
    
    public init(frame: FrameReference, proof: ZeroCopyProof) {
        self.frame = frame
        self.proof = proof
    }
}

/// The primary contract-aware interface for all media transformation engines.
public protocol MediaExecutor: Sendable {
    /// Executes a governed media transformation contract.
    func execute(contract: any MediaContract) async throws -> MediaReference
}
