//
//  ContractDashboardView.swift
//  AnigmaAppMac
//
//  Real-time contract health monitoring dashboard.
//

import SwiftUI
import Charts

struct ContractDashboardView: View {
    @State private var analytics: ContractAnalytics?
    @State private var report: ContractAnalyticsReport?
    @State private var selectedContract: String?

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if let report = report {
                reportContentView(report: report)
            } else {
                loadingView
            }
        }
        .background(Bauhaus.Color.background)
        .task {
            await loadAnalytics()
        }
    }

    private var headerView: some View {
        HStack {
            Text("Contract Health Dashboard")
                .font(Bauhaus.Font.header)

            Spacer()

            Button(action: refreshData) { // ButtonStyle
                Image(systemName: "arrow.clockwise")
            }
            .primaryButtonStyle()
            .accessibilityLabel("Refresh analytics")
            .accessibilityHint("Reloads contract violation data")
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
    }

    private func reportContentView(report: ContractAnalyticsReport) -> some View {
        ScrollView {
            VStack(spacing: Bauhaus.Grid.x2) {
                summaryCards(report: report)
                contractStatusGrid(report: report)
                topOffendersSection(report: report)
            }
            .padding(Bauhaus.Grid.x2)
        }
    }

    private func summaryCards(report: ContractAnalyticsReport) -> some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            MetricCard(
                title: "Total Violations",
                value: "\(report.totalViolations)",
                trend: .neutral,
                color: Bauhaus.Color.textPrimary
            )

            MetricCard(
                title: "Critical",
                value: "\(report.criticalViolations)",
                trend: .down,
                color: Bauhaus.Color.error
            )

            MetricCard(
                title: "Contracts",
                value: "\(report.contractReports.count)",
                trend: .neutral,
                color: Bauhaus.Color.accent
            )
        }
    }

    private func contractStatusGrid(report: ContractAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text("Contract Status")
                .font(Bauhaus.Font.subHeader)

            ForEach(Array(report.contractReports.keys.sorted()), id: \.self) { contractName in
                if let contractReport = report.contractReports[contractName] {
                    ContractStatusRow(
                        contract: contractReport,
                        isSelected: selectedContract == contractName
                    )                        { selectedContract = contractName }
                }
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
    }

    private func topOffendersSection(report: ContractAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text("Top Offenders")
                .font(Bauhaus.Font.subHeader)

            ForEach(Array(report.topOffenders.prefix(10)), id: \.file) { offender in
                offenderRow(offender)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
    }

    private func offenderRow(_ offender: (file: String, count: Int)) -> some View {
        let fileName = offender.file.components(separatedBy: "/").last ?? offender.file
        return HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Bauhaus.Color.warning)

            Text(fileName)
                .font(Bauhaus.Font.mono)
                .lineLimit(1)

            Spacer()

            Text("\(offender.count)")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.error)
        }
        .padding(Bauhaus.Grid.unit)
        .background(Bauhaus.Color.surface.opacity(0.6))
        .cornerRadius(4)
    }

    private var loadingView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            ProgressView()
            Text("Loading contract analytics...")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadAnalytics() async {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap appSupport")
        }
        let storageURL = appSupport.appendingPathComponent("Anigma/ContractAnalytics")

        analytics = ContractAnalytics(storageURL: storageURL)

        if let analytics = analytics {
            report = await analytics.generateReport()
        }
    }

    private func refreshData() {
        Task {
            await loadAnalytics()
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let trend: Trend
    let color: Color

    enum Trend {
        case up, down, neutral

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return Bauhaus.Color.error
            case .down: return Bauhaus.Color.trusted
            case .neutral: return Bauhaus.Color.textSecondary
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text(title)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(Bauhaus.Font.header)
                    .foregroundStyle(color)

                Image(systemName: trend.icon)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(trend.color)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
    }
}

// MARK: - Contract Status Row

struct ContractStatusRow: View {
    let contract: ContractReport
    let isSelected: Bool
    let onSelect: () -> Void

    var statusColor: Color {
        if contract.criticalViolations > 0 {
            return Bauhaus.Color.error
        } else if contract.totalViolations > 0 {
            return Bauhaus.Color.warning
        } else {
            return Bauhaus.Color.trusted
        }
    }

    var statusIcon: String {
        if contract.criticalViolations > 0 {
            return "xmark.circle.fill"
        } else if contract.totalViolations > 0 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    var trendIcon: String {
        switch contract.trend {
        case .improving: return "arrow.down.right"
        case .stable: return "minus"
        case .degrading: return "arrow.up.right"
        }
    }

    var trendColor: Color {
        switch contract.trend {
        case .improving: return Bauhaus.Color.trusted
        case .stable: return Bauhaus.Color.textSecondary
        case .degrading: return Bauhaus.Color.error
        }
    }

    var body: some View {
        Button(action: onSelect) { // ButtonStyle
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(contract.name)
                        .font(Bauhaus.Font.body)

                    HStack(spacing: Bauhaus.Grid.unit) {
                        Text("\(contract.totalViolations) violations")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        Text("•")
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        Text("\(Int(contract.coverage * 100))% coverage")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: trendIcon)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(trendColor)
            }
            .padding(Bauhaus.Grid.unit)
            .background(isSelected ? Bauhaus.Color.accent.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select contract: \(contract.name)")
        .accessibilityHint("Shows detailed violations for this contract")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    ContractDashboardView()
        .frame(width: 800, height: 600) // OK: Preview sizing
}
