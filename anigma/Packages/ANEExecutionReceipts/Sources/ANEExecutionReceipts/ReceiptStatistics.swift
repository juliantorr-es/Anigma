import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public struct ReceiptStatistics: Sendable, Codable {
    public let totalReceipts: Int
    public let validReceipts: Int
    public let expiredReceipts: Int
    public let receiptsByComputeUnit: [ANEComputeUnit: Int]
    public let receiptsByCapsule: [String: Int]
    public let averageExecutionDuration: TimeInterval?
    public let averagePowerConsumption: Double?
    public let generationTime: Date
    
    public init(
        totalReceipts: Int,
        validReceipts: Int,
        expiredReceipts: Int,
        receiptsByComputeUnit: [ANEComputeUnit: Int],
        receiptsByCapsule: [String: Int],
        averageExecutionDuration: TimeInterval?,
        averagePowerConsumption: Double?,
        generationTime: Date
    ) {
        self.totalReceipts = totalReceipts
        self.validReceipts = validReceipts
        self.expiredReceipts = expiredReceipts
        self.receiptsByComputeUnit = receiptsByComputeUnit
        self.receiptsByCapsule = receiptsByCapsule
        self.averageExecutionDuration = averageExecutionDuration
        self.averagePowerConsumption = averagePowerConsumption
        self.generationTime = generationTime
    }
}
