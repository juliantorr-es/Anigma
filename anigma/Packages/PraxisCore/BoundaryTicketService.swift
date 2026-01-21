//
//  BoundaryTicketService.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import CryptoKit
import Foundation

/// Event describing why PraxisModule blocked progression.
public struct BlockageEvent: Sendable {
    public let sessionID: String
    public let patchHash: String?
    public let violatedRuleIDs: [String]
    public let gateName: String?
    public let receiptIDs: [String]
    public let reason: String
    public let timestamp: Date
    public let phaseId: String?
    public let acceptanceRefs: [String]
    public let stopState: WorkflowStopState

    public init(
        sessionID: String,
        patchHash: String?,
        violatedRuleIDs: [String],
        gateName: String? = nil,
        receiptIDs: [String] = [],
        reason: String,
        timestamp: Date = Date(),
        phaseId: String? = nil,
        acceptanceRefs: [String] = [],
        stopState: WorkflowStopState = .blocked
    ) {
        self.sessionID = sessionID
        self.patchHash = patchHash
        self.violatedRuleIDs = violatedRuleIDs
        self.gateName = gateName
        self.receiptIDs = receiptIDs
        self.reason = reason
        self.timestamp = timestamp
        self.phaseId = phaseId
        self.acceptanceRefs = acceptanceRefs
        self.stopState = stopState
    }
}

/// Structured boundary ticket that describes a block.
public struct BoundaryTicket: Codable, Sendable {
    public let ticketID: String
    public let sessionID: String
    public let patchHash: String?
    public let violatedRuleIDs: [String]
    public let gateName: String?
    public let receipts: [String]
    public let reason: String
    public let timestamp: Date
    public let phaseId: String?
    public let acceptanceRefs: [String]
    public let stopState: WorkflowStopState

    public init(
        ticketID: String,
        sessionID: String,
        patchHash: String?,
        violatedRuleIDs: [String],
        gateName: String?,
        receipts: [String],
        reason: String,
        timestamp: Date,
        phaseId: String?,
        acceptanceRefs: [String],
        stopState: WorkflowStopState
    ) {
        self.ticketID = ticketID
        self.sessionID = sessionID
        self.patchHash = patchHash
        self.violatedRuleIDs = violatedRuleIDs
        self.gateName = gateName
        self.receipts = receipts
        self.reason = reason
        self.timestamp = timestamp
        self.phaseId = phaseId
        self.acceptanceRefs = acceptanceRefs
        self.stopState = stopState
    }
}

/// Service that generates and persists boundary tickets.
public struct BoundaryTicketService: Sendable {
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        let base = storageURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        self.storageURL = base.appendingPathComponent("Artifacts/praxis/tickets", isDirectory: true)
    }

    public func createTicket(from event: BlockageEvent) throws -> BoundaryTicket {
        let normalizedRules = event.violatedRuleIDs.sorted()
        let hashPayload = "\(event.sessionID)|\(event.patchHash ?? "head")|\(normalizedRules.joined(separator: ","))|\(event.reason)"
        let digest = SHA256.hash(data: Data(hashPayload.utf8))
        let ticketID = digest.map { String(format: "%02x", $0) }.joined()

        return BoundaryTicket(
            ticketID: ticketID,
            sessionID: event.sessionID,
            patchHash: event.patchHash,
            violatedRuleIDs: normalizedRules,
            gateName: event.gateName,
            receipts: event.receiptIDs,
            reason: event.reason,
            timestamp: event.timestamp,
            phaseId: event.phaseId,
            acceptanceRefs: event.acceptanceRefs,
            stopState: event.stopState
        )
    }

    @discardableResult
    public func persist(_ ticket: BoundaryTicket) throws -> URL {
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        let fileURL = storageURL.appendingPathComponent("\(ticket.ticketID).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(ticket)
        try data.write(to: fileURL, options: Data.WritingOptions.atomic)
        return fileURL
    }
}
