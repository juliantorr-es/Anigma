//
//  AppState.swift
//  AnigmaAppMac
//
//  Observable application state for the macOS app.
//

import SwiftUI
import Observation
import ObservatoriumModule

// MARK: - Navigation Types

enum SidebarDestination: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case documentLibrary = "Document Library"
    case observatorium = "Observatorium"
    case develop = "Develop"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .documentLibrary: return "doc.text.magnifyingglass"
        case .observatorium: return "chart.line.uptrend.xyaxis"
        case .develop: return "hammer"
        }
    }
}

// MARK: - Daemon Connection Status

enum DaemonConnectionStatus: String {
    case connected = "Connected"
    case connecting = "Connecting..."
    case disconnected = "Disconnected"
    case error = "Error"
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .connected: return "circle.fill"
        case .connecting: return "circle.dotted"
        case .disconnected: return "circle"
        case .error: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Governance Telemetry

struct GovernanceTelemetryEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let eventType: String
    let module: String
    let status: GovernanceStatus
    let message: String
}

enum GovernanceStatus: String {
    case passed = "Passed"
    case warning = "Warning"
    case failed = "Failed"
    
    var color: Color {
        switch self {
        case .passed: return .green
        case .warning: return .orange
        case .failed: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

// MARK: - Document Model

struct DocumentItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let fileType: String
    let size: Int64
    let lastModified: Date
    let tags: [String]
    let path: String
    
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

// MARK: - App State

@MainActor
@Observable
final class AppState {
    // Navigation
    var selectedDestination: SidebarDestination = .dashboard
    var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Daemon Connection
    var daemonStatus: DaemonConnectionStatus = .disconnected
    var daemonVersion: String = "Unknown"
    var lastHeartbeat: Date?
    
    // Observatorium State
    var observatoriumModule: ObservatoriumModule?
    
    // Governance Telemetry
    var telemetryEntries: [GovernanceTelemetryEntry] = []
    var telemetryFilter: GovernanceStatus?
    
    // Document Library
    var documents: [DocumentItem] = []
    var documentSearchQuery: String = ""
    var isLoadingDocuments: Bool = false

    // Develop
    var developState = DevelopState()
    
    // Filtered documents based on search
    var filteredDocuments: [DocumentItem] {
        if documentSearchQuery.isEmpty {
            return documents
        }
        return documents.filter { doc in
            doc.name.localizedCaseInsensitiveContains(documentSearchQuery) ||
            doc.tags.contains { $0.localizedCaseInsensitiveContains(documentSearchQuery) }
        }
    }
    
    // Filtered telemetry based on status filter
    var filteredTelemetry: [GovernanceTelemetryEntry] {
        if let filter = telemetryFilter {
            return telemetryEntries.filter { $0.status == filter }
        }
        return telemetryEntries
    }
    
    // Telemetry summary counts
    var passedCount: Int { telemetryEntries.filter { $0.status == .passed }.count }
    var warningCount: Int { telemetryEntries.filter { $0.status == .warning }.count }
    var failedCount: Int { telemetryEntries.filter { $0.status == .failed }.count }
    
    init() {
        loadMockData()
    }
    
    // MARK: - Actions
    
    func initializeObservatorium() async {
        observatoriumModule = ObservatoriumModule.shared
        await observatoriumModule?.start()
    }
    
    func connectToDaemon() async {
        daemonStatus = .connecting
        
        // Simulate connection delay
        try? await Task.sleep(for: .seconds(1))
        
        // Mock successful connection
        daemonStatus = .connected
        daemonVersion = "1.0.0-beta"
        lastHeartbeat = Date()
    }
    
    func disconnectFromDaemon() {
        daemonStatus = .disconnected
        lastHeartbeat = nil
    }
    
    func refreshDocuments() async {
        isLoadingDocuments = true
        
        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(500))
        
        loadMockDocuments()
        isLoadingDocuments = false
    }
    
    func refreshTelemetry() async {
        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(300))
        
        // Add a new mock entry
        let newEntry = GovernanceTelemetryEntry(
            timestamp: Date(),
            eventType: "Telemetry Refresh",
            module: "Core",
            status: .passed,
            message: "System health check completed"
        )
        telemetryEntries.insert(newEntry, at: 0)
    }
    
    // MARK: - Mock Data
    
    private func loadMockData() {
        loadMockTelemetry()
        loadMockDocuments()
    }
    
    private func loadMockTelemetry() {
        telemetryEntries = [
            GovernanceTelemetryEntry(
                timestamp: Date().addingTimeInterval(-60),
                eventType: "Swift6 Check",
                module: "AnigmaCore",
                status: .passed,
                message: "Strict concurrency compliance verified"
            ),
            GovernanceTelemetryEntry(
                timestamp: Date().addingTimeInterval(-120),
                eventType: "Type Authority",
                module: "ContractsCore",
                status: .passed,
                message: "No shadow authorities detected"
            ),
            GovernanceTelemetryEntry(
                timestamp: Date().addingTimeInterval(-180),
                eventType: "Dependency Check",
                module: "DataEngine",
                status: .warning,
                message: "Minor version drift detected in GRDB"
            ),
            GovernanceTelemetryEntry(
                timestamp: Date().addingTimeInterval(-240),
                eventType: "Escape Hatch Audit",
                module: "StorageCore",
                status: .passed,
                message: "All escape hatches have valid approval metadata"
            ),
            GovernanceTelemetryEntry(
                timestamp: Date().addingTimeInterval(-300),
                eventType: "Macro Expansion",
                module: "AnigmaPrimitives",
                status: .passed,
                message: "No forbidden constructs in expanded macros"
            ),
            GovernanceTelemetryEntry(
                timestamp: Date().addingTimeInterval(-600),
                eventType: "MainActor Drift",
                module: "AnigmaAppMac",
                status: .warning,
                message: "3 new MainActor annotations since last check"
            )
        ]
    }
    
    private func loadMockDocuments() {
        documents = [
            DocumentItem(
                name: "Architecture Overview",
                fileType: "md",
                size: 15_420,
                lastModified: Date().addingTimeInterval(-3600),
                tags: ["documentation", "architecture"],
                path: "/Docs/architecture/overview.md"
            ),
            DocumentItem(
                name: "Governance Policy",
                fileType: "md",
                size: 8_192,
                lastModified: Date().addingTimeInterval(-7200),
                tags: ["governance", "policy"],
                path: "/Docs/governance/policy.md"
            ),
            DocumentItem(
                name: "Type Authority Map",
                fileType: "json",
                size: 24_576,
                lastModified: Date().addingTimeInterval(-86400),
                tags: ["governance", "types"],
                path: "/Docs/governance/type-authority-map.json"
            ),
            DocumentItem(
                name: "Package Configuration",
                fileType: "swift",
                size: 69_187,
                lastModified: Date().addingTimeInterval(-1800),
                tags: ["build", "configuration"],
                path: "/Package.swift"
            ),
            DocumentItem(
                name: "README",
                fileType: "md",
                size: 2_884,
                lastModified: Date().addingTimeInterval(-172800),
                tags: ["documentation"],
                path: "/README.md"
            ),
            DocumentItem(
                name: "Design System Spec",
                fileType: "pdf",
                size: 1_048_576,
                lastModified: Date().addingTimeInterval(-259200),
                tags: ["design", "ui"],
                path: "/Docs/design/bauhaus-spec.pdf"
            ),
            DocumentItem(
                name: "API Reference",
                fileType: "html",
                size: 524_288,
                lastModified: Date().addingTimeInterval(-432000),
                tags: ["documentation", "api"],
                path: "/Docs/api/reference.html"
            ),
            DocumentItem(
                name: "Migration Guide",
                fileType: "md",
                size: 12_288,
                lastModified: Date().addingTimeInterval(-604800),
                tags: ["documentation", "migration"],
                path: "/Docs/guides/migration.md"
            )
        ]
    }
}
