//
//  PuzzleBuilders.swift
//  AnigmaCore
//
//  Puzzle builders for common security and compliance scenarios.
//  These create abstract puzzles from Anigma domain concepts.
//
//  Important: These builders ABSTRACT real data into anonymous symbols.
//  The reasoning kernel never sees actual student IDs, names, or PII.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation

// MARK: - State Abstractor

/// Abstracts real Anigma state into anonymous puzzle state.
/// This is the critical security boundary.
public actor StateAbstractor {
    /// Symbol counter for generating unique anonymous symbols.
    private var symbolCounter: Int = 0

    /// Mapping from real IDs to symbols (kept only in abstractor, never in puzzle).
    private var idToSymbol: [UUID: String] = [:]

    /// Reverse mapping for interpretation (optional, for result interpretation).
    private var symbolToId: [String: UUID] = [:]

    public init() {}

    /// Generates a new anonymous symbol.
    public func generateSymbol(prefix: String = "S") -> String {
        symbolCounter += 1
        return "\(prefix)\(symbolCounter)"
    }

    /// Maps a real ID to an anonymous symbol.
    public func anonymize(_ id: UUID, prefix: String = "E") -> String {
        if let existing = idToSymbol[id] {
            return existing
        }
        let symbol = generateSymbol(prefix: prefix)
        idToSymbol[id] = symbol
        symbolToId[symbol] = id
        return symbol
    }

    /// Looks up the real ID for a symbol (for result interpretation only).
    public func deanonymize(_ symbol: String) -> UUID? {
        symbolToId[symbol]
    }

    /// Clears all mappings (call between unrelated abstractions).
    public func reset() {
        symbolCounter = 0
        idToSymbol.removeAll()
        symbolToId.removeAll()
    }
}

// MARK: - Access Control Puzzle Builder

/// Builds puzzles for access control analysis.
public struct AccessControlPuzzleBuilder {

    /// Creates a puzzle to find unauthorized access paths.
    public static func buildUnauthorizedAccessPuzzle(
        principals: [(symbol: String, roles: Set<String>, isDeprovisioned: Bool)],
        resources: [(symbol: String, sensitivity: String, requiredRoles: Set<String>)],
        sessions: [(symbol: String, principalSymbol: String, isValid: Bool, mfaVerified: Bool)]
    ) -> ReasoningPuzzle {

        // Build initial state
        var initialSymbols: [String: SymbolValue] = [:]
        var initialSets: [String: Set<String>] = [:]

        // Principals
        for (symbol, roles, isDeprovisioned) in principals {
            initialSymbols["\(symbol).deprovisioned"] = .boolean(isDeprovisioned)
            initialSets["\(symbol).roles"] = roles
        }

        // Resources
        for (symbol, sensitivity, requiredRoles) in resources {
            initialSymbols["\(symbol).sensitivity"] = .category(sensitivity)
            initialSets["\(symbol).required_roles"] = requiredRoles
        }

        // Sessions
        for (symbol, principalSymbol, isValid, mfaVerified) in sessions {
            initialSymbols["\(symbol).valid"] = .boolean(isValid)
            initialSymbols["\(symbol).mfa"] = .boolean(mfaVerified)
            initialSymbols["\(symbol).principal"] = .category(principalSymbol)
        }

        let initialState = AbstractState(symbols: initialSymbols, sets: initialSets)

        // Build transitions
        var transitions: [AbstractTransition] = []

        // Session-based access attempts
        for session in sessions {
            for resource in resources {
                let transitionId = "access_\(session.symbol)_\(resource.symbol)"
                transitions.append(AbstractTransition(
                    transitionId: transitionId,
                    name: "Access \(resource.symbol) via \(session.symbol)",
                    preconditions: [
                        AbstractCondition(symbol: "\(session.symbol).valid", operator_: .equals, value: .boolean(true))
                    ],
                    effects: [
                        AbstractEffect(symbol: "accessed.\(resource.symbol)", effectType: .set, value: .boolean(true)),
                        AbstractEffect(symbol: "accessor", effectType: .set, value: .category(session.principalSymbol))
                    ]
                ))
            }
        }

        // Build constraints (unauthorized access = deprovisioned user accessing anything)
        var constraints: [AbstractConstraint] = []

        for principal in principals {
            for resource in resources {
                constraints.append(AbstractConstraint(
                    constraintId: "no_deprovisioned_access_\(principal.symbol)_\(resource.symbol)",
                    name: "Deprovisioned \(principal.symbol) cannot access \(resource.symbol)",
                    condition: AbstractCondition(
                        symbol: "\(principal.symbol).deprovisioned",
                        operator_: .equals,
                        value: .boolean(false)
                    ),
                    severity: .violation
                ))
            }
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: 100,
            metadata: [
                "principal_count": String(principals.count),
                "resource_count": String(resources.count),
                "session_count": String(sessions.count)
            ]
        )
    }

    /// Creates a puzzle to verify role-based access control.
    public static func buildRBACVerificationPuzzle(
        roles: [String],
        capabilities: [(role: String, capability: String)],
        operations: [(capability: String, resource: String)],
        targetOperation: String,
        targetResource: String
    ) -> ReasoningPuzzle {

        var initialSets: [String: Set<String>] = [:]

        // Role -> capabilities mapping
        for role in roles {
            let caps = capabilities.filter { $0.role == role }.map { $0.capability }
            initialSets["role.\(role).capabilities"] = Set(caps)
        }

        let initialState = AbstractState(sets: initialSets)

        // Transitions: attempt operations
        var transitions: [AbstractTransition] = []
        for role in roles {
            transitions.append(AbstractTransition(
                transitionId: "attempt_\(role)_\(targetOperation)",
                name: "Role \(role) attempts \(targetOperation)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "attempted_by", effectType: .set, value: .category(role)),
                    AbstractEffect(symbol: "attempted_operation", effectType: .set, value: .category(targetOperation))
                ]
            ))
        }

        // Constraint: only roles with the right capability should succeed
        let allowedRoles = capabilities
            .filter { $0.capability == targetOperation || operations.contains { $0.capability == $0.capability && $0.resource == targetResource } }
            .map { $0.role }

        var constraints: [AbstractConstraint] = []
        for role in roles where !allowedRoles.contains(role) {
            constraints.append(AbstractConstraint(
                constraintId: "deny_\(role)_\(targetOperation)",
                name: "\(role) should not perform \(targetOperation)",
                condition: AbstractCondition(
                    symbol: "attempted_by",
                    operator_: .notEquals,
                    value: .category(role)
                ),
                severity: .violation
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .verifyCompliance,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .proveInvariant(),
            maxSteps: 50
        )
    }
}

// MARK: - Tenant Isolation Puzzle Builder

/// Builds puzzles for tenant isolation analysis.
public struct TenantIsolationPuzzleBuilder {

    /// Creates a puzzle to find cross-tenant access paths.
    public static func buildCrossTenantPuzzle(
        tenants: [String],
        entityTenantMap: [(entitySymbol: String, tenantSymbol: String)],
        operationContexts: [(contextSymbol: String, tenantSymbol: String)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        // Entity ownership
        for (entity, tenant) in entityTenantMap {
            initialSymbols["\(entity).tenant"] = .category(tenant)
        }

        // Operation contexts
        for (context, tenant) in operationContexts {
            initialSymbols["\(context).tenant"] = .category(tenant)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        // Transitions: access attempts
        var transitions: [AbstractTransition] = []
        for (context, contextTenant) in operationContexts {
            for (entity, _) in entityTenantMap {
                transitions.append(AbstractTransition(
                    transitionId: "access_\(context)_\(entity)",
                    name: "Context \(context) accesses \(entity)",
                    preconditions: [],
                    effects: [
                        AbstractEffect(symbol: "access.context", effectType: .set, value: .category(context)),
                        AbstractEffect(symbol: "access.entity", effectType: .set, value: .category(entity)),
                        AbstractEffect(symbol: "access.context_tenant", effectType: .set, value: .category(contextTenant))
                    ]
                ))
            }
        }

        // Constraints: no cross-tenant access
        var constraints: [AbstractConstraint] = []
        for (entity, entityTenant) in entityTenantMap {
            for (context, contextTenant) in operationContexts where entityTenant != contextTenant {
                constraints.append(AbstractConstraint(
                    constraintId: "no_cross_\(context)_\(entity)",
                    name: "Context in \(contextTenant) cannot access entity in \(entityTenant)",
                    condition: AbstractCondition(
                        symbol: "access.entity",
                        operator_: .notEquals,
                        value: .category(entity)
                    ),
                    severity: .critical
                ))
            }
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .tenantIsolation,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: 100,
            metadata: [
                "tenant_count": String(tenants.count),
                "entity_count": String(entityTenantMap.count),
                "context_count": String(operationContexts.count)
            ]
        )
    }
}

// MARK: - Update Sequence Puzzle Builder

/// Builds puzzles for update and migration analysis.
public struct UpdateSequencePuzzleBuilder {

    /// Creates a puzzle to find problematic migration sequences.
    public static func buildMigrationSafetyPuzzle(
        migrations: [(id: String, dependencies: [String], isReversible: Bool)],
        initialVersion: String,
        targetVersion: String
    ) -> ReasoningPuzzle {

        let initialSymbols: [String: SymbolValue] = [
            "current_version": .category(initialVersion),
            "target_version": .category(targetVersion)
        ]

        let initialSets: [String: Set<String>] = [
            "applied_migrations": []
        ]

        let initialState = AbstractState(symbols: initialSymbols, sets: initialSets)

        // Transitions: apply migrations
        var transitions: [AbstractTransition] = []
        for migration in migrations {
            // Apply migration
            transitions.append(AbstractTransition(
                transitionId: "apply_\(migration.id)",
                name: "Apply migration \(migration.id)",
                preconditions: migration.dependencies.map { dep in
                    AbstractCondition(symbol: "migration.\(dep).applied", operator_: .equals, value: .boolean(true))
                },
                effects: [
                    AbstractEffect(symbol: "migration.\(migration.id).applied", effectType: .set, value: .boolean(true)),
                    AbstractEffect(symbol: "applied_migrations", effectType: .addToSet, value: .category(migration.id))
                ]
            ))

            // Rollback migration (if reversible)
            if migration.isReversible {
                transitions.append(AbstractTransition(
                    transitionId: "rollback_\(migration.id)",
                    name: "Rollback migration \(migration.id)",
                    preconditions: [
                        AbstractCondition(symbol: "migration.\(migration.id).applied", operator_: .equals, value: .boolean(true))
                    ],
                    effects: [
                        AbstractEffect(symbol: "migration.\(migration.id).applied", effectType: .set, value: .boolean(false)),
                        AbstractEffect(symbol: "applied_migrations", effectType: .removeFromSet, value: .category(migration.id))
                    ]
                ))
            }
        }

        // Constraints: data integrity
        let constraints: [AbstractConstraint] = [
            // Example: certain migrations should not be applied out of order
            AbstractConstraint(
                constraintId: "migration_order",
                name: "Migrations must be applied in order",
                condition: AbstractCondition(symbol: "order_violation", operator_: .equals, value: .boolean(false)),
                severity: .violation
            )
        ]

        // Goal: find a sequence that reaches target version safely
        let goalConditions = [
            AbstractCondition(symbol: "current_version", operator_: .equals, value: .category(targetVersion))
        ]

        return ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .updateSequence,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .reach(goalConditions),
            maxSteps: migrations.count * 2,
            metadata: [
                "migration_count": String(migrations.count),
                "initial_version": initialVersion,
                "target_version": targetVersion
            ]
        )
    }
}

// MARK: - Automation Rule Puzzle Builder

/// Builds puzzles for automation rule analysis.
public struct AutomationRulePuzzleBuilder {

    /// Creates a puzzle to find infinite loops in automation rules.
    public static func buildRuleLoopDetectionPuzzle(
        rules: [(id: String, triggers: [String], effects: [String])]
    ) -> ReasoningPuzzle {

        let initialSymbols: [String: SymbolValue] = [
            "loop_detected": .boolean(false),
            "execution_count": .integer(0)
        ]

        let initialState = AbstractState(symbols: initialSymbols)

        // Transitions: rule executions
        var transitions: [AbstractTransition] = []
        for rule in rules {
            var preconditions: [AbstractCondition] = []
            for trigger in rule.triggers {
                preconditions.append(AbstractCondition(
                    symbol: "event.\(trigger)",
                    operator_: .equals,
                    value: .boolean(true)
                ))
            }

            var effects: [AbstractEffect] = [
                AbstractEffect(symbol: "execution_count", effectType: .increment, value: .integer(1))
            ]
            for effect in rule.effects {
                effects.append(AbstractEffect(
                    symbol: "event.\(effect)",
                    effectType: .set,
                    value: .boolean(true)
                ))
            }

            transitions.append(AbstractTransition(
                transitionId: "execute_\(rule.id)",
                name: "Execute rule \(rule.id)",
                preconditions: preconditions,
                effects: effects
            ))
        }

        // Add a "trigger event" transition to start the chain
        transitions.append(AbstractTransition(
            transitionId: "trigger_initial",
            name: "Trigger initial event",
            preconditions: [],
            effects: [
                AbstractEffect(symbol: "event.initial", effectType: .set, value: .boolean(true))
            ]
        ))

        // Constraint: execution count should not exceed threshold (loop detection)
        let constraints = [
            AbstractConstraint(
                constraintId: "no_infinite_loop",
                name: "Rule execution count must stay bounded",
                condition: AbstractCondition(
                    symbol: "execution_count",
                    operator_: .lessThan,
                    value: .integer(rules.count * 3)
                ),
                severity: .critical
            )
        ]

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .automationRules,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["no_infinite_loop"]),
            maxSteps: rules.count * 5,
            metadata: [
                "rule_count": String(rules.count)
            ]
        )
    }
}

// MARK: - Compliance Puzzle Builder

/// Builds puzzles for compliance control analysis.
public struct CompliancePuzzleBuilder {

    /// Creates a puzzle to verify a control cannot be bypassed.
    public static func buildControlBypassPuzzle(
        controlId: String,
        protectedOperations: [String],
        bypassAttempts: [(name: String, steps: [String])]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [
            "control_active": .boolean(true),
            "bypassed": .boolean(false)
        ]

        for op in protectedOperations {
            initialSymbols["protected.\(op)"] = .boolean(true)
        }

        let initialState = AbstractState(symbols: initialSymbols)

        // Transitions: bypass attempts
        var transitions: [AbstractTransition] = []
        for attempt in bypassAttempts {
            transitions.append(AbstractTransition(
                transitionId: "attempt_\(attempt.name)",
                name: "Bypass attempt: \(attempt.name)",
                preconditions: [
                    AbstractCondition(symbol: "control_active", operator_: .equals, value: .boolean(true))
                ],
                effects: [
                    AbstractEffect(symbol: "attempted.\(attempt.name)", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        // "Successful" bypass (should not be reachable)
        transitions.append(AbstractTransition(
            transitionId: "complete_bypass",
            name: "Complete bypass",
            preconditions: bypassAttempts.map { attempt in
                AbstractCondition(symbol: "attempted.\(attempt.name)", operator_: .equals, value: .boolean(true))
            },
            effects: [
                AbstractEffect(symbol: "bypassed", effectType: .set, value: .boolean(true))
            ]
        ))

        let constraints = [
            AbstractConstraint(
                constraintId: "control_not_bypassed",
                name: "Control \(controlId) cannot be bypassed",
                condition: AbstractCondition(symbol: "bypassed", operator_: .equals, value: .boolean(false)),
                severity: .critical
            )
        ]

        return ReasoningPuzzle(
            puzzleType: .verifyCompliance,
            domain: .compliance,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .proveInvariant(),
            maxSteps: bypassAttempts.count * 2 + 5,
            metadata: [
                "control_id": controlId,
                "protected_operation_count": String(protectedOperations.count),
                "bypass_attempt_count": String(bypassAttempts.count)
            ]
        )
    }
}

// MARK: - Data Lifecycle Puzzle Builder

/// Builds puzzles for data lifecycle analysis.
public struct DataLifecyclePuzzleBuilder {

    /// Creates a puzzle to verify legal hold enforcement.
    public static func buildLegalHoldPuzzle(
        entities: [String],
        entitiesUnderHold: Set<String>,
        deletionAttempts: [String]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for entity in entities {
            initialSymbols["\(entity).exists"] = .boolean(true)
            initialSymbols["\(entity).under_hold"] = .boolean(entitiesUnderHold.contains(entity))
        }

        let initialState = AbstractState(symbols: initialSymbols)

        // Transitions: deletion attempts
        var transitions: [AbstractTransition] = []
        for entity in deletionAttempts {
            // Attempted deletion (should be blocked by hold)
            transitions.append(AbstractTransition(
                transitionId: "delete_\(entity)",
                name: "Attempt to delete \(entity)",
                preconditions: [
                    AbstractCondition(symbol: "\(entity).exists", operator_: .equals, value: .boolean(true)),
                    AbstractCondition(symbol: "\(entity).under_hold", operator_: .equals, value: .boolean(false))
                ],
                effects: [
                    AbstractEffect(symbol: "\(entity).exists", effectType: .set, value: .boolean(false))
                ]
            ))

            // Forced deletion (illegal, should violate constraint)
            transitions.append(AbstractTransition(
                transitionId: "force_delete_\(entity)",
                name: "Force delete \(entity) (bypass hold)",
                preconditions: [
                    AbstractCondition(symbol: "\(entity).exists", operator_: .equals, value: .boolean(true))
                ],
                effects: [
                    AbstractEffect(symbol: "\(entity).exists", effectType: .set, value: .boolean(false)),
                    AbstractEffect(symbol: "\(entity).illegally_deleted", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        // Constraints: entities under hold cannot be deleted
        var constraints: [AbstractConstraint] = []
        for entity in entitiesUnderHold {
            constraints.append(AbstractConstraint(
                constraintId: "hold_\(entity)",
                name: "Entity \(entity) under legal hold cannot be deleted",
                condition: AbstractCondition(
                    symbol: "\(entity).exists",
                    operator_: .equals,
                    value: .boolean(true)
                ),
                severity: .critical
            ))
        }

        return ReasoningPuzzle(
            puzzleType: .verifyCompliance,
            domain: .dataLifecycle,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .proveInvariant(),
            maxSteps: deletionAttempts.count * 2,
            metadata: [
                "entity_count": String(entities.count),
                "under_hold_count": String(entitiesUnderHold.count)
            ]
        )
    }
}
