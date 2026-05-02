import AnigmaEvents
import Foundation
import AnigmaSystemSpine
import DataCore

public extension ExportEngine {
    /// Event-driven export compilation that publishes export lifecycle events.
    func compilePlanWithEvents(request: ExportRequest) async throws -> ExportPlan {
        let exportId = UUID().uuidString
        let startTime = Date()

        _ = await sharedEventBus.publish(
            ExportStartedEvent(
                exportId: exportId,
                dataId: request.profileId,
                exportFormat: "plan",
                initiatedBy: "ExportEngine.compile",
                metadata: [
                    "profileId": request.profileId,
                    "inputCount": String(request.inputs.count),
                    "processingType": "compilation"
                ]
            ),
            source: "ExportCore"
        )

        _ = await sharedEventBus.publish(
            ExportProgressEvent(
                exportId: exportId,
                progress: 0.0,
                processedItems: 0,
                totalItems: 1,
                message: "Starting plan compilation",
                stage: "compilation"
            ),
            source: "ExportCore"
        )

        do {
            let plan = try await compilePlan(request: request)

            _ = await sharedEventBus.publish(
                ExportProgressEvent(
                    exportId: exportId,
                    progress: 1.0,
                    processedItems: 1,
                    totalItems: 1,
                    message: "Plan compilation completed",
                    stage: "compilation"
                ),
                source: "ExportCore"
            )

            _ = await sharedEventBus.publish(
                ExportCompletedEvent(
                    exportId: exportId,
                    result: plan.id,
                    duration: Date().timeIntervalSince(startTime),
                    success: true,
                    exportedItems: 1
                ),
                source: "ExportCore"
            )

            return plan
        } catch {
            _ = await sharedEventBus.publish(
                ExportFailedEvent(
                    exportId: exportId,
                    error: error,
                    exportedItems: 0
                ),
                source: "ExportCore"
            )
            throw error
        }
    }

    /// Event-driven export execution wrapper that forwards normal export events.
    func executeWithEvents(plan: ExportPlan) -> AsyncStream<ExportEvent> {
        let exportId = UUID().uuidString
        let startTime = Date()

        return AsyncStream { continuation in
            Task {
                _ = await sharedEventBus.publish(
                    ExportStartedEvent(
                        exportId: exportId,
                        dataId: plan.id,
                        exportFormat: "output",
                        initiatedBy: "ExportEngine.execute",
                        metadata: [
                            "planId": plan.id,
                            "inputCount": String(plan.inputs.count),
                            "processingType": "execution"
                        ]
                    ),
                    source: "ExportCore"
                )

                _ = await sharedEventBus.publish(
                    ExportProgressEvent(
                        exportId: exportId,
                        progress: 0.0,
                        processedItems: 0,
                        totalItems: 1,
                        message: "Starting export execution",
                        stage: "execution"
                    ),
                    source: "ExportCore"
                )

                var didFail = false
                var failureMessage: String?
                let stream = await self.execute(plan: plan)

                for await event in stream {
                    continuation.yield(event)
                    if case let .failed(message, _) = event {
                        didFail = true
                        failureMessage = message
                    }
                }

                let duration = Date().timeIntervalSince(startTime)

                if didFail {
                    let eventError = NSError(
                        domain: "ExportCore",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: failureMessage ?? "Export execution failed"]
                    )
                    _ = await sharedEventBus.publish(
                        ExportFailedEvent(
                            exportId: exportId,
                            error: eventError,
                            exportedItems: 0
                        ),
                        source: "ExportCore"
                    )
                } else {
                    _ = await sharedEventBus.publish(
                        ExportProgressEvent(
                            exportId: exportId,
                            progress: 1.0,
                            processedItems: 1,
                            totalItems: 1,
                            message: "Export execution completed",
                            stage: "execution_complete"
                        ),
                        source: "ExportCore"
                    )

                    _ = await sharedEventBus.publish(
                        ExportCompletedEvent(
                            exportId: exportId,
                            result: "Export completed successfully",
                            duration: duration,
                            success: true,
                            exportedItems: 1
                        ),
                        source: "ExportCore"
                    )
                }

                continuation.finish()
            }
        }
    }

    /// Placeholder subscription setup for compatibility.
    func setupEventSubscriptions() async {}

    /// Placeholder subscription cleanup for compatibility.
    func cleanupEventSubscriptions() async {}

    /// Create an export work item.
    func createExportWorkItem(
        planId: String,
        priority: Int = 1,
        metadata: [String: String]? = nil
    ) async -> String {
        let workItemId = UUID().uuidString
        var workItemMetadata = metadata ?? [:]
        workItemMetadata["planId"] = planId
        workItemMetadata["workflowType"] = "export"

        _ = await sharedEventBus.publish(
            WorkItemCreatedEvent(
                workItemId: workItemId,
                workItemType: "export",
                priority: priority,
                createdBy: "ExportCore",
                metadata: workItemMetadata
            ),
            source: "ExportCore"
        )

        return workItemId
    }

    /// Request export compilation through event bus.
    func requestExportCompilation(
        profileId: String,
        inputs: [Artifact],
        metadata: [String: String]? = nil
    ) async -> String {
        let exportId = UUID().uuidString
        var requestMetadata = metadata ?? [:]
        requestMetadata["profileId"] = profileId
        requestMetadata["inputCount"] = String(inputs.count)
        requestMetadata["processingType"] = "compilation"

        _ = await sharedEventBus.publish(
            ExportStartedEvent(
                exportId: exportId,
                dataId: profileId,
                exportFormat: "plan",
                initiatedBy: "ExportCore",
                metadata: requestMetadata
            ),
            source: "ExportCore"
        )

        return exportId
    }

    /// Request export execution through event bus.
    func requestExportExecution(
        planId: String,
        metadata: [String: String]? = nil
    ) async -> String {
        let exportId = UUID().uuidString
        var requestMetadata = metadata ?? [:]
        requestMetadata["planId"] = planId
        requestMetadata["processingType"] = "execution"

        _ = await sharedEventBus.publish(
            ExportStartedEvent(
                exportId: exportId,
                dataId: planId,
                exportFormat: "output",
                initiatedBy: "ExportCore",
                metadata: requestMetadata
            ),
            source: "ExportCore"
        )

        return exportId
    }
}

public extension ExportEvent {
    /// Convert an export event to a generic UI event.
    func toUIEvent(componentId: String) -> UIEvent {
        let eventId = UUID().uuidString
        let timestamp = Date()

        switch self {
        case let .started(jobId):
            return UIEvent(
                eventId: eventId,
                eventType: "export.started",
                componentId: componentId,
                payload: ["jobId": jobId],
                timestamp: timestamp
            )

        case let .phase(name):
            return UIEvent(
                eventId: eventId,
                eventType: "export.phase",
                componentId: componentId,
                payload: ["name": name],
                timestamp: timestamp
            )

        case let .progress(completed, total):
            var payload: [String: String] = ["completed": String(completed)]
            if let total {
                payload["total"] = String(total)
            }
            return UIEvent(
                eventId: eventId,
                eventType: "export.progress",
                componentId: componentId,
                payload: payload,
                timestamp: timestamp
            )

        case let .output(url, role):
            return UIEvent(
                eventId: eventId,
                eventType: "export.output",
                componentId: componentId,
                payload: ["url": url.absoluteString, "role": role],
                timestamp: timestamp
            )

        case let .finished(success, receiptRef):
            var payload: [String: String] = ["success": String(success)]
            if let receiptRef {
                payload["receiptRef"] = receiptRef
            }
            return UIEvent(
                eventId: eventId,
                eventType: "export.finished",
                componentId: componentId,
                payload: payload,
                timestamp: timestamp
            )

        case let .failed(message, receiptRef):
            var payload: [String: String] = ["message": message]
            if let receiptRef {
                payload["receiptRef"] = receiptRef
            }
            return UIEvent(
                eventId: eventId,
                eventType: "export.failed",
                componentId: componentId,
                payload: payload,
                timestamp: timestamp
            )
        }
    }
}
