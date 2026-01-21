//
//  StandardUserShell.swift
//  AnigmaAppMac
//
//  The "Studio Workbench" for Standard Users.
//  Focus: Library, Job Builder, Outputs.
//  Structure: Governance Strip (Top) + Sidebar (Left) + Content (Right).
//

import SwiftUI

struct StandardUserShell: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            // 1. Permanent Governance Strip (The Contract)
            GovernanceStrip()

            // 2. Main Content Area
            NavigationSplitView {
                SidebarView()
            } content: {
                switch store.sidebarSelection {
                case .workspace:
                    WorkspaceView()
                case .actionCatalog:
                    ActionCatalogView()
                case .settings:
                    SettingsView()
                case nil:
                    ContentUnavailableView("Select an item", systemImage: "sidebar.left")
                }
            } detail: {
                InspectorView(selection: store.inspectorSelection)
            }
        }
    }
}
