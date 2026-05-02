//
//  DaemonServer+Pipeline.swift
//  AnigmaDaemonCore
//
//  Pipeline control and execution endpoints for daemon-backed processing.
//

import Foundation
import AnigmaPrimitives

// MARK: - Pipeline Handler Extension

extension DaemonServer {
    
    /// List all available pipelines
    func handleListPipelines(ctx: DaemonRequestContext) async throws -> AnigmaPipelineListResponse {
        return AnigmaPipelineListResponse(
            pipelines: [],
            error: AnigmaErrorStatus(code: "PIPELINES_UNAVAILABLE", message: "Pipeline operations are unavailable in AnigmaDaemonCore")
        )
    }
    
    /// Create a new pipeline
    func handleCreatePipeline(ctx: DaemonRequestContext, request: AnigmaPipelineCreateRequest) async throws -> AnigmaPipelineCreateResponse {
        return AnigmaPipelineCreateResponse(
            pipelineId: "",
            name: request.name,
            error: AnigmaErrorStatus(code: "PIPELINES_UNAVAILABLE", message: "Pipeline operations are unavailable in AnigmaDaemonCore")
        )
    }
    
    /// Run a pipeline
    func handleRunPipeline(ctx: DaemonRequestContext, request: AnigmaPipelineRunRequest) async throws -> AnigmaPipelineRunResponse {
        return AnigmaPipelineRunResponse(
            runId: "",
            pipelineId: request.pipelineId,
            status: "failed",
            error: AnigmaErrorStatus(code: "PIPELINES_UNAVAILABLE", message: "Pipeline operations are unavailable in AnigmaDaemonCore")
        )
    }
    
    /// Get pipeline run status
    func handleGetPipelineStatus(ctx: DaemonRequestContext, request: AnigmaPipelineStatusRequest) async throws -> AnigmaPipelineStatusResponse {
        return AnigmaPipelineStatusResponse(
            runId: request.runId,
            status: "unknown",
            progress: 0.0,
            error: AnigmaErrorStatus(code: "PIPELINES_UNAVAILABLE", message: "Pipeline operations are unavailable in AnigmaDaemonCore")
        )
    }
    
    /// Cancel a pipeline run
    func handleCancelPipeline(ctx: DaemonRequestContext, request: AnigmaPipelineCancelRequest) async throws -> AnigmaPipelineCancelResponse {
        return AnigmaPipelineCancelResponse(
            success: false,
            message: "Pipeline operations are unavailable in AnigmaDaemonCore",
            error: AnigmaErrorStatus(code: "PIPELINES_UNAVAILABLE", message: "Pipeline operations are unavailable in AnigmaDaemonCore")
        )
    }
}
