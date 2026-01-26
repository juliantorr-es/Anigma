# HarmoniaAPI Integration Guide

## Overview

HarmoniaAPI provides a complete HTTP API for managing workflow orchestration through HarmoniaModule. The API is built on Swift async/await and integrates seamlessly with AnigmaDaemonCore.

## Architecture

```
HTTP Request
    ↓
HarmoniaHTTPServer (routes & serializes)
    ↓
HarmoniaAPIHandler (validates & orchestrates)
    ↓
HarmoniaCoordinator (actor-safe workflow management)
    ↓
HarmoniaModule (execution engine)
```

## Quick Start

### 1. Initialize Components

```swift
import HarmoniaModule
import HarmoniaAPI

// Create coordinator instance
let coordinator = HarmoniaCoordinator.shared

// Create API handler
let apiHandler = HarmoniaAPIHandler(coordinator: coordinator)

// Create HTTP server
let server = HarmoniaHTTPServer(handler: apiHandler, port: 8080)
```

### 2. Route HTTP Requests

```swift
func handleHTTPRequest(method: String, path: String, body: Data?) async -> HTTPResponse {
    let responseBody = await server.handleRequest(method: method, path: path, body: body)
    return HTTPResponse(statusCode: 200, body: responseBody)
}
```

### 3. Handle Responses

All responses follow the standard envelope:

```json
{
  "success": true,
  "data": { /* endpoint-specific data */ },
  "error": null,
  "timestamp": "2025-01-26T12:34:56.789Z"
}
```

Error responses:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "WORKFLOW_NOT_FOUND",
    "message": "Workflow execution not found: abc123",
    "statusCode": 404
  },
  "timestamp": "2025-01-26T12:34:56.789Z"
}
```

## API Endpoints

### Workflow Management

#### Submit Workflow
**POST** `/api/workflows/submit`

Request:
```json
{
  "definition": {
    "id": "wf-001",
    "name": "Data Pipeline",
    "description": "Process data in stages",
    "steps": [
      {
        "id": "step-1",
        "serviceId": "data-processor",
        "action": "validate",
        "input": { "format": "json" }
      }
    ],
    "parallelizable": false,
    "retryPolicy": {
      "maxRetries": 3,
      "backoffMultiplier": 2.0,
      "initialDelay": 1.0,
      "maxDelay": 60.0
    },
    "timeout": 3600
  }
}
```

Response:
```json
{
  "success": true,
  "data": {
    "executionId": "exec-uuid-12345",
    "state": "pending",
    "message": "Workflow 'Data Pipeline' submitted successfully"
  }
}
```

#### Get Workflow Status
**GET** `/api/workflows/{executionId}`

Response:
```json
{
  "success": true,
  "data": {
    "execution": {
      "id": "exec-uuid-12345",
      "definitionId": "wf-001",
      "state": "running",
      "steps": [
        {
          "id": "step-exec-1",
          "stepId": "step-1",
          "state": "completed",
          "retryCount": 0
        }
      ],
      "startTime": "2025-01-26T12:00:00.000Z",
      "endTime": null
    },
    "progress": 0.5,
    "stepStatuses": [...]
  }
}
```

#### List Workflows
**GET** `/api/workflows?state=running`

Query Parameters:
- `state` (optional): Filter by state (pending, running, paused, completed, failed, cancelled)

Response:
```json
{
  "success": true,
  "data": {
    "workflows": [
      {
        "id": "exec-uuid-12345",
        "definitionId": "wf-001",
        "state": "running",
        "progress": 0.5,
        "duration": 123.45,
        "stepCount": 4
      }
    ],
    "total": 1
  }
}
```

#### Cancel Workflow
**POST** `/api/workflows/{executionId}/cancel`

Response:
```json
{
  "success": true,
  "data": {
    "executionId": "exec-uuid-12345",
    "action": "cancelled",
    "newState": "cancelled",
    "message": "Workflow cancel successful"
  }
}
```

#### Pause Workflow
**POST** `/api/workflows/{executionId}/pause`

Response: Similar to cancel

#### Resume Workflow
**POST** `/api/workflows/{executionId}/resume`

Response: Similar to cancel

#### Get Workflow Result
**GET** `/api/workflows/{executionId}/result`

Response:
```json
{
  "success": true,
  "data": {
    "executionId": "exec-uuid-12345",
    "state": "completed",
    "results": {
      "step-1": { "status": "success", "output": "value" }
    },
    "duration": 234.56
  }
}
```

### Service Management

#### List Services
**GET** `/api/services`

Response:
```json
{
  "success": true,
  "data": {
    "services": [
      {
        "id": "data-processor",
        "name": "Data Processor",
        "version": "1.0.0",
        "capabilities": [
          {
            "action": "validate",
            "inputType": "JSON",
            "outputType": "JSON",
            "timeout": 30.0
          }
        ],
        "healthStatus": "healthy",
        "lastHealthCheck": "2025-01-26T12:30:00.000Z"
      }
    ],
    "total": 1
  }
}
```

#### Get Service Health
**POST** `/api/services/{serviceId}/health`

Response:
```json
{
  "success": true,
  "data": {
    "serviceId": "data-processor",
    "health": "healthy",
    "lastCheck": "2025-01-26T12:30:00.000Z"
  }
}
```

## Error Handling

### Error Codes

| Code | HTTP Status | Description |
|------|------------|-------------|
| WORKFLOW_NOT_FOUND | 404 | Execution ID doesn't exist |
| WORKFLOW_NOT_COMPLETED | 409 | Workflow hasn't finished |
| SERVICE_NOT_FOUND | 404 | Service ID doesn't exist |
| INVALID_STATE_TRANSITION | 409 | Can't perform action in current state |
| WORKFLOW_SUBMISSION_FAILED | 500 | Failed to start workflow |
| INVALID_REQUEST | 400 | Request validation failed |

### Error Response Example

```swift
do {
    let result = try await handler.getWorkflowStatus(executionId: "invalid")
} catch APIHandlerError.workflowNotFound(let id) {
    let error = APIError(
        code: "WORKFLOW_NOT_FOUND",
        message: "Workflow execution not found: \(id)",
        statusCode: 404
    )
}
```

## Integration with AnigmaDaemonCore

### Example: HTTP Server Integration

```swift
import AnigmaDaemonCore
import HarmoniaModule
import HarmoniaAPI

public class HarmoniaHTTPRouter {
    private let server: HarmoniaHTTPServer
    
    public init(config: DaemonConfig) {
        let coordinator = HarmoniaCoordinator.shared
        let handler = HarmoniaAPIHandler(coordinator: coordinator)
        self.server = HarmoniaHTTPServer(handler: handler, port: UInt16(config.apiPort))
    }
    
    public func route(request: HTTPRequest) async -> HTTPResponse {
        let responseData = await server.handleRequest(
            method: request.method,
            path: request.path,
            body: request.body
        )
        
        return HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: responseData
        )
    }
}
```

### Example: Daemon Integration

```swift
class AnigmaDaemon {
    private let harmoniaRouter: HarmoniaHTTPRouter
    
    init(config: DaemonConfig) {
        self.harmoniaRouter = HarmoniaHTTPRouter(config: config)
    }
    
    func handleIncomingRequest(_ request: HTTPRequest) async {
        if request.path.hasPrefix("/api/workflows") || request.path.hasPrefix("/api/services") {
            let response = await harmoniaRouter.route(request: request)
            // Send response
        }
    }
}
```

## Testing

### Manual Testing with curl

```bash
# Submit workflow
curl -X POST http://localhost:8080/api/workflows/submit \
  -H "Content-Type: application/json" \
  -d @workflow.json

# Get status
curl http://localhost:8080/api/workflows/exec-uuid-12345

# List all workflows
curl http://localhost:8080/api/workflows

# List running workflows
curl "http://localhost:8080/api/workflows?state=running"

# Cancel workflow
curl -X POST http://localhost:8080/api/workflows/exec-uuid-12345/cancel

# Get result
curl http://localhost:8080/api/workflows/exec-uuid-12345/result

# List services
curl http://localhost:8080/api/services

# Check service health
curl -X POST http://localhost:8080/api/services/data-processor/health
```

### Unit Testing

```swift
@main
struct HarmoniaAPITests {
    func testSubmitWorkflow() async throws {
        let coordinator = HarmoniaCoordinator()
        let handler = HarmoniaAPIHandler(coordinator: coordinator)
        
        let workflow = WorkflowDefinition(
            id: "test-wf",
            name: "Test",
            steps: []
        )
        
        let request = SubmitWorkflowRequest(definition: workflow)
        let response = try await handler.submitWorkflow(request)
        
        assert(response.state == .pending)
    }
    
    func testWorkflowNotFound() async throws {
        let coordinator = HarmoniaCoordinator()
        let handler = HarmoniaAPIHandler(coordinator: coordinator)
        
        do {
            _ = try await handler.getWorkflowStatus(executionId: "invalid")
            XCTFail("Should throw workflowNotFound")
        } catch APIHandlerError.workflowNotFound {
            // Expected
        }
    }
}
```

## Performance Considerations

1. **Async/Await**: All coordinator calls are non-blocking
2. **Actor Safety**: HarmoniaCoordinator serializes access internally
3. **JSON Encoding**: Configured with optimal DateFormatter
4. **Memory**: Workflows are stored in coordinator's internal dictionary
5. **Concurrency**: Multiple HTTP requests handled concurrently

## Security Notes

- Validate workflow definitions before submission
- Authenticate HTTP requests at daemon level
- Rate limit API endpoints
- Use HTTPS in production
- Implement request/response logging

## Common Use Cases

### 1. Workflow Progress Monitoring

```swift
while true {
    let status = try await handler.getWorkflowStatus(executionId: id)
    print("Progress: \(status.progress * 100)%")
    
    if status.execution.state == .completed || status.execution.state == .failed {
        break
    }
    
    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
}
```

### 2. Batch Workflow Submission

```swift
for definition in workflowDefinitions {
    let request = SubmitWorkflowRequest(definition: definition)
    let response = try await handler.submitWorkflow(request)
    executionIds.append(response.executionId)
}
```

### 3. Error Handling Chain

```swift
do {
    let result = try await handler.getWorkflowResult(executionId: id)
} catch APIHandlerError.workflowNotFound {
    // Handle missing workflow
} catch APIHandlerError.workflowNotCompleted(_, let reason) {
    // Handle incomplete workflow
    print("Still running: \(reason)")
} catch {
    // Handle other errors
}
```

## Troubleshooting

### Issue: "Workflow not found after submission"
- Ensure execution ID is correct
- Check coordinator is the same instance
- Verify workflow submission didn't fail silently

### Issue: "Invalid state transition"
- Can't cancel completed workflows
- Can't pause non-running workflows
- Check workflow state before action

### Issue: "Service not found"
- Register services before workflow submission
- Use correct service IDs
- Check ServiceRegistry state

## Future Enhancements

- WebSocket support for real-time updates
- Workflow history and audit logging
- Advanced filtering and sorting
- Workflow templates and reusability
- Metrics and performance analytics
