// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import HarmoniaAPIContracts
import HarmoniaWorkflowContracts
import HarmoniaV2Surface

// MARK: - Harmonia HTTP API Handler

/// Main HTTP API handler for HarmoniaModule workflow orchestration.
///
/// This handler exposes all workflow management and service discovery capabilities
/// through a RESTful HTTP API. It manages the separation of concerns between the
/// HTTP protocol layer and the HarmoniaCoordinator actor.
///
/// Integration pattern:
/// ```
/// let handler = HarmoniaAPIHandler(coordinator: HarmoniaCoordinator.shared)
/// // Route HTTP requests to handler methods
/// ```
///
/// Thread-safety: All coordinator access is actor-safe through async/await.
public actor HarmoniaAPIHandler {
    private let coordinator: HarmoniaCoordinator
    
    /// Initialize the API handler with a coordinator instance.
    /// - Parameter coordinator: The HarmoniaCoordinator instance managing workflows
    public init(coordinator: HarmoniaCoordinator) {
        self.coordinator = coordinator
    }
    
    // MARK: - Workflow Submission
    
    /// POST /api/workflows/submit
    /// Submit a new workflow for execution
    ///
    /// - Parameter request: SubmitWorkflowRequest containing workflow definition
    /// - Returns: SubmitWorkflowResponse with execution ID and initial state
    /// - Throws: APIHandlerError for invalid workflow definitions or coordinator errors
    public func submitWorkflow(_ request: SubmitWorkflowRequest) async throws -> SubmitWorkflowResponse {
        do {
            let execution = try await coordinator.submitWorkflow(request.definition)
            return SubmitWorkflowResponse(
                executionId: execution.id,
                state: execution.state,
                message: "Workflow '\(request.definition.name)' submitted successfully"
            )
        } catch {
            throw APIHandlerError.workflowSubmissionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Workflow Status
    
    /// GET /api/workflows/{id}
    /// Get the current status and progress of a workflow execution
    ///
    /// - Parameter executionId: The workflow execution ID
    /// - Returns: WorkflowStatusResponse with execution details and step statuses
    /// - Throws: APIHandlerError.workflowNotFound if execution doesn't exist
    public func getWorkflowStatus(executionId: String) async throws -> WorkflowStatusResponse {
        do {
            let execution = try await coordinator.getWorkflowStatus(executionId: executionId)
            return WorkflowStatusResponse(execution: execution)
        } catch CoordinatorError.workflowNotFound {
            throw APIHandlerError.workflowNotFound(executionId)
        } catch {
            throw APIHandlerError.statusRetrievalFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Workflow Listing
    
    /// GET /api/workflows?state=running
    /// List all workflows with optional state filtering
    ///
    /// - Parameter state: Optional WorkflowState filter (pending, running, completed, etc.)
    /// - Returns: ListWorkflowsResponse with filtered workflow summaries
    public func listWorkflows(state: WorkflowState? = nil) async -> ListWorkflowsResponse {
        let workflows = await coordinator.listWorkflows(state: state)
        return ListWorkflowsResponse(workflows: workflows)
    }
    
    // MARK: - Workflow Control
    
    /// POST /api/workflows/{id}/cancel
    /// Cancel a running or pending workflow
    ///
    /// - Parameter executionId: The workflow execution ID to cancel
    /// - Returns: WorkflowControlResponse confirming cancellation
    /// - Throws: APIHandlerError for invalid state transitions or missing workflow
    public func cancelWorkflow(executionId: String) async throws -> WorkflowControlResponse {
        do {
            try await coordinator.cancelWorkflow(executionId: executionId)
            let execution = try await coordinator.getWorkflowStatus(executionId: executionId)
            return WorkflowControlResponse(
                executionId: executionId,
                action: "cancelled",
                newState: execution.state
            )
        } catch CoordinatorError.workflowNotFound {
            throw APIHandlerError.workflowNotFound(executionId)
        } catch CoordinatorError.invalidWorkflowState(let state, let reason) {
            throw APIHandlerError.invalidStateTransition(from: state, reason: reason)
        } catch {
            throw APIHandlerError.controlOperationFailed("cancel", error.localizedDescription)
        }
    }
    
    /// POST /api/workflows/{id}/pause
    /// Pause a running workflow
    ///
    /// - Parameter executionId: The workflow execution ID to pause
    /// - Returns: WorkflowControlResponse confirming pause
    /// - Throws: APIHandlerError for invalid state or missing workflow
    public func pauseWorkflow(executionId: String) async throws -> WorkflowControlResponse {
        do {
            try await coordinator.pauseWorkflow(executionId: executionId)
            let execution = try await coordinator.getWorkflowStatus(executionId: executionId)
            return WorkflowControlResponse(
                executionId: executionId,
                action: "paused",
                newState: execution.state
            )
        } catch CoordinatorError.workflowNotFound {
            throw APIHandlerError.workflowNotFound(executionId)
        } catch CoordinatorError.invalidWorkflowState(let state, let reason) {
            throw APIHandlerError.invalidStateTransition(from: state, reason: reason)
        } catch {
            throw APIHandlerError.controlOperationFailed("pause", error.localizedDescription)
        }
    }
    
    /// POST /api/workflows/{id}/resume
    /// Resume a paused workflow
    ///
    /// - Parameter executionId: The workflow execution ID to resume
    /// - Returns: WorkflowControlResponse confirming resume
    /// - Throws: APIHandlerError for invalid state or missing workflow
    public func resumeWorkflow(executionId: String) async throws -> WorkflowControlResponse {
        do {
            try await coordinator.resumeWorkflow(executionId: executionId)
            let execution = try await coordinator.getWorkflowStatus(executionId: executionId)
            return WorkflowControlResponse(
                executionId: executionId,
                action: "resumed",
                newState: execution.state
            )
        } catch CoordinatorError.workflowNotFound {
            throw APIHandlerError.workflowNotFound(executionId)
        } catch CoordinatorError.invalidWorkflowState(let state, let reason) {
            throw APIHandlerError.invalidStateTransition(from: state, reason: reason)
        } catch {
            throw APIHandlerError.controlOperationFailed("resume", error.localizedDescription)
        }
    }
    
    // MARK: - Workflow Results
    
    /// GET /api/workflows/{id}/result
    /// Get aggregated results from a completed workflow
    ///
    /// - Parameter executionId: The workflow execution ID
    /// - Returns: WorkflowResultResponse with results and execution details
    /// - Throws: APIHandlerError if workflow not found or not completed
    public func getWorkflowResult(executionId: String) async throws -> WorkflowResultResponse {
        do {
            let results = try await coordinator.getWorkflowResult(executionId: executionId)
            let execution = try await coordinator.getWorkflowStatus(executionId: executionId)
            return WorkflowResultResponse(
                executionId: executionId,
                state: execution.state,
                results: results,
                duration: execution.duration
            )
        } catch CoordinatorError.workflowNotFound {
            throw APIHandlerError.workflowNotFound(executionId)
        } catch CoordinatorError.workflowNotCompleted(_, let reason) {
            throw APIHandlerError.workflowNotCompleted(executionId, reason: reason)
        } catch {
            throw APIHandlerError.resultRetrievalFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Service Discovery
    
    /// GET /api/services
    /// List all registered services
    ///
    /// - Returns: ServicesListResponse with all available service descriptors
    public func listServices() async -> ServicesListResponse {
        let services = await coordinator.getAvailableServices()
        return ServicesListResponse(services: services)
    }
    
    /// POST /api/services/{id}/health
    /// Get health status of a specific service
    ///
    /// - Parameter serviceId: The service ID to check
    /// - Returns: ServiceHealthResponse with current health status
    /// - Throws: APIHandlerError if service not found
    public func getServiceHealth(serviceId: String) async throws -> ServiceHealthResponse {
        let services = await coordinator.getAvailableServices()
        
        guard let service = services.first(where: { $0.id == serviceId }) else {
            throw APIHandlerError.serviceNotFound(serviceId)
        }
        
        return ServiceHealthResponse(
            serviceId: serviceId,
            health: service.healthStatus,
            lastCheck: service.lastHealthCheck
        )
    }
}

// MARK: - API Handler Errors

/// Errors that can occur during API handler operations
public enum APIHandlerError: LocalizedError, Sendable {
    case workflowNotFound(String)
    case workflowNotCompleted(String, reason: String)
    case serviceNotFound(String)
    case invalidStateTransition(from: WorkflowState, reason: String)
    case workflowSubmissionFailed(String)
    case statusRetrievalFailed(String)
    case controlOperationFailed(String, String)
    case resultRetrievalFailed(String)
    case invalidRequest(String)
    
    public var errorDescription: String? {
        switch self {
        case .workflowNotFound(let id):
            return "Workflow execution not found: \(id)"
        case .workflowNotCompleted(let id, let reason):
            return "Workflow \(id) has not completed: \(reason)"
        case .serviceNotFound(let id):
            return "Service not found: \(id)"
        case .invalidStateTransition(let state, let reason):
            return "Invalid state transition from \(state): \(reason)"
        case .workflowSubmissionFailed(let reason):
            return "Failed to submit workflow: \(reason)"
        case .statusRetrievalFailed(let reason):
            return "Failed to retrieve status: \(reason)"
        case .controlOperationFailed(let operation, let reason):
            return "Failed to \(operation) workflow: \(reason)"
        case .resultRetrievalFailed(let reason):
            return "Failed to retrieve results: \(reason)"
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        }
    }
    
    // MARK: - HTTP Status Code Mapping
    
    public var statusCode: Int {
        switch self {
        case .workflowNotFound, .serviceNotFound:
            return 404
        case .invalidStateTransition, .workflowNotCompleted:
            return 409
        case .invalidRequest:
            return 400
        default:
            return 500
        }
    }
    
    public var errorCode: String {
        switch self {
        case .workflowNotFound:
            return "WORKFLOW_NOT_FOUND"
        case .workflowNotCompleted:
            return "WORKFLOW_NOT_COMPLETED"
        case .serviceNotFound:
            return "SERVICE_NOT_FOUND"
        case .invalidStateTransition:
            return "INVALID_STATE_TRANSITION"
        case .workflowSubmissionFailed:
            return "WORKFLOW_SUBMISSION_FAILED"
        case .statusRetrievalFailed:
            return "STATUS_RETRIEVAL_FAILED"
        case .controlOperationFailed:
            return "CONTROL_OPERATION_FAILED"
        case .resultRetrievalFailed:
            return "RESULT_RETRIEVAL_FAILED"
        case .invalidRequest:
            return "INVALID_REQUEST"
        }
    }
}
