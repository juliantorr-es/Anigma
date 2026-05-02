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

            // If the context is fresh, ask the backend for authoritative status
            // rather than fabricating a local baseline-analysis job.
            let evidenceExists = AppState.shared.ledger.contains { $0.contextId == context.id }
            if !evidenceExists {
                 triggerBaselineAnalysis(for: context)
            }
        }
    }

    private func triggerBaselineAnalysis(for context: AnigmaContext) {
        guard let store = store else { return }

        Task {
            await store.refreshDaemonStatus()
            await MainActor.run {
                store.showToast(
                    title: "Context activated",
                    subtitle: "No local evidence found for \(context.name). Connect a source to start real ingestion.",
                    icon: "link"
                )
            }
        }
    }
}
