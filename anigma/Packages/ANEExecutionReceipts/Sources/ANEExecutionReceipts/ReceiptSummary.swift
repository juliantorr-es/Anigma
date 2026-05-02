import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct ReceiptSummary: Sendable, Codable {
    public let receiptId: String
    public let capsuleId: String
    public let computeUnit: ANEComputeUnit
    public let executionDuration: TimeInterval
    public let powerConsumption: Double
    public let memoryUsage: Int
    public let status: ReceiptStatus
    public let isValid: Bool
    
    public init(
        receiptId: String,
        capsuleId: String,
        computeUnit: ANEComputeUnit,
        executionDuration: TimeInterval,
        powerConsumption: Double,
        memoryUsage: Int,
        status: ReceiptStatus,
        isValid: Bool
    ) {
        self.receiptId = receiptId
        self.capsuleId = capsuleId
        self.computeUnit = computeUnit
        self.executionDuration = executionDuration
        self.powerConsumption = powerConsumption
        self.memoryUsage = memoryUsage
        self.status = status
        self.isValid = isValid
    }
}
