//
//  MLWorkerTypes.swift
//  ContractsCore
//
//  ML Worker type definitions.
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import AnigmaPrimitives
import Foundation

/// Types of tasks that can be performed by the ML Worker.
public enum MLWorkerTaskKind: String, Sendable, Codable {
    case embedding
    case chat
    case embed
    case generate
}
