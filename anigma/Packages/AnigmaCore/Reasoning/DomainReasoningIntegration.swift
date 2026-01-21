//
//  DomainReasoningIntegration.swift
//  AnigmaCore
//
//  Integrates domain-specific puzzle builders with the reasoning orchestrator.
//  Provides a unified interface for running adversarial analysis across all Anigma domains.
//

import Foundation

// MARK: - Domain Reasoning Coordinator

/// Coordinates adversarial reasoning across all Anigma domains.
public actor DomainReasoningCoordinator {
    /// The reasoning orchestrator.
    private let orchestrator: ReasoningOrchestrator

    /// The scenario library.
    private let scenarioLibrary: ScenarioLibrary

    /// The state abstractor for anonymizing data.
    private let abstractor: StateAbstractor

    /// Domain analysis results.
    private var domainResults: [String: DomainAnalysisResult] = [:]

    public init(
        orchestrator: ReasoningOrchestrator,
        scenarioLibrary: ScenarioLibrary
    ) {
        self.orchestrator = orchestrator
        self.scenarioLibrary = scenarioLibrary
        self.abstractor = StateAbstractor()
    }

    // MARK: - Identity Domain Analysis

    /// Analyzes identity and session security.
    public func analyzeIdentity(
        sessions: [(id: UUID, principalId: UUID, riskLevel: Int, mfaVerified: Bool)],
        principals: [(id: UUID, hasActiveRoles: Bool, hasSessions: Bool, hasPendingWork: Bool)],
        riskThreshold: Int = 80
    ) async throws -> DomainAnalysisResult {

        await abstractor.reset()

        // Abstract sessions
        var abstractSessions: [(symbol: String, principalSymbol: String, initialRisk: Int, mfaVerified: Bool)] = []
        for session in sessions {
            let sessionSymbol = await abstractor.anonymize(session.id, prefix: "SES")
            let principalSymbol = await abstractor.anonymize(session.principalId, prefix: "PRI")
            abstractSessions.append((sessionSymbol, principalSymbol, session.riskLevel, session.mfaVerified))
        }

        // Abstract principals
        var abstractPrincipals: [(symbol: String, hasActiveRoles: Bool, hasSessions: Bool, hasPendingWork: Bool)] = []
        for principal in principals {
            let symbol = await abstractor.anonymize(principal.id, prefix: "PRI")
            abstractPrincipals.append((symbol, principal.hasActiveRoles, principal.hasSessions, principal.hasPendingWork))
        }

        // Build puzzles
        let actions: [(name: String, riskDelta: Int, requiresMFA: Bool)] = [
            ("view_public", 5, false),
            ("view_internal", 10, false),
            ("view_restricted", 20, true),
            ("modify_data", 30, true),
            ("admin_action", 50, true)
        ]

        let sessionPuzzle = IdentityPuzzleBuilder.buildSessionRiskPuzzle(
            sessions: abstractSessions,
            actions: actions,
            riskThreshold: riskThreshold
        )

        let deprovPuzzle = IdentityPuzzleBuilder.buildDeprovisioningPuzzle(
            principals: abstractPrincipals,
            deprovisioningSteps: ["revoke_roles", "terminate_sessions", "reassign_work", "complete"]
        )

        // Run analysis
        let sessionResult = try await orchestrator.dispatch(sessionPuzzle)
        let deprovResult = try await orchestrator.dispatch(deprovPuzzle)

        // Aggregate results
        var issues: [DomainReasoningIssue] = []
        issues.append(contentsOf: convertToIssues(sessionResult, domain: "Identity"))
        issues.append(contentsOf: convertToIssues(deprovResult, domain: "Identity"))

        let result = DomainAnalysisResult(
            domain: "Identity",
            puzzlesRun: 2,
            issuesFound: issues,
            timestamp: Date(),
            metadata: [
                "session_count": String(sessions.count),
                "principal_count": String(principals.count)
            ]
        )

        domainResults["Identity"] = result

        // Store scenarios from results
        await storeScenarios(from: sessionResult, domain: .accessControl, title: "Session risk escalation")
        await storeScenarios(from: deprovResult, domain: .accessControl, title: "Deprovisioning gap")

        return result
    }

    // MARK: - Storage Domain Analysis

    /// Analyzes storage and disaster recovery.
    public func analyzeStorage(
        environments: [(id: UUID, tenantId: UUID, isProduction: Bool)],
        snapshots: [(id: UUID, environmentId: UUID, ageHours: Int, isValid: Bool)],
        rpoHours: Int = 4,
        rtoHours: Int = 8
    ) async throws -> DomainAnalysisResult {

        await abstractor.reset()

        // Abstract environments
        var abstractEnvs: [(symbol: String, tenantSymbol: String, isProduction: Bool)] = []
        for env in environments {
            let envSymbol = await abstractor.anonymize(env.id, prefix: "ENV")
            let tenantSymbol = await abstractor.anonymize(env.tenantId, prefix: "TEN")
            abstractEnvs.append((envSymbol, tenantSymbol, env.isProduction))
        }

        // Abstract snapshots
        var abstractSnapshots: [(symbol: String, envSymbol: String, ageHours: Int, isValid: Bool)] = []
        for snapshot in snapshots {
            let snapSymbol = await abstractor.anonymize(snapshot.id, prefix: "SNAP")
            let envSymbol = await abstractor.anonymize(snapshot.environmentId, prefix: "ENV")
            abstractSnapshots.append((snapSymbol, envSymbol, snapshot.ageHours, snapshot.isValid))
        }

        let puzzle = StoragePuzzleBuilder.buildDisasterRecoveryPuzzle(
            environments: abstractEnvs,
            snapshots: abstractSnapshots,
            rpoHours: rpoHours,
            rtoHours: rtoHours
        )

        let analysisResult = try await orchestrator.dispatch(puzzle)

        let result = DomainAnalysisResult(
            domain: "Storage",
            puzzlesRun: 1,
            issuesFound: convertToIssues(analysisResult, domain: "Storage"),
            timestamp: Date(),
            metadata: [
                "environment_count": String(environments.count),
                "snapshot_count": String(snapshots.count),
                "rpo_hours": String(rpoHours)
            ]
        )

        domainResults["Storage"] = result
        await storeScenarios(from: analysisResult, domain: .dataLifecycle, title: "DR violation")
        return result
    }

    // MARK: - DSPS Domain Analysis

    /// Analyzes DSPS accommodation and alt-media workflows.
    public func analyzeDSPS(
        cases: [(id: UUID, studentId: UUID, termId: UUID, hasDocumentation: Bool)],
        accommodations: [(caseId: UUID, type: String, isApproved: Bool)],
        letters: [(caseId: UUID, letterId: UUID, isDelivered: Bool)],
        altMediaRequests: [(id: UUID, caseId: UUID, format: String, priority: Int)],
        slaHours: Int = 72
    ) async throws -> DomainAnalysisResult {

        await abstractor.reset()

        // Abstract cases
        var abstractCases: [(symbol: String, studentSymbol: String, termSymbol: String, hasDocumentation: Bool)] = []
        for caseItem in cases {
            let caseSymbol = await abstractor.anonymize(caseItem.id, prefix: "CASE")
            let studentSymbol = await abstractor.anonymize(caseItem.studentId, prefix: "STU")
            let termSymbol = await abstractor.anonymize(caseItem.termId, prefix: "TERM")
            abstractCases.append((caseSymbol, studentSymbol, termSymbol, caseItem.hasDocumentation))
        }

        // Abstract accommodations
        var abstractAccommodations: [(caseSymbol: String, accommodationType: String, isApproved: Bool)] = []
        for acc in accommodations {
            let caseSymbol = await abstractor.anonymize(acc.caseId, prefix: "CASE")
            abstractAccommodations.append((caseSymbol, acc.type, acc.isApproved))
        }

        // Abstract letters
        var abstractLetters: [(caseSymbol: String, letterSymbol: String, isDelivered: Bool)] = []
        for letter in letters {
            let caseSymbol = await abstractor.anonymize(letter.caseId, prefix: "CASE")
            let letterSymbol = await abstractor.anonymize(letter.letterId, prefix: "LTR")
            abstractLetters.append((caseSymbol, letterSymbol, letter.isDelivered))
        }

        // Abstract alt-media requests
        var abstractRequests: [(symbol: String, caseSymbol: String, format: String, priority: Int)] = []
        for request in altMediaRequests {
            let reqSymbol = await abstractor.anonymize(request.id, prefix: "REQ")
            let caseSymbol = await abstractor.anonymize(request.caseId, prefix: "CASE")
            abstractRequests.append((reqSymbol, caseSymbol, request.format, request.priority))
        }

        // Build puzzles
        let casePuzzle = DSPSPuzzleBuilder.buildAccommodationCasePuzzle(
            cases: abstractCases,
            accommodations: abstractAccommodations,
            letters: abstractLetters
        )

        let workflowPuzzle = DSPSPuzzleBuilder.buildAltMediaWorkflowPuzzle(
            requests: abstractRequests,
            slaHours: slaHours
        )

        // Run analysis
        let caseResult = try await orchestrator.dispatch(casePuzzle)
        let workflowResult = try await orchestrator.dispatch(workflowPuzzle)

        var issues: [DomainReasoningIssue] = []
        issues.append(contentsOf: convertToIssues(caseResult, domain: "DSPS"))
        issues.append(contentsOf: convertToIssues(workflowResult, domain: "DSPS"))

        let result = DomainAnalysisResult(
            domain: "DSPS",
            puzzlesRun: 2,
            issuesFound: issues,
            timestamp: Date(),
            metadata: [
                "case_count": String(cases.count),
                "request_count": String(altMediaRequests.count),
                "sla_hours": String(slaHours)
            ]
        )

        domainResults["DSPS"] = result

        // Store critical scenarios
        await storeScenarios(from: caseResult, domain: .workflowStates, title: "Case workflow violation")
        await storeScenarios(from: workflowResult, domain: .workflowStates, title: "Alt-media SLA violation")

        return result
    }

    // MARK: - Transcriptum Domain Analysis

    /// Analyzes academic record invariants.
    public func analyzeTranscriptum(
        students: [(id: UUID, programId: UUID, completedUnits: Int, gpa: Double)],
        programs: [(id: UUID, requiredUnits: Int, minGPA: Double)],
        enrollments: [(id: UUID, studentId: UUID, sectionId: UUID, status: String)],
        sections: [(id: UUID, termId: UUID, capacity: Int, enrolled: Int)],
        terms: [(id: UUID, isActive: Bool)]
    ) async throws -> DomainAnalysisResult {

        await abstractor.reset()

        // Abstract students
        var abstractStudents: [(symbol: String, programSymbol: String, completedUnits: Int, gpa: Double)] = []
        for student in students {
            let stuSymbol = await abstractor.anonymize(student.id, prefix: "STU")
            let progSymbol = await abstractor.anonymize(student.programId, prefix: "PROG")
            abstractStudents.append((stuSymbol, progSymbol, student.completedUnits, student.gpa))
        }

        // Abstract programs
        var abstractPrograms: [(symbol: String, requiredUnits: Int, minGPA: Double)] = []
        for program in programs {
            let progSymbol = await abstractor.anonymize(program.id, prefix: "PROG")
            abstractPrograms.append((progSymbol, program.requiredUnits, program.minGPA))
        }

        // Abstract enrollments
        var abstractEnrollments: [(symbol: String, studentSymbol: String, sectionSymbol: String, status: String)] = []
        for enrollment in enrollments {
            let enrSymbol = await abstractor.anonymize(enrollment.id, prefix: "ENR")
            let stuSymbol = await abstractor.anonymize(enrollment.studentId, prefix: "STU")
            let secSymbol = await abstractor.anonymize(enrollment.sectionId, prefix: "SEC")
            abstractEnrollments.append((enrSymbol, stuSymbol, secSymbol, enrollment.status))
        }

        // Abstract sections
        var abstractSections: [(symbol: String, termSymbol: String, capacity: Int, enrolled: Int)] = []
        for section in sections {
            let secSymbol = await abstractor.anonymize(section.id, prefix: "SEC")
            let termSymbol = await abstractor.anonymize(section.termId, prefix: "TERM")
            abstractSections.append((secSymbol, termSymbol, section.capacity, section.enrolled))
        }

        // Abstract terms
        var abstractTerms: [(symbol: String, isActive: Bool)] = []
        for term in terms {
            let termSymbol = await abstractor.anonymize(term.id, prefix: "TERM")
            abstractTerms.append((termSymbol, term.isActive))
        }

        // Build puzzles
        let degreePuzzle = TranscriptumPuzzleBuilder.buildDegreeAwardPuzzle(
            students: abstractStudents,
            programs: abstractPrograms,
            degreeAwards: []
        )

        let enrollmentPuzzle = TranscriptumPuzzleBuilder.buildEnrollmentConsistencyPuzzle(
            enrollments: abstractEnrollments,
            sections: abstractSections,
            terms: abstractTerms
        )

        // Run analysis
        let degreeResult = try await orchestrator.dispatch(degreePuzzle)
        let enrollmentResult = try await orchestrator.dispatch(enrollmentPuzzle)

        var issues: [DomainReasoningIssue] = []
        issues.append(contentsOf: convertToIssues(degreeResult, domain: "Transcriptum"))
        issues.append(contentsOf: convertToIssues(enrollmentResult, domain: "Transcriptum"))

        let result = DomainAnalysisResult(
            domain: "Transcriptum",
            puzzlesRun: 2,
            issuesFound: issues,
            timestamp: Date(),
            metadata: [
                "student_count": String(students.count),
                "enrollment_count": String(enrollments.count),
                "section_count": String(sections.count)
            ]
        )

        domainResults["Transcriptum"] = result
        await storeScenarios(from: degreeResult, domain: .workflowStates, title: "Degree award violation")
        await storeScenarios(from: enrollmentResult, domain: .workflowStates, title: "Enrollment violation")
        return result
    }

    // MARK: - Security Domain Analysis

    /// Analyzes security architecture for bypass paths.
    public func analyzeSecurity(
        entryPoints: [String],
        sensitiveTargets: [String],
        securityGates: [(name: String, guards: [String], blocks: [String])],
        allowedPaths: [(from: String, to: String)],
        operations: [(id: UUID, risk: String, isBlocked: Bool)],
        killSwitches: [(name: String, blocksOperations: [UUID], isActive: Bool)]
    ) async throws -> DomainAnalysisResult {

        await abstractor.reset()

        // Build bypass puzzle
        let bypassPuzzle = SecurityPuzzleBuilder.buildBypassPathPuzzle(
            entryPoints: entryPoints,
            sensitiveTargets: sensitiveTargets,
            securityGates: securityGates,
            allowedPaths: allowedPaths
        )

        // Abstract operations
        var abstractOperations: [(symbol: String, risk: String, isBlocked: Bool)] = []
        for op in operations {
            let opSymbol = await abstractor.anonymize(op.id, prefix: "OP")
            abstractOperations.append((opSymbol, op.risk, op.isBlocked))
        }

        // Abstract kill switches
        var abstractKillSwitches: [(name: String, blocksOperations: [String], isActive: Bool)] = []
        for ks in killSwitches {
            var blockedOps: [String] = []
            for opId in ks.blocksOperations {
                blockedOps.append(await abstractor.anonymize(opId, prefix: "OP"))
            }
            abstractKillSwitches.append((ks.name, blockedOps, ks.isActive))
        }

        let killSwitchPuzzle = SecurityPuzzleBuilder.buildKillSwitchPuzzle(
            operations: abstractOperations,
            killSwitches: abstractKillSwitches
        )

        // Run analysis
        let bypassResult = try await orchestrator.dispatch(bypassPuzzle)
        let killSwitchResult = try await orchestrator.dispatch(killSwitchPuzzle)

        var issues: [DomainReasoningIssue] = []
        issues.append(contentsOf: convertToIssues(bypassResult, domain: "Security"))
        issues.append(contentsOf: convertToIssues(killSwitchResult, domain: "Security"))

        let result = DomainAnalysisResult(
            domain: "Security",
            puzzlesRun: 2,
            issuesFound: issues,
            timestamp: Date(),
            metadata: [
                "entry_point_count": String(entryPoints.count),
                "sensitive_target_count": String(sensitiveTargets.count),
                "operation_count": String(operations.count)
            ]
        )

        domainResults["Security"] = result
        await storeScenarios(from: bypassResult, domain: .accessControl, title: "Security bypass path")
        await storeScenarios(from: killSwitchResult, domain: .accessControl, title: "Kill switch bypass")
        return result
    }

    // MARK: - Full Platform Analysis

    /// Runs comprehensive analysis across all domains.
    public func analyzeAllDomains() async throws -> PlatformAnalysisReport {
        var results: [DomainAnalysisResult] = []
        var totalIssues = 0
        var criticalIssues = 0

        let identityResult = try await analyzeIdentity(
            sessions: [],
            principals: []
        )
        results.append(identityResult)

        let storageResult = try await analyzeStorage(
            environments: [],
            snapshots: []
        )
        results.append(storageResult)

        let dspsResult = try await analyzeDSPS(
            cases: [],
            accommodations: [],
            letters: [],
            altMediaRequests: []
        )
        results.append(dspsResult)

        let transcriptumResult = try await analyzeTranscriptum(
            students: [],
            programs: [],
            enrollments: [],
            sections: [],
            terms: []
        )
        results.append(transcriptumResult)

        let securityResult = try await analyzeSecurity(
            entryPoints: [],
            sensitiveTargets: [],
            securityGates: [],
            allowedPaths: [],
            operations: [],
            killSwitches: []
        )
        results.append(securityResult)

        for result in results {
            totalIssues += result.issuesFound.count
            criticalIssues += result.issuesFound.filter { $0.severity == .critical }.count
        }

        return PlatformAnalysisReport(
            timestamp: Date(),
            domainResults: results,
            totalIssuesFound: totalIssues,
            criticalIssuesFound: criticalIssues,
            overallHealth: criticalIssues == 0 ? .healthy : (criticalIssues < 3 ? .degraded : .critical)
        )
    }

    // MARK: - Helpers

    private func convertToIssues(_ result: ReasoningResult, domain: String) -> [DomainReasoningIssue] {
        guard result.outcome == .foundViolation else { return [] }

        return result.violatedConstraints.map { constraint in
            DomainReasoningIssue(
                id: UUID(),
                title: "Constraint violation: \(constraint)",
                description: "Found violation path in domain \(domain): \(result.explanation)",
                severity: .high,
                controlId: nil,
                violationPath: result.transitionSequence,
                recommendations: []
            )
        }
    }

    private func storeScenarios(from result: ReasoningResult, domain: ReasoningDomain, title: String) async {
        guard result.outcome == .foundViolation else { return }

        let scenario = AdversarialScenario(
            id: UUID(),
            discoveredAt: Date(),
            domain: domain,
            affectedControls: result.violatedConstraints,
            severity: .high,
            violationPath: result.transitionSequence,
            initialState: AbstractState(),
            finalState: result.finalState,
            violatedConstraints: result.violatedConstraints,
            title: title,
            description: result.explanation,
            discoveredBy: .controlAttacker,
            platformVersion: "current",
            recommendation: "Review and remediate the discovered violation path"
        )

        await scenarioLibrary.add(scenario)
    }

    // MARK: - Status

    /// Gets the latest result for a domain.
    public func getLatestResult(for domain: String) -> DomainAnalysisResult? {
        domainResults[domain]
    }

    /// Gets all cached results.
    public func getAllResults() -> [String: DomainAnalysisResult] {
        domainResults
    }
}

// MARK: - Supporting Types

/// Result of analyzing a single domain.
public struct DomainAnalysisResult: Sendable {
    public let domain: String
    public let puzzlesRun: Int
    public let issuesFound: [DomainReasoningIssue]
    public let timestamp: Date
    public let metadata: [String: String]

    public var hasIssues: Bool { !issuesFound.isEmpty }
    public var hasCriticalIssues: Bool { issuesFound.contains { $0.severity == .critical } }
}

/// Report covering all platform domains.
public struct PlatformAnalysisReport: Sendable {
    public let timestamp: Date
    public let domainResults: [DomainAnalysisResult]
    public let totalIssuesFound: Int
    public let criticalIssuesFound: Int
    public let overallHealth: PlatformHealth

    public enum PlatformHealth: String, Sendable {
        case healthy = "healthy"
        case degraded = "degraded"
        case critical = "critical"
    }
}

/// Issues discovered by domain reasoning analysis.
public struct DomainReasoningIssue: Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let severity: ReasoningIssueSeverity
    public let controlId: String?
    public let violationPath: [String]?
    public let recommendations: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        severity: ReasoningIssueSeverity,
        controlId: String? = nil,
        violationPath: [String]? = nil,
        recommendations: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.severity = severity
        self.controlId = controlId
        self.violationPath = violationPath
        self.recommendations = recommendations
    }
}
