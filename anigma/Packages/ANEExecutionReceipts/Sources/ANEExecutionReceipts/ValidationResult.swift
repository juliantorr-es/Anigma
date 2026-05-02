import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct ValidationResult: Sendable, Codable {
    public let isValid: Bool
    public let issues: [String]
    public let warnings: [String]
    public let validationTime: Date
    
    public init(
        isValid: Bool,
        issues: [String],
        warnings: [String],
        validationTime: Date
    ) {
        self.isValid = isValid
        self.issues = issues
        self.warnings = warnings
        self.validationTime = validationTime
    }
}
