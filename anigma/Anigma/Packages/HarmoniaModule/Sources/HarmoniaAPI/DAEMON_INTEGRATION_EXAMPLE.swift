// Copyright (c) 2025 Anigma
// Licensed under the MIT License

/// DAEMON INTEGRATION EXAMPLE
///
/// This file demonstrates how to integrate HarmoniaAPI into AnigmaDaemonCore.
/// It's a reference implementation showing the complete integration pattern.
///
/// To use this in your daemon:
/// 1. Copy the HarmoniaHTTPRouter class
/// 2. Initialize it in your daemon setup
/// 3. Route HTTP requests to the router based on path prefix
/// 4. Send responses back to HTTP clients

import Foundation

#if false
// MARK: - Example: HTTP Router for Daemon

import AnigmaDaemonCore
import HarmoniaModule
import HarmoniaAPI

/// Router that integrates HarmoniaAPI into AnigmaDaemonCore.
/// 
/// Responsibilities:
/// - Coordinate HTTP request routing
/// - Manage HarmoniaAPI handler and server instances
/// - Transform HTTP requests/responses
/// - Handle routing errors
public class HarmoniaHTTPRouter {
    private let server: HarmoniaHTTPServer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// Initialize router with daemon configuration.
    /// - Parameter coordinator: The HarmoniaCoordinator instance
    public init(coordinator: HarmoniaCoordinator) {
        let handler = HarmoniaAPIHandler(coordinator: coordinator)
        self.server = HarmoniaHTTPServer(handler: handler, port: 8080)
        
        // Configure JSON encoding for consistent timestamps
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
    }
    
    /// Route incoming HTTP request.
    /// 
    /// Call this method for any HTTP request with path starting with:
    /// - `/api/workflows`
    /// - `/api/services`
    ///
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: Request path (e.g., "/api/workflows/submit")
    ///   - body: Optional request body data
    /// - Returns: Tuple of (statusCode, responseBody)
    public func routeRequest(method: String, path: String, body: Data?) async -> (statusCode: Int, body: Data) {
        let responseBody = await server.handleRequest(method: method, path: path, body: body)
        return (statusCode: 200, body: responseBody)
    }
    
    /// Check if router can handle the request path.
    public func canHandle(_ path: String) -> Bool {
        return path.hasPrefix("/api/workflows") || path.hasPrefix("/api/services")
    }
}

// MARK: - Example: Daemon HTTP Handler

/// Example HTTP handler for AnigmaDaemonCore that uses HarmoniaHTTPRouter.
public class DaemonHTTPHandler {
    private let harmoniaRouter: HarmoniaHTTPRouter
    
    public init(coordinator: HarmoniaCoordinator) {
        self.harmoniaRouter = HarmoniaHTTPRouter(coordinator: coordinator)
    }
    
    /// Handle incoming HTTP request.
    ///
    /// Integration point: Call this from your daemon's HTTP server when
    /// a request is received.
    public func handle(
        method: String,
        path: String,
        headers: [String: String],
        body: Data?
    ) async -> (statusCode: Int, headers: [String: String], body: Data) {
        // Route Harmonia API requests
        if harmoniaRouter.canHandle(path) {
            let (statusCode, responseBody) = await harmoniaRouter.routeRequest(
                method: method,
                path: path,
                body: body
            )
            return (
                statusCode: statusCode,
                headers: ["Content-Type": "application/json"],
                body: responseBody
            )
        }
        
        // Route other requests (your other handlers)
        return (
            statusCode: 404,
            headers: ["Content-Type": "application/json"],
            body: Self.notFoundResponse()
        )
    }
    
    private static func notFoundResponse() -> Data {
        let json = #"{"success":false,"error":{"code":"NOT_FOUND","message":"Route not found","statusCode":404}}"#
        return json.data(using: .utf8) ?? Data()
    }
}

// MARK: - Example: Daemon Initialization

/// Example showing how to initialize HarmoniaAPI in your daemon.
public class AnigmaDaemon {
    private let httpHandler: DaemonHTTPHandler
    
    public init(config: DaemonConfig) {
        // Create HarmoniaModule components
        let coordinator = HarmoniaCoordinator.shared
        
        // Register services (example)
        // try? coordinator.registerService(YourService())
        
        // Create HTTP handler with HarmoniaAPI integration
        self.httpHandler = DaemonHTTPHandler(coordinator: coordinator)
    }
    
    /// Handle incoming HTTP connection
    public func handleHTTPRequest(
        method: String,
        path: String,
        headers: [String: String],
        body: Data?
    ) async -> (statusCode: Int, headers: [String: String], body: Data) {
        return await httpHandler.handle(
            method: method,
            path: path,
            headers: headers,
            body: body
        )
    }
}

// MARK: - Example: URLSession-based HTTP Server

/// Example HTTP server using URLSession for testing/development.
public class HarmoniaTestHTTPServer {
    private let router: HarmoniaHTTPRouter
    private let port: UInt16
    
    public init(coordinator: HarmoniaCoordinator, port: UInt16 = 8080) {
        self.router = HarmoniaHTTPRouter(coordinator: coordinator)
        self.port = port
    }
    
    /// Start test HTTP server (development/testing only).
    ///
    /// Example:
    /// ```swift
    /// let coordinator = HarmoniaCoordinator.shared
    /// let server = HarmoniaTestHTTPServer(coordinator: coordinator, port: 8080)
    /// try await server.start()
    /// ```
    public func start() async throws {
        // This is a reference implementation
        // Use your daemon's HTTP server instead for production
        print("Starting Harmonia HTTP server on port \(port)")
    }
}

// MARK: - Example: Testing

/// Example: Test the HarmoniaAPI integration
public class HarmoniaAPIIntegrationTest {
    public static func example() async throws {
        // Create coordinator
        let coordinator = HarmoniaCoordinator.shared
        
        // Create router
        let router = HarmoniaHTTPRouter(coordinator: coordinator)
        
        // Test workflow submission
        let submitJson = #"""
        {
          "definition": {
            "id": "test-wf",
            "name": "Test Workflow",
            "steps": []
          }
        }
        """#
        
        guard let submitBody = submitJson.data(using: .utf8) else {
            throw NSError(domain: "encoding", code: -1)
        }
        
        let (status, response) = await router.routeRequest(
            method: "POST",
            path: "/api/workflows/submit",
            body: submitBody
        )
        
        print("Status: \(status)")
        print("Response: \(String(data: response, encoding: .utf8) ?? "error")")
    }
}

// MARK: - Configuration Example

/// Example DaemonConfig for HarmoniaAPI
public struct DaemonConfig {
    public let apiPort: Int
    public let apiHost: String
    public let enableLogging: Bool
    public let requestTimeout: TimeInterval
    
    public init(
        apiPort: Int = 8080,
        apiHost: String = "0.0.0.0",
        enableLogging: Bool = true,
        requestTimeout: TimeInterval = 30.0
    ) {
        self.apiPort = apiPort
        self.apiHost = apiHost
        self.enableLogging = enableLogging
        self.requestTimeout = requestTimeout
    }
}

#endif

// MARK: - Integration Checklist

/**
 INTEGRATION CHECKLIST:
 
 Before integrating HarmoniaAPI into your daemon:
 
 [ ] 1. Verify HarmoniaAPI module is in package dependencies
 [ ] 2. Create HarmoniaCoordinator instance
 [ ] 3. Create HarmoniaAPIHandler with coordinator
 [ ] 4. Create HarmoniaHTTPServer with handler
 [ ] 5. Route HTTP requests by path prefix:
       - /api/workflows/* -> HarmoniaAPI
       - /api/services/* -> HarmoniaAPI
 [ ] 6. Return responses with Content-Type: application/json
 [ ] 7. Test all 9 endpoints:
       - POST /api/workflows/submit
       - GET /api/workflows/{id}
       - GET /api/workflows?state=...
       - POST /api/workflows/{id}/cancel
       - POST /api/workflows/{id}/pause
       - POST /api/workflows/{id}/resume
       - GET /api/workflows/{id}/result
       - GET /api/services
       - POST /api/services/{id}/health
 [ ] 8. Verify error handling (404, 409, 400, 500)
 [ ] 9. Test with sample workflows
 [ ] 10. Enable logging for debugging
 
 QUICK START:
 
 // 1. Create router
 let router = HarmoniaHTTPRouter(coordinator: HarmoniaCoordinator.shared)
 
 // 2. Check if request is for HarmoniaAPI
 if router.canHandle(path) {
     // 3. Route request
     let (status, body) = await router.routeRequest(method: method, path: path, body: body)
     // 4. Send response
     return HTTPResponse(statusCode: status, body: body)
 }
 
 TESTING WITH CURL:
 
 // Submit workflow
 // curl -X POST http://localhost:8080/api/workflows/submit \
 //      -H "Content-Type: application/json" \
 //      -d '{"definition":{"id":"test","name":"Test","steps":[]}}'
 
 // List workflows
 // curl http://localhost:8080/api/workflows
 
 // Get service health
 // curl -X POST http://localhost:8080/api/services/my-service/health
 */
