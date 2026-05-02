import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public enum ReceiptValidationError: Error, Sendable, LocalizedError {
    case validationFailed(result: ValidationResult)
    case invalidSignature(String)
    case hardwareEvidenceInvalid
    case performanceMetricsInvalid
    case timestampInvalid
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let result):
            return "CoreReceipt validation failed: \(result.issues.joined(separator: ", "))"
        case .invalidSignature(let reason):
            return "Invalid signature: \(reason)"
        case .hardwareEvidenceInvalid:
            return "Hardware evidence is invalid"
        case .performanceMetricsInvalid:
            return "Performance metrics are invalid"
        case .timestampInvalid:
            return "Timestamps are invalid"
        }
    }
}
