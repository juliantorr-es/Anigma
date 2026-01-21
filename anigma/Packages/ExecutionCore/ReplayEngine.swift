//
//  ReplayEngine.swift
//  ExecutionCore
//
//  Engine for deterministic replay from receipt chains.
//  Verifies that execution can be reproduced from receipts.
//

import Foundation
import TelemetryCore

// MARK: - Replay Engine

/// Engine for replaying execution from receipt chains.
/// Enables verification that recorded operations can be reproduced deterministically.
public actor ReplayEngine {
    private let telemetry: TelemetryClient

    public init(telemetry: TelemetryClient) {
        self.telemetry = telemetry
    }

    /// Replays a sequence of receipts and verifies chain integrity.
    /// Returns a report detailing the replay results.
    public func replay(receipts: [ReceiptWire]) async throws -> ReplayReport {
        let startTime = Date()
        var events: [ReplayEvent] = []
        var divergences: [ReplayDivergence] = []

        // Sort receipts chronologically
        let sorted = receipts.sorted { $0.timestampMs < $1.timestampMs }

        // Verify chain integrity first
        let chainValid = try await verifyChainIntegrity(receipts: sorted)
        if !chainValid {
            divergences.append(
                ReplayDivergence(
                    receiptID: sorted.first?.receiptID ?? "unknown",
                    type: .brokenChain,
                    description: "Receipt chain integrity check failed",
                    severity: .critical
                ))
        }

        // Replay each receipt
        for (index, receipt) in sorted.enumerated() {
            let event = try await replayReceipt(receipt, index: index)
            events.append(event)

            // Check for divergences
            if let divergence = detectDivergence(receipt: receipt, event: event) {
                divergences.append(divergence)
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        let report = ReplayReport(
            totalReceipts: receipts.count,
            successfulReplays: events.filter { $0.success }.count,
            failedReplays: events.filter { !$0.success }.count,
            divergences: divergences,
            chainValid: chainValid,
            durationSeconds: duration,
            events: events
        )

        // Emit telemetry
        _ = await telemetry.emit(
            category: .audit,
            name: "replay_completed",
            values: [
                "total_receipts": .integer(receipts.count),
                "successful": .integer(report.successfulReplays),
                "divergences": .integer(divergences.count),
                "chain_valid": .boolean(chainValid)
            ]
        )

        return report
    }

    /// Verifies the integrity of a receipt chain.
    private func verifyChainIntegrity(receipts: [ReceiptWire]) async throws -> Bool {
        guard !receipts.isEmpty else { return true }

        // First receipt should have no previous hash
        guard receipts[0].previousReceiptHash == nil else {
            return false
        }

        // Verify each subsequent receipt links to the previous one
        for i in 1..<receipts.count {
            let current = receipts[i]
            let previous = receipts[i - 1]

            // Verify the chain link
            guard current.previousReceiptHash == previous.receiptID else {
                return false
            }

            // Verify receipt ID matches content hash
            do {
                try current.verifyReceiptID()
            } catch {
                return false
            }
        }

        return true
    }

    /// Replays a single receipt and records the event.
    private func replayReceipt(_ receipt: ReceiptWire, index: Int) async throws -> ReplayEvent {
        // In a real implementation, this would re-execute the action
        // For now, we verify the receipt structure and metadata

        let success = receipt.signature != nil && !receipt.signature!.isEmpty

        return ReplayEvent(
            receiptID: receipt.receiptID,
            actionName: receipt.actionName,
            index: index,
            timestampMs: receipt.timestampMs,
            decision: receipt.decision,
            success: success,
            metadata: receipt.metadata
        )
    }

    /// Detects divergences between expected and actual replay results.
    private func detectDivergence(receipt: ReceiptWire, event: ReplayEvent) -> ReplayDivergence? {
        // Check for signature issues
        if receipt.signature == nil || receipt.signature!.isEmpty {
            return ReplayDivergence(
                receiptID: receipt.receiptID,
                type: .missingSignature,
                description: "Receipt lacks cryptographic signature",
                severity: .high
            )
        }

        // Check for replay failure
        if !event.success {
            return ReplayDivergence(
                receiptID: receipt.receiptID,
                type: .replayFailed,
                description: "Receipt replay did not succeed",
                severity: .medium
            )
        }

        return nil
    }
}

// MARK: - Replay Types

/// Report of a replay operation.
public struct ReplayReport: Codable, Sendable {
    /// Total number of receipts processed
    public let totalReceipts: Int

    /// Number of successful replays
    public let successfulReplays: Int

    /// Number of failed replays
    public let failedReplays: Int

    /// Detected divergences from expected behavior
    public let divergences: [ReplayDivergence]

    /// Whether the receipt chain is valid
    public let chainValid: Bool

    /// Duration of replay in seconds
    public let durationSeconds: TimeInterval

    /// Individual replay events
    public let events: [ReplayEvent]

    /// Overall success status
    public var success: Bool {
        return chainValid && divergences.isEmpty && failedReplays == 0
    }
}

/// Individual replay event.
public struct ReplayEvent: Codable, Sendable {
    /// Receipt ID being replayed
    public let receiptID: String

    /// Action name
    public let actionName: String

    /// Index in replay sequence
    public let index: Int

    /// Original timestamp
    public let timestampMs: Int64

    /// Decision from receipt
    public let decision: ReceiptDecision

    /// Whether replay succeeded
    public let success: Bool

    /// Metadata from receipt
    public let metadata: [String: TelemetryValue]
}

/// Divergence detected during replay.
public struct ReplayDivergence: Codable, Sendable {
    /// Receipt ID where divergence occurred
    public let receiptID: String

    /// Type of divergence
    public let type: DivergenceType

    /// Human-readable description
    public let description: String

    /// Severity level
    public let severity: DivergenceSeverity

    public enum DivergenceType: String, Codable, Sendable {
        case brokenChain = "broken_chain"
        case missingSignature = "missing_signature"
        case invalidHash = "invalid_hash"
        case replayFailed = "replay_failed"
        case outputMismatch = "output_mismatch"
    }

    public enum DivergenceSeverity: String, Codable, Sendable {
        case critical = "critical"
        case high = "high"
        case medium = "medium"
        case low = "low"
    }
}
