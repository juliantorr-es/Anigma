// HarmoniaRuntime Receipt Spine
// Minimal receipt and audit-event emission for HarmoniaRuntime actions

import Foundation
import HarmoniaV2Contracts
import AnigmaPrimitives
import ExecutionCore
import TelemetryCore

// MARK: - HarmoniaRuntime Receipt Types

/// Action types for HarmoniaRuntime receipts
public enum HarmoniaRuntimeAction: String, Sendable, Codable {
    case queryExecution = "harmonia.query"
    case statusCheck = "harmonia.status"
    case capabilityCheck = "harmonia.capability"
    case phase9Execution = "harmonia.phase9"
    case policyEvaluation = "harmonia.policy"
    case toolExecution = "harmonia.tool"
    case errorResponse = "harmonia.error"
    case healthMonitor = "harmonia.health"
}

/// Actionable reason codes for HarmoniaRuntime operations
public enum HarmoniaRuntimeReasonCode: String, Sendable, Codable {
    // Success codes
    case success = "SUCCESS"
    case partialSuccess = "PARTIAL_SUCCESS"
    
    // Configuration codes
    case notConfigured = "NOT_CONFIGURED"
    case missingBackend = "MISSING_BACKEND"
    case incompleteMigration = "INCOMPLETE_MIGRATION"
    
    // Capability codes
    case capabilityDeferred = "CAPABILITY_DEFERRED"
    case capabilityPartial = "CAPABILITY_PARTIAL"
    case capabilityUnavailable = "CAPABILITY_UNAVAILABLE"
    
    // Integration codes
    case integrationPending = "INTEGRATION_PENDING"
    case facadeRouting = "FACADE_ROUTING"
    case backendFailure = "BACKEND_FAILURE"
    
    // Policy codes
    case policyDenied = "POLICY_DENIED"
    case governanceRequired = "GOVERNANCE_REQUIRED"
    
    // Technical codes
    case validationFailed = "VALIDATION_FAILED"
    case serializationFailed = "SERIALIZATION_FAILED"
    case timeoutExceeded = "TIMEOUT_EXCEEDED"
}

private func canonicalJSONString<T: Encodable>(from value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .millisecondsSince1970

    guard
        let data = try? encoder.encode(value),
        let string = String(data: data, encoding: .utf8)
    else {
        return "{}"
    }

    return string
}

private func stableTimestampMs(from seed: String) -> Int64 {
    let hash = TelemetryHash(input: seed).hex
    let prefix = String(hash.prefix(16))
    let value = UInt64(prefix, radix: 16) ?? 0
    return Int64(bitPattern: value & 0x7FFF_FFFF_FFFF_FFFF)
}

/// HarmoniaRuntime-specific receipt metadata keys
public enum HarmoniaReceiptMetadataKey: String {
    case capabilityArea = "capability_area"
    case runtimeVersion = "runtime_version"
    case facadeVersion = "facade_version"
    case backendReference = "backend_reference"
    case policyContext = "policy_context"
    case evidenceReference = "evidence_reference"
}

// MARK: - Receipt Generation

/// Minimal receipt generator for HarmoniaRuntime actions
public struct HarmoniaReceiptGenerator {
    private let authority: String
    private let runtimeVersion: String
    private let timestampSeedProvider: (String) -> Int64
    
    public init(
        authority: String = "HarmoniaRuntime",
        runtimeVersion: String = "1.0.0",
        timestampSeedProvider: @escaping (String) -> Int64 = { seed in
            let hash = TelemetryHash(input: seed).hex
            let prefix = String(hash.prefix(16))
            let value = UInt64(prefix, radix: 16) ?? 0
            return Int64(bitPattern: value & 0x7FFF_FFFF_FFFF_FFFF)
        }
    ) {
        self.authority = authority
        self.runtimeVersion = runtimeVersion
        self.timestampSeedProvider = timestampSeedProvider
    }
    
    /// Generate a receipt for a HarmoniaRuntime action
    public func generateReceipt(
        action: HarmoniaRuntimeAction,
        decision: ReceiptDecision,
        reasonCode: HarmoniaRuntimeReasonCode,
        inputsHash: TelemetryHash,
        outputsHash: TelemetryHash? = nil,
        capabilityArea: HarmoniaRuntimeCapabilityState? = nil,
        policyContext: String? = nil,
        evidenceReference: String? = nil,
        previousReceiptHash: String? = nil
    ) -> ReceiptWire {
        var metadata: [String: TelemetryValue] = [
            HarmoniaReceiptMetadataKey.runtimeVersion.rawValue: .string(runtimeVersion),
            HarmoniaReceiptMetadataKey.facadeVersion.rawValue: .string("1.0")
        ]
        
        if let capabilityArea = capabilityArea {
            metadata[HarmoniaReceiptMetadataKey.capabilityArea.rawValue] = .string(capabilityArea.rawValue)
        }
        
        if let policyContext = policyContext {
            metadata[HarmoniaReceiptMetadataKey.policyContext.rawValue] = .string(policyContext)
        }
        
        if let evidenceReference = evidenceReference {
            metadata[HarmoniaReceiptMetadataKey.evidenceReference.rawValue] = .string(evidenceReference)
        }

        let timestampSeed = [
            "authority=\(authority)",
            "runtime_version=\(runtimeVersion)",
            "facade_version=1.0",
            "action=\(action.rawValue)",
            "decision=\(decision.rawValue)",
            "reason_code=\(reasonCode.rawValue)",
            "inputs_algorithm=\(inputsHash.algorithm.rawValue)",
            "inputs_hash=\(inputsHash.hex)",
            "outputs_algorithm=\(outputsHash?.algorithm.rawValue ?? "-")",
            "outputs_hash=\(outputsHash?.hex ?? "-")",
            "capability_area=\(capabilityArea?.rawValue ?? "-")",
            "policy_context=\(policyContext ?? "-")",
            "evidence_reference=\(evidenceReference ?? "-")",
            "previous_receipt_hash=\(previousReceiptHash ?? "-")",
            "metadata=\(canonicalJSONString(from: metadata))"
        ].joined(separator: "|")
        
        return ReceiptWire.create(
            actionName: action.rawValue,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode.rawValue,
            timestampMs: timestampSeedProvider(timestampSeed),
            inputsHash: inputsHash,
            outputsHash: outputsHash,
            previousReceiptHash: previousReceiptHash,
            metadata: metadata
        )
    }
    
    /// Generate a hash from input data for receipt stability
    public func generateInputHash(from input: String) -> TelemetryHash {
        TelemetryHash(input: input)
    }
    
    /// Generate a hash from multiple components
    public func generateCompositeHash(components: [String]) -> TelemetryHash {
        let compositeString = components.joined(separator: "|")
        return generateInputHash(from: compositeString)
    }
}

// MARK: - Audit Event Emission

/// Minimal audit event emitter for HarmoniaRuntime
public struct HarmoniaAuditEmitter {
    private let authority: String
    private let system: String
    
    public init(authority: String = "HarmoniaRuntime", system: String = "harmonia") {
        self.authority = authority
        self.system = system
    }
    
    /// Emit an audit event for a runtime action
    public func emitAuditEvent(
        action: HarmoniaRuntimeAction,
        outcome: ReceiptDecision,
        reasonCode: HarmoniaRuntimeReasonCode,
        actor: String,
        policyContext: String? = nil,
        evidenceReference: String? = nil,
        timestampMs: Int64? = nil,
        correlationID: String? = nil,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        metadata: [String: String] = [:]
    ) -> DiagnosticEvent {
        var eventMetadata = metadata
        eventMetadata["actor"] = actor
        if let policyContext, !policyContext.isEmpty {
            eventMetadata["policy_context"] = policyContext
        }
        if let evidenceReference, !evidenceReference.isEmpty {
            eventMetadata["evidence_reference"] = evidenceReference
        }
        if let spanID, !spanID.isEmpty {
            eventMetadata["span_id"] = spanID
        }
        if let parentSpanID, !parentSpanID.isEmpty {
            eventMetadata["parent_span_id"] = parentSpanID
        }
        eventMetadata["action"] = action.rawValue
        eventMetadata["outcome"] = outcome.rawValue
        eventMetadata["reason_code"] = reasonCode.rawValue
        eventMetadata["authority"] = authority
        eventMetadata["system"] = system

        let canonicalSeed = [
            "authority=\(authority)",
            "system=\(system)",
            "action=\(action.rawValue)",
            "outcome=\(outcome.rawValue)",
            "reason_code=\(reasonCode.rawValue)",
            "metadata=\(canonicalJSONString(from: eventMetadata))"
        ].joined(separator: "|")
        
        let level: DiagnosticLevel = outcome == .error ? .error : .info
        let eventTimestamp = timestampMs.map {
            Date(timeIntervalSince1970: TimeInterval($0) / 1000.0)
        } ?? Date(timeIntervalSince1970: TimeInterval(stableTimestampMs(from: canonicalSeed)) / 1000.0)
        let eventCorrelationID = correlationID ?? evidenceReference ?? TelemetryHash(input: canonicalSeed).hex
        
        return DiagnosticEvent(
            timestamp: eventTimestamp,
            level: level,
            category: "harmonia.runtime",
            message: "[HarmoniaRuntime] Action: \(action.rawValue), Outcome: \(outcome.rawValue), Reason: \(reasonCode.rawValue)",
            correlationID: eventCorrelationID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            duration: nil,
            metadata: eventMetadata
        )
    }
}

// MARK: - Actionable Error Enhancements

extension HarmoniaRuntimeError {
    /// Convert to actionable error with receipt context
    public func toActionableError(
        action: HarmoniaRuntimeAction,
        reasonCode: HarmoniaRuntimeReasonCode,
        helpContext: String? = nil
    ) -> HarmoniaRuntimeActionableError {
        let helpMessage: String
        switch reasonCode {
        case .notConfigured:
            helpMessage = "This capability requires additional configuration. Check HarmoniaRuntime setup."
        case .missingBackend:
            helpMessage = "The required backend service is not available. Verify backend dependencies."
        case .incompleteMigration:
            helpMessage = "Migration from legacy systems is incomplete. Run migration tasks."
        case .capabilityDeferred:
            helpMessage = "This capability is planned but not yet implemented. See roadmap for details."
        case .capabilityPartial:
            helpMessage = "This capability is partially implemented. Some features may be limited."
        case .capabilityUnavailable:
            helpMessage = "This capability is not available in the current configuration."
        case .integrationPending:
            helpMessage = "Integration with required systems is pending. Check system connections."
        case .facadeRouting:
            helpMessage = "Request is being routed through the HarmoniaRuntime facade."
        case .backendFailure:
            helpMessage = "The backend returned an internal or vault error. Check the runtime journal and backend migration state."
        case .policyDenied:
            helpMessage = "Request was denied by governance policy. Check policy settings."
        case .governanceRequired:
            helpMessage = "Additional governance approval is required for this action."
        case .validationFailed:
            helpMessage = "Input validation failed. Verify request parameters."
        case .serializationFailed:
            helpMessage = "Data serialization failed. Check data formats."
        case .timeoutExceeded:
            helpMessage = "Operation timed out. Try again or check system load."
        default:
            helpMessage = "An error occurred. See error details for more information."
        }
        
        return HarmoniaRuntimeActionableError(
            baseError: self,
            action: action,
            reasonCode: reasonCode,
            helpMessage: helpMessage,
            helpContext: helpContext
        )
    }
}

/// Enhanced error type with actionable context
public struct HarmoniaRuntimeActionableError: LocalizedError, Sendable {
    public let baseError: HarmoniaRuntimeError
    public let action: HarmoniaRuntimeAction
    public let reasonCode: HarmoniaRuntimeReasonCode
    public let helpMessage: String
    public let helpContext: String?
    
    public var errorDescription: String? {
        return "\(baseError.errorDescription ?? "Unknown error") [Action: \(action.rawValue), Reason: \(reasonCode.rawValue)]"
    }
    
    public var recoverySuggestion: String? {
        return helpMessage
    }
    
    public var helpContextDetails: String? {
        return helpContext
    }
}

// MARK: - Runtime Integration

extension HarmoniaRuntime {
    /// Generate a receipt for runtime actions
    public static func generateReceipt(
        action: HarmoniaRuntimeAction,
        decision: ReceiptDecision,
        reasonCode: HarmoniaRuntimeReasonCode,
        input: String,
        capabilityArea: HarmoniaRuntimeCapabilityState? = nil,
        policyContext: String? = nil,
        outputsHash: TelemetryHash? = nil
    ) -> ReceiptWire {
        let generator = HarmoniaReceiptGenerator()
        let inputHash = generator.generateInputHash(from: input)
        
        return generator.generateReceipt(
            action: action,
            decision: decision,
            reasonCode: reasonCode,
            inputsHash: inputHash,
            outputsHash: outputsHash,
            capabilityArea: capabilityArea,
            policyContext: policyContext
        )
    }
    
    /// Emit an audit event for runtime actions
    public static func emitAuditEvent(
        action: HarmoniaRuntimeAction,
        outcome: ReceiptDecision,
        reasonCode: HarmoniaRuntimeReasonCode,
        actor: String = "system",
        policyContext: String? = nil,
        evidenceReference: String? = nil,
        timestampMs: Int64? = nil,
        correlationID: String? = nil,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        metadata: [String: String] = [:]
    ) -> DiagnosticEvent {
        let emitter = HarmoniaAuditEmitter()
        return emitter.emitAuditEvent(
            action: action,
            outcome: outcome,
            reasonCode: reasonCode,
            actor: actor,
            policyContext: policyContext,
            evidenceReference: evidenceReference,
            timestampMs: timestampMs,
            correlationID: correlationID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            metadata: metadata
        )
    }
    
    /// Create an actionable error from a runtime error
    public static func createActionableError(
        from error: HarmoniaRuntimeError,
        action: HarmoniaRuntimeAction,
        reasonCode: HarmoniaRuntimeReasonCode
    ) -> HarmoniaRuntimeActionableError {
        return error.toActionableError(action: action, reasonCode: reasonCode)
    }
}
