//
//  AnigmaCoreAdapters.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import AnigmaPrimitives
import ContractsCore
import CryptoKit
import Foundation
import OSLog

/// Internal protocol for evidence recording in AnigmaCore.

private let log = os.Logger(subsystem: "com.anigma.core", category: "adapters")
///
/// > Warning: This is an internal protocol. For boundary contracts, use `ContractsCore.EvidenceRecording`.
/// > For loop event recording in tool router, use `AnigmaPrimitives.LoopEvidenceRecorder`.
@available(
    *, deprecated,
    message:
        "Use ContractsCore.EvidenceRecording for boundary contracts or AnigmaPrimitives.LoopEvidenceRecorder for loop events"
)
public protocol EvidenceRecorder: Sendable {
    func recordEvidence(
        evidenceId: String,
        headHash: String,
        content: Data,
        metadata: [String: String]
    ) async throws

    func recordIRGraph(
        graphId: String,
        nodeCount: Int,
        edgeCount: Int,
        metadata: [String: String]
    ) async throws

    func recordStateDelta(
        sessionId: String,
        delta: FoundationContracts.StateDelta,
        timestamp: Date
    ) async throws
}

/// Concrete adapter for AnigmaCore audit logging
public struct AnigmaAuditLogger: AuditLogging {
    private let manager: AuditLogManager

    public init(_ manager: AuditLogManager) {
        self.manager = manager
    }

    public func recordEvent(
        id: UUID,
        type: ContractsCore.AuditEventType,
        principal: String?,
        module: String?,
        description: String,
        metadata: [String: String]
    ) async throws {
        try await manager.recordEvent(
            id: id,
            type: type,
            principal: principal,
            module: module,
            description: description,
            metadata: metadata
        )
    }
}

/// Concrete adapter for AnigmaCore evidence recording
public struct AnigmaEvidenceRecorder: EvidenceRecording {
    private let recorder: any EvidenceRecording

    public init(_ recorder: any EvidenceRecording) {
        self.recorder = recorder
    }

    public func recordEvidence(
        head: EvidenceHead,
        content: Data
    ) async throws {
        try await recorder.recordEvidence(head: head, content: content)
    }

    public func recordStateDelta(
        sessionId: String,
        delta: FoundationContracts.StateDelta,
        timestamp: Date
    ) async throws {
        try await recorder.recordStateDelta(
            sessionId: sessionId, delta: delta, timestamp: timestamp)
    }
}

/// Mock evidence recorder that implements the full EvidenceRecording protocol
public actor MockEvidenceRecorder: EvidenceRecording {
    public func recordEvidence(
        head: EvidenceHead,
        content: Data
    ) async throws {
        // Mock implementation - just log that we received evidence
        log.info("MockEvidenceRecorder: Recorded evidence \(head.headId, privacy: .public)")
    }

    public func recordStateDelta(
        sessionId: String,
        delta: FoundationContracts.StateDelta,
        timestamp: Date
    ) async throws {
        // Mock implementation
        log.info("MockEvidenceRecorder: Recorded state delta for session \(sessionId, privacy: .public)")
    }
}
