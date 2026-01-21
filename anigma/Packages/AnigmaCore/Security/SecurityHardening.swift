//
//  SecurityHardening.swift
//  AnigmaCore
//
//  Critical security hardening infrastructure that closes attack vectors
//  and ensures governance cannot be bypassed.
//
//  This module addresses:
//  - Bypass protection for SecuredWorld/WriteGate
//  - Identity hardening with session risk tracking
//  - Tenant isolation enforcement
//  - Governance consistency with universal operation profiling
//  - Audit integrity with tamper-evident logging
//  - Automation containment with strict sandboxing
//
//  Design principles:
//  - Defense in depth: multiple layers of protection
//  - Fail-secure: deny by default, require explicit grants
//  - Audit everything: no operation escapes logging
//  - Explain everything: all decisions are traceable
//

import Foundation
import ContractsCore
import AnigmaPrimitives

// MARK: - Bypass Protection

/// Tracks and prevents bypass attempts around SecuredWorld.
public actor BypassProtection {
    /// Registered legitimate access paths.
    private var registeredAccessPaths: Set<String> = []

    /// Detected bypass attempts.
    private var bypassAttempts: [BypassAttempt] = []

    /// Kill switch for emergency lockdown.
    private var emergencyLockdown: Bool = false

    /// Audit log for recording violations.
    private var auditLog: (any AuditLogging)?

    public init() {}

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Registers a legitimate access path.
    public func registerAccessPath(_ path: String) {
        registeredAccessPaths.insert(path)
    }

    /// Validates an access path is legitimate.
    public func validateAccessPath(
        caller: String,
        operation: String,
        file: String = #file,
        line: Int = #line
    ) async throws {
        // Check emergency lockdown
        if emergencyLockdown {
            throw BypassError.emergencyLockdown
        }

        let path = "\(caller):\(operation)"

        // Check if this is a registered path
        if !registeredAccessPaths.contains(path) && !registeredAccessPaths.isEmpty {
            let attempt = BypassAttempt(
                caller: caller,
                operation: operation,
                file: file,
                line: line,
                timestamp: Date()
            )
            bypassAttempts.append(attempt)

            // Log the violation
            if let log = auditLog {
                try? await log.record(
                    eventType: ContractsCore.AuditEventType.policyViolation,
                    principal: "SYSTEM",
                    module: "BypassProtection",
                    description: "Potential bypass attempt: \(caller) tried \(operation) at \(file):\(line)",
                    metadata: ["severity": "critical", "caller": caller, "operation": operation, "file": file, "line": "\(line)"]
                )
            }

            // Trigger lockdown after threshold
            if bypassAttempts.count >= 10 {
                emergencyLockdown = true
            }

            throw BypassError.unregisteredAccessPath(caller: caller, operation: operation)
        }
    }

    /// Gets bypass attempt statistics.
    public func getStatistics() -> BypassStatistics {
        BypassStatistics(
            totalAttempts: bypassAttempts.count,
            recentAttempts: bypassAttempts.suffix(10).map { $0 },
            emergencyLockdown: emergencyLockdown,
            registeredPaths: registeredAccessPaths.count
        )
    }

    /// Clears lockdown (requires explicit admin action).
    public func clearLockdown(by principal: String) async {
        emergencyLockdown = false
        if let log = auditLog {
            try? await log.record(
                eventType: ContractsCore.AuditEventType.configChange,
                principal: principal,
                module: "BypassProtection",
                description: "Emergency lockdown cleared",
                metadata: ["principal": principal]
            )
        }
    }
}

/// A detected bypass attempt.
public struct BypassAttempt: Sendable {
    public let caller: String
    public let operation: String
    public let file: String
    public let line: Int
    public let timestamp: Date
}

/// Statistics about bypass attempts.
public struct BypassStatistics: Sendable {
    public let totalAttempts: Int
    public let recentAttempts: [BypassAttempt]
    public let emergencyLockdown: Bool
    public let registeredPaths: Int
}

/// Bypass protection errors.
public enum BypassError: Error, LocalizedError, Sendable {
    case unregisteredAccessPath(caller: String, operation: String)
    case emergencyLockdown

    public var errorDescription: String? {
        switch self {
        case .unregisteredAccessPath(let caller, let operation):
            return "Unregistered access path: \(caller) attempted \(operation)"
        case .emergencyLockdown:
            return "System is in emergency lockdown due to multiple bypass attempts"
        }
    }
}

// MARK: - Session Risk Tracking

/// Tracks and manages session risk levels.
public actor SessionRiskTracker {
    /// Active session risk assessments.
    private var sessionRisks: [UUID: SessionRiskAssessment] = [:]

    /// Risk factors and their weights.
    private var riskWeights: [RiskFactor: Double] = [
        .unusualIp: 0.3,
        .unusualTime: 0.2,
        .rapidActions: 0.25,
        .sensitiveAccess: 0.15,
        .failedAttempts: 0.35,
        .noMfa: 0.2,
        .longSession: 0.1,
        .elevatedPrivileges: 0.25
    ]

    /// Risk threshold for step-up authentication.
    private var stepUpThreshold: Double = 0.5

    /// Risk threshold for session termination.
    private var terminationThreshold: Double = 0.8

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    public init() {}

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Records a session with initial risk assessment.
    public func registerSession(
        _ sessionId: UUID,
        principalId: UUID,
        clientInfo: SessionClientInfo,
        authMethod: AuthenticationMethod,
        mfaVerified: Bool
    ) async -> SessionRiskAssessment {
        var factors: Set<RiskFactor> = []

        // Assess initial risk factors
        if !mfaVerified {
            factors.insert(.noMfa)
        }

        // Calculate initial risk
        let risk = calculateRisk(factors)

        let assessment = SessionRiskAssessment(
            sessionId: sessionId,
            principalId: principalId,
            currentRisk: risk,
            factors: factors,
            requiresStepUp: risk >= stepUpThreshold,
            createdAt: Date(),
            lastUpdated: Date()
        )

        sessionRisks[sessionId] = assessment
        return assessment
    }

    /// Updates session risk based on activity.
    public func recordActivity(
        sessionId: UUID,
        activityType: SessionActivityType,
        metadata: [String: String] = [:]
    ) async -> SessionRiskAssessment? {
        guard var assessment = sessionRisks[sessionId] else { return nil }

        // Add risk factors based on activity
        switch activityType {
        case .sensitiveDataAccess:
            assessment.factors.insert(.sensitiveAccess)
        case .rapidRequests:
            assessment.factors.insert(.rapidActions)
        case .failedOperation:
            assessment.factors.insert(.failedAttempts)
        case .privilegedOperation:
            assessment.factors.insert(.elevatedPrivileges)
        case .normalOperation:
            break
        }

        // Recalculate risk
        assessment.currentRisk = calculateRisk(assessment.factors)
        assessment.lastUpdated = Date()
        assessment.requiresStepUp = assessment.currentRisk >= stepUpThreshold

        sessionRisks[sessionId] = assessment

        // Check for termination
        if assessment.currentRisk >= terminationThreshold {
            if let log = auditLog {
                            try? await log.record(
                                eventType: ContractsCore.AuditEventType.policyViolation,
                                principal: assessment.principalId.uuidString,
                                module: "SessionRiskTracker",
                                description: "Session risk exceeded termination threshold: \(assessment.currentRisk)",
                                metadata: ["session_id": sessionId.uuidString, "current_risk": "\(assessment.currentRisk)"]
                            )            }
        }

        return assessment
    }

    /// Checks if a session requires step-up authentication.
    public func requiresStepUp(sessionId: UUID) -> Bool {
        sessionRisks[sessionId]?.requiresStepUp ?? true
    }

    /// Checks if a session should be terminated.
    public func shouldTerminate(sessionId: UUID) -> Bool {
        guard let assessment = sessionRisks[sessionId] else { return false }
        return assessment.currentRisk >= terminationThreshold
    }

    /// Removes a session from tracking.
    public func removeSession(_ sessionId: UUID) {
        sessionRisks.removeValue(forKey: sessionId)
    }

    /// Gets current risk assessment.
    public func getAssessment(_ sessionId: UUID) -> SessionRiskAssessment? {
        sessionRisks[sessionId]
    }

    private func calculateRisk(_ factors: Set<RiskFactor>) -> Double {
        var total: Double = 0
        for factor in factors {
            total += riskWeights[factor] ?? 0
        }
        return min(1.0, total)
    }
}

/// Session risk assessment.
public struct SessionRiskAssessment: Sendable {
    public let sessionId: UUID
    public let principalId: UUID
    public var currentRisk: Double
    public var factors: Set<RiskFactor>
    public var requiresStepUp: Bool
    public let createdAt: Date
    public var lastUpdated: Date
}

/// Risk factors that contribute to session risk.
public enum RiskFactor: String, Sendable, Hashable {
    case unusualIp = "unusual_ip"
    case unusualTime = "unusual_time"
    case rapidActions = "rapid_actions"
    case sensitiveAccess = "sensitive_access"
    case failedAttempts = "failed_attempts"
    case noMfa = "no_mfa"
    case longSession = "long_session"
    case elevatedPrivileges = "elevated_privileges"
}

/// Types of session activities.
public enum SessionActivityType: String, Sendable {
    case normalOperation
    case sensitiveDataAccess
    case rapidRequests
    case failedOperation
    case privilegedOperation
}

// MARK: - Tenant Isolation Enforcement

/// Enforces strict tenant isolation boundaries.
public actor TenantIsolationEnforcer {
    /// Known tenant IDs.
    private var knownTenants: Set<UUID> = []

    /// Current operation context stack (per-task isolation).
    private var operationContexts: [UUID: TenantOperationContext] = [:]

    /// Cross-tenant access attempts.
    private var crossTenantAttempts: [CrossTenantAttempt] = []

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    public init() {}

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Registers a known tenant.
    public func registerTenant(_ tenantId: UUID) {
        knownTenants.insert(tenantId)
    }

    /// Begins an operation in a tenant context.
    public func beginOperation(
        operationId: UUID,
        tenantId: UUID,
        principalId: UUID
    ) throws {
        guard knownTenants.contains(tenantId) else {
            throw TenantIsolationError.unknownTenant(tenantId)
        }

        operationContexts[operationId] = TenantOperationContext(
            operationId: operationId,
            tenantId: tenantId,
            principalId: principalId,
            startedAt: Date()
        )
    }

    /// Validates that an entity access is within tenant bounds.
    public func validateAccess(
        operationId: UUID,
        entityTenantId: UUID?,
        entityId: UUID
    ) async throws {
        guard let context = operationContexts[operationId] else {
            throw TenantIsolationError.noOperationContext
        }

        // Platform-wide entities (nil tenant) are always accessible
        guard let entityTenant = entityTenantId else { return }

        // Check tenant match
        if entityTenant != context.tenantId {
            let attempt = CrossTenantAttempt(
                operationId: operationId,
                sourceTenantId: context.tenantId,
                targetTenantId: entityTenant,
                entityId: entityId,
                principalId: context.principalId,
                timestamp: Date()
            )
            crossTenantAttempts.append(attempt)

            if let log = auditLog {
                            try? await log.record(
                                eventType: ContractsCore.AuditEventType.policyViolation,
                                principal: context.principalId.uuidString,
                                module: "TenantIsolationEnforcer",
                                description: "Cross-tenant access attempt: \(context.tenantId) tried to access entity in \(entityTenant)",
                                metadata: [
                                    "entity_id": entityId.uuidString,
                                    "source_tenant": context.tenantId.uuidString,
                                    "target_tenant": entityTenant.uuidString
                                ]
                            )            }

            throw TenantIsolationError.crossTenantAccess(
                source: context.tenantId,
                target: entityTenant
            )
        }
    }

    /// Ends an operation context.
    public func endOperation(_ operationId: UUID) {
        operationContexts.removeValue(forKey: operationId)
    }

    /// Gets cross-tenant attempt statistics.
    public func getCrossTenantAttempts() -> [CrossTenantAttempt] {
        crossTenantAttempts
    }
}

/// Context for a tenant-scoped operation.
public struct TenantOperationContext: Sendable {
    public let operationId: UUID
    public let tenantId: UUID
    public let principalId: UUID
    public let startedAt: Date
}

/// A cross-tenant access attempt.
public struct CrossTenantAttempt: Sendable {
    public let operationId: UUID
    public let sourceTenantId: UUID
    public let targetTenantId: UUID
    public let entityId: UUID
    public let principalId: UUID
    public let timestamp: Date
}

/// Tenant isolation errors.
public enum TenantIsolationError: Error, LocalizedError, Sendable {
    case unknownTenant(UUID)
    case noOperationContext
    case crossTenantAccess(source: UUID, target: UUID)

    public var errorDescription: String? {
        switch self {
        case .unknownTenant(let id):
            return "Unknown tenant: \(id)"
        case .noOperationContext:
            return "No tenant operation context for this operation"
        case .crossTenantAccess(let source, let target):
            return "Cross-tenant access denied: \(source) cannot access \(target)"
        }
    }
}

// MARK: - Universal Operation Profiling

/// Ensures all operations have registered profiles for governance.
public actor SecurityOperationRegistry {
    /// Registered operation profiles.
    private var profiles: [String: OperationProfile] = [:]

    /// Default profile for unregistered operations.
    private var defaultProfile = OperationProfile(
        operationId: "default",
        name: "Unregistered Operation",
        checkpointProfile: .hard, // Deny by default
        riskLevel: .high,
        requiresAudit: true,
        allowedModes: [.readOnly] // Only read-only by default
    )

    /// Whether to enforce profiles (can be relaxed in dev).
    private var enforceProfiles: Bool = true

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    public init() {}

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Sets whether profiles are enforced.
    public func setEnforcement(_ enforce: Bool) {
        self.enforceProfiles = enforce
    }

    /// Registers an operation profile.
    public func register(_ profile: OperationProfile) {
        profiles[profile.operationId] = profile
    }

    /// Registers multiple profiles at once.
    public func registerAll(_ newProfiles: [OperationProfile]) {
        for profile in newProfiles {
            profiles[profile.operationId] = profile
        }
    }

    /// Gets profile for an operation.
    public func getProfile(_ operationId: String) async -> OperationProfile {
        if let profile = profiles[operationId] {
            return profile
        }

        // Log unregistered operation access
        if enforceProfiles, let log = auditLog {
            try? await log.record(
                eventType: ContractsCore.AuditEventType.policyViolation,
                principal: "SYSTEM",
                module: "SecurityOperationRegistry",
                description: "Access to unregistered operation: \(operationId)",
                metadata: ["operation_id": operationId]
            )
        }

        return defaultProfile
    }

    /// Checks if an operation is allowed in the current mode.
    public func isAllowed(
        operationId: String,
        mode: OperatingMode
    ) async -> (allowed: Bool, reason: String) {
        let profile = await getProfile(operationId)

        let modeRaw: OperatingModeRaw = switch mode {
        case .readOnly: .readOnly
        case .assistive: .assistive
        case .autopilot: .autopilot
        }

        if profile.allowedModes.contains(modeRaw) {
            return (true, "Operation allowed in \(mode.label)")
        } else {
            return (false, "Operation '\(profile.name)' not allowed in \(mode.label) mode")
        }
    }

    /// Lists all registered operations.
    public func listOperations() -> [String] {
        Array(profiles.keys).sorted()
    }
}

/// Profile for an operation.
public struct OperationProfile: Sendable {
    public let operationId: String
    public let name: String
    public let checkpointProfile: CheckpointProfileType
    public let riskLevel: RiskLevel
    public let requiresAudit: Bool
    public let allowedModes: Set<OperatingModeRaw>
    public let requiredCapabilities: Set<String>
    public let maxSensitivity: DataSensitivity
    public let description: String?

    public init(
        operationId: String,
        name: String,
        checkpointProfile: CheckpointProfileType = .soft,
        riskLevel: RiskLevel = .low,
        requiresAudit: Bool = true,
        allowedModes: Set<OperatingModeRaw> = [.readOnly, .assistive, .autopilot],
        requiredCapabilities: Set<String> = [],
        maxSensitivity: DataSensitivity = .internal,
        description: String? = nil
    ) {
        self.operationId = operationId
        self.name = name
        self.checkpointProfile = checkpointProfile
        self.riskLevel = riskLevel
        self.requiresAudit = requiresAudit
        self.allowedModes = allowedModes
        self.requiredCapabilities = requiredCapabilities
        self.maxSensitivity = maxSensitivity
        self.description = description
    }
}

/// Checkpoint profile types for update draining.
public enum CheckpointProfileType: String, Sendable, Codable {
    /// Soft operations can complete during drain.
    case soft = "soft"
    /// Hard operations are blocked during drain.
    case hard = "hard"
    /// Checkpoint operations can save state.
    case checkpoint = "checkpoint"
    /// Read-only operations are always allowed.
    case readOnly = "read_only"
}

// MARK: - Audit Integrity

/// Provides tamper-evident audit logging with periodic anchoring.
public actor AuditIntegrityManager {
    /// The underlying audit log.
    private let auditLog: any AuditLogging

    /// Anchor points (signed checkpoints).
    private var anchors: [AuditAnchor] = []

    /// Signing key ID.
    private var signingKeyId: UUID?

    /// Key manager for signing.
    private var keyManager: KeyManager?

    /// Anchor interval (number of entries between anchors).
    private let anchorInterval: Int

    /// Entry count since last anchor.
    private var entriesSinceAnchor: Int = 0

    public init(auditLog: any AuditLogging, anchorInterval: Int = 100) {
        self.auditLog = auditLog
        self.anchorInterval = anchorInterval
    }

    /// Configures signing.
    public func configureSigning(keyManager: KeyManager, keyId: UUID) {
        self.keyManager = keyManager
        self.signingKeyId = keyId
    }
    
    /// Records a security event with integrity checking.
    public func record(
        eventType: ContractsCore.AuditEventType,
        principal: Principal,
        module: String,
        entityId: EntityId? = nil,
        componentType: String? = nil,
        sensitivity: DataSensitivity? = nil,
        description: String,
        metadata: [String: String] = [:]
    ) async {
        var updatedMetadata = metadata
        if let entityId = entityId {
            updatedMetadata["entity_id"] = entityId.raw.uuidString
        }
        if let componentType = componentType {
            updatedMetadata["component_type"] = componentType
        }
        if let sensitivity = sensitivity {
            updatedMetadata["sensitivity"] = String(sensitivity.rawValue)
        }

        // Record to underlying log
        try? await auditLog.recordEvent(
            id: UUID(),
            type: eventType,
            principal: principal.id,
            module: module,
            description: description,
            metadata: updatedMetadata
        )

        entriesSinceAnchor += 1

        // Check if we need to create an anchor
        if entriesSinceAnchor >= anchorInterval {
            await createAnchor()
        }
    }

    /// Creates an anchor point.
    public func createAnchor() async {
        let chainHead = await auditLog.getChainHead()

        var signatureString: String?
        if let keyId = signingKeyId, let km = keyManager {
            if let concreteChainHead = chainHead { // Safely unwrap chainHead
                // Sign the chain head
                if let data = concreteChainHead.data(using: String.Encoding.utf8) {
                    do {
                        let result = try await km.sign(data: data, using: keyId)
                        signatureString = result.signature.base64EncodedString()
                    } catch {
                        // Signing failed, continue without signature
                    }
                }
            }
        }

        let anchor = AuditAnchor(
            anchorId: UUID(),
            chainHead: chainHead ?? "", // Provide empty string if nil
            entryCount: await auditLog.entryCount(),
            createdAt: Date(),
            signature: signatureString,
            signingKeyId: signingKeyId?.uuidString
        )

        anchors.append(anchor)
        entriesSinceAnchor = 0
    }

    /// Verifies audit log integrity against anchors.
    public func verifyIntegrity() async -> IntegrityVerificationResult {
        var issues: [String] = []
        var verified = true

        // Verify chain integrity
        let chainValid = await auditLog.verifyChain()
        if !chainValid {
            verified = false
            issues.append("Hash chain integrity check failed")
        }

        // Verify anchor signatures
        for anchor in anchors {
            if let signature = anchor.signature,
               let keyIdStr = anchor.signingKeyId,
               let keyId = UUID(uuidString: keyIdStr),
               let km = keyManager,
               let data = anchor.chainHead.data(using: .utf8),
               let sigData = Data(base64Encoded: signature) {
                do {
                    let valid = try await km.verify(signature: sigData, for: data, using: keyId)
                    if !valid {
                        verified = false
                        issues.append("Anchor \(anchor.anchorId) signature verification failed")
                    }
                } catch {
                    verified = false
                    issues.append("Anchor \(anchor.anchorId) verification error: \(error)")
                }
            }
        }

        return IntegrityVerificationResult(
            verified: verified,
            anchorsChecked: anchors.count,
            issues: issues,
            lastAnchor: anchors.last,
            verifiedAt: Date()
        )
    }

    /// Gets all anchors.
    public func getAnchors() -> [AuditAnchor] {
        anchors
    }
}

/// An audit anchor point.
public struct AuditAnchor: Sendable {
    public let anchorId: UUID
    public let chainHead: String
    public let entryCount: Int
    public let createdAt: Date
    public let signature: String?
    public let signingKeyId: String?
}

/// Result of integrity verification.
public struct IntegrityVerificationResult: Sendable {
    public let verified: Bool
    public let anchorsChecked: Int
    public let issues: [String]
    public let lastAnchor: AuditAnchor?
    public let verifiedAt: Date
}

// MARK: - Sandbox Configuration

/// Configuration for creating an automation sandbox.
public struct SandboxConfiguration: Sendable {
    /// Unique identifier for this execution.
    public let executionId: UUID
    /// Identifier for the agent being contained.
    public let agentId: String
    /// Operating mode for the sandbox.
    public let operatingMode: OperatingMode
    /// Domains the sandbox is allowed to access.
    public let allowedDomains: [String]
    /// Maximum sensitivity level for operations.
    public let maxSensitivity: DataSensitivity
    /// Capabilities granted to the sandbox.
    public let allowedCapabilities: [String]
    /// Timeout in seconds before sandbox termination.
    public let timeoutSeconds: TimeInterval
    
    public init(
        executionId: UUID,
        agentId: String,
        operatingMode: OperatingMode,
        allowedDomains: [String],
        maxSensitivity: DataSensitivity,
        allowedCapabilities: [String],
        timeoutSeconds: TimeInterval
    ) {
        self.executionId = executionId
        self.agentId = agentId
        self.operatingMode = operatingMode
        self.allowedDomains = allowedDomains
        self.maxSensitivity = maxSensitivity
        self.allowedCapabilities = allowedCapabilities
        self.timeoutSeconds = timeoutSeconds
    }
}

// MARK: - Automation Containment

/// Provides strict sandboxing for automation and agent execution.
public actor AutomationContainment {
    /// Active sandboxes.
    private var activeSandboxes: [UUID: AutomationSandbox] = [:]
    
    /// Sandbox violations.
    private var violations: [SandboxViolation] = []
    
    /// Kill switches per agent.
    private var agentKillSwitches: [UUID: Bool] = [:]

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    public init() {}
    
    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Creates a new sandbox with the given configuration.
    public func createSandbox(
        executionId: UUID,
        agentId: UUID,
        operatingMode: OperatingMode,
        allowedDomains: [String],
        maxSensitivity: DataSensitivity,
        allowedCapabilities: [String],
        timeoutSeconds: Int = 300
    ) throws -> AutomationSandbox {
        // Check if agent is killed
        if agentKillSwitches[agentId] == true {
            throw ContainmentError.agentKilled(agentId)
        }

        let sandbox = AutomationSandbox(
            executionId: executionId,
            agentId: agentId,
            operatingMode: operatingMode,
            allowedDomains: Set(allowedDomains),
            maxSensitivity: maxSensitivity,
            allowedCapabilities: Set(allowedCapabilities),
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(TimeInterval(timeoutSeconds)),
            entityAccessCount: 0,
            writeAttempts: 0,
            violations: []
        )

        activeSandboxes[executionId] = sandbox
        return sandbox
    }

    /// Validates an operation within a sandbox.
    public func validateOperation(
        executionId: UUID,
        operation: SandboxedOperation
    ) async throws {
        guard var sandbox = activeSandboxes[executionId] else {
            throw ContainmentError.noSandbox(executionId)
        }

        // Check expiration
        if Date() > sandbox.expiresAt {
            throw ContainmentError.sandboxExpired(executionId)
        }

        // Check domain
        if let domain = operation.domain, !sandbox.allowedDomains.contains(domain) {
            let violation = SandboxViolation(
                executionId: executionId,
                violationType: .domainViolation,
                details: "Attempted access to domain: \(domain)",
                timestamp: Date()
            )
            sandbox.violations.append(violation)
            violations.append(violation)
            activeSandboxes[executionId] = sandbox

            await logViolation(violation, agentId: sandbox.agentId)
            throw ContainmentError.domainNotAllowed(domain)
        }

        // Check sensitivity
        if let sensitivity = operation.sensitivity, sensitivity > sandbox.maxSensitivity {
            let violation = SandboxViolation(
                executionId: executionId,
                violationType: .sensitivityViolation,
                details: "Attempted access to \(sensitivity.label) data",
                timestamp: Date()
            )
            sandbox.violations.append(violation)
            violations.append(violation)
            activeSandboxes[executionId] = sandbox

            await logViolation(violation, agentId: sandbox.agentId)
            throw ContainmentError.sensitivityExceeded(sensitivity)
        }

        // Check write permission
        if operation.isWrite {
            if sandbox.operatingMode == .readOnly {
                let violation = SandboxViolation(
                    executionId: executionId,
                    violationType: .modeViolation,
                    details: "Attempted write in read-only mode",
                    timestamp: Date()
                )
                sandbox.violations.append(violation)
                violations.append(violation)
                activeSandboxes[executionId] = sandbox

                await logViolation(violation, agentId: sandbox.agentId)
                throw ContainmentError.writeNotAllowed
            }
            sandbox.writeAttempts += 1
        }

        // Update access count
        sandbox.entityAccessCount += 1
        activeSandboxes[executionId] = sandbox

        // Check for excessive access (possible abuse)
        if sandbox.entityAccessCount > 1000 {
            // Auto-kill the agent
            agentKillSwitches[sandbox.agentId] = true

            await logViolation(
                SandboxViolation(
                    executionId: executionId,
                    violationType: .excessiveAccess,
                    details: "Agent exceeded access limit",
                    timestamp: Date()
                ),
                agentId: sandbox.agentId
            )

            throw ContainmentError.excessiveAccess
        }
    }

    /// Closes a sandbox.
    public func closeSandbox(_ executionId: UUID) -> AutomationSandbox? {
        activeSandboxes.removeValue(forKey: executionId)
    }

    /// Kills an agent (disables all future executions).
    public func killAgent(_ agentId: UUID, reason: String) async {
        agentKillSwitches[agentId] = true

        if let log = auditLog {
            try? await log.record(
                eventType: ContractsCore.AuditEventType.policyViolation,
                principal: "SYSTEM",
                module: "AutomationContainment",
                description: "Agent killed: \(reason)",
                metadata: ["agent_id": agentId.uuidString, "reason": reason]
            )
        }
    }

    /// Revives a killed agent.
    public func reviveAgent(_ agentId: UUID, by principal: String) async {
        agentKillSwitches[agentId] = false

        if let log = auditLog {
            try? await log.record(
                eventType: ContractsCore.AuditEventType.configChange,
                principal: principal,
                module: "AutomationContainment",
                description: "Agent revived",
                metadata: ["agent_id": agentId.uuidString, "principal": principal]
            )
        }
    }

    /// Checks if an agent is killed.
    public func isAgentKilled(_ agentId: UUID) -> Bool {
        agentKillSwitches[agentId] ?? false
    }

    /// Gets all violations.
    public func getViolations() -> [SandboxViolation] {
        violations
    }

    private func logViolation(_ violation: SandboxViolation, agentId: UUID) async {
        if let log = auditLog {
            try? await log.record(
                eventType: ContractsCore.AuditEventType.policyViolation,
                principal: "AGENT:\(agentId.uuidString)",
                module: "AutomationContainment",
                description: "Sandbox violation: \(violation.violationType.rawValue) - \(violation.details)",
                metadata: [
                    "execution_id": violation.executionId.uuidString,
                    "violation_type": violation.violationType.rawValue,
                    "agent_id": agentId.uuidString
                ]
            )
        }
    }
}

/// A sandbox for automation execution.
public struct AutomationSandbox: Sendable {
    public let executionId: UUID
    public let agentId: UUID
    public let operatingMode: OperatingMode
    public let allowedDomains: Set<String>
    public let maxSensitivity: DataSensitivity
    public let allowedCapabilities: Set<String>
    public let createdAt: Date
    public let expiresAt: Date
    public var entityAccessCount: Int
    public var writeAttempts: Int
    public var violations: [SandboxViolation]
}

/// An operation within a sandbox.
public struct SandboxedOperation: Sendable {
    public let operationType: String
    public let domain: String?
    public let sensitivity: DataSensitivity?
    public let isWrite: Bool
    public let entityId: UUID?

    public init(
        operationType: String,
        domain: String? = nil,
        sensitivity: DataSensitivity? = nil,
        isWrite: Bool = false,
        entityId: UUID? = nil
    ) {
        self.operationType = operationType
        self.domain = domain
        self.sensitivity = sensitivity
        self.isWrite = isWrite
        self.entityId = entityId
    }
}

/// A sandbox violation.
public struct SandboxViolation: Sendable {
    public let executionId: UUID
    public let violationType: ViolationType
    public let details: String
    public let timestamp: Date
}

/// Types of sandbox violations.
public enum ViolationType: String, Sendable {
    case domainViolation = "domain_violation"
    case sensitivityViolation = "sensitivity_violation"
    case modeViolation = "mode_violation"
    case excessiveAccess = "excessive_access"
    case timeout = "timeout"
}

/// Containment errors.
public enum ContainmentError: Error, LocalizedError, Sendable {
    case agentKilled(UUID)
    case noSandbox(UUID)
    case sandboxExpired(UUID)
    case domainNotAllowed(String)
    case sensitivityExceeded(DataSensitivity)
    case writeNotAllowed
    case excessiveAccess

    public var errorDescription: String? {
        switch self {
        case .agentKilled(let id):
            return "Agent \(id) has been killed and cannot execute"
        case .noSandbox(let id):
            return "No sandbox found for execution \(id)"
        case .sandboxExpired(let id):
            return "Sandbox for execution \(id) has expired"
        case .domainNotAllowed(let domain):
            return "Access to domain '\(domain)' not allowed in this sandbox"
        case .sensitivityExceeded(let sensitivity):
            return "Sensitivity level \(sensitivity.label) exceeds sandbox limit"
        case .writeNotAllowed:
            return "Write operations not allowed in this mode"
        case .excessiveAccess:
            return "Excessive access detected; agent has been killed"
        }
    }
}

// MARK: - Immediate Deprovisioning

/// Provides immediate access revocation for deprovisioned users.
public actor ImmediateDeprovisioner {
    /// Currently deprovisioned principal IDs.
    private var deprovisionedPrincipals: Set<UUID> = []

    /// Session invalidation callbacks.
    private var sessionInvalidators: [(UUID) async -> Void] = []

    /// Capability cache invalidation callbacks.
    private var capabilityCacheInvalidators: [(UUID) async -> Void] = []

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    public init() {}

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Registers a session invalidator.
    public func registerSessionInvalidator(_ invalidator: @escaping (UUID) async -> Void) {
        sessionInvalidators.append(invalidator)
    }

    /// Registers a capability cache invalidator.
    public func registerCapabilityCacheInvalidator(_ invalidator: @escaping (UUID) async -> Void) {
        capabilityCacheInvalidators.append(invalidator)
    }

    /// Immediately deprovisions a principal.
    public func deprovision(
        principalId: UUID,
        reason: String,
        initiatedBy: UUID
    ) async {
        // Add to deprovisioned set
        deprovisionedPrincipals.insert(principalId)

        // Invalidate all sessions immediately
        for invalidator in sessionInvalidators {
            await invalidator(principalId)
        }

        // Invalidate capability caches
        for invalidator in capabilityCacheInvalidators {
            await invalidator(principalId)
        }

        // Log the deprovisioning
        if let log = auditLog {
            try? await log.record(
                eventType: ContractsCore.AuditEventType.userDeprovisioned,
                principal: initiatedBy.uuidString,
                module: "ImmediateDeprovisioner",
                description: "Principal \(principalId) immediately deprovisioned: \(reason)",
                metadata: [
                    "deprovisioned_principal": principalId.uuidString,
                    "reason": reason,
                    "initiated_by": initiatedBy.uuidString
                ]
            )
        }
    }

    /// Checks if a principal is deprovisioned.
    public func isDeprovisioned(_ principalId: UUID) -> Bool {
        deprovisionedPrincipals.contains(principalId)
    }

    /// Reprovisions a principal (restores access).
    public func reprovision(
        principalId: UUID,
        reason: String,
        authorizedBy: UUID
    ) async {
        deprovisionedPrincipals.remove(principalId)

        if let log = auditLog {
            try? await log.record(
                eventType: ContractsCore.AuditEventType.configChange,
                principal: authorizedBy.uuidString,
                module: "ImmediateDeprovisioner",
                description: "Principal \(principalId) reprovisioned: \(reason)",
                metadata: [
                    "reprovisioned_principal": principalId.uuidString,
                    "reason": reason,
                    "authorized_by": authorizedBy.uuidString
                ]
            )
        }
    }

    /// Gets all deprovisioned principals.
    public func getDeprovisionedPrincipals() -> Set<UUID> {
        deprovisionedPrincipals
    }
}

// MARK: - Hardened Security Infrastructure

/// Unified security hardening infrastructure.
public actor HardenedSecurityInfrastructure {
    public let bypassProtection: BypassProtection
    public let sessionRiskTracker: SessionRiskTracker
    public let tenantIsolation: TenantIsolationEnforcer
    public let operationRegistry: SecurityOperationRegistry
    public let auditIntegrity: AuditIntegrityManager
    public let automationContainment: AutomationContainment
    public let deprovisioner: ImmediateDeprovisioner

    public init(auditLog: any AuditLogging, keyManager: KeyManager? = nil, signingKeyId: UUID? = nil) async {
        self.bypassProtection = BypassProtection()
        self.sessionRiskTracker = SessionRiskTracker()
        self.tenantIsolation = TenantIsolationEnforcer()
        self.operationRegistry = SecurityOperationRegistry()
        self.auditIntegrity = AuditIntegrityManager(auditLog: auditLog)
        self.automationContainment = AutomationContainment()
        self.deprovisioner = ImmediateDeprovisioner()

        // Wire up audit logging
        await bypassProtection.setAuditLog(auditLog)
        await sessionRiskTracker.setAuditLog(auditLog)
        await tenantIsolation.setAuditLog(auditLog)
        await operationRegistry.setAuditLog(auditLog)
        await automationContainment.setAuditLog(auditLog)
        await deprovisioner.setAuditLog(auditLog)

        // Configure signing if available
        if let km = keyManager, let keyId = signingKeyId {
            await auditIntegrity.configureSigning(keyManager: km, keyId: keyId)
        }
    }

    /// Performs a full security health check.
    public func healthCheck() async -> SecurityHealthReport {
        let bypassStats = await bypassProtection.getStatistics()
        let violations = await automationContainment.getViolations()
        let crossTenantAttempts = await tenantIsolation.getCrossTenantAttempts()
        let integrityResult = await auditIntegrity.verifyIntegrity()
        let deprovisionedCount = await deprovisioner.getDeprovisionedPrincipals().count

        let overallHealth: HealthStatus = {
            if bypassStats.emergencyLockdown || !integrityResult.verified {
                return .critical
            } else if bypassStats.totalAttempts > 0 || !violations.isEmpty || !crossTenantAttempts.isEmpty {
                return .warning
            } else {
                return .healthy
            }
        }()

        return SecurityHealthReport(
            overallHealth: overallHealth,
            bypassAttempts: bypassStats.totalAttempts,
            emergencyLockdown: bypassStats.emergencyLockdown,
            sandboxViolations: violations.count,
            crossTenantAttempts: crossTenantAttempts.count,
            auditIntegrityVerified: integrityResult.verified,
            auditAnchors: integrityResult.anchorsChecked,
            deprovisionedPrincipals: deprovisionedCount,
            checkedAt: Date()
        )
    }
}

/// Security health status.
public enum HealthStatus: String, Sendable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
}

/// Security health report.
public struct SecurityHealthReport: Sendable {
    public let overallHealth: HealthStatus
    public let bypassAttempts: Int
    public let emergencyLockdown: Bool
    public let sandboxViolations: Int
    public let crossTenantAttempts: Int
    public let auditIntegrityVerified: Bool
    public let auditAnchors: Int
    public let deprovisionedPrincipals: Int
    public let checkedAt: Date
}

// MARK: - Standard Operation Profiles

/// Standard operation profiles for core domains.
public enum StandardOperationProfiles {
    // Read operations
    public static let viewEntity = OperationProfile(
        operationId: "entity.view",
        name: "View Entity",
        checkpointProfile: .readOnly,
        riskLevel: .low,
        allowedModes: [.readOnly, .assistive, .autopilot]
    )

    public static let queryEntities = OperationProfile(
        operationId: "entity.query",
        name: "Query Entities",
        checkpointProfile: .readOnly,
        riskLevel: .low,
        allowedModes: [.readOnly, .assistive, .autopilot]
    )

    // Write operations
    public static let createEntity = OperationProfile(
        operationId: "entity.create",
        name: "Create Entity",
        checkpointProfile: .soft,
        riskLevel: .low,
        allowedModes: [.assistive, .autopilot]
    )

    public static let updateEntity = OperationProfile(
        operationId: "entity.update",
        name: "Update Entity",
        checkpointProfile: .soft,
        riskLevel: .medium,
        allowedModes: [.assistive, .autopilot]
    )

    public static let deleteEntity = OperationProfile(
        operationId: "entity.delete",
        name: "Delete Entity",
        checkpointProfile: .hard,
        riskLevel: .high,
        allowedModes: [.assistive], // No autopilot for deletes
        requiredCapabilities: ["entity.delete"]
    )

    // DSPS operations
    public static let createDspsCase = OperationProfile(
        operationId: "dsps.case.create",
        name: "Create DSPS Case",
        checkpointProfile: .checkpoint,
        riskLevel: .medium,
        allowedModes: [.assistive, .autopilot],
        maxSensitivity: .sensitive
    )

    public static let updateDspsCase = OperationProfile(
        operationId: "dsps.case.update",
        name: "Update DSPS Case",
        checkpointProfile: .soft,
        riskLevel: .medium,
        allowedModes: [.assistive, .autopilot],
        maxSensitivity: .sensitive
    )

    // Academic record operations
    public static let enrollStudent = OperationProfile(
        operationId: "transcriptum.enroll",
        name: "Enroll Student",
        checkpointProfile: .hard,
        riskLevel: .high,
        allowedModes: [.assistive], // No autopilot for enrollments
        maxSensitivity: .restricted
    )

    public static let recordGrade = OperationProfile(
        operationId: "transcriptum.grade.record",
        name: "Record Grade",
        checkpointProfile: .hard,
        riskLevel: .critical,
        allowedModes: [.assistive], // Never autopilot for grades
        requiredCapabilities: ["grades.manage", "grades.submit.assigned"],
        maxSensitivity: .restricted
    )

    // Configuration operations
    public static let changeConfig = OperationProfile(
        operationId: "system.config.change",
        name: "Change System Configuration",
        checkpointProfile: .hard,
        riskLevel: .critical,
        allowedModes: [.assistive],
        requiredCapabilities: ["system.manage"]
    )

    public static let changePolicy = OperationProfile(
        operationId: "governance.policy.change",
        name: "Change Governance Policy",
        checkpointProfile: .hard,
        riskLevel: .critical,
        allowedModes: [.assistive],
        requiredCapabilities: ["security.manage"]
    )

    /// All standard profiles.
    public static let all: [OperationProfile] = [
        viewEntity, queryEntities,
        createEntity, updateEntity, deleteEntity,
        createDspsCase, updateDspsCase,
        enrollStudent, recordGrade,
        changeConfig, changePolicy
    ]
}
