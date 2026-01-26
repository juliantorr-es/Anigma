//
//  MacShell.swift
//  AnigmaAppMac
//
//  macOS shell with Bauhaus geometry and explicit mode split.
//  Life mode for compass/inbox/tasks, Build mode for studio/tools.
//

import ExportUI
import AnigmaAIConsole
import AnigmaSidecar
import SwiftUI

import UniformTypeIdentifiers
import QuickLook

struct MacShell: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState
    @State private var isInspectorPresented = false
    @State private var quickLookURL: URL?

    var body: some View {
        @Bindable var bindableStore = store
        @Bindable var bindableAppState = appState

        NavigationSplitView {
            Sidebar()
                .frame(minWidth: Bauhaus.Grid.sidebarWidth)
        } detail: {
            VStack(spacing: 0) {
                // Daemon connection warning banner
                if store.daemonBridge == nil {
                    DaemonWarningBanner()
                }

                // Global OmniBar - persistent command palette
                OmniBar()
                    .padding(.horizontal, Bauhaus.Grid.x2)
                    .padding(.top, Bauhaus.Grid.x2)
                    .padding(.bottom, Bauhaus.Grid.unit)

                // Content surface
                ContentSurface()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Bauhaus.Color.background)
            .onChange(of: store.inspectorSelection) { _, newValue in
                isInspectorPresented = (newValue != nil)
            }
        }
        .inspector(isPresented: $isInspectorPresented) {
            InspectorPane()
                .frame(minWidth: Bauhaus.Grid.inspectorWidth, maxWidth: 400)
        }
        .sheet(isPresented: $bindableStore.isSourceConnectionPresented) {
            SourceConnectionView()
        }
        .sheet(isPresented: $bindableStore.isExportPresented) {
            UniversalExportView(engine: store.exportEngine)
                .frame(width: 600, height: 500)
        }
        .sheet(isPresented: $bindableStore.isJobCenterPresented) {
            JobCenterView()
        }
        .sheet(isPresented: $bindableStore.isAIConsolePresented) {
            AIConsoleView(client: store.aiConsoleClient)
                .frame(minWidth: 800, minHeight: 600)
        }
        .quickLookPreview($quickLookURL)
        .onChange(of: store.triggerQuickLook) { _, _ in
            handleQuickLook()
        }
        .fileImporter(
            isPresented: $bindableStore.isRepoPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        // Request access security scoped resource
                        let gotAccess = url.startAccessingSecurityScopedResource()
                        if !gotAccess { return } // Should handle error

                        await store.openLocalRepository(at: url)

                        // Note: In a real app we need to hold onto this access or bookmark it
                        // For this session we will just leave it open or let WorkspaceService manage bookmarking later
                    }
                }
            case .failure(let error):
                store.showToast(title: "Selection Failed", subtitle: error.localizedDescription)
            }
        }
        .toolbar {
            // Principle placement for Mode Picker
            ToolbarItem(placement: .principal) {
                Picker("", selection: $bindableAppState.currentMode) {
                    ForEach(AppMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320) // Wider for 4 modes
            }

            ToolbarItemGroup(placement: .primaryAction) {
                GovernanceChip()
                JobCenterButton()
            }
        }
        .overlay(alignment: .bottom) {
            ToastLayer()
        }
    }

    private func handleQuickLook() {
        guard let selection = store.inspectorSelection else { return }

        Task {
            switch selection {
            case .artifact(let id):
                // Download content to temp file
                if let data = await store.downloadArtifact(id: id),
                   let artifact = store.artifacts.first(where: { $0.id == id }) {
                    let tempDir = FileManager.default.temporaryDirectory
                    let url = tempDir.appendingPathComponent(artifact.name)
                    do {
                        try data.write(to: url)
                        await MainActor.run {
                            self.quickLookURL = url
                        }
                    } catch {
                        print("Failed to write preview file: \(error)")
                    }
                }
            case .entity(let id):
                // Generate a summary card for the entity
                let tempDir = FileManager.default.temporaryDirectory
                let url = tempDir.appendingPathComponent("Entity-\(id).html")
                let content = """
                <html>
                <head>
                    <style>
                        body { font-family: -apple-system, sans-serif; padding: 20px; color: #333; }
                        h1 { color: #007AFF; }
                        .card { border: 1px solid #ddd; padding: 20px; border-radius: 12px; background: #f9f9f9; }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <h1>Entity: \(id)</h1>
                        <p>This is a governed entity in the Anigma Graph.</p>
                        <p><strong>Status:</strong> Active</p>
                        <p><strong>Trust Level:</strong> Verifiable</p>
                    </div>
                </body>
                </html>
                """
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    await MainActor.run {
                        self.quickLookURL = url
                    }
                } catch {
                    print("Failed to generate entity preview: \(error)")
                }
            case .job(let id):
                // Preview job details
                if let job = store.jobs.first(where: { $0.id == id }) {
                    let tempDir = FileManager.default.temporaryDirectory
                    let url = tempDir.appendingPathComponent("Job-\(id).txt")
                    let content = """
                    Job: \(job.name)
                    ID: \(job.id)
                    Status: \(job.status)
                    Created: \(job.createdAt)
                    Trusted: \(job.isTrusted)
                    """
                    try? content.write(to: url, atomically: true, encoding: .utf8)
                    await MainActor.run {
                        self.quickLookURL = url
                    }
                }
            default:
                break
            }
        }
    }
}

// MARK: - Toast Layer

struct ToastLayer: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack {
            ForEach(store.activeToasts) { toast in
                ToastView(toast: toast)
                    .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: store.activeToasts)
        .onChange(of: store.activeToasts.count) { oldValue, newValue in
            if newValue > oldValue, let _ = store.activeToasts.last {
                // Announce new toast
            }
        }
    }
}

struct ToastView: View {
    let toast: AnigmaToast
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            if let icon = toast.icon {
                Image(systemName: icon)
                    .foregroundStyle(Bauhaus.Color.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(Bauhaus.Font.body).fontWeight(.bold)
                if let subtitle = toast.subtitle {
                    Text(subtitle).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }

            if let action = toast.actionLabel {
                Spacer()
                Button(action) {
                    store.isJobCenterPresented = true
                }
                .buttonStyle(.link)
                .font(Bauhaus.Font.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Bauhaus.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.bottom, 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(toast.title), \(toast.subtitle ?? "")")
        .accessibilityHint(toast.actionLabel != nil ? Text("Double tap to \(toast.actionLabel!)") : Text(""))
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var bindableAppState = appState

        List(selection: $bindableAppState.selectedSurface) {
            switch appState.currentMode {
            case .life:
                Section("Compass") {
                    SidebarRow(title: "Compass", icon: "location.north.fill")
                        .tag(UserSurface.compass)
                }

                Section("Personal") {
                    SidebarRow(title: "Inbox", icon: "tray.fill", count: store.inboxCount, statusText: store.inboxCount > 0 ? "\(store.inboxCount) queued" : nil)
                        .tag(UserSurface.inbox)
                    SidebarRow(title: "Atlas", icon: "globe", status: store.insightCount > 0 ? .newOutput : nil, statusText: store.insightCount > 0 ? "\(store.insightCount) new links" : nil)
                        .tag(UserSurface.atlas)
                    SidebarRow(title: "Ask", icon: "sparkles", status: .idle, statusText: "Ready")
                        .tag(UserSurface.ask)
                }

                Section("Shared") {
                    SidebarRow(title: "Projects", icon: "folder.fill", count: store.projectsCount)
                        .tag(UserSurface.projects)
                    SidebarRow(title: "Activity", icon: "chart.line.uptrend.xyaxis", count: store.runningJobsCount, status: store.hasRunningJobs ? .running : nil)
                        .tag(UserSurface.activity)
                }

                // ... (rest of the cases)

            case .work:
                Section("Work") {
                    SidebarRow(title: "Projects", icon: "folder.fill", count: store.projectsCount)
                        .tag(UserSurface.projects)
                    SidebarRow(title: "Data", icon: "tablecells.fill")
                        .tag(UserSurface.data)
                    SidebarRow(title: "Documents", icon: "books.vertical.fill", count: store.artifacts.count)
                        .tag(UserSurface.documentLibrary)
                    SidebarRow(title: "Project Inbox", icon: "tray.and.arrow.down.fill", count: store.inboxCount)
                        .tag(UserSurface.inbox)
                }

                Section("Assist") {
                    SidebarRow(title: "Ask", icon: "sparkles", status: .idle)
                        .tag(UserSurface.ask)
                    SidebarRow(title: "Activity", icon: "chart.line.uptrend.xyaxis", count: store.runningJobsCount, status: store.hasRunningJobs ? .running : nil)
                        .tag(UserSurface.activity)
                }

            case .insight:
                Section("Reasoning") {
                    SidebarRow(title: "Atlas", icon: "globe", count: store.insightCount)
                        .tag(UserSurface.atlas)
                    SidebarRow(title: "Evidence", icon: "link.circle.fill", status: .idle)
                        .tag(UserSurface.activity)
                }

                Section("Analysis") {
                    SidebarRow(title: "Data", icon: "tablecells.fill")
                        .tag(UserSurface.data)
                    SidebarRow(title: "Analyze", icon: "magnifyingglass.circle.fill")
                        .tag(UserSurface.ask)
                }

                Section("Monitoring") {
                    SidebarRow(title: "Observatorium", icon: "waveform.path.ecg")
                        .tag(UserSurface.observatorium)
                }

            case .develop:
                if let workspace = store.activeWorkspace {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(workspace.name).font(Bauhaus.Font.body).fontWeight(.bold)
                                Spacer()
                                if workspace.gitState.isDirty {
                                    Circle().frame(width: 8, height: 8).foregroundStyle(.orange)
                                }
                            }
                            HStack {
                                Image(systemName: "arrow.triangle.pull")
                                Text(workspace.gitState.branch).lineLimit(1)
                                Spacer()
                                Text(workspace.indexStatus.rawValue).font(Bauhaus.Font.mono).font(.system(size: 9))
                            }
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Navigator") {
                        SidebarRow(title: "Files", icon: "doc.on.doc.fill")
                            .tag(UserSurface.developFiles)
                        SidebarRow(title: "Search", icon: "magnifyingglass")
                            .tag(UserSurface.developSearch)
                    }

                    Section("Pipeline") {
                        SidebarRow(title: "Changes", icon: "diff", count: store.changeSets.filter { $0.status == .proposed }.count)
                            .tag(UserSurface.developChanges)
                        SidebarRow(title: "Runs", icon: "play.circle.fill", count: store.runningJobsCount, status: store.hasRunningJobs ? .running : nil)
                            .tag(UserSurface.developRuns)
                        SidebarRow(title: "Review", icon: "checkmark.seal.fill")
                            .tag(UserSurface.developReview)
                        SidebarRow(title: "Governance", icon: "shingle.2.fill")
                            .tag(UserSurface.developAgents)
                    }

                    Section("Work") {
                        SidebarRow(title: "Tasks", icon: "checklist", count: store.workItems.count)
                            .tag(UserSurface.developTasks)
                    }
                } else {
                    Section("Develop") {
                        Text("No active workspace").font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                        Button("Open Repository") {
                            // Workspace loader logic
                        }
                        .buttonStyle(.link)
                    }
                }
            case .build:
                Section("Construction") {
                    SidebarRow(title: "Studio", icon: "hammer.fill", status: .idle)
                        .tag(UserSurface.studio)
                    SidebarRow(title: "Export", icon: "square.and.arrow.up.fill")
                        .tag(UserSurface.export)
                    SidebarRow(title: "Action Catalog", icon: "tray.2.fill")
                        .tag(UserSurface.actionCatalog)
                }

                Section("Platform") {
                    SidebarRow(title: "AI Console", icon: "cpu.fill")
                        .tag(UserSurface.aiConsole)
                }

                Section("Assets") {
                    SidebarRow(title: "Artifact Store", icon: "archivebox.fill")
                        .tag(UserSurface.inbox)
                    SidebarRow(title: "Atlas (Raw)", icon: "globe")
                        .tag(UserSurface.atlas)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Anigma")
    }
}

// MARK: - Content Surface Router

struct ContentSurface: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.role {
        case .user:
            UserSurfaceView()
        case .worker:
            WorkerQueueView()
        case .admin:
            AdminConsoleView()
        case .developer:
            DevConsoleView()
        }
    }
}

import AnigmaWork

struct UserSurfaceView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.selectedSurface {
        case .compass:
            CompassView()
        case .inbox:
            InboxView()
        case .atlas:
            AtlasView()
        case .ask:
            AskView()
        case .projects:
            if let project = store.currentProject {
                WorkbenchView(project: project)
            } else {
                ProjectsView()
            }
        case .data:
            DataView()
        case .documentLibrary:
            DocumentLibraryView()
        case .studio:
            StudioView()
        case .export:
            UniversalExportView(engine: store.exportEngine)
        case .aiConsole:
            AIConsoleView(client: store.aiConsoleClient)
        case .develop, .developFiles, .developSearch, .developChanges, .developRuns, .developReview, .developTasks, .developAgents, .developBrowse, .developGithub:
            DevelopView()
        case .activity:
            ActivityView()
        case .actionCatalog:
            ActionCatalogView()
        case .observatorium:
            ObservatoriumDashboardView()
        }
    }
}

// MARK: - Daemon Warning Banner

struct DaemonWarningBanner: View {
    @Environment(AppStore.self) private var store
    @State private var isReconnecting = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Daemon Disconnected")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Some features are unavailable. The sidecar daemon is not responding.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Button {
                isReconnecting = true
                Task {
                    do {
                        _ = try await store.daemonCapability.ensureDaemonRunning()
                        store.daemonBridge = try await SidecarBridge.create(
                            clientName: "AnigmaAppMac",
                            scopes: ["Anigma.All"]
                        )
                        store.showToast(title: "Reconnected", subtitle: "Daemon is now available", icon: "checkmark.circle.fill")
                    } catch {
                        store.showError("Failed to reconnect: \(error.localizedDescription)")
                    }
                    isReconnecting = false
                }
            } label: {
                HStack {
                    if isReconnecting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text("Reconnect")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.orange)
            .disabled(isReconnecting)
        }
        .padding(.horizontal, Bauhaus.Grid.x3)
        .padding(.vertical, Bauhaus.Grid.x2)
        .background(Color.orange)
    }
}

#Preview {
    MacShell()
        .frame(width: 800, height: 600)
}
