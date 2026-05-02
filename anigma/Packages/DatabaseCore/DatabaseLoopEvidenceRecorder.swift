//
//  DatabaseLoopEvidenceRecorder.swift
//  DatabaseCore
//
//  Persists loop breaker events to loop_events table
//

import AnigmaPrimitives
import CryptoKit
import Foundation

public actor DatabaseLoopEvidenceRecorder: LoopEvidenceRecorder {
    public let databaseActor: DatabaseActor

    public init(databaseActor: DatabaseActor) {
        self.databaseActor = databaseActor
    }

    public func recordLoopEvent(
        toolCallId: String,
        event: LoopEvent,
        fingerprint: String,
        context: [String: Sendable]
    ) async throws {
        let eventId = UUID().uuidString
        let signatureHash = SHA256.hash(data: Data(fingerprint.utf8)).compactMap {
            String(format: "%02x", $0)
        }.joined()
        let contextJSON = try? JSONSerialization.data(withJSONObject: context, options: [])
        let contextString = contextJSON != nil ? String(data: contextJSON!, encoding: .utf8) : "{}"

        // Extract recovery strategy if present
        let recoveryStrategy: String? = context["recovery_strategy"] as? String

        _ = try await databaseActor.executeAsync(
            """
            INSERT INTO loop_events (
                id, tool_call_id, event_type, signature_hash,
                threshold, window_seconds, recovery_strategy, context
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(eventId),
                .text(toolCallId),
                .text(event.rawValue),
                .text(signatureHash),
                .int(3),  // Default threshold
                .int(60),  // Default window
                .text(recoveryStrategy ?? ""),
                .text(contextString ?? "{}")
            ]
        )
    }
}
