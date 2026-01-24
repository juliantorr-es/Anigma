//
//  IntakeManager.swift
//  AnigmaAppMac
//
//  Handles document and file intake logic.
//  Extracted from AppStore.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AnigmaClientKit
import AnigmaWork
import ContractsCore

@MainActor
final class IntakeManager {
    weak var store: AppStore?
    
    init(store: AppStore) {
        self.store = store
    }
    
    func handleIntake(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        Task { @MainActor in
                            self.handleIntake(url: url)
                        }
                    }
                }
            }
        }
    }

    func handleIntake(url: URL) {
        let item = IntakeItem(
            id: UUID(),
            sourceId: UUID(),
            name: url.lastPathComponent,
            location: url,
            size: 0,
            status: .queued,
            importedAt: Date()
        )
        AppState.shared.intakeQueue.append(item)
        self.processIntake(item)
    }

    private func processIntake(_ item: IntakeItem) {
        guard let store = store else { return }
        
        let jobId = UUID()
        let initialJob = AnigmaJob(
            id: jobId,
            title: "Ingest: \(item.name)",
            message: "Initializing...",
            contextId: AppState.shared.currentContext?.id,
            status: .running,
            progress: 0.0,
            startedAt: Date()
        )
        store.localJobs.append(initialJob)

        Task {
            let url = item.location
            let isPDF = url.pathExtension.lowercased() == "pdf"

            if isPDF {
                let pdfJob = PDFImportJob()
                // Subscribe to progress and update localJobs
                let cancellable = pdfJob.progressPublisher
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] result in
                        guard let self = self, let store = self.store else { return }
                        if let index = store.localJobs.firstIndex(where: { $0.id == jobId }) {
                            if let progress = result.progress {
                                store.localJobs[index].progress = progress.percent / 100.0
                                store.localJobs[index].message = progress.message
                            }

                            switch result.state {
                            case .success:
                                store.localJobs[index].status = .completed
                                store.localJobs[index].progress = 1.0
                                store.localJobs[index].completedAt = result.endTime
                            case .failure:
                                store.localJobs[index].status = .failed
                                store.localJobs[index].message = result.failure?.message
                            default:
                                break
                            }
                        }
                    }

                let result = await pdfJob.importPDF(at: url)
                cancellable.cancel()

                // Handle completion effects (evidence, artifacts)
                handleIntakeCompletion(item: item, jobId: jobId, result: result)
            } else {
                // Generic Ingest
                await performGenericIngest(item: item, jobId: jobId)
            }
        }
    }

    private func handleIntakeCompletion<T: Codable>(item: IntakeItem, jobId: UUID, result: OperationResult<T>) {
        guard let store = store else { return }
        
        // 1. Update Intake Queue status
        if let idx = AppState.shared.intakeQueue.firstIndex(where: { $0.id == item.id }) {
            AppState.shared.intakeQueue[idx].status = (result.state == .success) ? .indexed : .error
        }

        // 2. Create Artifact if success
        if result.state == .success {
            let artifactId = item.id.uuidString
            if !store.artifacts.contains(where: { $0.id == artifactId }) {
                let artifact = AnigmaClientKit.ArtifactSummary(
                    id: artifactId,
                    name: item.name,
                    type: artifactType(for: item),
                    createdAt: Date()
                )
                store.artifacts.insert(artifact, at: 0)
                store.saveCache()
            }
        }

        // 3. Create Evidence
        let summaryText = (result.state == .success) ? "Imported \(item.name)" : "Import failed: \(result.failure?.message ?? "Unknown error")"
        let evidence = AnigmaEvidence(
            id: UUID(),
            jobId: jobId,
            contextId: AppState.shared.currentContext?.id,
            timestamp: Date(),
            type: .importEvent,
            summary: summaryText
        )
        AppState.shared.ledger.append(evidence)
    }

    private func performGenericIngest(item: IntakeItem, jobId: UUID) async {
        guard let store = store else { return }
        
        let url = item.location
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resources.fileSize ?? 0)

            // Phase 1: Reading
            store.updateJob(id: jobId, progress: 0.3, message: "Reading file attributes...")
            try await Task.sleep(nanoseconds: 500_000_000)

            // Phase 2: Metadata
            store.updateJob(id: jobId, progress: 0.6, message: "Extracting metadata...")
            try await Task.sleep(nanoseconds: 800_000_000)

            // Phase 3: Finalizing
            store.updateJob(id: jobId, progress: 0.9, message: "Finalizing ingestion...")
            try await Task.sleep(nanoseconds: 300_000_000)

            // Success
            if let index = store.localJobs.firstIndex(where: { $0.id == jobId }) {
                store.localJobs[index].status = .completed
                store.localJobs[index].progress = 1.0
                store.localJobs[index].completedAt = Date()
                store.localJobs[index].message = "Imported (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))"
            }

            // Completion effects
            let result = OperationResult<Int>(id: jobId, kind: "genericIngest", startTime: Date(), endTime: Date(), state: .success, payload: nil, progress: nil, failure: nil)
            handleIntakeCompletion(item: item, jobId: jobId, result: result)

        } catch {
            if let index = store.localJobs.firstIndex(where: { $0.id == jobId }) {
                store.localJobs[index].status = .failed
                store.localJobs[index].message = error.localizedDescription
            }
            let result = OperationResult<Int>(id: jobId, kind: "genericIngest", startTime: Date(), endTime: Date(), state: .failure, payload: nil, progress: nil, failure: .init(code: "INGEST_ERROR", message: error.localizedDescription, recoveryHint: nil))
            handleIntakeCompletion(item: item, jobId: jobId, result: result)
        }
    }

    private func artifactType(for item: IntakeItem) -> String {
        let ext = item.location.pathExtension.lowercased()
        return ext.isEmpty ? "file" : ext
    }
}
