//
//  ContextManager.swift
//  AnigmaAppMac
//
//  Handles context activation and baseline analysis logic.
//  Extracted from AppStore.
//

import Foundation
import AnigmaClientKit
import AnigmaWork

@MainActor
final class ContextManager {
    weak var store: AppStore?
    
    init(store: AppStore) {
        self.store = store
    }
    
    func activateContext(_ context: AnigmaContext) {
        if AppState.shared.currentContext?.id != context.id {
            AppState.shared.currentContext = context

            // Check if we need to bootstrap (simulate checking if it's "fresh")
            let evidenceExists = AppState.shared.ledger.contains { $0.contextId == context.id }
            if !evidenceExists {
                 triggerBaselineAnalysis(for: context)
            }
        }
    }

    private func triggerBaselineAnalysis(for context: AnigmaContext) {
        guard let store = store else { return }
        
        let id = UUID()
        let initialJob = AnigmaJob(
            id: id,
            title: "Baseline: \(context.name)",
            message: "Initializing...",
            contextId: context.id,
            status: .running,
            progress: 0.05,
            startedAt: Date()
        )
        store.localJobs.append(initialJob)

        Task {
            await store.runSimulatedJob(id: id, stages: [
                (0.2, "Index verification..."),
                (0.4, "Invariant graph walk..."),
                (0.7, "Cross-source correlation..."),
                (0.9, "Generating evidence tokens...")
            ])

            let evidence = AnigmaEvidence(
                id: UUID(),
                jobId: id,
                contextId: context.id,
                timestamp: Date(),
                type: .jobCompletion,
                summary: "Atlas baseline established for \(context.name)"
            )
            AppState.shared.ledger.append(evidence)
        }
    }
}
