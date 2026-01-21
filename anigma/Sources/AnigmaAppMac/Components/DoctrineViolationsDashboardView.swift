//
//  DoctrineViolationsDashboardView.swift
//  AnigmaAppMac
//
//  Dashboard for viewing and managing doctrine violations.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct DoctrineViolationsDashboardView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var selectedSeverity: String?
    @State private var selectedDomain: String?
    @State private var showResolvedOnly = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            if let stats = store.doctrineStats {
                statisticsView(stats)
            }

            controlsView

            violationsListView

            if let error = errorMessage {
                errorView(error)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .task {
            await loadStats()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "list.clipboard.fill")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Violations Dashboard")
                .font(Bauhaus.Font.header)

            Spacer()

            Button(action: { Task { await loadStats() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh dashboard")
            .buttonStyle(.borderless)
            .disabled(isLoading)
        }
    }

    private func statisticsView(_ stats: DoctrineClient.ViolationStatsResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Overview")
                .font(Bauhaus.Font.subHeader)

            HStack(spacing: Bauhaus.Grid.x3) {
                statCard(
                    label: "Total",
                    value: "\(stats.totalViolations)",
                    color: Bauhaus.Color.accent
                )

                statCard(
                    label: "Unresolved",
                    value: "\(stats.unresolvedViolations)",
                    color: stats.unresolvedViolations > 0 ? Bauhaus.Color.warning : Bauhaus.Color.success
                )

                statCard(
                    label: "Resolved",
                    value: "\(stats.totalViolations - stats.unresolvedViolations)",
                    color: Bauhaus.Color.success
                )
            }

            if !stats.bySeverity.isEmpty {
                Divider()
                severityBreakdownView(stats.bySeverity)
            }

            if !stats.byDomain.isEmpty {
                Divider()
                domainBreakdownView(stats.byDomain)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: Bauhaus.Grid.unit) {
            Text(value)
                .font(Bauhaus.Font.header)
                .foregroundStyle(color)

            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func severityBreakdownView(_ bySeverity: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text("By Severity")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            ForEach(bySeverity.sorted { $0.value > $1.value }, id: \.key) { severity, count in
                HStack {
                    Circle()
                        .fill(severityColor(severity)) // OK: Bauhaus
                        .frame(width: Bauhaus.Grid.unit, height: Bauhaus.Grid.unit)

                    Text(severity.capitalized)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textPrimary)

                    Spacer()

                    Text("\(count)")
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(severityColor(severity)) // OK: Bauhaus
                }
            }
        }
    }

    private func domainBreakdownView(_ byDomain: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text("By Domain")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            ForEach(byDomain.sorted { $0.value > $1.value }, id: \.key) { domain, count in
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .frame(width: Bauhaus.Grid.x2)

                    Text(domain)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textPrimary)

                    Spacer()

                    Text("\(count)")
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(Bauhaus.Color.accent)
                }
            }
        }
    }

    private var controlsView: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            Menu {
                Button("All Severities") {
                    selectedSeverity = nil
                }
                .accessibilityLabel("View all severities")
                Divider()
                Button("Critical") { selectedSeverity = "critical" }
                    .accessibilityLabel("Filter critical violations")
                Button("Error") { selectedSeverity = "error" }
                    .accessibilityLabel("Filter error violations")
                Button("Warning") { selectedSeverity = "warning" }
                    .accessibilityLabel("Filter warning violations")
                Button("Info") { selectedSeverity = "info" }
                    .accessibilityLabel("Filter info violations")
            } label: {
                Label(selectedSeverity?.capitalized ?? "All Severities", systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.bordered)

            Menu {
                Button("All Domains") {
                    selectedDomain = nil
                }
                .accessibilityLabel("View all domains")
                Divider()
                if let stats = store.doctrineStats {
                    ForEach(Array(stats.byDomain.keys).sorted(), id: \.self) { domain in
                        Button(domain) { selectedDomain = domain }
                            .accessibilityLabel("Filter domain \(domain)")
                    }
                }
            } label: {
                Label(selectedDomain ?? "All Domains", systemImage: "tag")
            }
            .buttonStyle(.bordered)

            Toggle(isOn: $showResolvedOnly) {
                Text("Show Resolved")
                    .font(Bauhaus.Font.caption)
            }
            .accessibilityLabel("Show only resolved violations")
            .toggleStyle(.checkbox)

            Spacer()
        }
    }

    private var violationsListView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Violations")
                .font(Bauhaus.Font.subHeader)

            ScrollView {
                Text("Violation list coming soon...")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(Bauhaus.Grid.x4)
            }
            .frame(maxHeight: 300)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Bauhaus.Color.error)

            Text(message)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.error)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.error.opacity(0.1))
        .cornerRadius(Bauhaus.Grid.unit)
    }

    // MARK: - Actions

    private func loadStats() async {
        isLoading = true
        errorMessage = nil

        await store.loadDoctrineStats()

        if store.doctrineStats == nil {
            errorMessage = "Failed to load statistics. Check that doctrine is installed."
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func severityColor(_ severity: String) -> Color { // OK: Bauhaus
        switch severity.lowercased() {
        case "critical": return Bauhaus.Color.error
        case "error": return Bauhaus.Color.error
        case "warning": return Bauhaus.Color.warning
        case "info": return Bauhaus.Color.running
        default: return Bauhaus.Color.textSecondary
        }
    }
}
