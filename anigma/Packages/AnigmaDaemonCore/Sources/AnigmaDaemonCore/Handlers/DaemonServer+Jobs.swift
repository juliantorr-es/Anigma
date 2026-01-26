//
//  DaemonServer+Jobs.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore

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
            let jobId = await jobQueue.submit(spec: spec, clientId: ctx.clientId)

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
            jobId: job.id,
            state: job.state.rawValue,
            progressPermille: job.state == .succeeded ? 1000 : 0,
            outputs: job.outputs,
            finalReceiptHash: job.receiptHash,
            error: job.errorMessage.map {
                ErrorStatus(code: "JOB_FAILED", message: $0, detailJson: nil)
            }
        )
    }

    /// Cancel a running or queued job
    func handleCancelJob(
        ctx: DaemonRequestContext,
        jobId: String
    ) async throws -> CancelJobResponse {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return CancelJobResponse(canceled: false, receiptHash: nil, error: ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
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
            return CancelJobResponse(
                canceled: true,
                receiptHash: nil,
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
                print("failed to record job list receipt: \(error)")
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
        // Placeholder
    }
}
