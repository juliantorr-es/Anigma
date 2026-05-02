//
//  PipelineMonitorView.swift
//  AnigmaAppMac
//
//  Real-time pipeline and job queue monitoring.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct PipelineMonitorView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var autoRefresh = true
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            if let pipeline = store.pipelineStatus {
                statisticsView(pipeline)
                jobBreakdownView(pipeline)
            } else if isRefreshing {
                loadingView
            } else {
                emptyStateView
            }

            if let error = errorMessage {
                errorView(error)
            }

            controlsView
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .task {
            await refreshStatus()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "gauge.high")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Pipeline Monitor")
                .font(Bauhaus.Font.header)

            Spacer()

            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button(action: { Task { await refreshStatus() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh pipeline status")
            .buttonStyle(.borderless)
            .disabled(isRefreshing)
        }
    }

    private func statisticsView(_ pipeline: HarmoniaClient.PipelineStatusResponse) -> some View {
        HStack(spacing: Bauhaus.Grid.x3) {
            statCard(
                label: "Workspace",
                value: pipeline.workspace,
                icon: "folder.fill",
                color: Bauhaus.Color.accent
            )
        }
    }

    private func jobBreakdownView(_ pipeline: HarmoniaClient.PipelineStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Job Queue")
                .font(Bauhaus.Font.subHeader)

            jobStatRow(
                label: "Pending",
                count: pipeline.pendingJobs,
                icon: "clock.fill",
                color: Bauhaus.Color.warning
            )

            jobStatRow(
                label: "Running",
                count: pipeline.runningJobs,
                icon: "play.circle.fill",
                color: Bauhaus.Color.running
            )

            jobStatRow(
                label: "Completed",
                count: pipeline.completedJobs,
                icon: "checkmark.circle.fill",
                color: Bauhaus.Color.success
            )

            jobStatRow(
                label: "Failed",
                count: pipeline.failedJobs,
                icon: "xmark.circle.fill",
                color: Bauhaus.Color.error
            )

            Divider()

            HStack {
                Text("Total Jobs")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)

                Spacer()

                Text("\(totalJobs(pipeline))")
                    .font(Bauhaus.Font.mono)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func statCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func jobStatRow(label: String, count: Int, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: Bauhaus.Grid.x3)

            Text(label)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            Spacer()

            Text("\(count)")
                .font(Bauhaus.Font.mono)
                .foregroundStyle(count > 0 ? color : Bauhaus.Color.textSecondary)
                .padding(.horizontal, Bauhaus.Grid.x2)
                .padding(.vertical, Bauhaus.Grid.unit)
                .background(count > 0 ? color.opacity(0.1) : Color.clear)
                .cornerRadius(Bauhaus.Grid.unit / 2)
        }
    }

    private var loadingView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            ProgressView()
                .controlSize(.small)

            Text("Loading pipeline status...")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }

    private var emptyStateView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text("No workspace selected")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Text("Select a workspace to view pipeline status")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Bauhaus.Color.warning)

            Text(message)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.warning)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.warning.opacity(0.1))
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private var controlsView: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            Toggle(isOn: $autoRefresh) {
                Label("Auto-refresh", systemImage: "arrow.clockwise.circle")
                    .font(Bauhaus.Font.caption)
            }
            .accessibilityLabel("Toggle auto-refresh")
            .toggleStyle(.switch)
            .onChange(of: autoRefresh) { _, newValue in
                if newValue {
                    startAutoRefresh()
                } else {
                    stopAutoRefresh()
                }
            }

            if autoRefresh {
                Text("Every 30s")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private func refreshStatus() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil

        await store.refreshPipelineStatus()

        if store.pipelineStatus == nil && store.activeWorkspace == nil {
            errorMessage = nil // Don't show error if no workspace is selected
        }

        isRefreshing = false
    }

    private func startAutoRefresh() {
        guard autoRefresh else { return }

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                await refreshStatus()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Helpers

    private func totalJobs(_ pipeline: HarmoniaClient.PipelineStatusResponse) -> Int {
        pipeline.pendingJobs + pipeline.runningJobs + pipeline.completedJobs + pipeline.failedJobs
    }
}
