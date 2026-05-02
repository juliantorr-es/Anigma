//
//  DashboardView.swift
//  AnigmaAppMac
//
//  Assistant-first dashboard: essential status up front, ops detail behind disclosure.
//

import SwiftUI
import AnigmaClientKit

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var showOperationsDetails = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Start with the assistant. Expand operations only when needed.")
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

                AssistantPrimerCard()

                DaemonConnectionCard()

                DisclosureGroup(isExpanded: $showOperationsDetails) {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
                    ], spacing: 16) {
                        GovernanceSummaryCard()
                        SystemHealthCard()
                        QuickActionsCard()
                    }
                    .padding(.top, 8)

                    TelemetrySection()
                }
                label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Operations details")
                            .font(.headline)
                        Text("Governance telemetry, system health, and maintenance actions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
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
                        Task {
                            await appState.disconnectFromDaemon()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Connect") {
                        Task {
                            await appState.connectToDaemon()
                        }
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

// MARK: - Assistant Primer

struct AssistantPrimerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                Text("Assistant first")
                    .font(.headline)
            }

            Text("Use the assistant to answer questions, gather evidence, and draft actions before opening deeper operational tools.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
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
                    ForEach(Array(appState.filteredTelemetry.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            Text(entry)
                                .font(.subheadline)
                            Spacer()
                            Text("#\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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

// Telemetry row no longer needed; telemetry payload is string-based.

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
