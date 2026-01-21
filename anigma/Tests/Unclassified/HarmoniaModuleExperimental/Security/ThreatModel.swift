//
//  ThreatModel.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Concrete threat model for Anigma.
//  Defines adversaries, trust boundaries, and security goals.
//  Not vibes - actual attacker models and defense mappings.
//

import Foundation
import DoctrineCore
import HarmoniaModule

// MARK: - Threat Actors

/// Concrete threat actors for Anigma.
public enum ThreatActor: String, Sendable, Codable {
    // Local attackers (have shell access)
    case localMaliciousUser = "local_malicious_user"          // User with shell access
    case maliciousBrowserExtension = "malicious_browser_ext"  // Browser extension with file access
    case compromisedLocalTool = "compromised_local_tool"      // Local tool that's been compromised

    // Remote attackers (network access)
    case remoteAttacker = "remote_attacker"                   // Network attacker
    case maliciousAPIProvider = "malicious_api_provider"      // Compromised external API
    case supplyChainAttacker = "supply_chain_attacker"        // Compromised dependency

    // Internal threats
    case buggyEngine = "buggy_engine"                         // Engine with bugs
    case misconfiguredGovernance = "misconfigured_governance" // Wrong governance settings
    case doctrineBypass = "doctrine_bypass"                   // Attempt to bypass doctrine

    public var description: String {
        switch self {
        case .localMaliciousUser:
            return "Local user with shell access trying to exfiltrate secrets or corrupt repos"
        case .maliciousBrowserExtension:
            return "Browser extension with file system access trying to inject malicious code"
        case .compromisedLocalTool:
            return "Compromised local tool trying to escalate privileges or exfiltrate data"
        case .remoteAttacker:
            return "Remote attacker trying to exploit network endpoints or APIs"
        case .maliciousAPIProvider:
            return "Compromised external API trying to inject malicious responses"
        case .supplyChainAttacker:
            return "Compromised dependency trying to introduce backdoors"
        case .buggyEngine:
            return "Engine with bugs causing data corruption or security violations"
        case .misconfiguredGovernance:
            return "Incorrect governance settings allowing unsafe operations"
        case .doctrineBypass:
            return "Attempt to bypass doctrine checks through edge cases"
        }
    }

    public var capabilities: [ThreatCapability] {
        switch self {
        case .localMaliciousUser:
            return [.fileSystemAccess, .processExecution, .networkAccess]
        case .maliciousBrowserExtension:
            return [.fileSystemAccess, .networkAccess]
        case .compromisedLocalTool:
            return [.processExecution, .networkAccess, .privilegeEscalation]
        case .remoteAttacker:
            return [.networkAccess, .protocolExploitation]
        case .maliciousAPIProvider:
            return [.dataInjection, .maliciousResponses]
        case .supplyChainAttacker:
            return [.codeInjection, .backdoorInstallation]
        case .buggyEngine:
            return [.dataCorruption, .securityViolation]
        case .misconfiguredGovernance:
            return [.policyViolation, .unsafeOperations]
        case .doctrineBypass:
            return [.ruleEvasion, .edgeCaseExploitation]
        }
    }
}

/// Capabilities of threat actors.
public enum ThreatCapability: String, Sendable, Codable {
    case fileSystemAccess = "file_system_access"
    case processExecution = "process_execution"
    case networkAccess = "network_access"
    case privilegeEscalation = "privilege_escalation"
    case protocolExploitation = "protocol_exploitation"
    case dataInjection = "data_injection"
    case maliciousResponses = "malicious_responses"
    case codeInjection = "code_injection"
    case backdoorInstallation = "backdoor_installation"
    case dataCorruption = "data_corruption"
    case securityViolation = "security_violation"
    case policyViolation = "policy_violation"
    case unsafeOperations = "unsafe_operations"
    case ruleEvasion = "rule_evasion"
    case edgeCaseExploitation = "edge_case_exploitation"
}

// MARK: - Trust Boundaries

/// Trust zones in Anigma architecture.
public enum TrustZone: String, Sendable, Codable, Comparable {
    case untrusted = "untrusted"          // External inputs, inspiration repos
    case sandboxed = "sandboxed"          // Isolated execution environments
    case trustedReadOnly = "trusted_ro"   // Read-only analysis engines
    case trustedMutation = "trusted_mut"  // Mutation engines with filesystem access
    case trustedNetwork = "trusted_net"   // Networked engines with API access
    case system = "system"                // Core system, doctrine, governance

    public static func < (lhs: TrustZone, rhs: TrustZone) -> Bool {
        let order: [TrustZone] = [.untrusted, .sandboxed, .trustedReadOnly, .trustedMutation, .trustedNetwork, .system]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    /// What this zone is allowed to do.
    public var capabilities: [ZoneCapability] {
        switch self {
        case .untrusted:
            return [.readFiles, .parseContent]
        case .sandboxed:
            return [.readFiles, .parseContent, .executeCode, .limitedWrite]
        case .trustedReadOnly:
            return [.readFiles, .parseContent, .analyze, .generateReports]
        case .trustedMutation:
            return [.readFiles, .writeFiles, .gitOperations, .backupRestore]
        case .trustedNetwork:
            return [.networkCalls, .apiAccess, .dataFetch]
        case .system:
            return [.everything]
        }
    }

    /// Required doctrine checks for this zone.
    public var requiredDoctrineChecks: [DoctrineDomain] {
        switch self {
        case .untrusted:
            return [.lawCompliance, .privacy]
        case .sandboxed:
            return [.lawCompliance, .privacy, .computerScience]
        case .trustedReadOnly:
            return [.lawCompliance, .privacy, .computerScience, .statistics]
        case .trustedMutation:
            return [.lawCompliance, .privacy, .computerScience, .statistics]
        case .trustedNetwork:
            return [.lawCompliance, .privacy]
        case .system:
            return DoctrineDomain.allCases
        }
    }
}

/// Capabilities within a trust zone.
public enum ZoneCapability: String, Sendable, Codable {
    case readFiles = "read_files"
    case writeFiles = "write_files"
    case parseContent = "parse_content"
    case executeCode = "execute_code"
    case limitedWrite = "limited_write"
    case analyze = "analyze"
    case generateReports = "generate_reports"
    case gitOperations = "git_operations"
    case backupRestore = "backup_restore"
    case networkCalls = "network_calls"
    case apiAccess = "api_access"
    case dataFetch = "data_fetch"
    case everything = "everything"
}

// MARK: - Security Goals

/// Security goals for Anigma.
public struct SecurityGoals: Sendable, Codable {
    /// Confidentiality: Secrets stay secret.
    public let confidentiality: Bool

    /// Integrity: Code and data cannot be corrupted.
    public let integrity: Bool

    /// Availability: System remains operational.
    public let availability: Bool

    /// Auditability: All actions are logged and traceable.
    public let auditability: Bool

    /// Non-repudiation: Actions cannot be denied.
    public let nonRepudiation: Bool

    /// Least privilege: Engines get minimum required access.
    public let leastPrivilege: Bool

    /// Defense in depth: Multiple layers of protection.
    public let defenseInDepth: Bool

    public init(
        confidentiality: Bool = true,
        integrity: Bool = true,
        availability: Bool = true,
        auditability: Bool = true,
        nonRepudiation: Bool = true,
        leastPrivilege: Bool = true,
        defenseInDepth: Bool = true
    ) {
        self.confidentiality = confidentiality
        self.integrity = integrity
        self.availability = availability
        self.auditability = auditability
        self.nonRepudiation = nonRepudiation
        self.leastPrivilege = leastPrivilege
        self.defenseInDepth = defenseInDepth
    }

    /// Map security goals to doctrine rules.
    public func doctrineRules() -> [String: [String]] {
        var mapping: [String: [String]] = [:]

        if confidentiality {
            mapping["confidentiality"] = [
                "sec-secret-001",  // No secrets in repo
                "sec-data-001",    // Sensitive data encrypted
                "sec-log-001",     // No sensitive data in logs
                "sec-llm-001",     // No raw PII to LLMs
                "law-pii-001",     // PII must be classified
                "law-pii-002"      // No raw PII in logs
            ]
        }

        if integrity {
            mapping["integrity"] = [
                "sec-auth-001",    // Proper authentication
                "sec-ac-001",      // Access control
                "sec-input-001",   // Input validation
                "sec-crypto-001",  // No custom crypto
                "cs-002",          // No shared mutable state
                "cs-003"           // No sync-over-async
            ]
        }

        if auditability {
            mapping["auditability"] = [
                "sec-log-001",     // Proper logging
                "law-pii-002",     // Audit trails for PII
                "sec-local-001"    // Governance approval logging
            ]
        }

        if leastPrivilege {
            mapping["least_privilege"] = [
                "sec-ac-001",      // Access control
                "sec-local-001",   // No unauthorized exfiltration
                "sec-llm-001"      // LLM API restrictions
            ]
        }

        return mapping
    }
}

// MARK: - Threat Model

/// Complete threat model for Anigma.
public struct ThreatModel: Sendable, Codable {
    /// Threat actors we defend against.
    public let actors: [ThreatActor]

    /// Trust zones in the architecture.
    public let zones: [TrustZone]

    /// Security goals.
    public let goals: SecurityGoals

    /// Attack surfaces.
    public let attackSurfaces: [AttackSurface]

    /// Mitigations for each threat.
    public let mitigations: [ThreatActor: [Mitigation]]

    public init(
        actors: [ThreatActor] = ThreatActor.allCases,
        zones: [TrustZone] = TrustZone.allCases,
        goals: SecurityGoals = SecurityGoals(),
        attackSurfaces: [AttackSurface] = AttackSurface.allCases,
        mitigations: [ThreatActor: [Mitigation]] = ThreatModel.defaultMitigations()
    ) {
        self.actors = actors
        self.zones = zones
        self.goals = goals
        self.attackSurfaces = attackSurfaces
        self.mitigations = mitigations
    }

    /// Default mitigations for each threat actor.
    public static func defaultMitigations() -> [ThreatActor: [Mitigation]] {
        var mitigations: [ThreatActor: [Mitigation]] = [:]

        // Local malicious user
        mitigations[.localMaliciousUser] = [
            Mitigation(
                id: "mit-local-001",
                description: "Process isolation for mutation engines",
                implementation: .processIsolation,
                doctrineRules: ["sec-local-001", "sec-secret-001"]
            ),
            Mitigation(
                id: "mit-local-002",
                description: "Secret management with audit trails",
                implementation: .secretManagement,
                doctrineRules: ["sec-secret-001", "sec-log-001"]
            ),
            Mitigation(
                id: "mit-local-003",
                description: "Filesystem sandboxing",
                implementation: .sandboxing,
                doctrineRules: ["sec-local-001"]
            )
        ]

        // Supply chain attacker
        mitigations[.supplyChainAttacker] = [
            Mitigation(
                id: "mit-supply-001",
                description: "Dependency pinning and scanning",
                implementation: .supplyChainPolicy,
                doctrineRules: ["sec-supply-001"]
            ),
            Mitigation(
                id: "mit-supply-002",
                description: "Inspiration repo validation",
                implementation: .inspirationValidation,
                doctrineRules: ["sec-input-001"]
            )
        ]

        // Buggy engine
        mitigations[.buggyEngine] = [
            Mitigation(
                id: "mit-buggy-001",
                description: "Doctrine pre-flight checks",
                implementation: .doctrineChecks,
                doctrineRules: ["cs-001", "cs-002", "cs-003", "sec-input-001"]
            ),
            Mitigation(
                id: "mit-buggy-002",
                description: "Git guard rails and backups",
                implementation: .backupRestore,
                doctrineRules: []
            )
        ]

        // Doctrine bypass
        mitigations[.doctrineBypass] = [
            Mitigation(
                id: "mit-bypass-001",
                description: "Multiple doctrine check layers",
                implementation: .defenseInDepth,
                doctrineRules: []
            ),
            Mitigation(
                id: "mit-bypass-002",
                description: "Security property tests",
                implementation: .securityTests,
                doctrineRules: []
            )
        ]

        return mitigations
    }

    /// Check if a mitigation is implemented.
    public func isMitigationImplemented(_ mitigationId: String) -> Bool {
        // In practice, this would check actual implementation status
        // For now, return true for known mitigations
        let knownMitigations = [
            "mit-local-001", "mit-local-002", "mit-local-003",
            "mit-supply-001", "mit-supply-002",
            "mit-buggy-001", "mit-buggy-002",
            "mit-bypass-001", "mit-bypass-002"
        ]
        return knownMitigations.contains(mitigationId)
    }

    /// Get security posture score based on implemented mitigations.
    public func securityPostureScore() -> Double {
        let allMitigations = mitigations.values.flatMap { $0 }
        let implemented = allMitigations.filter { isMitigationImplemented($0.id) }

        if allMitigations.isEmpty {
            return 100.0
        }

        return Double(implemented.count) / Double(allMitigations.count) * 100.0
    }
}

// MARK: - Attack Surfaces

/// Attack surfaces in Anigma.
public enum AttackSurface: String, Sendable, Codable, CaseIterable {
    case fileSystem = "file_system"
    case network = "network"
    case process = "process"
    case dependencies = "dependencies"
    case configuration = "configuration"
    case doctrine = "doctrine"
    case governance = "governance"

    public var description: String {
        switch self {
        case .fileSystem:
            return "Filesystem access (read/write)"
        case .network:
            return "Network calls and APIs"
        case .process:
            return "Process execution and isolation"
        case .dependencies:
            return "Third-party dependencies"
        case .configuration:
            return "Configuration files and settings"
        case .doctrine:
            return "Doctrine rules and checks"
        case .governance:
            return "Governance policies"
        }
    }
}

// MARK: - Mitigation

/// Security mitigation.
public struct Mitigation: Sendable, Codable {
    public let id: String
    public let description: String
    public let implementation: MitigationImplementation
    public let doctrineRules: [String]

    public enum MitigationImplementation: String, Sendable, Codable {
        case processIsolation = "process_isolation"
        case secretManagement = "secret_management"
        case sandboxing = "sandboxing"
        case supplyChainPolicy = "supply_chain_policy"
        case inspirationValidation = "inspiration_validation"
        case doctrineChecks = "doctrine_checks"
        case backupRestore = "backup_restore"
        case defenseInDepth = "defense_in_depth"
        case securityTests = "security_tests"
    }

    public init(
        id: String,
        description: String,
        implementation: MitigationImplementation,
        doctrineRules: [String] = []
    ) {
        self.id = id
        self.description = description
        self.implementation = implementation
        self.doctrineRules = doctrineRules
    }
}

// MARK: - Trust Boundary Enforcement

/// Enforces trust boundaries between zones.
public actor TrustBoundaryEnforcer {
    private let threatModel: ThreatModel

    public init(threatModel: ThreatModel = ThreatModel()) {
        self.threatModel = threatModel
    }

    /// Check if an engine can perform an operation.
    public func canPerform(
        operation: ZoneCapability,
        from sourceZone: TrustZone,
        to targetZone: TrustZone,
        engineTrustTier: TrustTier
    ) -> Bool {
        // System zone can do anything
        if sourceZone == .system {
            return true
        }

        // Cannot move to higher trust zones
        if targetZone > sourceZone {
            return false
        }

        // Check if source zone has the capability
        guard sourceZone.capabilities.contains(operation) else {
            return false
        }

        // Additional checks based on operation
        switch operation {
        case .writeFiles, .gitOperations:
            // Writing requires at least gold trust tier
            return engineTrustTier >= .gold && sourceZone == .trustedMutation

        case .networkCalls, .apiAccess:
            // Network requires at least silver and trusted network zone
            return engineTrustTier >= .silver && sourceZone == .trustedNetwork

        case .everything:
            // Only system zone has everything
            return sourceZone == .system

        default:
            return true
        }
    }

    /// Get required doctrine checks for a zone transition.
    public func requiredDoctrineChecks(
        from sourceZone: TrustZone,
        to targetZone: TrustZone
    ) -> [DoctrineDomain] {
        var checks = Set<DoctrineDomain>()

        // Always check security (using lawCompliance as closest domain)
        checks.insert(.lawCompliance)

        // Add checks based on zones
        if targetZone == .trustedMutation || sourceZone == .trustedMutation {
            checks.insert(.computerScience)
            checks.insert(.lawCompliance)
        }

        if targetZone == .trustedNetwork || sourceZone == .trustedNetwork {
            checks.insert(.lawCompliance)
        }

        return Array(checks)
    }

    /// Validate an engine's trust assignment.
    public func validateEngineTrust(
        engineId: String,
        assignedZone: TrustZone,
        requestedCapabilities: [ZoneCapability],
        engineTrustTier: TrustTier
    ) -> ValidationResult {
        var violations: [String] = []

        // Check each requested capability
        for capability in requestedCapabilities {
            if !canPerform(
                operation: capability,
                from: assignedZone,
                to: assignedZone,  // Staying in same zone
                engineTrustTier: engineTrustTier
            ) {
                violations.append("Engine \(engineId) cannot perform \(capability.rawValue) from zone \(assignedZone.rawValue)")
            }
        }

        // Check trust tier requirements
        if assignedZone == .trustedMutation && engineTrustTier < .gold {
            violations.append("Mutation engines require at least gold trust tier")
        }

        if assignedZone == .trustedNetwork && engineTrustTier < .silver {
            violations.append("Network engines require at least silver trust tier")
        }

        if violations.isEmpty {
            return .valid(grant: nil)
        } else {
            return .invalid(reason: violations.joined(separator: "; "))
        }
    }
}

// MARK: - Threat Validation Result

public enum ThreatValidationResult: Sendable {
    case valid
    case invalid(violations: [String])

    public var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
}

// MARK: - Default Threat Model

extension ThreatModel {
    /// Default threat model for Anigma.
    public static let `default` = ThreatModel()
}

extension ThreatActor {
    /// All threat actors.
    public static var allCases: [ThreatActor] {
        return [
            .localMaliciousUser,
            .maliciousBrowserExtension,
            .compromisedLocalTool,
            .remoteAttacker,
            .maliciousAPIProvider,
            .supplyChainAttacker,
            .buggyEngine,
            .misconfiguredGovernance,
            .doctrineBypass
        ]
    }
}

extension TrustZone {
    /// All trust zones.
    public static var allCases: [TrustZone] {
        return [
            .untrusted,
            .sandboxed,
            .trustedReadOnly,
            .trustedMutation,
            .trustedNetwork,
            .system
        ]
    }
}
