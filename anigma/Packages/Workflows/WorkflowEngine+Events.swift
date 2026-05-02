import AnigmaEvents
import Foundation
import DataCore
import DataEngine
import AnigmaSystemSpine

public extension WorkflowEngine {
    /// Event-driven workflow execution wrapper around core execute.
    func executeWithEvents(workflow: WorkflowDefinition, context: String) async throws -> WorkflowResult {
        let workflowId = workflow.id
        let startTime = Date()

        _ = await sharedEventBus.publish(
            WorkflowStartedEvent(
                workflowId: workflowId,
                workflowName: workflow.name,
                initiatedBy: "Workflows",
                metadata: [
                    "stepCount": String(workflow.steps.count),
                    "context": context
                ]
            ),
            source: "Workflows"
        )

        _ = await sharedEventBus.publish(
            WorkflowProgressEvent(
                workflowId: workflowId,
                progress: 0.0,
                message: "Starting workflow execution",
                stepName: nil
            ),
            source: "Workflows"
        )

        do {
            let result = try await execute(workflow: workflow, context: context)

            _ = await sharedEventBus.publish(
                WorkflowProgressEvent(
                    workflowId: workflowId,
                    progress: 1.0,
                    message: "Workflow execution completed",
                    stepName: nil
                ),
                source: "Workflows"
            )

            _ = await sharedEventBus.publish(
                WorkflowCompletedEvent(
                    workflowId: workflowId,
                    result: "Workflow completed successfully",
                    duration: Date().timeIntervalSince(startTime),
                    success: true
                ),
                source: "Workflows"
            )

            return result
        } catch {
            _ = await sharedEventBus.publish(
                WorkflowFailedEvent(
                    workflowId: workflowId,
                    error: error
                ),
                source: "Workflows"
            )
            throw error
        }
    }

    /// Placeholder subscription setup for compatibility.
    func setupEventSubscriptions() async {}

    /// Placeholder subscription cleanup for compatibility.
    func cleanupEventSubscriptions() async {}

    /// Create a work item for workflow data processing.
    func createDataProcessingWorkItem(
        source: URL,
        workflowId: String,
        priority: Int = 1,
        metadata: [String: String]? = nil
    ) async -> String {
        let workItemId = UUID().uuidString
        var workItemMetadata = metadata ?? [:]
        workItemMetadata["workflowId"] = workflowId
        workItemMetadata["source"] = source.absoluteString
        workItemMetadata["processingType"] = "workflow_step"

        _ = await sharedEventBus.publish(
            WorkItemCreatedEvent(
                workItemId: workItemId,
                workItemType: "data_processing",
                priority: priority,
                createdBy: "Workflows",
                metadata: workItemMetadata
            ),
            source: "Workflows"
        )

        return workItemId
    }

    /// Request data processing for a workflow step.
    func requestDataProcessing(
        source: URL,
        workflowId: String,
        metadata: [String: String]? = nil
    ) async -> String {
        let processingId = UUID().uuidString
        var requestMetadata = metadata ?? [:]
        requestMetadata["workflowId"] = workflowId
        requestMetadata["source"] = source.absoluteString
        requestMetadata["processingType"] = "workflow_step"

        _ = await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: source.lastPathComponent,
                dataType: "url",
                initiatedBy: "Workflows",
                metadata: requestMetadata
            ),
            source: "Workflows"
        )

        return processingId
    }
}
