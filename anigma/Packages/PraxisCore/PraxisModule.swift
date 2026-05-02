//
//  PraxisModule.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Prisma representation of a patch summary for diagnostics.
public struct PatchSummary: Codable, Sendable {
    public let patchHash: String?
    public let recordCount: Int
    public let gateOutcomes: [String]
    public let missingPhases: [String]
    public let blocked: Bool
    public let phaseId: String?
    public let acceptanceRefs: [String]
    public let gateFailures: [GateFailure]

    public init(
        patchHash: String?,
        recordCount: Int,
        gateOutcomes: [String],
        missingPhases: [String],
        blocked: Bool,
        phaseId: String?,
        acceptanceRefs: [String],
        gateFailures: [GateFailure]
    ) {
        self.patchHash = patchHash
        self.recordCount = recordCount
        self.gateOutcomes = gateOutcomes
        self.missingPhases = missingPhases
        self.blocked = blocked
        self.phaseId = phaseId
        self.acceptanceRefs = acceptanceRefs
        self.gateFailures = gateFailures
    }
}

/// Session-level summary for diagnostics.
public struct SessionSummary: Codable, Sendable {
    public let sessionID: String
    public let patchSummaries: [PatchSummary]
    public let quarantineReasons: [String]
    public let missingPhases: [String]
    public let gateFailures: [GateFailure]

    public init(sessionID: String, patchSummaries: [PatchSummary], quarantineReasons: [String], missingPhases: [String], gateFailures: [GateFailure]) {
        self.sessionID = sessionID
        self.patchSummaries = patchSummaries
        self.quarantineReasons = quarantineReasons
        self.missingPhases = missingPhases
        self.gateFailures = gateFailures
    }
}

/// Diagnostic payload describing Praxis state.
public struct PraxisDiagnosis: Codable, Sendable {
    public let sessions: [SessionSummary]

    public init(sessions: [SessionSummary]) {
        self.sessions = sessions
    }
}

/// Main PraxisModule environment that wires rulepack, workflow, session index, and ticketing.
public struct PraxisModuleEnvironment: Sendable {
    public let rulepack: Rulepack
    public let workflow: WorkflowSpec
    public let sessionIndex: PraxisSessionIndex
    public let ticketService: BoundaryTicketService

    public init(rulepack: Rulepack, workflow: WorkflowSpec, sessionIndex: PraxisSessionIndex, ticketService: BoundaryTicketService) {
        self.rulepack = rulepack
        self.workflow = workflow
        self.sessionIndex = sessionIndex
        self.ticketService = ticketService
    }

    public func diagnose(sessionID: String? = nil) -> PraxisDiagnosis {
        let sessions = sessionIndex.describeSessions()
        let filtered = sessionID.flatMap { id in
            sessions.first { $0.sessionID == id }.map { [$0] }
        } ?? sessions

        let summaries = filtered.map { session -> SessionSummary in
            let patchSummaries = session.patchChains.map { chain in
                let missing = PraxisSessionIndex.missingPhases(in: chain.records)
                let blocked = !missing.isEmpty || !chain.gateFailures.isEmpty
                return PatchSummary(
                    patchHash: chain.patchHash,
                    recordCount: chain.records.count,
                    gateOutcomes: chain.gateOutcomes,
                    missingPhases: missing,
                    blocked: blocked,
                    phaseId: chain.phaseId,
                    acceptanceRefs: chain.acceptanceRefs,
                    gateFailures: chain.gateFailures
                )
            }
            return SessionSummary(
                sessionID: session.sessionID,
                patchSummaries: patchSummaries,
                quarantineReasons: session.quarantineReasons,
                missingPhases: session.missingPhases,
                gateFailures: session.gateFailures
            )
        }

        return PraxisDiagnosis(sessions: summaries)
    }

    public func createBoundaryTicket(for event: BlockageEvent) throws -> BoundaryTicket {
        let ticket = try ticketService.createTicket(from: event)
        _ = try ticketService.persist(ticket)
        return ticket
    }
}
