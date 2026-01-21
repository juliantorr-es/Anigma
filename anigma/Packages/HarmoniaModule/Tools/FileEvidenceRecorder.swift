//
//  FileEvidenceRecorder.swift
//  HarmoniaModule
//
//  Simple file-based evidence recorder for Phase 7.3.
//  Stores evidence in files rather than database for simpler implementation.
//

import AnigmaPrimitives
import Foundation

/// Simple file-based evidence recorder.
/// Stores loop events and evidence bundles in files for audit trail.
public final class LoopFileEvidenceRecorder: LoopEvidenceRecorder, @unchecked Sendable {
    /// Directory for evidence files
    private let evidenceDirectory: String

    /// Create evidence recorder with directory
    public init(evidenceDirectory: String? = nil) {
        // Default to ./.evidence in current directory
        let defaultPath = FileManager.default.currentDirectoryPath + "/.evidence"
        self.evidenceDirectory = evidenceDirectory ?? defaultPath

        // Create directory if needed
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.evidenceDirectory) {
            try? fileManager.createDirectory(
                atPath: self.evidenceDirectory, withIntermediateDirectories: true)
        }
    }

    /// Record a loop breaker event to file.
    public func recordLoopEvent(
        toolCallId: String,
        event: LoopEvent,
        fingerprint: String,
        context: [String: Sendable]
    ) async throws {
        // Create event record
        let record = LoopEventRecord(
            toolCallId: toolCallId,
            event: event,
            fingerprint: fingerprint,
            context: context.mapValues { String(describing: $0) },
            timestamp: Date()
        )

        // Serialize to JSON
        // Get or create log file
        let logFile = evidenceDirectory + "/loop_events.md"

        // Append to file
        let entry = """

            # Loop Event at \(record.timestamp)
            * Tool Call ID: \(record.toolCallId)
            * Event: \(record.event.rawValue)
            * Fingerprint: \(record.fingerprint)
            * Context: \(record.context)

            """

        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile) {
                let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: logFile))
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try data.write(to: URL(fileURLWithPath: logFile))
            }
        }
    }

    /// Get evidence file path for session
    public func getEvidencePath(forSessionId sessionId: String) -> String {
        return evidenceDirectory + "/session_" + sessionId + ".md"
    }

    /// Create evidence file for tool call
    public func createEvidenceBundle(
        for request: ToolCallRequest,
        result: ToolCallResponse,
        session: SessionContext
    ) async throws -> String {
        let bundleId = UUID().uuidString
        let evidenceFile = evidenceDirectory + "/bundle_" + bundleId + ".json"

        let bundle = [
            "bundleId": bundleId,
            "sessionId": request.sessionId,
            "toolName": request.toolName,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "request": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)),
            "result": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)),
            "session": try JSONSerialization.jsonObject(with: JSONEncoder().encode(session))
        ]

        let data = try JSONSerialization.data(withJSONObject: bundle, options: [.prettyPrinted])
        try data.write(to: URL(fileURLWithPath: evidenceFile))

        return bundleId
    }
}
