//
//  InferenceAuthority.swift
//  GovernanceCore
//
//  Governance authority for ML inference operations.
//  Records model metadata, quantization config, and toolchain version in ToolchainReceipt.
//

import Foundation
import Crypto

// MARK: - Toolchain Receipt

/// Verifiable receipt of ML model loading and inference configuration
public struct ToolchainReceipt: Codable {
    /// Unique receipt ID
    public let receiptID: String
    
    /// Model file path or identifier
    public let modelIdentifier: String
    
    /// BLAKE3 hash of model file
    public let modelHash: String
    
    /// Quantization configuration (e.g., "Q4_K_M", "fp16")
    public let quantizationConfig: String
    
    /// MLX toolchain version (e.g., "2.29.2")
    public let mlxVersion: String
    
    /// llama.cpp version if applicable
    public let llamaCppVersion: String?
    
    /// Hardware lane used for inference (CPU, GPU/Metal, ANE)
    public let hardwareLane: String
    
    /// Unique inference run ID
    public let inferenceID: String
    
    /// Input prompt hash
    public let inputHash: String
    
    /// Output hash
    public let outputHash: String
    
    /// Inference latency in milliseconds
    public let latencyMs: Double
    
    /// Timestamp of inference
    public let timestamp: Date
    
    /// Cryptographic signature
    public let signature: String
    
    public init(
        receiptID: String = UUID().uuidString,
        modelIdentifier: String,
        modelHash: String,
        quantizationConfig: String,
        mlxVersion: String,
        llamaCppVersion: String? = nil,
        hardwareLane: String,
        inferenceID: String = UUID().uuidString,
        inputHash: String,
        outputHash: String,
        latencyMs: Double,
        timestamp: Date = Date(),
        signature: String
    ) {
        self.receiptID = receiptID
        self.modelIdentifier = modelIdentifier
        self.modelHash = modelHash
        self.quantizationConfig = quantizationConfig
        self.mlxVersion = mlxVersion
        self.llamaCppVersion = llamaCppVersion
        self.hardwareLane = hardwareLane
        self.inferenceID = inferenceID
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.latencyMs = latencyMs
        self.timestamp = timestamp
        self.signature = signature
    }
}

// MARK: - Inference Authority

public class InferenceAuthority {
    private let evidenceChain: DatabaseEvidenceChain?
    private let hmacKey: SymmetricKey
    private let lock = NSLock()
    private var cachedReceipts: [String: ToolchainReceipt] = [:]
    
    public init(evidenceChain: DatabaseEvidenceChain? = nil, hmacKey: SymmetricKey? = nil) {
        self.evidenceChain = evidenceChain
        self.hmacKey = hmacKey ?? SymmetricKey(size: .bits256)
    }
    
    /// Record inference operation
    public func recordInference(
        modelPath: String,
        modelHash: String,
        quantization: String,
        mlxVersion: String,
        llamaCppVersion: String? = nil,
        hardwareLane: String,
        inputPrompt: String,
        outputText: String,
        latencyMs: Double
    ) throws -> ToolchainReceipt {
        let startTime = Date()
        
        // Compute hashes
        let inputHash = SHA256.hash(data: inputPrompt.data(using: .utf8) ?? Data())
        let outputHash = SHA256.hash(data: outputText.data(using: .utf8) ?? Data())
        
        let inputHashStr = Data(inputHash).base64EncodedString()
        let outputHashStr = Data(outputHash).base64EncodedString()
        
        // Create payload for signature
        let receiptID = UUID().uuidString
        let inferenceID = UUID().uuidString
        var payload = ""
        payload += receiptID
        payload += "|" + modelPath
        payload += "|" + modelHash
        payload += "|" + quantization
        payload += "|" + mlxVersion
        if let llamaVersion = llamaCppVersion {
            payload += "|" + llamaVersion
        }
        payload += "|" + hardwareLane
        payload += "|" + inferenceID
        payload += "|" + inputHashStr
        payload += "|" + outputHashStr
        payload += "|" + String(format: "%.2f", latencyMs)
        payload += "|" + ISO8601DateFormatter().string(from: startTime)
        
        let payloadData = payload.data(using: .utf8) ?? Data()
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: hmacKey)
        let signatureStr = Data(signature).base64EncodedString()
        
        let receipt = ToolchainReceipt(
            receiptID: receiptID,
            modelIdentifier: modelPath,
            modelHash: modelHash,
            quantizationConfig: quantization,
            mlxVersion: mlxVersion,
            llamaCppVersion: llamaCppVersion,
            hardwareLane: hardwareLane,
            inferenceID: inferenceID,
            inputHash: inputHashStr,
            outputHash: outputHashStr,
            latencyMs: latencyMs,
            timestamp: startTime,
            signature: signatureStr
        )
        
        // Cache receipt
        lock.lock()
        cachedReceipts[receipt.inferenceID] = receipt
        lock.unlock()
        
        // Link to evidence chain if available
        if let chain = evidenceChain {
            try addToEvidenceChain(receipt, to: chain)
        }
        
        return receipt
    }
    
    /// Get inference receipt by ID
    public func getReceipt(_ inferenceID: String) -> ToolchainReceipt? {
        lock.lock()
        defer { lock.unlock() }
        return cachedReceipts[inferenceID]
    }
    
    /// Verify receipt signature
    public func verifyReceipt(_ receipt: ToolchainReceipt) throws {
        let payload = try createReceiptPayload(receipt)
        let signature = HMAC<SHA256>.authenticationCode(for: payload, using: hmacKey)
        let expectedSignature = Data(signature).base64EncodedString()
        
        guard receipt.signature == expectedSignature else {
            throw InferenceAuthorityError.invalidSignature(
                "Toolchain receipt \(receipt.receiptID) has invalid signature"
            )
        }
    }
    
    /// Get all receipts (snapshot)
    public func allReceipts() -> [ToolchainReceipt] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cachedReceipts.values)
    }
    
    // MARK: - Private Helpers
    
    private func createReceiptPayload(_ receipt: ToolchainReceipt) throws -> Data {
        var payload = ""
        payload += receipt.receiptID
        payload += "|" + receipt.modelIdentifier
        payload += "|" + receipt.modelHash
        payload += "|" + receipt.quantizationConfig
        payload += "|" + receipt.mlxVersion
        if let llamaVersion = receipt.llamaCppVersion {
            payload += "|" + llamaVersion
        }
        payload += "|" + receipt.hardwareLane
        payload += "|" + receipt.inferenceID
        payload += "|" + receipt.inputHash
        payload += "|" + receipt.outputHash
        payload += "|" + String(format: "%.2f", receipt.latencyMs)
        payload += "|" + ISO8601DateFormatter().string(from: receipt.timestamp)
        
        return payload.data(using: .utf8) ?? Data()
    }
    
    private func addToEvidenceChain(_ receipt: ToolchainReceipt, to chain: DatabaseEvidenceChain) throws {
        // Convert ToolchainReceipt to DatabaseCoreReceipt for governance tracking
        let dbReceipt = DatabaseCoreReceipt(
            receiptID: receipt.receiptID,
            sessionID: "inference",
            principalID: "mlx",
            operationType: "INFERENCE",
            tableName: "inference_logs",
            statementHash: receipt.modelHash,
            rowsAffected: 1,
            signature: receipt.signature
        )
        
        try chain.add(dbReceipt)
    }
}

// MARK: - Error Types

public enum InferenceAuthorityError: LocalizedError {
    case modelNotFound(String)
    case loadingFailed(String)
    case quantizationFailed(String)
    case inferenceFailef(String)
    case invalidSignature(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Model not found at: \(path)"
        case .loadingFailed(let reason):
            return "Failed to load model: \(reason)"
        case .quantizationFailed(let reason):
            return "Quantization failed: \(reason)"
        case .inferenceFailef(let reason):
            return "Inference failed: \(reason)"
        case .invalidSignature(let msg):
            return "Invalid signature: \(msg)"
        }
    }
}

// MARK: - Model Registry with Provenance

public class ProvenanceTrackedModelRegistry {
    private let authority: InferenceAuthority
    private var models: [String: ModelMetadata] = [:]
    private let lock = NSLock()
    
    public init(authority: InferenceAuthority) {
        self.authority = authority
    }
    
    public struct ModelMetadata: Codable {
        public let identifier: String
        public let path: String
        public let fileHash: String
        public let quantization: String
        public let version: String
        public let registeredAt: Date
        public let registrationReceipt: String  // Reference to receipt
    }
    
    /// Register model with provenance tracking
    public func registerModel(
        identifier: String,
        path: String,
        fileHash: String,
        quantization: String,
        version: String
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        
        let metadata = ModelMetadata(
            identifier: identifier,
            path: path,
            fileHash: fileHash,
            quantization: quantization,
            version: version,
            registeredAt: Date(),
            registrationReceipt: UUID().uuidString
        )
        
        models[identifier] = metadata
        NSLog("Model registered with provenance: \(identifier)")
    }
    
    /// Get model metadata
    public func model(_ identifier: String) -> ModelMetadata? {
        lock.lock()
        defer { lock.unlock() }
        return models[identifier]
    }
    
    /// Get all registered models
    public func allModels() -> [ModelMetadata] {
        lock.lock()
        defer { lock.unlock() }
        return Array(models.values)
    }
}
