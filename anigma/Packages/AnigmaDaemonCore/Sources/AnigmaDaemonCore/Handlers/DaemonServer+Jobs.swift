//
//  DaemonServer+Jobs.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import AnigmaEvents
import AnigmaPrimitives
import TelemetryCore

extension DaemonServer {
    /// SubmitJob handler (simplified)
    func handleSubmitJob(
        ctx: DaemonRequestContext,
        spec: JobSpec
    ) async throws -> SubmitJobResponse {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
             return SubmitJobResponse(
                jobId: "",
                receiptHash: "",
                error: ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil)
             )
        }

        do {
            // Validate token
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "job.submit")

            // Submit job to queue
            let jobId = try await jobQueue.submit(spec: spec, clientId: ctx.clientId)
            
            // Phase 4: Track job start time for duration calculation
            jobStartTimes[jobId] = Date()

            do {
                let receipt = try await receiptEngine.recordActionExecution(
                    actionName: "job.submit",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "QUEUED",
                    inputs: [
                        "job_id": jobId,
                        "kind": spec.kind,
                        "client_id": ctx.clientId
                    ],
                    outputs: [
                        "input_count": spec.inputs.count
                    ]
                )
                await emitJobEvent(
                    jobId: jobId,
                    type: .state,
                    message: JobState.queued.rawValue,
                    progressPermille: 0,
                    receiptHash: receipt.receiptID
                )
                await publishEvidence(
                    action: "job.submit",
                    outcome: "allowed",
                    jobId: jobId,
                    traceID: TelemetryHash(input: "job.submit|\(ctx.clientId)|\(jobId)").hex,
                    receiptID: receipt.receiptID,
                    metadata: [
                        "kind": spec.kind,
                        "client_id": ctx.clientId,
                        "input_count": "\(spec.inputs.count)"
                    ]
                )

                return SubmitJobResponse(
                    jobId: jobId,
                    receiptHash: receipt.receiptID,
                    error: nil
                )
            } catch {
                await emitJobEvent(
                    jobId: jobId,
                    type: .state,
                    message: JobState.queued.rawValue,
                    progressPermille: 0,
                    receiptHash: nil
                )
                await publishEvidence(
                    action: "job.submit",
                    outcome: "failed",
                    jobId: jobId,
                    traceID: TelemetryHash(input: "job.submit|\(ctx.clientId)|\(jobId)|failed").hex,
                    metadata: [
                        "kind": spec.kind,
                        "client_id": ctx.clientId,
                        "error": error.localizedDescription
                    ]
                )
                return SubmitJobResponse(
                    jobId: jobId,
                    receiptHash: "",
                    error: ErrorStatus(
                        code: "RECEIPT_FAILED",
                        message: "Job queued but receipt failed: \(error.localizedDescription)",
                        detailJson: nil
                    )
                )
            }
        } catch {
            return SubmitJobResponse(
                jobId: "",
                receiptHash: "",
                error: ErrorStatus(
                    code: "SUBMIT_FAILED", message: error.localizedDescription, detailJson: nil)
            )
        }
    }

    /// GetJobStatus handler
    func handleGetJobStatus(
        ctx: DaemonRequestContext,
        jobId: String
    ) async throws -> GetJobStatusResponse {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return GetJobStatusResponse(
                jobId: jobId, state: "ERROR", progressPermille: 0, outputs: [], finalReceiptHash: nil,
                error: ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
        }

        // Validate token
        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "job.read")

        // Get job status
        guard let job = await jobQueue.getStatus(jobId: jobId) else {
            return GetJobStatusResponse(
                jobId: jobId,
                state: "NOT_FOUND",
                progressPermille: 0,
                outputs: [],
                finalReceiptHash: nil,
                error: ErrorStatus(
                    code: "JOB_NOT_FOUND",
                    message: "Job not found: \(jobId)",
                    detailJson: nil
                )
            )
        }

        return GetJobStatusResponse(
            jobId: job.jobId,
            state: job.state,
            progressPermille: job.state == JobState.succeeded.rawValue ? 1000 : 0,
            outputs: job.outputs,
            finalReceiptHash: job.finalReceiptHash,
            error: job.state == JobState.failed.rawValue
                ? ErrorStatus(code: "JOB_FAILED", message: "Job failed", detailJson: nil)
                : nil
        )
    }

    /// Cancel a running or queued job
    func handleCancelJob(
        ctx: DaemonRequestContext,
        jobId: String
    ) async throws -> CancelJobResponse {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return CancelJobResponse(canceled: false, receiptHash: "", error: ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "job.cancel")

        await jobQueue.cancel(jobId: jobId)
        await workerPool.terminateWorker(for: jobId)

        _ = await telemetry.emit(
            category: .system,
            name: "job_canceled",
            values: ["job_id": .hashedToken(TelemetryHash(input: jobId))]
        )

        do {
            let receipt = try await receiptEngine.recordActionExecution(
                actionName: "job.cancel",
                authority: "anigmad",
                decision: .allowed,
                reasonCode: "CANCELED",
                inputs: [
                    "job_id": jobId,
                    "client_id": ctx.clientId
                ]
            )

            await emitJobEvent(
                jobId: jobId,
                type: .state,
                message: JobState.canceled.rawValue,
                progressPermille: 0,
                receiptHash: receipt.receiptID
            )
            await publishEvidence(
                action: "job.cancel",
                outcome: "allowed",
                jobId: jobId,
                traceID: TelemetryHash(input: "job.cancel|\(ctx.clientId)|\(jobId)").hex,
                receiptID: receipt.receiptID,
                metadata: [
                    "client_id": ctx.clientId
                ]
            )

            return CancelJobResponse(
                canceled: true,
                receiptHash: receipt.receiptID,
                error: nil
            )
        } catch {
            await emitJobEvent(
                jobId: jobId,
                type: .state,
                message: JobState.canceled.rawValue,
                progressPermille: 0,
                receiptHash: nil,
                error: ErrorStatus(
                    code: "RECEIPT_FAILED",
                    message: "Job canceled but receipt failed: \(error.localizedDescription)",
                    detailJson: nil
                )
            )
            await publishEvidence(
                action: "job.cancel",
                outcome: "failed",
                jobId: jobId,
                traceID: TelemetryHash(input: "job.cancel|\(ctx.clientId)|\(jobId)|failed").hex,
                metadata: [
                    "client_id": ctx.clientId,
                    "error": error.localizedDescription
                ]
            )
            return CancelJobResponse(
                canceled: true,
                receiptHash: "",
                error: ErrorStatus(
                    code: "RECEIPT_FAILED",
                    message: "Job canceled but receipt failed: \(error.localizedDescription)",
                    detailJson: nil
                )
            )
        }
    }

    func handleListJobs(
        ctx: DaemonRequestContext,
        pageToken: String?,
        pageSize: Int?,
        filterByState: [String]
    ) async throws -> (jobs: [Job], nextPageToken: String?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "job.read")
        
        let (jobs, nextToken) = await jobQueue.listJobs(
            pageToken: pageToken,
            pageSize: pageSize,
            filterByState: filterByState
        )
        
        if configuration.governance.auditAllOperations {
            do {
                _ = try await receiptEngine.recordActionExecution(
                    actionName: "job.list",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "LISTED",
                    inputs: [
                        "client_id": ctx.clientId,
                        "page_token": pageToken ?? "none",
                        "page_size": pageSize ?? 100,
                        "filter_by_state": filterByState.joined(separator: ",")
                    ],
                    outputs: [
                        "count": jobs.count,
                        "next_page_token": nextToken ?? "none"
                    ]
                )
            } catch {
                Self.logger.error("failed to record job list receipt: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        return (jobs, nextToken)
    }

    func handleStreamJobEvents(ctx: DaemonRequestContext, jobId: String) async throws -> AsyncStream<DaemonJobEvent> {
        return AsyncStream { _ in }
    }

    func emitJobEvent(
        jobId: String,
        type: JobEventType,
        message: String,
        progressPermille: Int,
        receiptHash: String? = nil,
        error: ErrorStatus? = nil
    ) async {
        // Publish to Anigma event bus
        switch type {
        case .state:
            let state = message
            let progress = Double(progressPermille) / 1000.0
            
            // Phase 4: Calculate duration for completed jobs
            let duration: TimeInterval = if state == JobState.succeeded.rawValue || state == JobState.failed.rawValue {
                if let startTime = jobStartTimes[jobId] {
                    Date().timeIntervalSince(startTime)
                } else {
                    0
                }
            } else {
                0
            }
            
            if state == JobState.running.rawValue {
                _ = await sharedEventBus.publish(
                    JobStatusUpdatedEvent(
                        jobId: jobId,
                        status: "running",
                        progress: progress
                    ),
                    source: "AnigmaDaemonCore"
                )
                await publishEvidence(
                    action: "job.state.running",
                    outcome: "allowed",
                    jobId: jobId,
                    traceID: TelemetryHash(input: "job.state.running|\(jobId)").hex,
                    receiptID: receiptHash,
                    metadata: [
                        "progress_permille": "\(progressPermille)"
                    ]
                )
            } else if state == JobState.succeeded.rawValue {
                _ = await sharedEventBus.publish(
                    JobCompletedEvent(
                        jobId: jobId,
                        result: receiptHash,
                        duration: duration,
                        success: true
                    ),
                    source: "AnigmaDaemonCore"
                )
                await publishEvidence(
                    action: "job.state.succeeded",
                    outcome: "allowed",
                    jobId: jobId,
                    traceID: TelemetryHash(input: "job.state.succeeded|\(jobId)").hex,
                    receiptID: receiptHash,
                    metadata: [
                        "progress_permille": "\(progressPermille)"
                    ]
                )
            } else if state == JobState.failed.rawValue {
                _ = await sharedEventBus.publish(
                    JobCompletedEvent(
                        jobId: jobId,
                        result: nil,
                        duration: duration,
                        success: false
                    ),
                    source: "AnigmaDaemonCore"
                )
                await publishEvidence(
                    action: "job.state.failed",
                    outcome: "failed",
                    jobId: jobId,
                    traceID: TelemetryHash(input: "job.state.failed|\(jobId)").hex,
                    receiptID: receiptHash,
                    metadata: [
                        "progress_permille": "\(progressPermille)",
                        "error": error?.message ?? "unknown"
                    ]
                )
            }
        
        case .progress:
            let progress = Double(progressPermille) / 1000.0
            _ = await sharedEventBus.publish(
                JobStatusUpdatedEvent(
                    jobId: jobId,
                    status: "progress",
                    progress: progress
                ),
                source: "AnigmaDaemonCore"
            )
        
        case .log:
            // Could publish to SystemNotificationEvent
            break
        
        case .output:
            // Could publish custom event for output artifacts
            break
        }
        
        // Placeholder for internal job event handling
    }

    private func publishEvidence(
        action: String,
        outcome: String,
        jobId: String,
        traceID: String,
        receiptID: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        let event = AgentEvidenceEvent.jobLifecycle(
            source: "AnigmaDaemonCore",
            action: action,
            outcome: outcome,
            traceID: traceID,
            jobID: jobId,
            receiptID: receiptID,
            payloadArtifactReferences: receiptID.map {
                [AgentEvidenceArtifactReference(
                    artifactID: $0,
                    role: "receipt"
                )]
            } ?? [],
            metadata: metadata
        )
        _ = await sharedEventBus.publishWithLogging(event, source: event.source)
    }
}
