//
//  DomainPuzzleBuildersTests.swift
//  AnigmaCoreTests
//
//  Tests for domain-specific puzzle builders.
//

import Testing
@testable import AnigmaCore

@Suite("Domain Puzzle Builders Tests")
struct DomainPuzzleBuildersTests {

    // MARK: - Identity Puzzles

    @Test("Session risk puzzle detects escalation paths")
    func testSessionRiskPuzzle() async throws {
        let sessions: [(symbol: String, principalSymbol: String, initialRisk: Int, mfaVerified: Bool)] = [
            ("SES1", "PRI1", 20, false),
            ("SES2", "PRI2", 10, true)
        ]

        let actions: [(name: String, riskDelta: Int, requiresMFA: Bool)] = [
            ("view_public", 5, false),
            ("view_restricted", 20, true),
            ("admin_action", 50, true)
        ]

        let puzzle = IdentityPuzzleBuilder.buildSessionRiskPuzzle(
            sessions: sessions,
            actions: actions,
            riskThreshold: 80
        )

        #expect(puzzle.puzzleType == .findViolation)
        #expect(puzzle.domain == .accessControl)
        #expect(!puzzle.transitions.isEmpty)
        #expect(!puzzle.constraints.isEmpty)
        #expect(puzzle.maxSteps == 6) // actions * sessions
    }

    @Test("Deprovisioning puzzle detects incomplete cleanup")
    func testDeprovisioningPuzzle() async throws {
        let principals: [(symbol: String, hasActiveRoles: Bool, hasSessions: Bool, hasPendingWork: Bool)] = [
            ("PRI1", true, true, false),
            ("PRI2", false, false, true)
        ]

        let puzzle = IdentityPuzzleBuilder.buildDeprovisioningPuzzle(
            principals: principals,
            deprovisioningSteps: ["revoke_roles", "terminate_sessions", "reassign_work"]
        )

        #expect(puzzle.puzzleType == .findViolation)
        #expect(!puzzle.transitions.isEmpty)
        // Should have transitions for each step + completion + premature
        #expect(puzzle.transitions.count >= principals.count * 4)
    }

    // MARK: - Storage Puzzles

    @Test("Disaster recovery puzzle detects cross-tenant risks")
    func testDisasterRecoveryPuzzle() async throws {
        let environments: [(symbol: String, tenantSymbol: String, isProduction: Bool)] = [
            ("ENV1", "TEN1", true),
            ("ENV2", "TEN2", false)
        ]

        let snapshots: [(symbol: String, envSymbol: String, ageHours: Int, isValid: Bool)] = [
            ("SNAP1", "ENV1", 2, true),
            ("SNAP2", "ENV2", 24, true)
        ]

        let puzzle = StoragePuzzleBuilder.buildDisasterRecoveryPuzzle(
            environments: environments,
            snapshots: snapshots,
            rpoHours: 4,
            rtoHours: 8
        )

        #expect(puzzle.domain == .dataLifecycle)
        #expect(!puzzle.constraints.isEmpty)
        #expect(puzzle.metadata["rpo_hours"] == "4")
    }

    // MARK: - DSPS Puzzles

    @Test("Accommodation case puzzle detects improper closures")
    func testAccommodationCasePuzzle() async throws {
        let cases: [(symbol: String, studentSymbol: String, termSymbol: String, hasDocumentation: Bool)] = [
            ("CASE1", "STU1", "TERM1", true),
            ("CASE2", "STU2", "TERM1", false)
        ]

        let accommodations: [(caseSymbol: String, accommodationType: String, isApproved: Bool)] = [
            ("CASE1", "extended_time", true),
            ("CASE1", "separate_room", false)
        ]

        let letters: [(caseSymbol: String, letterSymbol: String, isDelivered: Bool)] = [
            ("CASE1", "LTR1", false)
        ]

        let puzzle = DSPSPuzzleBuilder.buildAccommodationCasePuzzle(
            cases: cases,
            accommodations: accommodations,
            letters: letters
        )

        #expect(puzzle.domain == .workflowStates)
        #expect(puzzle.puzzleType == .findViolation)
        // Each case should have proper close + premature close transitions
        #expect(puzzle.transitions.count >= cases.count * 5)
    }

    @Test("Alt-media workflow puzzle detects SLA violations")
    func testAltMediaWorkflowPuzzle() async throws {
        let requests: [(symbol: String, caseSymbol: String, format: String, priority: Int)] = [
            ("REQ1", "CASE1", "epub", 1),
            ("REQ2", "CASE1", "braille", 2)
        ]

        let puzzle = DSPSPuzzleBuilder.buildAltMediaWorkflowPuzzle(
            requests: requests,
            slaHours: 72
        )

        #expect(puzzle.domain == .workflowStates)
        #expect(puzzle.metadata["sla_hours"] == "72")
        // Should have no_abandon and sla constraints for each request
        #expect(puzzle.constraints.count == requests.count * 2)
    }

    // MARK: - Transcriptum Puzzles

    @Test("Degree award puzzle detects improper awards")
    func testDegreeAwardPuzzle() async throws {
        let students: [(symbol: String, programSymbol: String, completedUnits: Int, gpa: Double)] = [
            ("STU1", "PROG1", 60, 3.5),
            ("STU2", "PROG1", 45, 2.0)
        ]

        let programs: [(symbol: String, requiredUnits: Int, minGPA: Double)] = [
            ("PROG1", 60, 2.0)
        ]

        let puzzle = TranscriptumPuzzleBuilder.buildDegreeAwardPuzzle(
            students: students,
            programs: programs,
            degreeAwards: []
        )

        #expect(puzzle.domain == .workflowStates)
        #expect(!puzzle.constraints.isEmpty)
    }

    @Test("Enrollment consistency puzzle detects capacity violations")
    func testEnrollmentConsistencyPuzzle() async throws {
        let enrollments: [(symbol: String, studentSymbol: String, sectionSymbol: String, status: String)] = [
            ("ENR1", "STU1", "SEC1", "enrolled"),
            ("ENR2", "STU2", "SEC1", "enrolled")
        ]

        let sections: [(symbol: String, termSymbol: String, capacity: Int, enrolled: Int)] = [
            ("SEC1", "TERM1", 30, 28)
        ]

        let terms: [(symbol: String, isActive: Bool)] = [
            ("TERM1", true)
        ]

        let puzzle = TranscriptumPuzzleBuilder.buildEnrollmentConsistencyPuzzle(
            enrollments: enrollments,
            sections: sections,
            terms: terms
        )

        #expect(puzzle.domain == .workflowStates)
        // Should have capacity and active_term constraints per section
        #expect(puzzle.constraints.count == sections.count * 2)
    }

    // MARK: - Security Puzzles

    @Test("Bypass path puzzle detects security gaps")
    func testBypassPathPuzzle() async throws {
        let puzzle = SecurityPuzzleBuilder.buildBypassPathPuzzle(
            entryPoints: ["api_gateway", "admin_panel"],
            sensitiveTargets: ["database", "secrets"],
            securityGates: [
                ("auth_gate", ["api_gateway"], ["unauthenticated"]),
                ("admin_gate", ["admin_panel"], ["non_admin"])
            ],
            allowedPaths: [
                ("api_gateway", "service_layer"),
                ("service_layer", "database")
            ]
        )

        #expect(puzzle.domain == .accessControl)
        #expect(puzzle.puzzleType == .findViolation)
        #expect(!puzzle.transitions.isEmpty)
    }

    @Test("Kill switch puzzle verifies enforcement")
    func testKillSwitchPuzzle() async throws {
        let puzzle = SecurityPuzzleBuilder.buildKillSwitchPuzzle(
            operations: [
                ("OP1", "high", true),
                ("OP2", "medium", false)
            ],
            killSwitches: [
                ("emergency", ["OP1"], true),
                ("maintenance", ["OP2"], false)
            ]
        )

        #expect(puzzle.domain == .accessControl)
        #expect(!puzzle.constraints.isEmpty)
    }

    // MARK: - Conexus Puzzles

    @Test("Pipeline puzzle detects invalid transitions")
    func testPipelinePuzzle() async throws {
        let puzzle = ConexusPuzzleBuilder.buildPipelinePuzzle(
            deals: [
                ("DEAL1", "lead", "OWNER1"),
                ("DEAL2", "qualified", "OWNER1")
            ],
            stages: [
                ("lead", 1, false),
                ("qualified", 2, false),
                ("closed_won", 3, true),
                ("closed_lost", 4, true)
            ],
            transitions: [
                ("lead", "qualified", true),
                ("qualified", "closed_won", true),
                ("qualified", "closed_lost", true),
                ("closed_won", "lead", false) // Invalid backward transition
            ]
        )

        #expect(puzzle.domain == .workflowStates)
        #expect(!puzzle.constraints.isEmpty)
    }

    // MARK: - Pragma Puzzles

    @Test("Workflow deadlock puzzle detects cycles")
    func testWorkflowDeadlockPuzzle() async throws {
        let puzzle = PragmaPuzzleBuilder.buildWorkflowDeadlockPuzzle(
            tasks: [
                ("TASK1", ["TASK2"], "pending"),
                ("TASK2", ["TASK1"], "pending") // Circular dependency
            ],
            maxCycleLength: 5
        )

        #expect(puzzle.domain == .workflowStates)
        #expect(puzzle.puzzleType == .findViolation)
    }

    // MARK: - Codex Puzzles

    @Test("Permission path puzzle detects unauthorized access")
    func testPermissionPathPuzzle() async throws {
        let puzzle = CodexPuzzleBuilder.buildPermissionPathPuzzle(
            spaces: [
                ("SPACE1", nil, "internal"),
                ("SPACE2", "SPACE1", "restricted")
            ],
            pages: [
                ("PAGE1", "SPACE1", "internal"),
                ("PAGE2", "SPACE2", "restricted")
            ],
            roles: [
                ("staff", ["internal"]),
                ("admin", ["internal", "restricted"])
            ]
        )

        #expect(puzzle.domain == .accessControl)
        // Each page should have a constraint
        #expect(puzzle.constraints.count == 2)
    }

    // MARK: - Observatorium Puzzles

    @Test("Probe coverage puzzle detects gaps")
    func testProbeCoveragePuzzle() async throws {
        let puzzle = ObservatoriumPuzzleBuilder.buildProbeCoveragePuzzle(
            operations: [
                ("OP1", "security", "high"),
                ("OP2", "compliance", "medium"),
                ("OP3", "performance", "low")
            ],
            probes: [
                ("PROBE1", "security", ["high", "medium"]),
                ("PROBE2", "compliance", ["high"])
            ],
            requiredCoveragePercent: 80
        )

        #expect(puzzle.domain == .compliance)
        #expect(puzzle.metadata["required_coverage"] == "80")
    }
}
