//
//  BootstrappedAppClient.swift
//  AnigmaAppMac
//
//  Daemon-backed HarmoniaAppClient for the launcher runtime.
//

import Foundation
import AnigmaCore
import AnigmaHostMac
import AnigmaPrimitives
import AnigmaSidecar
import HarmoniaV2Surface
import HarmoniaV2Core
import HarmoniaV2Contracts
import OSLog

public actor BootstrappedAppClient: HarmoniaAppClient {
    private static let logger = Logger(subsystem: "com.anigma.AnigmaAppMac", category: "BootstrappedAppClient")
    private let daemonCapability: DaemonHostCapability
    private var bridge: SidecarBridge?
    private var hasBootstrapped = false

    public init(
        daemonCapability: DaemonHostCapability
    ) {
        self.daemonCapability = daemonCapability
    }

    public func bootstrap() async throws {
        if hasBootstrapped { return }

        // Canonical startup path: the mac app first ensures the daemon is alive
        // through the Harmonia control plane, then opens the daemon bridge used
        // by the assistant panels.
        _ = try await daemonCapability.ensureDaemonRunning()
        _ = try await ensureBridge()
        hasBootstrapped = true
        Self.logger.info("Bootstrapped daemon-backed app client")
    }

    public func getStatus(projectId: String?) async throws -> AppStatus {
        try await ensureBootstrapped()
        let response = try await ensureBridge().assistantStatus(projectId: projectId)
        try throwIfNeeded(response.error)

        return AppStatus(
            operatingMode: HarmoniaV2Contracts.OperatingMode(rawValue: response.operatingMode) ?? .normal,
            modeSource: ModeSource(rawValue: response.modeSource) ?? .defaultMode,
            killSwitchActive: response.killSwitchActive,
            killSwitchReason: response.killSwitchReason,
            lastDenial: nil
        )
    }

    public func setMode(_ mode: HarmoniaV2Contracts.OperatingMode, for projectId: String?, principal: Principal) async throws {
        try await ensureBootstrapped()
        let response = try await ensureBridge().assistantSetMode(
            mode: mode.rawValue,
            projectId: projectId,
            principalId: principal.id,
            principalDisplayName: principal.displayName
        )
        try throwIfNeeded(response.error)
    }

    public func setKillSwitch(active: Bool, for projectId: String?, reason: String?, principal: Principal) async throws {
        try await ensureBootstrapped()
        let response = try await ensureBridge().assistantSetKillSwitch(
            active: active,
            projectId: projectId,
            reason: reason,
            principalId: principal.id,
            principalDisplayName: principal.displayName
        )
        try throwIfNeeded(response.error)
    }

    public func createProject(id: String, name: String, embeddingModel: String, principal: Principal) async throws {
        try await ensureBootstrapped()
        let response = try await ensureBridge().assistantCreateProject(
            id: id,
            name: name,
            embeddingModel: embeddingModel,
            principalId: principal.id,
            principalDisplayName: principal.displayName
        )
        try throwIfNeeded(response.error)
    }

    public func listProjects() async throws -> [ProjectRecord] {
        try await ensureBootstrapped()
        let response = try await ensureBridge().assistantListProjects()
        try throwIfNeeded(response.error)

        return response.projects.map {
            ProjectRecord(
                id: $0.id,
                name: $0.name,
                createdAt: Date(timeIntervalSince1970: TimeInterval($0.createdAtUnixMs) / 1000),
                embeddingModel: $0.embeddingModel
            )
        }
    }

    public func index(folder: URL, projectId: String, principal: Principal, dryRun: Bool) async throws -> AsyncStream<IndexProgress> {
        try await ensureBootstrapped()
        let response = try await ensureBridge().assistantStartIndex(
            folderPath: folder.path,
            projectId: projectId,
            principalId: principal.id,
            principalDisplayName: principal.displayName,
            dryRun: dryRun
        )
        try throwIfNeeded(response.error)

        if let result = response.result {
            return AsyncStream { continuation in
                continuation.yield(IndexProgress.scanning(response.totalFiles))
                continuation.yield(IndexProgress.complete(total: response.totalFiles, chunks: result.chunksCreated + result.chunksReused))
                continuation.finish()
            }
        }

        guard let jobId = response.jobId else {
            return AsyncStream { continuation in
                continuation.yield(IndexProgress.complete(total: response.totalFiles, chunks: 0))
                continuation.finish()
            }
        }

        let bridge = try await ensureBridge()
        Self.logger.info("Started daemon index job '\(jobId, privacy: .public)' for project '\(projectId, privacy: .public)'")
        return AsyncStream { continuation in
            let task = Task {
                continuation.yield(IndexProgress.scanning(response.totalFiles))
                do {
                    while !Task.isCancelled {
                        let status = try await bridge.getJobStatus(jobId: jobId)
                        try await self.throwIfNeeded(status.error)

                        switch status.state.lowercased() {
                        case "queued":
                            continuation.yield(IndexProgress.scanning(response.totalFiles))
                        case "running":
                            let processed = response.totalFiles > 0
                                ? Int((Double(status.progressPermille) / 1000.0) * Double(response.totalFiles))
                                : 0
                            continuation.yield(
                                IndexProgress.processing(
                                    min(max(processed, 1), max(response.totalFiles, 1)),
                                    of: max(response.totalFiles, 1),
                                    chunks: 0,
                                    file: folder.lastPathComponent
                                )
                            )
                        case "succeeded":
                            let chunks = try await self.fetchIndexChunks(outputs: status.outputs)
                            continuation.yield(IndexProgress.complete(total: response.totalFiles, chunks: chunks))
                            continuation.finish()
                            return
                        case "canceled":
                            continuation.yield(IndexProgress.failed("Cancelled", processed: 0, total: response.totalFiles, chunks: 0))
                            continuation.finish()
                            return
                        case "failed":
                            continuation.yield(IndexProgress.failed("Daemon indexing failed", processed: 0, total: response.totalFiles, chunks: 0))
                            continuation.finish()
                            return
                        default:
                            break
                        }

                        try await Task.sleep(for: .milliseconds(500))
                    }

                    continuation.finish()
                } catch {
                    Self.logger.error("Daemon index polling failed for '\(jobId, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                    continuation.yield(IndexProgress.failed(error.localizedDescription, processed: 0, total: response.totalFiles, chunks: 0))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func recall(query: String, projectId: String, options: RecallOptions) async throws -> RecallResult {
        try await ensureBootstrapped()
        let response = try await ensureBridge().assistantRecall(
            query: query,
            projectId: projectId,
            options: AnigmaAssistantRecallOptions(
                topK: options.topK,
                scanLimit: options.scanLimit,
                threshold: options.threshold,
                hybrid: options.hybrid,
                explain: options.explain
            )
        )
        try throwIfNeeded(response.error)

        return RecallResult(
            query: response.query,
            projectId: response.projectId,
            results: response.results.map {
                RecallItem(
                    id: $0.id,
                    content: $0.content,
                    similarity: $0.similarity,
                    rank: $0.rank,
                    vectorRank: $0.vectorRank,
                    ftsRank: $0.ftsRank,
                    rrfScore: $0.rrfScore,
                    metadata: $0.metadata
                )
            },
            stats: RecallStats(
                rowsScanned: response.stats?.rowsScanned ?? 0,
                scanLimit: response.stats?.scanLimit,
                executionTime: response.stats?.executionTime ?? 0
            )
        )
    }

    public func addMemo(text: String, projectId: String, principal: Principal) async throws -> StoredMemoryRecord {
        try await ensureBootstrapped()
        let response = try await ensureBridge().assistantAddMemo(
            text: text,
            projectId: projectId,
            principalId: principal.id,
            principalDisplayName: principal.displayName
        )
        try throwIfNeeded(response.error)

        guard let record = response.record else {
            throw BootstrappedAppClientError.remoteError(code: "MISSING_RECORD", message: "Daemon did not return a stored memo record")
        }

        return StoredMemoryRecord(
            id: record.id,
            content: record.content,
            metadata: record.metadata,
            embedding: nil,
            embeddingModel: record.embeddingModel,
            createdAt: Date(timeIntervalSince1970: TimeInterval(record.createdAtUnixMs) / 1000)
        )
    }

    // MARK: - Vault Operations
    
    public func getVaultStatus() async throws -> HarmoniaV2Contracts.HarmoniaClient.VaultStatusResponse {
        try await ensureBootstrapped()
        let response = try await ensureBridge().getVaultStatus()
        try throwIfNeeded(response.error)
        
        return HarmoniaClient.VaultStatusResponse(
            isHealthy: response.isHealthy,
            receiptCount: response.receiptCount,
            diskUsage: response.diskUsage,
            headHash: response.headHash,
            lastVerifiedAt: response.lastVerifiedAt
        )
    }
    
    public func verifyVault() async throws -> HarmoniaV2Contracts.HarmoniaClient.VaultVerifyResponse {
        try await ensureBootstrapped()
        let response = try await ensureBridge().verifyVault()
        try throwIfNeeded(response.error)
        return HarmoniaClient.VaultVerifyResponse(success: response.success, message: response.message)
    }
    
    public func runVaultGC(dryRun: Bool) async throws -> HarmoniaV2Contracts.HarmoniaClient.VaultGCResponse {
        try await ensureBootstrapped()
        let response = try await ensureBridge().runVaultGC(dryRun: dryRun)
        try throwIfNeeded(response.error)
        return HarmoniaClient.VaultGCResponse(success: response.success, deletedCount: response.deletedCount, reclaimedSpace: response.reclaimedSpace)
    }
    
    // MARK: - Pipeline Operations
    
    public func listPipelines() async throws -> AnigmaPipelineListResponse {
        try await ensureBootstrapped()
        return try await ensureBridge().listPipelines()
    }
    
    public func createPipeline(name: String, stages: [PipelineStage]) async throws -> AnigmaPipelineCreateResponse {
        try await ensureBootstrapped()
        return try await ensureBridge().createPipeline(name: name, stages: stages)
    }
    
    public func runPipeline(pipelineId: String, inputs: [String: String]) async throws -> AnigmaPipelineRunResponse {
        try await ensureBootstrapped()
        return try await ensureBridge().runPipeline(pipelineId: pipelineId, inputs: inputs)
    }
    
    public func getPipelineStatus(runId: String) async throws -> AnigmaPipelineStatusResponse {
        try await ensureBootstrapped()
        return try await ensureBridge().getPipelineStatus(runId: runId)
    }
    
    public func cancelPipeline(runId: String) async throws -> AnigmaPipelineCancelResponse {
        try await ensureBootstrapped()
        return try await ensureBridge().cancelPipeline(runId: runId)
    }

    private func ensureBootstrapped() async throws {
        if !hasBootstrapped {
            try await bootstrap()
        }
    }

    private func ensureBridge() async throws -> SidecarBridge {
        if let bridge {
            return bridge
        }

        let bridge = try await SidecarBridge.create(
            clientName: "AnigmaAppMac",
            scopes: ["system.read", "project.read", "project.write", "governance.write", "job.submit", "job.read", "vault.read"]
        )
        self.bridge = bridge
        Self.logger.info("Created daemon sidecar bridge for launcher runtime")
        return bridge
    }

    private func fetchIndexChunks(outputs: [AnigmaArtifactRef]) async throws -> Int {
        guard let output = outputs.first else {
            return 0
        }

        let artifact = try await ensureBridge().retrieveArtifact(hash: output.hash)
        try throwIfNeeded(artifact.error)

        let result = try JSONDecoder().decode(AnigmaAssistantIndexResult.self, from: artifact.data)
        return result.chunksCreated + result.chunksReused
    }

    private func throwIfNeeded(_ error: AnigmaErrorStatus?) throws {
        if let error {
            throw BootstrappedAppClientError.remoteError(code: error.code, message: error.message)
        }
    }
}

enum BootstrappedAppClientError: LocalizedError {
    case remoteError(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .remoteError(let code, let message):
            return "\(code): \(message)"
        }
    }
}
