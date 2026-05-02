import Foundation
import FoundationContracts
import EvidenceContracts

/// Interface for emitting governed media events.
/// Must be Sendable to be injected into substrate actors.
public protocol GovernanceLogger: Sendable {
    func log(event: MaterializationEvent) async throws
}
