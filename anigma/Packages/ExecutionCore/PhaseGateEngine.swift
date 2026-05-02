//
//  PhaseGateEngine.swift
//  ExecutionCore
//
//  Runtime engine for phase transitions with external policy evaluation.
//  Enforces mechanical invariants only - no doctrine/trust evaluation.
//

import Foundation
import TelemetryCore

// MARK: - Policy Decision Interface

/// Result of policy evaluation from external authority (HarmoniaModule).
/// ExecutionCore does NOT compute these - it only accepts them.
public struct PolicyDecision: Sendable {
    public let decision: ReceiptDecision
    public let reasonCode: String
    public let authority: String
    public let contextHash: TelemetryHash
    public let metadata: [String: TelemetryValue]

    public init(
        decision: ReceiptDecision,
        reasonCode: String,
        authority: String,
        contextHash: TelemetryHash,
        metadata: [String: TelemetryValue] = [:]
    ) {
        self.decision = decision
        self.reasonCode = reasonCode
        self.authority = authority
        self.contextHash = contextHash
        self.metadata = metadata
    }
}

/// Protocol for external policy evaluation.
/// Implemented by HarmoniaModule, consumed by ExecutionCore.
public protocol PolicyEvaluator: Sendable {
    /// Evaluates whether a phase transition is allowed
    func evaluatePhaseTransition(
        from currentPhase: String,
        to requestedPhase: String,
        authority: String,
        context: [String: Sendable]
    ) async throws -> PolicyDecision

    /// Unique identifier for this evaluator
    var evaluatorID: String { get }
}

// MARK: - Phase Gate Engine Runtime

/// Runtime engine for managing phase transitions.
/// Enforces mechanical invariants only; policy decisions come from injected evaluator.
public actor PhaseGateEngine {
    private let policyEvaluator: any PolicyEvaluator
    private let receiptEngine: ReceiptEngine
    private let telemetry: TelemetryClient

    /// Known phase sequence for mechanical validation (if needed)
    private let knownPhases: [String]

    public init(
        policyEvaluator: any PolicyEvaluator,
        receiptEngine: ReceiptEngine,
        telemetry: TelemetryClient,
        knownPhases: [String] = []
    ) {
        self.policyEvaluator = policyEvaluator
        self.receiptEngine = receiptEngine
        self.telemetry = telemetry
        self.knownPhases = knownPhases
    }

    /// Attempts a phase transition with external policy evaluation.
    /// This is the ONLY way to transition phases.
    public func attemptTransition(
        from currentPhase: String,
        to requestedPhase: String,
        authority: String,
        context: [String: Sendable]
    ) async throws -> PolicyDecision {
        let transitionID = UUID().uuidString

        // Step 1: Check mechanical invariants only
        try validateMechanicalInvariants(
            from: currentPhase,
            to: requestedPhase,
            authority: authority
        )

        // Step 2: Emit telemetry for attempt
        _ = await telemetry.emit(
            category: .audit,
            name: "phase_transition_attempted",
            values: [
                "transition_id": .hashedToken(TelemetryHash(input: transitionID)),
                "from_phase": .hashedToken(TelemetryHash(input: currentPhase)),
                "to_phase": .hashedToken(TelemetryHash(input: requestedPhase)),
                "authority": .hashedToken(TelemetryHash(input: authority))
            ]
        )

        // Step 3: Call external policy evaluator
        let decision = try await policyEvaluator.evaluatePhaseTransition(
            from: currentPhase,
            to: requestedPhase,
            authority: authority,
            context: context
        )

        // Step 4: Record the decision
        _ = try await receiptEngine.recordPhaseTransition(
            transitionID: transitionID,
            fromPhase: currentPhase,
            toPhase: requestedPhase,
            authority: authority,
            decision: decision.decision,
            reasonCode: decision.reasonCode,
            context: context,
            metadata: decision.metadata
        )

        // Step 5: Emit telemetry for completion
        _ = await telemetry.emit(
            category: .audit,
            name: "phase_transition_completed",
            values: [
                "transition_id": .hashedToken(TelemetryHash(input: transitionID)),
                "decision": .limitedTag(try decisionTag(for: decision.decision)),
                "reason_code": .hashedToken(TelemetryHash(input: decision.reasonCode))
            ]
        )

        return decision
    }

    /// Validates mechanical invariants only (no policy logic).
    /// These are structural rules that don't depend on external doctrine.
    private func validateMechanicalInvariants(
        from currentPhase: String,
        to requestedPhase: String,
        authority: String
    ) throws {
        // Rule: Cannot transition to same phase
        if currentPhase == requestedPhase {
            throw PhaseGateError.samePhase(currentPhase: currentPhase)
        }

        // Rule: Must have authority (non-empty)
        if authority.isEmpty || authority.trimmingCharacters(in: .whitespaces).isEmpty {
            throw PhaseGateError.invalidAuthority(authority: authority)
        }

        // Rule: Phase names must be non-empty
        if currentPhase.isEmpty || requestedPhase.isEmpty {
            throw PhaseGateError.invalidPhaseName(
                current: currentPhase,
                requested: requestedPhase
            )
        }

        // Rule: If known phases are defined, both must be known
        if !knownPhases.isEmpty {
            if !knownPhases.contains(currentPhase) || !knownPhases.contains(requestedPhase) {
                throw PhaseGateError.unknownPhase(
                    current: currentPhase,
                    requested: requestedPhase,
                    known: knownPhases
                )
            }
        }

        // Add more mechanical invariants as needed
        // Examples: "cannot go backwards in sequence", "must pass through intermediate phases"
        // But these must be purely structural, not policy-based
    }

    /// Converts decision to telemetry-safe tag
    private func decisionTag(for decision: ReceiptDecision) throws -> TelemetryTag {
        switch decision {
        case .allowed:
            return try TelemetryTag("audit.phase_decision.allowed")
        case .denied:
            return try TelemetryTag("audit.phase_decision.denied")
        case .auditRequired:
            return try TelemetryTag("audit.phase_decision.audit_required")
        case .quarantine:
            return try TelemetryTag("audit.phase_decision.quarantine")
        case .error:
            return try TelemetryTag("audit.phase_decision.error")
        }
    }
}

// MARK: - Phase Gate Errors

/// Errors thrown by phase gate mechanical validation.
/// These are NOT policy errors - these are structural violations.
public enum PhaseGateError: Error, LocalizedError {
    case samePhase(currentPhase: String)
    case invalidAuthority(authority: String)
    case invalidPhaseName(current: String, requested: String)
    case unknownPhase(current: String, requested: String, known: [String])

    public var errorDescription: String? {
        switch self {
        case .samePhase(let currentPhase):
            return "Cannot transition from '\(currentPhase)' to same phase"
        case .invalidAuthority(let authority):
            return "Invalid authority: '\(authority)'"
        case .invalidPhaseName(let current, let requested):
            return "Invalid phase names - current: '\(current)', requested: '\(requested)'"
        case .unknownPhase(let current, let requested, let known):
            return
                "Unknown phases - current: '\(current)', requested: '\(requested)', known: \(known.joined(separator: ", "))"
        }
    }
}
