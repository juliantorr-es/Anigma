//
//  ReceiptTypes.swift
//  ExecutionCore
//
//  CoreReceipt wire types for deterministic encoding and persistence.
//  These are Codable wire formats - runtime engines are separate.
//

import AnigmaPrimitives
import Foundation
import TelemetryCore

// MARK: - Supporting Types for JCS Serialization

/// Payload struct for JCS serialization without the receiptID
private struct Payload: Codable {
    let actionName: String
    let authority: String
    let decision: ReceiptDecision
    let reasonCode: String
    let timestampMs: Int64
    let inputsHash: TelemetryHash
    let outputsHash: TelemetryHash?
    let previousReceiptHash: String?
    let metadata: [String: TelemetryValue]
}

/// Payload struct for JCS serialization without the transitionID
private struct TransitionPayload: Codable {
    let fromPhase: String
    let toPhase: String
    let authority: String
    let decision: ReceiptDecision
    let reasonCode: String
    let timestampMs: Int64
    let contextHash: TelemetryHash
    let metadata: [String: TelemetryValue]
}

// MARK: - CoreReceipt Errors

/// Errors that can occur during receipt operations
public enum ReceiptError: Error, LocalizedError {
    case receiptIDMismatch(expected: String, actual: String)
    case transitionIDMismatch(expected: String, actual: String)
    case migrationFailed(receipt: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .receiptIDMismatch(let expected, let actual):
            return "CoreReceipt ID mismatch. Expected: \(expected), got: \(actual)"
        case .transitionIDMismatch(let expected, let actual):
            return "Transition ID mismatch. Expected: \(expected), got: \(actual)"
        case .migrationFailed(let receipt, let message):
            return "Migration failed for receipt \(receipt): \(message)"
        }
    }
}

// MARK: - CoreReceipt Wire Format
/// Wire-format receipt for serialization and persistence.
/// This is the ONLY Codable receipt type - runtime engines are separate.
/// CRITICAL: receiptID is ALWAYS computed from BLAKE3(JCS(payload))
public struct ReceiptWire: Codable, Sendable {
    /// Unique identifier for this receipt - ALWAYS computed from BLAKE3(JCS(payload))
    private var _receiptID: String

    /// External facing ID (read-only)
    public var receiptID: String {
        return _receiptID
    }

    /// Name of the action being recorded
    public let actionName: String

    /// Authority that made the decision (who/what decided the outcome)
    public let authority: String

    /// Decision result (provided by policy evaluation, not computed here)
    public let decision: ReceiptDecision

    /// Machine-readable reason code (must be from controlled set)
    public let reasonCode: String

    /// Deterministic timestamp (milliseconds since epoch)
    public let timestampMs: Int64

    /// Hash of inputs for integrity verification
    public let inputsHash: TelemetryHash

    /// Optional hash of outputs for integrity verification
    public let outputsHash: TelemetryHash?

    /// Optional cryptographic signature (bytes in base64)
    public var signature: String?

    /// Hash of previous receipt in chain (for chain integrity)
    public let previousReceiptHash: String?

    /// Additional structured data (controlled keys only)
    public let metadata: [String: TelemetryValue]

    @available(
        *, deprecated,
        message:
            "Use ReceiptWire.create(...) instead. Direct receiptID parameter is not allowed due to canonical ID derivation requirement."
    )
    public init(
        receiptID: String,
        actionName: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        timestampMs: Int64,
        inputsHash: TelemetryHash,
        outputsHash: TelemetryHash? = nil,
        signature: String? = nil,
        previousReceiptHash: String? = nil,
        metadata: [String: TelemetryValue] = [:]
    ) {
        self._receiptID = receiptID
        self.actionName = actionName
        self.authority = authority
        self.decision = decision
        self.reasonCode = reasonCode
        self.timestampMs = timestampMs
        self.inputsHash = inputsHash
        self.outputsHash = outputsHash
        self.signature = signature
        self.previousReceiptHash = previousReceiptHash
        self.metadata = metadata
    }

    // Internal initializer used by create() - ID will be set later
    private init(
        actionName: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        timestampMs: Int64,
        inputsHash: TelemetryHash,
        outputsHash: TelemetryHash? = nil,
        signature: String? = nil,
        previousReceiptHash: String? = nil,
        metadata: [String: TelemetryValue] = [:]
    ) {
        self._receiptID = "temp"  // Placeholder, will be overridden
        self.actionName = actionName
        self.authority = authority
        self.decision = decision
        self.reasonCode = reasonCode
        self.timestampMs = timestampMs
        self.inputsHash = inputsHash
        self.outputsHash = outputsHash
        self.signature = signature
        self.previousReceiptHash = previousReceiptHash
        self.metadata = metadata
    }

    public static func create(
        actionName: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        timestampMs: Int64,
        inputsHash: TelemetryHash,
        outputsHash: TelemetryHash? = nil,
        signature: String? = nil,
        previousReceiptHash: String? = nil,
        metadata: [String: TelemetryValue] = [:]
    ) -> ReceiptWire {
        let tempReceipt = ReceiptWire(
            actionName: actionName,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode,
            timestampMs: timestampMs,
            inputsHash: inputsHash,
            outputsHash: outputsHash,
            signature: signature,
            previousReceiptHash: previousReceiptHash,
            metadata: metadata
        )
        
        var instance = tempReceipt
        instance._receiptID = instance.computeReceiptID()
        return instance
    }
}

/// Decision outcome for receipts.
/// These are provided by policy evaluation, not computed by ExecutionCore.
public enum ReceiptDecision: String, Sendable, Codable {
    case allowed = "allowed"
    case denied = "denied"
    case auditRequired = "audit_required"
    case quarantine = "quarantine"
    case error = "error"

    public var description: String {
        switch self {
        case .allowed: return "Action allowed"
        case .denied: return "Action denied"
        case .auditRequired: return "Manual audit required"
        case .quarantine: return "Action quarantined"
        case .error: return "Error during execution"
        }
    }
}

/// Wire format for phase transition records.
public struct PhaseTransitionWire: Codable, Sendable {
    /// Unique identifier for this transition - ALWAYS computed from BLAKE3(JCS(payload))
    private var _transitionID: String

    /// External facing ID (read-only)
    public var transitionID: String {
        return _transitionID
    }

    /// Current phase before transition
    public let fromPhase: String

    /// Target phase after transition
    public let toPhase: String

    /// Authority requesting the transition
    public let authority: String

    /// Decision from policy evaluation
    public let decision: ReceiptDecision

    /// Reason code for the decision
    public let reasonCode: String

    /// Deterministic timestamp
    public let timestampMs: Int64

    /// Hash of context provided to policy evaluator
    public let contextHash: TelemetryHash

    /// Optional metadata
    public let metadata: [String: TelemetryValue]

    @available(
        *, deprecated,
        message:
            "Use PhaseTransitionWire.create(...) instead. Direct transitionID parameter is not allowed due to canonical ID derivation requirement."
    )
    public init(
        transitionID: String,
        fromPhase: String,
        toPhase: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        timestampMs: Int64,
        contextHash: TelemetryHash,
        metadata: [String: TelemetryValue] = [:]
    ) {
        self._transitionID = transitionID
        self.fromPhase = fromPhase
        self.toPhase = toPhase
        self.authority = authority
        self.decision = decision
        self.reasonCode = reasonCode
        self.timestampMs = timestampMs
        self.contextHash = contextHash
        self.metadata = metadata
    }

    public static func create(
        fromPhase: String,
        toPhase: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        timestampMs: Int64,
        contextHash: TelemetryHash,
        metadata: [String: TelemetryValue] = [:]
    ) -> PhaseTransitionWire {
        let tempTransition = PhaseTransitionWire(
            transitionID: "temp",
            fromPhase: fromPhase,
            toPhase: toPhase,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode,
            timestampMs: timestampMs,
            contextHash: contextHash,
            metadata: metadata
        )
        
        var instance = tempTransition
        instance._transitionID = instance.computeTransitionID()
        return instance
    }
}

// MARK: - Protocol Interfaces for Runtime

/// Protocol for cryptographic signing of receipts.
/// Implementation is injected, not defined in ExecutionCore.
public protocol ReceiptSigner: Sendable {
    /// Signs the data and returns base64-encoded signature
    func sign(data: Data) async throws -> String

    /// Verifies the signature for the provided data.
    func verify(data: Data, signature: String) async throws -> Bool

    /// Unique identifier for this signer
    var signerID: String { get }
}

/// Protocol for receipt persistence/storage.
/// Implementation is injected, not defined in ExecutionCore.
public protocol ReceiptStore: Sendable {
    /// Stores a receipt and returns its storage path/ID
    func store(receipt: ReceiptWire) async throws -> String

    /// Retrieves a receipt by ID
    func retrieve(receiptID: String) async throws -> ReceiptWire?

    /// Lists receipts by criteria
    func list(filter: ReceiptFilter?) async throws -> [ReceiptWire]

    /// Unique identifier for this store
    var storeID: String { get }
}

/// Filter criteria for receipt queries.
public struct ReceiptFilter: Codable, Sendable {
    public let actionName: String?
    public let authority: String?
    public let decision: ReceiptDecision?
    public let fromTimestampMs: Int64?
    public let toTimestampMs: Int64?

    public init(
        actionName: String? = nil,
        authority: String? = nil,
        decision: ReceiptDecision? = nil,
        fromTimestampMs: Int64? = nil,
        toTimestampMs: Int64? = nil
    ) {
        self.actionName = actionName
        self.authority = authority
        self.decision = decision
        self.fromTimestampMs = fromTimestampMs
        self.toTimestampMs = toTimestampMs
    }
}

// MARK: - Deterministic Encoding Support

extension ReceiptWire {
    /// Creates deterministic JSON representation (JCS)
    /// CRITICAL: This must produce byte-identical output across platforms
    public func deterministicJSON() throws -> Data {
        // Create payload without receiptID for JCS computation
        let payload = Payload(
            actionName: actionName,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode,
            timestampMs: timestampMs,
            inputsHash: inputsHash,
            outputsHash: outputsHash,
            previousReceiptHash: previousReceiptHash,
            metadata: metadata
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(payload)
    }

    /// Computes deterministic BLAKE3 hash of JCS payload for receipt ID
    /// CRITICAL: CoreReceipt ID MUST be derived from this method only
    func computeReceiptID() -> String {
        do {
            // Get JCS payload
            let payload = try deterministicJSON()

            // Compute BLAKE3 hash (hex-encoded)
            return BLAKE3Digest.hex(of: payload)
        } catch {
            fatalError("BLAKE3 hash computation failed: \(error)")
        }
    }

    /// Computes deterministic hash of this receipt (legacy method)
    public func contentHash() throws -> TelemetryHash {
        let data = try deterministicJSON()
        return TelemetryHash(input: String(data: data, encoding: .utf8) ?? "")
    }

    /// Verifies that receiptID matches BLAKE3(JCS(payload))
    /// Throws if receiptID does not match computed hash
    public func verifyReceiptID() throws {
        let computedID = computeReceiptID()
        guard receiptID == computedID else {
            throw ReceiptError.receiptIDMismatch(expected: computedID, actual: receiptID)
        }
    }
}

extension PhaseTransitionWire {
    /// Creates deterministic JSON representation (JCS)
    /// CRITICAL: This must produce byte-identical output across platforms
    public func deterministicJSON() throws -> Data {
        // Create payload without transitionID for JCS computation
        let payload = TransitionPayload(
            fromPhase: fromPhase,
            toPhase: toPhase,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode,
            timestampMs: timestampMs,
            contextHash: contextHash,
            metadata: metadata
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(payload)
    }

    /// Computes deterministic BLAKE3 hash of JCS payload for transition ID
    /// CRITICAL: Transition ID MUST be derived from this method only
    func computeTransitionID() -> String {
        do {
            // Get JCS payload
            let payload = try deterministicJSON()

            // Compute BLAKE3 hash (hex-encoded)
            return BLAKE3Digest.hex(of: payload)
        } catch {
            fatalError("BLAKE3 hash computation failed: \(error)")
        }
    }

    /// Verifies that transitionID matches BLAKE3(JCS(payload))
    /// Throws if transitionID does not match computed hash
    public func verifyTransitionID() throws {
        let computedID = computeTransitionID()
        guard transitionID == computedID else {
            throw ReceiptError.transitionIDMismatch(expected: computedID, actual: transitionID)
        }
    }
}
