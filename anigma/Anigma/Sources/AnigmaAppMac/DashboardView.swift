//
//  DashboardView.swift
//  AnigmaAppMac
//
//  Dashboard showing daemon connection status, governance telemetry, and quick actions.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("System overview and governance telemetry")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        Task { await appState.refreshTelemetry() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .padding(.bottom, 8)
                
                // Status Cards Row
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
                ], spacing: 16) {
                    DaemonConnectionCard()
                    GovernanceSummaryCard()
                    SystemHealthCard()
                    QuickActionsCard()
                }
                
                // Telemetry Section
                TelemetrySection()
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Daemon Connection Card

struct DaemonConnectionCard: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Spacer()
                StatusPill(
                    text: appState.daemonStatus.rawValue,
                    color: appState.daemonStatus.color
                )
            }
            
            Text("Daemon Connection")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Version", value: appState.daemonVersion)
                    .font(.caption)
                
                if let heartbeat = appState.lastHeartbeat {
                    LabeledContent("Last Heartbeat") {
                        Text(heartbeat.formatted(.relative(presentation: .named)))
                    }
                    .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack {
                if appState.daemonStatus == .connected {
                    Button("Disconnect") {
                        appState.disconnectFromDaemon()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Connect") {
                        Task { await appState.connectToDaemon() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(appState.daemonStatus == .connecting)
                }
            }
        }
        .padding()
        .frame(height: 180)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Governance Summary Card

struct GovernanceSummaryCard: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundStyle(.green)
                Spacer()
                Text("\(appState.telemetryEntries.count) events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("Governance Status")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatBadge(
                    value: appState.passedCount,
                    label: "Passed",
                    color: .green
                )
                StatBadge(
                    value: appState.warningCount,
                    label: "Warnings",
                    color: .orange
                )
                StatBadge(
                    value: appState.failedCount,
                    label: "Failed",
                    color: .red
                )
            }
            
            Spacer()
            
            ProgressView(value: Double(appState.passedCount), total: Double(max(1, appState.telemetryEntries.count)))
                .tint(.green)
        }
        .padding()
        .frame(height: 180)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - System Health Card

struct SystemHealthCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Spacer()
                StatusPill(text: "Healthy", color: .green)
            }
            
            Text("System Health")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("CPU", value: "12%")
                    .font(.caption)
                LabeledContent("Memory", value: "2.4 GB")
                    .font(.caption)
                LabeledContent("Disk", value: "45.2 GB free")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(height: 180)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Spacer()
            }
            
            Text("Quick Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                ActionButton(
                    title: "Run CI Gates",
                    icon: "checkmark.shield",
                    action: { Task { await appState.refreshTelemetry() } }
                )
                ActionButton(
                    title: "Sync Documents",
                    icon: "arrow.triangle.2.circlepath",
                    action: { Task { await appState.refreshDocuments() } }
                )
                ActionButton(
                    title: "View Logs",
                    icon: "doc.text.magnifyingglass",
                    action: {}
                )
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 180)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Telemetry Section

struct TelemetrySection: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Governance Telemetry")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("Filter", selection: $state.telemetryFilter) {
                    Text("All").tag(GovernanceStatus?.none)
                    ForEach([GovernanceStatus.passed, .warning, .failed], id: \.self) { status in
                        Label(status.rawValue, systemImage: status.icon)
                            .tag(GovernanceStatus?.some(status))
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            
            if appState.filteredTelemetry.isEmpty {
                ContentUnavailableView(
                    "No Telemetry Events",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Governance telemetry events will appear here")
                )
                .frame(height: 200)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(appState.filteredTelemetry) { entry in
                        TelemetryRow(entry: entry)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Telemetry Row

struct TelemetryRow: View {
    let entry: GovernanceTelemetryEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.status.icon)
                .foregroundStyle(entry.status.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.eventType)
                        .font(.headline)
                    Text(entry.module)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
                Text(entry.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(entry.timestamp.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Helper Components

struct StatusPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .frame(width: 900, height: 800)
}
