import DataUI
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
                        case .browse: store.userSurface = .developBrowse
                        case .github: store.userSurface = .developGithub
                        }
                    }
                )) {
                    ForEach(DevelopNavMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(Bauhaus.Grid.unit)
                .accessibilityLabel("Navigator Mode")
                .accessibilityHint("Switches between file browser, search, changes, and runs")
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
                DevelopSearchView(workspace: workspace)
            case .changes:
                ChangeList(workspace: workspace)
            case .runs:
                RunHistory(workspace: workspace)
            case .review:
                ReviewQueueView(workspace: workspace)
            case .tasks:
                TaskBacklogView()
            case .agents:
                AgentManagement()
            case .browse:
                DevelopBrowseView()
            case .github:
                DevelopGithubView(workspace: workspace)
            }
        }
        .background(Bauhaus.Color.surface)
    }
}

// MARK: - Integrated Browser (HuggingFace Integration)

struct DevelopBrowseView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: String?
    guard let currentURL = URL(string: "https://huggingface.co") else {
        fatalError("Failed to unwrap currentURL")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(currentURL.host ?? currentURL.absoluteString)
                    .font(Bauhaus.Font.header)
                Spacer()
                if currentURL.host?.contains("huggingface.co") ?? false {
                    Button(action: { // Primary ButtonStyle
                        Task {
                            let jobId = try? await store.aiConsoleClient.installModel(url: currentURL)
                            if jobId != nil {
                                // showToast handled by installModel? No, let's do it here
                                store.activeToasts.append(AnigmaToast(id: UUID(), title: "Model Download Started", subtitle: currentURL.lastPathComponent, icon: "arrow.down.circle", actionLabel: nil))
                            }
                        }
                    }) {
                        Label("Import to Anigma", systemImage: "square.and.arrow.down.fill")
                    }
                    .primaryButtonStyle()
                    .accessibilityLabel("Import model to Anigma")
                    .accessibilityHint("Downloads and installs this model from HuggingFace")
                }
            }
            .padding(Bauhaus.Grid.unit)
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            BrowserLens(
                selection: $selection,
                initialURL: currentURL,
                onNavigate: { url in
                    currentURL = url
                }
            ) { _, _, _ in
                // Standard capture handling
            }
        }
    }
}

// MARK: - GitHub Integration

struct DevelopGithubView: View {
    let workspace: RepoWorkspace
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cable.connector.horizontal").resizable().frame(width: Bauhaus.Grid.x2, height: Bauhaus.Grid.x2)
                Text(workspace.rootURL.lastPathComponent).font(Bauhaus.Font.header)
                Spacer()
                Image(systemName: "safari").foregroundStyle(Bauhaus.Color.textSecondary)
            }
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            List {
                Section("Pull Requests") {
                    GithubItemRow(title: "Feat: Add support for recursive indexing", number: 421, author: "antigravity-bot", status: "Review Required", icon: "arrow.triangle.pull")
                    GithubItemRow(title: "Fix: Memory leak in worker pool", number: 419, author: "dev-alpha", status: "Approved", icon: "checkmark.circle.fill")
                }

                Section("Issues") {
                    GithubItemRow(title: "CLI: --dry-run fails on macOS 15", number: 388, author: "user-beta", status: "Bug", icon: "exclamationmark.circle")
                    GithubItemRow(title: "Docs: Clarify governance model", number: 385, author: "doc-master", status: "Documentation", icon: "doc.text")
                }
            }
            .listStyle(.inset)
        }
        .background(Bauhaus.Color.background)
    }
}

private struct GithubItemRow: View {
    let title: String
    let number: Int
    let author: String
    let status: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(Bauhaus.Font.callout)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Bauhaus.Font.bodyBold)
                HStack {
                    Text("#\(number)").foregroundStyle(Bauhaus.Color.textSecondary)
                    Text("by \(author)").foregroundStyle(Bauhaus.Color.textTertiary)
                    Spacer()
                    Text(status)
                        .font(Bauhaus.Font.microBold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Bauhaus.Color.accent.opacity(0.1))
                        .foregroundStyle(Bauhaus.Color.accent)
                        .cornerRadius(2)
                }
                .font(Bauhaus.Font.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        if icon.contains("checkmark") { return Bauhaus.Color.trusted }
        if icon.contains("exclamation") { return Bauhaus.Color.error }
        if icon.contains("pull") { return Bauhaus.Color.accent }
        return Bauhaus.Color.textSecondary
    }
}

// MARK: - Agent Management

struct AgentManagement: View {
    @State private var isCreatingProfile = false
    @State private var selectedTab: AgentTab = .orchestrator
    @Environment(AppStore.self) private var store

    enum AgentTab: String, CaseIterable {
        case orchestrator = "Orchestrator"
        case profiles = "Profiles"
        case providers = "Providers"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            HStack(spacing: 0) {
                ForEach(AgentTab.allCases, id: \.self) { tab in
                    Button { selectedTab = tab } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: tabIcon(tab))
                                Text(tab.rawValue)
                            }
                            .font(Bauhaus.Font.caption)
                            .fontWeight(.semibold)

                            Rectangle()
                                .fill(selectedTab == tab ? Bauhaus.Color.accent : Color.clear)
                                .frame(height: 2) // OK: Bauhaus line
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .background(Bauhaus.Color.surface)

            Divider()

            // Content
            switch selectedTab {
            case .orchestrator:
                OrchestratorView()

            case .profiles:
                profilesView

            case .providers:
                providersView
            }
        }
    }

    private func tabIcon(_ tab: AgentTab) -> String {
        switch tab {
        case .orchestrator: return "brain.head.profile"
        case .profiles: return "person.badge.shield.checkmark"
        case .providers: return "wrench.and.screwdriver"
        }
    }

    private var profilesView: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.agentProfiles) { profile in
                    HStack {
                        Image(systemName: "person.badge.shield.check.fill")
                            .foregroundStyle(Bauhaus.Color.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name).font(Bauhaus.Font.body)
                            if let model = profile.model {
                                Text(model).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                            }
                        }
                        Spacer()
                        Text(profile.networkStance.rawValue)
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Bauhaus.Color.surface)
                            .cornerRadius(4)
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            Button(action: { isCreatingProfile = true }) { // plain ButtonStyle
                Label("New Agent Profile", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .padding(Bauhaus.Grid.x2)
        }
        .sheet(isPresented: $isCreatingProfile) {
            AgentProfileCreator(isPresented: $isCreatingProfile)
        }
    }

    private var providersView: some View {
        List {
            ForEach(store.agentProviders) { provider in
                AgentProviderRow(provider: provider)
            }
        }
        .listStyle(.inset)
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
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(Bauhaus.Color.trusted)
                }
            }

            Text(provider.binaryPath)
                .font(Bauhaus.Font.monoMicro)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            if !provider.isEnabled {
                Button("Enable & Trust") { // link ButtonStyle
                    Task { await store.enableAgentProvider(provider.id) }
                }
                .buttonStyle(.link)
                .font(Bauhaus.Font.caption)
                .accessibilityLabel("Enable and trust \(provider.displayName)")
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
                                .frame(height: 2) // OK: Bauhaus line
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .accessibilityLabel("\(tab.rawValue) tab")
                    .accessibilityAddTraits(store.developWorkbenchTab == tab ? [.isSelected] : [])
                }

                Spacer()

                // Brain Chip
                Button {
                    store.isAIConsolePresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                        Text("Local: Gemini")
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
                .accessibilityLabel("Open AI Console")
                .accessibilityHint("Manage local AI models and settings")
            }
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            // Content
            ZStack {
                switch store.developWorkbenchTab {
                case .editor:
                    FileViewer(url: store.selectedFileURL)
                case .review:
                    PatchReviewLayout(workspace: workspace)
                case .logs:
                    RunLogsView(workspace: workspace)
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
                        Button {
                            if !url.hasDirectoryPath {
                                store.selectedFileURL = url
                            }
                        } label: {
                            Label(url.lastPathComponent, systemImage: url.hasDirectoryPath ? "folder.fill" : "doc.text")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .background(store.selectedFileURL == url ? Bauhaus.Color.accent.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                        .accessibilityLabel(url.hasDirectoryPath ? "Folder: \(url.lastPathComponent)" : "File: \(url.lastPathComponent)")
                        .accessibilityAddTraits(store.selectedFileURL == url ? [.isSelected] : [])
                    }
                } else {
                    ContentUnavailableView {
                        Label("Access Required", systemImage: "lock.fill")
                    } description: {
                        Text("Grant access to view files in this sandbox.")
                    } actions: {
                        Button("Grant Access") { // default ButtonStyle
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
                        .accessibilityLabel("Grant folder access")
                        .accessibilityHint("Opens file picker to grant access to this workspace")
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
                .primaryButtonStyle()
                .accessibilityLabel("Start agent refactor")
                .accessibilityHint("Opens preflight gate to configure and run agent refactoring")

                Button {
                    Task { await store.runCheckProfile(name: "Linting") }
                } label: {
                    Label("Run Linter", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Run linter")
                .accessibilityHint("Executes linting check on current workspace")
            }
            .padding(Bauhaus.Grid.unit)
        }
        .sheet(isPresented: $showingPreflight) {
            if let profile = store.agentProfiles.first {
                PreflightGate(
                    workspace: workspace,
                    profile: profile,
                    command: preflightCommand(for: profile, workspace: workspace)
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

    private func preflightCommand(for profile: AgentProfile, workspace: RepoWorkspace) -> String {
        let providerPath = profile.binaryPath
            ?? store.agentProviders.first { $0.id == profile.providerId }?.binaryPath
        let binary = providerPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? profile.providerId
        let instruction = "Refactor code"
        let workdir = workspace.sandboxURL?.path ?? workspace.rootURL.path
        return "ANIGMA_WORKSPACE=\"\(workdir)\" \(binary) \"\(instruction)\""
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
            .accessibilityLabel("View changeset: \(changeSet.title)")
            .accessibilityHint("Opens review tab to examine this changeset")
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
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Bauhaus.Color.trusted)
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
            }
            .primaryButtonStyle()
            .padding(Bauhaus.Grid.unit)
            .accessibilityLabel("Run test suite")
            .accessibilityHint("Executes all unit tests for this workspace")
        }
    }
}

private struct ReviewQueueView: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace

    private var pendingChanges: [ChangeSet] {
        store.changeSets.filter {
            $0.workspaceId == workspace.id && ($0.status == .proposed || $0.status == .applying)
        }
    }

    var body: some View {
        if pendingChanges.isEmpty {
            ContentUnavailableView {
                Label("No Reviews", systemImage: "checkmark.seal")
            } description: {
                Text("Proposed changes will appear here for approval.")
            }
        } else {
            List(pendingChanges) { changeSet in
                Button {
                    store.selectedChangeSetID = changeSet.id
                    store.developWorkbenchTab = .review
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(changeSet.title).font(Bauhaus.Font.body).fontWeight(.medium)
                        HStack {
                            StatusBadge(status: changeSet.status.rawValue)
                            Spacer()
                            Text(changeSet.createdAt, style: .time)
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(Bauhaus.Color.textTertiary)
                        }
                    }
                    .padding(Bauhaus.Grid.unit)
                    .background(store.selectedChangeSetID == changeSet.id ? Bauhaus.Color.accent.opacity(0.1) : Color.clear)
                    .cornerRadius(Bauhaus.Grid.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)
        }
    }
}

private struct TaskBacklogView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.workItems.isEmpty {
            ContentUnavailableView {
                Label("No Tasks Yet", systemImage: "tray")
            } description: {
                Text("Create or import work items to populate the backlog.")
            }
        } else {
            List(store.workItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(Bauhaus.Font.body).fontWeight(.medium)
                    HStack {
                        StatusBadge(status: item.status)
                        if let outcome = item.outcome {
                            Text(outcome)
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
        }
    }
}

private struct FileViewer: View {
    let url: URL?
    @State private var content: String = ""
    @State private var isLoading = false

    var body: some View {
        Group {
            if let url = url {
                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "doc.text").foregroundStyle(.secondary)
                                Text(url.lastPathComponent).font(Bauhaus.Font.monoBold)
                                Spacer()
                                Text("\(content.count) bytes").font(Bauhaus.Font.caption).foregroundStyle(.tertiary)
                            }
                            .padding(Bauhaus.Grid.unit)
                            .background(Bauhaus.Color.surface)

                            Divider()

                            Text(content)
                                .font(Bauhaus.Font.mono)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    .background(Bauhaus.Color.background)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "pencil.and.outline")
                        .font(Bauhaus.Font.displayXL)
                        .foregroundStyle(Bauhaus.Color.borderStrong)
                    Text("Select a file to inspect").font(Bauhaus.Font.body).foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }
        }
        .task(id: url) {
            await loadContent()
        }
    }

    private func loadContent() async {
        guard let url = url else { return }
        isLoading = true

        // Simple file load
        if let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            self.content = text
        } else {
            self.content = "Unable to load file content or file is binary."
        }

        isLoading = false
    }
}

private struct PatchReviewLayout: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace
    private var currentChangeSet: ChangeSet? {
        if let id = store.selectedChangeSetID, let cs = store.changeSets.first(where: { $0.id == id }) {
            return cs
        }
        return store.changeSets.first { $0.workspaceId == workspace.id && ($0.status == .proposed || $0.status == .applying) }
    }

    var body: some View {
        if let first = currentChangeSet {
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
                        } else if first.status == .proposed {
                            HStack {
                                Button("Reject") { // ButtonStyle
                                    Task { await store.rejectChangeSet(first.id) }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Bauhaus.Color.error)
                                .accessibilityLabel("Reject changes")
                                .accessibilityHint("Rejects the proposed changes")

                                Button("Apply Change") { // Primary ButtonStyle
                                    Task { await store.applyChangeSet(first.id) }
                                }
                                .primaryButtonStyle()
                                .accessibilityLabel("Apply changes")
                                .accessibilityHint("Applies the proposed patches")
                            }
                        } else {
                            StatusBadge(status: first.status.rawValue)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("PROVENANCE").font(Bauhaus.Font.caption).fontWeight(.bold).foregroundStyle(Bauhaus.Color.textTertiary)
                        HStack(spacing: Bauhaus.Grid.x3) {
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
                                Text(patch.filePath).font(Bauhaus.Font.mono)
                                Text(patch.diff)
                                    .font(Bauhaus.Font.mono)
                                    .padding(Bauhaus.Grid.unit)
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
                    .font(Bauhaus.Font.displayXL)
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

private struct RunLogsView: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace
    var body: some View {
        ConsoleView(logs: store.consoleLogs)
    }
}

// MARK: - Agent Profile Creator

struct AgentProfileCreator: View {
    @Environment(AppStore.self) private var store
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var selectedProviderId: String = ""
    @State private var selectedModel: String = ""
    @State private var stance: NetworkPolicy.Stance = .offline

    var body: some View {
        VStack(spacing: 20) {
            Text("New Agent Profile").font(Bauhaus.Font.header)

            Form {
                TextField("Profile Name", text: $name)
                    .accessibilityLabel("Profile Name")

                Picker("Provider", selection: $selectedProviderId) {
                    Text("Select Provider").tag("")
                    ForEach(store.agentProviders) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .accessibilityLabel("Provider")

                TextField("Model (e.g. gemini-2.0-flash)", text: $selectedModel)
                    .accessibilityLabel("Model")

                Picker("Network Stance", selection: $stance) {
                    ForEach([NetworkPolicy.Stance.offline, .localOnly, .open], id: \.self) { stance in
                        Text(stance.rawValue).tag(stance)
                    }
                }
                .accessibilityLabel("Network Stance")
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { isPresented = false } // plain ButtonStyle
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel")
                Spacer()
                Button("Create Profile") { // primaryButtonStyle
                    let provider = store.agentProviders.first { $0.id == selectedProviderId }
                    let profile = AgentProfile(
                        id: UUID(),
                        name: name,
                        providerId: selectedProviderId,
                        model: selectedModel.isEmpty ? nil : selectedModel,
                        networkStance: stance,
                        defaultCheckProfile: nil,
                        binaryPath: provider?.binaryPath
                    )
                    store.agentProfiles.append(profile)
                    isPresented = false
                }
                .primaryButtonStyle()
                .disabled(name.isEmpty || selectedProviderId.isEmpty)
                .accessibilityLabel("Create Profile")
                .accessibilityHint("Creates a new agent profile with the specified settings")
            }
        }
        .padding()
        .frame(width: 400, height: 400) // OK: Bauhaus form
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
                .font(Bauhaus.Font.small)
                .foregroundStyle(isAccent ? Bauhaus.Color.accent : Bauhaus.Color.textSecondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(label.uppercased())
                    .font(Bauhaus.Font.nanoBold)
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
            .font(Bauhaus.Font.nanoBold)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(2)
    }

    private var color: Color {
        switch status.lowercased() {
        case "proposed": return Bauhaus.Color.warning
        case "applied": return Bauhaus.Color.trusted
        case "rejected": return Bauhaus.Color.error
        default: return Bauhaus.Color.textSecondary
        }
    }
}
