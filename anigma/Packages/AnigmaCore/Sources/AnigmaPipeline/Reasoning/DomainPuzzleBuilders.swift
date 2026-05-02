//
//  DomainPuzzleBuilders.swift
//  AnigmaCore
//
//  Domain-specific puzzle builders for adversarial reasoning across all Anigma domains.
//  Each builder abstracts domain state into puzzles the reasoning kernel can analyze.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation

// MARK: - Identity Domain Puzzles

/// Builds puzzles for identity and session analysis.
public struct IdentityPuzzleBuilder {

    /// Creates a puzzle to find session risk escalation paths.
    public static func buildSessionRiskPuzzle(
        sessions: [(symbol: String, principalSymbol: String, initialRisk: Int, mfaVerified: Bool)],
        actions: [(name: String, riskDelta: Int, requiresMFA: Bool)],
        riskThreshold: Int
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for session in sessions {
            initialSymbols["\(session.symbol).risk"] = .integer(session.initialRisk)
            initialSymbols["\(session.symbol).mfa"] = .boolean(session.mfaVerified)
            initialSymbols["\(session.symbol).principal"] = .category(session.principalSymbol)
            initialSymbols["\(session.symbol).blocked"] = .boolean(false)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        for session in sessions {
            for action in actions {
                var preconditions: [AbstractCondition] = [
                    AbstractCondition(symbol: "\(session.symbol).blocked", operator_: .equals, value: .boolean(false))
                ]

                if action.requiresMFA {
                    preconditions.append(AbstractCondition(
                        symbol: "\(session.symbol).mfa",
                        operator_: .equals,
                        value: .boolean(true)
                    ))
                }

                transitions.append(AbstractTransition(
                    transitionId: "\(session.symbol)_\(action.name)",
                    name: "Session \(session.symbol) performs \(action.name)",
                    preconditions: preconditions,
                    effects: [
                        AbstractEffect(symbol: "\(session.symbol).risk", effectType: .increment, value: .integer(action.riskDelta)),
                        AbstractEffect(symbol: "\(session.symbol).last_action", effectType: .set, value: .category(action.name))
                    ]
                ))
            }
        }

        var constraints: [AbstractConstraint] = []
        for session in sessions {
            constraints.append(AbstractConstraint(
                constraintId: "risk_threshold_\(session.symbol)",
                name: "Session \(session.symbol) risk must stay below threshold",
                condition: AbstractCondition(
                    symbol: "\(session.symbol).risk",
                    operator_: .lessThan,
                    value: .integer(riskThreshold)
                ),
                severity: .violation
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: actions.count * sessions.count,
            metadata: [
                "session_count": String(sessions.count),
                "action_count": String(actions.count),
                "risk_threshold": String(riskThreshold)
            ]
        )
    }

    /// Creates a puzzle to verify deprovisioning completeness.
    public static func buildDeprovisioningPuzzle(
        principals: [(symbol: String, hasActiveRoles: Bool, hasSessions: Bool, hasPendingWork: Bool)],
        deprovisioningSteps: [String]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for principal in principals {
            initialSymbols["\(principal.symbol).active_roles"] = .boolean(principal.hasActiveRoles)
            initialSymbols["\(principal.symbol).sessions"] = .boolean(principal.hasSessions)
            initialSymbols["\(principal.symbol).pending_work"] = .boolean(principal.hasPendingWork)
            initialSymbols["\(principal.symbol).deprovisioned"] = .boolean(false)
            initialSymbols["\(principal.symbol).fully_cleaned"] = .boolean(false)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        for principal in principals {
            // Revoke roles
            transitions.append(AbstractTransition(
                transitionId: "revoke_roles_\(principal.symbol)",
                name: "Revoke roles for \(principal.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(principal.symbol).active_roles", effectType: .set, value: .boolean(false))
                ]
            ))

            // Terminate sessions
            transitions.append(AbstractTransition(
                transitionId: "terminate_sessions_\(principal.symbol)",
                name: "Terminate sessions for \(principal.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(principal.symbol).sessions", effectType: .set, value: .boolean(false))
                ]
            ))

            // Reassign work
            transitions.append(AbstractTransition(
                transitionId: "reassign_work_\(principal.symbol)",
                name: "Reassign pending work from \(principal.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(principal.symbol).pending_work", effectType: .set, value: .boolean(false))
                ]
            ))

            // Complete deprovisioning (should only succeed if all cleanup done)
            transitions.append(AbstractTransition(
                transitionId: "complete_deprov_\(principal.symbol)",
                name: "Complete deprovisioning of \(principal.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(principal.symbol).active_roles", operator_: .equals, value: .boolean(false)),
                    AbstractCondition(symbol: "\(principal.symbol).sessions", operator_: .equals, value: .boolean(false)),
                    AbstractCondition(symbol: "\(principal.symbol).pending_work", operator_: .equals, value: .boolean(false))
                ],
                effects: [
                    AbstractEffect(symbol: "\(principal.symbol).deprovisioned", effectType: .set, value: .boolean(true)),
                    AbstractEffect(symbol: "\(principal.symbol).fully_cleaned", effectType: .set, value: .boolean(true))
                ]
            ))

            // Premature deprovisioning (violation - should not happen)
            transitions.append(AbstractTransition(
                transitionId: "premature_deprov_\(principal.symbol)",
                name: "Prematurely deprovision \(principal.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(principal.symbol).deprovisioned", effectType: .set, value: .boolean(true)),
                    AbstractEffect(symbol: "\(principal.symbol).incomplete_deprov", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        var constraints: [AbstractConstraint] = []
        for principal in principals {
            constraints.append(AbstractConstraint(
                constraintId: "complete_deprov_\(principal.symbol)",
                name: "Deprovisioning of \(principal.symbol) must be complete",
                condition: AbstractCondition(
                    symbol: "\(principal.symbol).incomplete_deprov",
                    operator_: .notEquals,
                    value: .boolean(true)
                ),
                severity: .violation
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: principals.count * 5,
            metadata: ["principal_count": String(principals.count)]
        )
    }
}

// MARK: - Storage Domain Puzzles

/// Builds puzzles for storage and disaster recovery analysis.
public struct StoragePuzzleBuilder {

    /// Creates a puzzle to verify backup/recovery invariants.
    public static func buildDisasterRecoveryPuzzle(
        environments: [(symbol: String, tenantSymbol: String, isProduction: Bool)],
        snapshots: [(symbol: String, envSymbol: String, ageHours: Int, isValid: Bool)],
        rpoHours: Int,
        rtoHours: Int
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for env in environments {
            initialSymbols["\(env.symbol).tenant"] = .category(env.tenantSymbol)
            initialSymbols["\(env.symbol).production"] = .boolean(env.isProduction)
            initialSymbols["\(env.symbol).failed"] = .boolean(false)
            initialSymbols["\(env.symbol).recovered"] = .boolean(false)
        }

        for snapshot in snapshots {
            initialSymbols["\(snapshot.symbol).env"] = .category(snapshot.envSymbol)
            initialSymbols["\(snapshot.symbol).age"] = .integer(snapshot.ageHours)
            initialSymbols["\(snapshot.symbol).valid"] = .boolean(snapshot.isValid)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        // Environment failure
        for env in environments {
            transitions.append(AbstractTransition(
                transitionId: "fail_\(env.symbol)",
                name: "Environment \(env.symbol) fails",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(env.symbol).failed", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        // Recovery attempts
        for env in environments {
            for snapshot in snapshots where snapshot.envSymbol == env.symbol {
                // Valid recovery
                transitions.append(AbstractTransition(
                    transitionId: "recover_\(env.symbol)_from_\(snapshot.symbol)",
                    name: "Recover \(env.symbol) from \(snapshot.symbol)",
                    preconditions: [
                        AbstractCondition(symbol: "\(env.symbol).failed", operator_: .equals, value: .boolean(true)),
                        AbstractCondition(symbol: "\(snapshot.symbol).valid", operator_: .equals, value: .boolean(true))
                    ],
                    effects: [
                        AbstractEffect(symbol: "\(env.symbol).recovered", effectType: .set, value: .boolean(true)),
                        AbstractEffect(symbol: "\(env.symbol).recovery_age", effectType: .set, value: .integer(snapshot.ageHours))
                    ]
                ))
            }

            // Cross-tenant recovery (violation)
            for snapshot in snapshots where snapshot.envSymbol != env.symbol {
                let snapshotEnv = environments.first { $0.symbol == snapshot.envSymbol }
                if let snapshotEnv = snapshotEnv, snapshotEnv.tenantSymbol != env.tenantSymbol {
                    transitions.append(AbstractTransition(
                        transitionId: "cross_tenant_recover_\(env.symbol)_from_\(snapshot.symbol)",
                        name: "Cross-tenant recover \(env.symbol) from \(snapshot.symbol)",
                        preconditions: [
                            AbstractCondition(symbol: "\(env.symbol).failed", operator_: .equals, value: .boolean(true))
                        ],
                        effects: [
                            AbstractEffect(symbol: "\(env.symbol).cross_tenant_recovery", effectType: .set, value: .boolean(true))
                        ]
                    ))
                }
            }
        }

        var constraints: [AbstractConstraint] = []

        // No cross-tenant recovery
        for env in environments {
            constraints.append(AbstractConstraint(
                constraintId: "no_cross_tenant_\(env.symbol)",
                name: "No cross-tenant recovery for \(env.symbol)",
                condition: AbstractCondition(
                    symbol: "\(env.symbol).cross_tenant_recovery",
                    operator_: .notEquals,
                    value: .boolean(true)
                ),
                severity: .critical
            ))
        }

        // RPO compliance for production
        for env in environments where env.isProduction {
            constraints.append(AbstractConstraint(
                constraintId: "rpo_\(env.symbol)",
                name: "RPO compliance for \(env.symbol)",
                condition: AbstractCondition(
                    symbol: "\(env.symbol).recovery_age",
                    operator_: .lessThan,
                    value: .integer(rpoHours)
                ),
                severity: .violation
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .dataLifecycle,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: (environments.count + snapshots.count) * 3,
            metadata: [
                "environment_count": String(environments.count),
                "snapshot_count": String(snapshots.count),
                "rpo_hours": String(rpoHours),
                "rto_hours": String(rtoHours)
            ]
        )
    }
}

// MARK: - DSPS Domain Puzzles

/// Builds puzzles for DSPS accommodation and case management analysis.
public struct DSPSPuzzleBuilder {

    /// Creates a puzzle to verify accommodation case invariants.
    public static func buildAccommodationCasePuzzle(
        cases: [(symbol: String, studentSymbol: String, termSymbol: String, hasDocumentation: Bool)],
        accommodations: [(caseSymbol: String, accommodationType: String, isApproved: Bool)],
        letters: [(caseSymbol: String, letterSymbol: String, isDelivered: Bool)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]
        var initialSets: [String: Set<String>] = [:]

        for caseItem in cases {
            initialSymbols["\(caseItem.symbol).student"] = .category(caseItem.studentSymbol)
            initialSymbols["\(caseItem.symbol).term"] = .category(caseItem.termSymbol)
            initialSymbols["\(caseItem.symbol).documentation"] = .boolean(caseItem.hasDocumentation)
            initialSymbols["\(caseItem.symbol).status"] = .category("open")
            initialSets["\(caseItem.symbol).accommodations"] = Set(
                accommodations.filter { $0.caseSymbol == caseItem.symbol }.map { $0.accommodationType }
            )
        }

        for letter in letters {
            initialSymbols["\(letter.letterSymbol).delivered"] = .boolean(letter.isDelivered)
            initialSymbols["\(letter.letterSymbol).case"] = .category(letter.caseSymbol)
        }

        let initialState = AbstractState(symbols: initialSymbols, sets: initialSets)

        var transitions: [AbstractTransition] = []

        for caseItem in cases {
            // Approve accommodations (requires documentation)
            transitions.append(AbstractTransition(
                transitionId: "approve_\(caseItem.symbol)",
                name: "Approve accommodations for \(caseItem.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(caseItem.symbol).documentation", operator_: .equals, value: .boolean(true))
                ],
                effects: [
                    AbstractEffect(symbol: "\(caseItem.symbol).approved", effectType: .set, value: .boolean(true))
                ]
            ))

            // Generate letter (requires approval)
            transitions.append(AbstractTransition(
                transitionId: "generate_letter_\(caseItem.symbol)",
                name: "Generate letter for \(caseItem.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(caseItem.symbol).approved", operator_: .equals, value: .boolean(true))
                ],
                effects: [
                    AbstractEffect(symbol: "\(caseItem.symbol).letter_generated", effectType: .set, value: .boolean(true))
                ]
            ))

            // Deliver letter
            transitions.append(AbstractTransition(
                transitionId: "deliver_letter_\(caseItem.symbol)",
                name: "Deliver letter for \(caseItem.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(caseItem.symbol).letter_generated", operator_: .equals, value: .boolean(true))
                ],
                effects: [
                    AbstractEffect(symbol: "\(caseItem.symbol).letter_delivered", effectType: .set, value: .boolean(true))
                ]
            ))

            // Close case properly
            transitions.append(AbstractTransition(
                transitionId: "close_proper_\(caseItem.symbol)",
                name: "Properly close \(caseItem.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(caseItem.symbol).letter_delivered", operator_: .equals, value: .boolean(true))
                ],
                effects: [
                    AbstractEffect(symbol: "\(caseItem.symbol).status", effectType: .set, value: .category("closed")),
                    AbstractEffect(symbol: "\(caseItem.symbol).properly_closed", effectType: .set, value: .boolean(true))
                ]
            ))

            // Premature close (violation)
            transitions.append(AbstractTransition(
                transitionId: "close_premature_\(caseItem.symbol)",
                name: "Prematurely close \(caseItem.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(caseItem.symbol).status", effectType: .set, value: .category("closed")),
                    AbstractEffect(symbol: "\(caseItem.symbol).improperly_closed", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        var constraints: [AbstractConstraint] = []
        for caseItem in cases {
            constraints.append(AbstractConstraint(
                constraintId: "proper_close_\(caseItem.symbol)",
                name: "Case \(caseItem.symbol) must be properly closed",
                condition: AbstractCondition(
                    symbol: "\(caseItem.symbol).improperly_closed",
                    operator_: .notEquals,
                    value: .boolean(true)
                ),
                severity: .critical
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .workflowStates,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: cases.count * 6,
            metadata: [
                "case_count": String(cases.count),
                "accommodation_count": String(accommodations.count),
                "letter_count": String(letters.count)
            ]
        )
    }

    /// Creates a puzzle to verify alt-media request workflow invariants.
    public static func buildAltMediaWorkflowPuzzle(
        requests: [(symbol: String, caseSymbol: String, format: String, priority: Int)],
        slaHours: Int
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for request in requests {
            initialSymbols["\(request.symbol).case"] = .category(request.caseSymbol)
            initialSymbols["\(request.symbol).format"] = .category(request.format)
            initialSymbols["\(request.symbol).priority"] = .integer(request.priority)
            initialSymbols["\(request.symbol).status"] = .category("pending")
            initialSymbols["\(request.symbol).age_hours"] = .integer(0)
            initialSymbols["\(request.symbol).delivered"] = .boolean(false)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        for request in requests {
            // Start processing
            transitions.append(AbstractTransition(
                transitionId: "start_\(request.symbol)",
                name: "Start processing \(request.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(request.symbol).status", operator_: .equals, value: .category("pending"))
                ],
                effects: [
                    AbstractEffect(symbol: "\(request.symbol).status", effectType: .set, value: .category("processing"))
                ]
            ))

            // Complete processing
            transitions.append(AbstractTransition(
                transitionId: "complete_\(request.symbol)",
                name: "Complete processing \(request.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(request.symbol).status", operator_: .equals, value: .category("processing"))
                ],
                effects: [
                    AbstractEffect(symbol: "\(request.symbol).status", effectType: .set, value: .category("ready"))
                ]
            ))

            // Deliver
            transitions.append(AbstractTransition(
                transitionId: "deliver_\(request.symbol)",
                name: "Deliver \(request.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(request.symbol).status", operator_: .equals, value: .category("ready"))
                ],
                effects: [
                    AbstractEffect(symbol: "\(request.symbol).status", effectType: .set, value: .category("delivered")),
                    AbstractEffect(symbol: "\(request.symbol).delivered", effectType: .set, value: .boolean(true))
                ]
            ))

            // Time passes (simulates SLA pressure)
            transitions.append(AbstractTransition(
                transitionId: "time_passes_\(request.symbol)",
                name: "Time passes for \(request.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(request.symbol).age_hours", effectType: .increment, value: .integer(24))
                ]
            ))

            // Abandon request (violation if not delivered)
            transitions.append(AbstractTransition(
                transitionId: "abandon_\(request.symbol)",
                name: "Abandon \(request.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(request.symbol).status", effectType: .set, value: .category("abandoned")),
                    AbstractEffect(symbol: "\(request.symbol).abandoned", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        var constraints: [AbstractConstraint] = []
        for request in requests {
            // No abandoned requests
            constraints.append(AbstractConstraint(
                constraintId: "no_abandon_\(request.symbol)",
                name: "Request \(request.symbol) must not be abandoned",
                condition: AbstractCondition(
                    symbol: "\(request.symbol).abandoned",
                    operator_: .notEquals,
                    value: .boolean(true)
                ),
                severity: .critical
            ))

            // SLA compliance
            constraints.append(AbstractConstraint(
                constraintId: "sla_\(request.symbol)",
                name: "Request \(request.symbol) must meet SLA",
                condition: AbstractCondition(
                    symbol: "\(request.symbol).age_hours",
                    operator_: .lessThan,
                    value: .integer(slaHours)
                ),
                severity: .violation
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .workflowStates,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: requests.count * 5,
            metadata: [
                "request_count": String(requests.count),
                "sla_hours": String(slaHours)
            ]
        )
    }
}

// MARK: - Transcriptum Domain Puzzles

/// Builds puzzles for academic record invariant analysis.
public struct TranscriptumPuzzleBuilder {

    /// Creates a puzzle to verify degree award invariants.
    public static func buildDegreeAwardPuzzle(
        students: [(symbol: String, programSymbol: String, completedUnits: Int, gpa: Double)],
        programs: [(symbol: String, requiredUnits: Int, minGPA: Double)],
        degreeAwards: [(studentSymbol: String, programSymbol: String, isAwarded: Bool)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for student in students {
            initialSymbols["\(student.symbol).program"] = .category(student.programSymbol)
            initialSymbols["\(student.symbol).units"] = .integer(student.completedUnits)
            initialSymbols["\(student.symbol).gpa"] = .integer(Int(student.gpa * 100)) // Scale for integer comparison
            initialSymbols["\(student.symbol).degree_awarded"] = .boolean(false)
        }

        for program in programs {
            initialSymbols["\(program.symbol).required_units"] = .integer(program.requiredUnits)
            initialSymbols["\(program.symbol).min_gpa"] = .integer(Int(program.minGPA * 100))
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        for student in students {
            let program = programs.first { $0.symbol == student.programSymbol }
            guard let program = program else { continue }

            // Proper degree award
            transitions.append(AbstractTransition(
                transitionId: "award_proper_\(student.symbol)",
                name: "Properly award degree to \(student.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(student.symbol).units", operator_: .greaterThan, value: .integer(program.requiredUnits - 1)),
                    AbstractCondition(symbol: "\(student.symbol).gpa", operator_: .greaterThan, value: .integer(Int(program.minGPA * 100) - 1))
                ],
                effects: [
                    AbstractEffect(symbol: "\(student.symbol).degree_awarded", effectType: .set, value: .boolean(true)),
                    AbstractEffect(symbol: "\(student.symbol).properly_awarded", effectType: .set, value: .boolean(true))
                ]
            ))

            // Improper degree award (violation)
            transitions.append(AbstractTransition(
                transitionId: "award_improper_\(student.symbol)",
                name: "Improperly award degree to \(student.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(student.symbol).degree_awarded", effectType: .set, value: .boolean(true)),
                    AbstractEffect(symbol: "\(student.symbol).improperly_awarded", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        var constraints: [AbstractConstraint] = []
        for student in students {
            constraints.append(AbstractConstraint(
                constraintId: "proper_award_\(student.symbol)",
                name: "Degree for \(student.symbol) must be properly awarded",
                condition: AbstractCondition(
                    symbol: "\(student.symbol).improperly_awarded",
                    operator_: .notEquals,
                    value: .boolean(true)
                ),
                severity: .critical
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .workflowStates,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: students.count * 3,
            metadata: [
                "student_count": String(students.count),
                "program_count": String(programs.count)
            ]
        )
    }

    /// Creates a puzzle to verify enrollment consistency.
    public static func buildEnrollmentConsistencyPuzzle(
        enrollments: [(symbol: String, studentSymbol: String, sectionSymbol: String, status: String)],
        sections: [(symbol: String, termSymbol: String, capacity: Int, enrolled: Int)],
        terms: [(symbol: String, isActive: Bool)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for enrollment in enrollments {
            initialSymbols["\(enrollment.symbol).student"] = .category(enrollment.studentSymbol)
            initialSymbols["\(enrollment.symbol).section"] = .category(enrollment.sectionSymbol)
            initialSymbols["\(enrollment.symbol).status"] = .category(enrollment.status)
        }

        for section in sections {
            initialSymbols["\(section.symbol).term"] = .category(section.termSymbol)
            initialSymbols["\(section.symbol).capacity"] = .integer(section.capacity)
            initialSymbols["\(section.symbol).enrolled"] = .integer(section.enrolled)
        }

        for term in terms {
            initialSymbols["\(term.symbol).active"] = .boolean(term.isActive)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        // Enrollment operations
        for section in sections {
            let term = terms.first { $0.symbol == section.termSymbol }

            // Add enrollment (should check capacity and term active)
            transitions.append(AbstractTransition(
                transitionId: "enroll_\(section.symbol)",
                name: "Enroll in \(section.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(section.symbol).enrolled", operator_: .lessThan, value: .integer(section.capacity))
                ],
                effects: [
                    AbstractEffect(symbol: "\(section.symbol).enrolled", effectType: .increment, value: .integer(1))
                ]
            ))

            // Over-enroll (violation)
            transitions.append(AbstractTransition(
                transitionId: "overenroll_\(section.symbol)",
                name: "Over-enroll in \(section.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(section.symbol).enrolled", effectType: .increment, value: .integer(1)),
                    AbstractEffect(symbol: "\(section.symbol).over_capacity", effectType: .set, value: .boolean(true))
                ]
            ))

            // Enroll in inactive term (violation)
            if let term = term, !term.isActive {
                transitions.append(AbstractTransition(
                    transitionId: "enroll_inactive_\(section.symbol)",
                    name: "Enroll in inactive term section \(section.symbol)",
                    preconditions: [],
                    effects: [
                        AbstractEffect(symbol: "\(section.symbol).inactive_enrollment", effectType: .set, value: .boolean(true))
                    ]
                ))
            }
        }

        var constraints: [AbstractConstraint] = []
        for section in sections {
            constraints.append(AbstractConstraint(
                constraintId: "capacity_\(section.symbol)",
                name: "Section \(section.symbol) must not exceed capacity",
                condition: AbstractCondition(
                    symbol: "\(section.symbol).over_capacity",
                    operator_: .notEquals,
                    value: .boolean(true)
                ),
                severity: .violation
            ))

            constraints.append(AbstractConstraint(
                constraintId: "active_term_\(section.symbol)",
                name: "Section \(section.symbol) enrollments only in active terms",
                condition: AbstractCondition(
                    symbol: "\(section.symbol).inactive_enrollment",
                    operator_: .notEquals,
                    value: .boolean(true)
                ),
                severity: .violation
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .workflowStates,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: sections.count * 3,
            metadata: [
                "enrollment_count": String(enrollments.count),
                "section_count": String(sections.count),
                "term_count": String(terms.count)
            ]
        )
    }
}

// MARK: - Conexus Domain Puzzles

/// Builds puzzles for CRM and relationship graph analysis.
public struct ConexusPuzzleBuilder {

    /// Creates a puzzle to verify pipeline state machine invariants.
    public static func buildPipelinePuzzle(
        deals: [(symbol: String, stageSymbol: String, ownerSymbol: String)],
        stages: [(symbol: String, order: Int, isTerminal: Bool)],
        transitions: [(fromStage: String, toStage: String, isAllowed: Bool)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for deal in deals {
            initialSymbols["\(deal.symbol).stage"] = .category(deal.stageSymbol)
            initialSymbols["\(deal.symbol).owner"] = .category(deal.ownerSymbol)
            initialSymbols["\(deal.symbol).invalid_transition"] = .boolean(false)
        }

        for stage in stages {
            initialSymbols["\(stage.symbol).order"] = .integer(stage.order)
            initialSymbols["\(stage.symbol).terminal"] = .boolean(stage.isTerminal)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var puzzleTransitions: [AbstractTransition] = []

        for deal in deals {
            // Valid transitions
            for trans in transitions where trans.isAllowed {
                puzzleTransitions.append(AbstractTransition(
                    transitionId: "move_\(deal.symbol)_\(trans.fromStage)_\(trans.toStage)",
                    name: "Move \(deal.symbol) from \(trans.fromStage) to \(trans.toStage)",
                    preconditions: [
                        AbstractCondition(symbol: "\(deal.symbol).stage", operator_: .equals, value: .category(trans.fromStage))
                    ],
                    effects: [
                        AbstractEffect(symbol: "\(deal.symbol).stage", effectType: .set, value: .category(trans.toStage))
                    ]
                ))
            }

            // Invalid transitions (violation)
            for trans in transitions where !trans.isAllowed {
                puzzleTransitions.append(AbstractTransition(
                    transitionId: "invalid_move_\(deal.symbol)_\(trans.fromStage)_\(trans.toStage)",
                    name: "Invalid move \(deal.symbol) from \(trans.fromStage) to \(trans.toStage)",
                    preconditions: [
                        AbstractCondition(symbol: "\(deal.symbol).stage", operator_: .equals, value: .category(trans.fromStage))
                    ],
                    effects: [
                        AbstractEffect(symbol: "\(deal.symbol).stage", effectType: .set, value: .category(trans.toStage)),
                        AbstractEffect(symbol: "\(deal.symbol).invalid_transition", effectType: .set, value: .boolean(true))
                    ]
                ))
            }
        }

        var constraints: [AbstractConstraint] = []
        for deal in deals {
            constraints.append(AbstractConstraint(
                constraintId: "valid_transitions_\(deal.symbol)",
                name: "Deal \(deal.symbol) must only use valid transitions",
                condition: AbstractCondition(
                    symbol: "\(deal.symbol).invalid_transition",
                    operator_: .equals,
                    value: .boolean(false)
                ),
                severity: .violation
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .workflowStates,
            initialState: initialState,
            transitions: puzzleTransitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: deals.count * stages.count,
            metadata: [
                "deal_count": String(deals.count),
                "stage_count": String(stages.count)
            ]
        )
    }
}

// MARK: - Pragma Domain Puzzles

/// Builds puzzles for workflow and task management analysis.
public struct PragmaPuzzleBuilder {

    /// Creates a puzzle to find workflow deadlocks.
    public static func buildWorkflowDeadlockPuzzle(
        tasks: [(symbol: String, dependencies: [String], status: String)],
        maxCycleLength: Int
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]
        var initialSets: [String: Set<String>] = [:]

        for task in tasks {
            initialSymbols["\(task.symbol).status"] = .category(task.status)
            initialSymbols["\(task.symbol).blocked"] = .boolean(!task.dependencies.isEmpty)
            initialSets["\(task.symbol).dependencies"] = Set(task.dependencies)
        }

        let initialState = AbstractState(symbols: initialSymbols, sets: initialSets)

        var transitions: [AbstractTransition] = []

        for task in tasks {
            // Complete task (unblocks dependents)
            transitions.append(AbstractTransition(
                transitionId: "complete_\(task.symbol)",
                name: "Complete \(task.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(task.symbol).blocked", operator_: .equals, value: .boolean(false)),
                    AbstractCondition(symbol: "\(task.symbol).status", operator_: .notEquals, value: .category("completed"))
                ],
                effects: [
                    AbstractEffect(symbol: "\(task.symbol).status", effectType: .set, value: .category("completed"))
                ]
            ))

            // Add circular dependency (creates deadlock)
            for otherTask in tasks where otherTask.symbol != task.symbol {
                transitions.append(AbstractTransition(
                    transitionId: "add_dep_\(task.symbol)_\(otherTask.symbol)",
                    name: "Add dependency \(task.symbol) -> \(otherTask.symbol)",
                    preconditions: [],
                    effects: [
                        AbstractEffect(symbol: "\(task.symbol).blocked", effectType: .set, value: .boolean(true)),
                        AbstractEffect(symbol: "dep_added.\(task.symbol).\(otherTask.symbol)", effectType: .set, value: .boolean(true))
                    ]
                ))
            }
        }

        // Detect cycle: if task A depends on B and B depends on A
        var constraints: [AbstractConstraint] = []
        for task in tasks {
            for dep in task.dependencies {
                let depTask = tasks.first { $0.symbol == dep }
                if let depTask = depTask, depTask.dependencies.contains(task.symbol) {
                    constraints.append(AbstractConstraint(
                        constraintId: "no_cycle_\(task.symbol)_\(dep)",
                        name: "No circular dependency between \(task.symbol) and \(dep)",
                        condition: AbstractCondition(
                            symbol: "cycle_detected",
                            operator_: .equals,
                            value: .boolean(false)
                        ),
                        severity: .critical
                    ))
                }
            }
        }

        // General deadlock detection
        constraints.append(AbstractConstraint(
            constraintId: "no_deadlock",
            name: "No workflow deadlock",
            condition: AbstractCondition(
                symbol: "all_tasks_completable",
                operator_: .equals,
                value: .boolean(true)
            ),
            severity: .critical
        ))

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .workflowStates,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["no_deadlock"]),
            maxSteps: tasks.count * maxCycleLength,
            metadata: [
                "task_count": String(tasks.count),
                "max_cycle_length": String(maxCycleLength)
            ]
        )
    }
}

// MARK: - Security Domain Puzzles

/// Builds puzzles for security architecture analysis.
public struct SecurityPuzzleBuilder {

    /// Creates a puzzle to find bypass paths around security controls.
    public static func buildBypassPathPuzzle(
        entryPoints: [String],
        sensitiveTargets: [String],
        securityGates: [(name: String, guards: [String], blocks: [String])],
        allowedPaths: [(from: String, to: String)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for entry in entryPoints {
            initialSymbols["at.\(entry)"] = .boolean(false)
        }

        for target in sensitiveTargets {
            initialSymbols["reached.\(target)"] = .boolean(false)
            initialSymbols["reached.\(target).without_gate"] = .boolean(false)
        }

        for gate in securityGates {
            initialSymbols["gate.\(gate.name).passed"] = .boolean(false)
        }

        // Start at first entry point
        if let first = entryPoints.first {
            initialSymbols["at.\(first)"] = .boolean(true)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        // Movement along allowed paths
        for path in allowedPaths {
            transitions.append(AbstractTransition(
                transitionId: "move_\(path.from)_\(path.to)",
                name: "Move from \(path.from) to \(path.to)",
                preconditions: [
                    AbstractCondition(symbol: "at.\(path.from)", operator_: .equals, value: .boolean(true))
                ],
                effects: [
                    AbstractEffect(symbol: "at.\(path.from)", effectType: .set, value: .boolean(false)),
                    AbstractEffect(symbol: "at.\(path.to)", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        // Pass through security gates
        for gate in securityGates {
            transitions.append(AbstractTransition(
                transitionId: "pass_gate_\(gate.name)",
                name: "Pass through gate \(gate.name)",
                preconditions: gate.guards.map { guard_ in
                    AbstractCondition(symbol: "at.\(guard_)", operator_: .equals, value: .boolean(true))
                },
                effects: [
                    AbstractEffect(symbol: "gate.\(gate.name).passed", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        // Reach sensitive targets
        for target in sensitiveTargets {
            // Proper access (through gate)
            transitions.append(AbstractTransition(
                transitionId: "reach_proper_\(target)",
                name: "Properly reach \(target)",
                preconditions: [
                    AbstractCondition(symbol: "at.\(target)", operator_: .equals, value: .boolean(true))
                ],
                effects: [
                    AbstractEffect(symbol: "reached.\(target)", effectType: .set, value: .boolean(true))
                ]
            ))

            // Bypass access (violation)
            transitions.append(AbstractTransition(
                transitionId: "bypass_\(target)",
                name: "Bypass security to reach \(target)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "reached.\(target)", effectType: .set, value: .boolean(true)),
                    AbstractEffect(symbol: "reached.\(target).without_gate", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        var constraints: [AbstractConstraint] = []
        for target in sensitiveTargets {
            constraints.append(AbstractConstraint(
                constraintId: "no_bypass_\(target)",
                name: "Cannot reach \(target) without passing security gate",
                condition: AbstractCondition(
                    symbol: "reached.\(target).without_gate",
                    operator_: .equals,
                    value: .boolean(false)
                ),
                severity: .critical
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: (entryPoints.count + sensitiveTargets.count) * 5,
            metadata: [
                "entry_point_count": String(entryPoints.count),
                "sensitive_target_count": String(sensitiveTargets.count),
                "security_gate_count": String(securityGates.count)
            ]
        )
    }

    /// Creates a puzzle to verify kill switch effectiveness.
    public static func buildKillSwitchPuzzle(
        operations: [(symbol: String, risk: String, isBlocked: Bool)],
        killSwitches: [(name: String, blocksOperations: [String], isActive: Bool)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for op in operations {
            initialSymbols["\(op.symbol).risk"] = .category(op.risk)
            initialSymbols["\(op.symbol).blocked"] = .boolean(op.isBlocked)
            initialSymbols["\(op.symbol).executed"] = .boolean(false)
        }

        for ks in killSwitches {
            initialSymbols["killswitch.\(ks.name).active"] = .boolean(ks.isActive)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        for op in operations {
            // Execute blocked operation (should fail)
            transitions.append(AbstractTransition(
                transitionId: "execute_blocked_\(op.symbol)",
                name: "Execute blocked operation \(op.symbol)",
                preconditions: [
                    AbstractCondition(symbol: "\(op.symbol).blocked", operator_: .equals, value: .boolean(false))
                ],
                effects: [
                    AbstractEffect(symbol: "\(op.symbol).executed", effectType: .set, value: .boolean(true))
                ]
            ))

            // Bypass kill switch (violation)
            transitions.append(AbstractTransition(
                transitionId: "bypass_killswitch_\(op.symbol)",
                name: "Bypass kill switch for \(op.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(op.symbol).executed", effectType: .set, value: .boolean(true)),
                    AbstractEffect(symbol: "\(op.symbol).bypassed_killswitch", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        // Activate/deactivate kill switches
        for ks in killSwitches {
            transitions.append(AbstractTransition(
                transitionId: "activate_\(ks.name)",
                name: "Activate kill switch \(ks.name)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "killswitch.\(ks.name).active", effectType: .set, value: .boolean(true))
                ]
            ))

            transitions.append(AbstractTransition(
                transitionId: "deactivate_\(ks.name)",
                name: "Deactivate kill switch \(ks.name)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "killswitch.\(ks.name).active", effectType: .set, value: .boolean(false))
                ]
            ))
        }

        var constraints: [AbstractConstraint] = []
        for op in operations {
            constraints.append(AbstractConstraint(
                constraintId: "killswitch_respected_\(op.symbol)",
                name: "Kill switch must be respected for \(op.symbol)",
                condition: AbstractCondition(
                    symbol: "\(op.symbol).bypassed_killswitch",
                    operator_: .equals,
                    value: .boolean(false)
                ),
                severity: .critical
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: (operations.count + killSwitches.count) * 3,
            metadata: [
                "operation_count": String(operations.count),
                "killswitch_count": String(killSwitches.count)
            ]
        )
    }
}

// MARK: - Codex Domain Puzzles

/// Builds puzzles for knowledge base structure analysis.
public struct CodexPuzzleBuilder {

    /// Creates a puzzle to verify permission paths in knowledge hierarchy.
    public static func buildPermissionPathPuzzle(
        spaces: [(symbol: String, parentSymbol: String?, sensitivity: String)],
        pages: [(symbol: String, spaceSymbol: String, sensitivity: String)],
        roles: [(symbol: String, canAccessSensitivity: [String])]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for space in spaces {
            initialSymbols["\(space.symbol).sensitivity"] = .category(space.sensitivity)
            if let parent = space.parentSymbol {
                initialSymbols["\(space.symbol).parent"] = .category(parent)
            }
        }

        for page in pages {
            initialSymbols["\(page.symbol).space"] = .category(page.spaceSymbol)
            initialSymbols["\(page.symbol).sensitivity"] = .category(page.sensitivity)
            initialSymbols["\(page.symbol).accessed_by_unauthorized"] = .boolean(false)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        for role in roles {
            for page in pages {
                let canAccess = role.canAccessSensitivity.contains(page.sensitivity)

                if canAccess {
                    transitions.append(AbstractTransition(
                        transitionId: "access_\(role.symbol)_\(page.symbol)",
                        name: "Role \(role.symbol) accesses \(page.symbol)",
                        preconditions: [],
                        effects: [
                            AbstractEffect(symbol: "\(page.symbol).accessed_by.\(role.symbol)", effectType: .set, value: .boolean(true))
                        ]
                    ))
                } else {
                    // Unauthorized access (violation)
                    transitions.append(AbstractTransition(
                        transitionId: "unauthorized_access_\(role.symbol)_\(page.symbol)",
                        name: "Unauthorized access by \(role.symbol) to \(page.symbol)",
                        preconditions: [],
                        effects: [
                            AbstractEffect(symbol: "\(page.symbol).accessed_by_unauthorized", effectType: .set, value: .boolean(true)),
                            AbstractEffect(symbol: "\(page.symbol).unauthorized_role", effectType: .set, value: .category(role.symbol))
                        ]
                    ))
                }
            }
        }

        var constraints: [AbstractConstraint] = []
        for page in pages {
            constraints.append(AbstractConstraint(
                constraintId: "no_unauthorized_\(page.symbol)",
                name: "Page \(page.symbol) must not be accessed by unauthorized roles",
                condition: AbstractCondition(
                    symbol: "\(page.symbol).accessed_by_unauthorized",
                    operator_: .equals,
                    value: .boolean(false)
                ),
                severity: .violation
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: roles.count * pages.count,
            metadata: [
                "space_count": String(spaces.count),
                "page_count": String(pages.count),
                "role_count": String(roles.count)
            ]
        )
    }
}

// MARK: - Observatorium Domain Puzzles

/// Builds puzzles for observability coverage analysis.
public struct ObservatoriumPuzzleBuilder {

    /// Creates a puzzle to verify probe coverage.
    public static func buildProbeCoveragePuzzle(
        operations: [(symbol: String, domain: String, risk: String)],
        probes: [(symbol: String, coversDomain: String, coversRisk: [String])],
        requiredCoveragePercent: Int
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]
        var coveredCount = 0

        for op in operations {
            let isCovered = probes.contains { probe in
                probe.coversDomain == op.domain && probe.coversRisk.contains(op.risk)
            }
            initialSymbols["\(op.symbol).covered"] = .boolean(isCovered)
            if isCovered { coveredCount += 1 }
        }

        let coveragePercent = operations.isEmpty ? 100 : (coveredCount * 100) / operations.count
        initialSymbols["coverage_percent"] = .integer(coveragePercent)
        initialSymbols["coverage_sufficient"] = .boolean(coveragePercent >= requiredCoveragePercent)

        let initialState = AbstractState(symbols: initialSymbols)

        var transitions: [AbstractTransition] = []

        // Remove probe (degrades coverage)
        for probe in probes {
            transitions.append(AbstractTransition(
                transitionId: "remove_\(probe.symbol)",
                name: "Remove probe \(probe.symbol)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "\(probe.symbol).active", effectType: .set, value: .boolean(false)),
                    AbstractEffect(symbol: "coverage_degraded", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        // Add operation without probe (creates gap)
        transitions.append(AbstractTransition(
            transitionId: "add_uncovered_operation",
            name: "Add operation without probe coverage",
            preconditions: [],
            effects: [
                AbstractEffect(symbol: "uncovered_operation_added", effectType: .set, value: .boolean(true)),
                AbstractEffect(symbol: "coverage_degraded", effectType: .set, value: .boolean(true))
            ]
        ))

        let constraints = [
            AbstractConstraint(
                constraintId: "coverage_threshold",
                name: "Probe coverage must meet threshold",
                condition: AbstractCondition(
                    symbol: "coverage_degraded",
                    operator_: .equals,
                    value: .boolean(false)
                ),
                severity: .violation
            )
        ]

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .compliance,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["coverage_threshold"]),
            maxSteps: probes.count + 5,
            metadata: [
                "operation_count": String(operations.count),
                "probe_count": String(probes.count),
                "required_coverage": String(requiredCoveragePercent),
                "current_coverage": String(coveragePercent)
            ]
        )
    }
}
