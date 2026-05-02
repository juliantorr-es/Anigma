//
//  RepoNavigator.swift
//  AnigmaAppMac
//
//  Repository navigation and mode switching.
//

import AppKit
import SwiftUI

struct RepoNavigator: View {
    @Bindable var developState: DevelopState

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("Navigator Mode", selection: $developState.navigatorMode) {
                ForEach(RepoNavigatorMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch developState.navigatorMode {
            case .files:
                RepoFilesView(developState: developState)
            case .search:
                RepoSearchView(developState: developState)
            case .changes:
                RepoChangesView(developState: developState)
            case .runs:
                RepoRunsView(developState: developState)
            case .review:
                RepoReviewView(developState: developState)
            case .tasks:
                RepoTasksView(developState: developState)
            case .agents:
                RepoAgentsView(developState: developState)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Repository")
                    .font(.headline)
                Text(developState.repoURL?.lastPathComponent ?? "No repo selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open") {
                openRepoPicker()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func openRepoPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Open"
        panel.title = "Choose Repository"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                developState.openRepository(url: url)
            }
        }
    }
}

private struct RepoFilesView: View {
    @Bindable var developState: DevelopState

    var body: some View {
        List(selection: $developState.selectedFileURL) {
            OutlineGroup(developState.fileTree, children: \.children) { node in
                if node.isDirectory {
                    Label(node.name, systemImage: "folder")
                } else {
                    Label(node.name, systemImage: "doc.text")
                        .tag(node.url)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            developState.selectedFileURL = node.url
                        }
                }
            }
        }
        .overlay {
            if developState.isLoadingFiles {
                ProgressView()
            }
        }
        .listStyle(.sidebar)
    }
}

private struct RepoSearchView: View {
    @Bindable var developState: DevelopState

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search", text: $developState.searchQuery)
                    .textFieldStyle(.roundedBorder)
                Button("Go") {
                    Task { await developState.runSearch() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if developState.isSearching {
                ProgressView("Searching...")
                    .padding(.horizontal, 12)
            }

            List(developState.searchResults) { result in
                Button {
                    developState.selectedFileURL = result.url
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.url.lastPathComponent)
                            .font(.subheadline)
                        Text("Line \(result.lineNumber): \(result.preview)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
    }
}

private struct RepoChangesView: View {
    @Bindable var developState: DevelopState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Changes")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task { await developState.refreshChanges() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if developState.isLoadingChanges {
                ProgressView("Loading...")
                    .padding(.horizontal, 12)
            }

            List(developState.changeSet) { change in
                HStack {
                    Text(change.status)
                        .font(.caption)
                        .frame(width: 24, alignment: .leading)
                    Text(change.path)
                        .font(.subheadline)
                    Spacer()
                }
            }
            .listStyle(.inset)
        }
        .onAppear {
            Task { await developState.refreshChanges() }
        }
    }
}

private struct RepoRunsView: View {
    @Bindable var developState: DevelopState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Runs")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task { await developState.refreshJobs() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if developState.isLoadingJobs {
                ProgressView("Fetching jobs...")
                    .padding(.horizontal, 12)
            }

            if let error = developState.lastJobError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }

            List(developState.jobs) { job in
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.action)
                        .font(.subheadline)
                    Text("Status: \(job.status)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.inset)
        }
        .onAppear {
            Task { await developState.refreshJobs() }
        }
    }
}

private struct RepoReviewView: View {
    @Bindable var developState: DevelopState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Review")
                    .font(.headline)
                Spacer()
                Button("Reload") {
                    Task { await developState.refreshChanges() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            List(developState.changeSet) { change in
                Button {
                    if let repoURL = developState.repoURL {
                        developState.selectedFileURL = repoURL.appendingPathComponent(change.path)
                    }
                } label: {
                    HStack {
                        Text(change.status)
                            .font(.caption)
                            .frame(width: 24, alignment: .leading)
                        Text(change.path)
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
    }
}

private struct RepoTasksView: View {
    @Bindable var developState: DevelopState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tasks")
                    .font(.headline)
                Spacer()
                Button("Scan") {
                    Task { await developState.refreshTasks() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if developState.isLoadingTasks {
                ProgressView("Scanning...")
                    .padding(.horizontal, 12)
            }

            List(developState.taskItems) { task in
                Button {
                    developState.selectedFileURL = task.url
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.url.lastPathComponent)
                            .font(.subheadline)
                        Text("Line \(task.lineNumber): \(task.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
    }
}

private struct RepoAgentsView: View {
    @Bindable var developState: DevelopState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agent Refactor")
                .font(.headline)
                .padding(.top, 10)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Instruction")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $developState.agentInstruction)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3))
                    )
            }
            .padding(.horizontal, 12)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(developState.selectedFileURL?.lastPathComponent ?? "No file selected")
                        .font(.subheadline)
                }
                Spacer()
                Button("Run Refactor") {
                    Task { await developState.runAgentRefactor() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)

            if let error = developState.lastJobError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
