//
//  HarmoniaPuzzleBuilders.swift
//  HarmoniaModule
//
//  Puzzle builders for Harmonia-specific safety analysis.
//  These create abstract puzzles from development workflows, module structures,
//  and automation patterns.
//
//  Harmonia uses the reasoning kernel as a preflight brain for:
//  - New module wiring and system registration
//  - CLI/automation workflow safety
//  - Refactoring operations
//  - Module boundary violations
//  - Node/cluster orchestration
//

import Foundation
import AnigmaCore

// MARK: - Harmonia Reasoning Domain Extensions

/// Harmonia-specific reasoning domains.
public enum HarmoniaReasoningDomain: String, Sendable, Codable, CaseIterable {
    /// Module integration and dependency analysis.
    case moduleIntegration = "module_integration"

    /// CLI and automation workflow safety.
    case workflowSafety = "workflow_safety"

    /// Refactoring operation validation.
    case refactorSafety = "refactor_safety"

    /// Architecture boundary enforcement.
    case architectureBoundary = "architecture_boundary"

    /// Cluster and node orchestration.
    case clusterOrchestration = "cluster_orchestration"

    /// Maps to base reasoning domain.
    public var baseReasoningDomain: ReasoningDomain {
        switch self {
        case .moduleIntegration, .architectureBoundary:
            return .accessControl  // Module boundaries are a form of access control
        case .workflowSafety:
            return .automationRules
        case .refactorSafety:
            return .updateSequence  // Refactors are like migrations
        case .clusterOrchestration:
            return .tenantIsolation  // Node boundaries are isolation boundaries
        }
    }
}

// MARK: - Module Integration Puzzle Builder

/// Builds puzzles for module integration and dependency analysis.
public struct ModuleIntegrationPuzzleBuilder {

    /// Module dependency representation.
    public struct ModuleDependency: Sendable {
        public let sourceModule: String
        public let targetModule: String
        public let dependencyType: DependencyType

        public enum DependencyType: String, Sendable {
            case `import` = "import"
            case systemRegistration = "system_registration"
            case workflowRegistration = "workflow_registration"
            case directWorldAccess = "direct_world_access"
            case serviceCall = "service_call"
        }

        public init(source: String, target: String, type: DependencyType) {
            self.sourceModule = source
            self.targetModule = target
            self.dependencyType = type
        }
    }

    /// Architecture rule representation.
    public struct ArchitectureRule: Sendable {
        public let ruleId: String
        public let description: String
        public let forbiddenDependency: (from: String, to: String)?
        public let requiredPath: (from: String, through: String, to: String)?
        public let severity: ConstraintSeverity

        public init(
            ruleId: String,
            description: String,
            forbiddenDependency: (from: String, to: String)? = nil,
            requiredPath: (from: String, through: String, to: String)? = nil,
            severity: ConstraintSeverity = .violation
        ) {
            self.ruleId = ruleId
            self.description = description
            self.forbiddenDependency = forbiddenDependency
            self.requiredPath = requiredPath
            self.severity = severity
        }
    }

    /// Creates a puzzle to find architecture boundary violations.
    public static func buildBoundaryViolationPuzzle(
        modules: [String],
        dependencies: [ModuleDependency],
        rules: [ArchitectureRule]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]
        var initialSets: [String: Set<String>] = [:]

        // Module existence
        for module in modules {
            initialSymbols["module.\(module).exists"] = .boolean(true)
            initialSets["module.\(module).dependencies"] = Set(
                dependencies.filter { $0.sourceModule == module }.map { $0.targetModule }
            )
        }

        // Dependency edges
        for dep in dependencies {
            initialSymbols["dep.\(dep.sourceModule)_\(dep.targetModule).\(dep.dependencyType.rawValue)"] = .boolean(true)
        }

        let initialState = AbstractState(symbols: initialSymbols, sets: initialSets)

        // Transitions: adding new dependencies
        var transitions: [AbstractTransition] = []
        for source in modules {
            for target in modules where source != target {
                for depType in ModuleDependency.DependencyType.allCases {
                    transitions.append(AbstractTransition(
                        transitionId: "add_dep_\(source)_\(target)_\(depType.rawValue)",
                        name: "Add \(depType.rawValue) from \(source) to \(target)",
                        preconditions: [],
                        effects: [
                            AbstractEffect(
                                symbol: "dep.\(source)_\(target).\(depType.rawValue)",
                                effectType: .set,
                                value: .boolean(true)
                            ),
                            AbstractEffect(
                                symbol: "module.\(source).dependencies",
                                effectType: .addToSet,
                                value: .category(target)
                            )
                        ]
                    ))
                }
            }
        }

        // Constraints from architecture rules
        var constraints: [AbstractConstraint] = []
        for rule in rules {
            if let forbidden = rule.forbiddenDependency {
                // Any dependency type from forbidden.from to forbidden.to is a violation
                for depType in ModuleDependency.DependencyType.allCases {
                    constraints.append(AbstractConstraint(
                        constraintId: "\(rule.ruleId)_\(depType.rawValue)",
                        name: rule.description,
                        condition: AbstractCondition(
                            symbol: "dep.\(forbidden.from)_\(forbidden.to).\(depType.rawValue)",
                            operator_: .equals,
                            value: .boolean(false)
                        ),
                        severity: rule.severity
                    ))
                }
            }
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: modules.count * 3,
            metadata: [
                "module_count": String(modules.count),
                "dependency_count": String(dependencies.count),
                "rule_count": String(rules.count),
                "harmonia_domain": HarmoniaReasoningDomain.moduleIntegration.rawValue
            ]
        )
    }

    /// Creates a puzzle to verify SecuredWorld is always used.
    public static func buildSecuredWorldEnforcementPuzzle(
        modules: [String],
        worldAccessPoints: [(module: String, accessType: String, goesThrough: String?)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [:]

        for access in worldAccessPoints {
            let key = "access.\(access.module).\(access.accessType)"
            initialSymbols[key] = .boolean(true)
            if let through = access.goesThrough {
                initialSymbols["\(key).through"] = .category(through)
            } else {
                initialSymbols["\(key).direct"] = .boolean(true)
            }
        }

        let initialState = AbstractState(symbols: initialSymbols)

        // Transitions: attempting direct access
        var transitions: [AbstractTransition] = []
        for module in modules {
            transitions.append(AbstractTransition(
                transitionId: "direct_access_\(module)",
                name: "\(module) attempts direct World access",
                preconditions: [],
                effects: [
                    AbstractEffect(
                        symbol: "access.\(module).direct_world.direct",
                        effectType: .set,
                        value: .boolean(true)
                    ),
                    AbstractEffect(
                        symbol: "bypass_detected",
                        effectType: .set,
                        value: .boolean(true)
                    )
                ]
            ))
        }

        // Constraint: no direct world access
        let constraints = [
            AbstractConstraint(
                constraintId: "no_direct_world_access",
                name: "All World access must go through SecuredWorld",
                condition: AbstractCondition(
                    symbol: "bypass_detected",
                    operator_: .equals,
                    value: .boolean(false)
                ),
                severity: .critical
            )
        ]

        return ReasoningPuzzle(
            puzzleType: .verifyCompliance,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .proveInvariant(),
            maxSteps: modules.count * 2,
            metadata: [
                "module_count": String(modules.count),
                "access_point_count": String(worldAccessPoints.count),
                "harmonia_domain": HarmoniaReasoningDomain.architectureBoundary.rawValue
            ]
        )
    }
}

extension ModuleIntegrationPuzzleBuilder.ModuleDependency.DependencyType: CaseIterable {}

// MARK: - Workflow Safety Puzzle Builder

/// Builds puzzles for CLI and automation workflow safety analysis.
public struct WorkflowSafetyPuzzleBuilder {

    /// Workflow step representation.
    public struct WorkflowStep: Sendable {
        public let stepId: String
        public let command: String
        public let riskLevel: WorkflowRiskLevel
        public let affectedPaths: [String]
        public let requiresConfirmation: Bool

        public enum WorkflowRiskLevel: String, Sendable {
            case safe = "safe"
            case moderate = "moderate"
            case dangerous = "dangerous"
            case destructive = "destructive"
        }

        public init(
            stepId: String,
            command: String,
            riskLevel: WorkflowRiskLevel,
            affectedPaths: [String] = [],
            requiresConfirmation: Bool = false
        ) {
            self.stepId = stepId
            self.command = command
            self.riskLevel = riskLevel
            self.affectedPaths = affectedPaths
            self.requiresConfirmation = requiresConfirmation
        }
    }

    /// Safety constraint for workflows.
    public struct SafetyConstraint: Sendable {
        public let constraintId: String
        public let description: String
        public let forbiddenCommands: [String]
        public let protectedPaths: [String]
        public let requiresExplicitOverride: Bool

        public init(
            constraintId: String,
            description: String,
            forbiddenCommands: [String] = [],
            protectedPaths: [String] = [],
            requiresExplicitOverride: Bool = false
        ) {
            self.constraintId = constraintId
            self.description = description
            self.forbiddenCommands = forbiddenCommands
            self.protectedPaths = protectedPaths
            self.requiresExplicitOverride = requiresExplicitOverride
        }
    }

    /// Creates a puzzle to find dangerous command sequences.
    public static func buildDangerousSequencePuzzle(
        steps: [WorkflowStep],
        constraints: [SafetyConstraint],
        workspaceRoot: String
    ) -> ReasoningPuzzle {

        let initialSymbols: [String: SymbolValue] = [
            "workspace_root": .category(workspaceRoot),
            "dangerous_sequence_detected": .boolean(false),
            "step_count": .integer(0)
        ]

        let initialSets: [String: Set<String>] = [
            "executed_commands": [],
            "modified_paths": []
        ]

        let initialState = AbstractState(symbols: initialSymbols, sets: initialSets)

        // Transitions: executing workflow steps
        var transitions: [AbstractTransition] = []
        for step in steps {
            var effects: [AbstractEffect] = [
                AbstractEffect(symbol: "step.\(step.stepId).executed", effectType: .set, value: .boolean(true)),
                AbstractEffect(symbol: "executed_commands", effectType: .addToSet, value: .category(step.command)),
                AbstractEffect(symbol: "step_count", effectType: .increment, value: .integer(1))
            ]

            // Add path modifications
            for path in step.affectedPaths {
                effects.append(AbstractEffect(
                    symbol: "modified_paths",
                    effectType: .addToSet,
                    value: .category(path)
                ))
            }

            // Mark dangerous steps
            if step.riskLevel == .dangerous || step.riskLevel == .destructive {
                effects.append(AbstractEffect(
                    symbol: "dangerous_step_executed",
                    effectType: .set,
                    value: .boolean(true)
                ))
            }

            transitions.append(AbstractTransition(
                transitionId: "execute_\(step.stepId)",
                name: "Execute: \(step.command)",
                preconditions: step.requiresConfirmation ? [
                    AbstractCondition(symbol: "confirmation.\(step.stepId)", operator_: .equals, value: .boolean(true))
                ] : [],
                effects: effects
            ))
        }

        // Add confirmation granting transitions
        for step in steps where step.requiresConfirmation {
            transitions.append(AbstractTransition(
                transitionId: "confirm_\(step.stepId)",
                name: "User confirms: \(step.stepId)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "confirmation.\(step.stepId)", effectType: .set, value: .boolean(true))
                ]
            ))
        }

        // Build constraints
        var puzzleConstraints: [AbstractConstraint] = []
        for constraint in constraints {
            // Forbidden commands - use notEquals as a proxy check
            for command in constraint.forbiddenCommands {
                puzzleConstraints.append(AbstractConstraint(
                    constraintId: "\(constraint.constraintId)_cmd_\(command.hashValue)",
                    name: "\(constraint.description): \(command)",
                    condition: AbstractCondition(
                        symbol: "forbidden_command_executed",
                        operator_: .notEquals,
                        value: .boolean(true)
                    ),
                    severity: .critical
                ))
            }

            // Protected paths - use notEquals as a proxy check
            for path in constraint.protectedPaths {
                puzzleConstraints.append(AbstractConstraint(
                    constraintId: "\(constraint.constraintId)_path_\(path.hashValue)",
                    name: "\(constraint.description): protect \(path)",
                    condition: AbstractCondition(
                        symbol: "protected_path_modified.\(path.hashValue)",
                        operator_: .notEquals,
                        value: .boolean(true)
                    ),
                    severity: .critical
                ))
            }
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .automationRules,
            initialState: initialState,
            transitions: transitions,
            constraints: puzzleConstraints,
            goal: .violate(puzzleConstraints.map { $0.constraintId }),
            maxSteps: steps.count * 2,
            metadata: [
                "step_count": String(steps.count),
                "constraint_count": String(constraints.count),
                "workspace_root": workspaceRoot,
                "harmonia_domain": HarmoniaReasoningDomain.workflowSafety.rawValue
            ]
        )
    }

    /// Creates a puzzle to detect potential infinite loops in macros.
    public static func buildMacroLoopDetectionPuzzle(
        macros: [(id: String, triggers: [String], actions: [String])]
    ) -> ReasoningPuzzle {
        // Reuse the automation rule loop detection with Harmonia context
        var rules: [(id: String, triggers: [String], effects: [String])] = []
        for macro in macros {
            rules.append((id: macro.id, triggers: macro.triggers, effects: macro.actions))
        }

        let puzzle = AutomationRulePuzzleBuilder.buildRuleLoopDetectionPuzzle(rules: rules)

        // Add Harmonia-specific metadata
        var metadata = puzzle.metadata
        metadata["harmonia_domain"] = HarmoniaReasoningDomain.workflowSafety.rawValue
        metadata["macro_count"] = String(macros.count)

        return ReasoningPuzzle(
            puzzleType: puzzle.puzzleType,
            domain: puzzle.domain,
            initialState: puzzle.initialState,
            transitions: puzzle.transitions,
            constraints: puzzle.constraints,
            goal: puzzle.goal,
            maxSteps: puzzle.maxSteps,
            metadata: metadata
        )
    }
}

// MARK: - Refactor Safety Puzzle Builder

/// Builds puzzles for refactoring operation validation.
public struct RefactorSafetyPuzzleBuilder {

    /// Refactoring operation representation.
    public struct RefactorOperation: Sendable {
        public let operationId: String
        public let operationType: OperationType
        public let sourceEntities: [String]
        public let targetEntities: [String]
        public let dependencies: [String]

        public enum OperationType: String, Sendable {
            case extractModule = "extract_module"
            case mergeModules = "merge_modules"
            case moveSystem = "move_system"
            case renameComponent = "rename_component"
            case splitWorkflow = "split_workflow"
            case inlineService = "inline_service"
        }

        public init(
            operationId: String,
            operationType: OperationType,
            sourceEntities: [String],
            targetEntities: [String],
            dependencies: [String] = []
        ) {
            self.operationId = operationId
            self.operationType = operationType
            self.sourceEntities = sourceEntities
            self.targetEntities = targetEntities
            self.dependencies = dependencies
        }
    }

    /// Invariant that must be preserved after refactoring.
    public struct RefactorInvariant: Sendable {
        public let invariantId: String
        public let description: String
        public let condition: String

        public init(invariantId: String, description: String, condition: String) {
            self.invariantId = invariantId
            self.description = description
            self.condition = condition
        }
    }

    /// Creates a puzzle to verify refactoring preserves invariants.
    public static func buildRefactorSafetyPuzzle(
        operations: [RefactorOperation],
        invariants: [RefactorInvariant],
        dependencyGraph: [(from: String, to: String)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [
            "refactor_complete": .boolean(false),
            "invariant_violated": .boolean(false)
        ]

        let initialSets: [String: Set<String>] = [
            "existing_entities": Set(operations.flatMap { $0.sourceEntities }),
            "applied_operations": []
        ]

        // Dependency graph
        for (from, to) in dependencyGraph {
            initialSymbols["depends.\(from)_\(to)"] = .boolean(true)
        }

        let initialState = AbstractState(symbols: initialSymbols, sets: initialSets)

        // Transitions: applying refactoring operations
        var transitions: [AbstractTransition] = []
        for op in operations {
            var preconditions: [AbstractCondition] = []

            // Check dependencies are satisfied
            for dep in op.dependencies {
                preconditions.append(AbstractCondition(
                    symbol: "applied_operations",
                    operator_: .contains,
                    value: .category(dep)
                ))
            }

            // Source entities must exist
            for source in op.sourceEntities {
                preconditions.append(AbstractCondition(
                    symbol: "existing_entities",
                    operator_: .contains,
                    value: .category(source)
                ))
            }

            var effects: [AbstractEffect] = [
                AbstractEffect(
                    symbol: "applied_operations",
                    effectType: .addToSet,
                    value: .category(op.operationId)
                )
            ]

            // Remove source entities and add target entities
            for source in op.sourceEntities {
                effects.append(AbstractEffect(
                    symbol: "existing_entities",
                    effectType: .removeFromSet,
                    value: .category(source)
                ))
            }
            for target in op.targetEntities {
                effects.append(AbstractEffect(
                    symbol: "existing_entities",
                    effectType: .addToSet,
                    value: .category(target)
                ))
            }

            transitions.append(AbstractTransition(
                transitionId: "apply_\(op.operationId)",
                name: "\(op.operationType.rawValue): \(op.operationId)",
                preconditions: preconditions,
                effects: effects
            ))
        }

        // Constraints from invariants
        var constraints: [AbstractConstraint] = []
        for invariant in invariants {
            constraints.append(AbstractConstraint(
                constraintId: invariant.invariantId,
                name: invariant.description,
                condition: AbstractCondition(
                    symbol: "invariant.\(invariant.invariantId).valid",
                    operator_: .equals,
                    value: .boolean(true)
                ),
                severity: .violation
            ))
        }

        // Goal: complete all operations while maintaining invariants
        let goalConditions = operations.map { op in
            AbstractCondition(
                symbol: "applied_operations",
                operator_: .contains,
                value: .category(op.operationId)
            )
        }

        return ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .updateSequence,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .reach(goalConditions),
            maxSteps: operations.count * 3,
            metadata: [
                "operation_count": String(operations.count),
                "invariant_count": String(invariants.count),
                "harmonia_domain": HarmoniaReasoningDomain.refactorSafety.rawValue
            ]
        )
    }
}

// MARK: - Cluster Orchestration Puzzle Builder

/// Builds puzzles for distributed node orchestration safety.
public struct ClusterOrchestrationPuzzleBuilder {

    /// Node representation in a cluster.
    public struct ClusterNode: Sendable {
        public let nodeId: String
        public let nodeType: NodeType
        public let tenantAffinity: String?
        public let capabilities: Set<String>
        public let dataResidency: String

        public enum NodeType: String, Sendable {
            case primary = "primary"
            case worker = "worker"
            case mlx = "mlx"
            case storage = "storage"
            case lab = "lab"
        }

        public init(
            nodeId: String,
            nodeType: NodeType,
            tenantAffinity: String? = nil,
            capabilities: Set<String> = [],
            dataResidency: String = "local"
        ) {
            self.nodeId = nodeId
            self.nodeType = nodeType
            self.tenantAffinity = tenantAffinity
            self.capabilities = capabilities
            self.dataResidency = dataResidency
        }
    }

    /// Workload to be scheduled.
    public struct Workload: Sendable {
        public let workloadId: String
        public let requiredCapabilities: Set<String>
        public let dataSensitivity: String
        public let tenantRequirement: String?

        public init(
            workloadId: String,
            requiredCapabilities: Set<String>,
            dataSensitivity: String = "normal",
            tenantRequirement: String? = nil
        ) {
            self.workloadId = workloadId
            self.requiredCapabilities = requiredCapabilities
            self.dataSensitivity = dataSensitivity
            self.tenantRequirement = tenantRequirement
        }
    }

    /// Creates a puzzle to find data residency violations in scheduling.
    public static func buildDataResidencyPuzzle(
        nodes: [ClusterNode],
        workloads: [Workload],
        residencyRules: [(sensitivity: String, allowedResidencies: Set<String>)]
    ) -> ReasoningPuzzle {

        var initialSymbols: [String: SymbolValue] = [
            "residency_violation": .boolean(false)
        ]

        var initialSets: [String: Set<String>] = [:]

        // Node configurations
        for node in nodes {
            initialSymbols["node.\(node.nodeId).type"] = .category(node.nodeType.rawValue)
            initialSymbols["node.\(node.nodeId).residency"] = .category(node.dataResidency)
            if let tenant = node.tenantAffinity {
                initialSymbols["node.\(node.nodeId).tenant"] = .category(tenant)
            }
            initialSets["node.\(node.nodeId).capabilities"] = node.capabilities
        }

        // Workload configurations
        for workload in workloads {
            initialSymbols["workload.\(workload.workloadId).sensitivity"] = .category(workload.dataSensitivity)
            if let tenant = workload.tenantRequirement {
                initialSymbols["workload.\(workload.workloadId).tenant"] = .category(tenant)
            }
            initialSets["workload.\(workload.workloadId).required_caps"] = workload.requiredCapabilities
        }

        let initialState = AbstractState(symbols: initialSymbols, sets: initialSets)

        // Transitions: scheduling workloads to nodes
        var transitions: [AbstractTransition] = []
        for workload in workloads {
            for node in nodes {
                transitions.append(AbstractTransition(
                    transitionId: "schedule_\(workload.workloadId)_\(node.nodeId)",
                    name: "Schedule \(workload.workloadId) to \(node.nodeId)",
                    preconditions: [],
                    effects: [
                        AbstractEffect(
                            symbol: "workload.\(workload.workloadId).scheduled_to",
                            effectType: .set,
                            value: .category(node.nodeId)
                        ),
                        AbstractEffect(
                            symbol: "workload.\(workload.workloadId).actual_residency",
                            effectType: .set,
                            value: .category(node.dataResidency)
                        )
                    ]
                ))
            }
        }

        // Constraints: residency rules
        var constraints: [AbstractConstraint] = []
        for (sensitivity, allowedResidencies) in residencyRules {
            for workload in workloads where workload.dataSensitivity == sensitivity {
                for node in nodes where !allowedResidencies.contains(node.dataResidency) {
                    constraints.append(AbstractConstraint(
                        constraintId: "residency_\(workload.workloadId)_\(node.nodeId)",
                        name: "\(sensitivity) data cannot go to \(node.dataResidency) nodes",
                        condition: AbstractCondition(
                            symbol: "workload.\(workload.workloadId).scheduled_to",
                            operator_: .notEquals,
                            value: .category(node.nodeId)
                        ),
                        severity: .critical
                    ))
                }
            }
        }

        // Tenant isolation constraints
        for workload in workloads {
            if let requiredTenant = workload.tenantRequirement {
                for node in nodes {
                    if let nodeTenant = node.tenantAffinity, nodeTenant != requiredTenant {
                        constraints.append(AbstractConstraint(
                            constraintId: "tenant_\(workload.workloadId)_\(node.nodeId)",
                            name: "\(requiredTenant) workload cannot run on \(nodeTenant) node",
                            condition: AbstractCondition(
                                symbol: "workload.\(workload.workloadId).scheduled_to",
                                operator_: .notEquals,
                                value: .category(node.nodeId)
                            ),
                            severity: .critical
                        ))
                    }
                }
            }
        }

        return ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .tenantIsolation,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(constraints.map { $0.constraintId }),
            maxSteps: workloads.count * 2,
            metadata: [
                "node_count": String(nodes.count),
                "workload_count": String(workloads.count),
                "harmonia_domain": HarmoniaReasoningDomain.clusterOrchestration.rawValue
            ]
        )
    }
}
