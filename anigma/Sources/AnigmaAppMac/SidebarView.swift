//
//  SidebarView.swift
//  AnigmaAppMac
//
//  Sidebar with workspace list and navigation.
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

        List(selection: $bindableStore.sidebarSelection) {
            Section("Workspaces") {
                ForEach(store.workspaces) { workspace in
                    Label {
                        Text(workspace.name)
                    } icon: {
                        Image(systemName: "folder")
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Workspace: \(workspace.name)")
                    .accessibilityHint("Double tap to open workspace")
                    .tag(AppStore.SidebarItem.workspace(id: workspace.id))
                    .onAppear {
                        if workspace.id == store.workspaces.last?.id && store.hasMoreWorkspaces {
                            Task { await store.loadMoreWorkspaces() }
                        }
                    }
                    .contextMenu {
                        Button("Rename...") {
                            Task {
                                await store.updateWorkspace(
                                    id: workspace.id, name: "\(workspace.name) (Renamed)")
                            }
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            Task {
                                await store.deleteWorkspace(id: workspace.id)
                            }
                        }
                    }
                }
            }

            Section("Governance") {
                Label("Action Catalog", systemImage: "shield.checkerboard")
                    .tag(AppStore.SidebarItem.actionCatalog)

                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Governed Mode Active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Governed Mode Active")
                .accessibilityAddTraits(.isStaticText)
                .padding(.leading, 4)
            }

            Section("System") {
                Label("Settings", systemImage: "gear")
                    .tag(AppStore.SidebarItem.settings)
            }
        }
        .navigationTitle("Anigma")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await store.createWorkspace() } }) {
                    Label("New Workspace", systemImage: "plus")
                }
                .accessibilityLabel("Create New Workspace")
            }
        }
        .onChange(of: store.sidebarSelection) { _, newValue in
            if case .workspace(let id) = newValue {
                Task {
                    await store.selectWorkspace(id)
                }
            }
        }
    }
}
