//
//  ProjectsView.swift
//  AnigmaAppMac
//
//  Projects - active workspaces.
//  Bauhaus identity: flatter planes, sharper edges.
//

import SwiftUI
import AnigmaClientKit
import AnigmaWork

struct ProjectsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if store.workspaces.isEmpty {
                ProjectsEmptyState()
            } else {
                ProjectsContent()
            }
        }
        .navigationTitle("Projects")
        .background(Bauhaus.Color.background)
    }
}

// MARK: - Empty State

struct ProjectsEmptyState: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x4) {
            Spacer()

            Image(systemName: "folder.fill.badge.plus")
                .font(Bauhaus.Font.displayXXL)
                .foregroundStyle(Bauhaus.Color.accent.opacity(0.6))
                .accessibilityHidden(true)

            VStack(spacing: Bauhaus.Grid.unit) {
                Text("No projects yet")
                    .font(Bauhaus.Font.header)
                    .accessibilityAddTraits(.isHeader)
                Text("Use the command bar (⌘K) to start a new project.")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No projects yet. Use the command bar, Command K, to start a new project.")

            Spacer()
        }
    }
}

// MARK: - Content

struct ProjectsContent: View {
    @Environment(AppStore.self) private var store
    @State private var selection: WorkspaceID?

    var body: some View {
        NavigationSplitView {
            List(store.workspaces, selection: $selection) { workspace in
                Label(workspace.name, systemImage: "folder.fill")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(selection == workspace.id ? .white : Bauhaus.Color.textPrimary)
                    .tag(workspace.id)
            }
            .listStyle(.sidebar)
            .navigationTitle("Projects")
        } detail: {
            if let id = selection,
               let workspace = store.workspaces.first(where: { $0.id == id }) {
                ProjectDetail(workspace: workspace)
            } else {
                ContentUnavailableView("Select a project", systemImage: "folder")
            }
        }
    }
}

struct ProjectDetail: View {
    let workspace: WorkspaceSummary
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name)
                        .font(Bauhaus.Font.title)
                        .accessibilityAddTraits(.isHeader)
                    Text("ID: \(workspace.id)")
                        .font(Bauhaus.Font.monoSmall)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
                Spacer()
                Button("Activate Workspace") { // Primary ButtonStyle
                    let project = WorkbenchProject(
                        id: workspace.id,
                        name: workspace.name,
                        rootPath: workspace.description ?? workspace.id
                    )
                    store.currentProject = project
                    Task { await store.selectWorkspace(workspace.id) }
                }
                .primaryButtonStyle()
                .accessibilityLabel("Activate Workspace")
                .accessibilityHint("Activates this workspace.")
            }
            .padding(Bauhaus.Grid.x3)
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Governance")
                            .font(Bauhaus.Font.subHeader)
                        Text("This project contains evidence-backed artifacts and governed flows. All actions are logged to the immutable ledger.")
                            .font(Bauhaus.Font.body)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                    }
                    .padding(Bauhaus.Grid.x3)
                    .background(Bauhaus.Color.surface)
                    .cornerRadius(Bauhaus.Grid.cornerRadius)
                    .overlay(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius).stroke(Bauhaus.Color.border, lineWidth: 1))
                }
                .padding(Bauhaus.Grid.x4)
            }
        }
    }
}

