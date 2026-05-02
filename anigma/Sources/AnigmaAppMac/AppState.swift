import SwiftUI
import Observation
import AuthenticationServices
import AnigmaCore
import AnigmaPrimitives
import HarmoniaV2Contracts
import AnigmaClientKit

struct DocumentItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let fileType: String
    let size: Int64
    let lastModified: Date
    let tags: [String]
    let path: String?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileIcon: String {
        switch fileType.lowercased() {
        case "pdf": return "doc.fill"
        case "txt", "md": return "doc.text.fill"
        case "swift": return "swift"
        case "json": return "curlybraces"
        case "html": return "globe"
        default: return "doc"
        }
    }
}

// Governance status for telemetry filtering
public enum GovernanceStatus: String, CaseIterable, Sendable, Hashable {
    case passed = "Passed"
    case warning = "Warning"
    case failed = "Failed"
    
    var icon: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

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
    
    // Telemetry Filtering
    var telemetryFilter: GovernanceStatus? = nil
    
    // Document Library State
    var documents: [DocumentItem] = []
    var documentSearchQuery: String = ""
    var isLoadingDocuments: Bool = false
    
    var filteredDocuments: [DocumentItem] {
        if documentSearchQuery.isEmpty {
            return documents
        }
        return documents.filter { doc in
            doc.name.localizedCaseInsensitiveContains(documentSearchQuery) ||
            (doc.path?.localizedCaseInsensitiveContains(documentSearchQuery) ?? false)
        }
    }
    
    // MARK: - Daemon & Telemetry Status
    enum DaemonStatus {
        case connected, disconnected, connecting
        
        var rawValue: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting"
            }
        }
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .red
            case .connecting: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "xmark.circle.fill"
            case .connecting: return "ellipsis.circle.fill"
            }
        }
    }
    
    var daemonStatus: DaemonStatus = .disconnected
    var daemonVersion: String = "unknown"
    var telemetryEntries: [String] = []
    var lastHeartbeat: Date?
    var passedCount: Int = 0
    var failedCount: Int = 0
    var warningCount: Int = 0
    
    var filteredTelemetry: [String] {
        telemetryEntries
    }

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
    
    // MARK: - Daemon & Telemetry Methods
    func connectToDaemon() async {
        daemonStatus = .connecting
        // Stub implementation
        daemonStatus = .connected
        lastHeartbeat = Date()
    }
    
    func disconnectFromDaemon() async {
        daemonStatus = .disconnected
        lastHeartbeat = nil
    }
    
    func refreshTelemetry() async {
        // Stub implementation
        lastHeartbeat = Date()
    }
    
    func refreshDocuments() async {
        // Stub implementation
    }
}
