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
        @Bindable var state = appState
        
        NavigationSplitView(columnVisibility: $state.columnVisibility) {
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
        @Bindable var state = appState
        
        List(selection: $state.selectedDestination) {
            Section("Navigation") {
                ForEach(SidebarDestination.allCases) { destination in
                    Label(destination.rawValue, systemImage: destination.icon)
                        .tag(destination)
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
        switch appState.selectedDestination {
        case .dashboard:
            DashboardView()
        case .documentLibrary:
            DocumentLibraryView()
        case .observatorium:
            ObservatoriumDashboardView()
        case .develop:
            DevelopView()
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

#Preview {
    MainContentView()
        .environment(AppState())
        .frame(width: 1000, height: 700)
}
