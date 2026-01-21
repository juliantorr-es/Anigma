//
//  CapabilityValidator.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Capability validation for Anigma security spine.
//  Phase 1: Dumb in-memory validator with hardcoded policies.
//  Phase 2: Will be replaced with full CapabilitySecurityKernel.
//

import Foundation
import SecurityEventsManager
import AnigmaCore
import HarmoniaModule

// MARK: - Capability Context

/// Context for capability validation requests.
public struct CapabilityContext: Sendable {
    public let engineId: String?
    public let projectId: String?
    public let taskId: String?
    public let filePath: String?

    public init(
        engineId: String? = nil,
        projectId: String? = nil,
        taskId: String? = nil,
        filePath: String? = nil
    ) {
        self.engineId = engineId
        self.projectId = projectId
        self.taskId = taskId
        self.filePath = filePath
    }
}

// MARK: - Capability Validation Protocol

/// Protocol for validating engine capabilities.
public protocol CapabilityValidating: Sendable {
    /// Validate that an engine can perform operations with requested capabilities.
    /// - Parameters:
    ///   - engineType: Type of engine requesting capabilities
    ///   - requestedCapabilities: Capabilities the engine needs
    ///   - currentZone: Security zone where execution will happen
    ///   - claimedTier: Optional claimed trust tier (for escalation detection)
    ///   - context: Optional context for audit logging
    /// - Returns: Validation result with optional capability grant
    mutating func validate(
        engineType: EngineType,
        requestedCapabilities: [GranularCapability],
        currentZone: SecurityZone,
        claimedTier: TrustTier?,
        context: CapabilityContext?
    ) async throws -> ValidationResult

    /// Check if a capability grant is still valid.
    /// - Parameter grant: Capability grant to validate
    /// - Returns: True if grant is valid and not expired
    func validateGrant(_ grant: CapabilityGrant) -> Bool

    /// Revoke capabilities for an engine.
    /// - Parameter engineId: Engine identifier
    mutating func revokeCapabilities(for engineId: String)
}

// MARK: - Dumb Capability Validator (Phase 1)

/// Simple in-memory capability validator for Phase 1.
/// Hardcoded policies, no persistence, no escalation detection.
public struct DumbCapabilityValidator: CapabilityValidating {
    private let policies: [EngineType: CapabilityPolicy]
    private var activeGrants: [String: CapabilityGrant] = [:]
    private let securityEvents: SecurityEventsManager
    private let trustTierManager: TrustTierManager

    public init(
        securityEvents: SecurityEventsManager = SecurityEventsManager(),
        trustTierManager: TrustTierManager = TrustTierManager()
    ) {
        // Hardcoded policies for Phase 1
        self.policies = [
            .migration: CapabilityPolicy.migration,
            .doctrineScout: CapabilityPolicy.doctrineScout,
            .inspiration: CapabilityPolicy.inspiration
        ]
        self.securityEvents = securityEvents
        self.trustTierManager = trustTierManager
    }

    /// Helper to log capability blocked events
    private func logCapabilityBlocked(
        engineType: EngineType,
        requestedCapabilities: [GranularCapability],
        currentZone: SecurityZone,
        claimedTier: TrustTier?,
        context: CapabilityContext?,
        operation: String,
        reason: String,
        severity: SecurityEventSeverity = .medium
    ) {
        let details = SecurityEventDetails(
            engineType: engineType.rawValue,
            engineId: context?.engineId,
            zone: currentZone.rawValue,
            capability: requestedCapabilities.map { $0.rawValue }.joined(separator: ", "),
            reason: reason,
            attemptedAction: operation,
            taskId: context?.taskId
        )
        securityEvents.logEvent(
            type: .capabilityBlocked,
            severity: severity,
            engineId: context?.engineId,
            operation: operation,
            details: details
        )
    }

    public mutating func validate(
        engineType: EngineType,
        requestedCapabilities: [GranularCapability],
        currentZone: SecurityZone,
        claimedTier: TrustTier?,
        context: CapabilityContext? = nil
    ) async throws -> ValidationResult {
        // 1. Get policy for this engine type
        guard let policy = policies[engineType] else {
            // Log security event for unknown engine type
            logCapabilityBlocked(
                engineType: engineType,
                requestedCapabilities: requestedCapabilities,
                currentZone: currentZone,
                claimedTier: claimedTier,
                context: context,
                operation: "validate_engine_type",
                reason: "Unknown engine type: \(engineType.rawValue)",
                severity: .high
            )
            throw CapabilityError.unknownEngineType(engineType.rawValue)
        }

        // 2. Get actual trust tier from dynamic scoring
        let actualTier = await trustTierManager.resolveEffectiveTrust(
            engineType: engineType.rawValue,
            engineId: context?.engineId,
            projectId: context?.projectId
        )

        // 3. Check for capability escalation (claimed tier > actual tier)
        if let claimedTier = claimedTier, claimedTier > actualTier {
            // Log security event for capability escalation attempt
            logCapabilityBlocked(
                engineType: engineType,
                requestedCapabilities: requestedCapabilities,
                currentZone: currentZone,
                claimedTier: claimedTier,
                context: context,
                operation: "validate_capability_escalation",
                reason: "Capability escalation attempt. Claimed: \(claimedTier.rawValue), Actual: \(actualTier.rawValue)",
                severity: DoctrineCore.DoctrineSeverity.critical
            )

            // Degrade trust for escalation attempt
            if let engineId = context?.engineId {
                await trustTierManager.degradeTrust(
                    subjectId: engineId,
                    subjectKind: .engineInstance,
                    reason: "Capability escalation attempt: claimed \(claimedTier.rawValue) > actual \(actualTier.rawValue)",
                    severity: .high
                )
            }

            return .invalid(reason: "Capability escalation attempt: claimed \(claimedTier.rawValue) > actual \(actualTier.rawValue)")
        }

        // 4. Check trust tier
        guard actualTier >= policy.minimumTrustTier else {
            // Log security event for insufficient trust tier
            logCapabilityBlocked(
                engineType: engineType,
                requestedCapabilities: requestedCapabilities,
                currentZone: currentZone,
                claimedTier: claimedTier,
                context: context,
                operation: "validate_trust_tier",
                reason: "Insufficient trust tier: \(actualTier.rawValue) < \(policy.minimumTrustTier.rawValue)",
                severity: .medium
            )
            return .invalid(reason: "Insufficient trust tier: \(actualTier.rawValue) < \(policy.minimumTrustTier.rawValue)")
        }

        // 5. Check zone
        guard policy.allowedZones.contains(currentZone) else {
            // Log security event for zone violation
            logCapabilityBlocked(
                engineType: engineType,
                requestedCapabilities: requestedCapabilities,
                currentZone: currentZone,
                claimedTier: claimedTier,
                context: context,
                operation: "validate_zone",
                reason: "Zone not allowed: \(currentZone.rawValue). Allowed: \(policy.allowedZones.map { $0.rawValue }.joined(separator: ", "))",
                severity: .high
            )
            return .invalid(reason: "Engine type '\(engineType.rawValue)' not allowed in zone '\(currentZone.rawValue)'")
        }

        // 6. Check required capabilities
        let missingRequired = policy.requiredCapabilities.filter {
            !requestedCapabilities.contains($0)
        }

        if !missingRequired.isEmpty {
            // Log security event for missing required capabilities
            logCapabilityBlocked(
                engineType: engineType,
                requestedCapabilities: requestedCapabilities,
                currentZone: currentZone,
                claimedTier: claimedTier,
                context: context,
                operation: "validate_required_capabilities",
                reason: "Missing required capabilities: \(missingRequired.map { $0.rawValue }.joined(separator: ", ")). Required: \(policy.requiredCapabilities.map { $0.rawValue }.joined(separator: ", "))",
                severity: .medium
            )
            return .invalid(reason: "Missing required capabilities: \(missingRequired.map { $0.rawValue }.joined(separator: ", "))")
        }

        // 7. Check risk level of requested capabilities
        let maxRequestedRisk = requestedCapabilities.map { $0.riskLevel }.max() ?? .low
        if maxRequestedRisk > policy.maximumRiskLevel {
            // Log security event for risk level violation
            logCapabilityBlocked(
                engineType: engineType,
                requestedCapabilities: requestedCapabilities,
                currentZone: currentZone,
                claimedTier: claimedTier,
                context: context,
                operation: "validate_risk_level",
                reason: "Risk level violation: \(maxRequestedRisk.rawValue) > \(policy.maximumRiskLevel.rawValue)",
                severity: .high
            )
            return .invalid(reason: "Requested capabilities exceed maximum risk level: \(maxRequestedRisk.rawValue) > \(policy.maximumRiskLevel.rawValue)")
        }

        // 8. Check for capability escalation (simple Phase 1 check)
        if !policy.allowRuntimeRequests {
            // Engine can only request capabilities from its policy
            let allowedCapabilities = policy.requiredCapabilities + policy.optionalCapabilities
            let unauthorized = requestedCapabilities.filter {
                !allowedCapabilities.contains($0)
            }

            if !unauthorized.isEmpty {
            // Log security event for capability escalation attempt
            logCapabilityBlocked(
                engineType: engineType,
                requestedCapabilities: requestedCapabilities,
                currentZone: currentZone,
                claimedTier: claimedTier,
                context: context,
                operation: "validate_capability_escalation",
                reason: "Capability escalation attempt. Unauthorized: \(unauthorized.map { $0.rawValue }.joined(separator: ", ")). Allowed: \(allowedCapabilities.map { $0.rawValue }.joined(separator: ", "))",
                severity: DoctrineCore.DoctrineSeverity.critical
            )
                return .invalid(reason: "Unauthorized capability escalation attempt: \(unauthorized.map { $0.rawValue }.joined(separator: ", "))")
            }
        }

        // 9. Create capability grant
        let grant = CapabilityGrant(
            engineId: "\(engineType.rawValue)-\(UUID().uuidString.prefix(8))",
            capabilities: requestedCapabilities,
            expiresAt: Date().addingTimeInterval(policy.grantTTL),
            zone: currentZone,
            trustTier: actualTier
        )

        // Store grant (in-memory for Phase 1)
        activeGrants[grant.engineId] = grant

        // Log security event for successful capability grant
        let grantDetails = SecurityEventDetails(
            engineType: engineType.rawValue,
            engineId: context?.engineId,
            zone: currentZone.rawValue,
            capability: requestedCapabilities.map { $0.rawValue }.joined(separator: ", "),
            reason: "Capability grant created",
            attemptedAction: "capability_grant_created",
            taskId: context?.taskId
        )
        securityEvents.logEvent(
            type: .capabilityGranted,
            severity: .low,
            engineId: context?.engineId,
            operation: "capability_grant_created",
            details: grantDetails
        )

        return .valid(grant: grant)
    }

    public func validateGrant(_ grant: CapabilityGrant) -> Bool {
        // Check if grant exists and is not expired
        guard let storedGrant = activeGrants[grant.id.uuidString] else {
            return false
        }

        return !storedGrant.isExpired && storedGrant.id == grant.id
    }

    public mutating func revokeCapabilities(for engineId: String) {
        activeGrants.removeValue(forKey: engineId)
    }
}

// MARK: - Capability Errors

public enum CapabilityError: Error, LocalizedError {
    case unknownEngineType(String)
    case policyNotFound(String)
    case capabilityEscalation(String)
    case grantExpired(String)
    case zoneViolation(String)

    public var errorDescription: String? {
        switch self {
        case .unknownEngineType(let type):
            return "Unknown engine type: \(type)"
        case .policyNotFound(let engineType):
            return "No capability policy found for engine type: \(engineType)"
        case .capabilityEscalation(let details):
            return "Capability escalation attempt: \(details)"
        case .grantExpired(let engineId):
            return "Capability grant expired for engine: \(engineId)"
        case .zoneViolation(let details):
            return "Security zone violation: \(details)"
        }
    }
}

// MARK: - Task Analysis Helper

/// Helper to analyze migration tasks and determine required capabilities.
public struct TaskCapabilityAnalyzer {
    /// Analyze a migration task to determine engine type and required capabilities.
    public static func analyze(_ task: MigrationTaskRow) -> (EngineType, [GranularCapability]) {
        // Map task features to capabilities
        switch task.featureCategory {
        case "swift6-migration":
            return (.migration, [
                .fsReadProject,
                .fsWriteSource,
                .gitRead,
                .executeSwift
            ])

        case "inspiration-pattern":
            return (.inspiration, [
                .fsReadProject,
                .netRawGithub,
                .netHttpGet,
                .llmLocal
            ])

        case "doctrine-compliance":
            return (.doctrineScout, [
                .fsReadProject,
                .executeSwift
            ])

        case "secret-rotation":
            return (.secretManager, [
                .secretsReadVaultKey,
                .secretsWriteProjectToken,
                .systemKeychain
            ])

        case "supply-chain-scan":
            return (.supplyChainScanner, [
                .fsReadProject,
                .netHttpGet
            ])

        default:
            // Conservative default for unknown task types
            return (.migration, [
                .fsReadProject,
                .executeSwift
            ])
        }
    }

    /// Determine security zone from task context.
    public static func determineZone(for task: MigrationTaskRow) -> SecurityZone {
        // Default based on task type
        switch task.featureCategory {
        case "swift6-migration", "doctrine-compliance":
            return .selfHost
        case "inspiration-pattern":
            return .inspiration
        case "secret-rotation":
            return .system
        default:
            return .sandbox // Most restrictive default
        }
    }
}

// MARK: - Logging Helper

extension DumbCapabilityValidator {
    /// Log capability validation decision for audit trail.
    private func logValidation(
        engineType: EngineType,
        requestedCapabilities: [GranularCapability],
        zone: SecurityZone,
        claimedTier: TrustTier?,
        result: ValidationResult
    ) {
        let capabilityList = requestedCapabilities.map { $0.rawValue }.joined(separator: ", ")

        switch result {
        case .valid(let grant):
            if let grant = grant {
                let claimedInfo = claimedTier != nil ? "Claimed: \(claimedTier!.rawValue)" : "No claim"
                print("[CAPABILITY][VALID] Engine: \(engineType.rawValue), Zone: \(zone.rawValue), \(claimedInfo)")
                print("[CAPABILITY][GRANT] ID: \(grant.id), Expires: \(grant.expiresAt), Capabilities: \(capabilityList)")
            } else {
                let claimedInfo = claimedTier != nil ? "Claimed: \(claimedTier!.rawValue)" : "No claim"
                print("[CAPABILITY][VALID] Engine: \(engineType.rawValue), Zone: \(zone.rawValue), \(claimedInfo)")
            }

        case .invalid(let reason):
            let claimedInfo = claimedTier != nil ? "Claimed: \(claimedTier!.rawValue)" : "No claim"
            print("[CAPABILITY][INVALID] Engine: \(engineType.rawValue), Zone: \(zone.rawValue), \(claimedInfo)")
            print("[CAPABILITY][REASON] \(reason)")
            print("[CAPABILITY][REQUESTED] \(capabilityList)")
        }
    }
}

// MARK: - Test Helper

#if DEBUG
extension DumbCapabilityValidator {
    /// Test helper to verify policy enforcement.
    public mutating func testPolicyEnforcement() async -> [String: Bool] {
        var results: [String: Bool] = [:]

        // Test 1: Migration engine with correct capabilities
        do {
            let result = try await validate(
                engineType: .migration,
                requestedCapabilities: [.fsReadProject, .fsWriteSource, .gitRead, .executeSwift],
                currentZone: .selfHost,
                claimedTier: .gold
            )
            results["migration_valid"] = result.isValid
        } catch {
            results["migration_valid"] = false
        }

        // Test 2: Migration engine with insufficient trust
        do {
            let result = try await validate(
                engineType: .migration,
                requestedCapabilities: [.fsReadProject, .fsWriteSource],
                currentZone: .selfHost,
                claimedTier: .silver
            )
            results["migration_insufficient_trust"] = !result.isValid
        } catch {
            results["migration_insufficient_trust"] = true
        }

        // Test 3: Secret manager in wrong zone
        do {
            let result = try await validate(
                engineType: .secretManager,
                requestedCapabilities: [.secretsReadVaultKey],
                currentZone: .selfHost, // Should be .system
                claimedTier: .platinum
            )
            results["secret_manager_wrong_zone"] = !result.isValid
        } catch {
            results["secret_manager_wrong_zone"] = true
        }

        // Test 4: Capability escalation attempt
        do {
            let result = try await validate(
                engineType: .doctrineScout,
                requestedCapabilities: [.fsReadProject, .executeSwift, .secretsReadVaultKey], // secrets not allowed
                currentZone: .selfHost,
                claimedTier: .silver
            )
            results["capability_escalation"] = !result.isValid
        } catch {
            results["capability_escalation"] = true
        }

        return results
    }
}
#endif
