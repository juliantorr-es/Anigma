//
//  EnginePolicy.swift
//  AnigmaCore
//

import AnigmaFoundation
import GovernanceCore
import Foundation
import GovernanceContracts
import AnigmaPrimitives

/// Types of engines that request capabilities.
public enum EngineType: String, Sendable, Codable, CaseIterable {
    /// Swift 6 migration engine
    case migration = "migration"

    /// Inspiration pattern engine
    case inspiration = "inspiration"

    /// Web client for API calls
    case webClient = "web_client"

    /// Doctrine compliance scout
    case doctrineScout = "doctrine_scout"

    /// Secret vault manager
    case secretManager = "secret_manager"

    /// Supply chain scanner
    case supplyChainScanner = "supply_chain_scanner"

    /// Process isolation runner
    case processRunner = "process_runner"

    /// AST transformation engine
    case astTransformer = "ast_transformer"

    public var description: String {
        switch self {
        case .migration: return "Migration Engine"
        case .inspiration: return "Inspiration Engine"
        case .webClient: return "Web Client"
        case .doctrineScout: return "Doctrine Scout"
        case .secretManager: return "Secret Manager"
        case .supplyChainScanner: return "Supply Chain Scanner"
        case .processRunner: return "Process Runner"
        case .astTransformer: return "AST Transformer"
        }
    }
}

/// Policy mapping engine type to required capabilities.
public struct CapabilityPolicy: Sendable, Codable {
    /// Engine type this policy applies to.
    public let engineType: EngineType

    /// Required capabilities for this engine.
    public let requiredCapabilities: [GranularCapability]

    /// Optional capabilities (engine may request but not required).
    public let optionalCapabilities: [GranularCapability]

    /// Zones where this engine can operate.
    public let allowedZones: [SecurityZone]

    /// Minimum trust tier required.
    public let minimumTrustTier: TrustTier

    /// Maximum risk level allowed for this engine.
    public let maximumRiskLevel: RiskLevel

    /// Whether this engine can request additional capabilities at runtime.
    public let allowRuntimeRequests: Bool

    /// Time-to-live for capability grants (seconds).
    public let grantTTL: TimeInterval

    public init(
        engineType: EngineType,
        requiredCapabilities: [GranularCapability],
        optionalCapabilities: [GranularCapability] = [],
        allowedZones: [SecurityZone],
        minimumTrustTier: TrustTier,
        maximumRiskLevel: RiskLevel = .high,
        allowRuntimeRequests: Bool = false,
        grantTTL: TimeInterval = 300 // 5 minutes default
    ) {
        self.engineType = engineType
        self.requiredCapabilities = requiredCapabilities
        self.optionalCapabilities = optionalCapabilities
        self.allowedZones = allowedZones
        self.minimumTrustTier = minimumTrustTier
        self.maximumRiskLevel = maximumRiskLevel
        self.allowRuntimeRequests = allowRuntimeRequests
        self.grantTTL = grantTTL
    }
}

extension CapabilityPolicy {
    /// Default policy for migration engines.
    public static let migration = CapabilityPolicy(
        engineType: .migration,
        requiredCapabilities: [
            .fsReadProject,
            .fsWriteSource,
            .gitRead,
            .executeSwift
        ],
        optionalCapabilities: [
            .fsWriteGenerated,
            .gitWrite,
            .executeProcess
        ],
        allowedZones: [.selfHost, .sandbox],
        minimumTrustTier: .gold,
        maximumRiskLevel: .high,
        allowRuntimeRequests: false,
        grantTTL: 600 // 10 minutes for migrations
    )

    /// Default policy for inspiration engines.
    public static let inspiration = CapabilityPolicy(
        engineType: .inspiration,
        requiredCapabilities: [
            .fsReadProject,
            .netRawGithub,
            .netHttpGet
        ],
        optionalCapabilities: [
            .netGitHubApiRead,
            .llmLocal
        ],
        allowedZones: [.inspiration, .externalServices],
        minimumTrustTier: .silver,
        maximumRiskLevel: .medium,
        allowRuntimeRequests: true,
        grantTTL: 300 // 5 minutes
    )

    /// Default policy for web clients.
    public static let webClient = CapabilityPolicy(
        engineType: .webClient,
        requiredCapabilities: [
            .netHttpGet,
            .netHttpPost
        ],
        optionalCapabilities: [
            .netGitHubApiRead,
            .netOpenAiApi,
            .netHuggingfaceApi
        ],
        allowedZones: [.externalServices],
        minimumTrustTier: .gold,
        maximumRiskLevel: .high,
        allowRuntimeRequests: false,
        grantTTL: 180 // 3 minutes for API calls
    )

    /// Default policy for doctrine scouts.
    public static let doctrineScout = CapabilityPolicy(
        engineType: .doctrineScout,
        requiredCapabilities: [
            .fsReadProject,
            .executeSwift
        ],
        optionalCapabilities: [],
        allowedZones: [.selfHost, .sandbox],
        minimumTrustTier: .silver,
        maximumRiskLevel: .low,
        allowRuntimeRequests: false,
        grantTTL: 300
    )

    /// Default policy for secret managers.
    public static let secretManager = CapabilityPolicy(
        engineType: .secretManager,
        requiredCapabilities: [
            .secretsReadVaultKey,
            .secretsWriteProjectToken,
            .systemKeychain
        ],
        optionalCapabilities: [
            .secretsReadApiKey,
            .secretsRotate
        ],
        allowedZones: [.system],
        minimumTrustTier: .platinum,
        maximumRiskLevel: .critical,
        allowRuntimeRequests: false,
        grantTTL: 60 // 1 minute for secret operations
    )

    /// Get default policy for engine type.
    public static func `default`(for engineType: EngineType) -> CapabilityPolicy {
        switch engineType {
        case .migration: return .migration
        case .inspiration: return .inspiration
        case .webClient: return .webClient
        case .doctrineScout: return .doctrineScout
        case .secretManager: return .secretManager
        case .supplyChainScanner: return CapabilityPolicy(
            engineType: .supplyChainScanner,
            requiredCapabilities: [.fsReadProject, .netHttpGet],
            allowedZones: [.selfHost, .externalServices],
            minimumTrustTier: .silver
        )
        case .processRunner: return CapabilityPolicy(
            engineType: .processRunner,
            requiredCapabilities: [.executeProcess, .fsWriteTemp],
            allowedZones: [.sandbox],
            minimumTrustTier: .gold
        )
        case .astTransformer: return CapabilityPolicy(
            engineType: .astTransformer,
            requiredCapabilities: [.fsReadProject, .fsWriteSource, .executeSwift],
            allowedZones: [.selfHost, .sandbox],
            minimumTrustTier: .gold
        )
        }
    }
}
