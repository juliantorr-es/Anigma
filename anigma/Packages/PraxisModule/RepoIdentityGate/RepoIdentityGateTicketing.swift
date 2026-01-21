//
//  RepoIdentityGateTicketing.swift
//  PraxisModule
//
//  [Brief description of file purpose]
//

import Foundation
import PraxisCore

public struct RepoIdentityGateTicketPayload: Sendable, Codable {
    public let gate: String
    public let ok: Bool
    public let failure: RepoIdentityGateFailure?
    public let message: String
    public let probe: GitProbe?
    public let timestamp: String

    public init(gate: String, ok: Bool, failure: RepoIdentityGateFailure?, message: String, probe: GitProbe?, timestamp: String) {
        self.gate = gate
        self.ok = ok
        self.failure = failure
        self.message = message
        self.probe = probe
        self.timestamp = timestamp
    }
}

public extension RepoIdentityGate {
    func emitTicketIfBlocked(
        result: RepoIdentityGateResult,
        phaseID: String,
        acceptanceRefs: [String],
        ticketService: BoundaryTicketService,
        artifactsDir: URL
    ) async {
        guard result.ok == false else { return }

        let payload = RepoIdentityGateTicketPayload(
            gate: "RepoIdentityGate",
            ok: result.ok,
            failure: result.failure,
            message: result.message,
            probe: result.probe,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        do {
            let encoded = try JSONEncoder().encode(payload)
            let payloadURL = artifactsDir
                .appendingPathComponent("praxis", isDirectory: true)
                .appendingPathComponent("tickets", isDirectory: true)
                .appendingPathComponent("repo-identity-block-\(UUID().uuidString).json")

            try FileManager.default.createDirectory(at: payloadURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoded.write(to: payloadURL, options: [.atomic])

            let gateName = "RepoIdentityGate"
            let sessionID = result.probe?.headSHA ?? UUID().uuidString
            let ticket = try ticketService.createTicket(from: BlockageEvent(
                sessionID: sessionID,
                patchHash: result.probe?.headSHA,
                violatedRuleIDs: result.failure.map { [$0.rawValue] } ?? ["repo-identity"],
                gateName: gateName,
                receiptIDs: ["repo_identity_payload:\(payloadURL.path)"],
                reason: result.message,
                phaseId: phaseID,
                acceptanceRefs: acceptanceRefs,
                stopState: .blocked
            ))

            _ = try ticketService.persist(ticket)
        } catch {
            // Do not crash; the gate result is already blocking.
        }
    }
}
