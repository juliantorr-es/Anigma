//
//  DaemonServer+Processing.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import ExecutionCore
import StorageCore
import AnigmaPrimitives
import OSLog

private let processingLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "JobProcessing")

private func processingCheckpoint(_ message: String) {
    processingLogger.info("\(message, privacy: .public)")
}

extension DaemonServer {
    func runJobProcessingLoop() async {
        processingCheckpoint("loop started")
        processingLogger.info("Job processing loop started")
        logInfo("Starting continuous job processing loop", category: "JobProcessing")
        while !Task.isCancelled {
            if let job = await jobQueue.dequeue() {
                processingCheckpoint("dequeued jobId=\(job.jobId) kind=\(job.spec.kind)")
                processingLogger.info("Dequeued job \(job.jobId, privacy: .public) kind=\(job.spec.kind, privacy: .public)")
                await executeJob(job)
            } else {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func executeJob(_ job: Job) async {
        processingCheckpoint("execute start jobId=\(job.jobId) kind=\(job.spec.kind)")
        processingLogger.info("Execute job \(job.jobId, privacy: .public) kind=\(job.spec.kind, privacy: .public)")
        logInfo("Starting job: \(job.jobId)", category: "JobExecution")
        var execOutputs: [ArtifactRef] = []
        var execError: String?
        var decision: ReceiptDecision = .allowed
        var reason: String = "JOB_COMPLETED"

        do {
            await jobQueue.markRunning(jobId: job.jobId)
            processingCheckpoint("marked running jobId=\(job.jobId)")
            await emitJobEvent(jobId: job.jobId, type: .state, message: JobState.running.rawValue, progressPermille: 0)

            guard await jobRegistry.worker(for: job.spec.kind) != nil else {
                throw WorkerError.executionFailed("Unknown job kind: \(job.spec.kind)")
            }

            switch configuration.daemon.executionMode {
            case .subprocess:
                if job.spec.kind == IndexingWorker.kind {
                    logInfo("Falling back to in-process execution for \(job.spec.kind)", category: "JobExecution")
                    let workerOutputs = try await executeInProcess(job)
                    execOutputs = try await ingestWorkerOutputs(workerOutputs, inputs: job.spec.inputs, jobId: job.jobId, jobKind: job.spec.kind)
                } else {
                    let worker = await workerPool.acquireWorker(for: job.jobId)
                    defer {
                        let pool = self.workerPool
                        Task { await pool.releaseWorker(worker) }
                    }

                    let vaultData = try await loadVaultData(for: job.spec.inputs)
                    let workerOutputs = try await worker.execute(job: job, vaultData: vaultData)
                    execOutputs = try await ingestWorkerOutputs(workerOutputs, inputs: job.spec.inputs, jobId: job.jobId, jobKind: job.spec.kind)
                }
            case .inProcess:
                let workerOutputs = try await executeInProcess(job)
                execOutputs = try await ingestWorkerOutputs(workerOutputs, inputs: job.spec.inputs, jobId: job.jobId, jobKind: job.spec.kind)
            }
        } catch {
            execError = error.localizedDescription
            decision = .error
            reason = "JOB_FAILED"
            processingCheckpoint("execute error jobId=\(job.jobId) error=\(error.localizedDescription)")
            processingLogger.error("Job \(job.jobId, privacy: .public) failed before receipt: \(error.localizedDescription, privacy: .public)")
        }

        do {
            let receipt = try await receiptEngine.recordActionExecution(
                actionName: job.spec.kind,
                authority: "anigmad",
                decision: decision,
                reasonCode: reason,
                inputs: ["job_id": job.jobId],
                outputs: ["output_count": execOutputs.count, "error": execError ?? "none"]
            )

            if let err = execError {
                processingCheckpoint("mark fail jobId=\(job.jobId) receipt=\(receipt.receiptID)")
                await jobQueue.fail(jobId: job.jobId, error: err, receiptHash: receipt.receiptID)
                await emitJobEvent(jobId: job.jobId, type: .state, message: JobState.failed.rawValue, progressPermille: 0, receiptHash: receipt.receiptID, error: ErrorStatus(code: "JOB_FAILED", message: err, detailJson: nil))
            } else {
                processingCheckpoint("mark complete jobId=\(job.jobId) outputs=\(execOutputs.count)")
                await jobQueue.complete(jobId: job.jobId, outputs: execOutputs, receiptHash: receipt.receiptID)
                await emitJobEvent(jobId: job.jobId, type: .state, message: JobState.succeeded.rawValue, progressPermille: 1000, receiptHash: receipt.receiptID)
            }
        } catch {
            processingCheckpoint("receipt error jobId=\(job.jobId) error=\(error.localizedDescription)")
            Self.logger.error("CoreReceipt failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func executeInProcess(_ job: Job) async throws -> [JobOutputPayload] {
        guard let worker = await jobRegistry.worker(for: job.spec.kind) else {
            throw WorkerError.executionFailed("Unknown job kind: \(job.spec.kind)")
        }

        let vaultData = try await loadVaultData(for: job.spec.inputs)
        let inputs = job.spec.inputs.map { ArtifactRef(hash: $0.hash, mediaType: $0.mediaType, sizeBytes: $0.sizeBytes) }
        return try await worker.execute(inputs: inputs, config: job.spec.configCanonical, vaultData: vaultData)
    }

    func ingestWorkerOutputs(_ outputs: [JobOutputPayload], inputs: [AnigmaArtifactRef], jobId: String, jobKind: String) async throws -> [ArtifactRef] {
        var finalOutputs: [ArtifactRef] = []
        for output in outputs {
            let vKind = StorageCore.VaultArtifactKind(rawValue: output.kind) ?? .derived
            let ref = try await vault.ingest(data: output.data, kind: vKind, mime: output.mediaType)
            let artifactRef = ArtifactRef(hash: ref.hashHex, mediaType: ref.mime, sizeBytes: UInt64(ref.byteLen))
            finalOutputs.append(artifactRef)

            for input in inputs {
                try await vault.recordEdge(parentHash: input.hash, childHash: ref.hashHex, relation: "derived_from", runId: jobId, stepId: jobKind)
            }

            _ = try await receiptEngine.recordActionExecution(
                actionName: "job.output.ingest",
                authority: "anigmad",
                decision: .allowed,
                reasonCode: "OUTPUT_INGESTED",
                inputs: ["job_id": jobId, "output_hash": ref.hashHex],
                outputs: ["mime": ref.mime, "bytes": ref.byteLen]
            )
        }
        return finalOutputs
    }

    func loadVaultData(for inputs: [AnigmaArtifactRef]) async throws -> [String: Data] {
        // STUB_TRACK: daemon-vault-loading – Vault data loading not implemented
        processingLogger.warning("STUB INVOKED: DaemonServer.loadVaultData()")
        processingLogger.error("DaemonServer.loadVaultData() is not implemented; refusing to execute with empty vault data")
        
        throw WorkerError.executionFailed(
            "Vault data loading not implemented for \(inputs.count) artifacts. Process requires StorageCore.Vault integration."
        )
    }
}
