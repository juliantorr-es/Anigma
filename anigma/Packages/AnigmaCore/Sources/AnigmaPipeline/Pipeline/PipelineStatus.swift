//
//  PipelineStatus.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import ContractsCore
import DatabaseCore
import Foundation

/// Compact status snapshot for a pipeline session.
public struct PipelineStatus: Sendable, Codable {
    public let statusSchemaVersion: Int
    public let sessionID: String
    public let nextEligible: [String]
    public let blocked: [BlockedContractStatus]
    public let quarantined: [ContractReceipt]
    public let pendingJobs: [RunContractJobRecord]
    public let runningJobs: [RunContractJobRecord]

    public init(
        statusSchemaVersion: Int = 1,
        sessionID: String,
        nextEligible: [String],
        blocked: [BlockedContractStatus],
        quarantined: [ContractReceipt],
        pendingJobs: [RunContractJobRecord],
        runningJobs: [RunContractJobRecord]
    ) {
        self.statusSchemaVersion = statusSchemaVersion
        self.sessionID = sessionID
        self.nextEligible = nextEligible
        self.blocked = blocked
        self.quarantined = quarantined
        self.pendingJobs = pendingJobs
        self.runningJobs = runningJobs
    }
}

/// Details about a blocked contract and the upstream statuses causing the block.
public struct BlockedContractStatus: Sendable, Codable {
    public let contractID: ContractID
    public let upstreamStatuses: [ContractID: ContractStatus]
}
