//
//  SidebarView.swift
//  AnigmaAppMac
//
//  Sidebar with mode-aware navigation and workspace management.
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var bindableAppState = appState

        List(selection: $bindableAppState.selectedSurface) {
            switch appState.currentMode {
            case .life:
                Section("Compass") {
                    MainSidebarRow(title: "Compass", icon: "location.north.fill")
                        .tag(UserSurface.compass)
                }

                Section("Personal") {
                    MainSidebarRow(title: "Inbox", icon: "tray.fill", count: store.inboxCount)
                        .tag(UserSurface.inbox)
                    MainSidebarRow(title: "Atlas", icon: "globe")
                        .tag(UserSurface.atlas)
                    MainSidebarRow(title: "Ask", icon: "sparkles")
                        .tag(UserSurface.ask)
                }

                Section("Shared") {
                    MainSidebarRow(title: "Projects", icon: "folder.fill", count: store.projectsCount)
                        .tag(UserSurface.projects)
                    MainSidebarRow(title: "Activity", icon: "chart.line.uptrend.xyaxis", count: store.runningJobsCount, status: store.hasRunningJobs ? .running : nil)
                        .tag(UserSurface.activity)
                }

            case .work:
                Section("Work") {
                    MainSidebarRow(title: "Projects", icon: "folder.fill", count: store.projectsCount)
                        .tag(UserSurface.projects)
                    MainSidebarRow(title: "Data", icon: "tablecells.fill")
                        .tag(UserSurface.data)
                    MainSidebarRow(title: "Documents", icon: "books.vertical.fill", count: store.artifacts.count)
                        .tag(UserSurface.documentLibrary)
                    MainSidebarRow(title: "Project Inbox", icon: "tray.and.arrow.down.fill", count: store.inboxCount)
                        .tag(UserSurface.inbox)
                }

                Section("Assist") {
                    MainSidebarRow(title: "Ask", icon: "sparkles")
                        .tag(UserSurface.ask)
                    MainSidebarRow(title: "Activity", icon: "chart.line.uptrend.xyaxis", count: store.runningJobsCount, status: store.hasRunningJobs ? .running : nil)
                        .tag(UserSurface.activity)
                }

            case .insight:
                Section("Reasoning") {
                    MainSidebarRow(title: "Atlas", icon: "globe")
                        .tag(UserSurface.atlas)
                    MainSidebarRow(title: "Evidence", icon: "link.circle.fill")
                        .tag(UserSurface.activity)
                }

                Section("Analysis") {
                    MainSidebarRow(title: "Data", icon: "tablecells.fill")
                        .tag(UserSurface.data)
                    MainSidebarRow(title: "Analyze", icon: "magnifyingglass.circle.fill")
                        .tag(UserSurface.ask)
                }

                Section("Monitoring") {
                    MainSidebarRow(title: "Observatorium", icon: "waveform.path.ecg")
                        .tag(UserSurface.observatorium)
                }

            case .develop:
                if let workspace = store.activeWorkspace {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(workspace.name).font(.body).fontWeight(.bold)
                                Spacer()
                                if workspace.gitState.isDirty {
                                    Circle().frame(width: 8, height: 8).foregroundStyle(.orange)
                                }
                            }
                            HStack {
                                Image(systemName: "arrow.triangle.pull")
                                Text(workspace.gitState.branch).lineLimit(1)
                                Spacer()
                                Text(workspace.indexStatus.rawValue).font(.system(size: 9, design: .monospaced))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Navigator") {
                        MainSidebarRow(title: "Files", icon: "doc.on.doc.fill")
                            .tag(UserSurface.developFiles)
                        MainSidebarRow(title: "Search", icon: "magnifyingglass")
                            .tag(UserSurface.developSearch)
                    }

                    Section("Pipeline") {
                        MainSidebarRow(title: "Changes", icon: "diff", count: store.changeSets.filter { $0.status == .proposed }.count)
                            .tag(UserSurface.developChanges)
                        MainSidebarRow(title: "Runs", icon: "play.circle.fill", count: store.runningJobsCount, status: store.hasRunningJobs ? .running : nil)
                            .tag(UserSurface.developRuns)
                        MainSidebarRow(title: "Review", icon: "checkmark.seal.fill")
                            .tag(UserSurface.developReview)
                        MainSidebarRow(title: "Governance", icon: "shingle.2.fill")
                            .tag(UserSurface.developAgents)
                    }

                    Section("Work") {
                        MainSidebarRow(title: "Tasks", icon: "checklist", count: store.workItems.count)
                            .tag(UserSurface.developTasks)
                    }
                } else {
                    Section("Develop") {
                        Text("No active workspace").font(.caption).foregroundStyle(.tertiary)
                        Button("Open Repository") {
                            store.isRepoPickerPresented = true
                        }
                        .buttonStyle(.link)
                    }
                }
            case .build:
                Section("Construction") {
                    MainSidebarRow(title: "Studio", icon: "hammer.fill")
                        .tag(UserSurface.studio)
                    MainSidebarRow(title: "Export", icon: "square.and.arrow.up.fill")
                        .tag(UserSurface.export)
                    MainSidebarRow(title: "Action Catalog", icon: "tray.2.fill")
                        .tag(UserSurface.actionCatalog)
                }

                Section("Platform") {
                    MainSidebarRow(title: "AI Console", icon: "cpu.fill")
                        .tag(UserSurface.aiConsole)
                    MainSidebarRow(title: "Vault", icon: "shield.checkered")
                        .tag(UserSurface.vault)
                }

                Section("Assets") {
                    MainSidebarRow(title: "Artifact Store", icon: "archivebox.fill")
                        .tag(UserSurface.inbox)
                    MainSidebarRow(title: "Atlas (Raw)", icon: "globe")
                        .tag(UserSurface.atlas)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Anigma")
    }
}

private struct MainSidebarRow: View {
    let title: String
    let icon: String
    var count: Int? = nil
    var status: SidebarRowStatus? = nil

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private enum SidebarRowStatus {
    case running
}
