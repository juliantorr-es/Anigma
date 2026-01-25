//
//  TestProjectExecutionSurface.swift
//  HarmoniaModule
//
//  Test implementations of ProjectExecutionSurface for unit testing.
//

@preconcurrency import Foundation
import AnigmaPrimitives

/// Fake implementation of ProjectExecutionSurface for unit tests.
public final class FakeProjectSurface: @unchecked Sendable, ProjectExecutionSurface {
    public let projectId: UUID

    public var runSessionCalls: [SessionIntent] = []
    public var runSessionResult: SessionReport
    public var getStatusResult: ProjectStatusSummary
    public var getGovernanceStatusResult: GovernanceStatus
    public var listRecentSessionsResult: [SessionReport]
    public var acknowledgeSessionCalls: [Int] = []
    public var getBanditReportResult: String

    public init(
        projectId: UUID = UUID(),
        runSessionResult: SessionReport = SessionReport(
            sessionIndex: 1,
            projectId: UUID(),
            metrics: BehavioralHealthMetrics(
                sessionIndex: 1,
                projectId: UUID(),
                featureId: nil,
                analysisRatio: 0.5,
                firstEditLatency: 3,
                toolDiversity: 2,
                editCalls: 5,
                analysisCalls: 10,
                testCalls: 2,
                filesChanged: nil,
                linesChanged: nil,
                testsPassed: nil,
                testsFailed: nil,
                formatterSucceeded: nil,
                formatterWarnings: nil,
                formatterErrors: nil,
                gitDiffSummary: nil,
                lintSucceeded: nil,
                lintWarnings: nil,
                lintErrors: nil
            ),
            violations: [],
            toolSummary: [:],
            narrative: "Test session",
            recommendations: [],
            verdict: "Healthy",
            generatedAt: Date(),
            configId: "test_config",
            featureCategory: "test"
        ),
        getStatusResult: ProjectStatusSummary = ProjectStatusSummary(
            projectId: UUID(),
            name: "Test Project",
            healthRate: 0.9,
            totalSessions: 10,
            healthySessions: 9,
            banditSummary: BanditStatsSummary(
                categoryStats: [:]
            ),
            unacknowledgedIssueCount: 0
        ),
        getGovernanceStatusResult: GovernanceStatus = GovernanceStatus(
            projectId: UUID(),
            projectName: "Test Project",
            isQuarantined: false,
            quarantineStatus: nil,
            governanceSummary: nil,
            recentSessionCount: 0,
            lastSessionIndex: nil
        ),
        listRecentSessionsResult: [SessionReport] = [],
        getBanditReportResult: String = "Test bandit report"
    ) {
        self.projectId = projectId
        self.runSessionResult = runSessionResult
        self.getStatusResult = getStatusResult
        self.getGovernanceStatusResult = getGovernanceStatusResult
        self.listRecentSessionsResult = listRecentSessionsResult
        self.getBanditReportResult = getBanditReportResult
    }

    public func runSession(
        featureCategory: String,
        explicitConfigId: String?,
        trustTier: TrustTier,
        intent: SessionIntent?
    ) async throws -> SessionReport {
        let actualIntent = intent ?? SessionIntent(
            projectId: projectId,
            featureCategory: featureCategory,
            requestedConfigId: explicitConfigId,
            trustTier: trustTier.sessionTrustTier,
            metadata: [:]
        )
        runSessionCalls.append(actualIntent)
        return runSessionResult
    }

    public func getStatus() async throws -> ProjectStatusSummary {
        return getStatusResult
    }

    public func getGovernanceStatus() async throws -> GovernanceStatus {
        return getGovernanceStatusResult
    }

    public func listRecentSessions(limit: Int) async throws -> [SessionReport] {
        return Array(listRecentSessionsResult.prefix(limit))
    }

    public func acknowledgeSession(sessionIndex: Int) async throws {
        acknowledgeSessionCalls.append(sessionIndex)
    }

    public func getBanditReport() async throws -> String {
        return getBanditReportResult
    }

    public func getSessionReports(projectId: UUID, limit: Int) async throws -> [SessionReport] {
        return Array(listRecentSessionsResult.prefix(limit))
    }

    public func recentSessionsStream(limit: Int) -> AsyncThrowingStream<SessionReport, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                for session in listRecentSessionsResult.prefix(limit) {
                    continuation.yield(session)
                }
                continuation.finish()
            }
        }
    }

    public func canListSessions() async throws -> Bool {
        true
    }
}

/// In-memory implementation of ProjectExecutionSurface for integration tests.
public actor InMemoryProjectSurface: ProjectExecutionSurface {
    public let projectId: UUID
    private var sessions: [SessionReport] = []
    private var acknowledgedSessions: Set<Int> = []
    private var projectStatus: ProjectStatusSummary
    private var governanceStatus: GovernanceStatus

    public init(
        projectId: UUID = UUID(),
        initialStatus: ProjectStatusSummary = ProjectStatusSummary(
            projectId: UUID(),
            name: "In Memory Project",
            healthRate: 1.0,
            totalSessions: 0,
            healthySessions: 0,
            banditSummary: BanditStatsSummary(
                categoryStats: [:]
            ),
            unacknowledgedIssueCount: 0
        ),
        initialGovernanceStatus: GovernanceStatus = GovernanceStatus(
            projectId: UUID(),
            projectName: "In Memory Project",
            isQuarantined: false,
            quarantineStatus: nil,
            governanceSummary: nil,
            recentSessionCount: 0,
            lastSessionIndex: nil
        )
    ) {
        self.projectId = projectId
        self.projectStatus = initialStatus
        self.governanceStatus = initialGovernanceStatus
    }

    public nonisolated func runSession(
        featureCategory: String,
        explicitConfigId: String?,
        trustTier: TrustTier,
        intent: SessionIntent?
    ) async throws -> SessionReport {
        try await runSessionImpl(
            featureCategory: featureCategory,
            explicitConfigId: explicitConfigId,
            trustTier: trustTier,
            intent: intent
        )
    }

    private func runSessionImpl(
        featureCategory: String,
        explicitConfigId: String?,
        trustTier: TrustTier,
        intent: SessionIntent?
    ) async throws -> SessionReport {
        let sessionIndex = sessions.count + 1
        let session = SessionReport(
            sessionIndex: sessionIndex,
            projectId: projectId,
            metrics: BehavioralHealthMetrics(
                sessionIndex: sessionIndex,
                projectId: projectId,
                featureId: nil,
                analysisRatio: 0.5,
                firstEditLatency: 3,
                toolDiversity: 2,
                editCalls: 5,
                analysisCalls: 10,
                testCalls: 2,
                filesChanged: nil,
                linesChanged: nil,
                testsPassed: nil,
                testsFailed: nil,
                formatterSucceeded: nil,
                formatterWarnings: nil,
                formatterErrors: nil,
                gitDiffSummary: nil,
                lintSucceeded: nil,
                lintWarnings: nil,
                lintErrors: nil
            ),
            violations: [],
            toolSummary: [:],
            narrative: "Test session \(sessionIndex)",
            recommendations: [],
            verdict: "Healthy",
            generatedAt: Date(),
            configId: explicitConfigId ?? "default_config",
            featureCategory: featureCategory
        )

        sessions.append(session)

        projectStatus = ProjectStatusSummary(
            projectId: projectId,
            name: projectStatus.name,
            healthRate: Double(sessions.count) / Double(sessions.count + 1),
            totalSessions: sessions.count,
            healthySessions: sessions.count,
            banditSummary: projectStatus.banditSummary,
            unacknowledgedIssueCount: projectStatus.unacknowledgedIssueCount
        )

        return session
    }

    public nonisolated func getStatus() async throws -> ProjectStatusSummary {
        await getStatusImpl()
    }

    private func getStatusImpl() async -> ProjectStatusSummary {
        projectStatus
    }

    public nonisolated func getGovernanceStatus() async throws -> GovernanceStatus {
        await getGovernanceStatusImpl()
    }

    private func getGovernanceStatusImpl() async -> GovernanceStatus {
        governanceStatus
    }

    public nonisolated func listRecentSessions(limit: Int) async throws -> [SessionReport] {
        await listRecentSessionsImpl(limit: limit)
    }

    private func listRecentSessionsImpl(limit: Int) async -> [SessionReport] {
        Array(sessions.suffix(limit))
    }

    public nonisolated func acknowledgeSession(sessionIndex: Int) async throws {
        await acknowledgeSessionImpl(sessionIndex: sessionIndex)
    }

    private func acknowledgeSessionImpl(sessionIndex: Int) async {
        acknowledgedSessions.insert(sessionIndex)
    }

    public nonisolated func getBanditReport() async throws -> String {
        await getBanditReportImpl()
    }

    private func getBanditReportImpl() async -> String {
        """
        Bandit Report for Project \(projectId.uuidString.prefix(8))
        Total sessions: \(sessions.count)
        Acknowledged sessions: \(acknowledgedSessions.count)
        Average health score: \(String(format: "%.1f%%", projectStatus.healthRate * 100))
        """
    }

    public nonisolated func getSessionReports(projectId: UUID, limit: Int) async throws -> [SessionReport] {
        await getSessionReportsImpl(limit: limit)
    }

    private func getSessionReportsImpl(limit: Int) async -> [SessionReport] {
        Array(sessions.suffix(limit))
    }

    public nonisolated func recentSessionsStream(limit: Int) -> AsyncThrowingStream<SessionReport, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                let snapshot = await listRecentSessionsImpl(limit: limit)
                for session in snapshot {
                    continuation.yield(session)
                }
                continuation.finish()
            }
        }
    }

    public nonisolated func canListSessions() async throws -> Bool {
        true
    }

    // Test helper methods
    public func setProjectStatus(_ status: ProjectStatusSummary) {
        self.projectStatus = status
    }

    public func setGovernanceStatus(_ status: GovernanceStatus) {
        self.governanceStatus = status
    }

    public func getSessionCount() -> Int {
        return sessions.count
    }

    public func getAcknowledgedSessions() -> Set<Int> {
        return acknowledgedSessions
    }
}
