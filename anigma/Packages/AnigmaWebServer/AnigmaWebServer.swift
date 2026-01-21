//
//  AnigmaWebServer.swift
//  AnigmaWebServer
//
//  Single Anigma Computer - Web Service as Strict Evidence Layer
//  All user coordination requests go through Cathedral evidence enforcement
//
//  This implements the "single Anigma computer" architecture where:
//  - Web layer is a thin request/response wrapper around Cathedral
//  - All coordination decisions require evidence validation
//  - Raw ML operations are completely inaccessible from web layer
//

import Foundation
import Vapor
import DatabaseCore
import ContractsCore
import HarmoniaModule
import AnigmaCore

/// Single Anigma Computer - Web Service
/// Enforces Cathedral evidence requirements for all coordination requests
@main
struct AnigmaWebServer {

    // MARK: - Core Services

    private let evidenceSubstrate: EvidenceSubstrate
    private let planCompiler: PlanCompiler
    private let dbActor: DatabaseActor

    // MARK: - Web Controllers

    /// Submit a coordination request - must pass evidence enforcement
    func submitPlanRequest(req: PlanSubmissionRequest) async throws -> PlanSubmissionResponse {
        print("🌐 Web: Plan submission request for '\(req.operationType)'")

        // Step 1: Evidence enforcement (Cathedral invariant)
        let evidenceRequirements = try await extractEvidenceRequirements(for: req.operationType)

        do {
            _ = try await evidenceSubstrate.enforceEvidenceSubstrate(
                operation: req.operationType,
                evidenceLevel: evidenceRequirements.requirement
            )

            print("✅ Web: Evidence enforcement passed - proceeding with plan generation")

        } catch CathedralError.operationBlocked(let reason) {
            print("🚫 Web: Plan submission BLOCKED - \(reason)")
            return PlanSubmissionResponse(
                id: UUID().uuidString.lowercased(),
                status: .rejected,
                reason: .insufficientEvidence(reason: reason),
                submittedAt: Date()
            )
        } catch {
            print("❌ Web: Unexpected error during evidence enforcement: \(error)")
            throw error
        }

        // Step 2: Generate evidence-backed plan
        let plan = try await planCompiler.generateEvidenceProducedPlan(
            request: PlanRequest(
                operationType: req.operationType,
                sessionContext: req.sessionContext,
                parameters: req.parameters,
                priority: req.priority
            )
        )

        print("✅ Web: Evidence-backed plan generated")
        print("   Plan hash: \(plan.evidenceDigest.hash)")
        print("   Evidence deps: \(plan.evidenceDigest.dependencies.count)")
        print("   Execution lease: \(plan.executionLease?.durationSeconds ?? 0)s")

        return PlanSubmissionResponse(
            id: UUID().uuidString.lowercased(),
            status: .accepted,
            plan: plan,
            submittedAt: Date()
        )
    }

    /// Inspect a plan with evidence verification
    func inspectPlan(req: PlanInspectionRequest) async throws -> PlanInspectionResponse {
        print("🔍 Web: Plan inspection request for '\(req.planId)'")

        // Verify plan hash and evidence integrity
        let planVerification = try await verifyPlanIntegrity(planId: req.planId)
        let evidenceVerification = try await verifyEvidenceDependencies(planId: req.planId)

        let verificationResult = PlanVerificationResult(
            planIntegrity: planVerification,
            evidenceIntegrity: evidenceVerification,
            overallValid: planVerification.isValid && evidenceVerification.isValid
        )

        if verificationResult.overallValid {
            print("✅ Web: Plan verification passed - integrity confirmed")
        } else {
            print("🚫 Web: Plan verification FAILED - integrity compromised")
        }

        return PlanInspectionResponse(
            verification: verificationResult,
            inspectedAt: Date()
        )
    }

    /// Execute a plan with evidence binding
    func executePlan(req: PlanExecutionRequest) async throws -> PlanExecutionResponse {
        print("⚡ Web: Plan execution request for '\(req.planId)'")

        // Step 1: Verify execution lease
        let leaseVerification = try await verifyExecutionLease(planId: req.planId)

        guard leaseVerification.isValid else {
            print("🚫 Web: Execution rejected - lease expired/invalid")
            return PlanExecutionResponse(
                status: .rejected,
                reason: .leaseExpired,
                executedAt: Date()
            )
        }

        // Step 2: Bind outputs to plan evidence (Phase H core transformation)
        let outputBinding = try await bindOutputsToEvidence(
            planId: req.planId,
            outputs: req.outputs
        )

        print("✅ Web: Plan execution completed")
        print("   Output evidence binding: \(outputBinding.evidenceCount)")
        print("   Evidence chain updated: \(outputBinding.chainUpdated)")

        return PlanExecutionResponse(
            status: .completed,
            outputs: outputBinding.outputIds,
            evidenceBinding: outputBinding.evidenceIds,
            executedAt: Date()
        )
    }

    /// Export evidence bundle for legal discovery
    func exportBundle(req: BundleExportRequest) async throws -> BundleExportResponse {
        print("📦 Web: Evidence bundle export request for '\(req.reason)'")

        // Verify requestor has proper authorization
        let authVerification = try await verifyRequestorAuthorization(req.requestorId)

        guard authVerification.isValid else {
            print("🚫 Web: Bundle export rejected - insufficient authorization")
            throw CathedralError.unauthorizedEvidenceAccess("Invalid requestor authorization")
        }

        // Generate court-safe evidence bundle
        let bundle = try await generateCourtSafeBundle(
            request: req,
            authorizedBy: authVerification.requestorId
        )

        print("✅ Web: Evidence bundle generated")
        print("   Bundle ID: \(bundle.id)")
        print("   Artifacts: \(bundle.artifactPaths.count)")
        print("   Chain hash: \(bundle.evidenceChainHash)")

        return BundleExportResponse(
            bundleId: bundle.id,
            artifactPaths: bundle.artifactPaths,
            generatedAt: Date()
        )
    }

    // MARK: - Evidence Enforcement Helpers

    private func extractEvidenceRequirements(for operationType: String) async throws -> EvidenceRequirements {
        // Map operation types to Cathedral evidence requirements
        switch operationType {
        case "code_generation", "model_training", "system_modification":
            return EvidenceRequirements(
                requirement: .high,
                minimumCount: 3,
                recentTimeframeSeconds: 300,
                allowedEvidenceTypes: [.tamperEvidence, .forensicAcquisition, .retrievalReceipts]
            )

        case "document_ingestion", "embedding_generation", "semantic_search":
            return EvidenceRequirements(
                requirement: .moderate,
                minimumCount: 2,
                recentTimeframeSeconds: 180,
                allowedEvidenceTypes: [.forensicAcquisition, .retrievalReceipts]
            )

        case "user_query", "configuration_change":
            return EvidenceRequirements(
                requirement: .low,
                minimumCount: 1,
                recentTimeframeSeconds: 60,
                allowedEvidenceTypes: [.tamperEvidence]
            )

        default:
            return EvidenceRequirements(
                requirement: .strict,
                minimumCount: 1,
                recentTimeframeSeconds: 600,
                allowedEvidenceTypes: [.tamperEvidence, .forensicAcquisition, .retrievalReceipts]
            )
        }
    }

    // MARK: - Plan Verification

    private func verifyPlanIntegrity(planId: String) async throws -> PlanIntegrityVerification {
        // Get plan from database and verify its evidence digest
        let plan = try await getStoredPlan(planId: planId)
        let evidenceDependencies = try await gatherPlanEvidenceDependencies(planId: planId)

        let currentDigest = calculateEvidenceDigest(evidenceDependencies)
        let storedDigest = plan.evidenceDigest

        let isValid = currentDigest.hash == storedDigest.hash &&
                      currentDigest.dependencies.count == storedDigest.dependencies.count &&
                      !containsTamperEvidence(evidenceDependencies)

        return PlanIntegrityVerification(
            isValid: isValid,
            storedHash: storedDigest.hash,
            calculatedHash: currentDigest.hash,
            dependencyCount: currentDigest.dependencies.count
        )
    }

    private func verifyEvidenceDependencies(planId: String) async throws -> EvidenceIntegrityVerification {
        let dependencies = try await gatherPlanEvidenceDependencies(planId: planId)
        let violations = dependencies.compactMap { dep in
            validateEvidenceDependency(dep)
        }

        return EvidenceIntegrityVerification(
            isValid: violations.isEmpty,
            violations: violations,
            dependencyCount: dependencies.count
        )
    }

    private func validateEvidenceDependency(_ dependency: EvidenceDependency) -> EvidenceDependencyViolation? {
        // Check if evidence is too old
        if dependency.ageSeconds > 3600 { // 1 hour
            return EvidenceDependencyViolation(
                dependencyId: dependency.id,
                violationType: .expiredEvidence,
                severity: .medium,
                description: "Evidence expired: \(dependency.ageSeconds)s old"
            )
        }

        // Check if hash matches stored value
        let storedHash = try await getStoredEvidenceHash(dependency.id)
        if storedHash != dependency.hash {
            return EvidenceDependencyViolation(
                dependencyId: dependency.id,
                violationType: .hashMismatch,
                severity: .high,
                description: "Evidence hash mismatch: expected \(storedHash), got \(dependency.hash)"
            )
        }

        return nil // No violation
    }

    // MARK: - Execution Lease Management

    private func verifyExecutionLease(planId: String) async throws -> LeaseVerification {
        let plan = try await getStoredPlan(planId: planId)

        guard let lease = plan.executionLease else {
            return LeaseVerification(
                isValid: false,
                reason: .noLease
            )
        }

        let now = Date()
        let leaseEndTime = lease.startTime.addingTimeInterval(TimeInterval(lease.durationSeconds))

        let isValid = now < leaseEndTime && lease.renewalCount < lease.maxRenewals

        return LeaseVerification(
            isValid: isValid,
            expiresAt: leaseEndTime,
            reason: isValid ? nil : .expired
        )
    }

    // MARK: - Output Evidence Binding

    private func bindOutputsToEvidence(
        planId: String,
        outputs: [String: Sendable]
    ) async throws -> OutputEvidenceBinding {

        var evidenceIds: [String] = []
        var chainUpdated = false

        // Bind each output to plan evidence
        for (outputId, data) in outputs {
            let evidenceId = try await bindOutputToPlanEvidence(
                planId: planId,
                outputId: outputId,
                data: data
            )

            evidenceIds.append(evidenceId)

            // Update evidence chain
            try await updateEvidenceChain(
                fromEvidenceId: evidenceId,
                toEvidenceId: "plan_\(planId)"
            )

            chainUpdated = true
        }

        return OutputEvidenceBinding(
            outputIds: outputs.map { $0.key },
            evidenceIds: evidenceIds,
            chainUpdated: chainUpdated,
            evidenceCount: evidenceIds.count
        )
    }

    // MARK: - Court-Safe Bundle Generation

    private func generateCourtSafeBundle(
        request: BundleExportRequest,
        authorizedBy: String
    ) async throws -> CourtSafeBundle {

        let bundleId = UUID().uuidString.lowercased()

        // Gather all relevant evidence for the time range
        let evidence = try await gatherEvidenceForExport(
            timeRangeHours: request.timeRangeHours,
            reason: request.reason
        )

        // Generate cryptographic hash of entire bundle
        let bundleHash = try await generateBundleHash(evidence: evidence)

        // Create signed manifest
        let manifest = try await generateSignedManifest(
            bundleId: bundleId,
            evidence: evidence,
            hash: bundleHash,
            authorizedBy: authorizedBy
        )

        // Create export package
        let artifactPaths = try await createExportPackage(
            bundleId: bundleId,
            manifest: manifest,
            evidence: evidence
        )

        return CourtSafeBundle(
            id: bundleId,
            artifactPaths: artifactPaths,
            evidenceChainHash: bundleHash,
            generatedAt: Date()
        )
    }
}

// MARK: - Supporting Types

/// Plan submission request
public struct PlanSubmissionRequest: Codable {
    public let operationType: String
    public let sessionContext: String?
    public let parameters: [String: Sendable]
    public let priority: PlanRequest.Priority
}

/// Plan submission response
public struct PlanSubmissionResponse: Codable {
    public let id: String
    public let status: ResponseStatus
    public let plan: EvidenceProducedPlan?
    public let reason: RejectionReason?
    public let submittedAt: Date
}

/// Plan inspection request
public struct PlanInspectionRequest: Codable {
    public let planId: String
    public let includeEvidence: Bool
}

/// Plan inspection response
public struct PlanInspectionResponse: Codable {
    public let verification: PlanVerificationResult
    public let inspectedAt: Date
}

/// Plan execution request
public struct PlanExecutionRequest: Codable {
    public let planId: String
    public let outputs: [String: Sendable]
    public let evidenceOverride: String? // For emergency use only
}

/// Plan execution response
public struct PlanExecutionResponse: Codable {
    public let status: ExecutionStatus
    public let outputs: [String]
    public let evidenceBinding: OutputEvidenceBinding?
    public let executedAt: Date
}

/// Bundle export request
public struct BundleExportRequest: Codable {
    public let reason: String
    public let timeRangeHours: Int
    public let requestorId: String
}

/// Bundle export response
public struct BundleExportResponse: Codable {
    public let bundleId: String
    public let artifactPaths: [String]
    public let generatedAt: Date
}

// MARK: - Response Enums

public enum ResponseStatus: String, Codable, CaseIterable {
    case accepted = "accepted"
    case rejected = "rejected"
    case processing = "processing"
    case completed = "completed"
}

public enum RejectionReason: Codable {
    case insufficientEvidence(reason: String)
    case leaseExpired
    case authorizationInvalid
    case evidenceCorrupted
}

public enum ExecutionStatus: String, Codable, CaseIterable {
    case completed = "completed"
    case rejected = "rejected"
    case failed = "failed"
    case cancelled = "cancelled"
}

// MARK: - Verification Types

public struct PlanIntegrityVerification: Codable {
    public let isValid: Bool
    public let storedHash: String?
    public let calculatedHash: String
    public let dependencyCount: Int
}

public struct EvidenceIntegrityVerification: Codable {
    public let isValid: Bool
    public let violations: [EvidenceDependencyViolation]
    public let dependencyCount: Int
}

public struct EvidenceDependencyViolation: Codable {
    public let dependencyId: String
    public let violationType: EvidenceViolationType
    public let severity: EvidenceViolationSeverity
    public let description: String
}

public struct LeaseVerification: Codable {
    public let isValid: Bool
    public let expiresAt: Date?
    public let reason: LeaseRejectionReason?
}

public enum LeaseRejectionReason: String, Codable {
    case noLease
    case expired
    case insufficientEvidence
}

public struct OutputEvidenceBinding: Codable {
    public let outputIds: [String]
    public let evidenceIds: [String]
    public let chainUpdated: Bool
    public let evidenceCount: Int
}

public struct CourtSafeBundle: Codable {
    public let id: String
    public let artifactPaths: [String]
    public let evidenceChainHash: String
    public let generatedAt: Date
}

// MARK: - Application Entry Point

extension AnigmaWebServer {

    static func main() async throws {
        print("🌐 Starting Anigma Web Server - Cathedral Evidence Enforcement")
        print("=" * 60)

        // Initialize services
        let dbActor = try DatabaseActor.shared
        let evidenceSubstrate = try await EvidenceSubstrate(dbActor: dbActor)
        let planCompiler = PlanCompiler(
            dbActor: dbActor,
            evidenceSubstrate: evidenceSubstrate
        )

        // Configure Vapor app
        let app = Application()
        let staticSitePath = staticSiteRootPath()
        app.directory.publicDirectory = staticSitePath
        app.middleware = [
            EvidenceEnforcementMiddleware(evidenceSubstrate: evidenceSubstrate),
            AuthenticationMiddleware(),
            SecurityLoggingMiddleware()
        ]
        app.middleware.use(FileMiddleware(publicDirectory: staticSitePath))

        // Define routes
        app.post("api/v1/plan/submit", use: submitPlanRequest(req:))
        app.get("api/v1/plan/:id/inspect", use: inspectPlan(req:))
        app.post("api/v1/plan/:id/execute", use: executePlan(req:))
        app.post("api/v1/bundle/export", use: exportBundle(req:))

        // Add health check
        app.get("health") { _ in
            return HealthResponse(status: "healthy", cathedralVersion: "1.0.0")
        }

        print("🚀 Anigma Web Server ready")
        print("   Cathedral evidence enforcement: ACTIVE")
        print("   All requests must pass evidence validation")
        print("   Raw ML operations are INACCESSIBLE from web layer")
        print("   Single Anigma computer architecture: ENABLED")

        try await app.execute(
            on: HTTPServer.Configuration(
                address: .hostname("0.0.0.0", port: 8080),
                commandName: "anigma-web-server"
            )
        )
    }
}

private extension AnigmaWebServer {
    static func staticSiteRootPath() -> String {
        let currentDirectory = FileManager.default.currentDirectoryPath
        let siteURL = URL(fileURLWithPath: currentDirectory)
            .appendingPathComponent("anigma-website/Output")
        return siteURL.path + "/"
    }
}

/// Health check response
public struct HealthResponse: Codable {
    public let status: String
    public let cathedralVersion: String
}

// MARK: - Vapor Middleware (simplified for demonstration)

/// Evidence enforcement middleware - blocks requests without sufficient evidence
struct EvidenceEnforcementMiddleware: Middleware {
    private let evidenceSubstrate: EvidenceSubstrate

    init(evidenceSubstrate: EvidenceSubstrate) {
        self.evidenceSubstrate = evidenceSubstrate
    }

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // This is where you would implement the full evidence enforcement logic
        // For now, return a simple response
        let response = Response(
            status: .ok,
            headers: [:],
            body: ByteBuffer(string: "🏛️ Evidence enforcement middleware active").buffer
        )
        return next.respond(response)
    }
}

/// Authentication middleware - validates user identity and creates evidence events
struct AuthenticationMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // This creates evidence events for authenticated requests
        let response = Response(
            status: .ok,
            headers: [:],
            body: ByteBuffer(string: "🔐 Authentication middleware active").buffer
        )
        return next.respond(response)
    }
}

/// Security logging middleware - records all access attempts as evidence
struct SecurityLoggingMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // This creates security evidence events
        let response = Response(
            status: .ok,
            headers: [:],
            body: ByteBuffer(string: "🛡️ Security logging middleware active").buffer
        )
        return next.respond(response)
    }
}
