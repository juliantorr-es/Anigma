//
//  HarmoniaBackgroundSyncSettingsView.swift
//  AnigmaAppMac
//
//  Settings for configuring Harmonia background synchronization.
//

import SwiftUI

// NonPersistent
struct HarmoniaBackgroundSyncSettingsView: View, Sendable {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            if let sync = store.harmoniaBackgroundSync {
                statusView(sync)
                configurationView(sync)
                controlsView(sync)
            } else {
                Text("Background sync not initialized")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Background Sync")
                .font(Bauhaus.Font.header)

            Spacer()
        }
    }

    private func statusView(_ sync: HarmoniaBackgroundSync) -> some View {
        HStack(spacing: Bauhaus.Grid.x3) {
            statusCard(
                label: "Status",
                value: sync.isRunning ? "Running" : "Stopped",
                icon: sync.isRunning ? "checkmark.circle.fill" : "stop.circle.fill",
                color: sync.isRunning ? Bauhaus.Color.success : Bauhaus.Color.error
            )

            if let lastDaemon = sync.lastDaemonCheck {
                statusCard(
                    label: "Last Daemon Check",
                    value: formatDate(lastDaemon),
                    icon: "server.rack",
                    color: Bauhaus.Color.accent
                )
            }

            if let lastVault = sync.lastVaultRefresh {
                statusCard(
                    label: "Last Vault Refresh",
                    value: formatDate(lastVault),
                    icon: "archivebox.fill",
                    color: Bauhaus.Color.accent
                )
            }
        }
    }

    private func statusCard(label: String, value: String, icon: String, color: Color) -> some View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func configurationView(_ sync: HarmoniaBackgroundSync) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Configuration")
                .font(Bauhaus.Font.subHeader)

            configRow(
                label: "Daemon Check Interval",
                value: "\(Int(sync.configuration.daemonCheckInterval))s",
                icon: "timer"
            )

            configRow(
                label: "Vault Refresh Interval",
                value: "\(Int(sync.configuration.vaultRefreshInterval / 60))m",
                icon: "timer"
            )

            configRow(
                label: "Pipeline Refresh Interval",
                value: "\(Int(sync.configuration.pipelineRefreshInterval))s",
                icon: "timer"
            )

            Toggle(isOn: .constant(sync.configuration.enableToastNotifications)) {
                Label("Toast Notifications", systemImage: "bell.fill")
                    .font(Bauhaus.Font.body)
            }
            .accessibilityLabel("Enable notifications")
            .disabled(true) // Read-only for now
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func configRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .frame(width: Bauhaus.Grid.x3)

            Text(label)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            Spacer()

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
    }

    private func controlsView(_ sync: HarmoniaBackgroundSync) -> some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            if sync.isRunning {
                Button(action: { sync.stop() }) {
                    Label("Stop Sync", systemImage: "stop.fill")
                }
                .accessibilityLabel("Stop sync engine")
                .buttonStyle(.bordered)

                Button(action: { Task { await sync.refreshAll() } }) {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: { sync.start() }) {
                    Label("Start Sync", systemImage: "play.fill")
                }
                .accessibilityLabel("Start sync engine")
                .buttonStyle(.borderedProminent)
            }

            Spacer()

            Button(action: { sync.restart() }) {
                Label("Restart", systemImage: "arrow.triangle.2.circlepath")
            }
            .accessibilityLabel("Restart sync engine")
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
