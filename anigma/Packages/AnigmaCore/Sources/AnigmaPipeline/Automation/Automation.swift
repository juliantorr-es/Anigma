import AnigmaPrimitives

import AnigmaPrimitives

//
//  Automation.swift
//  AnigmaCore
//
//  Automation and agent orchestration infrastructure.
//  Manages automation rules, agent capabilities, and execution history
//  with full governance integration.
//
//  Design principles:
//  - Automations are first-class governed entities
//  - Agents declare capabilities as contracts
//  - All executions are logged with explanations
//  - Operating mode (assistive/autopilot) is enforced
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import InferenceCore
import Foundation
import ContractsCore
import AnigmaPrimitives

// MARK: - Automation Rule

/// A automation rule that triggers actions based on conditions.
public struct AutomationRuleComponent: Component, Sendable, Codable {
    /// Unique rule identifier.
    public let ruleId: UUID

    /// Human-readable name.
    public var name: String

    /// Description of what this automation does.
    public var description: String?

    /// The tenant this rule belongs to.
    public let tenantId: UUID?

    /// The workspace this rule belongs to (nil = tenant-wide).
    public let workspaceId: UUID?

    /// Whether the rule is enabled.
    public var isEnabled: Bool

    /// Operating mode for this rule.
    public var operatingMode: OperatingMode

    /// Trigger configuration.
    public var trigger: AutomationTrigger

    /// Conditions that must be met.
    public var conditions: [AutomationCondition]

    /// Actions to execute.
    public var actions: [AutomationAction]

    /// Who created the rule.
    public let createdBy: UUID

    /// When the rule was created.
    public let createdAt: Date

    /// When the rule was last modified.
    public var modifiedAt: Date

    /// When the rule was last executed.
    public var lastExecutedAt: Date?

    /// Execution count.
    public var executionCount: Int

    /// Failure count.
    public var failureCount: Int

    /// Rate limit (executions per hour, nil = unlimited).
    public var rateLimitPerHour: Int?

    /// Priority (higher = evaluated first).
    public var priority: Int

    public init(
        ruleId: UUID = UUID(),
        name: String,
        description: String? = nil,
        tenantId: UUID? = nil,
        workspaceId: UUID? = nil,
        operatingMode: OperatingMode = .assistive,
        trigger: AutomationTrigger,
        conditions: [AutomationCondition] = [],
        actions: [AutomationAction] = [],
        createdBy: UUID,
        rateLimitPerHour: Int? = nil,
        priority: Int = 100
    ) {
        self.ruleId = ruleId
        self.name = name
        self.description = description
        self.tenantId = tenantId
        self.workspaceId = workspaceId
        self.isEnabled = true
        self.operatingMode = operatingMode
        self.trigger = trigger
        self.conditions = conditions
        self.actions = actions
        self.createdBy = createdBy
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.lastExecutedAt = nil
        self.executionCount = 0
        self.failureCount = 0
        self.rateLimitPerHour = rateLimitPerHour
        self.priority = priority
    }
}

/// Trigger types for automation rules.
public struct AutomationTrigger: Sendable, Codable {
    /// Type of trigger.
    public var triggerType: TriggerType

    /// Entity types to watch (for entity triggers).
    public var entityTypes: Set<String>

    /// Fields to watch (for field change triggers).
    public var watchedFields: Set<String>

    /// Schedule expression (for scheduled triggers).
    public var schedule: String?

    /// Event types to watch (for event triggers).
    public var eventTypes: Set<String>

    public init(
        triggerType: TriggerType,
        entityTypes: Set<String> = [],
        watchedFields: Set<String> = [],
        schedule: String? = nil,
        eventTypes: Set<String> = []
    ) {
        self.triggerType = triggerType
        self.entityTypes = entityTypes
        self.watchedFields = watchedFields
        self.schedule = schedule
        self.eventTypes = eventTypes
    }

    /// Creates a trigger for entity creation.
    public static func onEntityCreated(_ types: Set<String>) -> AutomationTrigger {
        AutomationTrigger(triggerType: .entityCreated, entityTypes: types)
    }

    /// Creates a trigger for entity updates.
    public static func onEntityUpdated(_ types: Set<String>, fields: Set<String> = []) -> AutomationTrigger {
        AutomationTrigger(triggerType: .entityUpdated, entityTypes: types, watchedFields: fields)
    }

    /// Creates a trigger for state changes.
    public static func onStateChange(_ types: Set<String>) -> AutomationTrigger {
        AutomationTrigger(triggerType: .stateChange, entityTypes: types)
    }

    /// Creates a scheduled trigger.
    public static func scheduled(_ expression: String) -> AutomationTrigger {
        AutomationTrigger(triggerType: .scheduled, schedule: expression)
    }

    /// Creates an event-based trigger.
    public static func onEvent(_ types: Set<String>) -> AutomationTrigger {
        AutomationTrigger(triggerType: .eventBased, eventTypes: types)
    }
}

/// Types of triggers.
public enum TriggerType: String, Sendable, Codable {
    /// Triggered when an entity is created.
    case entityCreated = "entity_created"

    /// Triggered when an entity is updated.
    case entityUpdated = "entity_updated"

    /// Triggered when an entity changes state.
    case stateChange = "state_change"

    /// Triggered on a schedule.
    case scheduled = "scheduled"

    /// Triggered by an event.
    case eventBased = "event_based"

    /// Manual trigger.
    case manual = "manual"
}

/// Condition for automation execution.
public struct AutomationCondition: Sendable, Codable {
    /// Field to evaluate.
    public var field: String

    /// Operator for comparison.
    public var `operator`: ConditionOperator

    /// Value to compare against.
    public var value: String

    public init(field: String, operator: ConditionOperator, value: String) {
        self.field = field
        self.operator = `operator`
        self.value = value
    }
}

/// Operators for conditions.
public enum ConditionOperator: String, Sendable, Codable {
    case equals = "equals"
    case notEquals = "not_equals"
    case contains = "contains"
    case startsWith = "starts_with"
    case endsWith = "ends_with"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case isEmpty = "is_empty"
    case isNotEmpty = "is_not_empty"
    case isIn = "is_in"
    case matches = "matches"
}

/// Action to execute.
public struct AutomationAction: Sendable, Codable {
    /// Type of action.
    public var actionType: ActionType

    /// Target for the action.
    public var target: String?

    /// Parameters for the action.
    public var parameters: [String: String]

    /// Order of execution.
    public var order: Int

    public init(actionType: ActionType, target: String? = nil, parameters: [String: String] = [:], order: Int = 0) {
        self.actionType = actionType
        self.target = target
        self.parameters = parameters
        self.order = order
    }
}

// MARK: - Agent Definition

/// Definition of an AI agent's capabilities.
public struct AgentDefinitionComponent: Component, Sendable, Codable {
    /// Unique agent identifier.
    public let agentId: UUID

    /// Human-readable name.
    public var name: String

    /// Description.
    public var description: String?

    /// Version.
    public var version: String

    /// Agent type.
    public var agentType: AgentType

    /// Operating modes this agent supports.
    public var supportedModes: Set<OperatingModeRaw>

    /// Capabilities this agent provides.
    public var capabilities: [AgentCapability]

    /// Domains this agent can operate on.
    public var allowedDomains: Set<String>

    /// Maximum data sensitivity this agent can access.
    public var maxSensitivity: PrivacySensitivity

    /// Whether the agent is enabled.
    public var isEnabled: Bool

    /// Model/engine used (if applicable).
    public var modelId: String?

    /// When the agent was registered.
    public let registeredAt: Date

    public init(
        agentId: UUID = UUID(),
        name: String,
        description: String? = nil,
        version: String = "1.0.0",
        agentType: AgentType = AgentType.assistant,
        supportedModes: Set<OperatingModeRaw> = [.assistive],
        capabilities: [AgentCapability] = [],
        allowedDomains: Set<String> = [],
        maxSensitivity: PrivacySensitivity = PrivacySensitivity.internal,
        modelId: String? = nil
    ) {
        self.agentId = agentId
        self.name = name
        self.description = description
        self.version = version
        self.agentType = agentType
        self.supportedModes = supportedModes
        self.capabilities = capabilities
        self.allowedDomains = allowedDomains
        self.maxSensitivity = maxSensitivity
        self.isEnabled = true
        self.modelId = modelId
        self.registeredAt = Date()
    }
}

/// Types of agents.
public enum AgentType: String, Sendable, Codable {
    /// General assistant.
    case assistant = "assistant"

    /// Data processor.
    case processor = "processor"

    /// Quality assurance.
    case qa = "qa"

    /// Transformer (Diaplasion).
    case transformer = "transformer"

    /// Analyzer.
    case analyzer = "analyzer"

    /// Orchestrator.
    case orchestrator = "orchestrator"
}

/// A capability that an agent provides.
public struct AgentCapability: Sendable, Codable {
    /// Capability identifier.
    public var capabilityId: String

    /// Human-readable name.
    public var name: String

    /// Description.
    public var description: String?

    /// Input schema (simplified).
    public var inputFields: [CapabilityField]

    /// Output schema.
    public var outputFields: [CapabilityField]

    /// Whether this capability requires human confirmation.
    public var requiresConfirmation: Bool

    /// Risk level of this capability.
    public var riskLevel: RiskLevel

    public init(
        capabilityId: String,
        name: String,
        description: String? = nil,
        inputFields: [CapabilityField] = [],
        outputFields: [CapabilityField] = [],
        requiresConfirmation: Bool = false,
        riskLevel: RiskLevel = RiskLevel.low
    ) {
        self.capabilityId = capabilityId
        self.name = name
        self.description = description
        self.inputFields = inputFields
        self.outputFields = outputFields
        self.requiresConfirmation = requiresConfirmation
        self.riskLevel = riskLevel
    }
}

/// Field definition for capability schemas.
public struct CapabilityField: Sendable, Codable {
    public var name: String
    public var fieldType: String
    public var required: Bool
    public var description: String?

    public init(name: String, fieldType: String, required: Bool = false, description: String? = nil) {
        self.name = name
        self.fieldType = fieldType
        self.required = required
        self.description = description
    }
}

// MARK: - Automation Execution

/// Record of an automation execution.
public struct AutomationExecutionComponent: Component, Sendable, Codable {
    /// Unique execution identifier.
    public let executionId: UUID

    /// The rule that was executed.
    public let ruleId: UUID

    /// Status of the execution.
    public var status: ExecutionStatus

    /// When the execution started.
    public let startedAt: Date

    /// When the execution completed.
    public var completedAt: Date?

    /// Triggering context.
    public var triggerContext: TriggerContext

    /// Results of condition evaluation.
    public var conditionResults: [ConditionResult]

    /// Results of action execution.
    public var actionResults: [ActionResult]

    /// XAI explanation ID (if available).
    public var explanationId: UUID?

    /// Whether human confirmation was required.
    public var confirmationRequired: Bool

    /// Whether human confirmed (if required).
    public var humanConfirmed: Bool?

    /// Who confirmed (if required).
    public var confirmedBy: UUID?

    /// Error message (if failed).
    public var errorMessage: String?

    public init(
        executionId: UUID = UUID(),
        ruleId: UUID,
        triggerContext: TriggerContext,
        confirmationRequired: Bool = false
    ) {
        self.executionId = executionId
        self.ruleId = ruleId
        self.status = .pending
        self.startedAt = Date()
        self.completedAt = nil
        self.triggerContext = triggerContext
        self.conditionResults = []
        self.actionResults = []
        self.explanationId = nil
        self.confirmationRequired = confirmationRequired
        self.humanConfirmed = nil
        self.confirmedBy = nil
        self.errorMessage = nil
    }
}

/// Execution status.
public enum ExecutionStatus: String, Sendable, Codable {
    case pending = "pending"
    case evaluatingConditions = "evaluating_conditions"
    case awaitingConfirmation = "awaiting_confirmation"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"
    case cancelled = "cancelled"
}

/// Context that triggered the automation.
public struct TriggerContext: Sendable, Codable {
    public var triggerType: TriggerType
    public var entityId: UUID?
    public var entityType: String?
    public var eventType: String?
    public var changedFields: [String]
    public var metadata: [String: String]

    public init(
        triggerType: TriggerType,
        entityId: UUID? = nil,
        entityType: String? = nil,
        eventType: String? = nil,
        changedFields: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.triggerType = triggerType
        self.entityId = entityId
        self.entityType = entityType
        self.eventType = eventType
        self.changedFields = changedFields
        self.metadata = metadata
    }
}

/// Result of condition evaluation.
public struct ConditionResult: Sendable, Codable {
    public var field: String
    public var operator_: String
    public var expectedValue: String
    public var actualValue: String?
    public var passed: Bool

    public init(field: String, operator_: String, expectedValue: String, actualValue: String?, passed: Bool) {
        self.field = field
        self.operator_ = operator_
        self.expectedValue = expectedValue
        self.actualValue = actualValue
        self.passed = passed
    }
}

/// Result of action execution.
public struct ActionResult: Sendable, Codable {
    public var actionType: ActionType
    public var target: String?
    public var success: Bool
    public var message: String
    public var createdEntityId: UUID?
    public var durationMs: Int?

    public init(
        actionType: ActionType,
        target: String? = nil,
        success: Bool,
        message: String,
        createdEntityId: UUID? = nil,
        durationMs: Int? = nil
    ) {
        self.actionType = actionType
        self.target = target
        self.success = success
        self.message = message
        self.createdEntityId = createdEntityId
        self.durationMs = durationMs
    }
}

// MARK: - Agent Invocation

/// Record of an agent invocation.
public struct AgentInvocationComponent: Component, Sendable, Codable {
    /// Unique invocation identifier.
    public let invocationId: UUID

    /// The agent invoked.
    public let agentId: UUID

    /// The capability used.
    public let capabilityId: String

    /// Operating mode for this invocation.
    public let operatingMode: OperatingModeRaw

    /// Status.
    public var status: InvocationStatus

    /// Who initiated the invocation.
    public let initiatedBy: UUID

    /// When the invocation started.
    public let startedAt: Date

    /// When the invocation completed.
    public var completedAt: Date?

    /// Input provided.
    public var input: [String: String]

    /// Output produced.
    public var output: [String: String]?

    /// XAI explanation ID.
    public var explanationId: UUID?

    /// Entities affected.
    public var affectedEntityIds: Set<UUID>

    /// Whether changes were applied.
    public var changesApplied: Bool

    /// Human confirmation (if assistive).
    public var humanApproved: Bool?

    /// Token/resource usage.
    public var resourceUsage: ResourceUsage?

    public init(
        invocationId: UUID = UUID(),
        agentId: UUID,
        capabilityId: String,
        operatingMode: OperatingModeRaw,
        initiatedBy: UUID,
        input: [String: String] = [:]
    ) {
        self.invocationId = invocationId
        self.agentId = agentId
        self.capabilityId = capabilityId
        self.operatingMode = operatingMode
        self.status = .pending
        self.initiatedBy = initiatedBy
        self.startedAt = Date()
        self.completedAt = nil
        self.input = input
        self.output = nil
        self.explanationId = nil
        self.affectedEntityIds = []
        self.changesApplied = false
        self.humanApproved = nil
        self.resourceUsage = nil
    }
}

/// Invocation status.
public enum InvocationStatus: String, Sendable, Codable {
    case pending = "pending"
    case running = "running"
    case awaitingApproval = "awaiting_approval"
    case approved = "approved"
    case rejected = "rejected"
    case completed = "completed"
    case failed = "failed"
}

/// Resource usage metrics.
public struct ResourceUsage: Sendable, Codable {
    public var tokensUsed: Int?
    public var durationMs: Int?
    public var memoryBytes: Int64?

    public init(tokensUsed: Int? = nil, durationMs: Int? = nil, memoryBytes: Int64? = nil) {
        self.tokensUsed = tokensUsed
        self.durationMs = durationMs
        self.memoryBytes = memoryBytes
    }
}

// MARK: - Standard Agents

/// Standard agent definitions.
public enum StandardAgents {
    /// Alt-media processing agent.
    public static let altMediaProcessor = AgentDefinitionComponent(
        name: "Alt-Media Processor",
        description: "Processes documents through Diaplasion for accessible formats",
        agentType: AgentType.transformer,
        supportedModes: [.assistive, .autopilot],
        capabilities: [
            AgentCapability(
                capabilityId: "ocr",
                name: "OCR Processing",
                description: "Extract text from images and PDFs",
                inputFields: [
                    CapabilityField(name: "documentPath", fieldType: "string", required: true)
                ],
                outputFields: [
                    CapabilityField(name: "extractedText", fieldType: "string"),
                    CapabilityField(name: "confidence", fieldType: "number")
                ],
                riskLevel: RiskLevel.low
            ),
            AgentCapability(
                capabilityId: "convert_epub",
                name: "EPUB Conversion",
                description: "Convert documents to accessible EPUB",
                inputFields: [
                    CapabilityField(name: "documentPath", fieldType: "string", required: true),
                    CapabilityField(name: "title", fieldType: "string", required: true)
                ],
                outputFields: [
                    CapabilityField(name: "epubPath", fieldType: "string")
                ],
                riskLevel: RiskLevel.low
            )
        ],
        allowedDomains: ["diaplasion", "dsps"],
        maxSensitivity: PrivacySensitivity.confidential
    )

    /// DSPS case assistant.
    public static let dspsCaseAssistant = AgentDefinitionComponent(
        name: "DSPS Case Assistant",
        description: "Assists with DSPS case management and recommendations",
        agentType: AgentType.assistant,
        supportedModes: [.assistive],
        capabilities: [
            AgentCapability(
                capabilityId: "suggest_accommodations",
                name: "Suggest Accommodations",
                description: "Suggest appropriate accommodations based on student profile",
                requiresConfirmation: true,
                riskLevel: RiskLevel.medium
            ),
            AgentCapability(
                capabilityId: "draft_letter",
                name: "Draft Accommodation Letter",
                description: "Draft an accommodation letter for faculty",
                requiresConfirmation: true,
                riskLevel: RiskLevel.medium
            )
        ],
        allowedDomains: ["dsps", "conexus"],
        maxSensitivity: PrivacySensitivity.sensitive
    )

    /// Quality assurance agent.
    public static let qaAgent = AgentDefinitionComponent(
        name: "QA Agent",
        description: "Quality assurance checks for documents and outputs",
        agentType: AgentType.qa,
        supportedModes: [.assistive, .autopilot],
        capabilities: [
            AgentCapability(
                capabilityId: "check_accessibility",
                name: "Check Accessibility",
                description: "Verify document accessibility compliance",
                riskLevel: RiskLevel.low
            ),
            AgentCapability(
                capabilityId: "validate_content",
                name: "Validate Content",
                description: "Check content for errors and completeness",
                riskLevel: RiskLevel.low
            )
        ],
        allowedDomains: ["diaplasion", "codex"],
        maxSensitivity: PrivacySensitivity.confidential
    )
}
