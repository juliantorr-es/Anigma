//
//  ProjectsView.swift
//  AnigmaAppMac
//
//  Projects - active workspaces.
//  Bauhaus identity: flatter planes, sharper edges.
//

import SwiftUI
import AnigmaClientKit

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
                .font(.system(size: 56))
                .foregroundStyle(Bauhaus.Color.accent.opacity(0.6))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
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
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            HStack {
                Text(workspace.name)
                    .font(Bauhaus.Font.title)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Open Workspace") {
                    Task { await store.selectWorkspace(workspace.id) }
                }
                .bauhausAccentButton()
                .accessibilityHint("Activates this workspace.")
            }
            .bauhausSection()

            Text("This project contains evidence-backed artifacts and governed flows.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Spacer()
        }
        .padding(Bauhaus.Grid.x4)
    }
}

#Preview {
    ProjectsView()
        .frame(width: 800, height: 500)
}
