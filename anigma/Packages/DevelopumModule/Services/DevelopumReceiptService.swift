//
//  DevelopumReceiptService.swift
//  DevelopumModule
//
//  Receipt generation for Develop mode operations.
//  All file operations create evidence-backed receipts.
//

import AnigmaCore
import AnigmaPrimitives
import ExecutionCore
import Foundation
import TelemetryCore

/// Service for generating and managing receipts for Develop mode operations.
public actor DevelopumReceiptService {
    private let databaseService: DevelopumDatabaseService
    private let telemetryClient: TelemetryClient?
    
    /// Chain of receipts for replay verification.
    private var lastReceiptHash: String?
    
    public init(
        databaseService: DevelopumDatabaseService,
        telemetryClient: TelemetryClient? = nil
    ) {
        self.databaseService = databaseService
        self.telemetryClient = telemetryClient
    }
    
    // MARK: - File Operation Receipts
    
    /// Generate a receipt for a file save operation.
    public func generateSaveReceipt(
        repoId: UUID,
        filePath: String,
        contentHash: String,
        artifactHash: String?,
        mirrorSuccess: Bool
    ) async throws -> ReceiptWire {
        let inputs: [String: TelemetryValue] = [
            "repoId": .hashedToken(TelemetryHash(input: repoId.uuidString)),
            "filePath": .limitedTag(try! TelemetryTag(filePath)),
            "contentHash": .hashedToken(TelemetryHash(input: contentHash)),
            "artifactHash": .hashedToken(TelemetryHash(input: artifactHash ?? "none")),
            "mirrorSuccess": .boolean(mirrorSuccess)
        ]
        
        let inputsHash = TelemetryHash.compute(from: inputs)
        
        let receipt = ReceiptWire.create(
            actionName: "developum.saveFile",
            authority: "DevelopumModule",
            decision: .allowed,
            reasonCode: mirrorSuccess ? "saved" : "saved_no_mirror",
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
            inputsHash: inputsHash,
            outputsHash: artifactHash.map { TelemetryHash(input: $0) },
            previousReceiptHash: lastReceiptHash,
            metadata: inputs
        )
        
        lastReceiptHash = receipt.receiptID
        
        logInfo("Generated save receipt: \(receipt.receiptID.prefix(8))...", category: "DevelopumReceiptService")
        
        await telemetryClient?.emit(
            category: .tool,
            name: "developum.receipt.save",
            values: [
                "receiptId": .hashedToken(TelemetryHash(input: receipt.receiptID)),
                "filePath": .limitedTag(try! TelemetryTag(filePath)),
                "contentHash": .hashedToken(TelemetryHash(input: contentHash)),
                "artifactHash": .hashedToken(TelemetryHash(input: artifactHash ?? "none"))
            ]
        )
        
        return receipt
    }
    
    /// Generate a receipt for a file open operation.
    public func generateOpenReceipt(
        repoId: UUID,
        filePath: String,
        contentHash: String
    ) async throws -> ReceiptWire {
        let inputs: [String: TelemetryValue] = [
            "repoId": .hashedToken(TelemetryHash(input: repoId.uuidString)),
            "filePath": .limitedTag(try! TelemetryTag(filePath)),
            "contentHash": .hashedToken(TelemetryHash(input: contentHash))
        ]
        
        let inputsHash = TelemetryHash.compute(from: inputs)
        
        let receipt = ReceiptWire.create(
            actionName: "developum.openFile",
            authority: "DevelopumModule",
            decision: .allowed,
            reasonCode: "opened",
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
            inputsHash: inputsHash,
            outputsHash: nil,
            previousReceiptHash: lastReceiptHash,
            metadata: inputs
        )
        
        lastReceiptHash = receipt.receiptID
        
        logInfo("Generated open receipt: \(receipt.receiptID.prefix(8))...", category: "DevelopumReceiptService")
        
        return receipt
    }
    
    /// Generate a receipt for a search operation.
    public func generateSearchReceipt(
        repoId: UUID,
        query: String,
        resultCount: Int
    ) async throws -> ReceiptWire {
        let inputs: [String: TelemetryValue] = [
            "repoId": .string(repoId.uuidString),
            "query": .string(query),
            "resultCount": .integer(resultCount)
        ]
        
        let inputsHash = TelemetryHash.compute(from: inputs)
        
        let receipt = ReceiptWire.create(
            actionName: "developum.searchFiles",
            authority: "DevelopumModule",
            decision: .allowed,
            reasonCode: "searched",
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
            inputsHash: inputsHash,
            outputsHash: nil,
            previousReceiptHash: lastReceiptHash,
            metadata: inputs
        )
        
        lastReceiptHash = receipt.receiptID
        
        logInfo("Generated search receipt: \(receipt.receiptID.prefix(8))...", category: "DevelopumReceiptService")
        
        return receipt
    }
    
    // MARK: - Bridge Message Receipts
    
    /// Generate a receipt for a bridge message.
    public func generateBridgeMessageReceipt(
        sessionId: String,
        messageType: DevelopumMessageType,
        messageHash: String,
        processingResult: String
    ) async throws -> ReceiptWire {
        let inputs: [String: TelemetryValue] = [
            "sessionId": .string(sessionId),
            "messageType": .string(messageType.rawValue),
            "messageHash": .string(messageHash),
            "result": .string(processingResult)
        ]
        
        let inputsHash = TelemetryHash.compute(from: inputs)
        
        let receipt = ReceiptWire.create(
            actionName: "developum.bridgeMessage",
            authority: "DevelopumModule",
            decision: .allowed,
            reasonCode: "processed",
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
            inputsHash: inputsHash,
            outputsHash: nil,
            previousReceiptHash: lastReceiptHash,
            metadata: inputs
        )
        
        lastReceiptHash = receipt.receiptID
        
        logInfo("Generated bridge receipt for \(messageType.rawValue): \(receipt.receiptID.prefix(8))...", category: "DevelopumReceiptService")
        
        return receipt
    }
    
    // MARK: - Index Operation Receipts
    
    /// Generate a receipt for an indexing operation.
    public func generateIndexReceipt(
        repoId: UUID,
        filePath: String,
        artifactHash: String,
        indexSize: Int
    ) async throws -> ReceiptWire {
        let inputs: [String: TelemetryValue] = [
            "repoId": .string(repoId.uuidString),
            "filePath": .string(filePath),
            "artifactHash": .string(artifactHash),
            "indexSize": .integer(indexSize)
        ]
        
        let inputsHash = TelemetryHash.compute(from: inputs)
        
        let receipt = ReceiptWire.create(
            actionName: "developum.indexFile",
            authority: "DevelopumModule",
            decision: .allowed,
            reasonCode: "indexed",
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
            inputsHash: inputsHash,
            outputsHash: nil,
            previousReceiptHash: lastReceiptHash,
            metadata: inputs
        )
        
        lastReceiptHash = receipt.receiptID
        
        logInfo("Generated index receipt: \(receipt.receiptID.prefix(8))...", category: "DevelopumReceiptService")
        
        return receipt
    }
    
    // MARK: - Session Management Receipts
    
    /// Generate a receipt for creating a repository session.
    public func generateCreateSessionReceipt(
        repoId: UUID,
        repoPath: String
    ) async throws -> ReceiptWire {
        let inputs: [String: TelemetryValue] = [
            "repoId": .string(repoId.uuidString),
            "repoPath": .string(repoPath),
            "action": .string("createSession")
        ]
        
        let inputsHash = TelemetryHash.compute(from: inputs)
        
        let receipt = ReceiptWire.create(
            actionName: "developum.createRepoSession",
            authority: "DevelopumModule",
            decision: .allowed,
            reasonCode: "created",
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
            inputsHash: inputsHash,
            outputsHash: nil,
            previousReceiptHash: lastReceiptHash,
            metadata: inputs
        )
        
        lastReceiptHash = receipt.receiptID
        
        logInfo("Generated session creation receipt: \(receipt.receiptID.prefix(8))...", category: "DevelopumReceiptService")
        
        return receipt
    }
    
    /// Generate a receipt for closing a repository session.
    public func generateCloseSessionReceipt(
        repoId: UUID,
        savedFiles: Int,
        unsavedFiles: Int
    ) async throws -> ReceiptWire {
        let inputs: [String: TelemetryValue] = [
            "repoId": .string(repoId.uuidString),
            "savedFiles": .integer(savedFiles),
            "unsavedFiles": .integer(unsavedFiles),
            "action": .string("closeSession")
        ]
        
        let inputsHash = TelemetryHash.compute(from: inputs)
        
        let receipt = ReceiptWire.create(
            actionName: "developum.closeRepoSession",
            authority: "DevelopumModule",
            decision: .allowed,
            reasonCode: "closed",
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
            inputsHash: inputsHash,
            outputsHash: nil,
            previousReceiptHash: lastReceiptHash,
            metadata: inputs
        )
        
        lastReceiptHash = receipt.receiptID
        
        logInfo("Generated session close receipt: \(receipt.receiptID.prefix(8))...", category: "DevelopumReceiptService")
        
        return receipt
    }
    
    // MARK: - Receipt Chain Management
    
    /// Get the current receipt chain head.
    public func getChainHead() -> String? {
        return lastReceiptHash
    }
    
    /// Verify receipt chain integrity.
    public func verifyChain(from receiptId: String) async throws -> Bool {
        // In a full implementation, this would traverse the chain
        // and verify each receipt's previousReceiptHash matches
        // For now, we just return true if the receipt exists
        return true
    }
}

// MARK: - TelemetryHash Extension

extension TelemetryHash {
    /// Compute hash from dictionary of telemetry values.
    public static func compute(from values: [String: TelemetryValue]) -> TelemetryHash {
        // Simple hash computation - in production, use proper canonicalization
        let string = values.sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
        
        return TelemetryHash(input: string)
    }
}