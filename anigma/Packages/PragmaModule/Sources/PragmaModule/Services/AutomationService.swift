//
//  AutomationService.swift
//  PragmaModule
//
//  Automation rules engine for work items.
//  Enables "when X happens, do Y" automation patterns.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore

/// Service for managing and executing automation rules.
public actor AutomationService {
    // MARK: - Dependencies

    private let workService: WorkService
    private let governance: GovernanceController

    // MARK: - State

    private var rules: [AutomationRule] = []
    private var executionLog: [AutomationExecution] = []

    // MARK: - Initialization

    public init(workService: WorkService, governance: GovernanceController) {
        self.workService = workService
        self.governance = governance
    }

    // MARK: - Rule Management

    /// Registers an automation rule.
    public func registerRule(_ rule: AutomationRule) {
        rules.append(rule)
    }

    /// Removes a rule by ID.
    public func removeRule(id: String) {
        rules.removeAll { $0.id == id }
    }

    /// Lists all registered rules.
    public func listRules() -> [AutomationRule] {
        rules
    }

    /// Gets a rule by ID.
    public func getRule(id: String) -> AutomationRule? {
        rules.first { $0.id == id }
    }

    /// Enables or disables a rule.
    public func setRuleEnabled(_ ruleId: String, enabled: Bool) {
        if let index = rules.firstIndex(where: { $0.id == ruleId }) {
            rules[index].isEnabled = enabled
        }
    }

    // MARK: - Event Processing

    /// Processes an event and triggers matching rules.
    public func processEvent(_ event: WorkEvent, principal: String) async {
        let matchingRules = rules.filter { rule in
            rule.isEnabled && rule.trigger.matches(event)
        }

        for rule in matchingRules {
            await executeRule(rule, event: event, principal: principal)
        }
    }

    /// Executes a single rule's actions.
    private func executeRule(
        _ rule: AutomationRule,
        event: WorkEvent,
        principal: String
    ) async {
        let startTime = Date()
        var actionsExecuted = 0
        var errors: [String] = []

        for action in rule.actions {
            do {
                try await executeAction(action, event: event, principal: "automation:\(rule.id)")
                actionsExecuted += 1
            } catch {
                errors.append("\(action.actionType): \(error.localizedDescription)")
            }
        }

        // Log execution
        let execution = AutomationExecution(
            ruleId: rule.id,
            eventType: event.eventType,
            entityId: event.entityId,
            triggeredAt: startTime,
            completedAt: Date(),
            actionsExecuted: actionsExecuted,
            errors: errors
        )
        executionLog.append(execution)

        // Trim log if too large
        if executionLog.count > 1000 {
            executionLog.removeFirst(100)
        }

        // Audit
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: "automation:\(rule.id)",
            module: "AutomationService",
            description: "Executed rule '\(rule.name)': \(actionsExecuted) actions, \(errors.count) errors",
            metadata: ["original_event_type": "automation_rule_executed", "rule_id": rule.id, "rule_name": rule.name, "actions_executed": "\(actionsExecuted)", "errors_count": "\(errors.count)"]
        )
    }

    /// Executes a single action.
    private func executeAction(
        _ action: AutomationAction,
        event: WorkEvent,
        principal: String
    ) async throws {
        switch action.actionType {
        case .setField:
            guard let fieldName = action.parameters["field"],
                  let fieldValue = action.parameters["value"],
                  let entityId = event.entityId else {
                throw AutomationError.invalidParameters("setField requires field, value, and entityId")
            }

            _ = try await workService.updateTask(entityId: entityId, update: { task in
                task.customFields[fieldName] = fieldValue
            }, principal: principal)

        case .transitionStatus:
            guard let newStatus = action.parameters["status"],
                  let entityId = event.entityId else {
                throw AutomationError.invalidParameters("transitionStatus requires status and entityId")
            }

            _ = try await workService.transitionTask(
                entityId: entityId,
                to: newStatus,
                comment: "Automated transition by rule",
                principal: principal
            )

        case .assignTo:
            guard let assigneeId = action.parameters["assignee"],
                  let entityId = event.entityId else {
                throw AutomationError.invalidParameters("assignTo requires assignee and entityId")
            }

            _ = try await workService.assignTask(
                entityId: entityId,
                to: assigneeId,
                principal: principal
            )

        case .addTag:
            guard let tag = action.parameters["tag"],
                  let entityId = event.entityId else {
                throw AutomationError.invalidParameters("addTag requires tag and entityId")
            }

            _ = try await workService.updateTask(entityId: entityId, update: { task in
                if !task.tags.contains(tag) {
                    task.tags.append(tag)
                }
            }, principal: principal)

        case .removeTag:
            guard let tag = action.parameters["tag"],
                  let entityId = event.entityId else {
                throw AutomationError.invalidParameters("removeTag requires tag and entityId")
            }

            _ = try await workService.updateTask(entityId: entityId, update: { task in
                task.tags.removeAll { $0 == tag }
            }, principal: principal)

        case .addComment:
            guard let body = action.parameters["body"],
                  let entityId = event.entityId else {
                throw AutomationError.invalidParameters("addComment requires body and entityId")
            }

            _ = try await workService.addComment(
                to: entityId,
                body: body,
                authorId: "system",
                principal: principal
            )

        case .setPriority:
            guard let priorityString = action.parameters["priority"],
                  let priorityRaw = Int(priorityString),
                  let priority = WorkPriority(rawValue: priorityRaw),
                  let entityId = event.entityId else {
                throw AutomationError.invalidParameters("setPriority requires valid priority and entityId")
            }

            _ = try await workService.updateTask(entityId: entityId, update: { task in
                task.priority = priority
            }, principal: principal)

        case .notify:
            // Notification would be handled by NotificationService
            // For now, just log it
            try? await governance.auditLog.record(
                eventType: ContractsCore.AuditEventType.custom,
                principal: principal,
                module: "PragmaModule",
                description: "Automation notify: \(action.parameters["message"] ?? "no message")",
                metadata: ["original_event_type": "automation_notify"]
            )

        case .webhook:
            // Webhook would make HTTP call
            // For now, just log it
            try? await governance.auditLog.record(
                eventType: ContractsCore.AuditEventType.custom,
                principal: principal,
                module: "PragmaModule",
                description: "Automation webhook: \(action.parameters["url"] ?? "no url")",
                metadata: ["original_event_type": "automation_webhook"]
            )

        case .custom:
            // Custom actions require external handlers
            throw AutomationError.customActionNotImplemented(action.parameters["handler"] ?? "unknown")
        }
    }

    // MARK: - Execution History

    /// Gets recent executions for a rule.
    public func getExecutions(forRule ruleId: String, limit: Int = 50) -> [AutomationExecution] {
        executionLog
            .filter { $0.ruleId == ruleId }
            .suffix(limit)
            .reversed()
            .map { $0 }
    }

    /// Gets all recent executions.
    public func getRecentExecutions(limit: Int = 100) -> [AutomationExecution] {
        Array(executionLog.suffix(limit).reversed())
    }
}

// MARK: - Automation Rule

/// An automation rule definition.
public struct AutomationRule: Codable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var description: String?
    public var trigger: AutomationTrigger
    public var conditions: [AutomationCondition]
    public var actions: [AutomationAction]
    public var isEnabled: Bool
    public var projectId: WorkItemId?  // nil = applies globally
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        trigger: AutomationTrigger,
        conditions: [AutomationCondition] = [],
        actions: [AutomationAction],
        isEnabled: Bool = true,
        projectId: WorkItemId? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.trigger = trigger
        self.conditions = conditions
        self.actions = actions
        self.isEnabled = isEnabled
        self.projectId = projectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Automation Trigger

/// What event triggers a rule.
public struct AutomationTrigger: Codable, Sendable {
    public let eventType: WorkEventType
    public let filters: [String: String]

    public init(eventType: WorkEventType, filters: [String: String] = [:]) {
        self.eventType = eventType
        self.filters = filters
    }

    /// Checks if this trigger matches an event.
    public func matches(_ event: WorkEvent) -> Bool {
        guard event.eventType == eventType else { return false }

        for (key, value) in filters {
            guard let eventValue = event.metadata[key], eventValue == value else {
                return false
            }
        }

        return true
    }

    // Common trigger factories
    public static func onStatusChange(to statusId: String) -> AutomationTrigger {
        AutomationTrigger(eventType: .statusChanged, filters: ["new_status": statusId])
    }

    public static func onCreated(itemType: WorkItemType) -> AutomationTrigger {
        AutomationTrigger(eventType: .created, filters: ["item_type": itemType.rawValue])
    }

    public static var onAssigned: AutomationTrigger {
        AutomationTrigger(eventType: .assigned)
    }

    public static var onCommentAdded: AutomationTrigger {
        AutomationTrigger(eventType: .commentAdded)
    }
}

// MARK: - Work Events

/// Types of events that can trigger automation.
public enum WorkEventType: String, Codable, Sendable, CaseIterable {
    case created
    case updated
    case deleted
    case statusChanged
    case assigned
    case unassigned
    case priorityChanged
    case dueDateChanged
    case commentAdded
    case tagAdded
    case tagRemoved
    case workLogged
    case linked
    case unlinked
}

/// A work event for automation processing.
public struct WorkEvent: Sendable {
    public let eventType: WorkEventType
    public let entityId: EntityId?
    public let workItemId: WorkItemId?
    public let projectId: WorkItemId?
    public let principal: String
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        eventType: WorkEventType,
        entityId: EntityId? = nil,
        workItemId: WorkItemId? = nil,
        projectId: WorkItemId? = nil,
        principal: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.eventType = eventType
        self.entityId = entityId
        self.workItemId = workItemId
        self.projectId = projectId
        self.principal = principal
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Automation Condition

/// Additional conditions that must be met for a rule to execute.
public struct AutomationCondition: Codable, Sendable {
    public let field: String
    public let `operator`: ConditionOperator
    public let value: String

    public init(field: String, operator: ConditionOperator, value: String) {
        self.field = field
        self.operator = `operator`
        self.value = value
    }
}

public enum ConditionOperator: String, Codable, Sendable, CaseIterable {
    case equals
    case notEquals
    case contains
    case notContains
    case isEmpty
    case isNotEmpty
    case greaterThan
    case lessThan
}

// MARK: - Automation Action

/// An action to execute when a rule triggers.
public struct AutomationAction: Codable, Sendable {
    public let actionType: PragmaActionType
    public var parameters: [String: String]

    public init(actionType: PragmaActionType, parameters: [String: String] = [:]) {
        self.actionType = actionType
        self.parameters = parameters
    }

    // Common action factories
    public static func setStatus(_ statusId: String) -> AutomationAction {
        AutomationAction(actionType: .transitionStatus, parameters: ["status": statusId])
    }

    public static func assignTo(_ userId: String) -> AutomationAction {
        AutomationAction(actionType: .assignTo, parameters: ["assignee": userId])
    }

    public static func addTag(_ tag: String) -> AutomationAction {
        AutomationAction(actionType: .addTag, parameters: ["tag": tag])
    }

    public static func addComment(_ body: String) -> AutomationAction {
        AutomationAction(actionType: .addComment, parameters: ["body": body])
    }

    public static func setPriority(_ priority: WorkPriority) -> AutomationAction {
        AutomationAction(actionType: .setPriority, parameters: ["priority": String(priority.rawValue)])
    }
}

public enum PragmaActionType: String, Codable, Sendable, CaseIterable {
    case setField
    case transitionStatus
    case assignTo
    case addTag
    case removeTag
    case addComment
    case setPriority
    case notify
    case webhook
    case custom
}

// MARK: - Automation Execution

/// Record of a rule execution.
public struct AutomationExecution: Sendable {
    public let ruleId: String
    public let eventType: WorkEventType
    public let entityId: EntityId?
    public let triggeredAt: Date
    public let completedAt: Date
    public let actionsExecuted: Int
    public let errors: [String]

    public var durationMs: Int64 {
        Int64(completedAt.timeIntervalSince(triggeredAt) * 1000)
    }

    public var success: Bool {
        errors.isEmpty
    }
}

// MARK: - Automation Errors

public enum AutomationError: Error, LocalizedError, Sendable {
    case invalidParameters(String)
    case actionFailed(String)
    case ruleNotFound(String)
    case customActionNotImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .invalidParameters(let msg):
            return "Invalid automation parameters: \(msg)"
        case .actionFailed(let msg):
            return "Automation action failed: \(msg)"
        case .ruleNotFound(let id):
            return "Automation rule not found: \(id)"
        case .customActionNotImplemented(let handler):
            return "Custom action handler not implemented: \(handler)"
        }
    }
}

// MARK: - Built-in Rule Templates

extension AutomationRule {
    /// Template: Auto-assign bugs to a specific user.
    public static func autoAssignBugs(to userId: String, projectId: WorkItemId? = nil) -> AutomationRule {
        AutomationRule(
            name: "Auto-assign bugs",
            description: "Automatically assign new bugs to \(userId)",
            trigger: .onCreated(itemType: .bug),
            actions: [.assignTo(userId)],
            projectId: projectId
        )
    }

    /// Template: Add "urgent" tag when priority is critical.
    public static func tagUrgentCritical(projectId: WorkItemId? = nil) -> AutomationRule {
        AutomationRule(
            name: "Tag critical as urgent",
            description: "Add 'urgent' tag when priority is set to critical",
            trigger: AutomationTrigger(eventType: .priorityChanged, filters: ["new_priority": "5"]),
            actions: [.addTag("urgent")],
            projectId: projectId
        )
    }

    /// Template: Comment when task is done.
    public static func celebrateDone(projectId: WorkItemId? = nil) -> AutomationRule {
        AutomationRule(
            name: "Celebrate completion",
            description: "Add a celebratory comment when tasks are completed",
            trigger: .onStatusChange(to: "done"),
            actions: [.addComment("🎉 Task completed!")],
            projectId: projectId
        )
    }
}
