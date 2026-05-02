import SwiftUI
import Observation
import AuthenticationServices

@Observable
final class AppState {
    // Navigation State
    var currentMode: AppMode = .life {
        didSet { normalizeSelectionForMode() }
    }
    var selectedContextId: String?
    var selectedSurface: UserSurface = .compass

    // Develop Mode specific navigation
    var developNavMode: DevelopNavMode = .files
    var developWorkbenchTab: DevelopWorkbenchTab = .editor

    // Global Status Rollups
    var runningJobsCount: Int = 0
    var blockedJobsCount: Int = 0
    var needsAttentionCount: Int = 0
    var newOutputCount: Int = 0

    // Job Stream
    struct JobEntry: Identifiable {
        let id: UUID
        let title: String
        let status: Bauhaus.StatusState
        let progress: Double?
        let source: String
        let receiptLink: String?
        let timestamp: Date
    }

    var jobStream: [JobEntry] = []

    // System Status
    var isIndexing: Bool = false
    var isConnectedToNetwork: Bool = false

    // Singleton for easy access if needed, but prefer injection
    static let shared = AppState()

    init() {}

    func switchToMode(_ mode: AppMode) {
        self.currentMode = mode
        // normalizeSelectionForMode is called by didSet
    }

    private func normalizeSelectionForMode() {
        switch currentMode {
        case .life:
            if ![.compass, .inbox, .atlas, .ask, .projects, .activity].contains(selectedSurface) {
                selectedSurface = .compass
            }
        case .work:
            if ![.projects, .inbox, .ask, .activity, .data].contains(selectedSurface) {
                selectedSurface = .projects
            }
        case .insight:
            if ![.atlas, .activity, .ask, .data].contains(selectedSurface) {
                selectedSurface = .atlas
            }
        case .build:
            if ![.studio, .activity, .inbox, .atlas].contains(selectedSurface) {
                selectedSurface = .studio
            }
        case .develop:
            let developSurfaces: Set<UserSurface> = [.develop, .developFiles, .developSearch, .developChanges, .developRuns, .developReview, .developTasks, .developAgents, .activity, .ask, .projects]
            if !developSurfaces.contains(selectedSurface) {
                selectedSurface = .develop
            }
        }
    }
}
