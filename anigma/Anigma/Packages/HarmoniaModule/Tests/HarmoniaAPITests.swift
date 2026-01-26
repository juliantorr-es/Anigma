// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import XCTest
@testable import HarmoniaModule
@testable import HarmoniaAPI

// MARK: - Harmonia API Tests

final class HarmoniaAPITests: XCTestCase {
    
    var coordinator: HarmoniaCoordinator!
    var handler: HarmoniaAPIHandler!
    var server: HarmoniaHTTPServer!
    
    override func setUp() async throws {
        try await super.setUp()
        coordinator = HarmoniaCoordinator()
        handler = HarmoniaAPIHandler(coordinator: coordinator)
        server = HarmoniaHTTPServer(handler: handler, port: 8080)
    }
    
    // MARK: - Workflow Submission Tests
    
    func testSubmitValidWorkflow() async throws {
        // Create test workflow
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        let definition = WorkflowDefinition(
            id: "wf-1",
            name: "Test Workflow",
            description: "A test workflow",
            steps: [step],
            parallelizable: false
        )
        
        let request = SubmitWorkflowRequest(definition: definition)
        
        // Submit workflow
        let response = try await handler.submitWorkflow(request)
        
        // Assertions
        XCTAssertFalse(response.executionId.isEmpty)
        XCTAssertEqual(response.state, .pending)
        XCTAssertEqual(response.message, "Workflow 'Test Workflow' submitted successfully")
    }
    
    func testSubmitWorkflowWithRetryPolicy() async throws {
        let step = WorkflowStep(
            id: "step-retry",
            serviceId: "resilient-service",
            action: "process",
            retryCount: 3
        )
        
        let retryPolicy = RetryPolicy(
            maxRetries: 3,
            backoffMultiplier: 2.0,
            initialDelay: 1.0,
            maxDelay: 30.0
        )
        
        let definition = WorkflowDefinition(
            id: "wf-retry",
            name: "Resilient Workflow",
            steps: [step],
            parallelizable: false,
            retryPolicy: retryPolicy
        )
        
        let request = SubmitWorkflowRequest(definition: definition)
        let response = try await handler.submitWorkflow(request)
        
        XCTAssertEqual(response.state, .pending)
        
        // Verify workflow exists
        let status = try await handler.getWorkflowStatus(executionId: response.executionId)
        XCTAssertEqual(status.execution.state, .pending)
    }
    
    // MARK: - Workflow Status Tests
    
    func testGetWorkflowStatus() async throws {
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        let definition = WorkflowDefinition(
            id: "wf-1",
            name: "Status Test",
            steps: [step]
        )
        
        let submitRequest = SubmitWorkflowRequest(definition: definition)
        let submitResponse = try await handler.submitWorkflow(submitRequest)
        
        let statusResponse = try await handler.getWorkflowStatus(executionId: submitResponse.executionId)
        
        XCTAssertEqual(statusResponse.execution.id, submitResponse.executionId)
        XCTAssertEqual(statusResponse.execution.definitionId, "wf-1")
        XCTAssertGreaterThanOrEqual(statusResponse.progress, 0.0)
        XCTAssertLessThanOrEqual(statusResponse.progress, 1.0)
    }
    
    func testGetNonexistentWorkflow() async throws {
        do {
            _ = try await handler.getWorkflowStatus(executionId: "nonexistent")
            XCTFail("Should throw workflowNotFound error")
        } catch APIHandlerError.workflowNotFound(let id) {
            XCTAssertEqual(id, "nonexistent")
        }
    }
    
    // MARK: - Workflow Listing Tests
    
    func testListAllWorkflows() async throws {
        // Submit multiple workflows
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        for i in 0..<3 {
            let definition = WorkflowDefinition(
                id: "wf-\(i)",
                name: "Workflow \(i)",
                steps: [step]
            )
            let request = SubmitWorkflowRequest(definition: definition)
            _ = try await handler.submitWorkflow(request)
        }
        
        let response = await handler.listWorkflows(state: nil)
        
        XCTAssertGreaterThanOrEqual(response.total, 3)
        XCTAssertEqual(response.workflows.count, response.total)
    }
    
    func testListWorkflowsByState() async throws {
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        let definition = WorkflowDefinition(
            id: "wf-pending",
            name: "Pending Workflow",
            steps: [step]
        )
        
        let request = SubmitWorkflowRequest(definition: definition)
        _ = try await handler.submitWorkflow(request)
        
        let response = await handler.listWorkflows(state: .pending)
        
        XCTAssertGreaterThan(response.total, 0)
        XCTAssert(response.workflows.allSatisfy { $0.state == .pending })
    }
    
    // MARK: - Workflow Control Tests
    
    func testCancelWorkflow() async throws {
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        let definition = WorkflowDefinition(
            id: "wf-cancel",
            name: "Workflow to Cancel",
            steps: [step]
        )
        
        let submitRequest = SubmitWorkflowRequest(definition: definition)
        let submitResponse = try await handler.submitWorkflow(submitRequest)
        
        let cancelResponse = try await handler.cancelWorkflow(executionId: submitResponse.executionId)
        
        XCTAssertEqual(cancelResponse.executionId, submitResponse.executionId)
        XCTAssertEqual(cancelResponse.action, "cancelled")
        XCTAssertEqual(cancelResponse.newState, .cancelled)
    }
    
    func testCancelNonexistentWorkflow() async throws {
        do {
            _ = try await handler.cancelWorkflow(executionId: "nonexistent")
            XCTFail("Should throw workflowNotFound error")
        } catch APIHandlerError.workflowNotFound(let id) {
            XCTAssertEqual(id, "nonexistent")
        }
    }
    
    func testPauseWorkflow() async throws {
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        let definition = WorkflowDefinition(
            id: "wf-pause",
            name: "Workflow to Pause",
            steps: [step]
        )
        
        let submitRequest = SubmitWorkflowRequest(definition: definition)
        let submitResponse = try await handler.submitWorkflow(submitRequest)
        
        // Pause workflow (can only pause pending/running)
        let pauseResponse = try await handler.pauseWorkflow(executionId: submitResponse.executionId)
        
        XCTAssertEqual(pauseResponse.action, "paused")
    }
    
    func testResumeWorkflow() async throws {
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        let definition = WorkflowDefinition(
            id: "wf-resume",
            name: "Workflow to Resume",
            steps: [step]
        )
        
        let submitRequest = SubmitWorkflowRequest(definition: definition)
        let submitResponse = try await handler.submitWorkflow(submitRequest)
        
        // Pause first
        _ = try await handler.pauseWorkflow(executionId: submitResponse.executionId)
        
        // Then resume
        let resumeResponse = try await handler.resumeWorkflow(executionId: submitResponse.executionId)
        
        XCTAssertEqual(resumeResponse.action, "resumed")
        XCTAssertEqual(resumeResponse.newState, .running)
    }
    
    // MARK: - Workflow Result Tests
    
    func testGetWorkflowResultNotCompleted() async throws {
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        let definition = WorkflowDefinition(
            id: "wf-result",
            name: "Result Test",
            steps: [step]
        )
        
        let submitRequest = SubmitWorkflowRequest(definition: definition)
        let submitResponse = try await handler.submitWorkflow(submitRequest)
        
        // Try to get result from incomplete workflow
        do {
            _ = try await handler.getWorkflowResult(executionId: submitResponse.executionId)
            XCTFail("Should throw workflowNotCompleted error")
        } catch APIHandlerError.workflowNotCompleted(let id, _) {
            XCTAssertEqual(id, submitResponse.executionId)
        }
    }
    
    // MARK: - Service Management Tests
    
    func testListServices() async throws {
        let response = await handler.listServices()
        
        XCTAssertGreaterThanOrEqual(response.total, 0)
        XCTAssertEqual(response.services.count, response.total)
    }
    
    func testGetServiceHealth() async throws {
        let services = await handler.listServices()
        
        if let firstService = services.services.first {
            let healthResponse = try await handler.getServiceHealth(serviceId: firstService.id)
            
            XCTAssertEqual(healthResponse.serviceId, firstService.id)
            // Health status should be one of the defined values
            XCTAssert([.healthy, .degraded, .unhealthy, .unknown].contains(healthResponse.health))
        }
    }
    
    func testGetNonexistentServiceHealth() async throws {
        do {
            _ = try await handler.getServiceHealth(serviceId: "nonexistent-service")
            XCTFail("Should throw serviceNotFound error")
        } catch APIHandlerError.serviceNotFound(let id) {
            XCTAssertEqual(id, "nonexistent-service")
        }
    }
    
    // MARK: - HTTP Server Tests
    
    func testHTTPServerRequestRouting() async throws {
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute"
        )
        
        let definition = WorkflowDefinition(
            id: "wf-http",
            name: "HTTP Test",
            steps: [step]
        )
        
        let request = SubmitWorkflowRequest(definition: definition)
        let encoder = JSONEncoder()
        let requestBody = try encoder.encode(request)
        
        let responseData = await server.handleRequest(
            method: "POST",
            path: "/api/workflows/submit",
            body: requestBody
        )
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(APIResponse<SubmitWorkflowResponse>.self, from: responseData)
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.data)
        XCTAssertNil(response.error)
    }
    
    func testHTTPServerErrorHandling() async throws {
        let responseData = await server.handleRequest(
            method: "GET",
            path: "/api/workflows/invalid-id",
            body: nil
        )
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(APIResponse<WorkflowStatusResponse>.self, from: responseData)
        
        XCTAssertFalse(response.success)
        XCTAssertNil(response.data)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, "WORKFLOW_NOT_FOUND")
    }
    
    // MARK: - Error Code Mapping Tests
    
    func testErrorCodeMapping() {
        let errors: [(APIHandlerError, Int, String)] = [
            (.workflowNotFound("test"), 404, "WORKFLOW_NOT_FOUND"),
            (.serviceNotFound("test"), 404, "SERVICE_NOT_FOUND"),
            (.workflowNotCompleted("test", reason: "pending"), 409, "WORKFLOW_NOT_COMPLETED"),
            (.invalidRequest("invalid"), 400, "INVALID_REQUEST"),
            (.invalidStateTransition(from: .completed, reason: "test"), 409, "INVALID_STATE_TRANSITION"),
        ]
        
        for (error, expectedStatus, expectedCode) in errors {
            XCTAssertEqual(error.statusCode, expectedStatus)
            XCTAssertEqual(error.errorCode, expectedCode)
        }
    }
}

// MARK: - Integration Tests

final class HarmoniaAPIIntegrationTests: XCTestCase {
    
    var coordinator: HarmoniaCoordinator!
    var handler: HarmoniaAPIHandler!
    
    override func setUp() async throws {
        try await super.setUp()
        coordinator = HarmoniaCoordinator()
        handler = HarmoniaAPIHandler(coordinator: coordinator)
    }
    
    func testCompleteWorkflowLifecycle() async throws {
        // Create workflow
        let step = WorkflowStep(
            id: "step-1",
            serviceId: "test-service",
            action: "execute",
            timeout: 30.0
        )
        
        let definition = WorkflowDefinition(
            id: "wf-lifecycle",
            name: "Lifecycle Test",
            description: "Complete workflow lifecycle",
            steps: [step],
            parallelizable: false
        )
        
        // Submit
        let submitRequest = SubmitWorkflowRequest(definition: definition)
        let submitResponse = try await handler.submitWorkflow(submitRequest)
        let executionId = submitResponse.executionId
        
        XCTAssertEqual(submitResponse.state, .pending)
        
        // Check status
        var statusResponse = try await handler.getWorkflowStatus(executionId: executionId)
        XCTAssertEqual(statusResponse.execution.state, .pending)
        
        // Try to pause (pending workflow can be paused)
        let pauseResponse = try await handler.pauseWorkflow(executionId: executionId)
        XCTAssertEqual(pauseResponse.newState, .paused)
        
        // Resume
        let resumeResponse = try await handler.resumeWorkflow(executionId: executionId)
        XCTAssertEqual(resumeResponse.newState, .running)
        
        // List workflows
        let listResponse = await handler.listWorkflows(state: nil)
        XCTAssertGreaterThan(listResponse.total, 0)
        
        // Cancel
        let cancelResponse = try await handler.cancelWorkflow(executionId: executionId)
        XCTAssertEqual(cancelResponse.newState, .cancelled)
        
        // Verify final state
        statusResponse = try await handler.getWorkflowStatus(executionId: executionId)
        XCTAssertEqual(statusResponse.execution.state, .cancelled)
    }
}
