//
//  TechDebtDashboardView.swift
//  AnigmaAppMac
//
//  Tech debt analysis and code quality monitoring.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct TechDebtDashboardView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var analysisPath: String = ""
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showPathPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            pathSelectorView

            if let report = store.techDebtReport {
                reportView(report)
            } else if !analysisPath.isEmpty {
                emptyStateView
            }

            if let error = errorMessage {
                errorView(error)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .fileImporter(
            isPresented: $showPathPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    analysisPath = url.path
                }
            case .failure(let error):
                errorMessage = "Failed to select path: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Tech Debt Dashboard")
                .font(Bauhaus.Font.header)

            Spacer()
        }
    }

    private var pathSelectorView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Analysis Path")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            HStack(spacing: Bauhaus.Grid.x2) {
                TextField("Enter path to analyze", text: $analysisPath)
                    .accessibilityLabel("Directory Path")
                    .textFieldStyle(.roundedBorder)
                    .font(Bauhaus.Font.mono)

                Button(action: { showPathPicker = true }) {
                    Image(systemName: "folder")
                }
                .accessibilityLabel("Browse directory")
                .secondaryButtonStyle()

                Button(action: { Task { await runAnalysis() } }) {
                    Label("Analyze", systemImage: "magnifyingglass")
                }
                .accessibilityLabel("Execute analysis")
                .primaryButtonStyle()
                .disabled(analysisPath.isEmpty || isAnalyzing)

                if isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if !analysisPath.isEmpty {
                Text(analysisPath)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func reportView(_ report: HarmoniaClient.TechDebtAuditResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            summaryView(report)

            Divider()

            severityBreakdownView(report)

            if !report.categories.isEmpty {
                Divider()
                categoryBreakdownView(report)
            }
        }
    }

    private func summaryView(_ report: HarmoniaClient.TechDebtAuditResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Text("Total Issues")
                    .font(Bauhaus.Font.subHeader)

                Spacer()

                Text("\(report.totalIssues)")
                    .font(Bauhaus.Font.header)
                    .foregroundStyle(issueColor(report.totalIssues)) // OK: Bauhaus
            }

            if report.criticalIssues > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Bauhaus.Color.error)

                    Text("\(report.criticalIssues) critical issues require immediate attention")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.error)
                }
                .padding(Bauhaus.Grid.x2)
                .background(Bauhaus.Color.error.opacity(0.1))
                .cornerRadius(Bauhaus.Grid.unit)
            }
        }
    }

    private func severityBreakdownView(_ report: HarmoniaClient.TechDebtAuditResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("By Severity")
                .font(Bauhaus.Font.subHeader)

            severityRow(label: "Critical", count: report.criticalIssues, color: Bauhaus.Color.error)
            severityRow(label: "High", count: report.highIssues, color: Bauhaus.Color.warning)
            severityRow(label: "Medium", count: report.mediumIssues, color: Bauhaus.Color.warning.opacity(0.7))
            severityRow(label: "Low", count: report.lowIssues, color: Bauhaus.Color.accent)
        }
    }

    private func severityRow(label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: Bauhaus.Grid.unit, height: Bauhaus.Grid.unit)

            Text(label)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            Spacer()

            Text("\(count)")
                .font(Bauhaus.Font.mono)
                .foregroundStyle(count > 0 ? color : Bauhaus.Color.textSecondary)

            // Progress bar
            GeometryReader { _ in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Bauhaus.Color.background)
                        .frame(width: 100, height: 4) // OK: Fixed progress width

                    if count > 0, let report = store.techDebtReport {
                        Rectangle()
                            .fill(color)
                            .frame(width: min(100, CGFloat(count) / CGFloat(report.totalIssues) * 100), height: 4) // OK: Dynamic progress width
                    }
                }
            }
            .frame(width: 100, height: 4) // OK: Fixed progress width
        }
    }

    private func categoryBreakdownView(_ report: HarmoniaClient.TechDebtAuditResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("By Category")
                .font(Bauhaus.Font.subHeader)

            ForEach(Array(report.categories.sorted { $0.value > $1.value }), id: \.key) { category, count in
                categoryRow(name: category, count: count, total: report.totalIssues)
            }
        }
    }

    private func categoryRow(name: String, count: Int, total: Int) -> some View {
        HStack {
            Text(name)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Spacer()

            Text("\(count)")
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            Text("(\(percentage(count, total: total))%)")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text("No analysis yet")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Text("Click 'Analyze' to scan for tech debt")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
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

    private func runAnalysis() async {
        guard !analysisPath.isEmpty else { return }

        isAnalyzing = true
        errorMessage = nil

        await store.runTechDebtAudit(path: analysisPath)

        if store.techDebtReport == nil {
            errorMessage = "Analysis failed. Check that the path exists and is accessible."
        }

        isAnalyzing = false
    }

    // MARK: - Helpers

    private func issueColor(_ count: Int) -> Color { // OK: Bauhaus
        if count == 0 {
            return Bauhaus.Color.success
        } else if count < 10 {
            return Bauhaus.Color.warning.opacity(0.7) // Yellowish proxy
        } else if count < 50 {
            return Bauhaus.Color.warning // Orange proxy
        } else {
            return Bauhaus.Color.error
        }
    }

    private func percentage(_ count: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(count) / Double(total)) * 100)
    }
}
