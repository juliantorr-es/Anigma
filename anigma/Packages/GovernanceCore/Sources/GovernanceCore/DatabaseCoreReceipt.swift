//
//  DatabaseCoreReceipt.swift
//  GovernanceCore
//
//  Cryptographic receipts for database mutations.
//  Every SQL write operation generates a receipt linking session, principal, and mutation hash.
//

import Foundation
import Crypto

// MARK: - Receipt Types

/// Cryptographic receipt for a database mutation
public struct DatabaseCoreReceipt: Codable {
    /// Unique receipt ID (UUID)
    public let receiptID: String
    
    /// PostgresNIO session ID
    public let sessionID: String
    
    /// Principal/caller identity
    public let principalID: String
    
    /// SQL operation type (INSERT, UPDATE, DELETE)
    public let operationType: String
    
    /// Affected table name
    public let tableName: String
    
    /// Hash of the SQL statement (SHA256)
    public let statementHash: String
    
    /// Number of rows affected
    public let rowsAffected: Int
    
    /// Timestamp of mutation
    public let timestamp: Date
    
    /// Hash of previous receipt (for chain integrity)
    public let previousReceiptHash: String?
    
    /// BLAKE3 HMAC signature over all fields
    public let signature: String
    
    public init(
        receiptID: String = UUID().uuidString,
        sessionID: String,
        principalID: String,
        operationType: String,
        tableName: String,
        statementHash: String,
        rowsAffected: Int,
        timestamp: Date = Date(),
        previousReceiptHash: String? = nil,
        signature: String
    ) {
        self.receiptID = receiptID
        self.sessionID = sessionID
        self.principalID = principalID
        self.operationType = operationType
        self.tableName = tableName
        self.statementHash = statementHash
        self.rowsAffected = rowsAffected
        self.timestamp = timestamp
        self.previousReceiptHash = previousReceiptHash
        self.signature = signature
    }
}

// MARK: - Evidence Chain

/// Immutable linked list of database receipts
public class DatabaseEvidenceChain {
    private var receipts: [DatabaseCoreReceipt] = []
    private var receiptsByID: [String: DatabaseCoreReceipt] = [:]
    private var lastReceiptHash: String?
    private let lock = NSLock()
    private let hmacKey: SymmetricKey
    
    public init(hmacKey: SymmetricKey? = nil) {
        self.hmacKey = hmacKey ?? SymmetricKey(size: .bits256)
    }
    
    /// Add receipt to chain (validates cryptographic linking)
    public func add(_ receipt: DatabaseCoreReceipt) throws {
        lock.lock()
        defer { lock.unlock() }
        
        // Verify signature
        try verifyReceiptSignature(receipt)
        
        // Verify chain link
        if let lastHash = lastReceiptHash {
            guard receipt.previousReceiptHash == lastHash else {
                throw EvidenceChainError.chainLinkBroken(
                    "Receipt chain broken: expected previous hash \(lastHash), got \(receipt.previousReceiptHash ?? "nil")"
                )
            }
        } else {
            guard receipt.previousReceiptHash == nil else {
                throw EvidenceChainError.chainLinkBroken("First receipt should not have previousReceiptHash")
            }
        }
        
        receipts.append(receipt)
        receiptsByID[receipt.receiptID] = receipt
        lastReceiptHash = hashReceipt(receipt)
    }
    
    /// Get receipt by ID
    public func get(_ receiptID: String) -> DatabaseCoreReceipt? {
        lock.lock()
        defer { lock.unlock() }
        return receiptsByID[receiptID]
    }
    
    /// Get all receipts in chain (immutable snapshot)
    public func allReceipts() -> [DatabaseCoreReceipt] {
        lock.lock()
        defer { lock.unlock() }
        return receipts
    }
    
    /// Get receipts by principal
    public func receiptsByPrincipal(_ principalID: String) -> [DatabaseCoreReceipt] {
        lock.lock()
        defer { lock.unlock() }
        return receipts.filter { $0.principalID == principalID }
    }
    
    /// Get receipts by session
    public func receiptsBySession(_ sessionID: String) -> [DatabaseCoreReceipt] {
        lock.lock()
        defer { lock.unlock() }
        return receipts.filter { $0.sessionID == sessionID }
    }
    
    /// Get receipts by table
    public func receiptsByTable(_ tableName: String) -> [DatabaseCoreReceipt] {
        lock.lock()
        defer { lock.unlock() }
        return receipts.filter { $0.tableName == tableName }
    }
    
    /// Verify integrity of entire chain
    public func verifyIntegrity() throws {
        lock.lock()
        defer { lock.unlock() }
        
        var previousHash: String? = nil
        
        for receipt in receipts {
            try verifyReceiptSignature(receipt)
            
            // Verify chain link
            guard receipt.previousReceiptHash == previousHash else {
                throw EvidenceChainError.chainLinkBroken(
                    "Chain broken at receipt \(receipt.receiptID)"
                )
            }
            
            previousHash = hashReceipt(receipt)
        }
    }
    
    // MARK: - Private Helpers
    
    private func verifyReceiptSignature(_ receipt: DatabaseCoreReceipt) throws {
        let payload = try createReceiptPayload(receipt)
        let signature = HMAC<SHA256>.authenticationCode(
            for: payload,
            using: hmacKey
        )
        
        let expectedSignature = Data(signature).base64EncodedString()
        guard receipt.signature == expectedSignature else {
            throw EvidenceChainError.invalidSignature(
                "Receipt \(receipt.receiptID) has invalid signature"
            )
        }
    }
    
    private func createReceiptPayload(_ receipt: DatabaseCoreReceipt) throws -> Data {
        var payload = ""
        payload += receipt.receiptID
        payload += "|" + receipt.sessionID
        payload += "|" + receipt.principalID
        payload += "|" + receipt.operationType
        payload += "|" + receipt.tableName
        payload += "|" + receipt.statementHash
        payload += "|" + String(receipt.rowsAffected)
        payload += "|" + ISO8601DateFormatter().string(from: receipt.timestamp)
        if let prevHash = receipt.previousReceiptHash {
            payload += "|" + prevHash
        }
        
        return payload.data(using: .utf8) ?? Data()
    }
    
    private func hashReceipt(_ receipt: DatabaseCoreReceipt) -> String {
        let digest = SHA256.hash(data: (receipt.signature).data(using: .utf8) ?? Data())
        return Data(digest).base64EncodedString()
    }
}

// MARK: - Receipt Generator

public class DatabaseReceiptGenerator {
    private let chain: DatabaseEvidenceChain
    private let hmacKey: SymmetricKey
    
    public init(chain: DatabaseEvidenceChain, hmacKey: SymmetricKey? = nil) {
        self.chain = chain
        self.hmacKey = hmacKey ?? SymmetricKey(size: .bits256)
    }
    
    /// Generate receipt for a database mutation
    public func generateReceipt(
        sessionID: String,
        principalID: String,
        operationType: String,
        tableName: String,
        sqlStatement: String,
        rowsAffected: Int
    ) throws -> DatabaseCoreReceipt {
        let statementHash = SHA256.hash(data: sqlStatement.data(using: .utf8) ?? Data())
        let statementHashStr = Data(statementHash).base64EncodedString()
        
        let previousHash = chain.allReceipts().last.flatMap { Data(SHA256.hash(data: $0.signature.data(using: .utf8) ?? Data())).base64EncodedString() }
        
        let receiptID = UUID().uuidString
        var payload = ""
        payload += receiptID
        payload += "|" + sessionID
        payload += "|" + principalID
        payload += "|" + operationType
        payload += "|" + tableName
        payload += "|" + statementHashStr
        payload += "|" + String(rowsAffected)
        payload += "|" + ISO8601DateFormatter().string(from: Date())
        if let prevHash = previousHash {
            payload += "|" + prevHash
        }
        
        let payloadData = payload.data(using: .utf8) ?? Data()
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: hmacKey)
        let signatureStr = Data(signature).base64EncodedString()
        
        let receipt = DatabaseCoreReceipt(
            receiptID: receiptID,
            sessionID: sessionID,
            principalID: principalID,
            operationType: operationType,
            tableName: tableName,
            statementHash: statementHashStr,
            rowsAffected: rowsAffected,
            previousReceiptHash: previousHash,
            signature: signatureStr
        )
        
        // Add to chain
        try chain.add(receipt)
        
        return receipt
    }
    
    private func createReceiptPayload(_ receipt: DatabaseCoreReceipt) throws -> Data {
        var payload = ""
        payload += receipt.receiptID
        payload += "|" + receipt.sessionID
        payload += "|" + receipt.principalID
        payload += "|" + receipt.operationType
        payload += "|" + receipt.tableName
        payload += "|" + receipt.statementHash
        payload += "|" + String(receipt.rowsAffected)
        payload += "|" + ISO8601DateFormatter().string(from: receipt.timestamp)
        if let prevHash = receipt.previousReceiptHash {
            payload += "|" + prevHash
        }
        
        return payload.data(using: .utf8) ?? Data()
    }
}

// MARK: - Error Types

public enum EvidenceChainError: LocalizedError {
    case chainLinkBroken(String)
    case invalidSignature(String)
    case duplicateReceipt(String)
    case corruptedReceipt(String)
    
    public var errorDescription: String? {
        switch self {
        case .chainLinkBroken(let msg):
            return "Evidence chain link broken: \(msg)"
        case .invalidSignature(let msg):
            return "Invalid signature: \(msg)"
        case .duplicateReceipt(let msg):
            return "Duplicate receipt: \(msg)"
        case .corruptedReceipt(let msg):
            return "Corrupted receipt: \(msg)"
        }
    }
}
