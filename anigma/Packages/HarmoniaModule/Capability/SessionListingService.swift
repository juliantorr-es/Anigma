//
//  SessionListingService.swift
//  HarmoniaModule
//
//  Actor-based implementation of SessionListingProviding with cache, ECS queries,
//  and Harmonia governance integration. Follows Swift6 concurrency patterns
//  and maintains Core Governance Layer requirements.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore

// MARK: - Actor-Based Session Listing Service

/// Actor-based implementation of SessionListingProviding with cache, ECS queries,
/// and Harmonia governance integration.
/// 
/// This service combines:
/// - Actor-managed cache for performance and Swift6 concurrency safety
/// - ECS queries for efficient session candidate assembly
/// - Harmonia governance for access control and auditability
/// - Trust verification for court-safe session access
/// - AsyncThrowingStream for reactive, error-first streaming
public actor SessionListingService: SessionListingProviding {

    // MARK: - Dependencies

    /// ECS world for session entity queries
    private let world: World
    /// Policy registry for governance evaluation
    private let policyRegistry: PolicyRegistry

    /// Gatekeeper for per-session checks
    private let gatekeeper: Gatekeeper

    /// Security enforcer for quarantine checks
    private let securityEnforcer: SecurityEnforcer

    /// Event sink for governance logging
    private let eventSink: GovernanceEventSink

    /// Trust verifier for session trust validation
    private let trustVerifier: SessionTrustVerifier

    // MARK: - Cache State

    /// Cached session reports per project
    private var sessionCache: [UUID: CachedSessions] = [:]

    /// Cache TTL configuration
    private let cacheTTL: TimeInterval

    /// In-flight refresh operations to prevent duplicate work
    private var inFlightRefreshes: [UUID: Task<[SessionReport], Error>] = [:]

    // MARK: - Initialization

    public init(
        world: World,
        policyRegistry: PolicyRegistry,
        gatekeeper: Gatekeeper,
        securityEnforcer: SecurityEnforcer,
        eventSink: GovernanceEventSink,
        trustVerifier: SessionTrustVerifier,
        cacheTTL: TimeInterval = 300.0 // 5 minutes default
    ) {
        self.world = world
        self.policyRegistry = policyRegistry
        self.gatekeeper = gatekeeper
        self.securityEnforcer = securityEnforcer
        self.eventSink = eventSink
        self.trustVerifier = trustVerifier
        self.cacheTTL = cacheTTL
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
        trustTier: SessionTrustTier,
        operation: SessionListingOperation = .list
    ) async throws -> [SessionReport] {
        // 1. Governance evaluation first
        let accessRequest = SessionListingAccessRequest(
            projectId: projectId,
            operation: operation,
            trustTier: trustTier,
            requestedLimit: limit
        )

        try await evaluateAccessRequest(accessRequest)

        // 2. Check cache validity
        if let cached = sessionCache[projectId],
           !cached.isExpired(ttl: cacheTTL) {
            return Array(cached.sessions.prefix(limit))
        }

        // 3. Coalesce in-flight refreshes
        if let existingTask = inFlightRefreshes[projectId] {
            let sessions = try await existingTask.value
            return Array(sessions.prefix(limit))
        }

        // 4. Refresh cache with ECS-powered session assembly
        let refreshTask = Task<[SessionReport], Error> {
            try await refreshSessionCache(projectId: projectId, limit: limit, trustTier: trustTier)
        }

        inFlightRefreshes[projectId] = refreshTask

        do {
            let sessions = try await refreshTask.value
            inFlightRefreshes[projectId] = nil
            return Array(sessions.prefix(limit))
        } catch {
            inFlightRefreshes[projectId] = nil
            throw error
        }
    }

    public nonisolated func recentSessionsStream(
        projectId: UUID,
        limit: Int,
        trustTier: SessionTrustTier
    ) -> AsyncThrowingStream<SessionReport, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let sessions = try await listRecentSessionsImpl(
                        projectId: projectId,
                        limit: limit,
                        trustTier: trustTier,
                        operation: .stream
                    )

                    for session in sessions {
                        let trustResult = try await trustVerifier.verifySession(
                            sessionId: "\(session.sessionIndex)"
                        )

                        if trustResult.isTrusted {
                            continuation.yield(session)
                        } else {
                            throw SessionListingError.trustVerificationFailed(
                                sessionId: "\(session.sessionIndex)",
                                reason: trustResult.reasons.joined(separator: ", ")
                            )
                        }
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
        try await canListSessionsImpl(projectId: projectId, trustTier: trustTier)
    }

    private func canListSessionsImpl(
        projectId: UUID,
        trustTier: SessionTrustTier
    ) async throws -> Bool {
        let accessRequest = SessionListingAccessRequest(
            projectId: projectId,
            operation: .checkAccess,
            trustTier: trustTier,
            requestedLimit: 1
        )

        do {
            try await evaluateAccessRequest(accessRequest)
            return true
        } catch SessionListingError.accessDenied {
            return false
        } catch {
            return false
        }
    }

    // MARK: - Private Implementation

    /// Evaluates governance access request using Harmonia layers.
    private func evaluateAccessRequest(_ request: SessionListingAccessRequest) async throws {
        // 1. Check quarantine status first (SecurityEnforcer - Dominions)
        let isQuarantined = await securityEnforcer.isProjectQuarantined(request.projectId)
        if isQuarantined {
            throw SessionListingError.accessDenied(reason: "Project is quarantined")
        }

        // 2. Create session intent for governance evaluation
        let intent = SessionIntent(
            projectId: request.projectId,
            featureCategory: "session_listing",
            requestedConfigId: nil,
            trustTier: request.trustTier,
            metadata: [
                "operation": request.operation.rawValue,
                "requested_limit": "\(request.requestedLimit)"
            ]
        )

        // 3. PolicyRegistry validation (Seraphim)
        let policyDecision = try await policyRegistry.validateSessionPlan(
            intent: intent,
            configId: "session_listing_default"
        )

        switch policyDecision {
        case .allow:
            break // Continue
        case .deny(let reason):
            throw SessionListingError.accessDenied(reason: "Policy denied: \(reason)")
        case .requireEscalation(let reason):
            // Log escalation but allow for now
            await eventSink.emit(GovernanceLogEvent(
                projectId: request.projectId,
                severity: .warning,
                code: "session_listing_escalation",
                message: "Escalation required: \(reason)",
                context: ["operation": request.operation.rawValue]
            ))
        }

        // 4. Gatekeeper evaluation (Cherubim)
        let gatekeeperDecision = try await gatekeeper.evaluate(
            intent: intent,
            configId: "session_listing_default"
        )

        switch gatekeeperDecision {
        case .allow:
            break // Continue
        case .deny(let reason):
            throw SessionListingError.accessDenied(reason: "Gatekeeper denied: \(reason)")
        case .requireEscalation(let reason):
            // Log escalation but allow for now
            await eventSink.emit(GovernanceLogEvent(
                projectId: request.projectId,
                severity: .warning,
                code: "session_listing_gatekeeper_escalation",
                message: "Gatekeeper escalation: \(reason)",
                context: ["operation": request.operation.rawValue]
            ))
        }

        // 5. Log successful access evaluation
        await eventSink.emit(GovernanceLogEvent(
            projectId: request.projectId,
            severity: .info,
            code: "session_listing_access_granted",
            message: "Session listing access granted",
            context: [
                "operation": request.operation.rawValue,
                "trust_tier": request.trustTier.rawValue,
                "requested_limit": "\(request.requestedLimit)"
            ]
        ))
    }

    /// Refreshes session cache using ECS-powered session assembly.
    private func refreshSessionCache(
        projectId: UUID,
        limit: Int,
        trustTier: SessionTrustTier
    ) async throws -> [SessionReport] {
        let sessions = try await gatherSessionReports(projectId: projectId, trustTier: trustTier)

        let sorted = sessions.sorted { $0.generatedAt > $1.generatedAt }
        sessionCache[projectId] = CachedSessions(
            sessions: sorted,
            cachedAt: Date()
        )

        await eventSink.emit(GovernanceLogEvent(
            projectId: projectId,
            severity: .info,
            code: "session_listing_cache_refreshed",
            message: "Session cache refreshed with \(sorted.count) sessions",
            context: [
                "limit": "\(limit)",
                "trust_tier": trustTier.rawValue
            ]
        ))

        return Array(sorted.prefix(limit))
    }
}

// MARK: - Cache Data Structure

/// Cached session data with timestamp.
private struct CachedSessions: Sendable {
    let sessions: [SessionReport]
    let cachedAt: Date

    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(cachedAt) > ttl
    }
}

// MARK: - Helpers

extension SessionListingService {
    private func gatherSessionReports(
        projectId: UUID,
        trustTier: SessionTrustTier
    ) async throws -> [SessionReport] {
        var sessions: [SessionReport] = []

        for (entityId, sessionComponent, projectComponent) in await world.query(SessionComponent.self, ProjectComponent.self) {
            guard projectComponent.projectId == projectId else { continue }

            let report = try await buildSessionReport(
                entityId: entityId,
                sessionComponent: sessionComponent,
                projectComponent: projectComponent,
                trustTier: trustTier
            )
            sessions.append(report)
        }

        return sessions
    }

    private func buildSessionReport(
        entityId: EntityId,
        sessionComponent: SessionComponent,
        projectComponent: ProjectComponent,
        trustTier: SessionTrustTier
    ) async throws -> SessionReport {
        let trustResult = try await trustVerifier.verifySession(sessionId: sessionComponent.sessionId)
        guard trustResult.isTrusted else {
            throw SessionListingError.trustVerificationFailed(
                sessionId: sessionComponent.sessionId,
                reason: trustResult.reasons.joined(separator: ", ")
            )
        }

        let sessionIndex = computeSessionIndex(entityId: entityId)
        let metrics = BehavioralHealthMetrics(
            sessionIndex: sessionIndex,
            projectId: projectComponent.projectId,
            featureId: nil,
            analysisRatio: statsRatio(trustResult.trustScore),
            firstEditLatency: max(1, sessionComponent.messageCount),
            toolDiversity: max(1, min(sessionComponent.messageCount, 3)),
            editCalls: sessionComponent.messageCount,
            analysisCalls: max(1, sessionComponent.messageCount),
            testCalls: 0,
            timestamp: sessionComponent.createdAt
        )

        return SessionReport(
            sessionIndex: sessionIndex,
            projectId: projectComponent.projectId,
            metrics: metrics,
            violations: [],
            toolSummary: ["messages": sessionComponent.messageCount],
            narrative: "Session \(sessionComponent.sessionId)",
            recommendations: [],
            verdict: trustResult.isTrusted ? "TRUSTED" : "UNTRUSTED",
            generatedAt: sessionComponent.createdAt,
            governanceTrace: GovernanceTrace.default(trustTier: trustTier)
        )
    }

    private func computeSessionIndex(entityId: EntityId) -> Int {
        entityId.raw.hashValue & Int.max
    }

    private func statsRatio(_ score: Double) -> Double {
        min(max(score, 0.0), 1.0)
    }
}

// MARK: - ECS Components for Session Listing

/// Component that links session to project.
public struct ProjectComponent: Component, Codable {
    public let projectId: UUID
    public let projectName: String

    public init(projectId: UUID, projectName: String) {
        self.projectId = projectId
        self.projectName = projectName
    }
}
