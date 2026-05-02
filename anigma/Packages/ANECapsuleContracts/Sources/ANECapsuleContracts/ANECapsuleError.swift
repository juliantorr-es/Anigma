import Foundation
import ANEServicesCore

/// ANE capsule errors
public enum ANECapsuleError: Error, Sendable, LocalizedError {
    case unsupportedComputeUnit(
        capsuleId: String,
        requested: ANEComputeUnit,
        supported: Set<ANEComputeUnit>
    )
    case gated(capsuleId: String, reason: String)
    case deprecated(capsuleId: String, reason: String)
    case activationFailed(capsuleId: String, underlyingError: Error)
    case executionFailed(capsuleId: String, underlyingError: Error)
    case fallbackNotSupported(capsuleId: String)
    case receiptGenerationFailed(capsuleId: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedComputeUnit(let capsuleId, let requested, let supported):
            return "Capsule '\(capsuleId)' does not support compute unit '\(requested)'. Supported: \(supported)"
        case .gated(let capsuleId, let reason):
            return "Capsule '\(capsuleId)' is gated: \(reason)"
        case .deprecated(let capsuleId, let reason):
            return "Capsule '\(capsuleId)' is deprecated: \(reason)"
        case .activationFailed(let capsuleId, let error):
            return "Failed to activate capsule '\(capsuleId)': \(error.localizedDescription)"
        case .executionFailed(let capsuleId, let error):
            return "Failed to execute capsule '\(capsuleId)': \(error.localizedDescription)"
        case .fallbackNotSupported(let capsuleId):
            return "Capsule '\(capsuleId)' does not support CPU fallback"
        case .receiptGenerationFailed(let capsuleId, let reason):
            return "Failed to generate receipt for capsule '\(capsuleId)': \(reason)"
        }
    }
}
