//
//  ProjectExecutionSurface.swift
//  HarmoniaModule
//
//  Minimal interface for systems that need to execute harness work.
//  Workers talk to this, not to GRDB or bandit directly.
//

import Foundation
import ContractsCore
import AnigmaPrimitives

/// Minimal interface for systems that need to execute harness work.
/// Workers talk to this, not to GRDB or bandit directly.
public protocol ProjectExecutionSurface: Sendable {
    /// Project identifier.
    var projectId: UUID { get }

    /// Run a harness session for a feature category.
    /// - Parameters:
    ///   - featureCategory: Feature category (e.g., "ui", "backend", "maker")
    ///   - explicitConfigId: Optional config ID to use instead of bandit selection
    ///   - trustTier: Trust tier for this execution
    ///   - intent: Optional session intent (auto-created if nil)
    /// - Returns: Session report
    func runSession(
        featureCategory: String,
        explicitConfigId: String?,
        trustTier: TrustTier,
        intent: SessionIntent?
    ) async throws -> SessionReport

    /// Run MAKER step execution session
    /// - Parameters:
    ///   - stepId: Unique identifier for the step to execute
    ///   - context: Step execution context (state, candidates, etc.)
    ///   - trustTier: Trust tier for this execution
    ///   - Returns: Session report with MAKER-specific results
    func runMakerStep(
        stepId: String,
        context: MakerStepContext,
        trustTier: TrustTier
    ) async throws -> SessionReport

    /// Get project status summary.
    func getStatus() async throws -> ProjectStatusSummary

    /// Get governance status.
    func getGovernanceStatus() async throws -> GovernanceStatus

    /// List recent sessions.
    /// - Parameter limit: Maximum number of sessions to return
    /// - Returns: Array of session reports
    func listRecentSessions(limit: Int) async throws -> [SessionReport]

    /// Get session reports for this project.
    /// - Parameter projectId: Project identifier
    /// - Parameter limit: Maximum number of sessions to return
    /// - Returns: Array of session reports
    func getSessionReports(projectId: UUID, limit: Int) async throws -> [SessionReport]

    /// Acknowledge a session (mark as reviewed).
    /// - Parameter sessionIndex: Session index to acknowledge
    func acknowledgeSession(sessionIndex: Int) async throws

    /// Get bandit performance report.
    func getBanditReport() async throws -> String

    /// Streams recent sessions with reactive, error-first interface.
    /// - Parameter limit: Maximum number of sessions to stream
    /// - Returns: AsyncThrowingStream that yields sessions or throws errors
    func recentSessionsStream(limit: Int) -> AsyncThrowingStream<SessionReport, any Error>

    /// Checks if caller has permission to list sessions.
    /// - Returns: True if access is allowed, false otherwise
    func canListSessions() async throws -> Bool
}

/// Context for MAKER step execution.
public struct MakerStepContext: Sendable, Codable {
    public let stepId: String
    public let stateSlice: ContractsCore.StateSlice
    public let candidates: [ContractsCore.StepCandidate]
    public let policyContext: [String: String]
    public let metadata: [String: String]

    public init(
        stepId: String,
        stateSlice: ContractsCore.StateSlice,
        candidates: [ContractsCore.StepCandidate] = [],
        policyContext: [String: String] = [:],
        metadata: [String: String] = [:]
    ) {
        self.stepId = stepId
        self.stateSlice = stateSlice
        self.candidates = candidates
        self.policyContext = policyContext
        self.metadata = metadata
    }
}

// MARK: - Convenience Extensions

extension ProjectExecutionSurface {
    /// Run a harness session with default trust tier (.trusted).
    public func runSession(
        featureCategory: String,
        explicitConfigId: String? = nil
    ) async throws -> SessionReport {
        try await runSession(
            featureCategory: featureCategory,
            explicitConfigId: explicitConfigId,
            trustTier: .trusted,
            intent: nil
        )
    }

    /// Run MAKER step execution session
    /// - Parameters:
    ///   - stepId: Unique identifier for the step to execute
    ///   - context: Step execution context (state, candidates, etc.)
    ///   - trustTier: Trust tier for this execution
    ///   - Returns: Session report with MAKER-specific results
    public func runMakerStep(
        stepId: String,
        context: MakerStepContext,
        trustTier: TrustTier
    ) async throws -> SessionReport {
        // Create session intent for MAKER operations
        let intent = SessionIntent(
            projectId: projectId,
            featureCategory: "maker",
            requestedConfigId: nil,
            trustTier: trustTier.sessionTrustTier,
            metadata: ["stepId": stepId, "description": "Execute MAKER step: \(stepId)"]
        )

        // Run session with MAKER feature category
        let sessionReport = try await runSession(
            featureCategory: "maker",
            explicitConfigId: nil,
            trustTier: trustTier,
            intent: intent
        )

        // Integrate with MAKER engine
        _ = try await MakerHarmoniaIntegration.executeStep(
            stepId: stepId,
            stateSlice: context.stateSlice,
            candidates: context.candidates,
            trustTier: trustTier
        )

        // Return the existing session report with MAKER integration
        return sessionReport
    }

}

// MARK: - PrincipalityProjectController Conformance

extension PrincipalityProjectController: ProjectExecutionSurface {}
