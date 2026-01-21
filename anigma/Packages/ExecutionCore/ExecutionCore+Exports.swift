//
//  ExecutionCore+Exports.swift
//  ExecutionCore
//
//  Public exports and type aliases for ExecutionCore.
//  Provides stable API and compatibility shims.
//

import Foundation
import TelemetryCore

// MARK: - Core Types

// Export receipt types
public typealias Receipt = ReceiptWire
public typealias ReceiptDecisionType = ReceiptDecision
public typealias PhaseTransition = PhaseTransitionWire
public typealias CommandEntry = CommandLedgerWire

// Export protocol types  
public typealias PolicyProvider = PolicyEvaluator
public typealias TransportInterface = TransportProtocol

// MARK: - Compatibility Shims for Existing Code

/// Compatibility shim for existing PraxisCore usage
public enum PraxisCompatibility {
    /// Creates legacy-compatible receipt wire format
    public static func createLegacyReceipt(
        command: String,
        outcome: String,
        message: String,
        authority: String = "system"
    ) -> ReceiptWire {
        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
        let inputsHash = TelemetryHash(input: "\(command)-\(outcome)-\(message)")

        return ReceiptWire.create(
            actionName: command,
            authority: authority,
            decision: ReceiptDecision(rawValue: outcome) ?? .error,
            reasonCode: "legacy_compatibility",
            timestampMs: timestampMs,
            inputsHash: inputsHash,
            metadata: [
                "legacy_outcome": .hashedToken(TelemetryHash(input: outcome)),
                "legacy_message": .hashedToken(TelemetryHash(input: message))
            ]
        )
    }

    /// Converts legacy decision string to ReceiptDecision
    public static func convertLegacyDecision(_ decision: String) -> ReceiptDecision {
        switch decision.lowercased() {
        case "allowed", "success", "approved":
            return .allowed
        case "denied", "failed", "rejected":
            return .denied
        case "audit", "manual", "review":
            return .auditRequired
        case "quarantine", "blocked", "held":
            return .quarantine
        default:
            return .error
        }
    }
}

/// Compatibility shims for existing CommandLedger usage
public enum CommandLedgerCompatibility {
    /// Creates legacy-compatible command entry
    public static func createLegacyEntry(
        kind: String,
        sessionID: String? = nil,
        agent: String? = nil,
        command: String? = nil,
        messageID: String? = nil,
        detail: [String: String]? = nil
    ) -> CommandLedgerWire {
        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)

        // Convert legacy string details to TelemetryValue format
        let details: [String: TelemetryValue] = (detail ?? [:]).mapValues { value in
            .hashedToken(TelemetryHash(input: value))
        }

        return CommandLedgerWire(
            entryID: UUID().uuidString,
            kind: kind,
            timestampMs: timestampMs,
            sessionID: sessionID,
            agent: agent,
            command: command,
            messageID: messageID,
            details: details
        )
    }
}

/// Factory for creating ExecutionCore components with common configurations
public enum ExecutionCoreFactory {
    /// Creates a configured receipt engine
    public static func createReceiptEngine(
        signer: any ReceiptSigner,
        store: any ReceiptStore,
        telemetry: TelemetryClient = TelemetryClient.forDevelopment()
    ) -> ReceiptEngine {
        return ReceiptEngine(signer: signer, store: store, telemetry: telemetry)
    }

    /// Creates a configured phase gate engine
    public static func createPhaseGateEngine(
        policyEvaluator: any PolicyEvaluator,
        receiptEngine: ReceiptEngine,
        telemetry: TelemetryClient = TelemetryClient.forDevelopment(),
        knownPhases: [String] = []
    ) -> PhaseGateEngine {
        return PhaseGateEngine(
            policyEvaluator: policyEvaluator,
            receiptEngine: receiptEngine,
            telemetry: telemetry,
            knownPhases: knownPhases
        )
    }

    /// Creates a configured command ledger
    public static func createCommandLedger(
        repoRoot: URL,
        telemetry: TelemetryClient = TelemetryClient.forDevelopment()
    ) -> CommandLedger {
        return CommandLedger(repoRoot: repoRoot, telemetry: telemetry)
    }
}

// MARK: - Module Info

/// ExecutionCore module information and capabilities
public enum ExecutionCoreInfo {
    /// Module version
    public static let version = "1.0.0"

    /// Module name
    public static let moduleName = "ExecutionCore"

    /// Supported capabilities
    public static let capabilities: [String] = [
        "receipt_generation",
        "phase_gates",
        "command_ledger",
        "transport_abstraction",
        "deterministic_encoding",
        "telemetry_integration"
    ]

    /// Required dependencies
    public static let dependencies: [String] = [
        "TelemetryCore"
    ]

    /// External dependencies (protocols, not direct imports)
    public static let externalDependencies: [String] = [
        "PolicyEvaluator (implemented by HarmoniaModule)",
        "ReceiptSigner (injected)",
        "ReceiptStore (injected)"
    ]
}

// MARK: - Constants

/// ExecutionCore constants and defaults
public enum ExecutionCoreConstants {
    /// Default timeout for operations (in milliseconds)
    public static let defaultTimeoutMs: Int64 = 30000 // 30 seconds

    /// Maximum payload size for transport messages
    public static let maxPayloadSize: Int = 1024 * 1024 // 1MB

    /// Default correlation timeout for request/response
    public static let defaultCorrelationTimeoutMs: Int64 = 10000 // 10 seconds

    /// Supported encoding formats
    public static let supportedEncodings: [String] = ["json", "jsonl"]

    /// Default number of retry attempts
    public static let defaultRetryAttempts: Int = 3
}
