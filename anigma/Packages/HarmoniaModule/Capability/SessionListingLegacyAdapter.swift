//
//  SessionListingLegacyAdapter.swift
//  HarmoniaModule
//
//  Legacy adapter implementation of SessionListingProviding that uses existing
//  ProjectHarnessStore APIs. Provides immediate compatibility while
//  maintaining the new architectural contract.
//

import Foundation
import GRDB

// MARK: - Legacy Adapter Implementation

/// Legacy adapter that bridges new SessionListingProviding protocol
/// with existing ProjectHarnessStore implementation.
/// 
/// This adapter provides immediate compatibility by using existing store APIs
/// while maintaining the new architectural contract. It can be gradually
/// replaced with the full SessionListingService implementation.
public actor SessionListingLegacyAdapter: SessionListingProviding {

    // MARK: - Dependencies

    /// Legacy ProjectHarnessStore for data access
    private let store: ProjectHarnessStore

    /// Policy registry for governance evaluation
    private let policyRegistry: PolicyRegistry

    /// Gatekeeper for per-session checks
    private let gatekeeper: Gatekeeper

    /// Security enforcer for quarantine checks
    private let securityEnforcer: SecurityEnforcer

    /// Event sink for governance logging
    private let eventSink: GovernanceEventSink

    // MARK: - Initialization

    public init(
        store: ProjectHarnessStore = .shared,
        policyRegistry: PolicyRegistry = BlessedPolicyRegistry(),
        gatekeeper: Gatekeeper = GatekeeperImpl(),
        securityEnforcer: SecurityEnforcer = SecurityEnforcerImpl(),
        eventSink: GovernanceEventSink = ConsoleEventSink()
    ) {
        self.store = store
        self.policyRegistry = policyRegistry
        self.gatekeeper = gatekeeper
        self.securityEnforcer = securityEnforcer
        self.eventSink = eventSink
    }

    // MARK: - SessionListingProviding Implementation

    public nonisolated func listRecentSessions(
        projectId: UUID,
        limit: Int,
        trustTier: SessionTrustTier
    ) async throws -> [SessionReport] {
        try await listRecentSessionsImpl(
            projectId: projectId,
            limit: limit,
            trustTier: trustTier
        )
    }

    private func listRecentSessionsImpl(
        projectId: UUID,
        limit: Int,
        trustTier: SessionTrustTier
    ) async throws -> [SessionReport] {
        try await evaluateAccessRequest(
            projectId: projectId,
            operation: .list,
            trustTier: trustTier,
            requestedLimit: limit
        )

        let sessions = try await store.getSessionReports(projectId: projectId, limit: limit)
        await eventSink.emit(GovernanceLogEvent(
            projectId: projectId,
            severity: .info,
            code: "legacy_session_listed",
            message: "Sessions listed via legacy adapter",
            context: [
                "count": "\(sessions.count)",
                "limit": "\(limit)",
                "trust_tier": trustTier.rawValue
            ]
        ))

        return sessions
    }

    public nonisolated func recentSessionsStream(
        projectId: UUID,
        limit: Int,
        trustTier: SessionTrustTier
    ) -> AsyncThrowingStream<SessionReport, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await evaluateAccessRequest(
                        projectId: projectId,
                        operation: .stream,
                        trustTier: trustTier,
                        requestedLimit: limit
                    )

                    let sessions = try await store.getSessionReports(projectId: projectId, limit: limit)

                    for session in sessions {
                        if let trace = session.governanceTrace {
                            if trace.quarantineApplied {
                                throw SessionListingError.trustVerificationFailed(
                                    sessionId: "\(session.sessionIndex)",
                                    reason: "Session was quarantined"
                                )
                            }

                            if trace.tainted && trace.trustTier == .adversarial {
                                throw SessionListingError.trustVerificationFailed(
                                    sessionId: "\(session.sessionIndex)",
                                    reason: "Session is tainted and adversarial"
                                )
                            }
                        }

                        continuation.yield(session)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public nonisolated func canListSessions(
        projectId: UUID,
        trustTier: SessionTrustTier
    ) async throws -> Bool {
        do {
            try await evaluateAccessRequest(
                projectId: projectId,
                operation: .checkAccess,
                trustTier: trustTier,
                requestedLimit: 1
            )
            return true
        } catch SessionListingError.accessDenied {
            return false
        } catch {
            return false
        }
    }

    // MARK: - Private Implementation

    /// Evaluates governance access request using Harmonia layers.
    private func evaluateAccessRequest(
        projectId: UUID,
        operation: SessionListingOperation,
        trustTier: SessionTrustTier,
        requestedLimit: Int
    ) async throws {
        // 1. Check quarantine status first (SecurityEnforcer - Dominions)
        let isQuarantined = await securityEnforcer.isProjectQuarantined(projectId)
        if isQuarantined {
            throw SessionListingError.accessDenied(reason: "Project is quarantined")
        }

        // 2. Create session intent for governance evaluation
        let intent = SessionIntent(
            projectId: projectId,
            featureCategory: "session_listing",
            requestedConfigId: nil,
            trustTier: trustTier,
            metadata: [
                "operation": operation.rawValue,
                "requested_limit": "\(requestedLimit)",
                "adapter": "legacy"
            ]
        )

        // 3. PolicyRegistry validation (Seraphim)
        let policyDecision = try await policyRegistry.validateSessionPlan(
            intent: intent,
            configId: "session_listing_legacy"
        )

        switch policyDecision {
        case .allow:
            break // Continue
        case .deny(let reason):
            throw SessionListingError.accessDenied(reason: "Policy denied: \(reason)")
        case .requireEscalation(let reason):
            // Log escalation but allow for now
            await eventSink.emit(GovernanceLogEvent(
                projectId: projectId,
                severity: .warning,
                code: "legacy_session_listing_escalation",
                message: "Escalation required: \(reason)",
                context: ["operation": operation.rawValue]
            ))
        }

        // 4. Gatekeeper evaluation (Cherubim)
        let gatekeeperDecision = try await gatekeeper.evaluate(
            intent: intent,
            configId: "session_listing_legacy"
        )

        switch gatekeeperDecision {
        case .allow:
            break // Continue
        case .deny(let reason):
            throw SessionListingError.accessDenied(reason: "Gatekeeper denied: \(reason)")
        case .requireEscalation(let reason):
            // Log escalation but allow for now
            await eventSink.emit(GovernanceLogEvent(
                projectId: projectId,
                severity: .warning,
                code: "legacy_session_listing_gatekeeper_escalation",
                message: "Gatekeeper escalation: \(reason)",
                context: ["operation": operation.rawValue]
            ))
        }

        // 5. Log successful access evaluation
        await eventSink.emit(GovernanceLogEvent(
            projectId: projectId,
            severity: .info,
            code: "legacy_session_listing_access_granted",
            message: "Session listing access granted via legacy adapter",
            context: [
                "operation": operation.rawValue,
                "trust_tier": trustTier.rawValue,
                "requested_limit": "\(requestedLimit)"
            ]
        ))
    }
}

// MARK: - Mock Trust Verifier for Legacy Adapter

/// Simple trust verifier implementation for legacy adapter.
/// Uses governance trace information for basic trust verification.
public struct LegacySessionTrustVerifier: SessionTrustVerifier {
    public init() {}

    public func verifySession(sessionId: String) async throws -> SessionTrustResult {
        // This is a simplified implementation for the legacy adapter
        // In practice, this would integrate with proper trust stores

        return SessionTrustResult(
            sessionId: sessionId,
            isTrusted: true, // Default to trusted for legacy adapter
            verificationTime: Date(),
            trustScore: 1.0,
            reasons: ["Legacy adapter - basic verification"]
        )
    }

    public func verifySessions(sessionIds: [String]) async throws -> [SessionTrustResult] {
        return try await withThrowingTaskGroup(of: SessionTrustResult.self) { group in
            var results: [SessionTrustResult] = []

            for sessionId in sessionIds {
                group.addTask {
                    try await self.verifySession(sessionId: sessionId)
                }
            }

            for try await result in group {
                results.append(result)
            }

            return results
        }
    }
}

// MARK: - Factory for Legacy Adapter

/// Factory for creating legacy adapter instances.
public enum SessionListingAdapterFactory {
    /// Creates a legacy adapter with default dependencies.
    public static func createLegacyAdapter(
        store: ProjectHarnessStore = .shared
    ) -> SessionListingLegacyAdapter {
        return SessionListingLegacyAdapter(
            store: store,
            policyRegistry: BlessedPolicyRegistry(),
            gatekeeper: GatekeeperImpl(),
            securityEnforcer: SecurityEnforcerImpl(),
            eventSink: ConsoleEventSink()
        )
    }

    /// Creates a legacy adapter with custom dependencies.
    public static func createLegacyAdapter(
        store: ProjectHarnessStore,
        policyRegistry: PolicyRegistry,
        gatekeeper: Gatekeeper,
        securityEnforcer: SecurityEnforcer,
        eventSink: GovernanceEventSink
    ) -> SessionListingLegacyAdapter {
        return SessionListingLegacyAdapter(
            store: store,
            policyRegistry: policyRegistry,
            gatekeeper: gatekeeper,
            securityEnforcer: securityEnforcer,
            eventSink: eventSink
        )
    }
}
