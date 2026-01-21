//
//  AuthorityRouting.swift
//  AnigmaClientKit
//
//  [Brief description of file purpose]
//

import ContractsCore
import Foundation

/// Protocol abstraction for the Authority plane.
/// Enables `AnigmaClient` to interact with the Authority without importing `AnigmaHostKit`.
public protocol AuthorityRouting: Sendable {
    /// Validates and ensures an intent is authorized to execute.
    func validateAndRouteIntent(_ intent: ActionIntent) async -> Receipt
}
