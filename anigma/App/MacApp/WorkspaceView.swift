//
//  WorkspaceView.swift
//  AnigmaAppMac
//
//  Main workspace view with artifacts and jobs tabs.
//

import SwiftUI

struct WorkspaceView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: Tab = .jobs

    enum Tab: String, CaseIterable {
        case artifacts = "Artifacts"
        case jobs = "Jobs"

        var icon: String {
            switch self {
            case .artifacts: return "doc.text"
            case .jobs: return "gearshape.2"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !store.isOnline && !store.isInitializing {
                OfflineBanner()
                    .accessibilityLabel("App is offline")
            }

            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityLabel("Workspace Section Selector")
            .accessibilityHint("Choose between Artifacts and Jobs")

            Divider()

            // Content
            if store.isInitializing {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(store.daemonStatus)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.initializationError {
                ContentUnavailableView {
                    Label("Initialization Failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await store.initialLoad() }
                    }
                }
            } else {
                if selectedTab == .artifacts {
                    ArtifactListView()
                } else {
                    JobListView()
                }
            }
        }
        .navigationTitle(store.selectedWorkspaceID ?? "No Workspace")
        .navigationSubtitle(store.daemonStatus)
    }
}
