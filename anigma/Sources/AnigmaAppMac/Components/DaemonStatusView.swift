//
//  DaemonStatusView.swift
//  AnigmaAppMac
//
//  Displays Harmonia daemon status with start/stop controls.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct DaemonStatusView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var daemonStatus: HarmoniaClient.DaemonStatusResponse?
    @State private var isRefreshing = false
    @State private var isStarting = false
    @State private var isStopping = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            if let status = daemonStatus {
                statusDetailsView(status)
            } else if isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("Status unknown")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            if let error = errorMessage {
                errorView(error)
            }

            controlButtonsView
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .task {
            await refreshStatus()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Daemon Status")
                .font(Bauhaus.Font.header)

            Spacer()

            Button(action: { Task { await refreshStatus() } }) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .accessibilityLabel("Refresh status")
            .buttonStyle(.borderless)
            .disabled(isRefreshing)
        }
    }

    private func statusDetailsView(_ status: HarmoniaClient.DaemonStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Circle()
                    .fill(status.running ? Bauhaus.Color.success : Bauhaus.Color.error)
                    .frame(width: Bauhaus.Grid.unit, height: Bauhaus.Grid.unit)

                Text(status.running ? "Daemon \(status.running ? "Online" : "Offline")" : "Stopped")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(status.running ? Bauhaus.Color.success : Bauhaus.Color.error)
            }
            .padding(.bottom, 4)

            if let pid = status.pid {
                infoRow(label: "Process ID", value: "\(pid)")
            }

            if let uptime = status.uptime {
                infoRow(label: "Uptime", value: formatUptime(uptime))
            }

            if let detailed = store.daemonDetailedStatus {
                Divider().opacity(0.3)

                infoRow(label: "API Version", value: detailed.apiVersion)
                infoRow(label: "Build Hash", value: String(detailed.buildHash.prefix(8)))
                infoRow(label: "Parallel Workers", value: "\(detailed.workerProcesses)")

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Vault Usage")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                        Spacer()
                        Text("\(formatBytes(detailed.vaultSizeBytes)) / \(formatBytes(detailed.vaultQuotaBytes))")
                            .font(Bauhaus.Font.mono)
                            .foregroundStyle(Bauhaus.Color.textPrimary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Bauhaus.Color.background)
                                .frame(height: 4) // OK: Fixed progress height

                            Rectangle()
                                .fill(Bauhaus.Color.accent)
                                .frame(width: geo.size.width * min(1.0, Double(detailed.vaultSizeBytes) / Double(detailed.vaultQuotaBytes)), height: 4) // OK: Fixed progress height
                        }
                    }
                    .frame(height: 4) // OK: Fixed progress height
                    .cornerRadius(2)
                }
                .padding(.top, 4)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Spacer()

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textPrimary)
        }
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

    private var controlButtonsView: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            if daemonStatus?.running == true {
                Button(action: { Task { await stopDaemon() } }) {
                    Label("Stop Daemon", systemImage: "stop.fill")
                }
                .accessibilityLabel("Stop daemon process")
                .secondaryButtonStyle()
                .disabled(isStopping)

                if isStopping {
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                Button(action: { Task { await startDaemon() } }) {
                    Label("Start Active Sidecar", systemImage: "play.fill")
                }
                .accessibilityLabel("Start daemon process")
                .primaryButtonStyle()
                .disabled(isStarting)

                if isStarting {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Actions

    private func refreshStatus() async {
        isRefreshing = true
        errorMessage = nil

        do {
            daemonStatus = try await store.harmoniaClient.daemonStatus()
            if daemonStatus?.running == true {
                await store.refreshDaemonStatus()
            }
        } catch {
            errorMessage = "Failed to get status: \(error.localizedDescription)"
        }

        isRefreshing = false
    }

    private func startDaemon() async {
        isStarting = true
        errorMessage = nil

        do {
            try await store.startDaemon()
            // Wait a moment for daemon to start
            try await Task.sleep(for: .seconds(2))
            await refreshStatus()
        } catch {
            errorMessage = "Failed to start: \(error.localizedDescription)"
        }

        isStarting = false
    }

    private func stopDaemon() async {
        isStopping = true
        errorMessage = nil

        do {
            try await store.stopDaemon()
            // Wait a moment for daemon to stop
            try await Task.sleep(for: .seconds(0.5))
            await refreshStatus()
        } catch {
            errorMessage = "Failed to stop: \(error.localizedDescription)"
        }

        isStopping = false
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}
