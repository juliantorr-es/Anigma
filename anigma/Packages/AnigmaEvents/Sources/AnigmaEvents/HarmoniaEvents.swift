// HarmoniaEvents.swift
// Event definitions for Harmonia workflow system

import Foundation

/// Workflow state
public enum WorkflowState: String, Sendable, Codable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

/// Workflow event types
public struct WorkflowStartedEvent: AnigmaEvent {
    public static let eventType = "workflow.started"
    
    public let workflowId: String
    public let workflowName: String
    public let initiatedBy: String?
    public let metadata: [String: String]?
    
    public init(workflowId: String, workflowName: String, initiatedBy: String? = nil, metadata: [String: String]? = nil) {
        self.workflowId = workflowId
        self.workflowName = workflowName
        self.initiatedBy = initiatedBy
        self.metadata = metadata
    }
    
    public var description: String {
        "WorkflowStartedEvent(id: \"workflowId\", name: \"workflowName\")"
    }
}

public struct WorkflowProgressEvent: AnigmaEvent {
    public static let eventType = "workflow.progress"
    
    public let workflowId: String
    public let progress: Double
    public let message: String?
    public let stepName: String?
    
    public init(workflowId: String, progress: Double, message: String? = nil, stepName: String? = nil) {
        self.workflowId = workflowId
        self.progress = progress
        self.message = message
        self.stepName = stepName
    }
    
    public var description: String {
        "WorkflowProgressEvent(id: \"workflowId\", progress: \"progress\", step: \"stepName\")"
    }
}

public struct WorkflowCompletedEvent: AnigmaEvent {
    public static let eventType = "workflow.completed"
    
    public let workflowId: String
    public let result: String?
    public let duration: TimeInterval
    public let success: Bool
    public let errorMessage: String?
    
    public init(workflowId: String, result: String? = nil, duration: TimeInterval, success: Bool, errorMessage: String? = nil) {
        self.workflowId = workflowId
        self.result = result
        self.duration = duration
        self.success = success
        self.errorMessage = errorMessage
    }
    
    public var description: String {
        "WorkflowCompletedEvent(id: \"workflowId\", success: \"success\", duration: \"duration\"s)"
    }
}

public struct WorkflowFailedEvent: AnigmaEvent {
    public static let eventType = "workflow.failed"
    
    public let workflowId: String
    public let error: Error
    public let errorMessage: String
    public let stackTrace: String?
    
    public init(workflowId: String, error: Error, stackTrace: String? = nil) {
        self.workflowId = workflowId
        self.error = error
        self.errorMessage = error.localizedDescription
        self.stackTrace = stackTrace
    }
    
    public var description: String {
        "WorkflowFailedEvent(id: \"workflowId\", error: \"errorMessage\")"
    }
}

/// Job execution events
public struct JobSubmittedEvent: AnigmaEvent {
    public static let eventType = "job.submitted"
    
    public let jobId: String
    public let jobType: String
    public let submittedBy: String?
    
    public init(jobId: String, jobType: String, submittedBy: String? = nil) {
        self.jobId = jobId
        self.jobType = jobType
        self.submittedBy = submittedBy
    }
    
    public var description: String {
        "JobSubmittedEvent(id: \"jobId\", type: \"jobType\")"
    }
}

public struct JobStatusUpdatedEvent: AnigmaEvent {
    public static let eventType = "job.status.updated"
    
    public let jobId: String
    public let status: String
    public let progress: Double?
    
    public init(jobId: String, status: String, progress: Double? = nil) {
        self.jobId = jobId
        self.status = status
        self.progress = progress
    }
    
    public var description: String {
        "JobStatusUpdatedEvent(id: \"jobId\", status: \"status\", progress: \"progress?%%\")"
    }
}

public struct JobTokenEvent: AnigmaEvent {
    public static let eventType = "job.token"
    
    public let jobId: String
    public let token: String
    public let isComplete: Bool
    
    public init(jobId: String, token: String, isComplete: Bool = false) {
        self.jobId = jobId
        self.token = token
        self.isComplete = isComplete
    }
    
    public var description: String {
        "JobTokenEvent(id: \"jobId\", token: \"token\", complete: \"isComplete\")"
    }
}

public struct JobCompletedEvent: AnigmaEvent {
    public static let eventType = "job.completed"
    
    public let jobId: String
    public let result: String?
    public let duration: TimeInterval
    public let success: Bool
    
    public init(jobId: String, result: String? = nil, duration: TimeInterval, success: Bool) {
        self.jobId = jobId
        self.result = result
        self.duration = duration
        self.success = success
    }
    
    public var description: String {
        "JobCompletedEvent(id: \"jobId\", success: \"success\", duration: \"duration\"s)"
    }
}

/// System events
public struct SystemNotificationEvent: AnigmaEvent {
    public static let eventType = "system.notification"
    
    public let notificationId: String
    public let title: String
    public let message: String
    public let severity: String
    public let category: String?
    
    public init(notificationId: String, title: String, message: String, severity: String, category: String? = nil) {
        self.notificationId = notificationId
        self.title = title
        self.message = message
        self.severity = severity
        self.category = category
    }
    
    public var description: String {
        "SystemNotificationEvent(id: \"notificationId\", severity: \"severity\", title: \"title\")"
    }
}

public struct SystemErrorEvent: AnigmaEvent {
    public static let eventType = "system.error"
    
    public let errorId: String
    public let error: Error
    public let context: [String: String]?
    
    public init(errorId: String, error: Error, context: [String: String]? = nil) {
        self.errorId = errorId
        self.error = error
        self.context = context
    }
    
    public var description: String {
        "SystemErrorEvent(id: \"errorId\", error: \"error.localizedDescription\")"
    }
}

/// Agent events
public struct AgentActionStartedEvent: AnigmaEvent {
    public static let eventType = "agent.action.started"
    
    public let agentId: String
    public let action: String
    public let instruction: String
    public let workspaceId: String
    public let jobId: String
    public let timestamp: Date
    
    public init(agentId: String, action: String, instruction: String, workspaceId: String, jobId: String, timestamp: Date = Date()) {
        self.agentId = agentId
        self.action = action
        self.instruction = instruction
        self.workspaceId = workspaceId
        self.jobId = jobId
        self.timestamp = timestamp
    }
    
    public var description: String {
        "AgentActionStartedEvent(agent: \"agentId\", action: \"action\", job: \"jobId\")"
    }
}

public struct AgentActionCompletedEvent: AnigmaEvent {
    public static let eventType = "agent.action.completed"
    
    public let agentId: String
    public let action: String
    public let jobId: String
    public let duration: TimeInterval
    public let success: Bool
    public let result: String?
    public let errorMessage: String?
    
    public init(agentId: String, action: String, jobId: String, duration: TimeInterval, success: Bool, result: String? = nil, errorMessage: String? = nil) {
        self.agentId = agentId
        self.action = action
        self.jobId = jobId
        self.duration = duration
        self.success = success
        self.result = result
        self.errorMessage = errorMessage
    }
    
    public var description: String {
        "AgentActionCompletedEvent(agent: \"agentId\", action: \"action\", success: \"success\", duration: \"duration\"s)"
    }
}

public struct AgentErrorEvent: AnigmaEvent {
    public static let eventType = "agent.error"
    
    public let agentId: String
    public let action: String?
    public let jobId: String?
    public let error: Error
    public let errorMessage: String
    public let context: [String: String]?
    
    public init(agentId: String, action: String?, jobId: String?, error: Error, context: [String: String]? = nil) {
        self.agentId = agentId
        self.action = action
        self.jobId = jobId
        self.error = error
        self.errorMessage = error.localizedDescription
        self.context = context
    }
    
    public var description: String {
        "AgentErrorEvent(agent: \"agentId\", error: \"errorMessage\")"
    }
}

/// MARK: - Data Processing Events

/// Data processing state
public enum DataProcessingState: String, Sendable, Codable {
    case pending
    case processing
    case completed
    case failed
    case cancelled
}

/// Data processing started event
public struct DataProcessingStartedEvent: AnigmaEvent {
    public static let eventType = "data.processing.started"
    
    public let processingId: String
    public let dataSourceId: String
    public let dataType: String
    public let initiatedBy: String?
    public let metadata: [String: String]?
    
    public init(processingId: String, dataSourceId: String, dataType: String, initiatedBy: String? = nil, metadata: [String: String]? = nil) {
        self.processingId = processingId
        self.dataSourceId = dataSourceId
        self.dataType = dataType
        self.initiatedBy = initiatedBy
        self.metadata = metadata
    }
    
    public var description: String {
        "DataProcessingStartedEvent(id: \"processingId\", source: \"dataSourceId\", type: \"dataType\")"
    }
}

/// Data processing progress event
public struct DataProcessingProgressEvent: AnigmaEvent {
    public static let eventType = "data.processing.progress"
    
    public let processingId: String
    public let progress: Double
    public let processedItems: Int
    public let totalItems: Int?
    public let message: String?
    public let stage: String?
    
    public init(processingId: String, progress: Double, processedItems: Int, totalItems: Int? = nil, message: String? = nil, stage: String? = nil) {
        self.processingId = processingId
        self.progress = progress
        self.processedItems = processedItems
        self.totalItems = totalItems
        self.message = message
        self.stage = stage
    }
    
    public var description: String {
        "DataProcessingProgressEvent(id: \"processingId\", progress: \"progress\", items: \"processedItems\"/\"totalItems?\")"
    }
}

/// Data processing completed event
public struct DataProcessingCompletedEvent: AnigmaEvent {
    public static let eventType = "data.processing.completed"
    
    public let processingId: String
    public let result: String?
    public let duration: TimeInterval
    public let success: Bool
    public let processedItems: Int
    public let errorMessage: String?
    
    public init(processingId: String, result: String? = nil, duration: TimeInterval, success: Bool, processedItems: Int, errorMessage: String? = nil) {
        self.processingId = processingId
        self.result = result
        self.duration = duration
        self.success = success
        self.processedItems = processedItems
        self.errorMessage = errorMessage
    }
    
    public var description: String {
        "DataProcessingCompletedEvent(id: \"processingId\", success: \"success\", items: \"processedItems\", duration: \"duration\"s)"
    }
}

/// Data processing failed event
public struct DataProcessingFailedEvent: AnigmaEvent {
    public static let eventType = "data.processing.failed"
    
    public let processingId: String
    public let error: Error
    public let errorMessage: String
    public let processedItems: Int
    public let stackTrace: String?
    
    public init(processingId: String, error: Error, processedItems: Int, stackTrace: String? = nil) {
        self.processingId = processingId
        self.error = error
        self.errorMessage = error.localizedDescription
        self.processedItems = processedItems
        self.stackTrace = stackTrace
    }
    
    public var description: String {
        "DataProcessingFailedEvent(id: \"processingId\", error: \"errorMessage\", items: \"processedItems\")"
    }
}

/// MARK: - Rendering Events

/// Rendering state
public enum RenderingState: String, Sendable, Codable {
    case pending
    case rendering
    case completed
    case failed
    case cancelled
}

/// Rendering started event
public struct RenderingStartedEvent: AnigmaEvent {
    public static let eventType = "rendering.started"
    
    public let renderingId: String
    public let dataId: String
    public let renderType: String
    public let initiatedBy: String?
    public let metadata: [String: String]?
    
    public init(renderingId: String, dataId: String, renderType: String, initiatedBy: String? = nil, metadata: [String: String]? = nil) {
        self.renderingId = renderingId
        self.dataId = dataId
        self.renderType = renderType
        self.initiatedBy = initiatedBy
        self.metadata = metadata
    }
    
    public var description: String {
        "RenderingStartedEvent(id: \"renderingId\", data: \"dataId\", type: \"renderType\")"
    }
}

/// Rendering progress event
public struct RenderingProgressEvent: AnigmaEvent {
    public static let eventType = "rendering.progress"
    
    public let renderingId: String
    public let progress: Double
    public let message: String?
    public let stage: String?
    
    public init(renderingId: String, progress: Double, message: String? = nil, stage: String? = nil) {
        self.renderingId = renderingId
        self.progress = progress
        self.message = message
        self.stage = stage
    }
    
    public var description: String {
        "RenderingProgressEvent(id: \"renderingId\", progress: \"progress\", stage: \"stage\")"
    }
}

/// Rendering completed event
public struct RenderingCompletedEvent: AnigmaEvent {
    public static let eventType = "rendering.completed"
    
    public let renderingId: String
    public let result: String?
    public let duration: TimeInterval
    public let success: Bool
    public let errorMessage: String?
    
    public init(renderingId: String, result: String? = nil, duration: TimeInterval, success: Bool, errorMessage: String? = nil) {
        self.renderingId = renderingId
        self.result = result
        self.duration = duration
        self.success = success
        self.errorMessage = errorMessage
    }
    
    public var description: String {
        "RenderingCompletedEvent(id: \"renderingId\", success: \"success\", duration: \"duration\"s)"
    }
}

/// Rendering failed event
public struct RenderingFailedEvent: AnigmaEvent {
    public static let eventType = "rendering.failed"
    
    public let renderingId: String
    public let error: Error
    public let errorMessage: String
    public let stackTrace: String?
    
    public init(renderingId: String, error: Error, stackTrace: String? = nil) {
        self.renderingId = renderingId
        self.error = error
        self.errorMessage = error.localizedDescription
        self.stackTrace = stackTrace
    }
    
    public var description: String {
        "RenderingFailedEvent(id: \"renderingId\", error: \"errorMessage\")"
    }
}

/// MARK: - Export Events

/// Export state
public enum ExportState: String, Sendable, Codable {
    case pending
    case preparing
    case exporting
    case completed
    case failed
    case cancelled
}

/// Export started event
public struct ExportStartedEvent: AnigmaEvent {
    public static let eventType = "export.started"
    
    public let exportId: String
    public let dataId: String
    public let exportFormat: String
    public let exportPath: String?
    public let initiatedBy: String?
    public let metadata: [String: String]?
    
    public init(exportId: String, dataId: String, exportFormat: String, exportPath: String? = nil, initiatedBy: String? = nil, metadata: [String: String]? = nil) {
        self.exportId = exportId
        self.dataId = dataId
        self.exportFormat = exportFormat
        self.exportPath = exportPath
        self.initiatedBy = initiatedBy
        self.metadata = metadata
    }
    
    public var description: String {
        "ExportStartedEvent(id: \"exportId\", data: \"dataId\", format: \"exportFormat\")"
    }
}

/// Export progress event
public struct ExportProgressEvent: AnigmaEvent {
    public static let eventType = "export.progress"
    
    public let exportId: String
    public let progress: Double
    public let processedItems: Int
    public let totalItems: Int?
    public let message: String?
    public let stage: String?
    
    public init(exportId: String, progress: Double, processedItems: Int, totalItems: Int? = nil, message: String? = nil, stage: String? = nil) {
        self.exportId = exportId
        self.progress = progress
        self.processedItems = processedItems
        self.totalItems = totalItems
        self.message = message
        self.stage = stage
    }
    
    public var description: String {
        "ExportProgressEvent(id: \"exportId\", progress: \"progress\", items: \"processedItems\"/\"totalItems?\")"
    }
}

/// Export completed event
public struct ExportCompletedEvent: AnigmaEvent {
    public static let eventType = "export.completed"
    
    public let exportId: String
    public let result: String?
    public let duration: TimeInterval
    public let success: Bool
    public let exportedItems: Int
    public let exportPath: String?
    public let errorMessage: String?
    
    public init(exportId: String, result: String? = nil, duration: TimeInterval, success: Bool, exportedItems: Int, exportPath: String? = nil, errorMessage: String? = nil) {
        self.exportId = exportId
        self.result = result
        self.duration = duration
        self.success = success
        self.exportedItems = exportedItems
        self.exportPath = exportPath
        self.errorMessage = errorMessage
    }
    
    public var description: String {
        "ExportCompletedEvent(id: \"exportId\", success: \"success\", items: \"exportedItems\", duration: \"duration\"s)"
    }
}

/// Export failed event
public struct ExportFailedEvent: AnigmaEvent {
    public static let eventType = "export.failed"
    
    public let exportId: String
    public let error: Error
    public let errorMessage: String
    public let exportedItems: Int
    public let stackTrace: String?
    
    public init(exportId: String, error: Error, exportedItems: Int, stackTrace: String? = nil) {
        self.exportId = exportId
        self.error = error
        self.errorMessage = error.localizedDescription
        self.exportedItems = exportedItems
        self.stackTrace = stackTrace
    }
    
    public var description: String {
        "ExportFailedEvent(id: \"exportId\", error: \"errorMessage\", items: \"exportedItems\")"
    }
}

/// MARK: - Work Item Events

/// Work item state
public enum WorkItemState: String, Sendable, Codable {
    case created
    case queued
    case processing
    case completed
    case failed
    case cancelled
}

/// Work item created event
public struct WorkItemCreatedEvent: AnigmaEvent {
    public static let eventType = "workitem.created"
    
    public let workItemId: String
    public let workItemType: String
    public let priority: Int
    public let createdBy: String?
    public let metadata: [String: String]?
    
    public init(workItemId: String, workItemType: String, priority: Int = 0, createdBy: String? = nil, metadata: [String: String]? = nil) {
        self.workItemId = workItemId
        self.workItemType = workItemType
        self.priority = priority
        self.createdBy = createdBy
        self.metadata = metadata
    }
    
    public var description: String {
        "WorkItemCreatedEvent(id: \"workItemId\", type: \"workItemType\", priority: \"priority\")"
    }
}

/// Work item started event
public struct WorkItemStartedEvent: AnigmaEvent {
    public static let eventType = "workitem.started"
    
    public let workItemId: String
    public let startedBy: String?
    public let timestamp: Date
    
    public init(workItemId: String, startedBy: String? = nil, timestamp: Date = Date()) {
        self.workItemId = workItemId
        self.startedBy = startedBy
        self.timestamp = timestamp
    }
    
    public var description: String {
        "WorkItemStartedEvent(id: \"workItemId\", startedBy: \"startedBy?\")"
    }
}

/// Work item progress event
public struct WorkItemProgressEvent: AnigmaEvent {
    public static let eventType = "workitem.progress"
    
    public let workItemId: String
    public let progress: Double
    public let message: String?
    public let stage: String?
    
    public init(workItemId: String, progress: Double, message: String? = nil, stage: String? = nil) {
        self.workItemId = workItemId
        self.progress = progress
        self.message = message
        self.stage = stage
    }
    
    public var description: String {
        "WorkItemProgressEvent(id: \"workItemId\", progress: \"progress\", stage: \"stage\")"
    }
}

/// Work item completed event
public struct WorkItemCompletedEvent: AnigmaEvent {
    public static let eventType = "workitem.completed"
    
    public let workItemId: String
    public let result: String?
    public let duration: TimeInterval
    public let success: Bool
    public let errorMessage: String?
    
    public init(workItemId: String, result: String? = nil, duration: TimeInterval, success: Bool, errorMessage: String? = nil) {
        self.workItemId = workItemId
        self.result = result
        self.duration = duration
        self.success = success
        self.errorMessage = errorMessage
    }
    
    public var description: String {
        "WorkItemCompletedEvent(id: \"workItemId\", success: \"success\", duration: \"duration\"s)"
    }
}

/// Work item failed event
public struct WorkItemFailedEvent: AnigmaEvent {
    public static let eventType = "workitem.failed"
    
    public let workItemId: String
    public let error: Error
    public let errorMessage: String
    public let duration: TimeInterval
    public let stackTrace: String?
    
    public init(workItemId: String, error: Error, duration: TimeInterval, stackTrace: String? = nil) {
        self.workItemId = workItemId
        self.error = error
        self.errorMessage = error.localizedDescription
        self.duration = duration
        self.stackTrace = stackTrace
    }
    
    public var description: String {
        "WorkItemFailedEvent(id: \"workItemId\", error: \"errorMessage\", duration: \"duration\"s)"
    }
}

/// MARK: - UI Interaction Events

/// UI interaction event
public struct UIInteractionEvent: AnigmaEvent {
    public static let eventType = "ui.interaction"
    
    public let interactionId: String
    public let interactionType: String
    public let componentId: String
    public let userId: String?
    public let timestamp: Date
    public let metadata: [String: String]?
    
    public init(interactionId: String, interactionType: String, componentId: String, userId: String? = nil, timestamp: Date = Date(), metadata: [String: String]? = nil) {
        self.interactionId = interactionId
        self.interactionType = interactionType
        self.componentId = componentId
        self.userId = userId
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    public var description: String {
        "UIInteractionEvent(id: \"interactionId\", type: \"interactionType\", component: \"componentId\")"
    }
}

/// UI state updated event
public struct UIStateUpdatedEvent: AnigmaEvent {
    public static let eventType = "ui.state.updated"
    
    public let componentId: String
    public let stateType: String
    public let newState: String
    public let oldState: String?
    public let timestamp: Date
    
    public init(componentId: String, stateType: String, newState: String, oldState: String? = nil, timestamp: Date = Date()) {
        self.componentId = componentId
        self.stateType = stateType
        self.newState = newState
        self.oldState = oldState
        self.timestamp = timestamp
    }
    
    public var description: String {
        "UIStateUpdatedEvent(component: \"componentId\", state: \"stateType\", new: \"newState\")"
    }
}

/// Generic UI event
public struct UIEvent: AnigmaEvent {
    public static let eventType = "ui.event"
    
    public let eventId: String
    public let eventType: String
    public let componentId: String
    public let payload: [String: String]?
    public let timestamp: Date
    
    public init(eventId: String, eventType: String, componentId: String, payload: [String: String]? = nil, timestamp: Date = Date()) {
        self.eventId = eventId
        self.eventType = eventType
        self.componentId = componentId
        self.payload = payload
        self.timestamp = timestamp
    }
    
    public var description: String {
        "UIEvent(id: \"eventId\", type: \"eventType\", component: \"componentId\")"
    }
}
