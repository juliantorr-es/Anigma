//
//  HarmoniaCommandHistoryView.swift
//  AnigmaAppMac
//
//  View for browsing and managing Harmonia command history.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct HarmoniaCommandHistoryView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var selectedEntry: HarmoniaCommandHistory.HistoryEntry?
    @State private var searchText: String = ""
    @State private var showOnlyFailed: Bool = false
    @State private var showExportSheet: Bool = false

    private var filteredEntries: [HarmoniaCommandHistory.HistoryEntry] {
        guard let history = store.harmoniaCommandHistory else { return [] }

        var entries = showOnlyFailed ? history.failedEntries : history.entries

        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.fullCommand.localizedCaseInsensitiveContains(searchText) ||
                entry.error?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return entries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            if let history = store.harmoniaCommandHistory {
                statisticsView(history.statistics)
            }

            controlsView

            historyListView

            if let entry = selectedEntry {
                detailView(entry)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .sheet(isPresented: $showExportSheet) {
            exportView
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Command History")
                .font(Bauhaus.Font.header)

            Spacer()

            if let history = store.harmoniaCommandHistory {
                Text("\(history.entries.count) commands")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
    }

    private func statisticsView(_ stats: HarmoniaCommandHistory.Statistics) -> some View {
        HStack(spacing: Bauhaus.Grid.x3) {
            statCard(
                label: "Success Rate",
                value: stats.formattedSuccessRate,
                icon: "checkmark.circle.fill",
                color: stats.successRate > 0.8 ? Bauhaus.Color.success : Bauhaus.Color.warning
            )

            statCard(
                label: "Avg Duration",
                value: String(format: "%.2fs", stats.averageDuration),
                icon: "clock.fill",
                color: Bauhaus.Color.accent
            )

            if let mostUsed = stats.mostUsedCommand {
                statCard(
                    label: "Most Used",
                    value: mostUsed,
                    icon: "star.fill",
                    color: Bauhaus.Color.accent
                )
            }
        }
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private var controlsView: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            TextField("Search commands...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search commands")

            Toggle(isOn: $showOnlyFailed) {
                Label("Failed Only", systemImage: "xmark.circle")
                    .font(Bauhaus.Font.caption)
            }
            .toggleStyle(.switch)
            .accessibilityLabel("Show only failed commands")

            Button(action: { showExportSheet = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Export history")
            .secondaryButtonStyle()

            Button(action: clearHistory) {
                Label("Clear", systemImage: "trash")
            }
            .accessibilityLabel("Clear history")
            .destructiveButtonStyle()
        }
    }

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: Bauhaus.Grid.x2) {
                ForEach(filteredEntries) { entry in
                    historyRow(entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEntry = entry
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("View details for \(entry.fullCommand)")
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func historyRow(_ entry: HarmoniaCommandHistory.HistoryEntry) -> some View {
        let isSelected = selectedEntry?.id == entry.id

        return HStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.success ? Bauhaus.Color.success : Bauhaus.Color.error)
                .frame(width: 20) // OK: Icon width

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fullCommand)
                    .font(Bauhaus.Font.mono)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
                    .lineLimit(1)

                HStack {
                    Text(formatDate(entry.timestamp))
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    Text("•")
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    Text(entry.formattedDuration)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }

            Spacer()
        }
        .padding(Bauhaus.Grid.x2)
        .background(isSelected ? Bauhaus.Color.accent.opacity(0.1) : Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.unit)
                .stroke(isSelected ? Bauhaus.Color.accent : Color.clear, lineWidth: 1)
        )
    }

    private func detailView(_ entry: HarmoniaCommandHistory.HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Text("Details")
                    .font(Bauhaus.Font.subHeader)

                Spacer()

                Button(action: { selectedEntry = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                .accessibilityLabel("Close details")
                .buttonStyle(.borderless)
            }

            detailRow(label: "Command", value: entry.fullCommand)
            detailRow(label: "Timestamp", value: formatFullDate(entry.timestamp))
            detailRow(label: "Duration", value: entry.formattedDuration)
            detailRow(label: "Status", value: entry.success ? "Success" : "Failed")

            if let exitCode = entry.exitCode {
                detailRow(label: "Exit Code", value: "\(exitCode)")
            }

            if let output = entry.output {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("Output")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    Text(output)
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(Bauhaus.Color.textPrimary)
                        .textSelection(.enabled)
                }
            }

            if let error = entry.error {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("Error")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.error)

                    Text(error)
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(Bauhaus.Color.error)
                        .textSelection(.enabled)
                }
                .padding(Bauhaus.Grid.x2)
                .background(Bauhaus.Color.error.opacity(0.1))
                .cornerRadius(Bauhaus.Grid.unit)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .frame(width: 100, alignment: .leading) // OK: Label width

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textPrimary)
                .textSelection(.enabled)
        }
    }

    private var exportView: some View {
        VStack(spacing: Bauhaus.Grid.x3) {
            Text("Export Command History")
                .font(Bauhaus.Font.header)

            Button("Export as JSON") {
                exportJSON()
            }
            .accessibilityLabel("Download JSON")
            .primaryButtonStyle()

            Button("Export as CSV") {
                exportCSV()
            }
            .accessibilityLabel("Download CSV")
            .secondaryButtonStyle()

            Button("Cancel") {
                showExportSheet = false
            }
            .accessibilityLabel("Cancel export")
            .secondaryButtonStyle()
        }
        .padding(Bauhaus.Grid.x4)
        .frame(width: 300) // OK: Export sheet width
    }

    // MARK: - Actions

    private func clearHistory() {
        guard let history = store.harmoniaCommandHistory else { return }

        history.clear()
        selectedEntry = nil

        store.showToast(
            title: "History Cleared",
            subtitle: "All command history has been removed",
            icon: "trash.fill"
        )
    }

    private func exportJSON() {
        guard let history = store.harmoniaCommandHistory else { return }

        do {
            let data = try history.exportJSON()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "harmonia_history.json"

            panel.begin { response in
                if response == .OK, let url = panel.url {
                    try? data.write(to: url)
                    showExportSheet = false
                    store.showToast(
                        title: "Exported",
                        subtitle: "History saved to \(url.lastPathComponent)",
                        icon: "checkmark.circle.fill"
                    )
                }
            }
        } catch {
            store.showToast(
                title: "Export Failed",
                subtitle: error.localizedDescription,
                icon: "xmark.circle.fill"
            )
        }
    }

    private func exportCSV() {
        guard let history = store.harmoniaCommandHistory else { return }

        let csv = history.exportCSV()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "harmonia_history.csv"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
                showExportSheet = false
                store.showToast(
                    title: "Exported",
                    subtitle: "History saved to \(url.lastPathComponent)",
                    icon: "checkmark.circle.fill"
                )
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
