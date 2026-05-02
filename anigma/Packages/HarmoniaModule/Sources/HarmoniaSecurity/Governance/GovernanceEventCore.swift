//
//  GovernanceEventCore.swift
//  HarmoniaModule
//
//  Shared protocol for governance events.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import DoctrineCore
@preconcurrency import Foundation

protocol GovernanceEvent: Sendable {
    var eventId: String { get }
    var eventType: String { get }
    var version: Int { get }
    var timestamp: Date { get }
    var sessionId: String { get }
}
