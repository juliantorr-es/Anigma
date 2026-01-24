//
//  DaemonServer+Processing.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import ExecutionCore
import StorageCore

extension DaemonServer {
    func runJobProcessingLoop() async {
        logInfo("Starting continuous job processing loop", category: "JobProcessing")
        while !Task.isCancelled {
            if let job = await jobQueue.dequeue() {
                await executeJob(job)
            } else {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func executeJob(_ job: Job) async {
        logInfo("Starting job: \(job.id)", category: "JobExecution")
        var execOutputs: [ArtifactRef] = []
        var execError: String?
        var decision: ReceiptDecision = .allowed
        var reason: String = "JOB_COMPLETED"

        do {
            await jobQueue.markRunning(jobId: job.id)
            await emitJobEvent(jobId: job.id, type: .state, message: JobState.running.rawValue, progressPermille: 0)

            guard await jobRegistry.worker(for: job.spec.kind) != nil else {
                throw WorkerError.executionFailed("Unknown job kind: \(job.spec.kind)")
            }

            switch configuration.daemon.executionMode {
            case .subprocess:
                let worker = await workerPool.acquireWorker(for: job.id)
                defer {
                    let pool = self.workerPool
                    Task { await pool.releaseWorker(worker) }
                }

                let vaultData = try await loadVaultData(for: job.spec.inputs)
                let workerOutputs = try await worker.execute(job: job, vaultData: vaultData)
                execOutputs = try await ingestWorkerOutputs(workerOutputs, inputs: job.spec.inputs, jobId: job.id, jobKind: job.spec.kind)
            case .inProcess:
                let workerOutputs = try await executeInProcess(job)
                execOutputs = try await ingestWorkerOutputs(workerOutputs, inputs: job.spec.inputs, jobId: job.id, jobKind: job.spec.kind)
            }
        } catch {
            execError = error.localizedDescription
            decision = .error
            reason = "JOB_FAILED"
        }

        do {
            let receipt = try await receiptEngine.recordActionExecution(
                actionName: job.spec.kind,
                authority: "anigmad",
                decision: decision,
                reasonCode: reason,
                inputs: ["job_id": job.id],
                outputs: ["output_count": execOutputs.count, "error": execError ?? "none"]
            )

            if let err = execError {
                await jobQueue.fail(jobId: job.id, error: err, receiptHash: receipt.receiptID)
                await emitJobEvent(jobId: job.id, type: .state, message: JobState.failed.rawValue, progressPermille: 0, receiptHash: receipt.receiptID, error: ErrorStatus(code: "JOB_FAILED", message: err, detailJson: nil))
            } else {
                await jobQueue.complete(jobId: job.id, outputs: execOutputs, receiptHash: receipt.receiptID)
                await emitJobEvent(jobId: job.id, type: .state, message: JobState.succeeded.rawValue, progressPermille: 1000, receiptHash: receipt.receiptID)
            }
        } catch {
            print("Receipt failed: \(error)")
        }
    }

    func executeInProcess(_ job: Job) async throws -> [JobOutputPayload] {
        guard let worker = await jobRegistry.worker(for: job.spec.kind) else {
            throw WorkerError.executionFailed("Unknown job kind: \(job.spec.kind)")
        }

        let vaultData = try await loadVaultData(for: job.spec.inputs)
        return try await worker.execute(inputs: job.spec.inputs, config: job.spec.configCanonical, vaultData: vaultData)
    }

    func ingestWorkerOutputs(_ outputs: [JobOutputPayload], inputs: [ArtifactRef], jobId: String, jobKind: String) async throws -> [ArtifactRef] {
        var finalOutputs: [ArtifactRef] = []
        for output in outputs {
            let vKind = StorageCore.VaultArtifactKind(rawValue: output.kind) ?? .derived
            let ref = try await vault.ingest(data: output.data, kind: vKind, mime: output.mediaType)
            let artifactRef = ArtifactRef(hash: ref.sha256Hex, mediaType: ref.mime, sizeBytes: UInt64(ref.byteLen))
            finalOutputs.append(artifactRef)

            for input in inputs {
                try await vault.recordEdge(parentHash: input.hash, childHash: ref.sha256Hex, relation: "derived_from", runId: jobId, stepId: jobKind)
            }

            _ = try await receiptEngine.recordActionExecution(
                actionName: "job.output.ingest",
                authority: "anigmad",
                decision: .allowed,
                reasonCode: "OUTPUT_INGESTED",
                inputs: ["job_id": jobId, "output_hash": ref.sha256Hex],
                outputs: ["mime": ref.mime, "bytes": ref.byteLen]
            )
        }
        return finalOutputs
    }

    func loadVaultData(for inputs: [ArtifactRef]) async throws -> [String: Data] {
        // Placeholder
        return [:]
    }
}
