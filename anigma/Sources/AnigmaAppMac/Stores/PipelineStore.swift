//
//  PipelineStore.swift
//  AnigmaAppMac
//
//  Manages pipeline operations, execution, and monitoring.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaHostMac

@MainActor
@Observable
final class PipelineStore {

    // MARK: - Properties

    /// Pipeline client for data processing
    private let pipelineClient: PipelineClient

    /// Available pipelines
    var pipelines: [PipelineInfo] = []

    /// Active pipeline runs
    var pipelineRuns: [PipelineRunResponse] = []

    // MARK: - Dependencies (Injected)

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    // MARK: - Initialization

    init(pipelineClient: PipelineClient) {
        self.pipelineClient = pipelineClient
    }

    // MARK: - Pipeline Operations

    /// Load all available pipelines
    func loadPipelines() async {
        do {
            let response = try await pipelineClient.listPipelines()
            pipelines = response.pipelines
        } catch {
            showError("Failed to load pipelines: \(error)")
        }
    }

    /// Create a new pipeline with stages
    func createPipeline(name: String, stages: [PipelineStage]) async {
        do {
            _ = try await pipelineClient.createPipeline(name: name, stages: stages)
            await loadPipelines()
            showToast("Pipeline Created", name, "arrow.triangle.branch")
        } catch {
            showError("Failed to create pipeline: \(error)")
        }
    }

    /// Run a pipeline with given inputs
    func runPipeline(id: String, inputs: [String: String]) async {
        do {
            let response = try await pipelineClient.runPipeline(id: id, inputs: inputs)
            pipelineRuns.append(response)
            showToast("Pipeline Started", "Run ID: \(response.runId)", "play.circle")
        } catch {
            showError("Failed to run pipeline: \(error)")
        }
    }

    /// Monitor the progress of a pipeline run
    func monitorPipelineRun(runId: String) async {
        do {
            let status = try await pipelineClient.getPipelineStatus(runId: runId)
            // Update UI with status
            showToast("Pipeline Progress", "\(Int(status.progress * 100))%", "chart.bar")
        } catch {
            print("Failed to get pipeline status: \(error)")
        }
    }

    /// Cancel a running pipeline
    func cancelPipeline(runId: String) async {
        do {
            let response = try await pipelineClient.cancelPipeline(runId: runId)
            if response.success {
                showToast("Pipeline Canceled", runId, "xmark.circle")
                // Refresh pipeline runs to update status
                // Note: You may want to add a method to refresh individual run status
            }
        } catch {
            showError("Failed to cancel pipeline: \(error)")
        }
    }

    /// Get status for a specific pipeline run
    func getPipelineStatus(runId: String) async -> PipelineStatusResponse? {
        do {
            return try await pipelineClient.getPipelineStatus(runId: runId)
        } catch {
            showError("Failed to get pipeline status: \(error)")
            return nil
        }
    }
}
