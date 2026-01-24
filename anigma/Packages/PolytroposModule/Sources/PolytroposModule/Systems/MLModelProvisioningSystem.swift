//
//  MLModelProvisioningSystem.swift
//  PolytroposModule
//
//  System for ML model provisioning with consent validation and atomic installation.
//

import AnigmaCore
import CryptoKit
import Foundation
import AnigmaPrimitives

// MARK: - ML Model Provisioning System

/// Handles background model downloads, atomic installation, and consent validation.
public struct MLModelProvisioningSystem: System {
    public let name = "MLModelProvisioning"

    private let workDirectory: URL
    private let offlineMode: Bool
    private let networkBlocker: NetworkBlocker?

    public init(
        workDirectory: URL,
        offlineMode: Bool = false,
        networkBlocker: NetworkBlocker? = nil
    ) {
        self.workDirectory = workDirectory
        self.offlineMode = offlineMode
        self.networkBlocker = networkBlocker
    }

    public func update(world: World) async {
        await processPendingDownloads(world: world)
        await processInstallations(world: world)
        await validateConsentRequirements(world: world)
        await performMaintenanceTasks(world: world)
    }

    // MARK: - Download Management

    private func processPendingDownloads(world: World) async {
        guard !offlineMode else { return }

        let packEntities = await world.entitiesWith(ModelPackRegistryComponent.self)

        for entityId in packEntities {
            guard let pack = await world.getComponent(entityId, ModelPackRegistryComponent.self),
                  pack.installationStatus == .downloading else {
                continue
            }

            await continueDownload(for: entityId, pack: pack, world: world)
        }
    }

    private func continueDownload(
        for entityId: EntityId,
        pack: ModelPackRegistryComponent,
        world: World
    ) async {
        let downloadManager = ModelDownloadManager(
            workDirectory: workDirectory,
            networkBlocker: networkBlocker
        )

        let result = await downloadManager.continueDownload(
            pack: pack
        )            { progress in
                Task {
                    await Logger.shared.debug(
                        "Download progress for \(pack.name): \(String(format: "%.1f", progress * 100))%",
                        category: "Polytropos"
                    )
                }
            }

        switch result.status {
        case .completed:
            var updatedPack = pack
            updatedPack.installationStatus = .verifying
            await world.addComponent(entityId, updatedPack)

            await Logger.shared.info(
                "Download completed for model pack: \(pack.name)",
                category: "Polytropos"
            )
        case .failed(let reason):
            await Logger.shared.error(
                "Download failed for model pack \(pack.name): \(reason)",
                category: "Polytropos"
            )

            var updatedPack = pack
            updatedPack.installationStatus = .failed
            await world.addComponent(entityId, updatedPack)
        case .cancelled:
            await Logger.shared.warning(
                "Download cancelled for model pack \(pack.name)",
                category: "Polytropos"
            )

            var updatedPack = pack
            updatedPack.installationStatus = .failed
            await world.addComponent(entityId, updatedPack)
        }
    }

    // MARK: - Installation Management

    private func processInstallations(world: World) async {
        let packEntities = await world.entitiesWith(ModelPackRegistryComponent.self)

        for entityId in packEntities {
            guard let pack = await world.getComponent(entityId, ModelPackRegistryComponent.self) else {
                continue
            }

            switch pack.installationStatus {
            case .verifying:
                await verifyAndInstall(pack: pack, entityId: entityId, world: world)
            case .updating:
                await performUpdate(pack: pack, entityId: entityId, world: world)
            case .installed:
                await validateHealth(pack: pack, entityId: entityId, world: world)
            default:
                break
            }
        }
    }

    private func verifyAndInstall(
        pack: ModelPackRegistryComponent,
        entityId: EntityId,
        world: World
    ) async {
        let installer = ModelPackInstaller(workDirectory: workDirectory)

        do {
            // Verify integrity
            _ = try await installer.verify(pack: pack)

            // Perform atomic installation
            let installPath = try await installer.install(pack: pack)

            // Update status
            var updatedPack = pack
            updatedPack.installationStatus = .installed
            updatedPack.verification.verifiedAt = Date()
            updatedPack.verification.verificationResult = .passed
            await world.addComponent(entityId, updatedPack)

            // Create installation record
            let record = ModelInstallationRecordComponent(
                modelPackId: pack.id,
                currentState: .completed,
                approvalStatus: .approved,
                installedAt: Date(),
                installationPath: installPath,
                healthStatus: .healthy
            )

            let recordEntity = await world.createEntity()
            await world.addComponent(recordEntity, record)

            await Logger.shared.info(
                "Successfully installed model pack: \(pack.name) v\(pack.version)",
                category: "Polytropos"
            )
        } catch {
            await Logger.shared.error(
                "Installation failed for model pack \(pack.name): \(error)",
                category: "Polytropos"
            )

            var updatedPack = pack
            updatedPack.installationStatus = .failed
            await world.addComponent(entityId, updatedPack)
        }
    }

    private func performUpdate(
        pack: ModelPackRegistryComponent,
        entityId: EntityId,
        world: World
    ) async {
        // Implementation for updating existing models
        await Logger.shared.info(
            "Updating model pack: \(pack.name)",
            category: "Polytropos"
        )
    }

    private func validateHealth(
        pack: ModelPackRegistryComponent,
        entityId: EntityId,
        world: World
    ) async {
        let healthChecker = ModelHealthChecker(workDirectory: workDirectory)

        let health = await healthChecker.checkHealth(pack: pack)

        // Update health status in installation record
        let recordEntities = await world.entitiesWith(ModelInstallationRecordComponent.self)

        for recordEntityId in recordEntities {
            guard var record = await world.getComponent(recordEntityId, ModelInstallationRecordComponent.self),
                  record.modelPackId == pack.id else {
                continue
            }

            record.healthStatus = health
            await world.addComponent(recordEntityId, record)
            break
        }
    }

    // MARK: - Consent Validation

    private func validateConsentRequirements(world: World) async {
        let consentEntities = await world.entitiesWith(MLModelConsentComponent.self)

        for entityId in consentEntities {
            guard var consent = await world.getComponent(entityId, MLModelConsentComponent.self) else {
                continue
            }

            // Check for expired consent
            if consent.isValid == false && consent.consentState == .granted {
                consent.consentState = .expired
                await world.addComponent(entityId, consent)

                await Logger.shared.info(
                    "Consent expired for model type: \(consent.modelType)",
                    category: "Polytropos"
                )
            }

            // Check for consent nearing expiration (7 days)
            if consent.expiresWithin(7 * 24 * 60 * 60) && consent.autoRenewalEnabled {
                await initiateConsentRenewal(consent: consent, entityId: entityId, world: world)
            }
        }
    }

    private func initiateConsentRenewal(
        consent: MLModelConsentComponent,
        entityId: EntityId,
        world: World
    ) async {
        // Create consent flow UI component for renewal
        let flowUI = ConsentFlowUIComponent(
            currentStep: .confirmation,
            pendingConsents: [consent.modelType],
            flowContext: FlowContext(
                initiatingFeature: "consent_renewal",
                urgency: .normal
            )
        )

        let flowEntity = await world.createEntity()
        await world.addComponent(flowEntity, flowUI)

        await Logger.shared.info(
            "Initiated consent renewal for model type: \(consent.modelType)",
            category: "Polytropos"
        )
    }

    // MARK: - Maintenance Tasks

    private func performMaintenanceTasks(world: World) async {
        await cleanupUnusedModels(world: world)
        await cleanupExpiredConsentFlows(world: world)
        await optimizeModelStorage(world: world)
    }

    private func cleanupUnusedModels(world: World) async {
        let recordEntities = await world.entitiesWith(ModelInstallationRecordComponent.self)

        for entityId in recordEntities {
            guard let record = await world.getComponent(entityId, ModelInstallationRecordComponent.self),
                  record.healthStatus == .outdated || record.healthStatus == .corrupted else {
                continue
            }

            await uninstallModel(record: record, world: world)
        }
    }

    private func uninstallModel(record: ModelInstallationRecordComponent, world: World) async {
        let uninstaller = ModelPackInstaller(workDirectory: workDirectory)

        do {
            try await uninstaller.uninstall(modelPackId: record.modelPackId)

            await Logger.shared.info(
                "Uninstalled model pack: \(record.modelPackId)",
                category: "Polytropos"
            )
        } catch {
            await Logger.shared.error(
                "Failed to uninstall model pack \(record.modelPackId): \(error)",
                category: "Polytropos"
            )
        }
    }

    private func cleanupExpiredConsentFlows(world: World) async {
        let flowEntities = await world.entitiesWith(ConsentFlowUIComponent.self)

        for entityId in flowEntities {
            guard var flow = await world.getComponent(entityId, ConsentFlowUIComponent.self) else {
                continue
            }

            // Mark flows as abandoned after 24 hours of inactivity
            if flow.interactionState.timeSpent > 24 * 60 * 60 && !flow.interactionState.abandoned {
                flow.interactionState.abandoned = true
                flow.interactionState.abandonmentReason = "timeout"
                await world.addComponent(entityId, flow)
            }
        }
    }

    private func optimizeModelStorage(world: World) async {
        let optimizer = ModelStorageOptimizer(workDirectory: workDirectory)
        await optimizer.optimize()
    }
}

// MARK: - Supporting Classes

/// Tracks the lifecycle state of a download attempt.
public enum DownloadStatus: Sendable {
    case completed
    case failed(reason: String)
    case cancelled
}

/// Result returned after a download attempt finishes or aborts.
public struct DownloadResult: Sendable {
    public let packId: UUID
    public let progress: Double
    public let status: DownloadStatus

    public init(packId: UUID, progress: Double, status: DownloadStatus) {
        self.packId = packId
        self.progress = progress
        self.status = status
    }
}

/// Manages model downloads with progress tracking and network controls.
public actor ModelDownloadManager {
    private let workDirectory: URL
    private let networkBlocker: NetworkBlocker?
    private var activeDownloads: [UUID: Task<DownloadResult, Never>] = [:]

    public init(workDirectory: URL, networkBlocker: NetworkBlocker? = nil) {
        self.workDirectory = workDirectory
        self.networkBlocker = networkBlocker
    }

    public func continueDownload(
        pack: ModelPackRegistryComponent,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async -> DownloadResult {
        if let blocker = networkBlocker {
            do {
                try blocker.validateNetworkAccess(for: pack.downloadInfo.url)
            } catch {
                return DownloadResult(
                    packId: pack.id,
                    progress: 0,
                    status: .failed(reason: "Network blocked: \(error.localizedDescription)")
                )
            }
        }

        let downloadTask: Task<DownloadResult, Never>
        if let existingTask = activeDownloads[pack.id] {
            downloadTask = existingTask
        } else {
            let destination = downloadDestination(for: pack, workDirectory: workDirectory)
            downloadTask = Task.detached { [pack = pack, destination, onProgress] in
                await ModelDownloadManager.executeDownload(
                    pack: pack,
                    destination: destination,
                    onProgress: onProgress
                )
            }
            activeDownloads[pack.id] = downloadTask
        }

        let result = await downloadTask.value
        activeDownloads[pack.id] = nil
        return result
    }

    public func cancelDownload(packId: UUID) {
        activeDownloads[packId]?.cancel()
    }

    private static func executeDownload(
        pack: ModelPackRegistryComponent,
        destination: URL,
        onProgress: @Sendable (Double) -> Void
    ) async -> DownloadResult {
        if Task.isCancelled {
            return DownloadResult(packId: pack.id, progress: 0, status: .cancelled)
        }

        onProgress(0.0)

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: pack.downloadInfo.url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return DownloadResult(
                    packId: pack.id,
                    progress: 0,
                    status: .failed(reason: "HTTP \(httpResponse.statusCode)")
                )
            }

            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            onProgress(1.0)
            return DownloadResult(packId: pack.id, progress: 1.0, status: .completed)
        } catch {
            return DownloadResult(
                packId: pack.id,
                progress: 0,
                status: .failed(reason: error.localizedDescription)
            )
        }
    }
}

/// Handles atomic model installation with hash verification.
public actor ModelPackInstaller {
    private let workDirectory: URL

    public init(workDirectory: URL) {
        self.workDirectory = workDirectory
    }

    public func verify(pack: ModelPackRegistryComponent) async throws -> String {
        let payloadURL = downloadDestination(for: pack, workDirectory: workDirectory)
        guard FileManager.default.fileExists(atPath: payloadURL.path) else {
            throw ModelProvisioningError.missingDownload(pack.id)
        }

        let data = try Data(contentsOf: payloadURL)
        let digest = SHA256.hash(data: data)
        let actualHash = digest.compactMap { String(format: "%02x", $0) }.joined()
        let expectedHash = pack.verification.expectedHash.isEmpty ? pack.downloadInfo.checksum : pack.verification.expectedHash

        guard expectedHash.isEmpty || expectedHash == actualHash else {
            throw ModelProvisioningError.hashMismatch(expected: expectedHash, actual: actualHash)
        }

        return actualHash
    }

    public func install(pack: ModelPackRegistryComponent) async throws -> String {
        let payloadURL = downloadDestination(for: pack, workDirectory: workDirectory)
        let installDir = workDirectory.appendingPathComponent("models").appendingPathComponent(pack.id.uuidString)
        let installPayload = installDir.appendingPathComponent("payload.bin")

        try FileManager.default.createDirectory(at: installDir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: installPayload.path) {
            try FileManager.default.removeItem(at: installPayload)
        }
        try FileManager.default.moveItem(at: payloadURL, to: installPayload)
        return installDir.path
    }

    public func uninstall(modelPackId: UUID) async throws {
        let installDir = workDirectory.appendingPathComponent("models").appendingPathComponent(modelPackId.uuidString)
        if FileManager.default.fileExists(atPath: installDir.path) {
            try FileManager.default.removeItem(at: installDir)
        }
    }
}

/// Checks health and integrity of installed models.
public actor ModelHealthChecker {
    private let workDirectory: URL

    public init(workDirectory: URL) {
        self.workDirectory = workDirectory
    }

    public func checkHealth(pack: ModelPackRegistryComponent) async -> ModelHealthStatus {
        let installDir = workDirectory.appendingPathComponent("models").appendingPathComponent(pack.id.uuidString)
        let payload = installDir.appendingPathComponent("payload.bin")
        return FileManager.default.fileExists(atPath: payload.path) ? .healthy : .corrupted
    }
}

/// Blocks network access for offline mode enforcement.
public protocol NetworkBlocker: Sendable {
    func validateNetworkAccess(for url: URL) throws
}

/// Optimizes model storage and cache management.
public actor ModelStorageOptimizer {
    private let workDirectory: URL

    public init(workDirectory: URL) {
        self.workDirectory = workDirectory
    }

    public func optimize() async {
        let downloadsDir = workDirectory.appendingPathComponent("downloads")
        if let files = try? FileManager.default.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: nil, options: []) {
            for fileURL in files {
                if fileURL.lastPathComponent == ".DS_Store" {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }
}

private enum ModelProvisioningError: Error, LocalizedError {
    case missingDownload(UUID)
    case hashMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .missingDownload(let id):
            return "Missing download payload for pack \(id)"
        case .hashMismatch(let expected, let actual):
            return "Model pack hash mismatch: expected \(expected), got \(actual)"
        }
    }
}

private func downloadDestination(for pack: ModelPackRegistryComponent, workDirectory: URL) -> URL {
    let downloadDir = workDirectory.appendingPathComponent("downloads").appendingPathComponent(pack.id.uuidString)
    return downloadDir.appendingPathComponent("payload.bin")
}
