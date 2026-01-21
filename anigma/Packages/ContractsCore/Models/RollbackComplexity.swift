//
//  RollbackComplexity.swift
//  ContractsCore
//
//  Contract definition for RollbackComplexity in ContractsCore.
//

import Foundation

/// Complexity of rolling back a change (shared across ContractsCore).
public enum RollbackComplexity: String, Sendable, Codable {
    case trivial = "trivial"
    case simple = "simple"
    case moderate = "moderate"
    case complex = "complex"
    case impossible = "impossible"
}
