// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation

#if os(macOS) || os(Linux)
import Network
#endif

// MARK: - HTTP Server for Harmonia API

/// High-level HTTP server for exposing HarmoniaAPIHandler endpoints
///
/// This server handles HTTP request routing, serialization, and error responses.
/// It integrates with the HarmoniaAPIHandler to provide a complete HTTP API.
///
/// Usage:
/// ```
/// let handler = HarmoniaAPIHandler(coordinator: coordinator)
/// let server = HarmoniaHTTPServer(handler: handler, port: 8080)
/// try await server.start()
/// ```
public actor HarmoniaHTTPServer {
    private let handler: HarmoniaAPIHandler
    private let port: UInt16
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init(handler: HarmoniaAPIHandler, port: UInt16 = 8080) {
        self.handler = handler
        self.port = port
        
        // Configure JSON encoder/decoder
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
    }
    
    // MARK: - Route Handling
    
    /// Route HTTP request to appropriate handler
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: Request path
    ///   - body: Request body data
    /// - Returns: Encoded HTTP response
    public func handleRequest(method: String, path: String, body: Data?) async -> Data {
        do {
            let response: Data
            
            switch (method.uppercased(), path) {
            // Workflow submission
            case ("POST", "/api/workflows/submit"):
                response = try await handleSubmitWorkflow(body: body)
            
            // Workflow status
            case ("GET", let p) where p.hasPrefix("/api/workflows/") && p.hasSuffix("/status"):
                let executionId = extractExecutionId(from: p, suffix: "/status")
                response = try await handleGetWorkflowStatus(executionId: executionId)
            
            // Workflow get (alias for status)
            case ("GET", let p) where p.hasPrefix("/api/workflows/") && !p.contains("/"):
                let executionId = extractExecutionId(from: p, suffix: "")
                response = try await handleGetWorkflowStatus(executionId: executionId)
            
            // Workflow list
            case ("GET", let p) where p.hasPrefix("/api/workflows") && (p == "/api/workflows" || p.hasPrefix("/api/workflows?")):
                let state = extractQueryParameter(from: p, name: "state")
                response = try await handleListWorkflows(stateFilter: state)
            
            // Workflow cancel
            case ("POST", let p) where p.contains("/api/workflows/") && p.hasSuffix("/cancel"):
                let executionId = extractExecutionId(from: p, suffix: "/cancel")
                response = try await handleCancelWorkflow(executionId: executionId)
            
            // Workflow pause
            case ("POST", let p) where p.contains("/api/workflows/") && p.hasSuffix("/pause"):
                let executionId = extractExecutionId(from: p, suffix: "/pause")
                response = try await handlePauseWorkflow(executionId: executionId)
            
            // Workflow resume
            case ("POST", let p) where p.contains("/api/workflows/") && p.hasSuffix("/resume"):
                let executionId = extractExecutionId(from: p, suffix: "/resume")
                response = try await handleResumeWorkflow(executionId: executionId)
            
            // Workflow result
            case ("GET", let p) where p.contains("/api/workflows/") && p.hasSuffix("/result"):
                let executionId = extractExecutionId(from: p, suffix: "/result")
                response = try await handleGetWorkflowResult(executionId: executionId)
            
            // Services list
            case ("GET", "/api/services"):
                response = try await handleListServices()
            
            // Service health
            case ("POST", let p) where p.hasPrefix("/api/services/") && p.hasSuffix("/health"):
                let serviceId = extractExecutionId(from: p, suffix: "/health")
                response = try await handleGetServiceHealth(serviceId: serviceId)
            
            // Not found
            default:
                response = encodeError(
                    code: "NOT_FOUND",
                    message: "Route not found: \(method) \(path)",
                    statusCode: 404
                )
            }
            
            return response
        } catch {
            return encodeError(
                code: "INTERNAL_ERROR",
                message: error.localizedDescription,
                statusCode: 500
            )
        }
    }
    
    // MARK: - Request Handlers
    
    private func handleSubmitWorkflow(body: Data?) async throws -> Data {
        guard let body = body else {
            throw HTTPError.missingRequestBody
        }
        
        let request = try decoder.decode(SubmitWorkflowRequest.self, from: body)
        let result = try await handler.submitWorkflow(request)
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    private func handleGetWorkflowStatus(executionId: String) async throws -> Data {
        let result = try await handler.getWorkflowStatus(executionId: executionId)
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    private func handleListWorkflows(stateFilter: String?) async throws -> Data {
        let state: WorkflowState? = stateFilter.flatMap { WorkflowState(rawValue: $0) }
        let result = await handler.listWorkflows(state: state)
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    private func handleCancelWorkflow(executionId: String) async throws -> Data {
        let result = try await handler.cancelWorkflow(executionId: executionId)
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    private func handlePauseWorkflow(executionId: String) async throws -> Data {
        let result = try await handler.pauseWorkflow(executionId: executionId)
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    private func handleResumeWorkflow(executionId: String) async throws -> Data {
        let result = try await handler.resumeWorkflow(executionId: executionId)
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    private func handleGetWorkflowResult(executionId: String) async throws -> Data {
        let result = try await handler.getWorkflowResult(executionId: executionId)
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    private func handleListServices() async throws -> Data {
        let result = await handler.listServices()
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    private func handleGetServiceHealth(serviceId: String) async throws -> Data {
        let result = try await handler.getServiceHealth(serviceId: serviceId)
        let response = APIResponse(data: result)
        return try encoder.encode(response)
    }
    
    // MARK: - Response Encoding
    
    private func encodeError(code: String, message: String, statusCode: Int) -> Data {
        let error = APIError(code: code, message: message, statusCode: statusCode)
        let response: APIResponse<APIError> = APIResponse(error: error)
        
        do {
            return try encoder.encode(response)
        } catch {
            // Fallback to simple error JSON
            let fallback = #"{"success":false,"error":{"code":"\#(code)","message":"\#(message)","statusCode":\#(statusCode)}}"#
            return fallback.data(using: .utf8) ?? Data()
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractExecutionId(from path: String, suffix: String) -> String {
        let components = path.split(separator: "/")
        if components.count >= 3 {
            return String(components[2])
        }
        return ""
    }
    
    private func extractQueryParameter(from path: String, name: String) -> String? {
        guard let queryStart = path.firstIndex(of: "?") else {
            return nil
        }
        
        let queryString = String(path[queryStart...]).dropFirst()
        let parameters = queryString.split(separator: "&")
        
        for param in parameters {
            let parts = param.split(separator: "=")
            if parts.count == 2 && parts[0] == name {
                return String(parts[1])
            }
        }
        
        return nil
    }
}

// MARK: - HTTP Error

enum HTTPError: LocalizedError, Sendable {
    case missingRequestBody
    case invalidPath
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequestBody:
            return "Request body is required"
        case .invalidPath:
            return "Invalid request path"
        case .decodingFailed(let reason):
            return "Failed to decode request: \(reason)"
        }
    }
}

// MARK: - Integration Instructions

/// DAEMON INTEGRATION GUIDE:
///
/// 1. Create HarmoniaAPIHandler instance:
/// ```swift
/// let coordinator = HarmoniaCoordinator.shared
/// let apiHandler = HarmoniaAPIHandler(coordinator: coordinator)
/// ```
///
/// 2. Create HTTP server:
/// ```swift
/// let server = HarmoniaHTTPServer(handler: apiHandler, port: 8080)
/// ```
///
/// 3. Integrate with daemon HTTP server (example for URLSession-based server):
/// ```swift
/// // In your daemon's HTTP handler
/// let harmonia = HarmoniaHTTPServer(handler: apiHandler, port: 8080)
/// let requestData = try JSONEncoder().encode(request)
/// let responseData = await harmonia.handleRequest(
///     method: httpMethod,
///     path: httpPath,
///     body: requestData
/// )
/// let response = try JSONDecoder().decode(APIResponse<T>.self, from: responseData)
/// ```
///
/// 4. Example: Wiring into AnigmaDaemonCore
/// ```swift
/// public class HarmoniaHTTPRouter {
///     private let server: HarmoniaHTTPServer
///
///     init(coordinator: HarmoniaCoordinator) {
///         let handler = HarmoniaAPIHandler(coordinator: coordinator)
///         self.server = HarmoniaHTTPServer(handler: handler, port: 8080)
///     }

///     func routeRequest(_ request: HTTPRequest) async -> HTTPResponse {
///         let responseBody = await server.handleRequest(
///             method: request.method,
///             path: request.path,
///             body: request.body
///         )
///         return HTTPResponse(statusCode: 200, body: responseBody)
///     }
/// }
/// ```
///
/// 5. Testing endpoints:
/// ```bash
/// # Submit workflow
/// curl -X POST http://localhost:8080/api/workflows/submit \
///   -H "Content-Type: application/json" \
///   -d '{...workflow definition...}'
///
/// # Get workflow status
/// curl http://localhost:8080/api/workflows/{executionId}
///
/// # List services
/// curl http://localhost:8080/api/services
///
/// # Pause workflow
/// curl -X POST http://localhost:8080/api/workflows/{executionId}/pause
/// ```
