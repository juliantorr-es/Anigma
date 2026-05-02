import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

public actor ExecutionReceiptManager {
    private var receipts: [String: ExecutionReceipt] = [:]
    private let maxReceipts = 1000
    
    public init() {}
    
    /// Store a receipt
    public func store(_ receipt: ExecutionReceipt) {
        receipts[receipt.receiptId] = receipt
        
        // Enforce maximum limit
        if receipts.count > maxReceipts {
            // Remove oldest receipts
            let sorted = receipts.values.sorted { $0.receiptGenerationTime < $1.receiptGenerationTime }
            let toRemove = sorted.prefix(receipts.count - maxReceipts)
            for receipt in toRemove {
                receipts.removeValue(forKey: receipt.receiptId)
            }
        }
    }
    
    /// Get a receipt by ID
    public func getReceipt(_ id: String) -> ExecutionReceipt? {
        receipts[id]
    }
    
    /// Get all receipts
    public func getAllReceipts() -> [ExecutionReceipt] {
        Array(receipts.values).sorted { $0.receiptGenerationTime > $1.receiptGenerationTime }
    }
    
    /// Get receipts for a capsule
    public func getReceipts(forCapsule capsuleId: String) -> [ExecutionReceipt] {
        receipts.values
            .filter { $0.capsuleId == capsuleId }
            .sorted { $0.receiptGenerationTime > $1.receiptGenerationTime }
    }
    
    /// Get receipts by compute unit
    public func getReceipts(byComputeUnit computeUnit: ANEComputeUnit) -> [ExecutionReceipt] {
        receipts.values
            .filter { $0.computeUnit == computeUnit }
            .sorted { $0.receiptGenerationTime > $1.receiptGenerationTime }
    }
    
    /// Validate all receipts
    public func validateAllReceipts() async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        for receipt in receipts.values {
            do {
                let result = try await receipt.validate()
                results.append(result)
            } catch {
                let errorResult = ValidationResult(
                    isValid: false,
                    issues: [error.localizedDescription],
                    warnings: [],
                    validationTime: Date()
                )
                results.append(errorResult)
            }
        }
        
        return results
    }
    
    /// Clean up expired receipts
    public func cleanupExpiredReceipts() -> Int {
        let expired = receipts.values.filter { $0.isExpired }
        for receipt in expired {
            receipts.removeValue(forKey: receipt.receiptId)
        }
        return expired.count
    }
    
    /// Generate statistics
    public func generateStatistics() -> ReceiptStatistics {
        let allReceipts = Array(receipts.values)
        
        let totalReceipts = allReceipts.count
        let validReceipts = allReceipts.filter { $0.status == .valid }.count
        let expiredReceipts = allReceipts.filter { $0.isExpired }.count
        
        let byComputeUnit = Dictionary(grouping: allReceipts, by: { $0.computeUnit })
            .mapValues { $0.count }
        
        let byCapsule = Dictionary(grouping: allReceipts, by: { $0.capsuleId })
            .mapValues { $0.count }
        
        let durations = allReceipts.map { $0.executionDuration }
        let averageDuration = durations.isEmpty ? nil : durations.reduce(0, +) / TimeInterval(durations.count)
        
        let powers = allReceipts.compactMap { $0.performanceMetrics.powerWatts }
        let averagePower = powers.isEmpty ? nil : powers.reduce(0, +) / Double(powers.count)
        
        return ReceiptStatistics(
            totalReceipts: totalReceipts,
            validReceipts: validReceipts,
            expiredReceipts: expiredReceipts,
            receiptsByComputeUnit: byComputeUnit,
            receiptsByCapsule: byCapsule,
            averageExecutionDuration: averageDuration,
            averagePowerConsumption: averagePower,
            generationTime: Date()
        )
    }
}
