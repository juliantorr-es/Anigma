//
//  MainContentView.swift
//  AnigmaAppMac
//
//  Main content view with NavigationSplitView sidebar.
//

import SwiftUI

struct MainContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationSplitView {
            SidebarNavigationView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            DetailContentView()
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                DaemonStatusBadge()
            }
        }
        .task {
            await appState.connectToDaemon()
        }
    }
}

// MARK: - Sidebar Navigation

struct SidebarNavigationView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        List(selection: Binding(
            get: { appState.selectedSurface },
            set: { appState.selectedSurface = $0 }
        )) {
            Section("Navigation") {
                ForEach(UserSurface.allCases, id: \.self) { surface in
                    Label(surface.displayName, systemImage: surface.icon)
                        .tag(surface)
                }
            }
            
            Section("Quick Actions") {
                Button {
                    Task { await appState.refreshTelemetry() }
                } label: {
                    Label("Refresh Telemetry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                
                Button {
                    Task { await appState.refreshDocuments() }
                } label: {
                    Label("Sync Documents", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
            }
            
            Section("Status") {
                HStack {
                    Circle()
                        .fill(appState.daemonStatus.color)
                        .frame(width: 8, height: 8)
                    Text("Daemon: \(appState.daemonStatus.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let heartbeat = appState.lastHeartbeat {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                        Text("Last: \(heartbeat.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Anigma")
    }
}

// MARK: - Detail Content Router

struct DetailContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        switch appState.selectedSurface {
        case .compass:
            DashboardView()
        case .inbox, .documentLibrary:
            DocumentLibraryView()
        case .atlas:
            AtlasView()
        case .ask:
            AskView()
        case .projects, .data:
            ProjectsView()
        case .studio:
            StudioView()
        case .export:
            UniversalExportView(engine: nil)
        case .aiConsole:
            Text("AI Console")
        case .develop, .developFiles, .developSearch, .developChanges, .developRuns, .developReview, .developTasks, .developAgents, .developBrowse, .developGithub:
            DevelopView()
        case .activity:
            ActivityView()
        case .actionCatalog:
            ActionCatalogView()
        case .observatorium:
            ObservatoriumDashboardView()
        case .vault:
            Text("Vault")
        case .workerQueue:
            WorkerQueueView()
        case .adminConsole:
            AdminConsoleView()
        case .adminPolicies:
            AdminPoliciesView()
        case .adminAudit:
            AdminAuditView()
        case .developerConsole:
            Text("Developer Console")
        case .developerReceipts:
            DeveloperReceiptsView()
        case .developerMetrics:
            DeveloperMetricsView()
        case .settings:
            SettingsView()
        case .privacyConsole:
            PrivacyConsoleView()
        }
    }
}

// MARK: - Daemon Status Badge

struct DaemonStatusBadge: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: appState.daemonStatus.icon)
                .foregroundStyle(appState.daemonStatus.color)
                .font(.system(size: 10))
            
            if appState.daemonStatus == .connected {
                Text("v\(appState.daemonVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(appState.daemonStatus.color.opacity(0.1))
        .clipShape(Capsule())
        .help("Daemon Status: \(appState.daemonStatus.rawValue)")
    }
}
