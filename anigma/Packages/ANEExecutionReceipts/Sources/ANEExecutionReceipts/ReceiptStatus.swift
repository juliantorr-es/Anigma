import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public enum ReceiptStatus: String, Sendable, Codable, CaseIterable {
    case valid = "VALID"
    case invalid = "INVALID"
    case expired = "EXPIRED"
    case pending = "PENDING"
    case revoked = "REVOKED"
}
