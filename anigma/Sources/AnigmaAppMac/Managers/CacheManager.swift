//
//  CacheManager.swift
//  AnigmaAppMac
//
//  Handles state caching and persistence using UserDefaults.
//  Extracted from AppStore.
//

import Foundation
import AnigmaClientKit

@MainActor
final class CacheManager {
    weak var store: AppStore?
    
    init(store: AppStore) {
        self.store = store
    }
    
    func saveCache() {
        guard let store = store else { return }
        
        let encoder = JSONEncoder()
        if let encodedWorkspaces = try? encoder.encode(store.workspaces) {
            UserDefaults.standard.set(encodedWorkspaces, forKey: "cache_workspaces")
        }
        if let encodedArtifacts = try? encoder.encode(store.artifacts) {
            UserDefaults.standard.set(encodedArtifacts, forKey: "cache_artifacts")
        }
        if let encodedJobs = try? encoder.encode(store.jobs) {
            UserDefaults.standard.set(encodedJobs, forKey: "cache_jobs")
        }
        UserDefaults.standard.set(store.selectedWorkspaceID, forKey: "cache_selected_workspace_id")
    }

    func loadCache() {
        guard let store = store else { return }
        
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "cache_workspaces"),
          let decoded = try? decoder.decode([AnigmaClientKit.WorkspaceSummary].self, from: data) {
          store.workspaceStore.workspaces = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "cache_artifacts"),
          let decoded = try? decoder.decode([AnigmaClientKit.ArtifactSummary].self, from: data) {
          store.artifacts = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "cache_jobs"),
          let decoded = try? decoder.decode([AnigmaClientKit.JobSummary].self, from: data) {
          store.jobs = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "pinned_actions"),
          let decoded = try? decoder.decode([PinnedAction].self, from: data) {
          store.pinnedActions = decoded
        } else {
          // Default pinned actions
          store.pinnedActions = [
            PinnedAction(id: "ocr", title: "OCR", systemImage: "doc.text.viewfinder", actionName: "ocr"),
            PinnedAction(id: "translate", title: "Translate", systemImage: "globe", actionName: "translate"),
            PinnedAction(id: "summarize", title: "Summarize", systemImage: "text.quote", actionName: "summarize")
          ]
        }
        if let id = UserDefaults.standard.string(forKey: "cache_selected_workspace_id") {
          store.sidebarSelection = .workspace(id: id)
        }
    }
    
    func savePinnedActions() {
        guard let store = store else { return }
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(store.pinnedActions)
            try saveToUserDefaults(data, forKey: "pinned_actions")
        } catch {
            print("❌ [AppStore] Failed to save pinned actions: \(error)")
            store.showError("Failed to save pinned actions. Some settings may not persist.")
        }
    }

    /// Safely save data to UserDefaults with verification
    func saveToUserDefaults(_ data: Data, forKey key: String) throws {
        UserDefaults.standard.set(data, forKey: key)
        
        // Verify the write succeeded
        guard UserDefaults.standard.data(forKey: key) != nil else {
          throw NSError(
            domain: "AnigmaApp",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "UserDefaults write verification failed for key '\(key)'"]
          )
        }
    }
}
