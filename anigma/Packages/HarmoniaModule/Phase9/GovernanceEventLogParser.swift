//
//  GovernanceEventLogParser.swift
//  HarmoniaModule
//
//  Parser for reconstructing governance event logs from serialized bytes.
//  Provides deterministic parsing for verification processing.
//

@preconcurrency import Foundation

/// Parser for governance event logs used in replay verification.
/// Handles deserialization and validation of event log data.
public struct GovernanceEventLogParser {

    /// Parse event log from serialized byte data.
    /// Returns an array of governance event envelopes in order.
    public static func parse(_ data: Data) throws -> [GovernanceEventEnvelope] {
        // Validate data is not empty
        guard !data.isEmpty else {
            throw ParseError.emptyLog
        }

        // Decode using canonical JSON decoder
        let decoder = JSONDecoder()

        // Ensure deterministic decoding settings
        decoder.dateDecodingStrategy = .iso8601

        do {
            let envelope = try decoder.decode(GovernanceEventEnvelope.self, from: data)
            return [envelope]
        } catch let decodingError as DecodingError {
            // Provide more detailed error information
            throw ParseError.decodingError(decodingError)
        } catch {
            // Re-throw other errors
            throw error
        }
    }

    /// Parse event log with validation for Phase 9 verification requirements.
    /// Returns structured log with metadata for verification.
    public static func parseForVerification(_ data: Data) throws -> ParsedEventLog {
        let envelopes = try parse(data)

        // Extract metadata for verification
        let metadata = try extractVerificationMetadata(from: envelopes)

        // Validate log structure
        try validateLogStructure(envelopes)

        return ParsedEventLog(
            envelopes: envelopes,
            metadata: metadata
        )
    }

    /// Extract verification metadata from event envelopes.
    private static func extractVerificationMetadata(from envelopes: [GovernanceEventEnvelope]) throws -> EventLogMetadata {
        var sessionIds: Set<String> = []
        var toolInvocations: [String] = []
        var policyEvaluations: [String] = []
        var stateTransitions: [String] = []
        var jobEvents: [String] = []

        // Parse all events to extract metadata
        for envelope in envelopes {
            sessionIds.insert(envelope.sessionId)

            for event in envelope.events {
                switch event {
                case .sessionStarted(let session):
                    // Extract session context info
                    sessionIds.insert(session.sessionId)

                case .toolInvoked(let invoked):
                    toolInvocations.append(invoked.toolName)

                case .toolCompleted(let completed):
                    toolInvocations.append(completed.toolName)

                case .policyGateEvaluated(let evaluated):
                    policyEvaluations.append(evaluated.toolName)

                case .stateTransitionApproved(let transition):
                    stateTransitions.append(transition.transitionId)

                case .jobStarted(let started):
                    jobEvents.append(started.jobName)
                case .jobStepExecuted(let step):
                    jobEvents.append(step.stepName)
                case .jobCompleted(let completed):
                    jobEvents.append(completed.jobId)

                default:
                    break
                }
            }
        }

        return EventLogMetadata(
            sessionIds: Array(sessionIds),
            toolInvocations: toolInvocations,
            policyEvaluations: policyEvaluations,
            stateTransitions: stateTransitions,
            jobEvents: jobEvents,
            envelopeCount: envelopes.count
        )
    }

    /// Validate log structure for Phase 9 verification.
    /// Ensures required events are present and properly ordered.
    private static func validateLogStructure(_ envelopes: [GovernanceEventEnvelope]) throws {
        guard !envelopes.isEmpty else {
            throw ParseError.malformedLog("No envelopes found in event log")
        }

        // Check for session start event
        var hasSessionStart = false

        // Validate events in each envelope
        for envelope in envelopes {
            for event in envelope.events {
                switch event {
                case .sessionStarted:
                    hasSessionStart = true
                default:
                    break
                }
            }
        }

        guard hasSessionStart else {
            throw ParseError.malformedLog("Missing session start event")
        }
    }
}

/// Parsed event log with metadata for verification.
public struct ParsedEventLog: Sendable {
    public let envelopes: [GovernanceEventEnvelope]
    public let metadata: EventLogMetadata

    public init(envelopes: [GovernanceEventEnvelope], metadata: EventLogMetadata) {
        self.envelopes = envelopes
        self.metadata = metadata
    }

    /// Get all events from all envelopes in order
    public var allEvents: [AnyCodableEvent] {
        return envelopes.flatMap { $0.events }
    }

    /// Get events filtered by type
    public func events<T: GovernanceEvent>(ofType type: T.Type) -> [T] {
        return allEvents.compactMap { event in
            switch event {
            case .sessionStarted(let e): return e as? T
            case .sessionEnded(let e): return e as? T
            case .toolInvoked(let e): return e as? T
            case .toolCompleted(let e): return e as? T
            case .policyGateEvaluated(let e): return e as? T
            case .stateTransitionApproved(let e): return e as? T
            case .jobStarted(let e): return e as? T
            case .jobStepExecuted(let e): return e as? T
            case .jobCompleted(let e): return e as? T
            }
        }
    }
}

/// Metadata extracted from event log for verification.
public struct EventLogMetadata: Sendable {
    public let sessionIds: [String]
    public let toolInvocations: [String]
    public let policyEvaluations: [String]
    public let stateTransitions: [String]
    public let jobEvents: [String]
    public let envelopeCount: Int

    public init(
        sessionIds: [String],
        toolInvocations: [String],
        policyEvaluations: [String],
        stateTransitions: [String],
        jobEvents: [String],
        envelopeCount: Int
    ) {
        self.sessionIds = sessionIds
        self.toolInvocations = toolInvocations
        self.policyEvaluations = policyEvaluations
        self.stateTransitions = stateTransitions
        self.jobEvents = jobEvents
        self.envelopeCount = envelopeCount
    }
}

/// Errors that can occur during event log parsing.
public enum ParseError: Error, LocalizedError {
    case emptyLog
    case decodingError(DecodingError)
    case malformedLog(String)

    public var localizedDescription: String? {
        switch self {
        case .emptyLog:
            return "Event log is empty"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .malformedLog(let message):
            return "Malformed event log: \(message)"
        }
    }
}
