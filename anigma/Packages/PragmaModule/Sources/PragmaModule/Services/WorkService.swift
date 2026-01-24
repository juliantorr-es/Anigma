//
//  WorkService.swift
//  PragmaModule
//
//  Central service for work item management.
//  Integrates with ECS World, Governance, and Audit.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import GovernanceCore

// MARK: - Configuration Types

/// Configuration for creating a new task.
public struct CreateTaskConfiguration: Sendable {
    public let projectId: EntityId
    public let title: String
    public let description: String
    public let itemType: WorkItemType
    public let priority: WorkPriority
    public let assigneeId: String?
    public let reporterId: String
    public let dueDate: Date?
    public let tags: [String]
    public let principal: String
    
    public init(
        projectId: EntityId,
        title: String,
        description: String,
        itemType: WorkItemType,
        priority: WorkPriority,
        assigneeId: String? = nil,
        reporterId: String,
        dueDate: Date? = nil,
        tags: [String] = [],
        principal: String
    ) {
        self.projectId = projectId
        self.title = title
        self.description = description
        self.itemType = itemType
        self.priority = priority
        self.assigneeId = assigneeId
        self.reporterId = reporterId
        self.dueDate = dueDate
        self.tags = tags
        self.principal = principal
    }
}

/// Central service for managing work items (tasks, projects, etc.)
/// Provides governed CRUD operations with audit logging.
public actor WorkService {
    // MARK: - Dependencies

    private let world: World
    private let governance: GovernanceController
    private var workflowRegistry: [String: WorkflowDefinition] = [:]
    private var projectKeyIndex: [String: EntityId] = [:]  // keyPrefix → entityId
    private var workItemKeyIndex: [String: EntityId] = [:]  // key (e.g., "PROJ-123") → entityId

    // MARK: - Initialization

    public init(world: World, governance: GovernanceController) {
        self.world = world
        self.governance = governance

        // Register built-in workflows
        workflowRegistry["simple"] = .simple
        workflowRegistry["software"] = .software
    }

    // MARK: - Workflow Management

    /// Registers a custom workflow.
    public func registerWorkflow(_ workflow: WorkflowDefinition) {
        workflowRegistry[workflow.id] = workflow
    }

    /// Gets a workflow by ID.
    public func getWorkflow(id: String) -> WorkflowDefinition? {
        workflowRegistry[id]
    }

    /// Lists all available workflows.
    public func listWorkflows() -> [WorkflowDefinition] {
        Array(workflowRegistry.values)
    }

    // MARK: - Project Operations

    /// Creates a new project.
    public func createProject(
        keyPrefix: String,
        name: String,
        description: String? = nil,
        leadId: String,
        settings: ProjectSettings = ProjectSettings(),
        principal: String
    ) async throws -> (entityId: EntityId, project: ProjectComponent) {
        // Check governance
        let proposal = WriteProposal(
            principal: principal,
            module: "Pragma",
            operation: "create_project",
            componentType: "ProjectComponent"
        )

        let decision = await governance.canWrite(proposal)
        guard decision.allowed else {
            throw PragmaError.permissionDenied(
                reason: decision.failedChecks.map { $0.message }.joined(separator: "; ")
            )
        }

        // Validate key prefix uniqueness
        let normalizedPrefix = keyPrefix.uppercased()
        if projectKeyIndex[normalizedPrefix] != nil {
            throw PragmaError.duplicateKey(normalizedPrefix)
        }

        // Create entity and component
        let entityId = await world.createEntity()
        let project = ProjectComponent(
            keyPrefix: normalizedPrefix,
            name: name,
            description: description,
            leadId: leadId,
            settings: settings
        )

        await world.addComponent(entityId, project)

        // Update index
        projectKeyIndex[normalizedPrefix] = entityId

        // Audit
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "WorkService",
            description: "Created project: \(name) (\(normalizedPrefix))",
            metadata: ["original_event_type": "project_created", "project_id": project.id.raw.uuidString, "name": name, "key_prefix": normalizedPrefix]
        )

        return (entityId, project)
    }

    /// Gets a project by entity ID.
    public func getProject(entityId: EntityId) async -> ProjectComponent? {
        await world.getComponent(entityId, ProjectComponent.self)
    }

    /// Gets a project by key prefix.
    public func getProject(keyPrefix: String) async -> (entityId: EntityId, project: ProjectComponent)? {
        guard let entityId = projectKeyIndex[keyPrefix.uppercased()],
              let project = await world.getComponent(entityId, ProjectComponent.self) else {
            return nil
        }
        return (entityId, project)
    }

    /// Updates a project.
    public func updateProject(
        entityId: EntityId,
        update: (inout ProjectComponent) -> Void,
        principal: String
    ) async throws -> ProjectComponent {
        guard var project = await world.getComponent(entityId, ProjectComponent.self) else {
            throw PragmaError.workItemNotFound(WorkItemId(raw: entityId.raw))
        }

        // Check governance
        let proposal = WriteProposal(
            principal: principal,
            module: "Pragma",
            operation: "update_project",
            entityId: entityId,
            componentType: "ProjectComponent"
        )

        let decision = await governance.canWrite(proposal)
        guard decision.allowed else {
            throw PragmaError.permissionDenied(
                reason: decision.failedChecks.map { $0.message }.joined(separator: "; ")
            )
        }

        let oldPrefix = project.keyPrefix
        update(&project)
        project.updatedAt = Date()
        project.version += 1

        await world.addComponent(entityId, project)

        // Update index if prefix changed
        if oldPrefix != project.keyPrefix {
            projectKeyIndex.removeValue(forKey: oldPrefix)
            projectKeyIndex[project.keyPrefix] = entityId
        }

        return project
    }

    // MARK: - Task Operations

    /// Creates a new task.
    public func createTask(config: CreateTaskConfiguration) async throws -> (entityId: EntityId, task: TaskComponent) {
        // Get project
        guard var project = await world.getComponent(config.projectId, ProjectComponent.self) else {
            throw PragmaError.workItemNotFound(WorkItemId(raw: config.projectId.raw))
        }

        // Check governance
        let proposal = WriteProposal(
            principal: config.principal,
            module: "Pragma",
            operation: "create_task",
            componentType: "TaskComponent",
            context: ["project_id": config.projectId.raw.uuidString]
        )

        let decision = await governance.canWrite(proposal)
        guard decision.allowed else {
            throw PragmaError.permissionDenied(
                reason: decision.failedChecks.map { $0.message }.joined(separator: "; ")
            )
        }

        // Generate key
        let key = project.generateNextKey()
        await world.addComponent(config.projectId, project)

        // Get initial status from workflow
        let workflow = workflowRegistry[project.defaultWorkflowId] ?? .simple
        let initialStatus = workflow.initialStatusId

        // Create entity and task
        let entityId = await world.createEntity()
        var task = TaskComponent(
            key: key,
            itemType: config.itemType,
            title: config.title,
            description: config.description,
            statusId: initialStatus,
            priority: config.priority,
            assigneeId: project.settings.autoAssignToCreator ? config.reporterId : config.assigneeId,
            reporterId: config.reporterId,
            projectId: WorkItemId(raw: config.projectId.raw),
            dueDate: config.dueDate,
            tags: config.tags,
            workflowId: project.defaultWorkflowId
        )

        // Add watchers
        task.watcherIds = [config.reporterId]
        if let assignee = task.assigneeId, assignee != config.reporterId {
            task.watcherIds.append(assignee)
        }

        await world.addComponent(entityId, task)

        // Update index
        workItemKeyIndex[key] = entityId

        // Audit
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: config.principal,
            module: "WorkService",
            description: "Created task: \(key) - \(config.title)",
            metadata: ["original_event_type": "task_created", "task_key": key, "task_id": task.id.raw.uuidString, "title": config.title]
        )

        return (entityId, task)
    }

    /// Gets a task by entity ID.
    public func getTask(entityId: EntityId) async -> TaskComponent? {
        await world.getComponent(entityId, TaskComponent.self)
    }

    /// Gets a task by key (e.g., "PROJ-123").
    public func getTask(key: String) async -> (entityId: EntityId, task: TaskComponent)? {
        guard let entityId = workItemKeyIndex[key.uppercased()],
              let task = await world.getComponent(entityId, TaskComponent.self) else {
            return nil
        }
        return (entityId, task)
    }

    /// Updates a task's status with workflow validation.
    public func transitionTask(
        entityId: EntityId,
        to newStatusId: String,
        comment: String? = nil,
        principal: String
    ) async throws -> TaskComponent {
        guard var task = await world.getComponent(entityId, TaskComponent.self) else {
            throw PragmaError.workItemNotFound(WorkItemId(raw: entityId.raw))
        }

        // Validate transition
        let workflow = workflowRegistry[task.workflowId] ?? .simple
        guard workflow.isValidTransition(from: task.statusId, to: newStatusId) else {
            throw PragmaError.invalidTransition(from: task.statusId, to: newStatusId)
        }

        // Check governance
        let proposal = WriteProposal(
            principal: principal,
            module: "Pragma",
            operation: "transition_task",
            entityId: entityId,
            componentType: "TaskComponent",
            context: [
                "old_status": task.statusId,
                "new_status": newStatusId,
                "comment": comment ?? ""
            ]
        )

        let decision = await governance.canWrite(proposal)
        guard decision.allowed else {
            throw PragmaError.permissionDenied(
                reason: decision.failedChecks.map { $0.message }.joined(separator: "; ")
            )
        }

        // Add comment if provided
        if let comment = comment {
            let commentEntityId = await world.createEntity()
            let systemComment = CommentComponent(
                workItemId: WorkItemId(raw: entityId.raw),
                authorId: "system",
                body: "Status changed from \(task.statusId) to \(newStatusId): \(comment)",
                isSystemComment: true,
                createdAt: Date()
            )
            await world.addComponent(commentEntityId, systemComment)
        }

        // Update status
        task.statusId = newStatusId
        task.updatedAt = Date()

        await world.addComponent(entityId, task)

        return task
    }

    /// Assigns a task to a user.
    public func assignTask(
        entityId: EntityId,
        to assigneeId: String?,
        principal: String
    ) async throws -> TaskComponent {
        guard var task = await world.getComponent(entityId, TaskComponent.self) else {
            throw PragmaError.workItemNotFound(WorkItemId(raw: entityId.raw))
        }

        // Check governance
        let proposal = WriteProposal(
            principal: principal,
            module: "Pragma",
            operation: "assign_task",
            entityId: entityId,
            componentType: "TaskComponent",
            context: [
                "old_assignee": task.assigneeId ?? "none",
                "new_assignee": assigneeId ?? "none"
            ]
        )

        let decision = await governance.canWrite(proposal)
        guard decision.allowed else {
            throw PragmaError.permissionDenied(
                reason: decision.failedChecks.map { $0.message }.joined(separator: "; ")
            )
        }

        let oldAssigneeId = task.assigneeId
        task.assigneeId = assigneeId
        task.updatedAt = Date()

        // Update watchers
        if let assigneeId = assigneeId {
            if !task.watcherIds.contains(assigneeId) {
                task.watcherIds.append(assigneeId)
            }
        }

        await world.addComponent(entityId, task)

        // Add system comment
        let commentEntityId = await world.createEntity()
        let systemComment = CommentComponent(
            workItemId: WorkItemId(raw: entityId.raw),
            authorId: "system",
            body: "Task assigned from \(oldAssigneeId ?? "unassigned") to \(assigneeId ?? "unassigned")",
            isSystemComment: true,
            createdAt: Date()
        )
        await world.addComponent(commentEntityId, systemComment)

        return task
    }

    /// Updates a task with custom modifications.
    public func updateTask(
        entityId: EntityId,
        update: (inout TaskComponent) -> Void,
        principal: String
    ) async throws -> TaskComponent {
        guard var task = await world.getComponent(entityId, TaskComponent.self) else {
            throw PragmaError.workItemNotFound(WorkItemId(raw: entityId.raw))
        }

        // Check governance
        let proposal = WriteProposal(
            principal: principal,
            module: "Pragma",
            operation: "update_task",
            entityId: entityId,
            componentType: "TaskComponent"
        )

        let decision = await governance.canWrite(proposal)
        guard decision.allowed else {
            throw PragmaError.permissionDenied(
                reason: decision.failedChecks.map { $0.message }.joined(separator: "; ")
            )
        }

        update(&task)
        task.updatedAt = Date()

        await world.addComponent(entityId, task)

        return task
    }

    /// Gets all tasks for a project.
    public func getProjectTasks(projectId: EntityId) async -> [TaskComponent] {
        // This would require a query system in the ECS
        // For now, return empty array as placeholder
        return []
    }

    /// Adds a comment to a work item.
    public func addComment(
        to workItemId: EntityId,
        body: String,
        authorId: String,
        principal: String
    ) async throws -> CommentComponent {
        // Check governance
        let proposal = WriteProposal(
            principal: principal,
            module: "Pragma",
            operation: "add_comment",
            entityId: workItemId,
            componentType: "CommentComponent"
        )

        let decision = await governance.canWrite(proposal)
        guard decision.allowed else {
            throw PragmaError.permissionDenied(
                reason: decision.failedChecks.map { $0.message }.joined(separator: "; ")
            )
        }

        let commentEntityId = await world.createEntity()
        let comment = CommentComponent(
            workItemId: WorkItemId(raw: workItemId.raw),
            authorId: authorId,
            body: body,
            isSystemComment: false,
            createdAt: Date()
        )
        await world.addComponent(commentEntityId, comment)

        return comment
    }
}