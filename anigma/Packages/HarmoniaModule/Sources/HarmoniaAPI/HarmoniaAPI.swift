// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import HarmoniaAPIContracts
import HarmoniaV2Surface

// MARK: - Public API Module

/// HarmoniaAPI provides HTTP API endpoints for HarmoniaModule's workflow orchestration.
///
/// Exposed components:
/// - `HarmoniaAPIHandler`: Main handler managing all API operations
/// - `HarmoniaHTTPServer`: HTTP server for routing requests
/// - Request/Response models for all endpoints
///
/// Quick start:
/// ```swift
/// let coordinator = HarmoniaCoordinator.shared
/// let handler = HarmoniaAPIHandler(coordinator: coordinator)
/// let server = HarmoniaHTTPServer(handler: handler, port: 8080)
///
/// // Handle incoming HTTP requests
/// let response = await server.handleRequest(method: "GET", path: "/api/workflows", body: nil)
/// ```

// Re-export main components for public API
typealias HarmoniaHandler = HarmoniaAPIHandler
typealias HarmoniaServer = HarmoniaHTTPServer

// Re-export request/response models
typealias WorkflowRequest = SubmitWorkflowRequest
typealias WorkflowsRequest = ListWorkflowsRequest
