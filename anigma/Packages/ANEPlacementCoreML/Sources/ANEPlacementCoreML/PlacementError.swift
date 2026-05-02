import Foundation
import ANEServicesCore
import CoreML

public enum PlacementError: Error, Sendable, LocalizedError {
    case gated(capsuleId: String, reason: String)
    case deprecated(capsuleId: String, reason: String)
    case unsupportedComputeUnit(capsuleId: String, requested: ANEComputeUnit, supported: Set<ANEComputeUnit>)
    case systemIncompatible(computeUnit: ANEComputeUnit, reasons: [String])
    case resourceUnavailable(computeUnit: ANEComputeUnit, reasons: [String])
    case modelLoadFailed(modelURL: URL, error: Error)
    case coreMLNotAvailable
    
    public var errorDescription: String? {
        switch self {
        case .gated(let capsuleId, let reason):
            return "Capsule '\(capsuleId)' placement gated: \(reason)"
        case .deprecated(let capsuleId, let reason):
            return "Capsule '\(capsuleId)' deprecated: \(reason)"
        case .unsupportedComputeUnit(let capsuleId, let requested, let supported):
            return "Capsule '\(capsuleId)' does not support compute unit '\(requested)'. Supported: \(supported)"
        case .systemIncompatible(let computeUnit, let reasons):
            return "System incompatible with compute unit '\(computeUnit)': \(reasons.joined(separator: ", "))"
        case .resourceUnavailable(let computeUnit, let reasons):
            return "Resources unavailable for compute unit '\(computeUnit)': \(reasons.joined(separator: ", "))"
        case .modelLoadFailed(let modelURL, let error):
            return "Failed to load CoreML model at \(modelURL): \(error.localizedDescription)"
        case .coreMLNotAvailable:
            return "CoreML not available on this platform"
        }
    }
}
