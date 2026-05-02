//
//  ExecutorProfileModels.swift
//  ContractsCore
//
//  Executor profile contract types.
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import AnigmaPrimitives
import Foundation

/// Summary of an executor profile for listings.
public struct ExecutorProfileSummary: Sendable, Codable {
    public let id: String
    public let version: String
    public let displayName: String
    public let executorKind: String
    public let defaultVariant: String?

    public init(
        id: String,
        version: String,
        displayName: String,
        executorKind: String,
        defaultVariant: String?
    ) {
        self.id = id
        self.version = version
        self.displayName = displayName
        self.executorKind = executorKind
        self.defaultVariant = defaultVariant
    }
}

/// Governance constraints for executor profiles.
public struct ExecutorProfileGovernance: Sendable, Codable {
    public let requiredTrustTier: TrustTier
    public let securityZone: SecurityZone
    public let allowUnattendedExecution: Bool
    public let allowGovernedBuild: Bool

    public init(
        requiredTrustTier: TrustTier,
        securityZone: SecurityZone,
        allowUnattendedExecution: Bool = false,
        allowGovernedBuild: Bool = false
    ) {
        self.requiredTrustTier = requiredTrustTier
        self.securityZone = securityZone
        self.allowUnattendedExecution = allowUnattendedExecution
        self.allowGovernedBuild = allowGovernedBuild
    }
}

/// Default configuration for executor profiles.
public struct ExecutorProfileDefaults: Sendable, Codable {
    public let modelId: String
    public let mlTaskOptions: MLTaskOptions
    public let permissions: [Permission]
    public let granularCapabilities: [GranularCapability]
    public let budgets: ContractBudgets
    public let governance: ExecutorProfileGovernance

    public init(
        modelId: String,
        mlTaskOptions: MLTaskOptions,
        permissions: [Permission],
        granularCapabilities: [GranularCapability],
        budgets: ContractBudgets,
        governance: ExecutorProfileGovernance
    ) {
        self.modelId = modelId
        self.mlTaskOptions = mlTaskOptions
        self.permissions = permissions
        self.granularCapabilities = granularCapabilities
        self.budgets = budgets
        self.governance = governance
    }
}

/// Optional overrides applied to executor profiles.
public struct ExecutorProfileOverrides: Sendable, Codable {
    public let modelId: String?
    public let mlTaskOptions: MLTaskOptions?
    public let permissions: [Permission]?
    public let granularCapabilities: [GranularCapability]?
    public let budgets: ContractBudgets?
    public let governance: ExecutorProfileGovernance?

    public init(
        modelId: String? = nil,
        mlTaskOptions: MLTaskOptions? = nil,
        permissions: [Permission]? = nil,
        granularCapabilities: [GranularCapability]? = nil,
        budgets: ContractBudgets? = nil,
        governance: ExecutorProfileGovernance? = nil
    ) {
        self.modelId = modelId
        self.mlTaskOptions = mlTaskOptions
        self.permissions = permissions
        self.granularCapabilities = granularCapabilities
        self.budgets = budgets
        self.governance = governance
    }
}

/// Variant definition for executor profiles.
public struct ExecutorProfileVariant: Sendable, Codable {
    public let id: String
    public let description: String?
    public let overrides: ExecutorProfileOverrides

    public init(id: String, description: String? = nil, overrides: ExecutorProfileOverrides) {
        self.id = id
        self.description = description
        self.overrides = overrides
    }
}

/// Executor profile definition.
public struct ExecutorProfile: Sendable, Codable {
    public let id: String
    public let version: String
    public let displayName: String
    public let executorKind: String
    public let defaultVariant: String?
    public let defaults: ExecutorProfileDefaults
    public let variants: [ExecutorProfileVariant]

    public init(
        id: String,
        version: String,
        displayName: String,
        executorKind: String,
        defaultVariant: String? = nil,
        defaults: ExecutorProfileDefaults,
        variants: [ExecutorProfileVariant] = []
    ) {
        self.id = id
        self.version = version
        self.displayName = displayName
        self.executorKind = executorKind
        self.defaultVariant = defaultVariant
        self.defaults = defaults
        self.variants = variants
    }
}

/// Resolved executor profile after applying overrides.
public struct ResolvedExecutorProfile: Sendable, Codable {
    public let id: String
    public let version: String
    public let executorKind: String
    public let variantId: String?
    public let modelId: String
    public let mlTaskOptions: MLTaskOptions
    public let permissions: [Permission]
    public let granularCapabilities: [GranularCapability]
    public let budgets: ContractBudgets
    public let governance: ExecutorProfileGovernance

    public init(
        id: String,
        version: String,
        executorKind: String,
        variantId: String?,
        modelId: String,
        mlTaskOptions: MLTaskOptions,
        permissions: [Permission],
        granularCapabilities: [GranularCapability],
        budgets: ContractBudgets,
        governance: ExecutorProfileGovernance
    ) {
        self.id = id
        self.version = version
        self.executorKind = executorKind
        self.variantId = variantId
        self.modelId = modelId
        self.mlTaskOptions = mlTaskOptions
        self.permissions = permissions
        self.granularCapabilities = granularCapabilities
        self.budgets = budgets
        self.governance = governance
    }
}

/// Errors for executor profile operations.
public enum ExecutorProfileError: Error, LocalizedError, Sendable {
    case notFound(id: String)
    case variantNotFound(id: String, variantId: String)
    case accessDenied(reason: String)
    case invalidSchema(code: String, message: String)
    case governanceViolation(code: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Executor profile not found: \(id)"
        case .variantNotFound(let id, let variantId):
            return "Variant \(variantId) not found for profile \(id)"
        case .accessDenied(let reason):
            return "Access denied: \(reason)"
        case .invalidSchema(let code, let message):
            return "Invalid schema (\(code)): \(message)"
        case .governanceViolation(let code, let message):
            return "Governance violation (\(code)): \(message)"
        }
    }
}

extension ExecutorProfile {
    /// Canonical JSON encoding for hashing.
    public func canonicalEncode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

extension ExecutorProfileOverrides {
    /// Canonical JSON encoding for hashing.
    public func canonicalEncode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
