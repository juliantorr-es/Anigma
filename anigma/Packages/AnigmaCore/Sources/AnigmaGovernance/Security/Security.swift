//
//  Security.swift
//  AnigmaCore
//
//  Security infrastructure module for Anigma.
//  Exports all security-related types and utilities.
//
//  This module provides:
//  - Explainable AI (XAI) for auditable AI decisions
//  - Model Integrity protection against tampering and poisoning
//  - Policy Enforcement with zero-latency enforcement points
//  - Cryptographic Security with key management
//  - Vulnerability Disclosure and CVE tracking
//

import AnigmaFoundation
import AnigmaPrimitives
import GovernanceCore
import Foundation
import GovernanceContracts

// Disambiguate type references
public typealias VulnerabilityManager = VulnerabilityDisclosure.VulnerabilityManager

// MARK: - Re-exports

// All types are defined in their respective files and are public.
// This file serves as documentation for the Security module.

/// The Security module provides critical infrastructure for protecting
/// the Anigma platform against threats and ensuring accountability.
///
/// ## Components
///
/// ### Explainable AI (ExplainableAI.swift)
/// - `AIDecisionExplanation`: Human-readable explanations of AI decisions
/// - `ContributingFactor`: Factors that influenced a decision
/// - `XAIRegistry`: Central registry for AI decision explanations
/// - `LocalExplanationGenerator`: LIME-style local explanation generation
///
/// ### Model Integrity (ModelIntegrity.swift)
/// - `ModelIntegrityManager`: Central manager for model security
/// - `RegisteredModel`: Tracked ML models with integrity metadata
/// - `DriftEvent`: Detected model drift events
/// - `PoisoningAlert`: Data poisoning detection alerts
/// - `InputValidator`: Statistical input validation
///
/// ### Policy Enforcement (PolicyEnforcement.swift)
/// - `PolicyEnforcementEngine`: Central enforcement coordinator
/// - `DetectedThreat`: Threats requiring enforcement
/// - `EnforcementDecision`: Enforcement actions taken
/// - `PolicyEnforcementPoint`: Protocol for enforcement executors
/// - `ThreatFactory`: Helper for creating threats from various sources
///
/// ### Cryptographic Security (CryptographicSecurity.swift)
/// - `KeyManager`: Secure key management with rotation
/// - `KeyMetadata`: Key lifecycle tracking
/// - `EncryptionResult`: Encryption operation results
/// - `SignatureResult`: Signing operation results
/// - `SecureRandom`: Cryptographically secure random generation
/// - `HashUtilities`: Common hash operations
///
/// ### Vulnerability Disclosure (VulnerabilityDisclosure.swift)
/// - `VulnerabilityManager`: CVE and advisory lifecycle management
/// - `VulnerabilityRecord`: Tracked vulnerabilities
/// - `SecurityAdvisory`: Public security advisories
/// - `VulnerabilitySeverity`: CVSS-aligned severity levels
///
/// ## Usage Example
///
/// ```swift
/// // Initialize security infrastructure
/// let auditLog = AuditLog()
/// let keyManager = KeyManager()
/// let xaiRegistry = XAIRegistry()
/// let enforcementEngine = PolicyEnforcementEngine()
/// let modelIntegrity = ModelIntegrityManager()
/// let vulnManager = VulnerabilityManager()
///
/// // Wire up audit logging
/// await keyManager.setAuditLog(auditLog)
/// await xaiRegistry.setAuditLog(auditLog)
/// await enforcementEngine.setAuditLog(auditLog)
/// await modelIntegrity.setAuditLog(auditLog)
/// await vulnManager.setAuditLog(auditLog)
///
/// // Register enforcement points
/// let rateLimiter = InMemoryRateLimiter()
/// await enforcementEngine.registerPEP(rateLimiter)
///
/// // Generate and manage keys
/// let dataKey = await keyManager.generateSymmetricKey(
///     name: "user-data-key",
///     keyType: .dataKey,
///     usage: .encryptDecrypt,
///     createdBy: "system"
/// )
///
/// // Encrypt sensitive data
/// let encrypted = try await keyManager.encrypt(
///     data: sensitiveData,
///     using: dataKey.id
/// )
///
/// // Record AI decisions with explanations
/// let explanation = LocalExplanationGenerator(
///     modelIdentifier: "anomaly-detector-v1",
///     modelVersion: "1.0.0"
/// ).generateExplanation(
///     decisionType: .anomalyDetection,
///     outcome: "ANOMALY_DETECTED",
///     confidence: 0.85,
///     features: features
/// )
/// await xaiRegistry.record(explanation)
///
/// // Enforce security policy
/// let threat = ThreatFactory.fromAnomaly(
///     source: "user-123",
///     anomalyScore: 0.9,
///     description: "Unusual access pattern detected"
/// )
/// let decision = await enforcementEngine.enforce(threat)
/// ```
///
/// ## Integration with Governance
///
/// The Security module integrates with the Governance module:
/// - All security decisions are logged to the AuditLog
/// - Access control decisions flow through AccessController
/// - Kill switch can halt all operations in emergencies
/// - Operating modes affect what security actions are allowed
///
/// ## Thread Safety
///
/// All managers in this module are implemented as Swift actors,
/// providing thread-safe access in concurrent environments.
public enum SecurityModule {
    /// Version of the security module.
    public static let version = "1.0.0"

    /// Initializes the complete security infrastructure.
    public static func initialize(
        auditLog: any AuditLogging
    ) async -> SecurityInfrastructure {
        let keyManager = KeyManager()
        let xaiRegistry = XAIRegistry()
        let enforcementEngine = PolicyEnforcementEngine()
        let modelIntegrity = ModelIntegrityManager()
        let vulnManager = VulnerabilityManager()

        // Wire up audit logging
        await keyManager.setAuditLog(auditLog)
        await xaiRegistry.setAuditLog(auditLog)
        await enforcementEngine.setAuditLog(auditLog)
        await modelIntegrity.setAuditLog(auditLog)
        await vulnManager.setAuditLog(auditLog)

        // Register default enforcement points
        let rateLimiter = InMemoryRateLimiter()
        let sessionTerminator = SessionTerminator()
        await enforcementEngine.registerPEP(rateLimiter)
        await enforcementEngine.registerPEP(sessionTerminator)

        return SecurityInfrastructure(
            keyManager: keyManager,
            xaiRegistry: xaiRegistry,
            enforcementEngine: enforcementEngine,
            modelIntegrity: modelIntegrity,
            vulnerabilityManager: vulnManager,
            rateLimiter: rateLimiter,
            sessionTerminator: sessionTerminator
        )
    }
}

/// Container for all security infrastructure components.
public struct SecurityInfrastructure: Sendable {
    public let keyManager: KeyManager
    public let xaiRegistry: XAIRegistry
    public let enforcementEngine: PolicyEnforcementEngine
    public let modelIntegrity: ModelIntegrityManager
    public let vulnerabilityManager: VulnerabilityManager
    public let rateLimiter: InMemoryRateLimiter
    public let sessionTerminator: SessionTerminator
}

public struct SecurityInfrastructureBridge: AnigmaFoundation.SecurityInfrastructure {
    public let base: SecurityInfrastructure

    public init(base: SecurityInfrastructure) {
        self.base = base
    }

    public var enforcementEngine: any AnigmaFoundation.PolicyEnforcementEngineAPI {
        get async { PolicyEnforcementEngineBridge(base: base.enforcementEngine) }
    }
}

public struct PolicyEnforcementEngineBridge: AnigmaFoundation.PolicyEnforcementEngineAPI {
    public let base: PolicyEnforcementEngine

    public init(base: PolicyEnforcementEngine) {
        self.base = base
    }

    public func enforce(_ threat: AnigmaFoundation.DetectedThreat) async -> AnigmaFoundation.EnforcementDecision {
        let governanceThreat = DetectedThreat(
            id: threat.id,
            threatType: threat.threatType,
            level: Self.convertThreatLevel(threat.level),
            source: threat.source,
            target: threat.target,
            description: threat.description,
            evidence: threat.metadata
        )
        let decision = await base.enforce(governanceThreat)
        return AnigmaFoundation.EnforcementDecision(
            threatId: decision.threatId,
            action: decision.action.rawValue,
            reason: decision.reason,
            enforcedAt: decision.decidedAt
        )
    }

    private static func convertThreatLevel(_ level: AnigmaFoundation.ThreatLevel) -> ThreatLevel {
        switch level {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        case .critical:
            return .critical
        }
    }
}
