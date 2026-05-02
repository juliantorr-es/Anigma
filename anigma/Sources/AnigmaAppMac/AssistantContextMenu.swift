//
//  AssistantContextMenu.swift
//  AnigmaAppMac
//
//  Context menu for assistant-centric access to privileged surfaces.
//  Replaces direct navigation to maintain conversation flow.
//

import SwiftUI
import AnigmaClientKit

struct AssistantContextMenu: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Menu {
            // Tools Section
            Section("Tools") {
                if AccessGates.canAccessWorkerQueue(role: store.role) {
                    Button(action: { appState.selectedSurface = .workerQueue }) {
                        Label("Worker Queue", systemImage: "hammer.fill")
                    }
                }
                
                Button(action: { appState.selectedSurface = .actionCatalog }) {
                    Label("Action Catalog", systemImage: "tray.2.fill")
                }
            }
            
            // Admin Section (role-gated)
            if AccessGates.canAccessAdminConsole(role: store.role, adminSurfacesEnabled: store.adminSurfacesEnabled) {
                Section("Admin") {
                    Button(action: { appState.selectedSurface = .adminConsole }) {
                        Label("Doctrine", systemImage: "shield.checkered")
                    }
                    
                    Button(action: { appState.selectedSurface = .adminPolicies }) {
                        Label("Policies", systemImage: "doc.badge.gearshape")
                    }
                    
                    Button(action: { appState.selectedSurface = .adminAudit }) {
                        Label("Audit Log", systemImage: "list.bullet.clipboard")
                    }
                }
            }
            
            // Developer Section (role-gated)
            if AccessGates.canAccessDeveloperTools(role: store.role, developerToolsEnabled: store.developerToolsEnabled) {
                Section("Developer") {
                    Button(action: { appState.selectedSurface = .developerConsole }) {
                        Label("Traces", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    
                    Button(action: { appState.selectedSurface = .developerReceipts }) {
                        Label("Receipts", systemImage: "doc.text.below.ecg")
                    }
                    
                    Button(action: { appState.selectedSurface = .developerMetrics }) {
                        Label("Metrics", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
            }
            
            // Settings Section
            Section("Settings") {
                Button(action: { appState.selectedSurface = .settings }) {
                    Label("Preferences", systemImage: "gearshape.fill")
                }
                
                Button(action: { appState.selectedSurface = .privacyConsole }) {
                    Label("Privacy", systemImage: "hand.raised.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Bauhaus.Color.accent)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Assistant context menu")
    }
}

// MARK: - Preview
/*#Preview {
    AssistantContextMenu()
        .environment(AppStore.preview)
        .environment(AppState.preview)
}*/