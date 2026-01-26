import SwiftUI
import Observation
import AuthenticationServices

@MainActor
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

    // Global Context State (The Spine)
    var currentContext: AnigmaContext? {
        didSet {
            saveState()
        }
    }

    // The Ledger (Evidence & Activity)
    var ledger: [AnigmaEvidence] = []

    // Intake Queue
    var intakeQueue: [IntakeItem] = []

    // System Status
    var isIndexing: Bool = false
    var isConnectedToNetwork: Bool = false

    // Singleton for easy access if needed, but prefer injection
    static let shared = AppState()

    private let stateKey = "AnigmaState_v1"

    init() {
        restoreState()
    }

    func switchToMode(_ mode: AppMode) {
        self.currentMode = mode
        // normalizeSelectionForMode is called by didSet
    }

    private func saveState() {
        if let context = currentContext,
           let data = try? JSONEncoder().encode(context) {
            UserDefaults.standard.set(data, forKey: "currentContext")
        }
    }

    private func restoreState() {
        if let data = UserDefaults.standard.data(forKey: "currentContext"),
           let context = try? JSONDecoder().decode(AnigmaContext.self, from: data) {
            self.currentContext = context
        }
    }

    private func normalizeSelectionForMode() {
        switch currentMode {
        case .life:
            if ![.compass, .inbox, .atlas, .ask, .projects, .activity].contains(selectedSurface) {
                selectedSurface = .compass
            }
        case .work:
            if ![.projects, .inbox, .ask, .activity, .data, .documentLibrary].contains(selectedSurface) {
                selectedSurface = .projects
            }
        case .insight:
            if ![.atlas, .activity, .ask, .data, .observatorium].contains(selectedSurface) {
                selectedSurface = .atlas
            }
        case .build:
            if ![.studio, .activity, .inbox, .atlas, .actionCatalog].contains(selectedSurface) {
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
