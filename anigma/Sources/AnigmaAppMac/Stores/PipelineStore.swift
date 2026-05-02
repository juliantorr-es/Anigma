//
//  PipelineStore.swift
//  AnigmaAppMac
//
//  Manages pipeline operations, execution, and monitoring.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaPrimitives
import AnigmaSidecar

@MainActor
@Observable
final class PipelineStore {

    // MARK: - Properties

    /// Daemon bridge for pipeline operations
    private let daemonBridge: SidecarBridge

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

    init(daemonBridge: SidecarBridge) {
        self.daemonBridge = daemonBridge
    }

    // MARK: - Pipeline Operations

    /// Load all available pipelines via daemon
    func loadPipelines() async {
        do {
            let response = try await daemonBridge.listPipelines()
            if let error = response.error {
                showError("Failed to load pipelines: \(error.message)")
                return
            }
            pipelines = response.pipelines
        } catch {
            showError("Failed to load pipelines: \(error.localizedDescription)")
        }
    }

    /// Create a new pipeline with stages via daemon
    func createPipeline(name: String, stages: [PipelineStage]) async {
        do {
            let response = try await daemonBridge.createPipeline(name: name, stages: stages)
            if let error = response.error {
                showError("Failed to create pipeline: \(error.message)")
                return
            }
            await loadPipelines()
            showToast("Pipeline Created", name, "arrow.triangle.branch")
        } catch {
            showError("Failed to create pipeline: \(error.localizedDescription)")
        }
    }

    /// Run a pipeline with given inputs via daemon
    func runPipeline(id: String, inputs: [String: String]) async {
        do {
            let response = try await daemonBridge.runPipeline(pipelineId: id, inputs: inputs)
            if let error = response.error {
                showError("Failed to run pipeline: \(error.message)")
                return
            }
            pipelineRuns.append(PipelineRunResponse(
                runId: response.runId,
                pipelineId: response.pipelineId,
                status: response.status,
                startedAt: Date()
            ))
            showToast("Pipeline Started", "Run ID: \(response.runId)", "play.circle")
        } catch {
            showError("Failed to run pipeline: \(error.localizedDescription)")
        }
    }

    /// Monitor the progress of a pipeline run via daemon
    func monitorPipelineRun(runId: String) async {
        do {
            let response = try await daemonBridge.getPipelineStatus(runId: runId)
            if let error = response.error {
                showError("Failed to get pipeline status: \(error.message)")
                return
            }
            // Update UI with status
            showToast("Pipeline Progress", "\(Int(response.progress * 100))%", "chart.bar")
        } catch {
            print("Failed to get pipeline status: \(error.localizedDescription)")
        }
    }

    /// Cancel a running pipeline via daemon
    func cancelPipeline(runId: String) async {
        do {
            let response = try await daemonBridge.cancelPipeline(runId: runId)
            if let error = response.error {
                showError("Failed to cancel pipeline: \(error.message)")
                return
            }
            if response.success {
                showToast("Pipeline Canceled", runId, "xmark.circle")
                // Refresh pipeline runs to update status
                // Note: You may want to add a method to refresh individual run status
            }
        } catch {
            showError("Failed to cancel pipeline: \(error.localizedDescription)")
        }
    }

    /// Get status for a specific pipeline run via daemon
    func getPipelineStatus(runId: String) async -> PipelineStatusResponse? {
        do {
            let response = try await daemonBridge.getPipelineStatus(runId: runId)
            if let error = response.error {
                showError("Failed to get pipeline status: \(error.message)")
                return nil
            }
            return PipelineStatusResponse(
                runId: response.runId,
                status: response.status,
                currentStage: response.currentStage,
                progress: response.progress,
                outputs: response.outputs
            )
        } catch {
            showError("Failed to get pipeline status: \(error.localizedDescription)")
            return nil
        }
    }
}
