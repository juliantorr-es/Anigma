//
//  DevelopView.swift
//  AnigmaAppMac
//
//  Develop Mode Workbench - Repo-aware workbench.
//  Bauhaus utility: split panes, trace-focused, governed.
//

import SwiftUI
import AnigmaClientKit

struct DevelopView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if let workspace = store.activeWorkspace {
            HSplitView {
                // Left: Navigation (Explorer/Symbols/Search)
                RepoNavigator(workspace: workspace)
                    .frame(minWidth: 240, maxWidth: 350)

                // Right: Workbench (Editor/Patch/Logs)
                RepoWorkbench(workspace: workspace)
                    .frame(minWidth: 500)
            }
        } else {
            DevelopEmptyState()
        }
    }
}

// MARK: - Repo Navigator

struct RepoNavigator: View {
    let workspace: RepoWorkspace
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            // Navigator Header (Breadcrumb style label for current mode)
            HStack {
                Picker("Mode", selection: Binding(
                    get: { store.developNavMode },
                    set: { newMode in
                        switch newMode {
                        case .files: store.userSurface = .developFiles
                        case .search: store.userSurface = .developSearch
                        case .changes: store.userSurface = .developChanges
                        case .runs: store.userSurface = .developRuns
                        case .review: store.userSurface = .developReview
                        case .tasks: store.userSurface = .developTasks
                        case .agents: store.userSurface = .developAgents
                        }
                    }
                )) {
                    ForEach(DevelopNavMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(Bauhaus.Grid.unit)
            .background(Bauhaus.Color.surface)
            .bauhausSection()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Navigator Mode: \(store.developNavMode.rawValue)")
            .accessibilityAddTraits(.isHeader)

            switch store.developNavMode {
            case .files:
                FileExplorer(workspace: workspace)
            case .search:
                Text("Search interface coming soon...").padding() // Placeholder for LSP search
            case .changes:
                ChangeList(workspace: workspace)
            case .runs:
                RunHistory(workspace: workspace)
            case .review:
                Text("Review queue central view").padding()
            case .tasks:
                Text("Developer task backlog").padding()
            case .agents:
                AgentManagement()
            }
        }
        .background(Bauhaus.Color.surface)
    }
}

// MARK: - Agent Management

struct AgentManagement: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Agent Providers") {
                    ForEach(store.agentProviders) { provider in
                        AgentProviderRow(provider: provider)
                    }
                }

                Section("Active Profiles") {
                    ForEach(store.agentProfiles) { profile in
                        HStack {
                            Image(systemName: "person.badge.shield.check.fill").foregroundStyle(Bauhaus.Color.accent)
                            Text(profile.name).font(Bauhaus.Font.body)
                            Spacer()
                            Text(profile.networkStance.rawValue).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .accessibilityLabel("Agent Providers List")

            Divider()

            Button("New Agent Profile") {
                // Profile creator logic
            }
            .buttonStyle(.plain)
            .padding(Bauhaus.Grid.unit)
            .accessibilityHint("Create a new agent profile")
        }
    }
}

private struct AgentProviderRow: View {
    @Environment(AppStore.self) private var store
    let provider: AgentProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(provider.displayName).font(Bauhaus.Font.body).fontWeight(.bold)
                Spacer()
                if provider.isEnabled {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                }
            }

            Text(provider.binaryPath).font(Bauhaus.Font.mono).font(.system(size: 9)).foregroundStyle(Bauhaus.Color.textTertiary)

            if !provider.isEnabled {
                Button("Enable & Trust") {
                    Task { await store.enableAgentProvider(provider.id) }
                }
                .buttonStyle(.link)
                .font(Bauhaus.Font.caption)
            } else if let trust = provider.trustRecord {
                HStack {
                    Text("Trusted: \(trust.binaryHash.prefix(8))...").font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Repo Workbench

struct RepoWorkbench: View {
    let workspace: RepoWorkspace
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            // Tabs
            HStack(spacing: 0) {
                ForEach(DevelopWorkbenchTab.allCases, id: \.self) { tab in
                    Button { store.developWorkbenchTab = tab } label: {
                        VStack(spacing: 4) {
                            Text(tab.rawValue.uppercased())
                                .font(Bauhaus.Font.caption)
                                .fontWeight(.bold)
                            Rectangle()
                                .fill(store.developWorkbenchTab == tab ? Bauhaus.Color.accent : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }

                Spacer()

                // Brain Chip
                Button {
                    store.isAIConsolePresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                        Text("Local Only") // Placeholder
                            .font(Bauhaus.Font.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Bauhaus.Color.surface)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Bauhaus.Color.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            // Content
            ZStack {
                switch store.developWorkbenchTab {
                case .editor:
                    CodeEditorPlaceholder(workspace: workspace)
                case .review:
                    PatchReviewLayout(workspace: workspace)
                case .logs:
                    RunLogsPlaceholder(workspace: workspace)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Bauhaus.Color.background)
    }
}

// MARK: - Subcomponents (Internal)

private struct FileExplorer: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace
    @State private var showingPreflight = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                if let url = workspace.sandboxURL ?? (try? workspace.rootURL.checkResourceIsReachable() ? workspace.rootURL : nil),
                   let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    ForEach(contents, id: \.self) { url in
                        Label(url.lastPathComponent, systemImage: url.hasDirectoryPath ? "folder.fill" : "doc.text")
                    }
                } else {
                    ContentUnavailableView {
                        Label("Access Required", systemImage: "lock.fill")
                    } description: {
                        Text("Grant access to view files in this sandbox.")
                    } actions: {
                        Button("Grant Access") {
                            // In a real app, this would use a security scoped bookmark.
                            // Here we re-prompt for the folder to regain session access.
                            let panel = NSOpenPanel()
                            panel.directoryURL = workspace.rootURL
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.prompt = "Grant Access"
                            panel.runModal()
                            // Trigger refresh by toggling state or relying on View update
                            showingPreflight.toggle()
                            showingPreflight.toggle()
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            VStack(spacing: 8) {
                Button {
                    showingPreflight = true
                } label: {
                    Label("Agent Refactor", systemImage: "brain.head.profile")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .bauhausAccentButton()

                Button {
                    Task { await store.runCheckProfile(name: "Linting") }
                } label: {
                    Label("Run Linter", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .padding(Bauhaus.Grid.unit)
        }
        .sheet(isPresented: $showingPreflight) {
            if let profile = store.agentProfiles.first {
                PreflightGate(
                    workspace: workspace,
                    profile: profile,
                    command: "gemini-cli refactor --focus Sources/AnigmaAppMac --depth structured"
                ) {
                    showingPreflight = false
                    Task {
                        await store.submitJob(action: "agent-refactor", parameters: ["profile": .string(profile.id.uuidString)])
                    }
                } onCancel: {
                    showingPreflight = false
                }
            }
        }
    }
}

private struct ChangeList: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace
    var body: some View {
        List(store.changeSets.filter { $0.workspaceId == workspace.id }) { changeSet in
            Button { store.developWorkbenchTab = .review } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(changeSet.title).font(Bauhaus.Font.body).fontWeight(.medium)
                    HStack {
                        StatusBadge(status: changeSet.status.rawValue)
                        Spacer()
                        Text(changeSet.createdAt, style: .time).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.sidebar)
    }
}

private struct RunHistory: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Active") {
                    ForEach(store.jobs.filter { $0.status.uppercased() == "RUNNING" }) { job in
                        HStack {
                            ProgressView().controlSize(.small)
                            Text(job.name).font(Bauhaus.Font.body)
                        }
                    }
                }
                Section("Completed") {
                    ForEach(store.jobs.filter { $0.status.uppercased() == "COMPLETED" }.prefix(5)) { job in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(job.name).font(Bauhaus.Font.body)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            Button {
                Task { await store.runCheckProfile(name: "Unit Tests") }
            } label: {
                Label("Run Test Suite", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .bauhausAccentButton()
            .padding(Bauhaus.Grid.unit)
        }
    }
}

private struct CodeEditorPlaceholder: View {
    let workspace: RepoWorkspace
    var body: some View {
        VStack {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundStyle(Bauhaus.Color.borderStrong)
            Text("Select a file to edit").font(Bauhaus.Font.body).foregroundStyle(Bauhaus.Color.textSecondary)
        }
    }
}

private struct PatchReviewLayout: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace
    var body: some View {
        if let first = store.changeSets.first(where: { $0.status == .proposed || $0.status == .applying }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(first.title).font(Bauhaus.Font.header)
                            Text(first.summary).font(Bauhaus.Font.body).foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                        Spacer()

                        if first.status == .applying {
                            ProgressView("Applying...").controlSize(.small)
                        } else {
                            HStack {
                                Button("Reject") {
                                    Task { await store.rejectChangeSet(first.id) }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)

                                Button("Apply Change") {
                                    Task { await store.applyChangeSet(first.id) }
                                }
                                .bauhausAccentButton()
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("PROVENANCE").font(Bauhaus.Font.caption).fontWeight(.bold).foregroundStyle(Bauhaus.Color.textTertiary)
                        HStack(spacing: 24) {
                            ProvenanceChip(icon: "brain", label: "Agent", value: first.generatedBy ?? "Unknown")
                            ProvenanceChip(icon: "exclamationmark.shield", label: "Risk", value: String(format: "%.1f", first.riskScore))
                            if let hash = first.receiptHash {
                                ProvenanceChip(icon: "checkmark.shield", label: "Receipt", value: hash, isAccent: true)
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("DIFF").font(Bauhaus.Font.caption).fontWeight(.bold).foregroundStyle(Bauhaus.Color.textTertiary)
                        ForEach(first.patches) { patch in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(patch.filePath).font(Bauhaus.Font.mono).font(.system(size: 11))
                                Text(patch.diff)
                                    .font(Bauhaus.Font.mono)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(Bauhaus.Grid.x4)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "gate.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Bauhaus.Color.borderStrong)
                Text("No pending changes")
                    .font(Bauhaus.Font.header)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
                Text("Proposed changes will appear here for approval.")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
    }
}

private struct RunLogsPlaceholder: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace
    var body: some View {
        ConsoleView(logs: store.consoleLogs)
    }
}

struct DevelopEmptyState: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Bauhaus.EmptyState(
            title: "No Repository Selected",
            message: "Open a folder to index, analyze, and propose patches.",
            buttonTitle: "Open Repository"
        )            { store.isRepoPickerPresented = true }
    }
}

// MARK: - Integration Helpers

private struct ProvenanceChip: View {
    let icon: String
    let label: String
    let value: String
    var isAccent: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(isAccent ? Bauhaus.Color.accent : Bauhaus.Color.textSecondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                Text(value)
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

private struct StatusBadge: View {
    let status: String
    var body: some View {
        Text(status.uppercased())
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(2)
    }

    private var color: Color {
        switch status.lowercased() {
        case "proposed": return .orange
        case "applied": return .green
        case "rejected": return .red
        default: return .secondary
        }
    }
}
