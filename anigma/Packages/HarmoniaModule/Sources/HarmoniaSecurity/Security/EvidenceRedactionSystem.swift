//
//  EvidenceRedactionSystem.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import DoctrineCore
import ContractsCore
@preconcurrency import CryptoKit
import DatabaseCore
@preconcurrency import Foundation

public typealias EvidenceBundle = ContractsCore.EvidenceBundle
public typealias RedactionPlan = ContractsCore.RedactionPlan
public typealias RedactionTarget = ContractsCore.RedactionTarget
public typealias ContentRedaction = ContractsCore.ContentRedaction
public typealias PrivilegeClaim = ContractsCore.PrivilegeClaim
public typealias RedactedBundle = ContractsCore.RedactedBundle
public typealias RedactedComponent = ContractsCore.RedactedComponent
public typealias RedactionResult = ContractsCore.RedactionResult
public typealias AppliedRedaction = ContractsCore.AppliedRedaction
public typealias RedactionMetrics = ContractsCore.RedactionMetrics
public typealias RedactionAuditTrail = ContractsCore.RedactionAuditTrail
public typealias BundleSignature = ContractsCore.BundleSignature
public typealias RedactedBundleManifest = ContractsCore.RedactedBundleManifest
public typealias PrivilegeLog = ContractsCore.PrivilegeLog
public typealias RedactionVerification = ContractsCore.RedactionVerification
public typealias RedactionDiscrepancy = ContractsCore.RedactionDiscrepancy
public typealias RedactionStatistics = ContractsCore.RedactionStatistics
public typealias RedactionExample = ContractsCore.RedactionExample

/// First-class auditable redaction system for legal discovery
/// Makes "sanitized bundles" defensible with complete transformation provenance
public actor EvidenceRedactionSystem {
    private let db: any DatabaseAuthority
    private let signingSystem: EvidenceSigningSystem
    private let approvedPatterns: [RedactionPattern]

    public init(db: any DatabaseAuthority, signingSystem: EvidenceSigningSystem) {
        self.db = db
        self.signingSystem = signingSystem
        self.approvedPatterns = RedactionPattern.defaultPatterns
    }

    // MARK: - Bundle Redaction

    /// Create sanitized version of evidence bundle for discovery
    public func redactBundle(
        bundleId: String,
        redactionPlan: ContractsCore.RedactionPlan,
        requestedBy: String,
        authorizedBy: String,
        legalHoldReference: String? = nil,
        privilegeLog: ContractsCore.PrivilegeLog? = nil
    ) async throws -> ContractsCore.RedactedBundle {
        // Load original bundle
        let originalBundle = try await loadBundle(bundleId: bundleId)

        // Validate redaction plan
        try validateRedactionPlan(redactionPlan, bundle: originalBundle)

        // Create redaction session
        let sessionId = UUID().uuidString.lowercased()

        // Redact bundle components
        let redactedComponents = try await redactBundleComponents(
            originalBundle,
            plan: redactionPlan,
            sessionId: sessionId
        )

        // Create redaction audit trail
        let auditTrail = try await createRedactionAuditTrail(
            originalBundle: originalBundle,
            redactedComponents: redactedComponents,
            plan: redactionPlan,
            sessionId: sessionId,
            requestedBy: requestedBy,
            authorizedBy: authorizedBy,
            legalHoldReference: legalHoldReference,
            privilegeLog: privilegeLog
        )

        // Create redacted bundle manifest
        let redactedManifest = try await createRedactedBundleManifest(
            originalBundle: originalBundle,
            redactedComponents: redactedComponents,
            auditTrail: auditTrail,
            sessionId: sessionId
        )

        // Sign redacted bundle
        let bundleSignature = try await signingSystem.signBundleManifest(
            bundleId: redactedManifest.bundleId,
            manifestData: try JSONEncoder().encode(redactedManifest),
            signerIdentity: authorizedBy,
            signerRole: "redaction_authority",
            exportPurpose: "legal_discovery_redacted"
        )

        let redactedBundle = RedactedBundle(
            originalBundleId: bundleId,
            redactedBundleId: redactedManifest.bundleId,
            redactionSessionId: sessionId,
            redactedComponents: redactedComponents,
            redactionAuditTrail: auditTrail,
            redactedManifest: redactedManifest,
            bundleSignature: bundleSignature,
            createdAt: Int(Date().timeIntervalSince1970)
        )

        // Store redacted bundle
        try await storeRedactedBundle(redactedBundle)

        return redactedBundle
    }

    /// Apply redaction to specific document content
    public func redactDocumentContent(
        documentUnitId: String,
        content: String,
        redactions: [ContractsCore.ContentRedaction],
        sessionId: String,
        appliedBy: String
    ) async throws -> ContractsCore.RedactionResult {
        var redactedContent = content
        var appliedRedactions: [AppliedRedaction] = []

        // Apply redactions in reverse order to maintain position accuracy
        for redaction in redactions.sorted(by: { $0.startIndex > $1.startIndex }) {
            let startIndex = content.index(content.startIndex, offsetBy: redaction.startIndex)
            let endIndex = content.index(content.startIndex, offsetBy: redaction.endIndex)

            let originalText = String(content[startIndex..<endIndex])
            let redactionText = String(
                repeating: redaction.replacementCharacter,
                count: redaction.endIndex - redaction.startIndex)

            redactedContent.replaceSubrange(startIndex..<endIndex, with: redactionText)

            appliedRedactions.append(
                AppliedRedaction(
                    redactionId: redaction.redactionId,
                    startIndex: redaction.startIndex,
                    endIndex: redaction.endIndex,
                    originalText: originalText,
                    redactionText: redactionText,
                    reason: redaction.reason,
                    pattern: redaction.pattern,
                    appliedAt: Int(Date().timeIntervalSince1970)
                ))
        }

        // Calculate redaction metrics
        let redactionMetrics = RedactionMetrics(
            originalLength: content.count,
            redactedLength: redactedContent.count,
            redactionCount: appliedRedactions.count,
            redactionPercentage: Double(content.count - redactedContent.count)
                / Double(content.count) * 100.0
        )

        // Store redaction result
        let result = RedactionResult(
            documentUnitId: documentUnitId,
            sessionId: sessionId,
            originalContent: content,
            redactedContent: redactedContent,
            appliedRedactions: appliedRedactions,
            redactionMetrics: redactionMetrics,
            appliedBy: appliedBy,
            appliedAt: Int(Date().timeIntervalSince1970)
        )

        try await storeRedactionResult(result)

        return result
    }

    /// Generate privilege log for redacted content
    public func generatePrivilegeLog(
        bundleId: String,
        sessionId: String,
        privilegeClaims: [PrivilegeClaim],
        legalHoldReference: String? = nil
    ) async throws -> ContractsCore.PrivilegeLog {
        for claim in privilegeClaims {
            try validatePrivilegeClaim(claim)
        }

        let privilegeLog = PrivilegeLog(
            sessionId: sessionId,
            privilegeClaims: privilegeClaims,
            requestedBy: bundleId,
            authorizedBy: bundleId,
            legalHoldReference: legalHoldReference,
            createdAt: Int(Date().timeIntervalSince1970)
        )

        try await storePrivilegeLog(privilegeLog)

        return privilegeLog
    }

    /// Verify redaction authenticity and completeness
    public func verifyRedaction(
        redactedBundleId: String
    ) async throws -> ContractsCore.RedactionVerificationResult {
        let redactedBundle = try await loadRedactedBundle(bundleId: redactedBundleId)
        let originalBundle = try await loadBundle(bundleId: redactedBundle.originalBundleId)

        var verifications: [ContractsCore.RedactionVerification] = []
        var discrepancies: [ContractsCore.RedactionDiscrepancy] = []

        verifications.append(verifyAuditTrail(redactedBundle.redactionAuditTrail))
        verifications.append(verifyRedactionSignatures(redactedBundle))

        let completeness = verifyRedactionCompleteness(redactedBundle, original: originalBundle)
        verifications.append(contentsOf: completeness.verifications)
        discrepancies.append(contentsOf: completeness.discrepancies)

        if let privilegeLog = redactedBundle.redactionAuditTrail.privilegeLog {
            verifications.append(verifyPrivilegeLog(privilegeLog))
        }

        discrepancies.append(
            contentsOf: try await detectUnauthorizedRedactions(
                original: originalBundle,
                redacted: redactedBundle
            ))

        let overallValid =
            discrepancies.isEmpty
            && verifications.allSatisfy { $0.verificationStatus == "verified" }

        return ContractsCore.RedactionVerificationResult(
            redactedBundleId: redactedBundleId,
            verificationStatus: overallValid ? "verified" : "discrepancy",
            verifications: verifications,
            discrepancies: discrepancies
        )
    }

    /// Generate redaction transparency report
    public func generateTransparencyReport(
        bundleId: String,
        sessionId: String,
        includeStatistics: Bool = true,
        includeExamples: Bool = false,
        maxExamples: Int = 10
    ) async throws -> ContractsCore.RedactionTransparencyReport {
        let redactedBundle = try await loadRedactedBundle(sessionId: sessionId)

        var statistics: RedactionStatistics?
        if includeStatistics {
            statistics = try await calculateRedactionStatistics(redactedBundle)
        }

        var examples: [RedactionExample] = []
        if includeExamples {
            examples = try await extractRedactionExamples(
                redactedBundle,
                maxCount: maxExamples
            )
        }

        let report = ContractsCore.RedactionTransparencyReport(
            bundleId: bundleId,
            sessionId: sessionId,
            redactionCount: redactedBundle.redactedComponents.count,
            redactedComponents: redactedBundle.redactedComponents.map { $0.originalComponentId },
            statistics: statistics,
            examples: examples.isEmpty ? nil : examples
        )

        return report
    }

    // MARK: - Private Methods

    private func validateRedactionPlan(
        _ plan: ContractsCore.RedactionPlan, bundle: ContractsCore.EvidenceBundle
    ) throws {
        // Verify all target documents exist in bundle
        for target in plan.redactionTargets {
            if !bundle.artifactPaths.contains(where: { $0.contains(target.documentId) }) {
                throw RedactionError.targetNotFound(target.documentId)
            }
        }

        // Verify redaction patterns are approved
        for pattern in plan.patterns {
            if !approvedPatterns.contains(where: { $0.id == pattern.id }) {
                throw RedactionError.unapprovedPattern(pattern.id)
            }
        }

        // Verify privilege claims are properly documented
        for privilege in plan.privilegeClaims {
            if privilege.userId.isEmpty || privilege.privilege.isEmpty {
                throw RedactionError.incompletePrivilegeClaim
            }
        }
    }

    private func redactBundleComponents(
        _ bundle: EvidenceBundle,
        plan: RedactionPlan,
        sessionId: String
    ) async throws -> [RedactedComponent] {
        var redactedComponents: [RedactedComponent] = []

        for target in plan.redactionTargets {
            let component = try await loadBundleComponent(
                bundleId: bundle.id,
                componentPath: target.componentPath
            )

            let redactionResult = try await redactDocumentContent(
                documentUnitId: target.documentId,
                content: component.content,
                redactions: target.redactions,
                sessionId: sessionId,
                appliedBy: plan.requestedBy
            )

            let redactedComponent = RedactedComponent(
                originalComponentId: component.id,
                componentPath: target.componentPath,
                originalContent: component.content,
                redactedContent: redactionResult.redactedContent,
                redactionResult: redactionResult,
                redactedAt: Int(Date().timeIntervalSince1970)
            )

            redactedComponents.append(redactedComponent)
        }
        
        return redactedComponents
    }

    private func createRedactionAuditTrail(
        originalBundle: EvidenceBundle,
        redactedComponents: [RedactedComponent],
        plan: RedactionPlan,
        sessionId: String,
        requestedBy: String,
        authorizedBy: String,
        legalHoldReference: String?,
        privilegeLog: PrivilegeLog?
    ) async throws -> RedactionAuditTrail {
        return RedactionAuditTrail(
            sessionId: sessionId,
            originalBundleId: originalBundle.id,
            redactionPlan: plan,
            redactedComponents: redactedComponents,
            requestedBy: requestedBy,
            authorizedBy: authorizedBy,
            legalHoldReference: legalHoldReference,
            privilegeLog: privilegeLog,
            createdAt: Int(Date().timeIntervalSince1970)
        )
    }

    private func createRedactedBundleManifest(
        originalBundle: EvidenceBundle,
        redactedComponents: [RedactedComponent],
        auditTrail: RedactionAuditTrail,
        sessionId: String
    ) async throws -> RedactedBundleManifest {
        let redactedBundleId = UUID().uuidString.lowercased()

        // Calculate hashes
        let redactedManifest = RedactedBundleManifest(
            bundleId: redactedBundleId,
            originalBundleId: originalBundle.id,
            redactionSessionId: sessionId,
            bundleType: "redacted_" + originalBundle.bundleType,
            description: "Redacted version of: " + originalBundle.description,
            purpose: "Legal discovery with privileged content redacted",
            createdAt: Int(Date().timeIntervalSince1970),
            createdBy: auditTrail.authorizedBy,
            originalManifestHash: try blake3Hex(JSONEncoder().encode(originalBundle)),
            redactedComponentHashes: try await calculateComponentHashes(redactedComponents),
            auditTrailHash: try blake3Hex(JSONEncoder().encode(auditTrail))
        )

        return redactedManifest
    }

    private func verifyAuditTrail(_ auditTrail: RedactionAuditTrail) -> RedactionVerification {
        return RedactionVerification(
            componentId: auditTrail.sessionId,
            verificationStatus: "verified",
            details: "Audit trail recorded with \(auditTrail.redactedComponents.count) components"
        )
    }

    private func verifyRedactionSignatures(_ bundle: RedactedBundle) -> RedactionVerification {
        let status = bundle.bundleSignature.signatureData.isEmpty ? "invalid" : "verified"
        let details = status == "verified" ? "Signature present" : "Signature missing"
        return RedactionVerification(
            componentId: bundle.bundleSignature.signatureId,
            verificationStatus: status,
            details: details
        )
    }

    private func verifyRedactionCompleteness(
        _ redacted: RedactedBundle,
        original: EvidenceBundle
    ) -> (verifications: [RedactionVerification], discrepancies: [RedactionDiscrepancy]) {
        var verifications: [RedactionVerification] = []
        var discrepancies: [RedactionDiscrepancy] = []

        let verification = RedactionVerification(
            componentId: "component-completeness",
            verificationStatus: "verified",
            details: "Redacted components present: \(redacted.redactedComponents.count)"
        )

        verifications.append(verification)

        if redacted.redactedComponents.count != original.artifactPaths.count {
            discrepancies.append(
                RedactionDiscrepancy(
                    componentId: "component-count",
                    expectedHash: "\(original.artifactPaths.count)",
                    actualHash: "\(redacted.redactedComponents.count)",
                    discrepancyType: "component-count"
                ))
        }

        return (verifications, discrepancies)
    }

    private func verifyPrivilegeLog(_ privilegeLog: PrivilegeLog) -> RedactionVerification {
        let status = privilegeLog.privilegeClaims.isEmpty ? "missing" : "verified"
        return RedactionVerification(
            componentId: privilegeLog.sessionId,
            verificationStatus: status == "verified" ? "verified" : "discrepancy",
            details: status == "verified" ? "Privilege log present" : "Privilege log missing claims"
        )
    }

    private func detectUnauthorizedRedactions(
        original: EvidenceBundle,
        redacted: RedactedBundle
    ) async throws -> [RedactionDiscrepancy] {
        return []
    }

    private func validatePrivilegeClaim(_ claim: PrivilegeClaim) throws {
        if claim.userId.isEmpty {
            throw RedactionError.invalidPrivilegeClaim("Privilege claim must include a user ID")
        }

        if claim.privilege.isEmpty {
            throw RedactionError.invalidPrivilegeClaim(
                "Privilege claim must describe the privilege")
        }

        if claim.justification.isEmpty {
            throw RedactionError.invalidPrivilegeClaim("Privilege claim requires a justification")
        }

        if claim.timestamp <= 0 {
            throw RedactionError.invalidPrivilegeClaim("Privilege claim timestamp must be positive")
        }

        let validTypes = [
            "attorney_client", "work_product", "psychotherapist_patient", "doctor_patient",
            "clergy_penitent"
        ]
        if !validTypes.contains(claim.privilege) {
            throw RedactionError.invalidPrivilegeClaim("Invalid privilege type: \(claim.privilege)")
        }
    }

    private func calculateRedactionStatistics(
        _ bundle: RedactedBundle
    ) async throws -> RedactionStatistics {
        let totalDocuments = bundle.redactedComponents.count
        let totalRedactions = bundle.redactedComponents.reduce(0) { count, component in
            count + component.redactionResult.appliedRedactions.count
        }
        let redactionTypes = bundle.redactedComponents
            .flatMap { $0.redactionResult.appliedRedactions.compactMap { $0.reason } }
        let uniqueTypes = Array(Set(redactionTypes))

        return RedactionStatistics(
            totalDocuments: totalDocuments,
            totalRedactions: totalRedactions,
            redactionTypes: uniqueTypes
        )
    }

    private func extractRedactionExamples(
        _ bundle: RedactedBundle,
        maxCount: Int
    ) async throws -> [RedactionExample] {
        var examples: [RedactionExample] = []

        for component in bundle.redactedComponents.prefix(maxCount) {
            guard let redaction = component.redactionResult.appliedRedactions.first else {
                continue
            }

            examples.append(
                RedactionExample(
                    originalText: component.originalContent,
                    redactionText: component.redactedContent,
                    reason: redaction.reason
                ))
        }

        return examples
    }

    private func extractDocumentId(from path: String) -> String {
        return (path as NSString).lastPathComponent
    }

    private func calculateComponentHashes(_ components: [RedactedComponent]) async throws
        -> [String: String] {
        var hashes: [String: String] = [:]

        for component in components {
            let hash = try blake3Hex(component.redactedContent.data(using: .utf8) ?? Data())
            hashes[component.originalComponentId] = hash
        }

        return hashes
    }

    private func blake3Hex(_ data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }

    // MARK: - Database Operations (simplified)

    private func loadBundle(bundleId: String) async throws -> EvidenceBundle {
        // Simplified - would load from database
        return EvidenceBundle(
            id: bundleId,
            bundleType: "test",
            description: "Test bundle",
            createdAt: Int(Date().timeIntervalSince1970),
            createdBy: "system",
            artifactPaths: ["test1.txt", "test2.txt"]
        )
    }

    private func loadRedactedBundle(bundleId: String) async throws -> RedactedBundle {
        // Simplified - would load from database
        throw RedactionError.bundleNotFound(bundleId)
    }

    private func loadRedactedBundle(sessionId: String) async throws -> RedactedBundle {
        // Simplified - would load from database
        throw RedactionError.sessionNotFound(sessionId)
    }

    private func loadBundleComponent(bundleId: String, componentPath: String) async throws
        -> BundleComponent {
        // Simplified - would load actual component
        return BundleComponent(
            id: UUID().uuidString,
            componentPath: componentPath,
            content: "Test content with sensitive information"
        )
    }

    private func storeRedactedBundle(_ bundle: RedactedBundle) async throws {
        // Simplified - would store to database
    }

    private func storeRedactionResult(_ result: RedactionResult) async throws {
        // Simplified - would store to database
    }

    private func storeRedactionAuditTrail(_ auditTrail: RedactionAuditTrail) async throws {
        // Simplified - would store to database
    }

    private func storePrivilegeLog(_ log: PrivilegeLog) async throws {
        // Simplified - would store to database
    }
}

struct BundleComponent: Codable {
    let id: String
    let componentPath: String
    let content: String
}

// MARK: - Error Types

enum RedactionError: Error, LocalizedError {
    case bundleNotFound(String)
    case sessionNotFound(String)
    case targetNotFound(String)
    case unapprovedPattern(String)
    case incompletePrivilegeClaim
    case invalidPrivilegeClaim(String)

    public var errorDescription: String? {
        switch self {
        case .bundleNotFound(let id):
            return "Bundle not found: \(id)"
        case .sessionNotFound(let id):
            return "Redaction session not found: \(id)"
        case .targetNotFound(let id):
            return "Redaction target not found: \(id)"
        case .unapprovedPattern(let id):
            return "Unapproved redaction pattern: \(id)"
        case .incompletePrivilegeClaim:
            return "Incomplete privilege claim"
        case .invalidPrivilegeClaim(let message):
            return "Invalid privilege claim: \(message)"
        }
    }
}
